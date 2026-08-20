# void-i3

Void Linux mit i3 auf einem Notebook (HP ENVY x360, 1920x1080) — im Gegensatz
zu den `termux-*`-Ordnern also ein gewöhnlicher Rechner, kein Telefon.

Kein Display-Manager, keine Desktop-Umgebung, kein Panel. `.bash_profile`
startet X beim Login auf tty1, `.xinitrc` startet i3, fertig. Vier feste
Arbeitsflächen: Browser, lokales Terminal, SSH-Sitzung und ein
Systemmonitor-Dashboard.

## Für welches Gerät

Das Setup ist auf **ein** Notebook zugeschnitten: **HP ENVY x360 Convertible
13-bd0xxx** (Intel Core i7-1165G7 „Tiger Lake", Audio-Codec Realtek ALC245
mit HP-Subsystem `0x103c8824`, 1920×1080). Das meiste läuft auf jedem
Rechner, aber ein paar Teile sind an genau diese Hardware gebunden — vor
allem die LED-Ansteuerung, die direkt in Register des Codecs schreibt:

| Teil | Gebunden an | Auf anderem Gerät |
| --- | --- | --- |
| `system/bin/tasten-led.c` (LEDs in F5/F8) | GPIO-Pin 2 und COEF-Register `0x0b` des ALC245, durch Ausprobieren auf diesem Gerät ermittelt | **Nicht installieren.** Das Programm prüft nur die Codec-ID (ALC245), nicht das HP-Subsystem — auf einem anderen ALC245-Gerät schreibt es dieselben Register, und dort kann die Belegung eine ganz andere sein. Den Block „LEDs in F5 und F8" in `setup.sh` überspringen, `mikro-led`/`ton-led` laufen dann ohne LED weiter. |
| `etc/udev/hwdb.d/61-hp-envy-fkeys.hwdb` | DMI-Match auf genau dieses Modell | greift schlicht nicht, harmlos |
| `bindcode 248` (F12-Zahnrad) in der i3-Config | `KEY_UNKNOWN` des `hp-wmi`-Treibers | ohne Wirkung; Sitzungsmenü bleibt über `$mod+Shift+e` erreichbar |
| `etc/udev/rules.d/60-rfkill-unblock.rules` | WLAN-Softblock durch `hp_wmi` beim Booten | harmlos |
| `akku-wache`, `netz-ton`, `i3status/config` | `BAT1`, `ACAD`, `/sys/class/hwmon/hwmon4` (coretemp) | anpassen: meist `BAT0`/`AC`, und die hwmon-Nummer nachsehen (`cat /sys/class/hwmon/*/name`) |
| `xf86-video-intel` in der Paketliste | Intel-Grafik | bei AMD/NVIDIA aus der Liste nehmen, der `modesetting`-Treiber aus `xorg-server` reicht |

Tastatur- und Touchpad-Konfiguration, Schriften, Ton, Bluetooth, das
Dashboard und die i3-Config selbst sind nicht gerätespezifisch.

## Einrichten

Nach einer frischen Void-Installation (Basissystem, noch kein Xorg):

```sh
xbps-fetch -o setup.sh https://raw.githubusercontent.com/dev0gig/linuxrice/main/void-i3/setup.sh
sh setup.sh
```

`xbps-fetch` liegt jedem Void bei — `curl` und `git` sind auf einem frischen
System noch nicht da. Das Skript holt sich den Rest des Repos selbst. Wer
schon geklont hat, ruft stattdessen `sh void-i3/setup.sh` auf.

Das Skript fragt zu Beginn nach dem SSH-Ziel für Arbeitsfläche 3 und den
Beschriftungen für die Arbeitsflächen 2 und 3 — im Repo stehen dafür nur
Platzhalter, keine echten Rechnernamen. Danach läuft es ohne Rückfragen
durch und ist **mehrfach ausführbar**: was es überschreibt, legt es vorher
als `<datei>.vor-void-i3` daneben.

Es richtet ein:

| | |
| --- | --- |
| Pakete | Xorg ohne Display-Manager, i3, rofi, picom, Alacritty, PCManFM, Flatpak und die Werkzeuge des Dashboards |
| Dienste | `dbus`, `dhcpcd`, `wpa_supplicant`, `tailscaled`, `bluetoothd`, `alsa`, `rtkit` |
| Locale | `de_DE.UTF-8` erzeugen (Systemsprache bleibt `C.UTF-8`), Konsolentastatur auf `de` |
| Schriften | Red Hat Mono nach `/usr/share/fonts`, dazu die fontconfig-Regel, die `monospace` darauf umbiegt |
| Mauszeiger | Nordzy nach `~/.icons` |
| Eingabe | deutsches Tastaturlayout in X, Touchpad mit natürlichem Scrollen und Tap-to-Click, Drei-Finger-Gesten |
| Hardware | udev-Regel gegen den WLAN-Softblock von `hp_wmi` beim Booten |
| Ton | PipeWire mit WirePlumber und PulseAudio-Schnittstelle, dazu `dumb_runtime_dir` (nicht in `base-system`) und `/run/user` aus `rc.local` — ohne `XDG_RUNTIME_DIR` startet PipeWire nicht |
| Bluetooth | `bluez`; der Adapter bleibt nach dem Booten aus und geht erst auf Klick an |
| Browser | Chrome (Standard) und Brave als Flatpak von Flathub |
| Dashboard | das komplette [`workspaces-vitals`](workspaces-vitals/) auf Arbeitsfläche 4 |

Was danach von Hand kommt — WLAN, Tailscale-Anmeldung, `sensors-detect`,
eigene Hintergrundbilder, Anmeldung in Chrome — listet das Skript am Ende
noch einmal auf.

## Aufbau des Ordners

```
setup.sh              das Einrichtungsskript
config/               wird nach $HOME kopiert
system/               wird nach / kopiert (mit sudo)
workspaces-vitals/    das Dashboard von Arbeitsfläche 4, mit eigener README
```

`config/` und `workspaces-vitals/home/` überschneiden sich nicht: die Dateien
des Dashboards liegen **nur** unter `workspaces-vitals`, `setup.sh` kopiert
von beiden Stellen. So gibt es von jeder Datei genau eine Fassung.

## Arbeitsflächen

| | Inhalt | Fensterklasse |
| --- | --- | --- |
| 1 | Chrome (Autostart, keine eigene Taste — sonst rofi) | `Google-chrome` |
| 2 | lokales Terminal | `autostart-term` |
| 3 | SSH-Sitzung, hält nach dem Ende eine lokale Shell offen | `remote-term` |
| 4 | Vitals-Dashboard | `vitals-dashboard` |
| 5 | Dateimanager Yazi, volle Fläche ohne Rahmen | `yazi-term` |

Jedes Autostart-Fenster hat eine eigene Fensterklasse — damit landet genau
*dieses* Fenster auf seiner Fläche, während normal gestartete Terminals sich
unverändert verhalten. Die Beschriftungen setzt `~/.local/bin/i3-workspace-names`
live nach der Fensterklasse; die Nummer bleibt vorn stehen, deshalb
funktionieren `workspace number N` und die `assign`-Regeln weiter.

## Tastenbelegung

| Taste | Wirkung |
| --- | --- |
| `Strg+Alt+T` | Terminal |
| `$mod+space` / `$mod+d` | rofi |
| `$mod+Shift+d` | dmenu (Rückfallebene) |
| `$mod+e` | Dateimanager Yazi — springt auf Fläche 5 |
| `Strg+$mod+e` | Dateimanager PCManFM (Fenster) |
| `$mod+Shift+f` | Vollbild |
| `$mod+t` | Aufteilung umschalten |
| `Strg+q` | Fenster schließen |
| `$mod+Shift+w` | Hintergrundbild wählen |
| `$mod+v` | Verlauf der Zwischenablage |
| `$mod+Shift+v` | senkrecht teilen |
| `$mod+1` … `$mod+4` | Arbeitsflächen |

Deutsches Tastaturlayout — deshalb steht in den Bindings `$mod+odiaeresis`
statt `$mod+semicolon`.

`$mod+v` ist die Entsprechung zu Super+V unter Windows: `clipmenud` schreibt
jeden Kopiervorgang mit, `~/.local/bin/zwischenablage` zeigt den Verlauf als
rofi-Liste, und ein gewählter Eintrag landet wieder in der Zwischenablage.
Deshalb ist `split v` auf `$mod+Shift+v` umgezogen.

Der Verlauf liegt unter `$XDG_RUNTIME_DIR/clipmenu.6.$USER`, also im tmpfs —
beim Neustart ist er weg und landet nie auf der Platte. Nur Text; Bilder kann
clipmenu nicht. Solange er lebt, steht darin allerdings alles im Klartext,
auch kopierte Passwörter. Eine Ausnahmeliste über `CM_IGNORE_WINDOW` geht nur
nach Fensterklasse und hilft deshalb nicht gegen ein Passwort-Plugin im
Browser — das wäre dieselbe Klasse wie der Browser selbst.

## Dateien, Text und Code

Zwei Dateimanager nebeneinander, mit klarer Aufgabenteilung:

* **Yazi** auf `$mod+e` ist der Alltagsweg. Es läuft in Alacritty und lässt
  sich komplett mit den Cursortasten bedienen — hoch/runter bewegen, rechts
  in den Ordner hinein, links wieder heraus. `hjkl` liegt parallel darauf,
  man muss es aber nicht benutzen. Maus ist über `mouse_events` in
  `~/.config/yazi/yazi.toml` eingeschaltet.

  Yazi hat eine feste Arbeitsfläche (5) und liegt dort allein und ohne
  Rahmen. `$mod+e` startet deshalb kein Fenster in der gerade benutzten
  Fläche — das würde sie kacheln und den Dateimanager auf die Hälfte
  drücken. Stattdessen schaltet `~/.local/bin/dateien` auf 5 und startet
  Yazi nur dann, wenn dort gerade keins läuft. Zwei Ordner nebeneinander
  braucht kein zweites Fenster: `t` macht in Yazi einen Tab auf, `y`/`x`
  kopiert bzw. schneidet aus, `p` fügt im anderen Tab ein.
* **PCManFM** auf `Strg+$mod+e` bleibt für die zwei Dinge, die ein
  TUI-Dateimanager nicht kann: Dateien per Drag-and-Drop in andere Fenster
  ziehen und Bilder als Vorschaubilder durchblättern. Es kostet 1,4 MB, und
  nichts im System hängt davon ab — deshalb steht es hier statt weg zu sein.

Ordner bleiben absichtlich bei PCManFM zugeordnet (`inode/directory`), damit
„Ordner öffnen" aus den Browser-Downloads weiter funktioniert. Yazi steht
dafür im Rechtsklick unter „Öffnen mit".

Zum Ansehen und Bearbeiten:

| Werkzeug | Wofür |
| --- | --- |
| `hx` (Helix) | Editor für Text, Markdown und Code; LSP ist eingebaut |
| `nano` | schneller Notausgang für „eine Zeile ändern" |
| `glow -p` | Markdown gerendert im Terminal lesen |
| `bat` | `cat` mit Syntaxhervorhebung (als Alias auf `cat` gelegt) |
| `nsxiv` | Bilder in einem richtigen Fenster |

`Enter` auf einer Textdatei öffnet Helix — aber in einem **eigenen**
Alacritty-Fenster, das i3 rechts neben Yazi kachelt. Yazis Vorgabe wäre
`${EDITOR:-vi} %s` mit `block = true`; das lässt den Editor das Yazi-Fenster
übernehmen, der Dateimanager verschwindet dahinter. Der `[opener]`-Abschnitt
in `~/.config/yazi/yazi.toml` ersetzt das durch `orphan = true` und ein
eigenes Fenster, damit beide nebeneinander stehen bleiben.

`EDITOR=hx` aus der `.bashrc` bleibt trotzdem wichtig — für alles andere,
was einen Editor aufruft (`git commit`, `crontab`, …).

**Kitty wurde bewusst nicht genommen.** Das einzige Argument wäre Yazis
Bildvorschau im Terminal gewesen — Alacritty kann kein Sixel und kein
Kitty-Graphics-Protokoll. Dafür ist `nsxiv` aber ohnehin die bessere Lösung,
und ein Terminalwechsel hätte `i3/config`, `rofi/config.rasi` und das
zellij-Layout angefasst.

## Klicks in der Statusleiste

`i3status` kann keine Mausklicks entgegennehmen, darum läuft die Leiste über
`~/.local/bin/i3status-melder`: der Wrapper reicht `i3status` durch, macht
einzelne Blöcke anklickbar und hängt zwei eigene an — Bluetooth links neben
dem WLAN, die Glocke des Benachrichtigungs-Verlaufs ganz rechts.

| Block | Linksklick | Rechtsklick |
| --- | --- | --- |
| Bluetooth | Funk an/aus | Menü: suchen, koppeln, verbinden, trennen |
| WLAN | Funk an/aus | — |
| Ton | stumm um (Mausrad: lauter/leiser) | — |
| Glocke | Verlauf ansehen | Verlauf leeren |

Das Bluetooth-Icon zeigt den Zustand: stumpf heißt aus, blau heißt an, und
sobald ein Gerät verbunden ist, steht sein Name daneben. Während der Suche
wird der Block gelb und die Punkte hinter „sucht“ wandern — der Scan dauert
acht Sekunden und sähe sonst aus wie eingeschaltetes Bluetooth. Dieselben Schritte
gehen auch im Terminal — `bluetooth an|aus|um|zustand|menue`.

## Stolpersteine, die hier schon gelöst sind

* **Komma und Semikolon in `exec`-Zeilen** sind für i3 Befehlstrenner. Ein
  `-combi-modes drun,run` bringt rofi zwar zum Laufen, wirft aber jedes Mal
  einen Parse-Fehler samt rotem `i3-nagbar`. Lösung: das ganze Kommando in
  Anführungszeichen.
* **`i3-msg reload` startet `i3status` nicht neu.** Die Leiste zeigt weiter
  die alte Ausgabe; erst `i3-msg restart` startet i3bar samt i3status neu
  (und behält dabei Fenster und Layout).
* **Die Höhe der i3bar** kommt aus `padding` im `bar {}`-Block. Ein `height`
  wie zu i3-gaps-Zeiten kennt i3 nicht.
* **`default_border none` greift nur bei neuen Fenstern.** Bestehende
  behalten ihren Rahmen auch über `i3-msg restart` hinweg — einmalig
  `i3-msg '[class=".*"] border none'`.
* **Symbole in der Leiste** kommen aus `nerd-fonts-symbols-ttf`, eingebunden
  als Pango-Fallback hinter dem Textfont. Zum Ändern **nicht** `sed` mit dem
  rohen Glyph benutzen — das greift unzuverlässig; stattdessen Python mit
  Codepoints. Und Symbole über die Glyphennamen suchen, nicht durch Raten:
  Nerd Fonts v3 legt Font Awesome 6 nach `ed00-efcf`, nicht in den alten
  Bereich `f000-f385`.
* **`monospace` → Red Hat Mono** steht in `/etc/fonts/conf.d/56-redhat-mono.conf`.
  Die **56** ist zwingend: `57-dejavu-sans-mono.conf` setzt DejaVu als
  `monospace`, und die zuerst geladene Datei gewinnt. Zwei Minuszeichen
  hintereinander in einem XML-Kommentar legen die Datei still lahm.
* **Der Gelbstich im Terminal** kam nicht vom Farbschema, sondern von
  `opacity` in `alacritty.toml` — picom ließ das Wallpaper durchscheinen.
  Bei `0.92` war der Stich deutlich, `0.95` ist der Kompromiss aus etwas
  Transparenz und neutralem Hintergrund.
* **Mittelklick-Einfügen** hat unter X11 keinen globalen Schalter, es ist pro
  Toolkit zu setzen: GTK 3 und 4 (`gtk-enable-primary-paste=false`) und
  Alacritty. Chrome und Brave bringen keinen solchen Schalter mit — dort
  bleibt es an.
* **Flatpak-Programme tauchen erst nach der Neuanmeldung im Starter auf.**
  `XDG_DATA_DIRS` bekommt die Pfade `…/flatpak/exports/share` aus
  `/etc/profile.d/flatpak.sh`, und das läuft nur bei der Anmeldung. In einer
  Sitzung, die vor der Installation gestartet ist, findet rofi die Browser
  nicht und `xdg-open` löst ihre `.desktop`-Dateien nicht auf.
* **Hardware-Video in Chrome und Brave** braucht `intel-media-driver` *nicht*
  auf dem Host: Flatpak zieht `org.freedesktop.Platform.VAAPI.Intel` von
  selbst mit (`download-if = have-intel-gpu` in der Runtime), der iHD-Treiber
  liegt dann im Sandkasten unter
  `/usr/lib/x86_64-linux-gnu/dri/intel-vaapi-driver/`. Kontrolle in
  `chrome://gpu` unter „Video Decode".
* **Chrome kann sich selbst nicht zum Standardbrowser machen.** Im Sandkasten
  fehlt `xdg-settings`, der Knopf läuft ins Leere (`failed to execvp`). Der
  Eintrag steht deshalb direkt in `~/.config/mimeapps.list`.
* **Die `assign`-Regel trifft `Google-chrome`, nicht `chrome`.** Die WM_CLASS
  des Flatpak-Fensters vorher mit `i3-msg -t get_tree` nachsehen, nicht raten.
* **`Terminal=true` in einer `.desktop`-Datei ist hier eine Falle.** libfm
  sucht sich dann selbst ein Terminal und landet bei `xterm` — falsche
  Schrift, falsche Farben. Genau so kommen `Helix.desktop` und `yazi.desktop`
  aus den Paketen. Die eigenen Einträge unter
  `~/.local/share/applications/*-alacritty.desktop` rufen Alacritty deshalb
  ausdrücklich im `Exec` auf und lassen `Terminal=false`.
* **`xdg-mime query filetype` und der Dateimanager sind sich nicht einig.**
  Für eine `.md` liefert das Shellskript `text/plain` (es fällt auf
  `file --mime-type` zurück), `gio info` dagegen `text/markdown` — und *das*
  benutzt libfm. Beim Prüfen von Zuordnungen also `gio info` fragen. In
  `mimeapps.list` stehen beide Typen, damit es egal ist, welcher Weg greift.
* **Neue `.desktop`-Dateien brauchen `update-desktop-database`.** Ohne den
  Aufruf auf `~/.local/share/applications` findet der Dateimanager sie erst
  nach der nächsten Anmeldung.
* Die Fallstricke rund um zellij, glances und die Uhr stehen in der
  [README des Dashboards](workspaces-vitals/).
