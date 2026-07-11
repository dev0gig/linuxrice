#!/data/data/com.termux/files/usr/bin/bash
set -e  # Script bricht sofort ab, wenn ein Befehl fehlschlägt

echo "🚀 Starte die vollautomatische Debian XFCE + Dev-Environment Installation..."
echo "   Läuft komplett unbeaufsichtigt durch — keine Eingaben nötig."

# ─────────────────────────────────────────────────────────────────────────────
# EIGENE ASSET-QUELLE: Alle Themes/Fonts/Cursor liegen in DEINEM GitHub-Repo.
# Vorteil: Links können nie fremd-verschwinden, feste Versionen, du kontrollierst sie.
# Wenn du Repo/Ordner/Branch umbenennst, NUR diese eine Zeile anpassen.
# ─────────────────────────────────────────────────────────────────────────────
ASSET_BASE="https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-proot-debian-xfce-nordic/assets"

# 0. Root-Check — verhindert das proot-Chaos von Play-Store-Termux
if [ "$(id -u)" = "0" ]; then
  echo "❌ FEHLER: Termux läuft als root (UID 0)."
  echo "   Das deutet auf eine Play-Store-Installation von Termux hin — die ist"
  echo "   veraltet und unsupported und verursacht kaputte proot-Umgebungen."
  echo ""
  echo "   Bitte Play-Store-Termux DEINSTALLIEREN und stattdessen installieren von:"
  echo "   - F-Droid: https://f-droid.org/"
  echo "   - oder GitHub: https://github.com/termux/termux-app/releases"
  echo "     (für Fold 7: die 'arm64-v8a' APK)"
  exit 1
fi

# 1. Termux-Mirror fest einstellen (verhindert langsame Auto-Discovery bei jedem pkg update)
echo "🌍 Setze schnellen Termux-Mirror (CDN, automatisch nächstgelegen)..."
mkdir -p $PREFIX/etc/apt/sources.list.d
echo "deb [signed-by=/data/data/com.termux/files/usr/etc/apt/trusted.gpg.d/termux.gpg] https://packages-cf.termux.dev/apt/termux-main stable main" > $PREFIX/etc/apt/sources.list

# 2. Termux-Pakete aktualisieren
echo "📦 Aktualisiere das Basis-System..."
pkg update -y
pkg upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold

# 2. Notwendige Pakete und Repositories installieren
echo "🛠️ Installiere Core-Tools und X11-Repo..."
pkg install x11-repo -y
pkg install git proot-distro termux-x11-nightly -y

# 3. Debian ARM64 herunterladen
echo "🐧 Installiere Debian (ARM64)..."
proot-distro install debian

# 4. XFCE, Alacritty, Firefox, japanische Schriften, Curl INNERHALB von Debian installieren
# HINWEIS: xfce4-terminal (VTE) rendert bestimmte Nerd-Font-Symbole (Private-Use-Area)
# nicht korrekt, selbst bei korrekt installierter Font. Alacritty (kein VTE) zeigt sie
# zuverlässig an — deshalb hier direkt als Standard-Terminal gesetzt.
# fonts-noto-cjk behebt die kaputten japanischen Zeichen in Firefox-Tabs (z.B. Toride-Wiki).
# HINWEIS: tailscale ist NICHT in Debians Standard-Repos — braucht eigenes APT-Repo (siehe Schritt 4c).
# SCHLANK GEHALTEN: Bewusst KEIN xfce4-goodies (zieht ~40 ungenutzte Plugins) und KEIN
# task-german-desktop (zieht LibreOffice + GDAL, ~500 MB). Stattdessen nur explizit, was die
# handgebaute Panel-Config wirklich braucht: thunar (FileManager + thunar-tpa-Applet) und
# xfce4-terminal. Panel-Plugins (whiskermenu/clipman/notes) folgen separat in Schritt 12.
echo "🖥️ Lade und konfiguriere XFCE-Desktop & Apps... (☕ Kaffee-Pause!)"
proot-distro login debian -- bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold &&
apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold xfce4 thunar thunar-tpa xfce4-terminal alacritty xterm login dbus-x11 x11-xkb-utils \
  firefox-esr curl wget unzip mousepad fonts-noto-cjk fonts-noto-color-emoji \
  locales gnupg &&
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50 &&
update-alternatives --set x-terminal-emulator /usr/bin/alacritty || true
"

# 4b. Offizielles Tailscale-APT-Repo hinzufügen und installieren (nicht in Debian-Standard-Repos)
echo "🔗 Füge offizielles Tailscale-Repo hinzu und installiere..."
proot-distro login debian -- bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list
apt update
apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold tailscale
"

# 5. Nerd Font (Space Mono) für korrekte Claude Code Symbole installieren
# Quelle: eigenes Repo. Fallback: schlägt der Download fehl, wird übersprungen statt
# das ganze Script abzubrechen (CLI zeigt dann Ersatzschrift, Rest läuft weiter).
echo "🔤 Installiere Space Mono Nerd Font für fehlerfreie CLI-Anzeige..."
proot-distro login debian -- bash -c "
mkdir -p /root/.local/share/fonts
if curl -fLo /tmp/SpaceMono.zip \"$ASSET_BASE/SpaceMono.zip\"; then
  unzip -o /tmp/SpaceMono.zip -d /root/.local/share/fonts/
  fc-cache -f -v
  rm /tmp/SpaceMono.zip
else
  echo '⚠ Space-Mono-Download fehlgeschlagen — überspringe Font (Rest läuft weiter).'
fi
"

# 5b. Font automatisch in Alacritty als Default setzen + Dark Theme
echo "🎨 Setze SpaceMono Nerd Font + Dark Theme automatisch in Alacritty..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/alacritty
cat << 'EOF' > /root/.config/alacritty/alacritty.toml
[font]
size = 11

[font.normal]
family = \"SpaceMono Nerd Font Mono\"
style = \"Regular\"

[font.bold]
family = \"SpaceMono Nerd Font Mono\"
style = \"Bold\"

[font.italic]
family = \"SpaceMono Nerd Font Mono\"
style = \"Italic\"

[window]
padding = { x = 8, y = 8 }
dynamic_title = true

[scrolling]
history = 10000

[cursor]
style = { shape = \"Block\", blinking = \"Off\" }

[colors.primary]
background = \"#1e1e1e\"
foreground = \"#d4d4d4\"
EOF
"

# 6. Claude Code direkt in Debian installieren & PATH setzen
echo "🤖 Installiere Claude Code im Debian-System..."
proot-distro login debian -- bash -c "
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> /root/.bashrc
"

# 6b. Claude Code Theme automatisch auf Dark Mode vorbelegen (kein manuelles Auswählen mehr)
echo "🌑 Setze Claude Code Theme auf Dark Mode..."
proot-distro login debian -- bash -c "
mkdir -p /root/.claude
cat << 'EOF' > /root/.claude/settings.json
{
  \"theme\": \"dark\"
}
EOF
"

# 7. Locale + Tastaturlayout auf Deutsch (Österreich) setzen
# WICHTIG: Nur .bashrc reicht NICHT — das greift nur für interaktive Shells, nicht für die
# grafische XFCE-Session selbst (Panel, Menüs, Anwendungssprache). Daher zusätzlich
# systemweit in /etc/default/locale UND in .xsessionrc setzen, damit die GUI beim Start
# die richtige Locale erhält.
echo "⌨️ Konfiguriere Locale & Tastaturlayout auf de_AT..."
proot-distro login debian -- bash -c "
set -e
sed -i 's/# de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=de_AT.UTF-8 LANGUAGE=de_AT:de LC_ALL=de_AT.UTF-8

cat << 'EOF' > /etc/default/locale
LANG=de_AT.UTF-8
LANGUAGE=de_AT:de
LC_ALL=de_AT.UTF-8
EOF

echo 'export LANG=de_AT.UTF-8' >> /root/.bashrc
echo 'export LANGUAGE=de_AT:de' >> /root/.bashrc
echo 'export LC_ALL=de_AT.UTF-8' >> /root/.bashrc

cat << 'EOF' > /root/.xsessionrc
export LANG=de_AT.UTF-8
export LANGUAGE=de_AT:de
export LC_ALL=de_AT.UTF-8
EOF

mkdir -p /root/.config/autostart
cat << 'EOF' > /root/.config/autostart/setxkbmap.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.94
Type=Application
Name=Keyboard Layout AT
Comment=Set keyboard layout to Austrian German
Exec=setxkbmap at
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF
"

# 8. Nordic GTK+xfwm4 Theme installieren (Nord-Farbpalette, bläulich) — stabiler Release-Download,
# kein Git-Clone/Build nötig. Enthält sowohl GTK3-Theme als auch xfwm4 (Fensterrahmen).
echo "🎨 Installiere Nordic Theme (blau, GTK + Fensterrahmen)..."
proot-distro login debian -- bash -c "
mkdir -p /root/.themes
if curl -fLo /tmp/Nordic.tar.xz \"$ASSET_BASE/Nordic.tar.xz\"; then
  tar -xJf /tmp/Nordic.tar.xz -C /root/.themes
  rm -f /tmp/Nordic.tar.xz
else
  echo '⚠ Nordic-Download fehlgeschlagen — überspringe Theme (Rest läuft weiter).'
fi
"

# 8b. Ecken/Kanten global auf eckig erzwingen (kein Theme ist von Haus aus 100% rundungsfrei)
echo "📐 Erzwinge komplett eckigen, flachen Stil (keine Rundungen/Schatten)..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/gtk-3.0
cat << 'EOF' > /root/.config/gtk-3.0/gtk.css
* {
  border-radius: 0 !important;
  box-shadow: none !important;
  outline-radius: 0 !important;
}
EOF
mkdir -p /root/.config/gtk-4.0
cp /root/.config/gtk-3.0/gtk.css /root/.config/gtk-4.0/gtk.css
"

# 9. Papirus Icon Theme installieren + blaue Ordner-Farbe setzen (statt violet — Konsistenz mit
# Nordic-Theme und Bibata-Cursor, damit die gesamte Optik stimmig bläulich ist)
# Die Icons kommen per apt (stabil wie Debian selbst). Nur das kleine 'papirus-folders'-Script
# (zum Umfärben der Ordner) kommt aus dem eigenen Repo — der alte git.io-Installer ist tot und
# brauchte zudem wget. Fällt der Download aus, bleiben die Ordner einfach in Standardfarbe.
echo "🎨 Installiere Papirus Icon Theme mit blauen Ordnern..."
proot-distro login debian -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold papirus-icon-theme
if curl -fLo /usr/bin/papirus-folders \"$ASSET_BASE/papirus-folders\"; then
  chmod +x /usr/bin/papirus-folders
  papirus-folders -C blue --theme Papirus-Dark
else
  echo '⚠ papirus-folders-Download fehlgeschlagen — Ordner bleiben in Standardfarbe (Rest läuft weiter).'
fi
"

# 10. Bibata Modern Ice Cursor aus eigenem Repo installieren (weiß, abgerundete Kanten)
# Format .tar.xz (kleiner als .tar.gz). Fällt der Download aus, bleibt der Standard-Cursor.
echo "🖱️ Installiere Bibata Modern Ice Cursor..."
proot-distro login debian -- bash -c "
mkdir -p /root/.icons /root/.local/share/icons
if curl -fLo /tmp/Bibata-Modern-Ice.tar.xz \"$ASSET_BASE/Bibata-Modern-Ice.tar.xz\"; then
  tar -xJf /tmp/Bibata-Modern-Ice.tar.xz -C /tmp
  cp -r /tmp/Bibata-Modern-Ice /root/.icons/
  cp -r /tmp/Bibata-Modern-Ice /root/.local/share/icons/
  rm -rf /tmp/Bibata-Modern-Ice /tmp/Bibata-Modern-Ice.tar.xz
else
  echo '⚠ Bibata-Download fehlgeschlagen — Standard-Cursor bleibt (Rest läuft weiter).'
fi
"

# 11. XFCE systemweit auf Nordic-Theme + Papirus-Icons + Bibata-Cursor setzen.
# HINWEIS: Kein automatisches Wallpaper mehr — Standard-XFCE-Wallpaper bleibt bestehen.
# Desktop-Icons komplett deaktiviert (leerer Desktop).
echo "🌑 Setze XFCE-Theme, Icons, Cursor, Desktop-Icons aus..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
cat << 'EOF' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xsettings\" version=\"1.0\">
  <property name=\"Net\" type=\"empty\">
    <property name=\"ThemeName\" type=\"string\" value=\"Nordic\"/>
    <property name=\"IconThemeName\" type=\"string\" value=\"Papirus-Dark\"/>
  </property>
  <property name=\"Gtk\" type=\"empty\">
    <property name=\"CursorThemeName\" type=\"string\" value=\"Bibata-Modern-Ice\"/>
    <property name=\"CursorThemeSize\" type=\"int\" value=\"32\"/>
  </property>
</channel>
EOF
cat << 'EOF' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfwm4\" version=\"1.0\">
  <property name=\"general\" type=\"empty\">
    <property name=\"theme\" type=\"string\" value=\"Nordic\"/>
  </property>
</channel>
EOF
cat << 'EOF' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfce4-desktop\" version=\"1.0\">
  <property name=\"desktop-icons\" type=\"empty\">
    <property name=\"style\" type=\"int\" value=\"0\"/>
  </property>
</channel>
EOF
"

# 12. Whisker-Menu-Plugin + Clipman + Notes installieren (werden von der Panel-Config referenziert
# — müssen VOR der Panel-Config installiert sein, sonst kennt XFCE die Plugin-Typen nicht)
echo "📦 Installiere Whisker-Menu, Clipman, Notes-Plugin für Panel..."
proot-distro login debian -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
  xfce4-whiskermenu-plugin xfce4-clipman-plugin xfce4-notes-plugin
"

# 13. Panel-Konfiguration: EXAKTE, händisch gebaute Config des Users, 1:1 übernommen.
# Whisker-Menu, 4 Launcher (FileManager/WebBrowser/TerminalEmulator/Notes via exo-open),
# Clipman, mehrere einzelne Uhr-Widgets (Stunde/Minute/Tag/Datum/Jahr getrennt).
# WICHTIG: Die Launcher nutzen exo-open, das die konfigurierten Standardanwendungen öffnet —
# daher werden diese zusätzlich fest auf Thunar/Firefox/Alacritty gesetzt (Schritt 13b),
# sonst laufen die Launcher ins Leere.
echo "📌 Konfiguriere Panel (händisch gebaute Config, 1:1 übernommen)..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
cat << 'EOF' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<channel name=\"xfce4-panel\" version=\"1.0\">
  <property name=\"panels\" type=\"array\">
    <value type=\"int\" value=\"1\"/>
  </property>
  <property name=\"panel-1\" type=\"empty\">
    <property name=\"position\" type=\"string\" value=\"p=6;x=30;y=540\"/>
    <property name=\"size\" type=\"uint\" value=\"48\"/>
    <property name=\"mode\" type=\"uint\" value=\"2\"/>
    <property name=\"length\" type=\"double\" value=\"100\"/>
    <property name=\"position-locked\" type=\"bool\" value=\"true\"/>
    <property name=\"length-adjust\" type=\"bool\" value=\"true\"/>
    <property name=\"background-style\" type=\"uint\" value=\"0\"/>
    <property name=\"plugin-ids\" type=\"array\">
      <value type=\"int\" value=\"25\"/>
      <value type=\"int\" value=\"2\"/>
      <value type=\"int\" value=\"26\"/>
      <value type=\"int\" value=\"3\"/>
      <value type=\"int\" value=\"13\"/>
      <value type=\"int\" value=\"4\"/>
      <value type=\"int\" value=\"5\"/>
      <value type=\"int\" value=\"6\"/>
      <value type=\"int\" value=\"7\"/>
      <value type=\"int\" value=\"8\"/>
      <value type=\"int\" value=\"22\"/>
      <value type=\"int\" value=\"21\"/>
      <value type=\"int\" value=\"11\"/>
      <value type=\"int\" value=\"9\"/>
      <value type=\"int\" value=\"12\"/>
      <value type=\"int\" value=\"19\"/>
      <value type=\"int\" value=\"14\"/>
      <value type=\"int\" value=\"27\"/>
      <value type=\"int\" value=\"20\"/>
      <value type=\"int\" value=\"28\"/>
      <value type=\"int\" value=\"29\"/>
      <value type=\"int\" value=\"30\"/>
      <value type=\"int\" value=\"17\"/>
    </property>
    <property name=\"nrows\" type=\"uint\" value=\"1\"/>
    <property name=\"border-width\" type=\"uint\" value=\"0\"/>
  </property>
  <property name=\"dark-mode\" type=\"bool\" value=\"true\"/>
  <property name=\"plugins\" type=\"empty\">
    <property name=\"plugin-2\" type=\"string\" value=\"whiskermenu\">
      <property name=\"recent\" type=\"array\">
        <value type=\"string\" value=\"xfce-wmtweaks-settings.desktop\"/>
      </property>
      <property name=\"show-button-icon\" type=\"bool\" value=\"true\"/>
      <property name=\"show-button-title\" type=\"bool\" value=\"false\"/>
      <property name=\"profile-shape\" type=\"int\" value=\"1\"/>
      <property name=\"position-categories-alternate\" type=\"bool\" value=\"true\"/>
      <property name=\"position-profile-alternate\" type=\"bool\" value=\"true\"/>
      <property name=\"button-single-row\" type=\"bool\" value=\"false\"/>
      <property name=\"button-icon\" type=\"string\" value=\"skullgirls\"/>
      <property name=\"view-mode\" type=\"int\" value=\"0\"/>
      <property name=\"launcher-show-name\" type=\"bool\" value=\"true\"/>
      <property name=\"default-category\" type=\"int\" value=\"2\"/>
      <property name=\"position-search-alternate\" type=\"bool\" value=\"true\"/>
    </property>
    <property name=\"plugin-3\" type=\"string\" value=\"separator\"/>
    <property name=\"plugin-4\" type=\"string\" value=\"launcher\">
      <property name=\"items\" type=\"array\">
        <value type=\"string\" value=\"17837956301.desktop\"/>
      </property>
    </property>
    <property name=\"plugin-5\" type=\"string\" value=\"launcher\">
      <property name=\"items\" type=\"array\">
        <value type=\"string\" value=\"17837956322.desktop\"/>
      </property>
    </property>
    <property name=\"plugin-6\" type=\"string\" value=\"launcher\">
      <property name=\"items\" type=\"array\">
        <value type=\"string\" value=\"17837956343.desktop\"/>
      </property>
    </property>
    <property name=\"plugin-7\" type=\"string\" value=\"launcher\">
      <property name=\"items\" type=\"array\">
        <value type=\"string\" value=\"17837956404.desktop\"/>
      </property>
    </property>
    <property name=\"plugin-8\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
      <property name=\"expand\" type=\"bool\" value=\"true\"/>
    </property>
    <property name=\"plugin-9\" type=\"string\" value=\"thunar-tpa\"/>
    <property name=\"plugin-11\" type=\"string\" value=\"xfce4-clipman-plugin\"/>
    <property name=\"plugin-12\" type=\"string\" value=\"separator\"/>
    <property name=\"plugin-13\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-14\" type=\"string\" value=\"clock\">
      <property name=\"mode\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-layout\" type=\"uint\" value=\"3\"/>
      <property name=\"digital-date-format\" type=\"string\" value=\"%a., %d.%m.\"/>
      <property name=\"digital-time-font\" type=\"string\" value=\"SpaceMono Nerd Font 18\"/>
      <property name=\"digital-date-font\" type=\"string\" value=\"SpaceMono Nerd Font Medium 8\"/>
      <property name=\"digital-time-format\" type=\"string\" value=\"%H\"/>
    </property>
    <property name=\"plugin-17\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-19\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-20\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-21\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-22\" type=\"string\" value=\"separator\"/>
    <property name=\"plugin-25\" type=\"string\" value=\"separator\">
      <property name=\"style\" type=\"uint\" value=\"0\"/>
      <property name=\"expand\" type=\"bool\" value=\"false\"/>
    </property>
    <property name=\"plugin-26\" type=\"string\" value=\"separator\">
      <property name=\"expand\" type=\"bool\" value=\"false\"/>
      <property name=\"style\" type=\"uint\" value=\"0\"/>
    </property>
    <property name=\"plugin-27\" type=\"string\" value=\"clock\">
      <property name=\"mode\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-layout\" type=\"uint\" value=\"3\"/>
      <property name=\"digital-time-format\" type=\"string\" value=\"%M\"/>
      <property name=\"digital-time-font\" type=\"string\" value=\"SpaceMono Nerd Font 18\"/>
    </property>
    <property name=\"plugin-28\" type=\"string\" value=\"clock\">
      <property name=\"mode\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-layout\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-date-font\" type=\"string\" value=\"SpaceMono Nerd Font Mono 14\"/>
      <property name=\"digital-date-format\" type=\"string\" value=\"%a\"/>
    </property>
    <property name=\"plugin-29\" type=\"string\" value=\"clock\">
      <property name=\"mode\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-layout\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-date-font\" type=\"string\" value=\"SpaceMono Nerd Font Mono 10\"/>
      <property name=\"digital-date-format\" type=\"string\" value=\"%d.%m\"/>
    </property>
    <property name=\"plugin-30\" type=\"string\" value=\"clock\">
      <property name=\"mode\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-layout\" type=\"uint\" value=\"2\"/>
      <property name=\"digital-date-format\" type=\"string\" value=\"%Y\"/>
      <property name=\"digital-date-font\" type=\"string\" value=\"SpaceMono Nerd Font Mono 11\"/>
    </property>
  </property>
  <property name=\"configver\" type=\"int\" value=\"2\"/>
</channel>
EOF

mkdir -p /root/.config/xfce4/panel/launcher-4
cat << 'EOF' > /root/.config/xfce4/panel/launcher-4/17837956301.desktop
[Desktop Entry]
Version=1.0
Type=Application
Exec=exo-open --launch FileManager %u
Icon=org.xfce.filemanager
StartupNotify=true
Terminal=false
Categories=Utility;X-XFCE;X-Xfce-Toplevel;
Keywords=file;manager;explorer;browse;filesystem;directory;folder;xfce;
OnlyShowIn=XFCE;
X-XFCE-MimeType=inode/directory;x-scheme-handler/trash;
X-AppStream-Ignore=True
Name=File Manager
Comment=Browse the file system
X-XFCE-Source=file:///usr/share/applications/xfce4-file-manager.desktop
EOF

mkdir -p /root/.config/xfce4/panel/launcher-5
cat << 'EOF' > /root/.config/xfce4/panel/launcher-5/17837956322.desktop
[Desktop Entry]
Version=1.0
Type=Application
Exec=exo-open --launch WebBrowser %u
Icon=org.xfce.webbrowser
StartupNotify=true
Terminal=false
Categories=Network;X-XFCE;X-Xfce-Toplevel;
Keywords=internet;web;browser;surf;explore;xfce;
OnlyShowIn=XFCE;
X-XFCE-MimeType=x-scheme-handler/http;x-scheme-handler/https;
X-AppStream-Ignore=True
Name=Web Browser
Comment=Browse the web
X-XFCE-Source=file:///usr/share/applications/xfce4-web-browser.desktop
EOF

mkdir -p /root/.config/xfce4/panel/launcher-6
cat << 'EOF' > /root/.config/xfce4/panel/launcher-6/17837956343.desktop
[Desktop Entry]
Version=1.0
Type=Application
Exec=exo-open --launch TerminalEmulator
Icon=org.xfce.terminalemulator
StartupNotify=true
Terminal=false
Categories=Utility;X-XFCE;X-Xfce-Toplevel;
Keywords=terminal;command line;shell;console;xfce;
OnlyShowIn=XFCE;
X-AppStream-Ignore=True
Name=Terminal Emulator
Comment=Use the command line
X-XFCE-Source=file:///usr/share/applications/xfce4-terminal-emulator.desktop
EOF

mkdir -p /root/.config/xfce4/panel/launcher-7
cat << 'EOF' > /root/.config/xfce4/panel/launcher-7/17837956404.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Notes
Comment=Ideal for your quick notes
TryExec=xfce4-notes
Exec=xfce4-notes
Icon=org.xfce.notes
Terminal=false
Categories=GTK;Utility;TrayIcon;
OnlyShowIn=XFCE;GNOME;
StartupNotify=false
X-XFCE-Source=file:///usr/share/applications/xfce4-notes.desktop
EOF
"

# 13b. Standardanwendungen fest setzen, da die Panel-Launcher via exo-open die konfigurierten
# Standardanwendungen öffnen (nicht direkt Thunar/Firefox/Alacritty aufrufen)
echo "🔧 Setze Standardanwendungen (FileManager=Thunar, WebBrowser=Firefox, Terminal=Alacritty)..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/xfce4
cat << 'EOF' > /root/.config/xfce4/helpers.rc
FileManager=thunar
WebBrowser=firefox-esr
TerminalEmulator=alacritty
EOF
"

# 14. Xarchiver (Archiv-Manager) installieren
echo "📦 Installiere Xarchiver..."
proot-distro login debian -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold xarchiver
"

# 15. Tailscale-Autostart einrichten (userspace-networking, kein TUN-Zugriff in proot möglich)
# WICHTIG: Login-Schritt (OAuth im Browser) bleibt einmalig manuell nötig — kann nicht
# automatisiert werden, da Tailscale das aus Sicherheitsgründen erfordert.
echo "🔗 Richte Tailscale-Autostart ein (userspace-networking + SOCKS5-Proxy)..."
proot-distro login debian -- bash -c "
mkdir -p /root/.config/autostart
cat << 'EOF' > /root/start-tailscale.sh
#!/bin/bash
# Tailscale im Hintergrund starten (kein systemd in proot verfügbar)
mkdir -p /var/lib/tailscale /var/run/tailscale
if ! pgrep -x tailscaled > /dev/null; then
  nohup tailscaled \\
    --state=/var/lib/tailscale/tailscaled.state \\
    --socket=/var/run/tailscale/tailscaled.sock \\
    --tun=userspace-networking \\
    --socks5-server=localhost:1055 \\
    --outbound-http-proxy-listen=localhost:1055 \\
    > /var/log/tailscaled.log 2>&1 &
  sleep 2
fi
if ! tailscale status > /dev/null 2>&1; then
  echo 'Tailscale läuft, aber noch nicht eingeloggt.'
  echo 'Bitte einmalig ausführen: tailscale up'
fi
EOF
chmod +x /root/start-tailscale.sh

cat << 'EOF' > /root/.config/autostart/tailscale.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.94
Type=Application
Name=Tailscale Autostart
Comment=Startet tailscaled im Hintergrund mit SOCKS5-Proxy
Exec=/root/start-tailscale.sh
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF

if ! grep -q 'ALL_PROXY=socks5h://localhost:1055' /root/.bashrc; then
  cat << 'EOF' >> /root/.bashrc

# Tailscale SOCKS5-Proxy für CLI-Tools (userspace-networking, kein TUN in proot)
export ALL_PROXY=socks5h://localhost:1055
export HTTPS_PROXY=socks5h://localhost:1055
export HTTP_PROXY=socks5h://localhost:1055
export NO_PROXY=localhost,127.0.0.1
EOF
fi
"

# 15b. Firefox SOCKS5-Proxy-Config vorbereiten (Profil wird beim ersten Start erzeugt,
# daher als Script, das das Profil danach patcht statt es fest zu verdrahten)
echo "🦊 Bereite Firefox-Proxy-Konfiguration vor (Profil-Pfad ändert sich pro Setup)..."
proot-distro login debian -- bash -c "
cat << 'EOF' > /root/configure-firefox-proxy.sh
#!/bin/bash
PROFILE_DIR=\$(find /root/.mozilla/firefox -maxdepth 1 -name '*.default-esr' 2>/dev/null | head -1)
if [ -z \"\$PROFILE_DIR\" ]; then
  echo 'Kein Firefox-Profil gefunden. Firefox bitte einmal öffnen und dann dieses Script erneut ausführen.'
  exit 1
fi
cat << 'PROXYEOF' >> \"\$PROFILE_DIR/user.js\"
user_pref(\"network.proxy.type\", 1);
user_pref(\"network.proxy.socks\", \"localhost\");
user_pref(\"network.proxy.socks_port\", 1055);
user_pref(\"network.proxy.socks_version\", 5);
user_pref(\"network.proxy.socks_remote_dns\", true);
user_pref(\"network.proxy.no_proxies_on\", \"localhost, 127.0.0.1\");
PROXYEOF
echo 'Firefox-Proxy-Config gesetzt in: '\$PROFILE_DIR
EOF
chmod +x /root/configure-firefox-proxy.sh
"

# 16. termux-setup-storage ausführen (einmalige Android-Berechtigung für Speicherzugriff)
echo "📂 Richte Android-Speicherzugriff ein (Berechtigung wird gleich abgefragt)..."
termux-setup-storage

# 17. Den Alias 'linuxdesk' in die Termux-.bashrc schreiben (mit Android-Storage-Bind-Mount)
echo "⚙️ Richte den Start-Alias 'linuxdesk' ein..."
if ! grep -q "alias linuxdesk=" ~/.bashrc; then
    echo "alias linuxdesk='termux-x11 :1 -xstartup \"proot-distro login debian --shared-tmp -b ~/storage/shared:/root/android-storage -- env DISPLAY=:1 xfce4-session\"'" >> ~/.bashrc
fi

# 18. Direkt das Termux:Widget Skript mit anlegen (ebenfalls mit Android-Storage-Bind-Mount)
echo "📱 Richte den Homescreen-Shortcut ein..."
mkdir -p ~/.shortcuts
cat << 'EOF' > ~/.shortcuts/linuxdesk.sh
#!/data/data/com.termux/files/usr/bin/bash
termux-x11 :1 -xstartup "proot-distro login debian --shared-tmp -b ~/storage/shared:/root/android-storage -- env DISPLAY=:1 xfce4-session"
EOF
chmod +x ~/.shortcuts/linuxdesk.sh

echo "================================================="
echo "✅ BOOM! All-in-One Umgebung erfolgreich eingerichtet!"
echo "================================================="
echo "Führe zuerst aus: source ~/.bashrc"
echo "Danach kannst du mit 'linuxdesk' oder dem Widget deine GUI starten."
echo ""
echo "💡 Was automatisch lief:"
echo "   ✓ Alacritty als Standard-Terminal, JetBrains Nerd Font, Dark Theme"
echo "   ✓ Claude Code auf Dark Mode vorkonfiguriert"
echo "   ✓ Nordic Theme (blau) für GTK + Fensterrahmen, komplett eckig (keine Rundungen)"
echo "   ✓ Papirus Icon Theme mit blauen Ordnern"
echo "   ✓ Bibata Modern Ice Cursor (weiß, Größe 32)"
echo "   ✓ Desktop-Icons deaktiviert (leerer Desktop), Standard-Wallpaper bleibt"
echo "   ✓ Panel: Whisker-Menu, Dateimanager/Browser/Terminal/Notes-Launcher, Clipman, Papierkorb, mehrteilige Uhr (exakt deine händische Config)"
echo "   ✓ Xarchiver installiert"
echo "   ✓ Android-Speicher unter /root/android-storage in Debian verfügbar"
echo "   ✓ Locale + Tastatur + XFCE-Oberfläche auf Deutsch (Österreich)"
echo "   ✓ Japanische Schriften (fonts-noto-cjk) — Toride-Wiki sollte jetzt korrekt anzeigen"
echo "   ✓ Tailscale-Autostart eingerichtet (SOCKS5-Proxy auf Port 1055)"
echo ""
echo "⚠️  EINMALIGE MANUELLE SCHRITTE (nicht automatisierbar):"
echo "   1. In XFCE ein Terminal öffnen und ausführen: tailscale up"
echo "      → Link im Firefox öffnen, im Browser einloggen/bestätigen"
echo "   2. Danach Firefox einmal öffnen (damit ein Profil existiert)"
echo "   3. Dann ausführen: /root/configure-firefox-proxy.sh"
echo "      → Danach Firefox neu starten, MagicDNS-Namen (*.ts.net) funktionieren dann"
echo "   4. In der Termux:X11-App (nicht Termux selbst) unter Keyboard-Einstellungen:"
echo "      'Intercept system shortcuts' UND 'Prefer scancodes when possible' aktivieren"
echo "      → Behebt fehlende Tastenkürzel (Strg/Alt/Meta-Kombis), die sonst von Android"
echo "        abgefangen werden statt an X11 durchgereicht zu werden. Nicht automatisierbar,"
echo "        da App-eigene UI-Einstellung von Termux:X11."
