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
das Startmenü, und fragt genau **eine** Sache: den Namen deines Servers fürs
Menü. Danach:

```bash
source ~/.bashrc
desk
```

Alles Weitere ist vorkonfiguriert — Terminal, Darkmode und Firefox.

### Das Skript ist beliebig oft wiederholbar

Es überschreibt bei jedem Lauf **alles** — Konfiguration, Startskript, Menü — und
fragt dabei auch **jedes Mal** neu nach dem SSH-Ziel fürs Menü
(`benutzer@rechner`, landet in `~/.termux-menu.conf`).

**Enter behält den bisherigen Wert**, eine neue Eingabe ersetzt ihn. So bleibt
ein Wiederholungslauf schnell, ohne dass etwas heimlich hängen bleibt.

⚠️ **Der Servername wird dabei nie auf den Bildschirm geschrieben** — auch nicht
als Vorschlag in der Eingabezeile. Terminal-Ausgaben landen erfahrungsgemäß in
Chats, Fehlerberichten und Screenshots; stünde der Name in der Zeile, wanderte
er beim Kopieren jedes Mal mit. Das Setup bestätigt nur, **dass** ein Wert da
ist — nie, **welcher**. In `~/.termux-menu.conf` und `~/.ssh/config` steht er
selbstverständlich weiterhin, sonst könnte sich das Menü nicht anmelden.

Der `~/.ssh/config`-Eintrag wird dabei **ersetzt, nicht angehängt**. Sonst
sammelten sich bei jedem Lauf Doppel-Einträge für denselben Rechner an, und
`ssh` nähme stillschweigend den ersten Treffer — mit womöglich veraltetem
Benutzernamen. Andere Einträge in der Datei bleiben unberührt.

Auch die `~/.bashrc` wird jedes Mal frisch geschrieben — allerdings **nur der
Block zwischen den beiden Markierungen** `# >>> setup_i3.sh` und
`# <<< setup_i3.sh`. Eigene Zeilen außerhalb davon bleiben stehen. Frühere
Fassungen legten diesen Block nur an, wenn er noch fehlte; auf einem bereits
eingerichteten Handy kam eine Verbesserung daran damit **nie** an. Einen alten
Block ohne Markierungen erkennt das Skript und räumt ihn mit weg.

Am Ende listet das Setup auf, welche Dateien es geschrieben hat. Einzige
Ausnahme ist das Mauszeiger-Thema in `~/.icons` — das ist bloß ein Download und
wird übersprungen, wenn es schon da ist. Zum Erneuern den Ordner löschen.

### Ohne Nachfrage durchlaufen lassen

Wo keine Tastatur hängt (Skript, `ssh handy 'curl … | bash'`), kann nicht
gefragt werden. Das Skript sagt das dann deutlich und behält den alten Wert.
Das SSH-Ziel lässt sich auch vorgeben:

```bash
ZIEL_VORGABE=benutzer@rechner ./setup_i3.sh
```

### ⚠️ Termux verträgt keine Teil-Aktualisierungen

Das Setup macht darum **immer** ein `pkg upgrade`. Das ist keine Bequemlichkeit,
sondern Pflicht:

Die Basis-Pakete aus der heruntergeladenen APK sind oft Monate alt, die
Spiegelserver liefern stets den neuesten Stand. Mischt man beides, passen die
C++-Bibliotheken nicht mehr zusammen:

```
CANNOT LINK EXECUTABLE "ffmpeg": cannot locate symbol ...
  referenced by "libplacebo.so"
dpkg: dependency problems prevent configuration of firefox
```

Termux nennt in dieser Fehlermeldung selbst `pkg upgrade` als Lösung. Genau das
ist am 16.8.2026 passiert, weil das Setup damals bewusst **nicht** aktualisiert
hat — ein Standard, der für das Nebeneinander mit XFCE gedacht war und auf einem
frischen Termux falsch ist.

Abschalten nur, wenn man weiß warum: `KEIN_UPGRADE=1 ./setup_i3.sh`.

**Aus demselben Vorfall entstanden zwei weitere Absicherungen:**

- Vor dem Installieren räumt das Skript einen halben `dpkg`-Zustand auf
  (`dpkg --configure -a`, `apt --fix-broken install`). Bricht eine Installation
  einmal mittendrin ab, scheitert sonst jeder weitere Aufruf an diesem Rest.
- **Ein kaputtes Paket bricht nicht mehr das ganze Setup ab.** Vorher endete der
  Lauf bei Schritt 2, und i3-Konfiguration, Startskript und Menü wurden gar
  nicht erst geschrieben — der schlechteste Ausgang. Jetzt läuft der Rest durch,
  und am Ende steht eine Liste dessen, was fehlt.

### Spiegelserver

Termux sucht sich sonst selbst einen, und das ging zweimal daneben — einmal ein
Spiegel in Indien mit **~20 kB/s**, einmal einer mit halb kaputtem Paketstand.
Gleich zu Beginn festlegen:

```bash
termux-change-repo    #  ->  Mirror group  ->  Europe
```

Das Setup weist darauf hin, wenn keine Gruppe gewählt ist.

## Was drin ist

| Ebene | Was |
|---|---|
| Anzeige | Termux-X11 |
| Fenster | i3 (ohne `bar`-Block) |
| Programme in der Sitzung | ein Terminal und **Firefox** — sonst nichts |
| Terminal-Inhalt | Startmenü → SSH zum Server |
| Termux selbst | zweireihige Tastenleiste (`extra-keys`) |
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

### Wenn die Super-Taste nichts tut

✅ **Auf dem Fold7 unter DeX funktioniert sie** (geprüft 16.8.2026) — die
Befürchtung aus der XFCE-Zeit hat sich nicht bestätigt. Der folgende Absatz ist
nur für den Fall, dass es auf einem anderen Gerät klemmt.

Samsung DeX greift die Super-/Meta-Taste manchmal selbst ab, dann kommt sie in
X11 nie an. Prüfen — im Terminal ausführen und Super drücken:

```bash
xev -event keyboard | grep -i keysym
```

Kommt keine Zeile mit `Super_L`, schluckt Android die Taste. Dann in
`~/.config/i3/config` den `set $mod`-Block umstellen: `Mod4` auskommentieren,
`Mod1` (Alt) freigeben. Steht dort direkt erklärt.

## Die Termux-Tastenleiste (zwei Reihen)

Das ist die Leiste **über der Bildschirmtastatur** — sie gehört zu Termux
selbst, nicht zu i3, und wirkt darum auch in der normalen Termux-Sitzung ohne
laufende X11-Sitzung. Ab Werk zeigt Termux dort eine einzige Reihe
(`ESC TAB CTRL ALT - DOWN UP`). Das Setup schreibt zwei:

| | Tasten |
|---|---|
| Reihe 1 | `ESC` `TAB` `S-TAB` `ALT` `-` `V|` `UP` `H-` |
| Reihe 2 | `HOME` `END` `\|` `EXIT` `DEL` `LEFT` `DOWN` `RIGHT` |

Die vier Sondertasten sind Makros:

| Taste | Was sie schickt | Wofür |
|---|---|---|
| `S-TAB` | `ESC [ Z` | Shift+Tab, z. B. der Moduswechsel in Claude Code |
| `V\|` | `Strg+B` `%` | tmux-Fenster senkrecht teilen |
| `H-` | `Strg+B` `"` | tmux-Fenster waagrecht teilen |
| `EXIT` | `exit` + Enter | Sitzung beenden, ohne die Tastatur aufzuklappen |

### ⚠️ Die `SHIFT`-Taste der Leiste taugt nicht für Shift+Tab

Naheliegend wäre, einfach `SHIFT` in die Leiste zu legen und damit `TAB` zu
drücken. Das funktioniert **nicht**: Die Leistentasten sind keine echten
Modifier für die Terminal-Ebene. Terminals erwarten für Shift+Tab die
Escape-Sequenz `ESC [ Z`, und die muss man direkt schicken — darum das Makro.
Das hat vorher wochenlang gefehlt und war der Anlass für die zweite Reihe.

### Die Datei wird nicht überschrieben

Geschrieben wird `~/.termux/termux.properties`, aber nur der Block zwischen
den Markierungen `# >>> setup_i3.sh` und `# <<< setup_i3.sh`. Alles andere
(Farben, `volume-keys`, Schriftart, Termux:Boot) bleibt stehen. Eine von Hand
gesetzte `extra-keys`-Zeile außerhalb wird entfernt — auch eine mehrzeilige mit
`\` am Zeilenende, sonst bliebe ein Rumpf stehen, den Termux als kaputte
Einstellung liest. Die verwandten Schlüssel `extra-keys-style` und
`extra-keys-text-all-caps` bleiben ausdrücklich unangetastet.

Danach läuft `termux-reload-settings` — die Leiste ist sofort da, ohne Termux
neu zu starten.

**Rückgängig:** den Block zwischen den Markierungen löschen, dann
`termux-reload-settings`.

## Darkmode

Ohne Zutun wäre Firefox **hell**: Er nimmt sonst das GTK-Standardtheme, und das
ist Adwaita light.

Zwei Stellen sorgen dafür, dass das nicht passiert — beide erledigt das Setup:

- `GTK_THEME=Adwaita:dark` in `start-i3.sh` färbt Fensterrahmen und Menüs.
- `ui.systemUsesDarkTheme` = `1` in der `user.js` färbt Firefox selbst **und**
  entscheidet über `prefers-color-scheme`, also ob **Webseiten** dunkel rendern.
  Das ist der wichtigere von beiden.

Details unter [Feinschliff](#firefox-vertikale-tabs-dunkel-keine-menüleiste).

## Feinschliff

Drei Dinge, die **nicht** in der i3-Konfiguration liegen können, weil sie
außerhalb von X11 bzw. im Firefox-Profil sitzen.

### Echtes Vollbild auf Samsung DeX

Solange das X11-Fenster ein normales DeX-Fenster ist, bleibt darunter die
DeX-Taskleiste sichtbar und frisst Platz. Das ist keine i3-Einstellung — i3
kennt nur den Bereich, den Termux-X11 ihm gibt.

Der Schalter sitzt in der **App Termux:X11 selbst**, in deren Einstellungen
(Drei-Punkte-Menü der App). Dort gibt es eine Vollbild-Option; ist sie aktiv,
verschwindet die DeX-Leiste und i3 bekommt die volle Fläche.

### Terminal ohne Menü- und Bildlaufleiste

Erledigt das Setup selbst. Bei `lxterminal` passiert das über die Datei
`~/.config/lxterminal/lxterminal.conf` (`hidemenubar`, `hidescrollbar`,
`hideclosebutton`), die bei jedem Lauf neu geschrieben wird.

Fällt die Auswahl auf `xfce4-terminal`, muss es dagegen **beim Aufruf**
passieren (`--hide-menubar --hide-toolbar`) — das merkt sich xfce4-terminal
nämlich nicht über Fenster hinweg.

### Mauszeiger: Größe und eigenes Aussehen

Zwei getrennte Dinge, beide über Umgebungsvariablen in `start-i3.sh`:

**Größe** — wirkt auch ganz ohne eigenes Thema:

```bash
export XCURSOR_SIZE=32
```

Der X-Standard ist winzig. 32 ist auf dem Fold ein guter Wert, 40–48 gehen
deutlich größer. Zahl ändern, Sitzung neu starten, fertig. Kein Paket nötig.

**Eigenes Aussehen** — dafür braucht es genau zwei Dinge:

1. Einen Ordner `~/.icons/<Name>/cursors/` mit den Zeiger-Dateien darin.
2. Den Namen dieses Ordners in `XCURSOR_THEME`.

```bash
export XCURSOR_THEME=GoogleDot-Blue
```

Das Setup lädt **GoogleDot-Blue** selbst herunter, falls es noch nicht da ist —
aus [ful1e5/Google_Cursor](https://github.com/ful1e5/Google_Cursor).

Jedes andere X-Cursor-Thema geht genauso: entpacken nach `~/.icons/`, Namen
eintragen. Aus demselben Repo gibt es `GoogleDot-Black`, `-White` und `-Red`;
für eine andere Farbe nur die beiden Zeilen im Setup-Skript anpassen
(`CURSOR_THEME` und `CURSOR_URL`).

**Fehlt der Ordner, geht nichts kaputt:** X nimmt dann einfach seinen
Standardzeiger, und `XCURSOR_SIZE` wirkt trotzdem.

### Firefox: vertikale Tabs, dunkel, keine Menüleiste

Macht das Setup selbst. Es schreibt eine `user.js` ins Firefox-Profil:

| Einstellung | Wirkung |
|---|---|
| `sidebar.revamp` + `sidebar.verticalTabs` | vertikale Tabs; die waagrechte Leiste verschwindet dabei von selbst |
| `ui.systemUsesDarkTheme` = `1` | dunkel — auch **Webseiten** über `prefers-color-scheme` |
| `browser.menubarVisible` = `false` | keine Menüleiste |

Vertikale Tabs sind seit Firefox 136 eingebaut, es braucht **kein Add-on**.

**Warum `user.js` und nicht `prefs.js`:** `prefs.js` schreibt Firefox beim
Beenden selbst neu und würde alles überbügeln. Die Werte in `user.js` gelten
dagegen bei jedem Start.

⚠️ **Der Preis:** Änderungen über die Oberfläche halten nur bis zum nächsten
Start. Wer wieder freie Hand will, löscht die `user.js` im Profil.

**Das vorhandene Profil bleibt erhalten** — Chronik, Lesezeichen und Passwörter
aus der XFCE-Zeit werden nicht angefasst. Bei mehreren Profilen wird das
tatsächlich benutzte gewählt (`Default=` aus `profiles.ini`), nicht einfach das
erste.

### Startseite: macht das Setup bewusst nicht

Es fragt sie nicht, speichert sie nicht und schreibt sie nicht in die `user.js`.
Eine Startseite ist eine Adresse aus dem eigenen Netz — die hat hier nichts zu
suchen, auch nicht als Beispiel.

**Stell sie in Firefox selbst ein.** Sie überlebt auch den nächsten Setup-Lauf,
weil `user.js` genau diese Einstellung nicht anfasst. Eine Merkdatei
`~/.i3-firefox.conf` aus einer früheren Fassung räumt das Setup beim nächsten
Lauf weg.

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

### ⚠️ Der Benutzername beim SSH-Ziel ist Pflicht

Beim Setup muss das Ziel als **`benutzer@rechner`** angegeben werden, nicht nur
als Rechnername. Sonst kommt beim ersten Anmelden:

```
user u0_a543 is not permitted
```

**Warum:** Android gibt Termux einen Benutzernamen wie `u0_a543`. Ohne
ausdrücklichen Benutzer meldet sich `ssh` mit genau diesem Namen an — und den
gibt es auf dem Server nicht. Bei Tailscale SSH führt das zu obiger Meldung.

Das ist **kein** Berechtigungsproblem: Den Android-Benutzer in die Tailscale-ACL
aufzunehmen wäre der falsche Weg, denn die Nummer **ändert sich bei jeder
Neuinstallation von Termux**.

Das Setup fragt nach, wenn das `@` fehlt, und legt zusätzlich einen Eintrag in
`~/.ssh/config` an — damit auch ein von Hand getipptes `ssh rechner` den
richtigen Benutzer nimmt:

```
Host rechner
    User benutzer
```

Nachträglich reicht das Anpassen von `~/.termux-menu.conf`.

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

### ⚠️ Und `rxvt-unicode` gibt es in Termux gar nicht

Frühere Fassungen dieses Setups wollten `urxvt` installieren und nannten es
„erste Wahl". Das Paket existiert in Termux aber **überhaupt nicht** —
nachgeprüft am 17.8.2026 in der Paketliste des `x11-repo`. Der Aufruf stand als
`inst_opt` da, durfte also fehlschlagen und meldete nichts. Ergebnis: Die
Auswahl fiel *jedes Mal still* auf aterm zurück, und das Terminal sah kaputt aus
— ohne dass irgendwo eine Fehlermeldung darauf hingewiesen hätte.

**Das Setup installiert darum jetzt `lxterminal` und wählt in dieser
Reihenfolge:**

| | Terminal | Größe | Bewertung |
|---|---|---|---|
| 1. | `lxterminal` | 224 kB | **erste Wahl.** VTE — dieselbe Technik wie in GNOME/XFCE. Lupenreines UTF-8, braucht nur `gtk3` + `libvte`. |
| 2. | `xfce4-terminal` | 552 kB | technisch gleichwertig, zieht aber `xfconf` mit — ein D-Bus-Hintergrunddienst, den eine nackte i3-Sitzung nicht hat. |
| 3. | `st` | 136 kB | echtes UTF-8, aber ohne Scrollback und nur zur Übersetzungszeit einstellbar. Reserve. |
| 4. | `xterm` / aterm | 188 kB | Notnagel **mit Warnung** — siehe oben. Lieber ein kaputtes Terminal als gar keines. |

`--no-remote` ist bei lxterminal Pflicht: Ohne diese Option reicht ein zweiter
Aufruf die Anfrage an das schon laufende Fenster weiter und öffnet dort nur
einen neuen Reiter. In i3 will man ein eigenes Fenster für eine eigene
Arbeitsfläche.

**Schrift und Farben ändern:** nicht in der i3-Config, sondern in
`~/.config/lxterminal/lxterminal.conf` — die Zahl hinter
`fontname=DejaVu Sans Mono` anpassen und ein neues Fenster öffnen. Ein
i3-Neustart ist dafür nicht nötig. Voreinstellung ist 12.

`ttf-dejavu` und `fontconfig` sind dabei **Pflicht, nicht Kür**: VTE zeichnet
über fontconfig. Ohne anständige Monospace-Schrift fehlen genau die
Sonderzeichen wieder, derentwegen das Terminal überhaupt gewechselt wurde.

Dazu gehört die Zeile `export LANG="${LANG:-en_US.UTF-8}"` in `start-i3.sh`:
Ohne UTF-8-Sprachumgebung stellt auch ein moderner Terminal Umlaute falsch dar,
weil er die Bytes nicht als UTF-8 deutet.

## Warum kein Rust-Terminal

Kurz, damit die Frage nicht zweimal gestellt wird: **Alacritty**, **WezTerm** und
**Rio** sind in Rust — und alle drei rendern über die GPU. Genau der Pfad, der hier
kaputt ist. Sie würden entweder gar nicht starten oder auf Software zurückfallen
und wären dann *langsamer* als lxterminal. (`alacritty`, `kitty` und `wezterm`
stehen durchaus im `x11-repo` — sie sind hier trotzdem die falsche Wahl.)

Alacritty ist nicht schnell, weil es Rust ist, sondern weil es die GPU benutzt. Der
Flaschenhals ist hier ohnehin die SSH-Verbindung und der Termux-X11-Transport, nicht
der Terminal-Renderer.

Falls doch etwas anderes gewünscht ist: `rxvt-unicode` wäre die einzige sinnvolle
Alternative — ebenfalls C, ebenfalls ohne GPU, aber besser bei Unicode und mit
brauchbarem Scrollback.

## XFCE entfernen

Der Umstieg lief über ein **komplett frisches Termux**: App-Daten löschen, neu
installieren, das Setup-Skript einmal laufen lassen. Das ist sauberer als jedes
Deinstallieren und dauert kaum länger.

Bleibt aus irgendeinem Grund ein altes XFCE stehen, richtet es keinen Schaden
an — es startet nur nicht mehr von selbst. Zwei Stellen wären beim Aufräumen
von Hand zu beachten:

- **`xfce4-terminal` nicht mitentfernen.** Es ist eine Abhängigkeit des
  XFCE-Metapakets, `apt autoremove` würde es mitreißen — und dann wäre die
  Sitzung ohne Terminal unbrauchbar. Vorher `apt-mark manual xfce4-terminal`.
- **`~/.config/xfce4/terminal` stehen lassen.** Dort liegen Schrift,
  Schriftgröße und Farben des Terminals.

## Rollback

i3 beenden: `Super` + `Shift` + `Rücktaste`.

Bei schwarzem Bildschirm oder klemmender Sitzung, in der Termux-App:

```bash
killall -9 termux-x11 i3 lxterminal xfce4-terminal st xterm aterm
```

