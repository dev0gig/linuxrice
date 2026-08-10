#!/usr/bin/env bash
#
# XFCE Rice Setup — MANUELL im Desktop-Terminal ausführen, nachdem XFCE gestartet ist.
# Papirus-Dark Icons, Red Hat Mono Font, Bibata-Modern-Ice Cursor,
# Wallhaven-Wallpaper, Dark Mode, direktere Maus (keine Beschleunigung).
#
# Idempotent: kann gefahrlos mehrfach ausgeführt werden.
#
set -euo pipefail

FONTS_DIR="$HOME/.local/share/fonts"
ICONS_DIR="$HOME/.icons"
WALLPAPER_DIR="$HOME/Pictures/Wallpaper"
WALLPAPER_URL="https://w.wallhaven.cc/full/ln/wallhaven-lnzdw4.png"
WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper.png"

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

log "Lade Wallpaper..."
mkdir -p "$WALLPAPER_DIR"
if wget -q -O "$WALLPAPER_FILE" "$WALLPAPER_URL" && [ -s "$WALLPAPER_FILE" ]; then
    log "Wallpaper gespeichert."
else
    err "Wallpaper-Download fehlgeschlagen."
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

log "Deaktiviere Panel dauerhaft (kein Panel, verlässlicher Zustand)..."
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'PANELEOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array"/>
  <property name="plugins" type="empty"/>
</channel>
PANELEOF

mkdir -p ~/.config/autostart
cat > ~/.config/autostart/xfce4-panel.desktop << 'AUTOSTARTEOF'
[Desktop Entry]
Type=Application
Name=xfce4-panel
Exec=xfce4-panel
Hidden=true
X-GNOME-Autostart-enabled=false
AUTOSTARTEOF

pkill xfce4-panel 2>/dev/null
xfconf-query -c xfce4-panel -R -r /panels 2>/dev/null || true
rm -rf ~/.cache/sessions
rm -rf ~/.config/xfce4/panel

log "Panel deaktiviert."

log "Lade laufende Komponenten neu, damit Änderungen sichtbar werden..."
pkill xfdesktop 2>/dev/null
sleep 1
xfdesktop &
disown
xfwm4 --replace &
disown
killall -HUP xfsettingsd 2>/dev/null || xfsettingsd --replace &

log "Rice fertig."
