#!/bin/sh
# void-i3/setup.sh -- richtet nach einer frischen Void-Installation die
# komplette Arbeitsumgebung ein: Xorg, i3, Terminal, Schriften, Cursor,
# Touchpad, Tastatur und btop auf Arbeitsflaeche 4 (Vitals).
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
#   * Chrome einrichten (Google-Konto anmelden, Erweiterungen)
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

# ------------------------------------------------------------------- Fragen

schritt "Ein paar Angaben"

# Die Antworten landen spaeter per sed in anderen Dateien: die Namen in der
# Python-Datei i3-workspace-names (zwischen Anfuehrungszeichen), das SSH-Ziel
# in einem alias in .bashrc (zwischen Hochkommata). Ein | & \ " oder ' darin
# zerlegt den sed-Ausdruck oder die Zieldatei -- und das Fehlerbild haette
# mit der Ursache nichts mehr zu tun (alle Arbeitsflaechen hiessen dann nur
# noch "1" bis "4"). Darum werden genau diese Zeichen entfernt; Umlaute und
# alles andere bleiben.
name_saeubern() { printf '%s' "$1" | tr -d '|&\\"'"'"; }
# Ein SSH-Ziel besteht aus benutzer@rechner, Rechner auch als IP oder mit
# Port-Doppelpunkt -- mehr Zeichen braucht es nicht.
ziel_saeubern() { printf '%s' "$1" | tr -cd 'A-Za-z0-9@._:-'; }

info "Arbeitsflaeche 2 traegt ein lokales Terminal, Arbeitsflaeche 3 eine"
info "SSH-Sitzung. Die Namen stehen spaeter in der Leiste."
printf '    Name fuer Arbeitsflaeche 2 [lokal]: '
read -r WS2_NAME || WS2_NAME=""
WS2_NAME=$(name_saeubern "$WS2_NAME")
[ -n "$WS2_NAME" ] || WS2_NAME="lokal"

printf '    SSH-Ziel fuer Arbeitsflaeche 3, z.B. benutzer@rechner\n'
printf '    (leer lassen, dann bleibt Arbeitsflaeche 3 frei): '
read -r SSH_TARGET || SSH_TARGET=""
SSH_TARGET=$(ziel_saeubern "$SSH_TARGET")

WS3_NAME=""
if [ -n "$SSH_TARGET" ]; then
    # Vorschlag: der Rechnername aus benutzer@rechner
    VORGABE=${SSH_TARGET#*@}
    printf '    Name fuer Arbeitsflaeche 3 [%s]: ' "$VORGABE"
    read -r WS3_NAME || WS3_NAME=""
    WS3_NAME=$(name_saeubern "$WS3_NAME")
    [ -n "$WS3_NAME" ] || WS3_NAME="$VORGABE"
fi

# ------------------------------------------------------------------- Pakete

schritt "Pakete"

# Grundlage: Xorg ohne Display-Manager, i3, Terminal, Browser.
PAKETE="xorg-minimal xorg-fonts xrdb setxkbmap xinput xdg-utils
        mesa-dri xf86-video-intel
        i3 i3status i3lock rofi dmenu picom feh clipmenu
        alacritty xterm pcmanfm flatpak
        xdg-desktop-portal xdg-desktop-portal-gtk
        libinput-gestures python3-i3ipc
        nerd-fonts-symbols-ttf noto-fonts-cjk-sans papirus-icon-theme"

# Benachrichtigungen: dunst ist der D-Bus-Dienst auf
# org.freedesktop.Notifications. Fehlt er, verschwinden Meldungen von
# Chrome & Co. spurlos -- es gibt dann schlicht niemanden, der sie anzeigt.
# libnotify liefert notify-send, brightnessctl und playerctl bedienen die
# F-Tasten, acpi liest Akku und Temperatur. acpid ist der Daemon dazu und
# wird hier nur fuer den Deckelschalter gebraucht.
PAKETE="$PAKETE dunst libnotify brightnessctl playerctl acpi acpid"

# Ton. PipeWire ersetzt hier PulseAudio und JACK; wireplumber ist die
# Geraeteverwaltung, ohne die PipeWire zwar laeuft, aber nichts verschaltet.
# alsa-pipewire legt das ALSA-Plugin dazu, damit auch Programme Ton machen,
# die stur ueber ALSA gehen. alsa-utils bringt amixer und den alsa-Dienst,
# rtkit gibt den Audio-Threads Echtzeitprioritaet (sonst knackst es unter
# Last).
#
# dumb_runtime_dir ist KEIN Teil von base-system, obwohl /etc/pam.d/system-login
# (aus pam-base) das Modul pam_dumb_runtime_dir.so schon eintraegt -- mit
# fuehrendem "-", also stillschweigend uebersprungen, solange das Paket fehlt.
# Ohne das Paket wird beim Login kein /run/user/<uid> angelegt und kein
# XDG_RUNTIME_DIR gesetzt; PipeWire startet dann gar nicht erst, und zwar ohne
# jede Fehlermeldung in der Sitzung. Das /run/user aus rc.local ist nur das
# Elternverzeichnis dafuer.
PAKETE="$PAKETE pipewire wireplumber alsa-pipewire alsa-utils rtkit dumb_runtime_dir"

# Bluetooth. bluez bringt bluetoothd und bluetoothctl mit; bedient wird beides
# ueber den Bluetooth-Block in der Leiste (~/.local/bin/bluetooth). Ein
# Tray-Applet wie blueman braucht es dafuer nicht.
PAKETE="$PAKETE bluez"

# btop fuellt Arbeitsflaeche 4 (Vitals) allein und ueber die volle Flaeche.
# Hier standen frueher zellij, glances, bandwhich und eine selbstgezeichnete
# Uhr als geteiltes Dashboard -- das ist raus, btop zeigt dieselben Werte
# ohne festes Layout, das an Schriftgroesse und Barhoehe haengt.
# lm_sensors bleibt: btop liest die Temperaturen darueber.
PAKETE="$PAKETE btop lm_sensors"

# Fuer die LEDs in F5 und F8: gcc uebersetzt das winzige Hilfsprogramm
# tasten-led, setcap (aus libcap-progs) gibt ihm die noetige Capability.
# Begruendung im Kopf von system/bin/tasten-led.c.
PAKETE="$PAKETE gcc libcap-progs"

# Dateien und Text: PCManFM ist der Dateimanager (weiter oben in der Liste),
# nano der Editor im Terminal fuer git commit und "eine Zeile aendern" --
# das eigentliche Programmieren laeuft in VS Code, weiter unten als Flatpak.
# glow zeigt Markdown gerendert, bat ist cat mit Syntaxhervorhebung, nsxiv
# oeffnet Bilder in einem richtigen Fenster statt als ASCII im Terminal.
# Kitty wurde bewusst nicht genommen: das einzige Argument waere die
# Bildvorschau im Terminal gewesen, und dafuer ist nsxiv ohnehin besser.
PAKETE="$PAKETE nano glow bat nsxiv desktop-file-utils"

# Papierkorb. libfm loescht schon von sich aus nach ~/.local/share/Trash
# (use_trash=1), aber oeffnen laesst sich der Papierkorb ohne gvfs nicht:
# trash:/// beantwortet GIO dann mit "Operation not supported", der Eintrag in
# der Seitenleiste bleibt tot, und Wiederherstellen oder Leeren gibt es gar
# nicht. gvfs bringt dafuer gvfsd-trash mit. Es zieht udisks2 nach, womit
# nebenbei das Einhaengen von USB-Sticks funktioniert, das pcmanfm.conf mit
# mount_removable=1 ohnehin schon verlangt. Beide starten per D-Bus-Aktivierung
# und brauchen keinen eigenen Dienst unter /var/service.
PAKETE="$PAKETE gvfs"

# Werkzeuge, die im Alltag dazugehoeren.
PAKETE="$PAKETE git github-cli rclone xclip ImageMagick nodejs tailscale
        fonttools"

info "xbps wird aufgefrischt und die Paketliste installiert."
sudo xbps-install -Syu || true          # erster Lauf aktualisiert ggf. nur xbps
# shellcheck disable=SC2086
sudo xbps-install -Sy $PAKETE
gut "Pakete installiert"

# ------------------------------------------------------------------ Browser

schritt "Browser"

# Chrome und Brave liegen nicht in den Void-Repos. Der Weg ueber xbps-src
# (restricted-Template) baut zwar ein echtes Paket, aber jedes
# Sicherheitsupdate muesste man von Hand nachbauen -- bei einem Browser alle
# paar Wochen. Flatpak aktualisiert stattdessen mit "flatpak update" mit.
#
# Chrome ist der Standardbrowser (Sync mit dem Google-Konto), Brave steht als
# Zweitbrowser mit eingebautem Werbeblocker daneben.
#
# Hardware-Videodekodierung: Flatpak zieht org.freedesktop.Platform.VAAPI.Intel
# automatisch mit (die Runtime markiert sie mit "download-if = have-intel-gpu").
# Der iHD-Treiber liegt dann IM Sandkasten -- intel-media-driver muss dafuer
# NICHT auf dem Host installiert sein. Kontrolle spaeter in chrome://gpu unter
# "Video Decode".
sudo flatpak remote-add --if-not-exists flathub \
     https://dl.flathub.org/repo/flathub.flatpakrepo
# VS Code kommt aus demselben Grund als Flatpak: die Version im Void-Repo
# ist ein aelterer Code-OSS-Build ohne den Microsoft-Marktplatz. Der Flatpak
# hat filesystems=host, kommt also ohne Zusatzrechte an alle Dateien.
sudo flatpak install -y flathub com.google.Chrome com.brave.Browser \
     com.visualstudio.code
gut "Chrome, Brave und VS Code installiert"

# VS Code meldet sonst dauerhaft "Update verfuegbar" und schickt beim Klick
# darauf nur den Browser auf die Download-Seite: der Flatpak kann sich nicht
# selbst aktualisieren, und Flathub hinkt der Version von Microsoft ohnehin
# hinterher (Stand 21.08.2026: Flathub 1.130, Microsoft bietet 1.134 an).
# Der Hinweis kaeme also immer wieder und liesse sich nie erledigen.
# Aktualisiert wird hier ueber "flatpak update".
#
# Angelegt wird die Datei hier gleich mit: das Verzeichnis entsteht sonst erst
# beim ersten Start von VS Code, und bis dahin hat es schon einmal gemeldet.
VSCODE_USER="$HOME/.var/app/com.visualstudio.code/config/Code/User"
mkdir -p "$VSCODE_USER"
if [ -s "$VSCODE_USER/settings.json" ]; then
    # Schon eigene Einstellungen da: nur die beiden Schluessel dazulegen,
    # nicht die Datei ersetzen. Schlaegt fehl, wenn dort Kommentare stehen --
    # VS Code erlaubt sie, json.load nicht. Dann bleibt es beim Hinweis.
    [ -e "$VSCODE_USER/settings.json.vor-void-i3" ] \
        || cp -a "$VSCODE_USER/settings.json" "$VSCODE_USER/settings.json.vor-void-i3"
    if python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["update.mode"] = "none"
d["update.showReleaseNotes"] = False
open(p, "w").write(json.dumps(d, indent=4) + "\n")
' "$VSCODE_USER/settings.json" 2>/dev/null; then
        gut "Update-Meldung in VS Code abgeschaltet"
    else
        warn "settings.json von VS Code nicht lesbar -- \"update.mode\": \"none\" bitte selbst eintragen"
    fi
else
    cat > "$VSCODE_USER/settings.json" <<'JSON'
{
    "update.mode": "none",
    "update.showReleaseNotes": false
}
JSON
    gut "Update-Meldung in VS Code abgeschaltet"
fi

# Mauszeiger in Flatpak-Fenstern. Drei Haelften, alle noetig:
#
# 1. Flatpak reicht XCURSOR_THEME und XCURSOR_SIZE NICHT in den Sandkasten
#    durch, auch wenn beide in der Sitzung gesetzt sind. Ohne den Override
#    kennt die Anwendung den Namen des Themas gar nicht.
# 2. Das Thema muss an einem Ort liegen, den der Sandkasten sieht.
#    /usr/share/icons ist dort als /run/host/share/icons eingeblendet,
#    ~/.local/share/icons als /run/host/user-share/icons -- ~/.icons dagegen
#    gar nicht. Das Thema liegt deshalb systemweit, siehe Cursor-Abschnitt.
# 3. XCURSOR_PATH wird ausdruecklich auf diese beiden Host-Pfade gesetzt.
#    Ohne die Variable sucht libXcursor im Sandkasten unter /usr/share/icons
#    -- das ist dort die Runtime, nicht das Wirtssystem.
#
# Fehlt das Thema, faellt Chromium/Electron auf eingebaute Zeiger zurueck:
# die Groesse stimmt dann, das Aussehen nicht. Der Override gilt global fuer
# alle Flatpaks des Nutzers, nicht nur fuer eine App.
flatpak override --user \
    --env=XCURSOR_THEME=Colloid-dark-cursors \
    --env=XCURSOR_SIZE=36 \
    --env=XCURSOR_PATH=/run/host/user-share/icons:/run/host/share/icons
gut "Mauszeiger fuer Flatpaks gesetzt"

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

# ----------------------------------------------------------------------- Ton

schritt "Ton"
# PipeWire liest nur seine eigene Konfiguration. WirePlumber und die
# PulseAudio-Schnittstelle kommen erst dazu, wenn ihre Beispieldateien in
# /etc/pipewire/pipewire.conf.d/ verlinkt sind -- ohne sie laeuft zwar ein
# pipewire, es verschaltet aber nichts und kein Programm findet ein Ausgabe-
# geraet. Symlinks statt Kopien, damit Updates der Beispiele durchschlagen.
sudo mkdir -p /etc/pipewire/pipewire.conf.d
for paar in "wireplumber/10-wireplumber.conf" "pipewire/20-pipewire-pulse.conf"; do
    ziel="/usr/share/examples/$paar"
    name=$(basename "$paar")
    if [ ! -e "$ziel" ]; then
        warn "$ziel fehlt -- Paket nicht installiert?"
    elif [ -e "/etc/pipewire/pipewire.conf.d/$name" ]; then
        info "$name ist bereits verlinkt"
    else
        sudo ln -s "$ziel" "/etc/pipewire/pipewire.conf.d/$name"
        gut "$name verlinkt"
    fi
done

# ------------------------------------------------------------------ Dienste

schritt "Dienste"
# dbus muss mit: bluetoothd bricht ohne ihn ab ("sv check dbus" in seinem
# run-Skript), und die Meldungen von dunst laufen ebenfalls darueber.
# alsa stellt die Mischerpegel beim Booten wieder her, rtkit vergibt die
# Echtzeitprioritaet fuer PipeWire.
# acpid horcht auf den Deckelschalter (sperren + Bereitschaft, siehe
# etc/acpi/deckel.sh). Seine Sammelregel "anything" wird oben durch die
# abgeschaltete Fassung ersetzt -- sonst faehrt die Einschalttaste den
# Rechner ohne Rueckfrage herunter.
for d in dbus dhcpcd wpa_supplicant tailscaled bluetoothd alsa rtkit acpid; do
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

# Colloid, weisse Variante. Im Quellbaum heisst sie "dist-dark" und traegt
# den Namen Colloid-dark-cursors -- "dark" meint die dunkle Oberflaeche, fuer
# die der Zeiger gedacht ist, der Zeiger selbst ist weiss mit dunklem Rand.
#
# Das Thema liegt systemweit unter /usr/share/icons und nicht im Home:
# * jede native Anwendung findet es dort (Suchreihenfolge von libXcursor:
#   ~/.local/share/icons:~/.icons:/usr/share/icons:/usr/share/pixmaps),
# * Flatpaks sehen es als /run/host/share/icons (siehe Override weiter oben),
# * und Programme ohne eigene Cursor-Einstellung landen ueber
#   /usr/share/icons/default/index.theme ebenfalls dort.
# ~/.icons ist als Ablage in beiden Faellen falsch: nativ sichtbar, im
# Sandkasten nicht.
#
# Groesse 36 ist eine der vier im Theme gebauten Groessen (24/30/36/48, die
# zugehoerigen Pixmaps sind 32/40/48/64 px). Nur bei diesen Werten wird nicht
# skaliert. 36 entspricht optisch etwa Nordzy in Groesse 48.

schritt "Mauszeiger Colloid (weiss)"
if [ -d /usr/share/icons/Colloid-dark-cursors ]; then
    info "liegt schon unter /usr/share/icons/Colloid-dark-cursors"
else
    TMPC=$(mktemp -d)
    # Nur den Cursor-Ordner holen -- der ganze Baum des Icon-Themes waere
    # rund 76 MB, die fertigen Zeiger sind 3 MB.
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/vinceliuice/Colloid-icon-theme.git "$TMPC/colloid" \
        || fehler "Colloid-icon-theme konnte nicht geladen werden."
    ( cd "$TMPC/colloid" && git sparse-checkout set cursors/dist-dark ) \
        || fehler "sparse-checkout fehlgeschlagen."
    sudo cp -r "$TMPC/colloid/cursors/dist-dark" /usr/share/icons/Colloid-dark-cursors
    sudo chown -R root:root /usr/share/icons/Colloid-dark-cursors
    sudo find /usr/share/icons/Colloid-dark-cursors -type d -exec chmod 755 {} +
    sudo find /usr/share/icons/Colloid-dark-cursors -type f -exec chmod 644 {} +
    rm -rf "$TMPC"
    gut "nach /usr/share/icons/Colloid-dark-cursors entpackt"
fi

# /usr/share/icons/default/index.theme ist der Weg, ueber den Programme OHNE
# eigene Cursor-Einstellung zum Thema kommen -- das X-Wurzelfenster, Toolkits
# ohne gesetztes XCURSOR_THEME, alles was ausserhalb der Sitzung startet.
# Ohne diese Datei bleibt es dort beim eingebauten X-Zeiger, egal wie gut der
# Rest konfiguriert ist. Dieselbe Datei nochmal im Home, damit der Nutzer sie
# ohne Root aendern kann.
schritt "Standard-Cursorthema"
for D in /usr/share/icons/default "$HOME/.local/share/icons/default"; do
    case "$D" in
        /usr/*) SUDO=sudo ;;
        *)      SUDO= ;;
    esac
    $SUDO mkdir -p "$D"
    printf '[Icon Theme]\nName=Default\nComment=Default cursor theme\nInherits=Colloid-dark-cursors\n' \
        | $SUDO tee "$D/index.theme" >/dev/null
done
gut "default/index.theme zeigt auf Colloid-dark-cursors"

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
           etc/profile.d/claude-code.sh \
           etc/acpi/deckel.sh \
           etc/acpi/events/deckel \
           etc/acpi/events/anything \
           etc/rc.local; do
    sudo mkdir -p "/$(dirname "$rel")"
    sichern_system "/$rel"
    sudo cp "$QUELLE/system/$rel" "/$rel"
    info "/$rel"
done
sudo fc-cache -f >/dev/null 2>&1 || true

# /etc/runit/2 ruft die Datei als "[ -x /etc/rc.local ] && /etc/rc.local" auf.
# Ohne das Ausfuehrrecht wird sie beim Booten stillschweigend uebersprungen --
# und cp behaelt die Rechte einer bereits vorhandenen Zieldatei bei.
sudo chmod 755 /etc/rc.local

# Dasselbe fuer den Deckel-Handler: acpid ruft ihn direkt auf.
sudo chmod 755 /etc/acpi/deckel.sh

# Der Dienst wurde weiter oben eingeschaltet, also bevor diese Regeln hier
# lagen -- acpid liest sie nur beim Start. Ohne den Neustart bliebe bis zum
# naechsten Booten die Sammelregel des Pakets aktiv.
if [ -e /var/service/acpid ]; then
    sudo sv restart acpid >/dev/null 2>&1 || true
    info "acpid mit der Deckel-Regel neu gestartet"
fi

# Die hwdb-Datei wirkt erst, wenn sie nach /etc/udev/hwdb.bin uebersetzt ist.
# Der trigger zieht sie fuer die bereits angemeldeten Tastaturen nach, sodass
# F8 und F12 ohne Neustart ankommen.
sudo udevadm hwdb --update
sudo udevadm trigger --sysname-match="event*"
info "Tastatur-Remap F8/F12 uebersetzt und aktiv"

# ------------------------------------------------- WLAN-Steuersocket fuer wheel

schritt "WLAN-Steuersocket fuer die Gruppe wheel"
# ~/.local/bin/netz sucht Netze und traegt Passwoerter ein -- beides laeuft
# ueber den Steuersocket von wpa_supplicant in /run/wpa_supplicant. Der gehoert
# von Haus aus root allein, und das run-Skript des Dienstes setzt das bei jedem
# Start eigens wieder durch. Ohne diese beiden Aenderungen kaeme das Menue nicht
# an den Socket und muesste ueber sudo gehen.
#
# Geoeffnet wird nur das Laufzeitverzeichnis. Die Konfigdatei mit den
# Passwoertern bleibt root allein -- hineingeschrieben wird sie von
# wpa_supplicant selbst (save_config), nicht vom Menue.
if [ -f /etc/sv/wpa_supplicant/run ]; then
    if grep -q 'chown -R root:root /run/wpa_supplicant' /etc/sv/wpa_supplicant/run; then
        sichern_system /etc/sv/wpa_supplicant/run
        sudo sed -i \
            -e 's|install -m 700 -g root -o root -d /run/wpa_supplicant|install -m 750 -g wheel -o root -d /run/wpa_supplicant|' \
            -e 's|chown -R root:root /run/wpa_supplicant|chown -R root:wheel /run/wpa_supplicant\nchmod 750 /run/wpa_supplicant|' \
            /etc/sv/wpa_supplicant/run
        gut "run-Skript chownt nicht mehr auf root:root"
    else
        info "run-Skript ist schon offen"
    fi
fi

# Dasselbe in der Konfigdatei: ohne GROUP legt wpa_supplicant den Socket beim
# naechsten Start wieder root:root an. Betrifft jede Konfig in dem Ordner,
# weil das Dienst-conf auf eine davon zeigt.
for c in /etc/wpa_supplicant/wpa_supplicant*.conf; do
    [ -f "$c" ] || continue
    if sudo grep -q '^ctrl_interface=/run/wpa_supplicant$' "$c"; then
        sudo sed -i 's|^ctrl_interface=/run/wpa_supplicant$|ctrl_interface=DIR=/run/wpa_supplicant GROUP=wheel|' "$c"
        gut "$(basename "$c"): GROUP=wheel eingetragen"
    fi
done

# Und einmal sofort, damit es ohne Neustart des Dienstes gilt.
if [ -d /run/wpa_supplicant ]; then
    sudo chown -R root:wheel /run/wpa_supplicant
    sudo chmod 750 /run/wpa_supplicant
    info "/run/wpa_supplicant gehoert jetzt der Gruppe wheel"
fi

# sudoers braucht Modus 440 und muss fehlerfrei sein -- eine kaputte Datei
# dort sperrt sudo komplett aus. Also erst pruefen, dann mit install ablegen
# (cp wuerde die Rechte des Repos mitnehmen). Jede Datei einzeln, damit ein
# Fehler in der einen die andere nicht mitreisst.
for schnipsel in "$QUELLE"/system/etc/sudoers.d/*; do
    name=$(basename "$schnipsel")
    if sudo visudo -c -f "$schnipsel" >/dev/null 2>&1; then
        sudo install -m 440 -o root -g root "$schnipsel" "/etc/sudoers.d/$name"
        info "/etc/sudoers.d/$name"
    else
        warn "sudoers-Schnipsel $name fehlerhaft -- uebersprungen."
        case "$name" in
            10-sitzung)
                warn "Das Sitzungsmenue kann dann nur sperren und abmelden." ;;
            20-zeitfenster)
                warn "sudo merkt sich die Anmeldung dann wieder fuenf Minuten." ;;
        esac
    fi
done

gut "abgelegt, Schriftcache erneuert"

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

# ------------------------------------------------------ Fingerabdrucksensor
# Der Synaptics 06cb:00e7 braucht einen selbst gebauten libfprint-Treiber,
# siehe fingerabdruck/README.md. Das dauert ein paar Minuten und nimmt die
# Void-Pakete fprintd/libfprint raus -- darum wird gefragt statt gemacht.
schritt "Fingerabdrucksensor"
sensor_00e7=0
for d in /sys/bus/usb/devices/*; do
    if [ "$(cat "$d/idVendor" 2>/dev/null)" = 06cb ] &&
       [ "$(cat "$d/idProduct" 2>/dev/null)" = 00e7 ]; then
        sensor_00e7=1
    fi
done
if [ "$sensor_00e7" -eq 1 ]; then
    printf '    Synaptics 06cb:00e7 gefunden. Treiber jetzt bauen (libfprint + fprintd,\n'
    printf '    einige Minuten)? [j/N] '
    read -r antwort
    case "$antwort" in
        j|J|ja|Ja)
            if sh "$QUELLE/fingerabdruck/einrichten.sh"; then
                gut "Fingerabdrucksensor eingerichtet -- Finger anlernen steht unten"
            else
                warn "einrichten.sh ist abgebrochen -- spaeter von Hand: sh fingerabdruck/einrichten.sh"
            fi
            ;;
        *)
            info "uebersprungen -- spaeter: sh fingerabdruck/einrichten.sh"
            ;;
    esac
else
    info "kein Synaptics 06cb:00e7 am USB -- uebersprungen"
fi

# --------------------------------------------------------- Benutzerdateien

sichern() {   # sichern <repo-datei> <ziel>
    # Nur echte Abweichungen sichern: was schon identisch aus dem Repo kam,
    # braucht keine Kopie. Eine vorhandene .vor-void-i3 bleibt stehen -- sie
    # ist der Stand von VOR dem ersten Lauf, und genau den will man zurueck.
    [ -e "$2" ] || return 0
    cmp -s "$1" "$2" && return 0
    [ -e "$2.vor-void-i3" ] || cp -a "$2" "$2.vor-void-i3"
}

schritt "Konfiguration im Benutzerverzeichnis"
# Erst sichern, was schon da ist -- und zwar jede Datei, die gleich aus dem
# Repo kommt, nicht nur eine Handvoll Dotfiles: auch alacritty.toml, dunstrc,
# die Skripte in ~/.local/bin und die Dashboard-Konfiguration werden
# ueberschrieben. Dann kopieren; cp -r auf den Punkt kopiert auch die
# versteckten Dateien ("$QUELLE/config/." statt "$QUELLE/config/*").
# Die Dateiliste kommt per Here-Dokument statt per Pipe in die Schleife,
# sonst liefe sie in einer Subshell und der Zaehler bliebe bei 0.
GESICHERT=0
for quelle in "$QUELLE/config"; do
    while read -r f; do
        [ -n "$f" ] || continue
        sichern "$quelle/${f#./}" "$HOME/${f#./}"
        [ -e "$HOME/${f#./}.vor-void-i3" ] && GESICHERT=$((GESICHERT + 1))
    done <<LISTE
$(cd "$quelle" && find . -type f)
LISTE
done
[ "$GESICHERT" -eq 0 ] || info "$GESICHERT Dateien liegen als .vor-void-i3 gesichert"
cp -r "$QUELLE/config/." "$HOME/"
chmod 755 "$HOME"/.local/bin/* "$HOME/.config/i3/wallpaper.sh"
gut "Dateien abgelegt"

# Die Zuordnungen in mimeapps.list zeigen teils auf eigene .desktop-Eintraege
# in ~/.local/share/applications (glow fuer Markdown, bat zum Ansehen), teils
# auf VS Code und PCManFM. Ohne diesen Aufruf findet der Dateimanager die
# eigenen Eintraege erst nach dem naechsten Login.
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# ------------------------------------------------------------- Platzhalter

schritt "Platzhalter einsetzen"

sed -i "s|@@WS2_NAME@@|$WS2_NAME|" "$HOME/.local/bin/i3-workspace-names"

if [ -n "$SSH_TARGET" ]; then
    ALIAS_NAME=$(printf '%s' "${SSH_TARGET#*@}" | tr -cd 'a-zA-Z0-9_')
    # Bleibt nichts uebrig (Ziel war z.B. nur eine IP mit Punkten), braucht
    # der alias trotzdem einen Namen -- "alias ='ssh ...'" waere ein Fehler
    # bei jedem Shell-Start.
    [ -n "$ALIAS_NAME" ] || ALIAS_NAME=remote
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
for s in "$HOME"/.local/bin/vitals-btop "$HOME"/.local/bin/wallpaper "$HOME/.config/i3/wallpaper.sh"; do
    [ -f "$s" ] && { sh -n "$s" && info "ok: $(basename "$s")"; }
done

# -------------------------------------------------------------------- Schluss

cat <<ENDE

${FETT}Fertig.${AUS} Was jetzt noch von Hand kommt:

  1. Abmelden und neu anmelden -- die Gruppe input greift erst dann, sonst
     laufen die Touchpad-Gesten nicht. Ausserdem setzt /etc/profile.d
     erst bei der Anmeldung XDG_DATA_DIRS auf die Flatpak-Pfade; ohne das
     findet rofi Chrome und Brave nicht.
  2. Auf tty1 anmelden: .bash_profile startet X und i3 von selbst.
     Auf anderen Konsolen passiert bewusst nichts.
  3. WLAN: das erste Netz braucht noch die Konsole, weil ohne Verbindung
     auch keine Oberflaeche laeuft:
       wpa_passphrase 'NETZ' | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf >/dev/null
     (fragt das Passwort ab; ein ">>" hinter sudo scheitert, weil die Datei
     root gehoert und die Umleitung als Benutzer laeuft)
     danach sudo sv restart wpa_supplicant
     Jedes weitere Netz geht dann per Rechtsklick auf den WLAN-Block in der
     Leiste -- suchen, auswaehlen, Passwort eintippen.
  4. Tailscale anmelden: sudo tailscale up
     danach sudo tailscale set --operator=\$USER  -- sonst bleibt der
     Linksklick auf den Tailscale-Block in der Leiste wirkungslos, weil
     tailscaled Befehle nur von root oder dem eingetragenen Operator annimmt.
     Dasselbe gilt fuer den Tailscale-Eintrag im Netz-Menue.
     Nach einer Umbenennung des Benutzers muss das erneut gesetzt werden.
  5. Sensoren einlesen: sudo sensors-detect   -- danach im Dashboard pruefen,
     ob die Temperaturen erscheinen.
  6. Eigene Hintergrundbilder nach ~/Bilder/Wallpapers, dann \$mod+Shift+w.
  7. In Chrome mit dem Google-Konto anmelden -- das kann kein Skript.
     Lesezeichen, Passwoerter und Tabs kommen dann vom Handy mit.
  8. Falls der Fingerabdrucksensor eingerichtet wurde: fprintd-enroll
     (11 Beruehrungen), dann fprintd-verify als Gegenprobe.

Tastenbelegung in Kuerze:  Strg+Alt+T Terminal, \$mod+space rofi,
\$mod+e Dateien, Strg+q Fenster schliessen,
\$mod+v Verlauf der Zwischenablage,
\$mod+1..4 Arbeitsflaechen.  Alles Weitere in ~/.config/i3/config.

Ueberschriebene Dateien liegen als <datei>.vor-void-i3 daneben.
ENDE
