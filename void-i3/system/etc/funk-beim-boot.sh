#!/bin/sh
# funk-beim-boot.sh -- WLAN nach dem Neustart zuverlaessig anschalten.
#
# Auf diesem HP setzt hp_wmi beim Start einen rfkill-Softblock aufs WLAN.
# Dagegen hielten bisher zwei Stellen:
#
#   * /etc/udev/rules.d/60-rfkill-unblock.rules -- greift nur auf ACTION=="add",
#     also genau einmal, sobald das rfkill-Geraet auftaucht (gemessen: Sekunde
#     4,4). Der ACTION-Filter ist zwingend, sonst liesse sich WLAN nie
#     ausschalten; die Begruendung steht in der Regel selbst.
#   * "rfkill unblock wifi" in /etc/rc.local -- laeuft in Sekunde ~6, direkt
#     bevor runit die Dienste startet.
#
# Beides ist zu frueh. hp_wmi laedt erst in Sekunde 5,8 ("query 0x4c returned
# error 0x6") und meldet danach noch eigene Ereignisse -- gemessen ein
# "hp_wmi: Unknown event_id - 131073" in Sekunde 15. Kommt der Block erst
# danach, haelt ihn nichts mehr auf, und die Anmeldung findet ein totes WLAN
# vor.
#
# Darum haelt dieses Skript ein Startfenster lang dagegen: sofort einschalten
# und danach jede halbe Sekunde nachsehen, ob wieder geblockt wurde. Nach
# FENSTER Sekunden ist Schluss -- ab dann darf der WLAN-Klick in der Leiste
# (~/.local/bin/netz) wieder ausschalten, ohne dass hier jemand dagegenhaelt.
#
# Zweiter Fall, den das Fenster mit abdeckt: wpa_supplicant startet in Sekunde
# 6 und findet ein geblocktes Geraet vor. Haengt es danach fest, statt neu zu
# suchen, bekaeme man trotz freiem Funk keine Verbindung -- deshalb der eine
# Anstoss nach ANSTOSS Sekunden.
#
# Was passiert ist, steht in /var/log/funk-beim-boot.log (bei jedem Boot neu).
#
# Aufgerufen aus /etc/rc.local, laeuft von dort im Hintergrund weiter.

FENSTER=90      # so lange wird der Block aufgehoben
ANSTOSS=25      # danach notfalls wpa_supplicant neu starten
LOG=/var/log/funk-beim-boot.log

PATH=/usr/bin:/usr/sbin

zeit()  { awk '{printf "%6.1f", $1}' /proc/uptime; }
notiz() { echo "$(zeit)s  $*" >> "$LOG"; }

# Pfad des WLAN-rfkill-Geraets. Jedes Mal neu gesucht: beim Boot kann es noch
# fehlen, weil iwlwifi erst geladen wird.
wlan_rfkill() {
    for d in /sys/class/rfkill/*; do
        [ -r "$d/type" ] || continue
        [ "$(cat "$d/type")" = wlan ] && { echo "$d"; return 0; }
    done
    return 1
}

# Name der WLAN-Schnittstelle -- nicht fest verdrahtet, das Geraet heisst hier
# wlo1, auf anderer Hardware anders.
wlan_geraet() {
    for n in /sys/class/net/*; do
        [ -d "$n/wireless" ] && { basename "$n"; return 0; }
    done
    return 1
}

# True, solange keine Funkverbindung steht.
ohne_verbindung() {
    g=$(wlan_geraet) || return 0
    [ "$(cat "/sys/class/net/$g/carrier" 2>/dev/null)" = 1 ] && return 1
    return 0
}

: > "$LOG"
notiz "Startfenster offen (${FENSTER}s)"

ende=$(awk -v f="$FENSTER" '{print $1 + f}' /proc/uptime)
angestossen=nein
zuletzt=

while awk -v e="$ende" '{ exit !($1 < e) }' /proc/uptime; do
    if d=$(wlan_rfkill); then
        if [ "$(cat "$d/soft")" = 1 ]; then
            rfkill unblock wlan
            notiz "Softblock auf $(basename "$d") gefunden -- aufgehoben"
            zuletzt=block
        elif [ "$zuletzt" != frei ]; then
            notiz "Funk frei"
            zuletzt=frei
        fi
    elif [ "$zuletzt" != fehlt ]; then
        notiz "noch kein WLAN-rfkill-Geraet"
        zuletzt=fehlt
    fi

    # Funk ist frei, aber es kommt keine Verbindung: einmal anstossen.
    if [ "$angestossen" = nein ] && [ "$zuletzt" = frei ] && ohne_verbindung &&
       awk -v a="$ANSTOSS" '{ exit !($1 > a) }' /proc/uptime; then
        angestossen=ja
        notiz "keine Verbindung trotz freiem Funk -- wpa_supplicant neu gestartet"
        sv restart wpa_supplicant >/dev/null 2>&1
    fi

    sleep 0.5
done

notiz "Startfenster zu -- $(ip -br addr show scope global 2>/dev/null | tr -s ' ' | tr '\n' '|')"
