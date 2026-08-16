# Termux XFCE GPU Desktop

> **📦 ARCHIV — seit 16.8.2026 nicht mehr in Benutzung.**
> Abgelöst durch [`termux-i3-minimal`](../termux-i3-minimal/). Nach einer Woche
> im Alltag zeigte sich, dass von diesem Desktop nur zwei Programme benutzt
> wurden: Firefox und ein Terminal. Der ganze Unterbau war Ballast, und der
> Einstellungsdienst `xfconfd` war eine dauerhafte Fehlerquelle.
>
> **Dieser Ordner bleibt trotzdem stehen** — wegen zweier Untersuchungen, die
> weiterhin gelten und im i3-Setup verlinkt sind:
> [warum Firefox trotz Turnip auf Software rendert](#warum-firefox-trotz-turnip-auf-software-rendert)
> und [warum die Panel-Config immer verschwand](#warum-die-panel-config-früher-nach-jedem-neustart-weg-war).

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
- **Minimales Seiten-Panel** (via `rice.sh`): schmale, dunkle Taskleiste rechts, vertikal mittig, nur laufende Fenster — kein Schatten, kein Rest-Chrome
- **Compositing aus**: bewusst abgeschaltet, weil Modal-Dialoge im Browser sonst ruckeln (siehe [Warum Firefox trotz Turnip auf Software rendert](#warum-firefox-trotz-turnip-auf-software-rendert)) — der Preis ist ein undurchsichtiges statt transparentes Panel
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
| App-Suche öffnen | `Super + Space` **oder** `Ctrl + Alt + Space` |
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

## Warum Firefox trotz Turnip auf Software rendert

Kurzfassung: **Der Desktop nutzt die GPU, Firefox nicht — und das ist nicht zu ändern.**
Ausführlich hier, damit diese Diagnose kein zweites Mal geführt werden muss.

`about:support` zeigt in Firefox unter *Compositing* dauerhaft `WebRender (Software)`.
Im Failure Log steht:

```
Failed[3] to create EGL library display: FEATURE_FAILURE_NO_DISPLAY
GLContextEGL::FindVisual(): Failed to load EGL library!
Failed GL context creation for hardware WebRender: true
Fallback WR to SW-WR
```

Firefox bekommt also über **EGL** keinen Display. Das ist deshalb bitter, weil die
GPU nachweislich läuft — `glxinfo -B` meldet:

```
OpenGL renderer string: zink Vulkan 1.4(Adreno (TM) 830 (MESA_TURNIP))
OpenGL version string: 4.6 (Compatibility Profile) Mesa 26.0.6
```

Der Haken: `glxinfo` spricht **GLX**, Firefox spricht **EGL**. GLX funktioniert hier,
EGL nicht. Und Mozilla hat den GLX-Pfad aus Firefox entfernt — unter X11 gibt es nur
noch EGL. `MOZ_X11_EGL=0` greift deshalb nicht mehr, der Fehler bleibt identisch.

### Was alles geprüft und ausgeschlossen wurde (16.8.2026)

Jede einzelne Voraussetzung ist erfüllt — deswegen ist unklar, woran es am Ende hängt:

| Verdacht | Prüfung | Ergebnis |
|---|---|---|
| GPU/Treiber fehlt | `glxinfo -B` | ❌ widerlegt — Turnip auf Adreno 830, OpenGL 4.6 |
| EGL-Bibliotheken fehlen | `ls $PREFIX/lib \| grep -i egl` | ❌ widerlegt — `libEGL.so.1`, `libEGL_mesa.so.0` da |
| Mesa kann kein EGL-auf-X11 | `strings libEGL_mesa.so.0 \| grep platform_` | ❌ widerlegt — `EGL_EXT_platform_x11` vorhanden |
| libglvnd findet den Treiber nicht | `share/glvnd/egl_vendor.d/50_mesa.json` | ❌ widerlegt — Datei da und korrekt |
| X-Server ohne DRI3/Present | `xdpyinfo \| grep -iE 'DRI\|Present'` | ❌ widerlegt — `DRI3`, `MIT-SHM`, `Present` da |
| Falscher EGL-Plattform-Default | `EGL_PLATFORM=x11 firefox` | ❌ ohne Wirkung |
| Firefox-Blocklist | `EGL_LOG_LEVEL=debug firefox` | ❌ ohne Erkenntnis, weiterhin Software |

**Fazit:** Nicht weiter dran arbeiten. Der Aufwand steht in keinem Verhältnis — und
mit abgeschaltetem Compositing (siehe unten) ist das eigentliche Problem, ruckelnde
Modals, ohnehin gelöst.

### Was stattdessen hilft

1. **Compositing aus** — macht `rice.sh` inzwischen selbst. Messbarer Effekt auf die
   Flüssigkeit von Modal-Dialogen. Der Preis: keine Fenster-Transparenz mehr.
2. **Auf der Webseite kein `backdrop-filter: blur()`** — das ist die mit Abstand
   teuerste CSS-Eigenschaft und muss ohne GPU jeden Bildpunkt des Hintergrunds pro
   Einzelbild auf der CPU anfassen. Ein halbtransparentes Overlay tut es genauso und
   kostet praktisch nichts.

Beides zusammen bringt eine flüssige Bedienung, ohne dass die GPU je ins Spiel kommt.

## Wenn die App-Suche (Super+Space) nicht aufgeht

Der Hotkey läuft über `sxhkd`, nicht über XFCE. Zwei Ursachen sind bekannt:

1. **`sxhkd` startet gar nicht.** Es bricht ab, wenn die Variable `SHELL` leer ist
   („The 'SHELL' environment variable is not defined") — und weil es im Hintergrund
   gestartet wird, sieht man den Fehler nicht. `start-desktop.sh` setzt `SHELL`
   deshalb selbst und meldet beim Start, ob `sxhkd` läuft. Nachschauen:

   ```bash
   pgrep -a sxhkd || cat ~/.cache/sxhkd.log
   ```

2. **Android/Samsung DeX frisst die Super-Taste**, dann kommt sie in X11 nie an.
   Dafür ist `Ctrl + Alt + Space` als zweite Kombination eingerichtet — die geht auch
   dann. Prüfen, ob X11 die Taste überhaupt sieht (im Desktop-Terminal, dann Super
   drücken; kommt keine Zeile mit `Super_L`, schluckt Android die Taste):

   ```bash
   xev -event keyboard | grep -i keysym
   ```

Rofi selbst testen, unabhängig vom Hotkey: `rofi -show drun`

## Bekannte Einschränkungen

- Zink/turnip auf Termux-X11 ist kein offiziell unterstützter Pfad — kann bei Mesa- oder Termux-X11-Updates brechen
- **Browser bekommen die GPU nicht zu sehen.** Zink/turnip trägt für OpenGL-Programme (GLX), aber Firefox braucht EGL und scheitert dort reproduzierbar — Details und die komplette Ausschlussliste unter [Warum Firefox trotz Turnip auf Software rendert](#warum-firefox-trotz-turnip-auf-software-rendert)
- **Keine Fenster-Transparenz**, weil Compositing bewusst aus ist (sonst ruckeln Modals)
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
