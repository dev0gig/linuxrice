# Termux i3 Minimal

**Stand: 16.8.2026 — Nachfolger von [`termux-xfce-gpu-desktop`](../termux-xfce-gpu-desktop/).**

Eine i3-Sitzung auf dem Fold7, die auf das Nötigste eingedampft ist: **genau zwei
Programme** laufen darin — ein Terminal und Firefox. Keine Desktop-Umgebung, kein
Panel, kein Compositor, kein Theme-Dienst, kein Launcher, kein Wallpaper.

Der Grund für diesen Zuschnitt ist das tatsächliche Nutzungsverhalten nach einer
Woche XFCE: Firefox, Terminal, sonst nichts. Und das Terminal ist im Wesentlichen
ein SSH-Fenster zum Server — die eigentliche Arbeit passiert dort, nicht auf dem
Handy.

## Installation

Ein Befehl auf einem frischen Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-i3-minimal/setup_i3.sh | bash
```

Das Skript installiert alles, schreibt die i3-Konfiguration, das Startskript und
das Startmenü, und fragt einmal nach dem Namen deines Servers. Danach:

```bash
source ~/.bashrc
desk
```

Zwei Handgriffe bleiben manuell — siehe [Darkmode](#darkmode-zwei-klicks-in-firefox).

### i3 testen, ohne XFCE aufzugeben

Das Setup ist absichtlich so gebaut, dass beide Sitzungen nebeneinander leben
können — man muss sich nicht vorher entscheiden.

- **Der XFCE-Starter bleibt unangetastet.** Solange `~/start-desktop.sh`
  existiert, erscheint XFCE im Startmenü als Punkt 6. Umschalten geht also aus
  demselben Menü.
- **Das alte Menü wird gesichert** nach `~/.termux-menu.sh.bak`, bevor es
  überschrieben wird.
- **Es wird bewusst kein `pkg upgrade` gemacht.** Ein Rundum-Upgrade würde auch
  `mesa` und `termux-x11` anfassen — genau die Stücke, an denen der
  Zink/turnip-Pfad hängt, der offiziell gar nicht unterstützt ist. Ginge danach
  etwas kaputt, wüsste man nicht, ob es an i3 lag oder am Upgrade. Wer alles
  mitziehen will: `MIT_UPGRADE=1 ./setup_i3.sh`.

Wenn i3 sich bewährt, verschwindet Punkt 6 von selbst, sobald
`~/start-desktop.sh` gelöscht wird.

**Zurück zum alten Zustand:**

```bash
mv ~/.termux-menu.sh.bak ~/.termux-menu.sh
```

## Was drin ist

| Ebene | Was |
|---|---|
| Anzeige | Termux-X11 |
| Fenster | i3 (ohne `bar`-Block) |
| Programme in der Sitzung | **urxvt** und **Firefox** — sonst nichts |
| Terminal-Inhalt | Startmenü → SSH zum Server |
| Konfiguration | eine i3-Config, ~60 Zeilen inkl. Kommentaren |
| Dienste im Hintergrund | **keine** |

## Was bewusst fehlt — und warum

Das ist der eigentliche Punkt dieses Ordners, darum ausführlich:

- **`xfconfd` und die ganze XFCE-Maschinerie.** Der größte Ärger des alten Setups
  war ein Dienst, der Einstellungen im Speicher hält, sie beim Beenden über die
  Dateien kippt und dadurch die Panel-Konfiguration bei jedem Neustart zerlegt hat
  (die komplette Erklärung steht im [Nachbarordner](../termux-xfce-gpu-desktop/#warum-die-panel-config-früher-nach-jedem-neustart-weg-war)).
  i3 liest eine Textdatei beim Start. Kein Dienst, keine Vorlage, keine
  `killall`-Choreografie in exakter Reihenfolge.
- **Panel / `i3bar`.** Es läuft ohnehin alles bildschirmfüllend — eine Leiste
  würde man nie sehen. Der `bar`-Block fehlt darum ganz, dadurch startet auch
  kein `i3status`.
- **Wallpaper.** Dieselbe Begründung: nie sichtbar.
- **GTK-Theme, Icon-Theme, Cursor-Theme, Schrift-Setup.** Es gibt keine
  GTK-Anwendung außer Firefox, und dessen Darkmode kommt aus dem Firefox-Profil.
  `GTK_THEME=Adwaita:dark` im Startskript erledigt die Fensterrahmen — eine Zeile,
  kein Paket, kein Dienst.
- **`.Xresources` und `xorg-xrdb`.** Die Terminalfarben stehen direkt im
  Terminal-Aufruf in der i3-Config. Spart eine Datei und ein Paket.
- **Rofi und `sxhkd`.** Bei zwei Programmen braucht es keine App-Suche, und i3
  bringt Tastenkürzel selbst mit.
- **`yazi`, `btop`, `htop`, `tmux` lokal.** Läuft alles auf dem Server, wo es
  hingehört — die Auslastung des Servers ist die interessante, nicht die des
  Handys. `btop` ist im Termux-Repo ohnehin nicht vorhanden (Stand 16.8.2026).

## Tastenkürzel

| Taste | Wirkung |
|---|---|
| `Super` + `1` / `2` / `3` | Arbeitsfläche wechseln (1 = Firefox, 2 = Terminal) |
| `Super` + `Return` | neues Terminal |
| `Strg` + `Alt` + `T` | neues Terminal |
| `Super` + `F` | Firefox |
| `Strg` + `Q` | Fenster schließen |
| `Alt` + `F4` | Fenster schließen |
| `Super` + `Shift` + `F` | Vollbild an/aus |
| `Super` + `Shift` + `R` | i3 neu laden |
| `Super` + `Shift` + `Rücktaste` | i3 beenden |

`Super+F` ist hier Firefox, nicht Vollbild — abweichend von der i3-Standardbelegung.
Vollbild liegt darum auf `Super+Shift+F`.

Beenden liegt absichtlich auf der Rücktaste, weit weg von allem anderen. Die
i3-Standardbelegung `Super+Shift+E` sitzt zu nah an den anderen Kürzeln.

### ⚠️ Wenn die Super-Taste nichts tut

Samsung DeX greift die Super-/Meta-Taste gern selbst ab, dann kommt sie in X11 nie
an. Erst prüfen — im Terminal ausführen und Super drücken:

```bash
xev -event keyboard | grep -i keysym
```

Kommt keine Zeile mit `Super_L`, schluckt Android die Taste. Dann in
`~/.config/i3/config` den `set $mod`-Block umstellen: `Mod4` auskommentieren,
`Mod1` (Alt) freigeben. Steht dort direkt erklärt.

## Darkmode: zwei Klicks in Firefox

Das ist der einzige Teil, der nicht automatisch passiert, und ohne ihn ist alles
hell — Firefox nimmt sonst das GTK-Standardtheme, und das ist Adwaita **light**.

1. Firefox → Einstellungen → Design → **Dunkel**
2. `about:config` → `ui.systemUsesDarkTheme` = **1**

Punkt 2 ist der wichtige: Er entscheidet über `prefers-color-scheme` und damit,
ob **Webseiten** dunkel rendern. Punkt 1 färbt nur Firefox selbst.

Beides liegt im Firefox-Profil und überlebt Neustarts, Updates und
Sitzungsabstürze. Deshalb wird es hier nicht ins Setup-Skript gepresst — das
müsste den Profilpfad raten, der beim ersten Start noch gar nicht existiert.

## Das Startmenü

Öffnet sich in jedem neuen Terminal, sowohl in der Termux-App als auch in jedem
Terminalfenster innerhalb der Sitzung:

```
   1   Server      SSH + tmux "cc"
   2   Server pur  SSH ohne tmux
   3   Auslastung  btop auf dem Server
   4   Terminal    nur die Shell
   5   Desktop     i3 starten
   6   Desktop alt XFCE starten
```

Punkt 5 und 6 erscheinen nur **außerhalb** der grafischen Sitzung — innerhalb
liefe der Start ins Leere und würde die eigene Sitzung abschießen.

Punkt 6 taucht nur auf, solange `~/start-desktop.sh` existiert. Das ist die
Brücke für die Testphase; nach dem Löschen des XFCE-Starters verschwindet er.

In i3 ist das Menü praktischer als in der Termux-App: Du kannst mehrere Terminals
öffnen und in jedem einen anderen Punkt wählen — etwa Arbeitsfläche 2 mit der
tmux-Sitzung und Arbeitsfläche 3 mit `btop`.

**Der Servername steht nicht im Repo.** Das Setup fragt einmal danach und legt ihn
in `~/.termux-menu.conf` ab. Zum Ändern nur diese Datei anfassen —
`~/.termux-menu.sh` wird bei jedem Setup überschrieben.

### ⚠️ `TERMUX_MENU_DONE` muss zurückgesetzt werden

Das Menü setzt beim Start `TERMUX_MENU_DONE=1` und **exportiert** es, damit es
sich nicht endlos selbst aufruft. Wird i3 aus dem Menü heraus gestartet, erbt
jedes später geöffnete Terminal die Variable — und das Menü erschiene dort **nie**.

`start-i3.sh` setzt sie darum vor dem Start zurück. Wer das Startskript
umschreibt, darf diese Zeile nicht verlieren.

## Was i3 *nicht* löst

**Der Blur bleibt kaputt, und i3 ändert daran nichts.** Das ist wichtig
festzuhalten, weil die Erwartung naheliegt:

Firefox rendert hier dauerhaft auf der CPU, weil er über EGL keinen Display
bekommt — die vollständige Diagnose samt Ausschlussliste steht im
[Nachbarordner](../termux-xfce-gpu-desktop/#warum-firefox-trotz-turnip-auf-software-rendert).
Diese Kette ist vom Fenstermanager völlig unabhängig.

Auch das Argument „i3 spart CPU, also bleibt mehr für Firefox" trägt nicht: Die
XFCE-Hintergrunddienste haben **RAM** gekostet, keine CPU-Zeit, und Compositing
war ohnehin schon abgeschaltet. `backdrop-filter: blur()` ist Volllast in Firefox'
eigenen Render-Threads — da fehlen keine paar Prozent, da fehlt die GPU.

Was i3 real bringt: **weniger Speicherdruck** (Android würgt die Sitzung seltener
ab), und der `xfconfd`-Ärger ist ersatzlos weg.

Der einzige Weg zu echter GPU-Beschleunigung im Browser wäre Wayland — daran wurde
am 16.8.2026 zweimal gearbeitet, siehe
[`termux-wayland-labwc`](../termux-wayland-labwc/). Beide Wege scheitern derzeit an
der Eingabe bzw. am Browser.

**Praktische Folge, unverändert:** Auf eigenen Webseiten kein `backdrop-filter:
blur()` verwenden. Ein halbtransparentes Overlay sieht fast gleich aus und kostet
praktisch nichts.

## Bekannte Einschränkungen

- **Keine Fenstertransparenz, keine Schatten** — es läuft kein Compositor. War
  unter XFCE zuletzt auch schon so, dort bewusst abgeschaltet.
- **Browser sehen die GPU nicht** (siehe oben). Zink/turnip trägt nur für
  Programme, die OpenGL über GLX ansprechen.
- **i3 kachelt.** Öffnest du ein zweites Fenster auf derselben Arbeitsfläche,
  teilt i3 den Schirm. Bei einem Fenster pro Arbeitsfläche fällt das nie auf.
- **`btop` fehlt im Termux-Repo** (Stand 16.8.2026) — deshalb läuft es über SSH
  auf dem Server, was ohnehin die interessantere Auslastung zeigt.
- **Braille-Zeichen in btop** brauchen eine passende Schrift. Sieht der Graph
  kaputt aus, fehlt `ttf-dejavu` — nicht das Terminal tauschen.
- Zink/turnip auf Termux-X11 ist kein offiziell unterstützter Pfad und kann bei
  Mesa- oder Termux-X11-Updates brechen.

## ⚠️ Das Terminal: Finger weg von „xterm"

Das war der unangenehmste Fund der Testphase, darum ausführlich.

**Was Termux als `xterm` installiert, ist in Wirklichkeit `aterm`** — ein Fork
des alten rxvt aus der Zeit *vor* Unicode. Zwei Folgen:

1. Es kennt die Xft-Optionen `-fa` und `-fs` nicht, bricht bei ihnen sofort mit
   `bad option` ab — und dann startet **überhaupt kein Terminal**, auch nicht
   über die Tastenkürzel.
2. Viel schlimmer: **es kann kein UTF-8.** Sonderzeichen, Rahmenlinien, Umlaute
   und die Braille-Graphen von `btop` werden falsch dargestellt. Das ist keine
   Einstellungssache — aterm benutzt klassische X-Core-Fonts, da hilft keine
   Schriftgröße und keine Schriftart. Genau deshalb hieß der Nachfolger später
   rxvt-**unicode**.

Für eine SSH-Sitzung ist aterm damit unbrauchbar.

**Das Setup wählt darum selbst aus, in dieser Reihenfolge:**

| | Terminal | Bewertung |
|---|---|---|
| 1. | `urxvt` (rxvt-unicode) | schlank, echtes UTF-8, Xft-Schriften frei skalierbar |
| 2. | `xfce4-terminal` | ebenfalls tadellos, zieht aber GTK/VTE mit sich |
| 3. | `xterm` / aterm | Notnagel, mit Warnung — siehe oben |

**`-tn xterm-256color` ist bei urxvt Pflicht.** Ohne das meldet es sich beim
Server als `rxvt-unicode-256color` an, und wenn dessen Terminfo-Eintrag dort
fehlt, ist die Anzeige über SSH kaputt. `xterm-256color` kennt jeder Server.

**Schriftgröße ändern:** in `~/.config/i3/config` die Zahl hinter `size=`
anpassen, dann `Super+Shift+R`. Voreinstellung ist 13.

Dazu gehört die Zeile `export LANG="${LANG:-en_US.UTF-8}"` in `start-i3.sh`:
Ohne UTF-8-Sprachumgebung stellt auch ein moderner Terminal Umlaute falsch dar,
weil er die Bytes nicht als UTF-8 deutet.

## Warum xterm und kein Rust-Terminal

Kurz, damit die Frage nicht zweimal gestellt wird: **Alacritty**, **WezTerm** und
**Rio** sind in Rust — und alle drei rendern über die GPU. Genau der Pfad, der hier
kaputt ist. Sie würden entweder gar nicht starten oder auf Software zurückfallen
und wären dann *langsamer* als xterm.

Alacritty ist nicht schnell, weil es Rust ist, sondern weil es die GPU benutzt. Der
Flaschenhals ist hier ohnehin die SSH-Verbindung und der Termux-X11-Transport, nicht
der Terminal-Renderer.

Falls doch etwas anderes gewünscht ist: `rxvt-unicode` wäre die einzige sinnvolle
Alternative — ebenfalls C, ebenfalls ohne GPU, aber besser bei Unicode und mit
brauchbarem Scrollback.

## Rollback

i3 beenden: `Super` + `Shift` + `Rücktaste`.

Bei schwarzem Bildschirm oder klemmender Sitzung, in der Termux-App:

```bash
killall -9 termux-x11 i3 xterm aterm urxvt
```

Zurück zu XFCE: `~/start-desktop.sh` aus dem
[Nachbarordner](../termux-xfce-gpu-desktop/) existiert weiterhin unverändert.
Beide Setups stören einander nicht — sie teilen sich nur `~/.bashrc` und das
Startmenü.
