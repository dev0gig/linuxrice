#!/usr/bin/env bash
#
# XFCE Rice Setup — MANUELL im Desktop-Terminal ausführen, nachdem XFCE gestartet ist.
# Papirus-Dark Icons, Red Hat Mono Font, Bibata-Modern-Ice Cursor,
# eigenes Wallpaper (liegt im Repo), Dark Mode, direktere Maus (keine Beschleunigung).
#
# Idempotent: kann gefahrlos mehrfach ausgeführt werden.
#
set -euo pipefail

SKRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FONTS_DIR="$HOME/.local/share/fonts"
ICONS_DIR="$HOME/.icons"
WALLPAPER_DIR="$HOME/Pictures/Wallpaper"
WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper.png"
# Das Wallpaper liegt neben diesem Skript im Repo — kein Download mehr von
# fremden Servern (der alte Wallhaven-Link hätte jederzeit sterben können).
WALLPAPER_QUELLE="$SKRIPT_DIR/wallpaper.png"
# Notnagel, falls das Skript ohne sein Repo unterwegs ist:
WALLPAPER_FERN="benutzer@rechner:~/assets/wallpaper/toride-die.png"

CURSOR_THEME="Bibata-Modern-Ice"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"

FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/redhatmono/RedHatMono%5Bwght%5D.ttf"

log()  { echo -e "\033[1;31m[rice]\033[0m $1"; }
err()  { echo -e "\033[1;31m[rice ERROR]\033[0m $1" >&2; }

if ! command -v xfconf-query >/dev/null 2>&1; then
    err "xfconf-query nicht gefunden. Läuft das Script innerhalb der XFCE-Umgebung?"
    exit 1
fi

if [ -z "${DISPLAY:-}" ]; then
    err "Keine DISPLAY-Variable gesetzt. Dieses Skript muss INNERHALB des laufenden XFCE-Desktops laufen."
    exit 1
fi

NEEDED_PKGS=()
command -v wget >/dev/null 2>&1 || NEEDED_PKGS+=("wget")
command -v tar >/dev/null 2>&1 || NEEDED_PKGS+=("tar")
command -v fc-cache >/dev/null 2>&1 || NEEDED_PKGS+=("fontconfig")
command -v xrandr >/dev/null 2>&1 || NEEDED_PKGS+=("xorg-xrandr")
dpkg -s papirus-icon-theme >/dev/null 2>&1 || NEEDED_PKGS+=("papirus-icon-theme")
dpkg -s arc-gtk-theme >/dev/null 2>&1 || NEEDED_PKGS+=("arc-gtk-theme")
if [ "${#NEEDED_PKGS[@]}" -gt 0 ]; then
    log "Installiere: ${NEEDED_PKGS[*]}"
    pkg install -y "${NEEDED_PKGS[@]}"
fi

if fc-list | grep -qi "Red Hat Mono"; then
    log "Red Hat Mono bereits installiert."
else
    log "Installiere Red Hat Mono..."
    mkdir -p "$FONTS_DIR"
    TMP="$(mktemp -d)"
    if wget -q -O "$TMP/RedHatMono.ttf" "$FONT_URL" && [ -s "$TMP/RedHatMono.ttf" ]; then
        cp "$TMP/RedHatMono.ttf" "$FONTS_DIR/"
        fc-cache -f "$FONTS_DIR" >/dev/null
        log "Red Hat Mono installiert."
    else
        err "Red Hat Mono Download fehlgeschlagen."
    fi
    rm -rf "$TMP"
fi

if [ -d "$ICONS_DIR/$CURSOR_THEME" ]; then
    log "Bibata-Modern-Ice bereits installiert."
else
    log "Installiere Bibata-Modern-Ice Cursor..."
    mkdir -p "$ICONS_DIR"
    TMP="$(mktemp -d)"
    if wget -q -O "$TMP/bibata.tar.xz" "$CURSOR_URL"; then
        tar -xf "$TMP/bibata.tar.xz" -C "$TMP"
        if [ -d "$TMP/$CURSOR_THEME" ]; then
            mv "$TMP/$CURSOR_THEME" "$ICONS_DIR/"
            log "Bibata-Modern-Ice installiert."
        else
            err "Entpackter Ordner '$CURSOR_THEME' nicht gefunden."
        fi
    else
        err "Bibata-Cursor Download fehlgeschlagen."
    fi
    rm -rf "$TMP"
fi

log "Setze Wallpaper..."
mkdir -p "$WALLPAPER_DIR"
if [ -s "$WALLPAPER_QUELLE" ]; then
    cp -f "$WALLPAPER_QUELLE" "$WALLPAPER_FILE"
    log "Wallpaper aus dem Repo übernommen."
elif [ -s "$WALLPAPER_FILE" ]; then
    # Wichtig: ein selbst gewähltes Wallpaper wird NICHT mehr überschrieben.
    log "Wallpaper ist schon da — bleibt unangetastet."
elif command -v scp >/dev/null 2>&1 && scp -q "$WALLPAPER_FERN" "$WALLPAPER_FILE" 2>/dev/null; then
    log "Wallpaper per scp geholt."
else
    err "Kein Wallpaper gefunden: weder $WALLPAPER_QUELLE noch $WALLPAPER_FILE."
    err "Von einem eigenen Rechner holen: scp $WALLPAPER_FERN $WALLPAPER_FILE"
fi

log "Aktiviere Icons, Font, Cursor, Dark Mode..."
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" --create -t string 2>/dev/null || \
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
xfconf-query -c xsettings -p /Gtk/FontName -s "Red Hat Mono 10" --create -t string 2>/dev/null || \
    xfconf-query -c xsettings -p /Gtk/FontName -s "Red Hat Mono 10"
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$CURSOR_THEME" --create -t string 2>/dev/null || \
    xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$CURSOR_THEME"
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 32 --create -t int 2>/dev/null || \
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 32
xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark" --create -t string 2>/dev/null || \
    xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark"
xfconf-query -c xsettings -p /Gtk/ApplicationPreferDarkTheme -s true --create -t bool 2>/dev/null || \
    xfconf-query -c xsettings -p /Gtk/ApplicationPreferDarkTheme -s true
xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark" --create -t string 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark"
xfconf-query -c xfwm4 -p /general/title_font -s "Red Hat Mono Bold 10" --create -t string 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/title_font -s "Red Hat Mono Bold 10"

log "Setze Wallpaper..."
MONITOR_NAME=$(xrandr --listmonitors 2>/dev/null | awk 'NR==2{print $NF}')
if [ -z "$MONITOR_NAME" ]; then
    MONITOR_NAME="external"
    err "Monitorname nicht per xrandr erkannt, verwende Fallback '$MONITOR_NAME'."
fi
WALLPAPER_PROP="/backdrop/screen0/monitor${MONITOR_NAME}/workspace0/last-image"
xfconf-query -c xfce4-desktop -p "$WALLPAPER_PROP" -n -t string -s "$WALLPAPER_FILE" 2>/dev/null || \
    xfconf-query -c xfce4-desktop -p "$WALLPAPER_PROP" -s "$WALLPAPER_FILE"
log "Wallpaper gesetzt unter: $WALLPAPER_PROP"

# Zusätzlich auf allen bereits bekannten backdrop-Properties setzen (falls vorhanden)
WALLPAPER_PROPS=$(xfconf-query -c xfce4-desktop -p /backdrop -l 2>/dev/null | grep "last-image" || true)
if [ -n "$WALLPAPER_PROPS" ]; then
    while IFS= read -r prop; do
        xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER_FILE"
    done <<< "$WALLPAPER_PROPS"
fi

log "Deaktiviere Mausbeschleunigung..."
xfconf-query -c pointers -p /DeviceDefault/AccelerationProfile -s -1 --create -t int 2>/dev/null || \
    xfconf-query -c pointers -p /DeviceDefault/AccelerationProfile -s -1
xfconf-query -c pointers -p /DeviceDefault/AccelerationScheme -s "none" --create -t string 2>/dev/null || \
    xfconf-query -c pointers -p /DeviceDefault/AccelerationScheme -s "none"
xset m 0 0 2>/dev/null || true

log "Deaktiviere Panel-/Fenster-Schatten..."
xfconf-query -c xfwm4 -p /general/show_dock_shadow -n -t bool -s false 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/show_dock_shadow -s false
xfconf-query -c xfwm4 -p /general/show_frame_shadow -n -t bool -s false 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false

log "Stelle sicher, dass Compositing aktiv ist..."
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/use_compositing -s true

xfwm4 --replace &
disown
sleep 1

log "Deaktiviere Desktop-Icons..."
xfconf-query -c xfce4-desktop -p /desktop-icons/style -n -t int -s 0 2>/dev/null || \
    xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0

log "Deaktiviere Session-Autosave (verhindert, dass XFCE eigenen Panel-Zustand wiederherstellt)..."
xfconf-query -c xfce4-session -p /general/SaveOnExit -n -t bool -s false 2>/dev/null || \
    xfconf-query -c xfce4-session -p /general/SaveOnExit -s false
rm -rf ~/.cache/sessions

# ------------------------------------------------------------------
# Panel: schmale, transparente Taskleiste rechts, vertikal mittig.
#
# WARUM DAS SO UMSTÄNDLICH AUSSIEHT:
# XFCE liest Einstellungen nicht direkt aus der Konfigdatei. Dazwischen sitzt
# der Dienst "xfconfd", der alles im Speicher hält. Schreibt man die Datei
# einfach nur um (so hat es dieses Skript vorher gemacht), merkt xfconfd das
# nicht — und schreibt beim Beenden seinen eigenen, alten Stand wieder drüber.
# Deshalb war die Panel-Config nach jedem X11-Neustart wieder weg.
#
# Die Lösung besteht aus zwei Teilen:
#   1. Die Wunsch-Konfiguration liegt als VORLAGE unter panel-template.xml.
#      start-desktop.sh kopiert sie bei JEDEM Desktop-Start über die echte
#      Konfigdatei — nachdem xfconfd beendet wurde. Damit ist die Vorlage die
#      Quelle der Wahrheit und übersteht jeden Neustart.
#   2. Damit es auch sofort sichtbar wird, wird xfconfd hier einmal hart beendet
#      und das Panel neu gestartet. Details zur Reihenfolge weiter unten.
# ------------------------------------------------------------------
log "Ermittle Bildschirmgröße für die Panel-Position..."
PANEL_SIZE=48
SCREEN_DIMS=$(xrandr 2>/dev/null | awk '/current/{gsub(",","");print $8" "$10; exit}')
SCREEN_W=$(echo "$SCREEN_DIMS" | awk '{print $1}')
SCREEN_H=$(echo "$SCREEN_DIMS" | awk '{print $2}')
if ! [ "${SCREEN_W:-0}" -gt 100 ] 2>/dev/null || ! [ "${SCREEN_H:-0}" -gt 100 ] 2>/dev/null; then
    SCREEN_W=1920
    SCREEN_H=1060
    err "Bildschirmgröße nicht erkannt, nutze Rückfallwert ${SCREEN_W}x${SCREEN_H}."
fi
# Rechter Rand, vertikal mittig. Bei 1920x1060 ergibt das die bisher von Hand
# eingetragenen Werte x=1901;y=530 — passt so aber auch im gefalteten Zustand.
PANEL_X=$(( SCREEN_W - 19 ))
PANEL_Y=$(( SCREEN_H / 2 ))
log "Bildschirm ${SCREEN_W}x${SCREEN_H} -> Panel-Position p=3;x=${PANEL_X};y=${PANEL_Y}"

log "Schreibe Panel-Vorlage..."
PANEL_TEMPLATE="$HOME/.config/xfce4/panel-template.xml"
PANEL_CONFIG="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
mkdir -p "$(dirname "$PANEL_TEMPLATE")" "$(dirname "$PANEL_CONFIG")"
cat > "$PANEL_TEMPLATE" << PANELEOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=3;x=${PANEL_X};y=${PANEL_Y}"/>
      <property name="size" type="uint" value="${PANEL_SIZE}"/>
      <property name="mode" type="uint" value="1"/>
      <property name="length" type="double" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="autohide-behavior" type="uint" value="1"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="5"/>
        <value type="int" value="2"/>
      </property>
      <property name="background-style" type="uint" value="1"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0"/>
        <value type="double" value="0"/>
        <value type="double" value="0"/>
        <value type="double" value="0"/>
      </property>
      <property name="enter-opacity" type="uint" value="100"/>
      <property name="leave-opacity" type="uint" value="100"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-5" type="string" value="tasklist">
      <property name="flat-buttons" type="bool" value="true"/>
      <property name="show-labels" type="bool" value="false"/>
      <property name="show-handle" type="bool" value="false"/>
      <property name="grouping" type="bool" value="false"/>
    </property>
  </property>
  <property name="configver" type="int" value="2"/>
</channel>
PANELEOF

# Alte Blockade aus früheren Versionen entfernen — wir wollen das Panel jetzt.
rm -f ~/.config/autostart/xfce4-panel.desktop

log "Wende Panel-Vorlage sofort an..."
# Die Reihenfolge hier ist der ganze Trick. xfconfd hält ALLES im Speicher —
# auch das Wallpaper und das Theme, die oben per xfconf-query gesetzt wurden.
# Auf die Platte schreibt er das erst beim sauberen Beenden.
#
#   1. xfconfd NORMAL beenden (SIGTERM). Dabei schreibt er brav alles raus, was
#      oben eingestellt wurde — Wallpaper, Icons, Theme, Maus. Würde man ihn
#      hier mit -9 abschießen, wäre all das weg (genau so ist vorher das
#      Wallpaper verschwunden).
killall xfconfd 2>/dev/null || true
sleep 3
#   2. Erst JETZT die Panel-Datei überschreiben. Beim Rausschreiben in Schritt 1
#      hat xfconfd nämlich auch seinen alten Panel-Stand mit auf die Platte
#      gelegt — den bügeln wir hier wieder weg.
cp -f "$PANEL_TEMPLATE" "$PANEL_CONFIG"
#   3. xfconfd jetzt hart beenden, damit er die frische Panel-Datei sicher neu
#      liest. Das ist an dieser Stelle gefahrlos: alles Wertvolle liegt nach
#      Schritt 1 schon auf der Platte.
killall -9 xfconfd 2>/dev/null || true
sleep 1
#   4. Panel neu starten, damit es die frischen Werte liest. XFCE startet es
#      meist von selbst wieder; falls nicht, starten wir es hier.
#      (Kein "xfce4-panel --quit" — das bleibt unter Termux-X11 hängen.)
killall -9 xfce4-panel 2>/dev/null || true
sleep 2
if ! pgrep -x xfce4-panel >/dev/null 2>&1; then
    xfce4-panel >/dev/null 2>&1 &
    disown
fi

log "Panel eingerichtet (Vorlage: $PANEL_TEMPLATE)."

log "Lade laufende Komponenten neu, damit Änderungen sichtbar werden..."
pkill xfdesktop 2>/dev/null
sleep 1
xfdesktop &
disown
xfwm4 --replace &
disown
killall -HUP xfsettingsd 2>/dev/null || xfsettingsd --replace &

log "Rice fertig."
