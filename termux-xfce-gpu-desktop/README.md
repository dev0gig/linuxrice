# Termux XFCE GPU Desktop

Natives Linux-Desktop-Setup auf Android via Termux — kein proot-distro, kein Debian-Chroot. XFCE läuft direkt in Termux, mit GPU-Beschleunigung über Zink/turnip (Vulkan) statt reinem Software-Rendering.

Getestet auf: Samsung Galaxy Z Fold 7 (Snapdragon / Adreno GPU).

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-xfce-gpu-desktop/setup_termux_desktop.sh | bash
```

Lädt das Setup-Skript direkt von GitHub und führt es aus. Danach `source ~/.bashrc` und `xfce` zum Starten.

`rice.sh` liegt dabei noch nicht lokal vor — entweder das ganze Repo klonen (siehe [Installation](#installation)), oder gezielt nachladen:

```bash
curl -fsSLO https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-xfce-gpu-desktop/rice.sh
chmod +x rice.sh
```

## Was das hier ist

Zwei Skripte, zwei Zwecke:

- **`setup_termux_desktop.sh`** — einmaliges Grundsetup. Installiert XFCE, GPU-Treiber, Rofi als App-Launcher, richtet Aliase ein. Läuft in Termux, bevor der Desktop überhaupt existiert.
- **`rice.sh`** — Kosmetik und Feintuning. Icons, Font, Cursor, Wallpaper, Dark-Theme, Maus-Verhalten, minimales Panel. Läuft **innerhalb** des laufenden Desktops (braucht einen aktiven X-Server), deshalb separat und manuell auszuführen.

## Features

- **GPU-Beschleunigung**: Zink (OpenGL-über-Vulkan) auf turnip (nativer Adreno-Vulkan-Treiber), statt `llvmpipe`-Software-Rendering
- **Kein Standard-Panel**: XFCE startet komplett ohne obere/untere Taskleiste — voller Fokus-Screen
- **Panel-Config übersteht den Neustart**: die Einstellungen liegen als Vorlage bereit und werden bei jedem Start wieder eingespielt (siehe [Warum die Panel-Config früher weg war](#warum-die-panel-config-früher-nach-jedem-neustart-weg-war))
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

## Warum die Panel-Config früher nach jedem Neustart weg war

Das war lange der nervigste Bug hier, darum kurz erklärt — er ist nicht offensichtlich:

XFCE liest seine Einstellungen **nicht** direkt aus den XML-Dateien. Dazwischen sitzt
ein Dienst namens `xfconfd`, der alle Einstellungen im Speicher hält. Die Konfigdatei
liest er nur **einmal** beim Start; danach ist *er* für XFCE die einzige Wahrheit.

Daraus folgen drei Fallen:

1. **Datei umschreiben wirkt nicht.** Schreibt ein Skript die `xfce4-panel.xml` neu,
   während `xfconfd` läuft, merkt der Dienst davon nichts — XFCE arbeitet weiter mit
   dem alten Stand aus dem Speicher.
2. **`xfconfd` schreibt beim Beenden zurück.** Wird er normal beendet (SIGTERM), kippt
   er seinen Speicherstand über die Dateien — eine vorher frisch geschriebene Datei ist
   damit wieder kaputt.
3. **Mit `killall -9` ist alles Ungespeicherte weg.** Alles, was per `xfconf-query`
   gesetzt wurde (Wallpaper, Theme, Icons, Maus), liegt nur im Speicher — auf die Platte
   kommt es praktisch erst beim sauberen Beenden. Wer `xfconfd` hart abschießt, wirft
   diese Einstellungen weg.

Unter Termux kommt dazu, dass `xfconfd` einen X11-Neustart oft **überlebt** (Android
würgt die Sitzung im Hintergrund ab, die Termux-Shell und der D-Bus laufen weiter).
Dann gilt weiter der alte Stand, und die Panel-Config war nach jedem Neustart wieder weg.

**Die Lösung besteht aus zwei Teilen:**

- Die Wunsch-Konfiguration liegt als **Vorlage** in `~/.config/xfce4/panel-template.xml`.
- `start-desktop.sh` und `rice.sh` gehen beide in dieser Reihenfolge vor:
  1. `xfconfd` **normal** beenden (`killall xfconfd`, ohne `-9`) — dabei schreibt er
     Wallpaper, Theme und Icons brav auf die Platte,
  2. **danach** die Vorlage über die `xfce4-panel.xml` kopieren — das überschreibt den
     alten Panel-Stand, den er in Schritt 1 mit rausgeschrieben hat,
  3. dann `killall -9 xfconfd`, damit er die frische Panel-Datei sicher neu liest. Das
     ist jetzt gefahrlos, weil alles Wertvolle schon auf der Platte liegt.

Diese Reihenfolge ist wirklich wichtig: dreht man 1 und 2, gewinnt der alte Panel-Stand.
Lässt man Schritt 1 weg und schießt gleich hart ab, verschwindet das Wallpaper.

Wer das Panel ändern will, ändert also `rice.sh` (bzw. direkt die Vorlage) — nicht die
`xfce4-panel.xml`, die wird bei jedem Start überschrieben.

Nebenbei: `xfce4-panel --quit` wird hier absichtlich **nicht** benutzt — der Aufruf
bleibt unter Termux-X11 ohne Session-Manager hängen. Stattdessen `killall -9 xfce4-panel`.

## Bekannte Einschränkungen

- Zink/turnip auf Termux-X11 ist kein offiziell unterstützter Pfad — kann bei Mesa- oder Termux-X11-Updates brechen
- Chromium zeigt Rendering-Flackern bei Modals unter Termux-X11 (Ursache: Compositor/Redraw-Zyklen bei Mausbewegung, nicht durch GPU-Flags behebbar) — deshalb Firefox als Standard-Browser
- Die Panel-Position rechnet `rice.sh` aus der aktuellen Bildschirmgröße (rechter Rand,
  vertikal mittig). Wechselt die Auflösung dauerhaft — beim Fold z.B. innen/außen —,
  einmal `./rice.sh` erneut laufen lassen, damit die Vorlage neu berechnet wird.

## Rollback

Bei schwarzem Bildschirm oder kaputter Session:

```bash
rm -rf ~/.cache/sessions
rm -rf ~/.config/xfce4/panel
```

Danach `xfce` neu starten.

Wenn das Panel spinnt, hilft fast immer der harte Weg — Dienst beenden, Vorlage
zurückkopieren:

```bash
killall xfconfd; sleep 3          # ohne -9, damit Wallpaper/Theme erhalten bleiben
cp -f ~/.config/xfce4/panel-template.xml \
      ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
killall -9 xfconfd xfce4-panel
xfce4-panel &
```
