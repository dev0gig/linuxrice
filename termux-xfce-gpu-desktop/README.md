# Termux XFCE GPU Desktop

Natives Linux-Desktop-Setup auf Android via Termux — kein proot-distro, kein Debian-Chroot. XFCE läuft direkt in Termux, mit GPU-Beschleunigung über Zink/turnip (Vulkan) statt reinem Software-Rendering.

Getestet auf: Samsung Galaxy Z Fold 7 (Snapdragon / Adreno GPU).

## Was das hier ist

Zwei Skripte, zwei Zwecke:

- **`setup_termux_desktop.sh`** — einmaliges Grundsetup. Installiert XFCE, GPU-Treiber, Rofi als App-Launcher, richtet Aliase ein. Läuft in Termux, bevor der Desktop überhaupt existiert.
- **`rice.sh`** — Kosmetik und Feintuning. Icons, Font, Cursor, Wallpaper, Dark-Theme, Maus-Verhalten, minimales Panel. Läuft **innerhalb** des laufenden Desktops (braucht einen aktiven X-Server), deshalb separat und manuell auszuführen.

## Features

- **GPU-Beschleunigung**: Zink (OpenGL-über-Vulkan) auf turnip (nativer Adreno-Vulkan-Treiber), statt `llvmpipe`-Software-Rendering
- **Kein Standard-Panel**: XFCE startet komplett ohne obere/untere Taskleiste — voller Fokus-Screen
- **Rofi als App-Launcher**: `Super + Space` öffnet eine mittig zentrierte App-Suche (über `sxhkd`, nicht über XFCE-eigene Shortcuts — zuverlässiger)
- **Minimales Seiten-Panel** (via `rice.sh`): schmale, transparente Taskleiste rechts, vertikal mittig, nur laufende Fenster — kein Schatten, kein Rest-Chrome
- **Dark Mode**: Arc-Dark GTK-Theme, Papirus-Dark Icons, Red Hat Mono Font
- **Direktere Maus**: Beschleunigung deaktiviert, größerer Cursor (Bibata-Modern-Ice, 32px)
- **Kein Desktop-Icon-Clutter**
- **Firefox statt Chromium**: Chromium hatte unter Termux-X11 hartnäckiges Flackern bei Modal-Dialogen (Compositor-/Redraw-Problem, nicht GPU-bedingt) — Firefox läuft stabil
- **Chromium-freie Umgebung**: falls du Chromium doch brauchst, ist es nicht Teil des Standard-Setups mehr
- **OpenSSH**: Client + Server vorinstalliert

## Installation

### 1. Grundsetup (in Termux, vor dem ersten Desktop-Start)

```bash
chmod +x setup_termux_desktop.sh
./setup_termux_desktop.sh
source ~/.bashrc
```

### 2. Desktop starten

```bash
xfce
```

Startet Termux-X11, setzt die GPU-Umgebungsvariablen, startet `sxhkd` (für Rofi-Hotkey) und XFCE.

### 3. Rice-Setup (einmalig, im Desktop-Terminal)

Terminal im Desktop öffnen (`Super + Space` → „xterm" oder „mousepad" tippen zum Testen, dass Rofi läuft), dann:

```bash
chmod +x rice.sh
./rice.sh
```

Lädt Font/Cursor/Wallpaper herunter, setzt Theme, Panel-Config, Maus-Verhalten. Idempotent — kann gefahrlos erneut ausgeführt werden.

## Alltag

| Aktion | Befehl / Geste |
|---|---|
| Desktop starten | `xfce` |
| App-Suche öffnen | `Super + Space` |
| Browser | Firefox (über Rofi oder `firefox &`) |
| Texteditor | Mousepad (über Rofi oder `mousepad &`) |
| Taskmanager | `xfce4-taskmanager` |

## Bekannte Einschränkungen

- Zink/turnip auf Termux-X11 ist kein offiziell unterstützter Pfad — kann bei Mesa- oder Termux-X11-Updates brechen
- Chromium zeigt Rendering-Flackern bei Modals unter Termux-X11 (Ursache: Compositor/Redraw-Zyklen bei Mausbewegung, nicht durch GPU-Flags behebbar) — deshalb Firefox als Standard-Browser
- Panel-Position ist auf die getestete Bildschirmauflösung zugeschnitten (`x=1901;y=530`) — bei anderen Auflösungen ggf. in `rice.sh` anpassen

## Rollback

Bei schwarzem Bildschirm oder kaputter Session:

```bash
rm -rf ~/.cache/sessions
rm -rf ~/.config/xfce4/panel
```

Danach `xfce` neu starten.
