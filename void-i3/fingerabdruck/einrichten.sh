#!/bin/sh
# void-i3/fingerabdruck/einrichten.sh -- bringt den Fingerabdrucksensor
# Synaptics 06cb:00e7 (HP ENVY x360 13) unter Void Linux zum Laufen.
#
# Warum ein eigener Build: libfprint aus dem Void-Repo kennt diesen Sensor
# nicht ("No driver found for USB device 06CB:00E7"). Er gehoert zur
# Synaptics-Familie "Tudor Match-in-Sensor": Abgleich und Speicherung laufen
# komplett im Chip, die Verbindung ist TLS-verschluesselt und an eine
# Kopplung mit dem Rechner gebunden. Der quelloffene Treiber "synatlsmoc"
# von vojtapl (reverse-engineered, kein Windows-Blob) liegt in einem
# libfprint-Fork; dazu braucht fprintd einen kleinen Patch, damit es die
# Kopplungsdaten des Sensors dauerhaft ablegt (/var/lib/fprint/0-persistent).
#
# Das Skript baut beides nach /usr/local, entfernt die Void-Pakete fprintd
# und libfprint (sie wuerden sich sonst um /usr/lib/security/pam_fprintd.so
# streiten), legt die polkit-Regel ab und traegt pam_fprintd fuer sudo und
# den tty-Login ein. Es ist mehrfach ausfuehrbar.
#
# Aufruf als normaler Benutzer (fragt selbst nach sudo):
#     sh void-i3/fingerabdruck/einrichten.sh
#
# Danach von Hand:  fprintd-enroll   (11 Beruehrungen), dann fprintd-verify.
#
# Achtung bei Dual-Boot: die Kopplung mit Linux macht eine vorhandene
# Windows-Hello-Kopplung ungueltig (und umgekehrt). Hier ohne Belang -- auf
# dem Notebook liegt nur Void.

set -eu

ROT=''; GRUEN=''; GELB=''; FETT=''; AUS=''
if [ -t 1 ]; then
    ROT=$(printf '\033[31m'); GRUEN=$(printf '\033[32m')
    GELB=$(printf '\033[33m'); FETT=$(printf '\033[1m'); AUS=$(printf '\033[0m')
fi
schritt()  { printf '\n%s==> %s%s\n' "$FETT" "$1" "$AUS"; }
info()     { printf '    %s\n' "$1"; }
gut()      { printf '    %s%s%s\n' "$GRUEN" "$1" "$AUS"; }
warn()     { printf '    %s%s%s\n' "$GELB" "$1" "$AUS"; }
fehler()   { printf '%sFehler: %s%s\n' "$ROT" "$1" "$AUS" >&2; exit 1; }

# Feste Staende, damit der Build auch in einem Jahr noch dasselbe ergibt.
LIBFPRINT_REPO=https://github.com/vojtapl/libfprint
LIBFPRINT_STAND=2f8b3e781b53793d11ed53d3054977271ed6689e   # 2026-07-08, Treiber synatlsmoc
FPRINTD_REPO=https://gitlab.freedesktop.org/libfprint/fprintd.git
FPRINTD_STAND=v1.94.5                                       # wie das Void-Paket

HIER=$(cd "$(dirname "$0")" && pwd)
BAU=${BAU:-$HOME/.cache/void-i3-fingerabdruck}
JOBS=$(nproc 2>/dev/null || echo 2)

# ---------------------------------------------------------------- Vorpruefung

command -v xbps-install >/dev/null 2>&1 || fehler "Das ist kein Void Linux -- xbps-install fehlt."
[ "$(id -u)" -ne 0 ] || fehler "Bitte als normaler Benutzer starten, nicht als root."
command -v sudo >/dev/null 2>&1 || fehler "sudo fehlt."
[ -f "$HIER/fprintd-persistent-data.patch" ] || fehler "fprintd-persistent-data.patch fehlt neben dem Skript."

sensor_da() {
    for d in /sys/bus/usb/devices/*; do
        [ "$(cat "$d/idVendor" 2>/dev/null)" = 06cb ] &&
        [ "$(cat "$d/idProduct" 2>/dev/null)" = 00e7 ] && return 0
    done
    return 1
}
sensor_da || fehler "Kein Synaptics 06cb:00e7 am USB. Fuer andere Sensoren reicht meist das Void-Paket fprintd."

# ------------------------------------------------------------------- Pakete

schritt "Pakete"
sudo xbps-install -Sy git meson ninja gcc pkg-config \
    glib-devel libgusb-devel nss-devel pixman-devel gdk-pixbuf-devel \
    openssl-devel libusb-devel polkit-devel dbus-devel dbus-glib-devel \
    pam-devel elogind-devel cairo-devel gettext libxslt \
    python3-cairo python3-dbus python3-gobject gobject-introspection
gut "Build-Werkzeuge da"

# Die Void-Pakete muessen weg, BEVOR unser fprintd installiert wird: beide
# legen /usr/lib/security/pam_fprintd.so ab, und xbps-remove wuerde spaeter
# unsere Datei mitnehmen.
for p in fprintd libfprint libfprint-udev-rules; do
    if xbps-query "$p" >/dev/null 2>&1; then
        sudo xbps-remove -y "$p" >/dev/null
        info "Void-Paket $p entfernt (Ersatz kommt nach /usr/local)"
    fi
done

# ---------------------------------------------------------------- libfprint

schritt "libfprint mit Treiber synatlsmoc"
mkdir -p "$BAU"
if [ ! -d "$BAU/libfprint/.git" ]; then
    git clone -q "$LIBFPRINT_REPO" "$BAU/libfprint"
fi
git -C "$BAU/libfprint" fetch -q origin
git -C "$BAU/libfprint" checkout -q "$LIBFPRINT_STAND"
grep -q '0x00E7' "$BAU/libfprint/libfprint/drivers/synatlsmoc/synatlsmoc.c" \
    || fehler "Der Treiber im Fork kennt 06cb:00e7 nicht mehr -- Stand pruefen."
if [ ! -f "$BAU/libfprint/build/build.ninja" ]; then
    meson setup "$BAU/libfprint/build" "$BAU/libfprint" --prefix=/usr/local \
        -Dudev_rules=disabled -Dgtk-examples=false -Ddoc=false \
        -Dintrospection=false >/dev/null
fi
ninja -C "$BAU/libfprint/build" -j "$JOBS" >/dev/null
sudo ninja -C "$BAU/libfprint/build" install >/dev/null
sudo ldconfig
gut "/usr/local/lib/libfprint-2.so.2"

# ------------------------------------------------------------------ fprintd

schritt "fprintd mit Persistenz-Patch"
if [ ! -d "$BAU/fprintd/.git" ]; then
    git clone -q --branch "$FPRINTD_STAND" --depth 1 "$FPRINTD_REPO" "$BAU/fprintd"
fi
git -C "$BAU/fprintd" checkout -q -- .
git -C "$BAU/fprintd" apply "$HIER/fprintd-persistent-data.patch"
if [ ! -f "$BAU/fprintd/build/build.ninja" ]; then
    # Void hat kein systemd: Sitzungsdinge kommen von libelogind, das PAM-Modul
    # muss dorthin, wo Void seine PAM-Module sucht.
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
    meson setup "$BAU/fprintd/build" "$BAU/fprintd" --prefix=/usr/local \
        --sysconfdir=/etc/fprintd -Dman=false -Dgtk_doc=false \
        -Dsystemd=false -Dlibsystemd=libelogind \
        -Dpam_modules_dir=/usr/lib/security >/dev/null
fi
ninja -C "$BAU/fprintd/build" -j "$JOBS" >/dev/null
sudo ninja -C "$BAU/fprintd/build" install >/dev/null
# D-Bus-Dienstdatei und polkit-Aktion landen ueber pkg-config direkt unter
# /usr/share -- dort, wo dbus-daemon und polkitd sie auch lesen.
sudo pkill -x fprintd 2>/dev/null || true
sudo dbus-send --system --type=method_call --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig 2>/dev/null || true
gut "/usr/local/libexec/fprintd, /usr/lib/security/pam_fprintd.so"

# ------------------------------------------------------------------- polkit

schritt "polkit"
# Ohne elogind gibt es keine "aktive Sitzung", also wuerde polkit jeden
# Aufruf als Benutzer ablehnen. Die Regel erlaubt wheel das Anlernen und
# Pruefen eigener Finger; polkitd liest rules.d von selbst neu ein.
sudo install -m 644 -o root -g root "$HIER/50-fprintd-local.rules" \
    /etc/polkit-1/rules.d/50-fprintd-local.rules
gut "/etc/polkit-1/rules.d/50-fprintd-local.rules"

# ---------------------------------------------------------------------- PAM

schritt "PAM (sudo und tty-Login)"
# Eine Zeile vor dem ersten "auth ... include": bei sudo ist das die erste
# auth-Zeile ueberhaupt, bei login steht sie hinter securetty und nologin.
# "sufficient": Treffer reicht, alles andere faellt auf das Passwort zurueck.
# Wer keinen Finger angelernt hat, merkt nichts -- pam_fprintd gibt sofort ab.
pam_eintragen() {
    datei=/etc/pam.d/$1
    [ -f "$datei" ] || { warn "$datei fehlt -- uebersprungen"; return 0; }
    if grep -q pam_fprintd "$datei"; then
        info "$datei: schon eingetragen"
        return 0
    fi
    [ -e "$datei.vor-void-i3" ] || sudo cp -a "$datei" "$datei.vor-void-i3"
    awk 'BEGIN { getan = 0 }
         !getan && $1 == "auth" && $0 ~ /include/ {
             print "# void-i3: Fingerabdruck zuerst, nach 15 s ohne Finger kommt die Passwortfrage."
             print "auth \t\tsufficient \tpam_fprintd.so timeout=15"
             getan = 1
         }
         { print }' "$datei" > "/tmp/pam.$$"
    sudo install -m 644 -o root -g root "/tmp/pam.$$" "$datei"
    rm -f "/tmp/pam.$$"
    info "$datei"
}
pam_eintragen sudo
pam_eintragen login
gut "Fingerabdruck fuer sudo und Login eingetragen (Passwort bleibt)"

# ---------------------------------------------------------------- Kontrolle

schritt "Kontrolle"
if fprintd-list "$(id -un)" 2>&1 | grep -q 'Synaptics Tudor'; then
    gut "fprintd sieht den Sensor als 'Synaptics Tudor Match-In-Sensor'"
else
    warn "fprintd findet den Sensor nicht. Log: sudo G_MESSAGES_DEBUG=all /usr/local/libexec/fprintd -t"
fi

cat <<ENDE

${FETT}Fertig.${AUS} Jetzt Finger anlernen -- als normaler Benutzer:

    fprintd-enroll                      rechter Zeigefinger, 11 Beruehrungen
    fprintd-enroll -f left-index-finger weitere Finger
    fprintd-verify                      Gegenprobe

Danach: sudo fragt zuerst nach dem Finger, der tty-Login ebenso, und das
Sperrmenue (F12) entsperrt auf Fingertipp. Das Passwort geht ueberall weiter.
ENDE
