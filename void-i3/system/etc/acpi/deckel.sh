#!/bin/sh
# deckel.sh -- Deckel zu: Bildschirm sperren, dann Bereitschaft (ACPI S3).
#
# Wird von acpid aufgerufen, siehe /etc/acpi/events/deckel. acpid uebergibt
# die Rohzeile des Ereignisses, bei diesem Geraet:
#   button/lid LID0 00000080 00000001  (zu)
#   button/lid LID0 00000080 00000002  (auf)
# Das dritte Feld ist bei manchen Geraeten "close"/"open", bei diesem eine
# Zahl -- darum wird der Zustand nicht aus den Argumenten gelesen, sondern
# direkt in /proc/acpi/button/lid/LID0/state nachgeschaut. Das ist die
# einzige Quelle, die auf jeder Firmware stimmt.
#
# Laeuft als root. Gesperrt werden muss aber in der X-Sitzung des Benutzers,
# darum wird der Besitzer des laufenden i3 gesucht und dessen DISPLAY und
# XAUTHORITY aus seiner Prozessumgebung uebernommen. Fest verdrahtete Werte
# waeren hier falsch: die X-Cookies haengen am Rechnernamen.

zustand=$(cat /proc/acpi/button/lid/LID0/state 2>/dev/null)
case "$zustand" in
    *closed) ;;
    *) exit 0 ;;   # aufgeklappt oder nicht lesbar: nichts tun
esac

# Nur eine Ausfuehrung gleichzeitig. acpid meldet den Schalter je nach
# Firmware doppelt, und zwei parallele zzz-Laeufe waeren ein Rennen.
if [ "$DECKEL_SPERRE" != "1" ]; then
    DECKEL_SPERRE=1
    export DECKEL_SPERRE
    exec flock -n /run/deckel.lock "$0" "$@"
fi

i3pid=$(pgrep -x i3 | head -n1)
if [ -n "$i3pid" ]; then
    benutzer=$(ps -o user= -p "$i3pid" | tr -d ' ')
    umgebung=$(tr '\0' '\n' < "/proc/$i3pid/environ" 2>/dev/null)
    anzeige=$(printf '%s\n' "$umgebung" | sed -n 's/^DISPLAY=//p'    | head -n1)
    cookie=$( printf '%s\n' "$umgebung" | sed -n 's/^XAUTHORITY=//p' | head -n1)

    if [ -n "$benutzer" ] && [ -n "$anzeige" ]; then
        # i3lock forkt, der Aufruf kehrt also sofort zurueck. Das Sperren
        # laeuft ueber dasselbe Skript wie $mod+l und das Sitzungsmenue --
        # damit gilt hier auch das Entsperren per Fingerabdruck.
        su "$benutzer" -c \
           "DISPLAY='$anzeige' XAUTHORITY='$cookie' ~/.local/bin/i3-sitzung sperren" \
           >/dev/null 2>&1
        # Kurz warten, damit das Sperrfenster noch sicher hochkommt, bevor
        # der Rechner einschlaeft -- sonst liegt der entsperrte Schirm beim
        # Aufwachen einen Wimpernschlag lang offen da.
        sleep 1
    else
        logger -t deckel "X-Sitzung nicht bestimmbar, es wird ohne Sperre geschlafen"
    fi
else
    logger -t deckel "kein i3 gefunden, es wird ohne Sperre geschlafen"
fi

logger -t deckel "Deckel zu -- Bereitschaft"
zzz
