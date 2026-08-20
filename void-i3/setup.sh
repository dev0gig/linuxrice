#!/bin/sh
# void-i3/setup.sh -- richtet nach einer frischen Void-Installation die
# komplette Arbeitsumgebung ein: Xorg, i3, Terminal, Schriften, Cursor,
# Touchpad, Tastatur und das Vitals-Dashboard auf Arbeitsflaeche 4.
#
# Aufruf aus dem geklonten Repo heraus:
#     sh void-i3/setup.sh
#
# Oder ohne Klon -- xbps-fetch liegt auf jedem Void bei, curl und git nicht:
#     xbps-fetch -o setup.sh https://raw.githubusercontent.com/dev0gig/linuxrice/main/void-i3/setup.sh
#     sh setup.sh
# Das Skript holt sich das Repo dann selbst.
#
# Es ist mehrfach ausfuehrbar: bestehende Dateien werden vor dem
# Ueberschreiben nach <datei>.vor-void-i3 gesichert.
#
# Was das Skript NICHT tut, weil es ohne dich nicht geht:
#   * WLAN verbinden (wpa_supplicant), Tailscale anmelden
#   * Firefox einrichten (Profil, Anmeldungen, Erweiterungen)
#   * eigene Hintergrundbilder nach ~/Bilder/Wallpapers legen
# Am Ende steht eine Liste davon.

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

# ---------------------------------------------------------------- Vorpruefung

command -v xbps-install >/dev/null 2>&1 || fehler "Das ist kein Void Linux -- xbps-install fehlt."
[ "$(id -u)" -ne 0 ] || fehler "Bitte als normaler Benutzer starten, nicht als root. Fuer die Systemteile fragt das Skript selbst nach sudo."
command -v sudo >/dev/null 2>&1 || fehler "sudo fehlt. Nachinstallieren mit: su -c 'xbps-install -S sudo' -- und den eigenen Benutzer in die Gruppe wheel aufnehmen."

# ------------------------------------------------------- Repo finden oder holen
# $0 zeigt beim Aufruf ueber eine Pipe nicht auf eine Datei, darum die Pruefung
# auf das Verzeichnis daneben statt auf $0 allein.
QUELLE=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
if [ -z "$QUELLE" ] || [ ! -d "$QUELLE/config" ]; then
    schritt "Repo wird geholt"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT INT TERM
    xbps-fetch -o "$TMP/repo.tar.gz" \
        "https://codeload.github.com/dev0gig/linuxrice/tar.gz/refs/heads/main" \
        || fehler "Download fehlgeschlagen. Besteht eine Netzverbindung?"
    tar xzf "$TMP/repo.tar.gz" -C "$TMP"
    QUELLE="$TMP/linuxrice-main/void-i3"
    [ -d "$QUELLE/config" ] || fehler "Das Repo sieht anders aus als erwartet."
    gut "nach $QUELLE entpackt"
fi
VITALS="$QUELLE/workspaces-vitals/home"
[ -d "$VITALS" ] || fehler "workspaces-vitals fehlt neben dem Skript."

# ------------------------------------------------------------------- Fragen

schritt "Ein paar Angaben"
info "Arbeitsflaeche 2 traegt ein lokales Terminal, Arbeitsflaeche 3 eine"
info "SSH-Sitzung. Die Namen stehen spaeter in der Leiste."
printf '    Name fuer Arbeitsflaeche 2 [lokal]: '
read -r WS2_NAME || WS2_NAME=""
[ -n "$WS2_NAME" ] || WS2_NAME="lokal"

printf '    SSH-Ziel fuer Arbeitsflaeche 3, z.B. benutzer@rechner\n'
printf '    (leer lassen, dann bleibt Arbeitsflaeche 3 frei): '
read -r SSH_TARGET || SSH_TARGET=""

WS3_NAME=""
if [ -n "$SSH_TARGET" ]; then
    # Vorschlag: der Rechnername aus benutzer@rechner
    VORGABE=${SSH_TARGET#*@}
    printf '    Name fuer Arbeitsflaeche 3 [%s]: ' "$VORGABE"
    read -r WS3_NAME || WS3_NAME=""
    [ -n "$WS3_NAME" ] || WS3_NAME="$VORGABE"
fi

# ------------------------------------------------------------------- Pakete

schritt "Pakete"

# Grundlage: Xorg ohne Display-Manager, i3, Terminal, Browser.
PAKETE="xorg-minimal xorg-fonts xrdb setxkbmap xinput xdg-utils
        mesa-dri xf86-video-intel
        i3 i3status i3lock rofi dmenu picom feh
        alacritty xterm firefox pcmanfm
        libinput-gestures python3-i3ipc
        nerd-fonts-symbols-ttf noto-fonts-cjk-sans papirus-icon-theme"

# Benachrichtigungen: dunst ist der D-Bus-Dienst auf
# org.freedesktop.Notifications. Fehlt er, verschwinden Meldungen von
# Firefox & Co. spurlos -- es gibt dann schlicht niemanden, der sie anzeigt.
# libnotify liefert notify-send, brightnessctl und playerctl bedienen die
# F-Tasten, acpi liest Akku und Temperatur.
PAKETE="$PAKETE dunst libnotify brightnessctl playerctl acpi"

# Bluetooth. bluez bringt bluetoothd und bluetoothctl mit; bedient wird beides
# ueber den Bluetooth-Block in der Leiste (~/.local/bin/bluetooth). Ein
# Tray-Applet wie blueman braucht es dafuer nicht.
PAKETE="$PAKETE bluez"

# Das Vitals-Dashboard auf Arbeitsflaeche 4.
PAKETE="$PAKETE zellij btop glances bandwhich tty-clock lm_sensors"

# Fuer die LEDs in F5 und F8: gcc uebersetzt das winzige Hilfsprogramm
# tasten-led, setcap (aus libcap-progs) gibt ihm die noetige Capability.
# Begruendung im Kopf von system/bin/tasten-led.c.
PAKETE="$PAKETE gcc libcap-progs"

# Werkzeuge, die im Alltag dazugehoeren.
PAKETE="$PAKETE git github-cli rclone xclip ImageMagick nodejs tailscale
        duf dust fonttools"

info "xbps wird aufgefrischt und die Paketliste installiert."
sudo xbps-install -Syu || true          # erster Lauf aktualisiert ggf. nur xbps
# shellcheck disable=SC2086
sudo xbps-install -Sy $PAKETE
gut "Pakete installiert"

# ---------------------------------------------------------------- Bluetooth

schritt "Bluetooth"
# AutoEnable=false: der Adapter bleibt nach dem Booten aus und geht erst auf
# Klick an (Bluetooth-Block in der Leiste). Muss stehen, bevor bluetoothd das
# erste Mal startet -- sonst schaltet er den Adapter sofort ein.
if [ -f /etc/bluetooth/main.conf ]; then
    if grep -q '^AutoEnable=false' /etc/bluetooth/main.conf; then
        info "Bluetooth startet bereits ausgeschaltet"
    else
        sudo sed -i 's/^#\?AutoEnable=true$/AutoEnable=false/' /etc/bluetooth/main.conf
        gut "Bluetooth startet ausgeschaltet"
    fi
else
    warn "/etc/bluetooth/main.conf fehlt, AutoEnable nicht gesetzt"
fi

# ------------------------------------------------------------------ Dienste

schritt "Dienste"
# dbus muss mit: bluetoothd bricht ohne ihn ab ("sv check dbus" in seinem
# run-Skript), und die Meldungen von dunst laufen ebenfalls darueber.
for d in dbus dhcpcd wpa_supplicant tailscaled bluetoothd; do
    if [ ! -e "/etc/sv/$d" ]; then
        warn "$d gibt es nicht, uebersprungen"
    elif [ -e "/var/service/$d" ]; then
        info "$d laeuft bereits"
    else
        sudo ln -sf "/etc/sv/$d" /var/service/
        gut "$d eingeschaltet"
    fi
done

# ------------------------------------------------------------------- Locale

schritt "Deutsche Locale"
# i3status und die Uhr im Dashboard brauchen de_DE.UTF-8 fuer Wochentag und
# Monat. Die Systemsprache bleibt bewusst C.UTF-8 -- Programmmeldungen sollen
# englisch bleiben, nur die Datumsformate deutsch.
if locale -a 2>/dev/null | grep -qi '^de_DE.utf8$'; then
    info "de_DE.UTF-8 ist bereits erzeugt"
else
    sudo sed -i 's/^#\(de_DE.UTF-8 UTF-8\)/\1/' /etc/default/libc-locales
    sudo xbps-reconfigure -f glibc-locales
    gut "de_DE.UTF-8 erzeugt"
fi

# Deutsche Tastatur auf der Textkonsole (in X macht das 00-keyboard.conf).
if grep -q '^KEYMAP=de' /etc/rc.conf 2>/dev/null; then
    info "Konsolentastatur steht schon auf de"
else
    sudo sed -i 's/^#\?KEYMAP=.*/KEYMAP=de/' /etc/rc.conf
    grep -q '^KEYMAP=' /etc/rc.conf || printf 'KEYMAP=de\n' | sudo tee -a /etc/rc.conf >/dev/null
    gut "Konsolentastatur auf de gestellt"
fi

# -------------------------------------------------------------------- Gruppe

schritt "Gruppenzugehoerigkeit"
# libinput-gestures liest /dev/input/* direkt und braucht dafuer die Gruppe
# input. Sie greift erst nach einer Neuanmeldung.
BENUTZER=$(id -un)
if id -nG "$BENUTZER" | tr ' ' '\n' | grep -qx input; then
    info "$BENUTZER ist bereits in der Gruppe input"
else
    sudo usermod -aG input "$BENUTZER"
    gut "$BENUTZER zur Gruppe input hinzugefuegt (wirkt nach der naechsten Anmeldung)"
fi

# ------------------------------------------------------------------ Schriften

schritt "Schrift Red Hat Mono"
# Void hat die Familie nicht als Paket, und das Sammelpaket google-fonts-ttf
# waere mit 1,9 GB unverhaeltnismaessig -- es sind zehn Dateien zu 780 KB.
if [ -d /usr/share/fonts/redhat-mono ]; then
    info "liegt schon unter /usr/share/fonts/redhat-mono"
else
    TMPF=$(mktemp -d)
    xbps-fetch -o "$TMPF/rh.tar.gz" \
        "https://github.com/RedHatOfficial/RedHatFont/archive/refs/tags/5.0.0.tar.gz" \
        || fehler "Red Hat Mono konnte nicht geladen werden."
    tar xzf "$TMPF/rh.tar.gz" -C "$TMPF"
    sudo mkdir -p /usr/share/fonts/redhat-mono
    find "$TMPF" -name 'RedHatMono-*.ttf' -exec sudo cp {} /usr/share/fonts/redhat-mono/ \;
    find "$TMPF" -maxdepth 3 -iname 'LICENSE*' -exec sudo cp {} /usr/share/fonts/redhat-mono/ \; 2>/dev/null || true
    rm -rf "$TMPF"
    gut "$(ls /usr/share/fonts/redhat-mono/*.ttf | wc -l) Schnitte installiert"
fi

# ------------------------------------------------------------------- Cursor

schritt "Mauszeiger Nordzy"
if [ -d "$HOME/.icons/Nordzy-cursors" ]; then
    info "liegt schon unter ~/.icons/Nordzy-cursors"
else
    TMPC=$(mktemp -d)
    xbps-fetch -o "$TMPC/nz.tar.gz" \
        "https://github.com/guillaumeboehm/Nordzy-cursors/releases/latest/download/Nordzy-cursors.tar.gz" \
        || fehler "Nordzy-cursors konnte nicht geladen werden."
    mkdir -p "$HOME/.icons"
    tar xzf "$TMPC/nz.tar.gz" -C "$HOME/.icons"
    rm -rf "$TMPC"
    gut "nach ~/.icons/Nordzy-cursors entpackt"
fi

# ------------------------------------------------------------- Systemdateien

sichern_system() {
    [ -e "$1" ] && [ ! -e "$1.vor-void-i3" ] && sudo cp -a "$1" "$1.vor-void-i3" || true
}

schritt "Systemdateien"
for rel in etc/X11/xorg.conf.d/00-keyboard.conf \
           etc/X11/xorg.conf.d/30-touchpad.conf \
           etc/fonts/conf.d/56-redhat-mono.conf \
           etc/udev/rules.d/60-rfkill-unblock.rules \
           etc/udev/hwdb.d/61-hp-envy-fkeys.hwdb \
           etc/profile.d/claude-code.sh; do
    sudo mkdir -p "/$(dirname "$rel")"
    sichern_system "/$rel"
    sudo cp "$QUELLE/system/$rel" "/$rel"
    info "/$rel"
done
sudo fc-cache -f >/dev/null 2>&1 || true

# Die hwdb-Datei wirkt erst, wenn sie nach /etc/udev/hwdb.bin uebersetzt ist.
# Der trigger zieht sie fuer die bereits angemeldeten Tastaturen nach, sodass
# F8 und F12 ohne Neustart ankommen.
sudo udevadm hwdb --update
sudo udevadm trigger --sysname-match="event*"
info "Tastatur-Remap F8/F12 uebersetzt und aktiv"

# sudoers braucht Modus 440 und muss fehlerfrei sein -- eine kaputte Datei
# dort sperrt sudo komplett aus. Also erst pruefen, dann mit install ablegen
# (cp wuerde die Rechte des Repos mitnehmen).
if sudo visudo -c -f "$QUELLE/system/etc/sudoers.d/10-sitzung" >/dev/null 2>&1; then
    sudo install -m 440 -o root -g root \
         "$QUELLE/system/etc/sudoers.d/10-sitzung" /etc/sudoers.d/10-sitzung
    info "/etc/sudoers.d/10-sitzung"
else
    warn "sudoers-Schnipsel fehlerhaft -- uebersprungen."
    warn "Das Sitzungsmenue kann dann nur sperren und abmelden."
fi

gut "abgelegt, Schriftcache erneuert"

# Firefox: Mittelklick soll nicht einfuegen. Die Datei liegt im Programm-
# verzeichnis, weil beim ersten Lauf noch kein Profil existiert -- ein
# Firefox-Update ueberschreibt sie wieder.
if [ -d /usr/lib/firefox/browser/defaults/preferences ]; then
    sudo cp "$QUELLE/system/firefox/no-middleclick-paste.js" \
            /usr/lib/firefox/browser/defaults/preferences/
    info "Firefox: Mittelklick-Einfuegen abgeschaltet"
    warn "Diese Datei verschwindet bei jedem Firefox-Update wieder."
fi

# Die LEDs in F8 (Mikrofon stumm) und F5 (Ton stumm). Beide haengen am Codec
# ALC245, fuer den der Kernel keinen Mute-LED-Quirk kennt -- ohne dieses
# Programm bleiben sie immer dunkel. Es muss ein Binaerprogramm sein: das
# Codec-Geraet zu oeffnen verlangt CAP_SYS_RAWIO, und eine Capability kann kein
# Skript tragen. Rechte 750 root:audio, damit es nicht jeder Benutzer aufrufen
# kann.
schritt "LEDs in F5 und F8"
if command -v gcc >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
    if gcc -O2 -o "/tmp/tasten-led.$$" "$QUELLE/system/bin/tasten-led.c" 2>/dev/null; then
        sudo install -m 750 -o root -g audio "/tmp/tasten-led.$$" /usr/local/bin/tasten-led
        rm -f "/tmp/tasten-led.$$"
        sudo setcap cap_sys_rawio+ep /usr/local/bin/tasten-led
        gut "/usr/local/bin/tasten-led gebaut und eingerichtet"
    else
        rm -f "/tmp/tasten-led.$$"
        warn "tasten-led liess sich nicht uebersetzen -- die LEDs in F5/F8 bleiben dunkel."
    fi
else
    warn "gcc oder setcap fehlt -- die LEDs in F5/F8 bleiben dunkel."
fi

# --------------------------------------------------------- Benutzerdateien

sichern() {
    [ -e "$1" ] && [ ! -e "$1.vor-void-i3" ] && cp -a "$1" "$1.vor-void-i3" || true
}

schritt "Konfiguration im Benutzerverzeichnis"
# Erst sichern, was schon da ist -- dann kopieren. cp -r auf den Punkt kopiert
# auch die versteckten Dateien; "$QUELLE/config/." statt "$QUELLE/config/*".
for f in .xinitrc .bash_profile .bashrc .Xresources .gtkrc-2.0; do
    sichern "$HOME/$f"
done
sichern "$HOME/.config/i3/config"
cp -r "$QUELLE/config/." "$HOME/"

# Das Dashboard kommt aus workspaces-vitals -- dort liegt die einzige Kopie.
cp -r "$VITALS/." "$HOME/"
chmod 755 "$HOME"/.local/bin/* "$HOME/.config/i3/wallpaper.sh"
gut "Dateien abgelegt"

# ------------------------------------------------------------- Platzhalter

schritt "Platzhalter einsetzen"

# Die Pfade im zellij-Layout muessen absolut sein -- KDL kennt kein $HOME.
sed -i "s|/home/user|$HOME|g" \
    "$HOME/.config/zellij/layouts/dashboard.kdl" \
    "$HOME/.local/bin/vitals-sensoren"
info "Pfade im Dashboard auf $HOME gesetzt"

sed -i "s|@@WS2_NAME@@|$WS2_NAME|" "$HOME/.local/bin/i3-workspace-names"

if [ -n "$SSH_TARGET" ]; then
    ALIAS_NAME=$(printf '%s' "${SSH_TARGET#*@}" | tr -cd 'a-zA-Z0-9_')
    sed -i "s|@@SSH_TARGET@@|$SSH_TARGET|g; s|@@REMOTE_ALIAS_NAME@@|$ALIAS_NAME|g" \
        "$HOME/.local/bin/remote-shell"
    sed -i "s|@@REMOTE_ALIAS@@|alias $ALIAS_NAME='ssh $SSH_TARGET'|" "$HOME/.bashrc"
    sed -i "s|@@WS3_NAME@@|$WS3_NAME|" "$HOME/.local/bin/i3-workspace-names"
    gut "Arbeitsflaeche 3 verbindet nach $SSH_TARGET (Alias: $ALIAS_NAME)"
else
    # Kein SSH-Ziel: die beiden Zeilen fuer Arbeitsflaeche 3 stilllegen und
    # den festen Namen entfernen, damit sich die Flaeche wieder nach dem
    # laufenden Programm benennt.
    sed -i '/remote-term/s|^|# |' "$HOME/.config/i3/config"
    sed -i '/@@WS3_NAME@@/d' "$HOME/.local/bin/i3-workspace-names"
    sed -i "s|@@REMOTE_ALIAS@@||" "$HOME/.bashrc"
    rm -f "$HOME/.local/bin/remote-shell"
    warn "Arbeitsflaeche 3 bleibt frei -- kein SSH-Ziel angegeben"
fi

# ---------------------------------------------------------------- Wallpaper

schritt "Hintergrundbild"
mkdir -p "$HOME/Bilder/Wallpapers"
ANZAHL=$(find "$HOME/Bilder/Wallpapers" -maxdepth 1 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | wc -l)
if [ "$ANZAHL" -gt 0 ]; then
    info "$ANZAHL Bilder vorhanden"
elif command -v magick >/dev/null 2>&1; then
    magick -size 1920x1080 xc:'#1c1c1c' "$HOME/Bilder/Wallpapers/uni-dunkel.png"
    gut "einfarbiges Ersatzbild angelegt -- eigene Bilder einfach dazulegen"
else
    warn "Ordner angelegt, aber noch leer"
fi

# ------------------------------------------------------------------ Kontrolle

schritt "Kontrolle"
if i3 -C -c "$HOME/.config/i3/config" >/dev/null 2>&1; then
    gut "i3-Konfiguration ist syntaktisch in Ordnung"
else
    warn "i3 meldet etwas an der Konfiguration:"
    i3 -C -c "$HOME/.config/i3/config" 2>&1 | sed 's/^/      /'
fi
for s in "$HOME"/.local/bin/vitals "$HOME"/.local/bin/wallpaper "$HOME/.config/i3/wallpaper.sh"; do
    [ -f "$s" ] && { sh -n "$s" && info "ok: $(basename "$s")"; }
done

# -------------------------------------------------------------------- Schluss

cat <<ENDE

${FETT}Fertig.${AUS} Was jetzt noch von Hand kommt:

  1. Abmelden und neu anmelden -- die Gruppe input greift erst dann, sonst
     laufen die Touchpad-Gesten nicht.
  2. Auf tty1 anmelden: .bash_profile startet X und i3 von selbst.
     Auf anderen Konsolen passiert bewusst nichts.
  3. WLAN: sudo wpa_passphrase 'NETZ' 'PASSWORT' >> /etc/wpa_supplicant/wpa_supplicant.conf
     danach sudo sv restart wpa_supplicant
  4. Tailscale anmelden: sudo tailscale up
  5. Sensoren einlesen: sudo sensors-detect   -- danach im Dashboard pruefen,
     ob die Temperaturen erscheinen.
  6. Eigene Hintergrundbilder nach ~/Bilder/Wallpapers, dann \$mod+Shift+w.
  7. Firefox einrichten (Profil, Erweiterungen) -- das kann kein Skript.

Tastenbelegung in Kuerze:  Strg+Alt+T Terminal, \$mod+space rofi,
\$mod+f Firefox, \$mod+e Dateien, Strg+q Fenster schliessen,
\$mod+1..4 Arbeitsflaechen.  Alles Weitere in ~/.config/i3/config.

Ueberschriebene Dateien liegen als <datei>.vor-void-i3 daneben.
ENDE
