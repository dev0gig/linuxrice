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
| `fingerabdruck/` (selbst gebauter libfprint-Treiber) | Synaptics `06cb:00e7` und seine Tudor-Geschwister (`00c9`, `00ff`, `00d8`, `016c`) | `setup.sh` erkennt den Sensor und fragt; bei jedem anderen Sensor reicht das Void-Paket `fprintd`. Bei Dual-Boot vorher `fingerabdruck/README.md` lesen — die Kopplung verdrängt Windows Hello. |

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

> **Diese Dateien sind Vorlagen, keine Kopien eines laufenden Systems.**
> Sie lassen sich nicht mit `cp ~/.config/… hierher` pflegen — dabei gehen
> die Platzhalter verloren, und echte Rechnernamen landen im öffentlichen
> Repo. Genau das war schon zweimal passiert. Betroffen sind:
>
> | Datei | steht hier absichtlich anders |
> | --- | --- |
> | `config/.config/i3/config` | `remote-term` / `remote-shell` statt echter Namen, `~/…` statt `/home/<name>/…` |
> | `config/.bashrc` | `@@REMOTE_ALIAS@@` statt eines fertigen `alias` |
> | `config/.local/bin/i3-workspace-names` | `@@WS2_NAME@@`, `@@WS3_NAME@@` |
> | `config/.local/bin/remote-shell` | `@@SSH_TARGET@@`, `@@REMOTE_ALIAS_NAME@@`; heißt lokal anders |
>
> Änderungen an diesen vier also von Hand nachziehen. Alles Übrige darf
> direkt kopiert werden.

Es richtet ein:

| | |
| --- | --- |
| Pakete | Xorg ohne Display-Manager, i3, rofi, picom, Alacritty, PCManFM, Flatpak, btop |
| Dienste | `dbus`, `dhcpcd`, `wpa_supplicant`, `tailscaled`, `bluetoothd`, `alsa`, `rtkit` |
| Locale | `de_DE.UTF-8` erzeugen (Systemsprache bleibt `C.UTF-8`), Konsolentastatur auf `de` |
| Schriften | Red Hat Mono nach `/usr/share/fonts`, dazu die fontconfig-Regel, die `monospace` darauf umbiegt |
| Mauszeiger | Nordzy nach `~/.icons` |
| Eingabe | deutsches Tastaturlayout in X, Touchpad mit natürlichem Scrollen und Tap-to-Click, Drei-Finger-Gesten |
| Hardware | udev-Regel gegen den WLAN-Softblock von `hp_wmi` beim Booten |
| Fingerabdruck | auf Nachfrage: libfprint-Fork mit dem Treiber `synatlsmoc` und gepatchtes fprintd nach `/usr/local`, polkit-Regel, `pam_fprintd` für sudo und Login; das Sperrmenü entsperrt auf Fingertipp (`fingerabdruck/`) |
| Ton | PipeWire mit WirePlumber und PulseAudio-Schnittstelle, dazu `dumb_runtime_dir` (nicht in `base-system`) und `/run/user` aus `rc.local` — ohne `XDG_RUNTIME_DIR` startet PipeWire nicht |
| Bluetooth | `bluez`; der Adapter bleibt nach dem Booten aus und geht erst auf Klick an |
| Browser | Chrome (Standard) und Brave als Flatpak von Flathub |
| Systemmonitor | btop über die volle Arbeitsfläche 4, unschließbar (`config/.local/bin/vitals-btop`) |

Was danach von Hand kommt — WLAN, Tailscale-Anmeldung, `sensors-detect`,
eigene Hintergrundbilder, Anmeldung in Chrome — listet das Skript am Ende
noch einmal auf.

## Aufbau des Ordners

```
setup.sh              das Einrichtungsskript
config/               wird nach $HOME kopiert
system/               wird nach / kopiert (mit sudo)
fingerabdruck/        Treiber-Build fuer den Synaptics-Sensor, eigenes README
```

## Arbeitsflächen

| | Inhalt | Fensterklasse |
| --- | --- | --- |
| 1 | Chrome (Autostart, keine eigene Taste — sonst rofi) | `Google-chrome` |
| 2 | lokales Terminal | `autostart-term` |
| 3 | SSH-Sitzung, hält nach dem Ende eine lokale Shell offen | `remote-term` |
| 4 | btop über die volle Fläche | `vitals-dashboard` |

Ab 5 sind die Flächen frei: sie entstehen beim Hinschalten, werden nach dem
Programm darin benannt (`5: Code`) und verschwinden wieder, sobald das letzte
Fenster zu ist.

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
| `$mod+e` | Dateimanager PCManFM (frei bewegliches Fenster) |
| `$mod+c` | VS Code (kacheln, nicht schwebend) |
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

**PCManFM** auf `$mod+e` ist der Dateimanager, als schwebendes Fenster
(1000x750, mittig). Schwebend statt gekachelt, weil ein Dateimanager meist
nur kurz aufgemacht wird — er soll über der Arbeit liegen und sie nicht zur
Seite schieben. Drag-and-Drop in andere Fenster und Vorschaubilder für Bilder
kann er von Haus aus; Ordner sind ihm auch als `inode/directory` zugeordnet,
damit „Ordner öffnen" aus den Browser-Downloads dort landet.

**VS Code** auf `$mod+c` ist die Entwicklungsumgebung, installiert als
Flatpak (`com.visualstudio.code`). Der Flatpak statt des Void-Pakets, weil
`vscode` aus dem Repo ein älterer Code-OSS-Build ohne den Microsoft-
Marktplatz ist — kein Pylance, kein offizielles Remote-SSH. Der Flatpak hat
`filesystems=host`, kommt also ohne Zusatzrechte an alle Dateien, und über
`ssh-auth` auch an den SSH-Agenten.

Anders als der Dateimanager kachelt VS Code ganz normal. Die Regel
`for_window [class="(?i)^code$"] floating disable` steht trotzdem in der
Config: das erste Fenster meldet eine eigene Wunschgröße an und der
Willkommensbildschirm kann als Dialog durchgehen, was i3 sonst gelegentlich
schwebend stehen lässt.

Zum Ansehen und Bearbeiten im Terminal:

| Werkzeug | Wofür |
| --- | --- |
| `nano` | Editor im Terminal; `EDITOR`/`VISUAL` zeigen hierher |
| `glow -p` | Markdown gerendert im Terminal lesen |
| `bat` | `cat` mit Syntaxhervorhebung (als Alias auf `cat` gelegt) |
| `nsxiv` | Bilder in einem richtigen Fenster |

`EDITOR=nano` ist bewusst nicht VS Code: `git commit` und `visudo` erwarten
einen Editor, der im Terminal läuft und erst zurückkehrt, wenn die Datei
gespeichert ist. Ein GUI-Fenster passt da nicht hinein.

Doppelklick auf eine Text- oder Codedatei öffnet sie in VS Code — die
Zuordnungen in `~/.config/mimeapps.list` zeigen auf
`com.visualstudio.code.desktop`. Markdown lässt sich im Rechtsklick unter
„Öffnen mit" weiterhin mit `glow` oder `bat` im Terminal ansehen.

**Kitty wurde bewusst nicht genommen.** Das einzige Argument wäre eine
Bildvorschau im Terminal gewesen — Alacritty kann kein Sixel und kein
Kitty-Graphics-Protokoll. Dafür ist `nsxiv` aber ohnehin die bessere Lösung,
und ein Terminalwechsel hätte `i3/config` und `rofi/config.rasi`
angefasst.

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
  Schrift, falsche Farben. Genau so kommen die `.desktop`-Dateien der
  Terminalprogramme aus den Paketen. Die eigenen Einträge unter
  `~/.local/share/applications/*-alacritty.desktop` rufen Alacritty deshalb
  ausdrücklich im `Exec` auf und lassen `Terminal=false`.
* **VS Code meldet seine Fensterklasse klein: `code`, nicht `Code`.** i3
  vergleicht `class=` mit einem regulären Ausdruck und achtet dabei auf
  Groß- und Kleinschreibung — eine Regel auf `[class="Code"]` greift
  wortlos nicht. Auch hier gilt: WM_CLASS mit `i3-msg -t get_tree`
  nachsehen, nicht raten.
* **`xdg-mime query filetype` und der Dateimanager sind sich nicht einig.**
  Für eine `.md` liefert das Shellskript `text/plain` (es fällt auf
  `file --mime-type` zurück), `gio info` dagegen `text/markdown` — und *das*
  benutzt libfm. Beim Prüfen von Zuordnungen also `gio info` fragen. In
  `mimeapps.list` stehen beide Typen, damit es egal ist, welcher Weg greift.
* **Neue `.desktop`-Dateien brauchen `update-desktop-database`.** Ohne den
  Aufruf auf `~/.local/share/applications` findet der Dateimanager sie erst
  nach der nächsten Anmeldung.
* **btop auf Fläche 4 lässt sich nicht schließen** — und das ist Absicht.
  Zwei Teile greifen ineinander: `i3/config` nimmt die Klasse
  `vitals-dashboard` von `Mod+Shift+q` und `Strg+q` aus, und
  `~/.local/bin/vitals-btop` startet btop in einer Schleife sofort neu, wenn
  es über `q`, `Strg+C` oder das Esc-Menü beendet wird. Alles andere in btop
  — sortieren, filtern, Maus, Menü — funktioniert unverändert. Ein `flock`
  in derselben Datei hält die Zahl der Fenster bei genau einem.
