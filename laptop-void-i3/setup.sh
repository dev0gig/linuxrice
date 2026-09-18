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
# Ueberschreiben nach <datei>.vor-void-i3 gesichert. Die Antworten aus der
# Uebersicht merkt es sich in ~/.config/void-i3/antworten.conf und legt sie
# beim naechsten Lauf wieder vor; mit VOID_I3_UNATTENDED=1 laeuft es ohne
# jede Rueckfrage durch.
#
# Passt die Hardware nicht, bricht es ganz am Anfang ab -- bevor irgendein
# Paket installiert oder eine Datei angefasst wurde.
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

# ----------------------------------------------------------------- Hardware
# Vor der ersten Frage und lange vor dem ersten Paket: passt der Rechner
# ueberhaupt? Jeder Punkt hat einen von drei Ausgaengen:
#
#   Blocker   Abbruch mit Begruendung. Veraendert wurde dann noch nichts --
#             darum steht dieser Block ganz vorne und nicht mittendrin.
#   messbar   Der Wert wird ermittelt und weiter unten per sed in die
#             Vorlagen gesetzt (Akku, Netzteil, Temperatur, Grafiktreiber).
#   gebunden  Der Teil haengt an genau diesem Notebook und wird
#             uebersprungen; der Grund landet in $UEBERSPRUNGEN und steht in
#             der Uebersicht und am Ende noch einmal.
#
# Frueher stand all das fest in den Vorlagen -- BAT1, ACAD, hwmon4,
# xf86-video-intel -- und war auf jedem anderen Notebook stillschweigend
# falsch: die Leiste zeigte keine Temperatur, akku-wache warnte nie, und
# Xorg fiel wortlos auf modesetting zurueck.

schritt "Hardware"

# Uebersprungene Teile sammeln, je Zeile "Teil|Grund".
UEBERSPRUNGEN=""
ueberspringen() {
    UEBERSPRUNGEN="${UEBERSPRUNGEN}$1|$2
"
}

# --- Blocker ---------------------------------------------------------------

if [ "$(uname -m)" != x86_64 ]; then
    fehler "Dieser Rechner meldet sich als $(uname -m), die Einrichtung ist auf
       x86_64 zugeschnitten: die Paketliste, die beiden C-Programme in
       system/bin und die Zugriffe auf /proc/asound und /sys/class/dmi."
fi

AKKU=""
for b in /sys/class/power_supply/BAT*; do
    if [ -r "$b/capacity" ]; then AKKU=${b##*/}; break; fi
done
if [ -z "$AKKU" ]; then
    fehler "Kein Akku unter /sys/class/power_supply/BAT* gefunden.
       Das hier ist ein Notebook-Setup: Akkuwarnung, Ton beim An- und
       Abstecken, Deckelschalter, Helligkeitstasten, Touchpad-Gesten und der
       Akkublock in der Leiste haengen alle daran. Auf einem Rechner ohne
       Akku bliebe davon die Haelfte totes Gewicht -- darum hier der
       Abbruch statt einer halb eingerichteten Oberflaeche."
fi

# --- Messbares -------------------------------------------------------------

# Das Netzteil heisst je nach Geraet ACAD, AC oder AC0. Statt zu raten wird
# der Anschluss vom Typ "Mains" gesucht -- den gibt es genau einmal.
NETZ=""
for a in /sys/class/power_supply/*; do
    if [ -r "$a/type" ] && [ "$(cat "$a/type")" = Mains ]; then
        NETZ=${a##*/}; break
    fi
done
if [ -z "$NETZ" ]; then
    NETZ=AC
    ueberspringen "Ton beim An- und Abstecken" \
        "kein Anschluss vom Typ Mains unter /sys/class/power_supply -- akku-wache und netz-ton koennen das Netzteil nicht erkennen"
fi

# Die Package-Temperatur. Die hwmon-Nummer ist NICHT stabil: sie haengt an
# der Reihenfolge, in der die Module geladen wurden, und kann sich nach
# einem Kernel-Update verschieben. Darum wird nach dem Namen gesucht --
# einmal hier, und das Ergebnis dann fest in i3status/config geschrieben,
# weil i3status nur einen fertigen Pfad annimmt. Verschiebt sich die Nummer
# spaeter doch, hilft ein erneuter Lauf dieses Skripts.
TEMP=""
for h in /sys/class/hwmon/hwmon*; do
    if [ -r "$h/name" ] && [ -r "$h/temp1_input" ]; then
        case "$(cat "$h/name")" in
            coretemp|k10temp|zenpower) TEMP="$h/temp1_input"; break ;;
        esac
    fi
done
if [ -z "$TEMP" ]; then
    for h in /sys/class/hwmon/hwmon*; do
        if [ -r "$h/name" ] && [ -r "$h/temp1_input" ] &&
           [ "$(cat "$h/name")" = acpitz ]; then
            TEMP="$h/temp1_input"; break
        fi
    done
fi
if [ -z "$TEMP" ]; then
    ueberspringen "Temperatur in der Leiste" \
        "keine Quelle gefunden (weder coretemp/k10temp noch acpitz mit temp1_input) -- der Block entfaellt, sudo sensors-detect kann helfen"
fi

# Der Grafiktreiber. lspci waere bequemer, aber pciutils gehoert nicht zu
# base-system -- auf einem frischen Void ist es nicht da. Die Klasse 0x0300
# ist "VGA compatible controller", 0x0302 ist "3D controller".
GPU_PAKET=""
GPU_TEXT="unbekannt -- modesetting aus xorg-server"
for d in /sys/bus/pci/devices/*; do
    if [ -r "$d/class" ] && [ -r "$d/vendor" ]; then
        case "$(cat "$d/class")" in 0x0300*|0x0302*) ;; *) continue ;; esac
        case "$(cat "$d/vendor")" in
            0x8086) GPU_PAKET="xf86-video-intel"
                    GPU_TEXT="Intel -- xf86-video-intel" ;;
            0x1002) GPU_PAKET="xf86-video-amdgpu"
                    GPU_TEXT="AMD -- xf86-video-amdgpu" ;;
            0x10de) GPU_TEXT="NVIDIA -- modesetting aus xorg-server (der nonfree-Treiber bleibt deine Sache)" ;;
        esac
        break
    fi
done

# --- Geraetegebundenes -----------------------------------------------------

# Die LEDs in F5 und F8. tasten-led schreibt GPIO-Pin 2 und COEF-Register
# 0x0b des ALC245 -- Werte, die auf genau diesem Notebook ausprobiert wurden.
# Das Programm selbst prueft nur die Codec-ID, nicht das Subsystem; auf einem
# fremden Geraet mit demselben Codec schriebe es dieselben Register blind.
# Darum wird hier das HP-Subsystem geprueft und nicht dort.
LED_OK=0
LED_GRUND=""
CODEC_TEXT="kein Realtek ALC245 gefunden"
for c in /proc/asound/card*/codec#*; do
    if [ -r "$c" ] && grep -q 'Codec: Realtek ALC245' "$c"; then
        sub=$(sed -n 's/^Subsystem Id: *//p' "$c" | head -1)
        if [ "$sub" = 0x103c8824 ]; then
            LED_OK=1
            CODEC_TEXT="ALC245, HP-Subsystem $sub"
        else
            CODEC_TEXT="ALC245, aber Subsystem ${sub:-unbekannt}"
            LED_GRUND="Subsystem ${sub:-unbekannt} statt 0x103c8824 (HP ENVY x360 13-bd0xxx) -- tasten-led schreibt feste GPIO- und COEF-Register, die auf einem anderen Geraet mit demselben Codec ganz anders belegt sein koennen"
        fi
        break
    fi
done
if [ "$LED_OK" -eq 0 ]; then
    [ -n "$LED_GRUND" ] || LED_GRUND="kein Realtek ALC245 am HDA-Bus"
    ueberspringen "LEDs in F5 und F8" "$LED_GRUND"
fi

# Die hwdb-Regel und das F12-Zahnrad greifen per DMI-Match nur auf diesem
# Modell. Abgelegt werden sie trotzdem -- sie sind woanders wirkungslos,
# nicht schaedlich -- aber gesagt werden soll es.
DMI=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unbekannt)
case "$DMI" in
    "HP ENVY x360 Convertible 13-bd0xxx") ;;
    *) ueberspringen "F-Tasten-Zuordnung und F12-Zahnrad" \
           "die hwdb-Regel passt per DMI-Match nur auf den HP ENVY x360 13-bd0xxx; sie wird abgelegt, bleibt hier aber wirkungslos -- das Sitzungsmenue erreichst du weiter ueber \$mod+Shift+e" ;;
esac

# Der Fingerabdrucksensor. Nur erkennen, gefragt wird weiter unten.
SENSOR_00E7=0
for d in /sys/bus/usb/devices/*; do
    if [ "$(cat "$d/idVendor" 2>/dev/null || echo)" = 06cb ] &&
       [ "$(cat "$d/idProduct" 2>/dev/null || echo)" = 00e7 ]; then
        SENSOR_00E7=1
    fi
done

gut "geprueft -- $DMI"

# ------------------------------------------------------------------- Fragen
# Alle Fragen stehen hier vorne. Frueher kam die nach dem Fingerabdruck erst
# nach der Paketinstallation, also einige Minuten spaeter -- bis dahin
# konnte niemand weggehen.
#
# Die Antworten landen in ~/.config/void-i3/antworten.conf und werden beim
# naechsten Lauf wieder vorgelegt: das Skript ist mehrfach ausfuehrbar, und
# ohne diese Datei tippt man jedes Mal dasselbe neu. Ueberschreiben laesst
# sich alles per Umgebungsvariable (VOID_I3_WS2, VOID_I3_SSH, VOID_I3_WS3,
# VOID_I3_FINGER), und mit VOID_I3_UNATTENDED=1 laeuft es ohne Rueckfrage
# durch.

schritt "Ein paar Angaben"

# Die Antworten landen spaeter per sed in anderen Dateien: die Namen in der
# Python-Datei i3-workspace-names (zwischen Anfuehrungszeichen), das SSH-Ziel
# in einem alias in .bashrc (zwischen Hochkommata). Ein | & \ " oder ' darin
# zerlegt den sed-Ausdruck oder die Zieldatei -- und das Fehlerbild haette
# mit der Ursache nichts mehr zu tun (alle Arbeitsflaechen hiessen dann nur
# noch "1" bis "4"). Darum werden genau diese Zeichen entfernt; Umlaute und
# alles andere bleiben. Dieselbe Saeuberung schuetzt nebenbei die
# Antwortdatei, die weiter unten mit Hochkommata geschrieben wird.
name_saeubern() { printf '%s' "$1" | tr -d '|&\\"'"'"; }
# Ein SSH-Ziel besteht aus benutzer@rechner, Rechner auch als IP oder mit
# Port-Doppelpunkt -- mehr Zeichen braucht es nicht.
ziel_saeubern() { printf '%s' "$1" | tr -cd 'A-Za-z0-9@._:-'; }

ANTWORTEN="${XDG_CONFIG_HOME:-$HOME/.config}/void-i3/antworten.conf"
# Der Ordner void-i3 liegt bewusst nicht in config/ im Repo -- sonst wuerde
# der Kopierschritt weiter unten die eigenen Antworten ueberbuegeln.
if [ -r "$ANTWORTEN" ]; then
    # shellcheck disable=SC1090  # Pfad steht erst zur Laufzeit fest
    . "$ANTWORTEN"
    info "fruehere Antworten aus $ANTWORTEN"
fi

# Reihenfolge: Umgebungsvariable schlaegt Antwortdatei schlaegt Vorgabe.
WS2_NAME=$(name_saeubern "${VOID_I3_WS2:-${WS2_NAME:-lokal}}")
SSH_TARGET=$(ziel_saeubern "${VOID_I3_SSH:-${SSH_TARGET:-}}")
WS3_NAME=$(name_saeubern "${VOID_I3_WS3:-${WS3_NAME:-}}")
FINGER=${VOID_I3_FINGER:-${FINGER:-n}}
case "$FINGER" in j|J|ja|Ja) FINGER=j ;; *) FINGER=n ;; esac
if [ -n "$SSH_TARGET" ] && [ -z "$WS3_NAME" ]; then WS3_NAME=${SSH_TARGET#*@}; fi
if [ "$SENSOR_00E7" -eq 0 ]; then FINGER=n; fi

frage_ws2() {
    printf '    Arbeitsflaeche 2 traegt ein lokales Terminal. Der Name steht\n'
    printf '    spaeter in der Leiste.\n'
    printf '    Name fuer Arbeitsflaeche 2 [%s]: ' "$WS2_NAME"
    read -r a || a=""
    a=$(name_saeubern "$a")
    if [ -n "$a" ]; then WS2_NAME="$a"; fi
}

frage_ssh() {
    printf '    Arbeitsflaeche 3 traegt eine SSH-Sitzung, z.B. benutzer@rechner.\n'
    printf '    Ein einzelner Bindestrich loescht das Ziel, dann bleibt die\n'
    printf '    Flaeche frei.\n'
    printf '    SSH-Ziel [%s]: ' "${SSH_TARGET:-keins}"
    read -r a || a=""
    case "$a" in
        "")  ;;
        -)   SSH_TARGET=""; WS3_NAME="" ;;
        *)   SSH_TARGET=$(ziel_saeubern "$a"); WS3_NAME="" ;;
    esac
    if [ -n "$SSH_TARGET" ]; then
        vorgabe=${WS3_NAME:-${SSH_TARGET#*@}}
        printf '    Name fuer Arbeitsflaeche 3 [%s]: ' "$vorgabe"
        read -r a || a=""
        a=$(name_saeubern "$a")
        WS3_NAME=${a:-$vorgabe}
    fi
}

frage_finger() {
    if [ "$SENSOR_00E7" -eq 0 ]; then
        warn "Kein Synaptics 06cb:00e7 am USB -- hier gibt es nichts zu waehlen."
        return 0
    fi
    printf '    Der Sensor braucht einen selbst gebauten libfprint-Treiber; das\n'
    printf '    dauert einige Minuten und nimmt die Void-Pakete fprintd und\n'
    printf '    libfprint heraus. Bei Dual-Boot vorher fingerabdruck/README.md\n'
    printf '    lesen -- die Kopplung verdraengt Windows Hello.\n'
    printf '    Treiber jetzt bauen? [j/N] '
    read -r a || a=""
    case "$a" in j|J|ja|Ja) FINGER=j ;; *) FINGER=n ;; esac
}

uebersicht() {
    printf '\n%s  So wird eingerichtet:%s\n\n' "$FETT" "$AUS"
    printf '    1  Arbeitsflaeche 2   %s\n' "$WS2_NAME"
    if [ -n "$SSH_TARGET" ]; then
        printf '    2  Arbeitsflaeche 3   %s  (Name: %s)\n' "$SSH_TARGET" "$WS3_NAME"
    else
        printf '    2  Arbeitsflaeche 3   bleibt frei\n'
    fi
    if [ "$SENSOR_00E7" -eq 0 ]; then
        printf '    3  Fingerabdruck      kein Sensor 06cb:00e7 gefunden\n'
    elif [ "$FINGER" = j ]; then
        printf '    3  Fingerabdruck      06cb:00e7 -- Treiber wird gebaut\n'
    else
        printf '    3  Fingerabdruck      06cb:00e7 -- uebersprungen\n'
    fi
    printf '\n       Gemessen:\n'
    printf '       Geraet           %s\n' "$DMI"
    printf '       Akku / Netzteil  %s / %s\n' "$AKKU" "$NETZ"
    printf '       Temperatur       %s\n' "${TEMP:-keine Quelle -- Block entfaellt}"
    printf '       Grafik           %s\n' "$GPU_TEXT"
    printf '       Audio-Codec      %s\n' "$CODEC_TEXT"
    if [ -n "$UEBERSPRUNGEN" ]; then
        printf '\n%s       Wird uebersprungen:%s\n' "$GELB" "$AUS"
        printf '%s' "$UEBERSPRUNGEN" | while IFS='|' read -r teil grund; do
            if [ -n "$teil" ]; then
                printf '       %s%s%s\n' "$GELB" "$teil" "$AUS"
                printf '%s\n' "$grund" | fold -s -w 60 | sed 's/^/         /'
            fi
        done
    fi
    printf '\n'
}

antworten_sichern() {
    mkdir -p "$(dirname "$ANTWORTEN")"
    cat > "$ANTWORTEN" <<ENDE
# Von void-i3/setup.sh angelegt und beim naechsten Lauf wieder vorgelegt.
# Loeschen, um alles neu gefragt zu bekommen.
WS2_NAME='$WS2_NAME'
SSH_TARGET='$SSH_TARGET'
WS3_NAME='$WS3_NAME'
FINGER='$FINGER'
ENDE
}

# Ohne Terminal an der Eingabe -- etwa aus einem anderen Skript heraus --
# gaebe read sofort auf und die Schleife liefe leer durch. Dann lieber gleich
# ohne Rueckfragen.
UNATTENDED=${VOID_I3_UNATTENDED:-0}
[ -t 0 ] || UNATTENDED=1

if [ "$UNATTENDED" = 1 ]; then
    uebersicht
    info "ohne Rueckfrage (VOID_I3_UNATTENDED oder keine Eingabe am Terminal)"
else
    while :; do
        uebersicht
        printf '    [Enter] starten   [1-3] aendern   [q] abbrechen: '
        read -r wahl || wahl=""
        case "$wahl" in
            "")   break ;;
            1)    frage_ws2 ;;
            2)    frage_ssh ;;
            3)    frage_finger ;;
            q|Q)  printf '\n    Abgebrochen -- veraendert wurde nichts.\n'; exit 0 ;;
            *)    warn "Bitte Enter, 1, 2, 3 oder q." ;;
        esac
    done
fi

if [ "$SENSOR_00E7" -eq 0 ]; then FINGER=n; fi
antworten_sichern
gut "Antworten in $ANTWORTEN gemerkt"

# ------------------------------------------------------------------- Pakete

schritt "Pakete"

# Grundlage: Xorg ohne Display-Manager, i3, Terminal, Browser.
PAKETE="xorg-minimal xorg-fonts xrdb setxkbmap xinput xdg-utils
        mesa-dri $GPU_PAKET
        i3 i3status i3lock rofi dmenu picom feh clipmenu
        alacritty xterm pcmanfm flatpak
        xdg-desktop-portal xdg-desktop-portal-gtk
        libinput-gestures python3-i3ipc python3-xlib
        nerd-fonts-symbols-ttf noto-fonts-cjk-sans papirus-icon-theme"

# Benachrichtigungen: dunst ist der D-Bus-Dienst auf
# org.freedesktop.Notifications. Fehlt er, verschwinden Meldungen von
# Chrome & Co. spurlos -- es gibt dann schlicht niemanden, der sie anzeigt.
# libnotify liefert notify-send, brightnessctl und playerctl bedienen die
# F-Tasten, acpi liest Akku und Temperatur. acpid ist der Daemon dazu und
# wird hier nur fuer den Deckelschalter gebraucht.
PAKETE="$PAKETE dunst libnotify brightnessctl playerctl acpi acpid"

# xprintidle meldet, wie lange niemand Tastatur oder Maus angefasst hat. Darauf
# stuetzt sich ~/.local/bin/akku wache, die den Bildschirm dunkel macht, sperrt
# und in Bereitschaft schickt. Nicht xautolock: das kennt nur EINEN Zaehler,
# seine zweite Aktion haengt am Sperren statt am Leerlauf und hat einen festen
# Mindestabstand von 10 Minuten -- "sperren nach 10, schlafen nach 30" laesst
# sich damit nicht bauen.
PAKETE="$PAKETE xprintidle"

# Sperrbildschirm. xsecurelock statt i3lock, weil es Hintergrundbild,
# Anmeldemaske und Fenstergriffe in getrennte Prozesse legt -- nur so laesst
# sich ein eigenes Bild samt Fingerabdruck-Hinweis zeigen. Das Bild baut
# ImageMagick (steht weiter unten schon in der Liste).
PAKETE="$PAKETE xsecurelock"
# cairo und libX11 als Entwicklungsdateien: daraus wird sperrsaver gebaut,
# das kleine Programm, das das Bild in das Fenster von xsecurelock malt.
PAKETE="$PAKETE cairo-devel libX11-devel"

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

# Webcam. guvcview ist die kleinste GUI mit Vorschau, Foto und Video: GTK3,
# zieht nur SDL2 und gsl nach. cheese kann dasselbe, bringt aber den halben
# GNOME-Unterbau mit. Wichtig zu wissen: die Kamera haengt am Schieber ueber
# dem Bildschirm -- ist er zu, trennt die Hardware das USB-Geraet und
# /dev/video0 verschwindet ganz. "Keine Kamera gefunden" heisst also fast
# immer "Schieber zu" und nicht "Treiber fehlt".
PAKETE="$PAKETE guvcview"

# Scanner. Der Brother MFC-L3760CDW haengt im WLAN, nicht am USB, und kann
# eSCL (Apple AirScan) -- damit braucht es keinen Herstellertreiber:
# sane-airscan spricht das Protokoll direkt, simple-scan ist die GUI dazu
# (derselbe "Document Scanner" wie frueher unter Debian mit GNOME).
# avahi findet das Geraet per mDNS; ohne den Daemon sieht "scanimage -L"
# gar nichts. avahi-utils liefert avahi-browse zum Nachschauen, wenn doch
# einmal nichts gefunden wird.
PAKETE="$PAKETE sane sane-airscan simple-scan avahi avahi-utils nss-mdns"

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

# Medientasten (F9/F10/F11) fuer Chrome: der Flatpak von Google Chrome bringt
# in seinem Manifest die Zeile
#     org.mpris.MediaPlayer2.chromium.*=own
# mit -- offensichtlich vom Chromium-Paket uebernommen. Google Chrome meldet
# seinen MPRIS-Dienst aber unter "chrome" an, nicht unter "chromium". Der
# D-Bus-Filter des Sandkastens blockt die Anmeldung deshalb, und "playerctl"
# findet ueberhaupt keinen Player -- die F-Tasten laufen ins Leere, obwohl an
# ihnen nichts falsch ist. Nachgemessen mit dbus-send im Sandkasten:
# RequestName auf ...MediaPlayer2.chrome.* antwortet ohne diesen Override mit
# ServiceUnknown, mit ihm mit "uint32 1".
# Brave braucht das nicht, dort steht im Manifest korrekt "brave.*".
flatpak override --user com.google.Chrome \
     --own-name='org.mpris.MediaPlayer2.chrome.*'
gut "MPRIS-Berechtigung fuer Chrome gesetzt (Medientasten)"

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
# avahi-daemon sucht den Netzwerkscanner per mDNS (Abschnitt "Scanner" weiter
# unten).
for d in dbus dhcpcd wpa_supplicant tailscaled bluetoothd alsa rtkit acpid avahi-daemon; do
    if [ ! -e "/etc/sv/$d" ]; then
        warn "$d gibt es nicht, uebersprungen"
    elif [ -e "/var/service/$d" ]; then
        info "$d laeuft bereits"
    else
        sudo ln -sf "/etc/sv/$d" /var/service/
        gut "$d eingeschaltet"
    fi
done

# ------------------------------------------------------------------ Scanner

schritt "Scanner"

# Zwei Kleinigkeiten, ohne die der Scanner scheinbar gar nicht da ist:
#
# 1. avahi-browse und scanimage melden hartnaeckig "Daemon not running",
#    obwohl "sv status avahi-daemon" laeuft. Grund ist der schon laufende
#    system-dbus: er kennt die erst jetzt installierte Policy in
#    /usr/share/dbus-1/system.d/avahi-dbus.conf noch nicht. Ein reload (HUP)
#    genuegt -- ein Neustart von dbus wuerde die laufende Sitzung zerlegen.
#
# 2. SANE bringt neben airscan ein eigenes escl-Backend mit. Es fragt den
#    Webserver des Druckers auf Port 80 ab und kippt dessen komplette
#    HTML-Startseite nach stdout -- sieht nach Fehler aus, ist nur Laerm --,
#    und liefert das Geraet ein zweites Mal. airscan kann dasselbe besser,
#    also bleibt escl aus.

if [ -e /var/service/dbus ]; then
    sudo sv reload dbus >/dev/null 2>&1 && gut "dbus hat die Avahi-Policy nachgeladen"
fi
[ -e /var/service/avahi-daemon ] && sudo sv restart avahi-daemon >/dev/null 2>&1

if [ -f /etc/sane.d/dll.conf ] && grep -q '^escl$' /etc/sane.d/dll.conf; then
    sudo sed -i 's/^escl$/#escl/' /etc/sane.d/dll.conf
    gut "escl-Backend abgeschaltet, airscan uebernimmt"
else
    info "escl-Backend ist bereits aus"
fi

# Kontrolle: "scanimage -L" soll genau eine Zeile mit airscan zeigen. Beim
# ersten Lauf braucht mDNS ein paar Sekunden, darum die Schleife.
n=0
while [ $n -lt 4 ]; do
    if scanimage -L 2>/dev/null | grep -q '^device .airscan:'; then
        gut "Scanner gefunden: $(scanimage -L 2>/dev/null | sed -n 's/^device .[^ ]* is a //p' | head -1)"
        break
    fi
    n=$((n + 1))
    sleep 3
done
[ $n -lt 4 ] || warn "Kein Scanner gefunden. Ist er eingeschaltet und im selben WLAN? Nachsehen mit: avahi-browse -rt _uscan._tcp"

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
           etc/pam.d/xsecurelock \
           usr/libexec/xsecurelock/saver_sperrbild \
           etc/zzz.d/resume/10-fingerabdruck \
           etc/zzz.d/resume/20-funk \
           etc/funk-beim-boot.sh \
           etc/runit/shutdown.d/05-sanft-beenden.sh \
           usr/local/sbin/sanft-beenden \
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

# Und fuer das Startfenster, das rc.local im Hintergrund aufruft.
sudo chmod 755 /etc/funk-beim-boot.sh

# Und fuer das Beenden-Skript: das Fragment in /etc/runit/shutdown.d ruft es
# nur auf, wenn es ausfuehrbar ist -- sonst faehrt der Rechner wie bisher
# herunter, ohne Fehlermeldung, aber auch ohne Wirkung.
sudo chmod 755 /usr/local/sbin/sanft-beenden

# Dasselbe fuer den Deckel-Handler: acpid ruft ihn direkt auf.
sudo chmod 755 /etc/acpi/deckel.sh

# Und fuer den Aufwach-Hook: /usr/bin/zzz laeuft die Verzeichnisse
# /etc/zzz.d/suspend und /etc/zzz.d/resume durch und ruft daraus nur auf, was
# ausfuehrbar ist -- eine Datei ohne das Recht wird wortlos uebergangen.
sudo chmod 755 /etc/zzz.d/resume/10-fingerabdruck
sudo chmod 755 /etc/zzz.d/resume/20-funk

# Und fuer das Saver-Modul: xsecurelock startet es als Programm. Es muss neben
# den mitgelieferten Modulen liegen -- xsecurelock sucht seine Module nur in
# diesem einen Verzeichnis, ein Pfad in XSECURELOCK_SAVER hilft nicht.
sudo chmod 755 /usr/libexec/xsecurelock/saver_sperrbild

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
if [ "$LED_OK" -eq 0 ]; then
    warn "uebersprungen: $LED_GRUND"
    warn "mikro-led und ton-led laufen weiter, nur ohne Licht in der Taste."
elif command -v gcc >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
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

# Das Bild des Sperrbildschirms. Warum ein eigenes Programm noetig ist, steht
# ausfuehrlich im Kopf von system/bin/sperrsaver.c -- kurz: ImageMagicks
# "display -window" findet die namenlosen Fenster von xsecurelock nicht, und
# mpv nur zum Anzeigen eines Standbilds mitzuschleppen waere unverhaeltnismaessig.
schritt "Sperrbildschirm"
if command -v gcc >/dev/null 2>&1 && pkg-config --exists cairo x11 2>/dev/null; then
    if gcc -O2 -o "/tmp/sperrsaver.$$" "$QUELLE/system/bin/sperrsaver.c" \
           $(pkg-config --cflags --libs cairo x11) 2>/dev/null; then
        sudo install -m 755 "/tmp/sperrsaver.$$" /usr/local/bin/sperrsaver
        rm -f "/tmp/sperrsaver.$$"
        gut "/usr/local/bin/sperrsaver gebaut"
    else
        rm -f "/tmp/sperrsaver.$$"
        warn "sperrsaver liess sich nicht uebersetzen -- der Sperrbildschirm bliebe schwarz."
    fi
else
    warn "gcc oder die Entwicklungsdateien von cairo/x11 fehlen -- kein Sperrbild."
fi

# ------------------------------------------------------ Fingerabdrucksensor
# Der Synaptics 06cb:00e7 braucht einen selbst gebauten libfprint-Treiber,
# siehe fingerabdruck/README.md. Erkannt wird der Sensor im Hardware-Block,
# gefragt wurde in der Uebersicht -- hier wird nur noch ausgefuehrt.
schritt "Fingerabdrucksensor"
if [ "$FINGER" = j ]; then
    if sh "$QUELLE/fingerabdruck/einrichten.sh"; then
        gut "Fingerabdrucksensor eingerichtet -- Finger anlernen steht unten"
    else
        warn "einrichten.sh ist abgebrochen -- spaeter von Hand: sh fingerabdruck/einrichten.sh"
    fi
elif [ "$SENSOR_00E7" -eq 1 ]; then
    info "abgewaehlt -- spaeter: sh fingerabdruck/einrichten.sh"
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

# Die im Hardware-Block gemessenen Pfade. Sie standen frueher fest in den
# drei Dateien und waren auf jedem anderen Notebook falsch.
sed -i "s|@@AKKU@@|$AKKU|g; s|@@NETZ@@|$NETZ|g" \
    "$HOME/.local/bin/akku-wache" "$HOME/.local/bin/netz-ton" "$HOME/.local/bin/akku"
if [ -n "$TEMP" ]; then
    sed -i "s|@@TEMP@@|$TEMP|g" \
        "$HOME/.local/bin/akku-wache" "$HOME/.config/i3status/config"
    gut "Akku $AKKU, Netzteil $NETZ, Temperatur $TEMP"
else
    # Ohne Quelle bleibt der Block in der Datei stehen, wird aber nicht mehr
    # angeordnet -- i3status stoert ein unbenutzter Block nicht, ein Pfad
    # ins Leere dagegen schon.
    sed -i "s|@@TEMP@@||g" "$HOME/.local/bin/akku-wache"
    sed -i '/order += "cpu_temperature 0"/d; s|@@TEMP@@||' "$HOME/.config/i3status/config"
    warn "keine Temperaturquelle -- der Block bleibt aus der Leiste heraus"
fi

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

# Was wegen der Hardware ausgelassen wurde, gehoert an den Schluss: oben in
# der Uebersicht ist es nach einem langen Lauf laengst aus dem Bild gerollt.
if [ -n "$UEBERSPRUNGEN" ]; then
    printf '\n%sWegen der Hardware ausgelassen:%s\n' "$FETT" "$AUS"
    printf '%s' "$UEBERSPRUNGEN" | while IFS='|' read -r teil grund; do
        if [ -n "$teil" ]; then
            printf '\n  %s%s%s\n' "$GELB" "$teil" "$AUS"
            printf '%s\n' "$grund" | fold -s -w 66 | sed 's/^/    /'
        fi
    done
fi

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
