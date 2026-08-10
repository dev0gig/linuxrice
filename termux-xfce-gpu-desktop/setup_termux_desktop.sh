#!/bin/bash
set -e

# ============================================================
# Native Termux XFCE Desktop Setup (mit turnip/Zink GPU-Support)
# Für: Samsung Galaxy Z Fold 7 (Snapdragon/Adreno)
# ============================================================

echo "=== [1/6] System aktualisieren ==="
export DEBIAN_FRONTEND=noninteractive
pkg update -y
pkg upgrade -y -o Dpkg::Options::="--force-confnew"

echo "=== [2/6] X11-Repo freischalten ==="
pkg install -y -o Dpkg::Options::="--force-confnew" x11-repo

echo "=== [3/6] Basis-Pakete installieren ==="
pkg install -y -o Dpkg::Options::="--force-confnew" termux-x11-nightly
pkg install -y -o Dpkg::Options::="--force-confnew" mesa-vulkan-icd-freedreno mesa
pkg install -y -o Dpkg::Options::="--force-confnew" xfce4 xterm rofi firefox papirus-icon-theme xfce4-taskmanager sxhkd mousepad openssh

echo "=== [4/6] Panel-Vorlage anlegen (ohne Panel als Startzustand) ==="
# Die Panel-Einstellungen leben ab jetzt in einer VORLAGE. Beim Desktop-Start
# wird diese Vorlage über die echte Konfigdatei kopiert (siehe start-desktop.sh).
# Grund: XFCE merkt sich Panel-Einstellungen nicht in der Datei, sondern im
# laufenden Dienst "xfconfd". Der schreibt beim Beenden seinen eigenen, alten
# Stand über die Datei — dadurch war jede Panel-Anpassung nach einem Neustart
# wieder weg. Die Vorlage ist die Quelle der Wahrheit, nicht der Dienst.
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/panel-template.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array"/>
  <property name="plugins" type="empty"/>
  <property name="configver" type="int" value="2"/>
</channel>
EOF
cp -f ~/.config/xfce4/panel-template.xml \
      ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

# Session-Autospeichern aus: sonst legt XFCE beim Beenden einen eigenen
# Sitzungszustand ab und stellt daraus wieder ein Panel her.
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="SaveOnExit" type="bool" value="false"/>
  </property>
</channel>
EOF

echo "=== [5/6] Rofi mittig konfigurieren ==="
mkdir -p ~/.config/rofi
cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run";
    show-icons: true;
}
window {
    location: center;
    anchor: center;
    width: 40%;
    y-offset: 0;
}
EOF

echo "=== Rofi-Hotkey einrichten (sxhkd, Super+Space) ==="
mkdir -p ~/.config/sxhkd
cat > ~/.config/sxhkd/sxhkdrc << 'EOF'
super + space
    rofi -show drun
EOF

echo "=== [6/6] Start-Skript erstellen ==="
cat > ~/start-desktop.sh << 'EOF'
#!/bin/bash

# Alte Instanzen sauber beenden
killall -9 termux-x11 sxhkd 2>/dev/null
killall -9 xfce4-session xfce4-panel xfwm4 xfdesktop xfsettingsd 2>/dev/null

# WICHTIG: den Einstellungs-Dienst "xfconfd" mit beenden.
# Er hält alle XFCE-Einstellungen im Speicher und ist für XFCE die einzige
# Wahrheit — die Konfigdatei liest er nur EINMAL beim Start. Überlebt er den
# X11-Neustart (was in Termux oft passiert, wenn Android die Sitzung im
# Hintergrund abwürgt), gilt weiter sein alter Stand, und beim Beenden schreibt
# er den auch noch über die Datei. Genau daran ist die Panel-Config bisher
# nach jedem Neustart verloren gegangen.
killall -9 xfconfd 2>/dev/null
# warten, bis er wirklich weg ist (sonst kopieren wir gegen einen laufenden Dienst an)
for _ in $(seq 1 20); do
    pgrep -x xfconfd >/dev/null 2>&1 || break
    sleep 0.25
done

# Session-Cache bereinigen (verhindert, dass XFCE einen gespeicherten Panel-Zustand wiederherstellt)
rm -rf ~/.cache/sessions

# Panel-Einstellungen aus der Vorlage wiederherstellen.
# Erst JETZT kopieren — nachdem xfconfd tot ist. Vorher wäre die Datei gleich
# wieder von seinem alten Stand überschrieben worden.
PANEL_TEMPLATE="$HOME/.config/xfce4/panel-template.xml"
PANEL_CONFIG="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
if [ -f "$PANEL_TEMPLATE" ]; then
    mkdir -p "$(dirname "$PANEL_CONFIG")"
    cp -f "$PANEL_TEMPLATE" "$PANEL_CONFIG"
fi

# GPU-Treiber: Zink (OpenGL-Übersetzung) über turnip (Vulkan/Adreno)
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
export MESA_NO_ERROR=1

# X11-Server im Hintergrund starten
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0

# Hotkey-Daemon für Rofi (Super+Space) im Hintergrund starten
sxhkd &

# XFCE4 Desktop starten
startxfce4
EOF
chmod +x ~/start-desktop.sh

echo "=== Firefox-Alias einrichten ==="
if ! grep -q "alias firefox=" ~/.bashrc 2>/dev/null; then
    echo "alias firefox='firefox'" >> ~/.bashrc
fi

echo "=== Alias 'xfce' einrichten ==="
if ! grep -q "alias xfce=" ~/.bashrc 2>/dev/null; then
    echo "alias xfce='~/start-desktop.sh'" >> ~/.bashrc
fi

echo "=== Panel-Session-Cache bereinigen (verhindert Wiederherstellung leerer Panels) ==="
pkill xfce4-panel 2>/dev/null
rm -rf ~/.cache/sessions
rm -rf ~/.config/xfce4/panel

source ~/.bashrc

echo ""
echo "============================================"
echo "  Setup abgeschlossen!"
echo "============================================"
echo ""
echo "Nächste Schritte:"
echo "  1. source ~/.bashrc"
echo "  2. Desktop starten mit: xfce"
echo "  3. App-Suche im Desktop: Super+Space"
echo "  4. Im Desktop-Terminal: ./rice.sh (für Icons/Font/Cursor/Wallpaper/Maus)"
echo ""
echo "Chromium wurde durch Firefox ersetzt (stabileres Rendering unter Termux-X11)."
echo ""
