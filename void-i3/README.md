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
| `etc/zzz.d/resume/20-funk` (WLAN-Teil) | demselben Softblock, nur nach dem Aufwachen | harmlos; der Bluetooth-Teil ist geräteunabhängig |
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
| Pakete | Xorg ohne Display-Manager, i3, rofi, picom, Alacritty, PCManFM mit gvfs, Flatpak, btop |
| Dienste | `dbus`, `dhcpcd`, `wpa_supplicant`, `tailscaled`, `bluetoothd`, `alsa`, `rtkit` |
| Locale | `de_DE.UTF-8` erzeugen (Systemsprache bleibt `C.UTF-8`), Konsolentastatur auf `de` |
| Schriften | Red Hat Mono nach `/usr/share/fonts`, dazu die fontconfig-Regel, die `monospace` darauf umbiegt |
| Mauszeiger | Colloid in Weiß (`Colloid-dark-cursors`) systemweit nach `/usr/share/icons`, Größe 36, dazu `default/index.theme` als Auffangnetz für alles ohne eigene Einstellung |
| Eingabe | deutsches Tastaturlayout in X, Touchpad mit natürlichem Scrollen und Tap-to-Click, Drei-Finger-Gesten mit Karussell-Animation beim Arbeitsflächenwechsel |
| Hardware | udev-Regel gegen den WLAN-Softblock von `hp_wmi` beim Booten, dazu `etc/zzz.d/resume/20-funk`: nach der Bereitschaft geht WLAN ausnahmslos wieder an, Bluetooth in seinen letzten Zustand |
| Netz | Steuersocket von `wpa_supplicant` gehört der Gruppe `wheel`, damit das Netz-Menü ohne `sudo` suchen und verbinden kann |
| Fingerabdruck | auf Nachfrage: libfprint-Fork mit dem Treiber `synatlsmoc` und gepatchtes fprintd nach `/usr/local`, polkit-Regel, `pam_fprintd` für sudo und Login; das Sperrmenü entsperrt auf Fingertipp (`fingerabdruck/`) |
| Ton | PipeWire mit WirePlumber und PulseAudio-Schnittstelle, dazu `dumb_runtime_dir` (nicht in `base-system`) und `/run/user` aus `rc.local` — ohne `XDG_RUNTIME_DIR` startet PipeWire nicht |
| Bluetooth | `bluez`; der Adapter kommt so hoch, wie er zuletzt geschaltet war — `bluetooth` notiert jedes An und Aus in `~/.local/state/bluetooth-zustand`, die i3-Config stellt es beim Sitzungsstart nach. `AutoEnable` in `/etc/bluetooth/main.conf` bleibt dafür auf `false`: bluez selbst kennt nur *immer an* oder *immer aus*, keinen letzten Zustand |
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
Programm darin benannt (`5: code`) und verschwinden wieder, sobald das letzte
Fenster zu ist.

Jedes Autostart-Fenster hat eine eigene Fensterklasse — damit landet genau
*dieses* Fenster auf seiner Fläche, während normal gestartete Terminals sich
unverändert verhalten. Die Beschriftungen setzt `~/.local/bin/i3-workspace-names`
live nach der Fensterklasse; die Nummer bleibt vorn stehen, deshalb
funktionieren `workspace number N` und die `assign`-Regeln weiter.

### Blinken, wenn woanders etwas passiert

Will ein Programm auf einer *anderen* Fläche nach vorn — der Alltagsfall: ein
Klick in VS Code macht einen neuen Tab in Chrome auf, und Chrome liegt auf
Fläche 1 —, dann gibt i3 den Fokus nicht her, sondern setzt das
`urgent`-Flag. Bis dahin wurde der Knopf in der Leiste dabei nur still rot,
was man beim Schreiben übersieht. Jetzt **blinkt** er: hinter dem Namen steht
ein Punkt, und die Farbe wechselt im 0,6-Sekunden-Takt zwischen Warnrot und
dem Grau der inaktiven Flächen. Beim Hinschalten ist es sofort vorbei, i3
löscht das Flag dann selbst.

Das Blinken steckt in `i3-workspace-names` und nicht in einem eigenen Dienst:
der Name der Fläche ist der einzige Hebel, mit dem sich ein Knopf in i3bar
umfärben lässt (i3bar rendert ihn mit Pango-Markup, `bar { colors }` kennt nur
feste Farben). Zwei Dienste würden also im selben Takt umbenennen und sich
gegenseitig überschreiben. Die Nummer bleibt bewusst außerhalb des Markups —
`ws-swipe` liest die Namen aus `_NET_DESKTOP_NAMES` und schneidet die Nummer
mit `split(":")[0]` ab.

## Tastenbelegung

| Taste | Wirkung |
| --- | --- |
| `Strg+Alt+T` | Terminal |
| `$mod+space` | rofi als App-Drawer-Raster (Icons 5 nebeneinander, Name darunter) |
| `$mod+d` | rofi als Liste, mit `run` für Programme ohne `.desktop`-Eintrag |
| `$mod+Shift+d` | dmenu (Rückfallebene) |
| `$mod+e` | Dateimanager PCManFM (frei bewegliches Fenster) |
| `$mod+c` | VS Code (kacheln, nicht schwebend) |
| `$mod+Shift+f` | Vollbild |
| `$mod+t` | Aufteilung umschalten |
| `Strg+q` | Fenster schließen |
| `$mod+Shift+w` | Hintergrundbild wählen |
| `$mod+v` | Verlauf der Zwischenablage |
| `$mod+Shift+v` | senkrecht teilen |
| `$mod+1` … `$mod+4` | Arbeitsflächen (wie die Drei-Finger-Geste mit Karussell-Animation) |

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

### Karussell beim Arbeitsflächenwechsel

Drei Finger nach links wischen wechselt zur nächsten Arbeitsfläche, nach
rechts zur vorherigen — und die Fenster fahren dabei in die Wischrichtung
aus dem Bild, die neuen kommen von der Gegenseite herein. i3 kann das nicht
selbst, picom 13 kennt zwar Animationen, aber keine Arbeitsflächen. Die
Konstruktion:

- i3 un-/mapped die Fenster beim Wechsel; picom animiert das über die
  Trigger `hide` und `show`/`open` mit den Presets `fly-out` und `fly-in`
  (`config/.config/picom.conf`). `open` steht daneben, weil picom Fenster,
  die beim Start oder beim Neuladen seiner Konfig gerade auf einer anderen
  Fläche liegen, beim nächsten Auftauchen als `open` meldet — sie flögen
  sonst genau einmal nicht herein. Frisch geöffnete Fenster stört das nicht,
  die bekommen einen neuen i3-Rahmen ohne `_SWIPE_DIR`.
- Die Richtung kommt aus der X-Property `_SWIPE_DIR`, die
  `config/.local/bin/ws-swipe` vor jedem Wechsel auf alle i3-Rahmenfenster
  schreibt; zwei picom-Regeln wählen danach die Flugrichtung. Gesten
  (`libinput-gestures.conf`) und `$mod+1` … `$mod+0` laufen alle über
  dieses Skript, bei Nummern ergibt sich die Richtung aus dem Vergleich mit
  der aktuellen Fläche.
- Zwei Fallstricke stecken als Kommentar im Skript: die Property muss auf
  den **Rahmen** (nicht den Client), und picom braucht nach der Änderung
  einen erzwungenen Zeichenzyklus, sonst animiert es mit der alten Richtung.

Das ist kein Wischen, das am Finger klebt — libinput-gestures meldet erst
das Ende der Geste. Ein echtes Finger-Karussell gäbe es unter X11 nicht,
dafür bräuchte es einen Wayland-Compositor wie Hyprland oder niri.

## Titelleiste an Terminals, die etwas zu sagen haben

Fenster haben hier keinen Rahmen und keine Titelleiste (`default_border
none`) — bis auf eine Ausnahme: ein **Alacritty-Fenster, dessen Titel nicht
mehr der Standardtitel ist**, bekommt eine. Der Fall aus dem Alltag sind
mehrere gleichzeitig laufende **Claude-Code-Sitzungen** nebeneinander auf
einer Fläche. Die sehen alle gleich aus, und worum es in welcher geht, steht
nur weiter oben im Verlauf. Claude setzt aber den Fenstertitel auf das Thema
der Sitzung, mit einem Zustandszeichen davor: `✳` wartet auf Eingabe, `◐`/`◑`
arbeitet gerade. In der Titelleiste steht damit beides — das Thema und ob
gerade gerechnet wird.

Erkannt wird bewusst **nicht das Zeichen**, sondern „der Titel ist nicht mehr
`Alacritty`":

```
for_window [class="^Alacritty$" title="^(?!Alacritty$).*$"] border normal 0
for_window [class="^Alacritty$" title="^Alacritty$"] border none
```

Die Shell setzt hier gar keinen Titel, ein abweichender kommt also immer von
einem laufenden Programm — das hält auch dann, wenn Claude sein Zeichen mal
ändert, und nimmt `vim` und `ssh` gleich mit. `border normal 0` heißt
Titelleiste ja, Rahmen an den Seiten nein. Die zweite Zeile räumt sie wieder
weg, sobald der Titel zurückfällt; i3 wertet `title`-Kriterien bei **jeder**
Titeländerung neu aus, beides greift also im laufenden Betrieb. Die anderen
Terminals (`remote-term`, `vitals-dashboard`) laufen unter eigenen Klassen und
sind nicht betroffen.

Damit die Leiste nicht als Balken auffällt, sondern wie ein Stück Terminal
aussieht, ist sie **`#1d1d1d`** — nicht `#1e1e1e` wie der Terminalhintergrund
in `alacritty.toml`. Grund ist `opacity = 0.95`: das dunkle Wallpaper zieht
den Hintergrund eine Stufe herunter. Am Schirm nachgemessen mit `import` und
`magick ... histogram:` — Terminal `#1d1d1d`, Titelleiste mit `#1e1e1e` eben
`#1e1e1e`. Fokussiert und unfokussiert unterscheidet nur noch die Schriftfarbe.

Der Titel steht **mittig** (`title_align center`) — linksbündig klebt er in
der Ecke über dem Text, in der Mitte liest er sich wie eine Überschrift. Eine
eigene Höhe für Titelleisten kennt i3 nicht, sie ergibt sich aus der globalen
`font`. Nachgemessen über `deco_rect.height` in `i3-msg -t get_tree`:

| `font`-Größe | 11 | 12 | 13 | 14 |
|---|---|---|---|---|
| Titelleiste | 24 px | 26 px | 28 px | 30 px |

Eingestellt ist **11** — 24 px, und zugleich die Größe der Statusleiste, Leiste
oben und Titelleiste darunter passen also zusammen.

### Blinken, wenn eine Rückfrage ansteht

Geht man weg, während Claude arbeitet, bleibt eine Rückfrage stehen, bis man
zufällig wieder hinschaut. `~/.local/bin/claude-warte-blinken` lässt darum die
**Titelleiste** der betroffenen Sitzung pulsieren — im selben Rot und im selben
Takt wie der Arbeitsflächen-Knopf in der Leiste, es ist ja dieselbe Aussage.
Nur die Leiste blinkt, nicht das Fenster: i3 rendert `title_format` mit
Pango-Markup, ein Farbwechsel darin lässt den Inhalt darunter in Ruhe.

Der naheliegende Weg über das **urgent-Flag reicht dafür nicht**. Alacritty
setzt es bei der Terminal-Glocke nur, wenn das Fenster **nicht** den Fokus hat
— und genau im gefragten Fall, weggegangen mit der Sitzung im Vordergrund,
passiert dort nichts. Der Dienst liest deshalb den **Fenstertitel**, in dem
Claude seinen Zustand ohnehin mitschreibt: `✳` wartet auf Eingabe, `◐`/`◑`
arbeitet. Der **Wechsel** von arbeitet nach wartet ist das Ereignis — ein
Dauerzustand wäre es nicht, eine ruhende Sitzung steht schließlich immer auf
`✳`. Als zweite, davon unabhängige Quelle zählt das urgent-Flag weiterhin mit;
fällt eine der beiden aus, greift die andere.

Aufhören soll es, sobald man es gesehen hat — und „gesehen" heißt **anwesend**,
nicht „fokussiert": im gefragten Fall liegt das Fenster ja die ganze Zeit
vorne. Gemessen wird die echte Leerlaufzeit über die X-Erweiterung
**MIT-SCREEN-SAVER** (`screensaver_query_info().idle`, dafür `python3-xlib`).
Erst Fokus **und** eine Eingabe in den letzten 5 Sekunden räumen das Blinken
weg. Sitzt man davor und tippt, fängt es also gar nicht erst an.

Beim Erkennen gilt bewusst nur `✳` als „wartet" und alles andere als
„arbeitet", nicht umgekehrt: ändert Claude sein Zeichen, blinkt es dann eben
nicht mehr. Die Umkehrung würde bei jeder Titeländerung fälschlich
Dauerblinken auslösen, und das fällt weit unangenehmer auf. Zum Nachmessen
nimmt der Dienst `CLAUDE_BLINK_LOG=/tmp/blink.log` und schreibt dort jedes
`neu:`, `gesehen:` und `erledigt:` mit.

Zum Blinken kommt ein **Ton**: derselbe Übergang schickt eine Meldung per
`notify-send -a claude`, und die dunstrc hängt daran über `[ton-bei-meldung]`
von allein `melde-ton`. Der Ton muss also nirgends aufgerufen werden — genau
so, wie `melde-ton` es im eigenen Kopf beschreibt. Nebenbei landet die Meldung
im Verlauf hinter der Glocke: kommt man nach längerer Zeit zurück, steht dort
noch, was angestanden hat.

Ein **Klick auf diese Meldung springt zur wartenden Sitzung**. Dafür braucht
`meldung-klick` einen Sonderfall, denn hinter dem Absender „claude" steckt kein
Programm mit eigener Fensterklasse, sondern eine Sitzung *im* Terminal: gesucht
wird das Alacritty-Fenster mit `✳` im Titel. Ohne den Sonderfall greift die
unschärfste Stufe der Fenstersuche („Name irgendwo im Fenstertitel") und der
Klick landet bei einem Chrome-Fenster, in dem claude.ai offen ist.

Der erste Durchlauf nach dem Start nimmt den Zustand nur auf, ohne etwas
auszulösen — sonst gälte nach jedem `i3-msg restart` jede bereits wartende
Sitzung als frische Frage, und es klingelte für alle auf einmal.

## Benachrichtigungen

### Wie eine Meldung aussieht

Eckig, einzeilig, immer mit Icon. Die Form steht in
`config/.config/dunst/dunstrc`, das Icon geben die Skripte selbst mit.

- **Eckig.** `corner_radius = 0`, beim Fortschrittsbalken genauso. Das spart
  nebenbei die Transparenz: runde Ecken müssten den Hintergrund durchscheinen
  lassen, gerade nicht.
- **Einzeilig, höchstens ein Drittel breit.** `format = "<b>%s</b>  %b"` setzt
  den Text hinter den fetten Titel statt darunter; `word_wrap = no` und
  `ellipsize = end` schneiden hinten ab, nicht in der Mitte. `width = (240,
  640)` heißt: kurze Meldungen bleiben schmal, lange wachsen bis 640 px — ein
  Drittel der Bildbreite — und enden mit „…". `progress_bar_max_width` steht
  deshalb auf 600 statt auf 390, sonst bliebe der OSD-Balken im breiteren
  Fenster stehen.
- **Immer ein Icon**, links, 24×24 px. Die Skripte geben es per
  `dunstify -i <name>` mit; dafür fällt das Nerd-Font-Zeichen aus dem Titel
  weg. Was keins mitgibt, bekommt `default_icon = dialog-information`.

| Skript | Fall | Icon |
| --- | --- | --- |
| `osd` | stumm oder 0 % | `audio-volume-muted` |
| `osd` | ≤ 33 / ≤ 66 / darüber | `audio-volume-low` / `-medium` / `-high` |
| `osd` | Mikrofon an / stumm | `microphone-sensitivity-high` / `-muted` |
| `osd` | Helligkeit | `gpm-brightness-lcd` |
| `netz` | WLAN an / aus / verbindet | `network-wireless-connected` / `-offline` / `-acquiring` |
| `netz` | Tailscale an / aus | `network-vpn` / `network-offline` |
| `netz` | ging schief | `network-error` |
| `netz-ton` | Netzteil angesteckt | `ac-adapter` |
| `netz-ton` | abgezogen | `battery-000` … `battery-100` nach Ladung |
| `akku-wache` | knapp / kritisch | `battery-020` / `battery-010` |
| `akku-wache` | CPU heiß | `indicator-sensors-cpu` |
| `bluetooth` | an / aus / verbunden / Suche | `bluetooth-active` / `-disabled` / `-paired` / `edit-find` |
| `benachrichtigungen` | Verlauf leer | `notification-active` |

**Der Fallstrick steckt in `icon_theme`.** Dort stand `Papirus-Dark`, und
dessen symbolische Icons sind `#dfdfdf` — fast weiß, auf dem hellen
Meldungsfenster (`#e8e8e8`) also praktisch unsichtbar. „Dark" meint eben die
dunkle *Umgebung*, für die das Icon gedacht ist, nicht seine eigene Farbe.
Jetzt steht dort `Papirus-Light, Papirus, Adwaita, hicolor`; Papirus-Light
zeichnet dieselben Icons in `#444444`. Das große `Papirus` muss dahinter
stehen, weil Papirus-Light nur ein Aufsatz mit 7314 Icons ist und **nicht**
von Papirus erbt (`Inherits=breeze,hicolor`) — die Programm-Icons wie Chrome
kommen von dort.

Zwei Dinge, die auffallen und trotzdem in Ordnung sind: die „Aus"-Icons
(`audio-volume-muted`, `microphone-sensitivity-muted`, `bluetooth-disabled`)
zeichnet Papirus mit `opacity:.35`, also blass — bei upstream sieht „aus"
ausgegraut aus. Und kommt dieselbe Meldung zweimal, schreibt dunst `(1)`
davor: der Zähler gestapelter Dubletten, der die *zusätzlichen* Kopien meint.
`hide_duplicate_count = yes` würde ihn abschalten.

**Die Position gilt für alle Meldungen gemeinsam.** `origin` und `offset` sind
global und nicht pro Regel einstellbar, und zwei dunst-Instanzen gehen auch
nicht — den D-Bus-Namen `org.freedesktop.Notifications` gibt es nur einmal.
„Normale Meldungen oben, OSD unten" ist mit dunst allein also nicht zu haben;
hier steht deshalb alles oben mittig, das OSD eingeschlossen.

### Wie sie hereinfliegen

Dieselbe picom-Technik, nur ohne `_SWIPE_DIR`: eine dritte Regel auf
`class_g = 'Dunst'` lässt Meldungen von oben hereinfliegen und nach oben
wieder verschwinden (0,15 s). dunst selbst kann keine Animationen.

Zwei Dinge, die man dabei wissen muss:

- **Die Trigger sind unsymmetrisch.** dunst hält *ein* Fenster und mappt es
  nur ab und zu. picom meldet das erste Mappen nach dem Start als `open`,
  jedes weitere als `show` — steht nur `open` da, fliegt bloß die allererste
  Meldung. Beim Verschwinden ist es `hide`; `close` kommt erst, wenn dunst
  endet. Deshalb stehen in der Regel alle vier.
- **Mehrere Meldungen zeichnet dunst in dasselbe Fenster**, es wird nur
  größer. Geflogen wird also einmal am Anfang und einmal am Ende, nicht pro
  Meldung — und das OSD fliegt nicht bei jedem Tastendruck neu, solange die
  stehende Meldung ersetzt wird.

## Dateien, Text und Code

**PCManFM** auf `$mod+e` ist der Dateimanager, als schwebendes Fenster
(1000x750, mittig). Schwebend statt gekachelt, weil ein Dateimanager meist
nur kurz aufgemacht wird — er soll über der Arbeit liegen und sie nicht zur
Seite schieben. Drag-and-Drop in andere Fenster und Vorschaubilder für Bilder
kann er von Haus aus; Ordner sind ihm auch als `inode/directory` zugeordnet,
damit „Ordner öffnen" aus den Browser-Downloads dort landet.

Gelöschtes landet im **Papierkorb** unter `~/.local/share/Trash`, nicht im
Nichts — das macht libfm mit `use_trash=1` von allein, ohne dass etwas
installiert sein muss. Zu sehen bekommt man ihn aber erst mit **gvfs**:
`trash:///` ist eine GIO-Adresse, und ohne `gvfsd-trash` beantwortet GIO sie
mit „Operation not supported“. Der Eintrag *Trash Can* in der Seitenleiste
steht auch vorher schon da (`places_trash=1`), führt dann aber ins Leere.
Mit dem Paket öffnet er sich — über die Seitenleiste oder *Go → Trash*. Der
Rechtsklick auf eine Datei darin kennt *Restore* und legt sie an ihren alten
Pfad zurück; der Rechtsklick auf *Trash Can* in der Seitenleiste hat *Empty
Trash Can*. Endgültig löschen ohne Umweg bleibt `Umschalt+Entf`.


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

Der eingebaute Update-Prüfer ist abgeschaltet (`"update.mode": "none"` in den
Benutzereinstellungen). Ein Flatpak kann sich nicht selbst aktualisieren, und
Flathub hinkt Microsoft hinterher — die Meldung „Update verfügbar" kam
deshalb immer wieder, und der Klick darauf öffnete nur einen neuen Browser-Tab
auf der Download-Seite. Aktualisiert wird mit `flatpak update`.

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
| WLAN | Funk an/aus | Menü: Netze suchen, Passwort eingeben, verbinden |
| Tailscale | Tailnet an/aus | — |
| Ton | stumm um (Mausrad: lauter/leiser) | — |
| Glocke | Verlauf ansehen | Verlauf leeren |

Das Bluetooth-Icon zeigt den Zustand: stumpf heißt aus, blau heißt an, und
sobald ein Gerät verbunden ist, steht sein Name daneben. Während der Suche
wird der Block gelb und die Punkte hinter „sucht“ wandern — der Scan dauert
acht Sekunden und sähe sonst aus wie eingeschaltetes Bluetooth. Dieselben Schritte
gehen auch im Terminal — `bluetooth an|aus|um|zustand|menue`.

Das Gegenstück fürs Netz ist `~/.local/bin/netz`, gleicher Aufbau und gleiche
Befehle (`netz an|aus|um|ts-an|ts-aus|ts-um|zustand|menue`). Im Menü stehen
zuerst die beiden Schalter — WLAN und Tailscale —, darunter die Netze in
Reichweite mit Signalbalken und Schloss: verbunden, gespeichert oder neu. Ein
neues Netz fragt das Passwort in einem verdeckten rofi-Fenster ab. Gespeichert
wird es erst, wenn die Verbindung wirklich steht; ein Tippfehler landet also
nicht dauerhaft in der Konfig, wo ihn der Rechner bei jedem Start erneut
probieren würde. Das Passwort selbst geht nicht im Klartext dorthin, sondern
als der daraus gerechnete Schlüssel — dasselbe, was `wpa_passphrase` tut.

Jede dieser Handlungen meldet sich kurz über dunst: „WLAN an", „Tailscale aus",
„<Netzname> verbunden". Deshalb schaltet die Leiste auch nicht mehr selbst
per `rfkill`, sondern ruft `netz` auf — die Meldung hängt an einer Stelle statt
an zweien.

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
* **„Chrome wurde nicht ordnungsgemäß beendet"** nach jedem Herunterfahren
  liegt an `/etc/runit/shutdown.d/70-pkill.sh`: das schickt allen Prozessen
  SIGTERM, wartet **eine** Sekunde und schickt dann SIGKILL. Chrome braucht
  länger, um seine Sitzung wegzuschreiben, und wird mitten im Speichern
  erschlagen. Gegenmittel ist `system/usr/local/sbin/sanft-beenden`, das als
  `05-sanft-beenden.sh` **vor** dem Dienste-Stopp läuft: erst SIGTERM an die
  Hauptprozesse von Chrome, Brave und VS Code und bis zu 20 Sekunden warten,
  bis sie weg sind, dann der Rest der Sitzung mit fünf Sekunden Geduld. Zwei
  Feinheiten: Getroffen wird nur, wessen **argv[0] exakt** passt (`grep` auf
  `/app/extra/chrome` würde sonst auch den `chrome_crashpad_handler` treffen)
  und wessen Kommandozeile **kein** `--type=` enthält — die Renderer- und
  GPU-Kinder gehen mit dem Hauptprozess von selbst. Ohne Argument macht das
  Skript nur einen Trockenlauf und zeigt, wen es beenden würde; der Hook ruft
  es mit `--jetzt` auf. Nachlesen lässt sich der letzte Durchlauf in
  `/var/log/sanft-beenden.log`.
* **Chrome kann sich selbst nicht zum Standardbrowser machen.** Im Sandkasten
  fehlt `xdg-settings`, der Knopf läuft ins Leere (`failed to execvp`). Der
  Eintrag steht deshalb direkt in `~/.config/mimeapps.list`.
* **Flatpak-Apps öffnen keine Links, solange `xdg-desktop-portal` fehlt.**
  Im Sandkasten gibt es kein `xdg-open` zum Host; VS Code, Chrome und Brave
  reichen Links über `org.freedesktop.portal.OpenURI` weiter. Ohne Portal
  verpufft der Klick auf „Sign in" in VS Code lautlos, und auch der Rückweg
  (`vscode://`-Link aus dem Browser) kommt nie an. Dazu kommt: `gtk.portal`
  hat `UseIn=gnome`, und i3 setzt kein `XDG_CURRENT_DESKTOP` — darum steht in
  `~/.config/xdg-desktop-portal/portals.conf` ausdrücklich `default=gtk`.
  Prüfen: `gdbus call --session --dest org.freedesktop.portal.Desktop
  --object-path /org/freedesktop/portal/desktop --method
  org.freedesktop.portal.OpenURI.OpenURI '' 'https://example.com' '{}'` muss
  einen Browser-Tab öffnen.
* **Die `assign`-Regel trifft `Google-chrome`, nicht `chrome`.** Die WM_CLASS
  des Flatpak-Fensters vorher mit `i3-msg -t get_tree` nachsehen, nicht raten.
* **`Terminal=true` in einer `.desktop`-Datei ist hier eine Falle.** libfm
  sucht sich dann selbst ein Terminal und landet bei `xterm` — falsche
  Schrift, falsche Farben. Genau so kommen die `.desktop`-Dateien der
  Terminalprogramme aus den Paketen. Die eigenen Einträge unter
  `~/.local/share/applications/*-alacritty.desktop` rufen Alacritty deshalb
  ausdrücklich im `Exec` auf und lassen `Terminal=false`.
* **Ein Cursor-Thema braucht vier Einträge, nicht einen.** Damit der Zeiger
  wirklich überall stimmt — und zwar ab dem ersten Moment einer neuen
  Sitzung, ohne Nachhelfen:

  1. `XCURSOR_THEME`/`XCURSOR_SIZE` in `~/.xinitrc` (alles, was i3 startet),
  2. `Xcursor.theme`/`Xcursor.size` in `~/.Xresources` (Anwendungen, die
     ohne diese Umgebung starten),
  3. `gtk-cursor-theme-name`/`-size` in GTK 2, 3 und 4,
  4. **`/usr/share/icons/default/index.theme` mit `Inherits=`** — der Weg
     für alles, was von keinem der drei etwas weiß: das X-Wurzelfenster,
     Fenster ohne eigenen Zeiger (die erben ihn vom Elternfenster),
     Programme außerhalb der Sitzung. Fehlt diese Datei, bleibt es dort beim
     eingebauten X-Zeiger, egal wie sauber der Rest gesetzt ist.

  Nachprüfen lässt sich Punkt 4 ohne X: `XcursorLibraryLoadImage("left_ptr",
  NULL, 36)` über `ctypes` liefert dann trotzdem das Bild aus dem Thema.

* **Das Thema gehört nach `/usr/share/icons`, nicht nach `~/.icons`.**
  libXcursor sucht in `~/.local/share/icons:~/.icons:/usr/share/icons:/usr/share/pixmaps`
  (nachzulesen mit `strings /usr/lib/libXcursor.so.1`), ein Flatpak sieht
  vom Wirtssystem aber nur `/run/host/user-share/icons` (= `~/.local/share/icons`)
  und `/run/host/share/icons` (= `/usr/share/icons`). **`~/.icons` ist dort
  nicht vertreten** — ein Thema dort ist für jede native Anwendung sichtbar
  und für keine Flatpak-Anwendung.

* **Der Mauszeiger in Flatpak-Fenstern hängt an drei Dingen.** Erstens
  reicht Flatpak `XCURSOR_THEME`/`XCURSOR_SIZE` **nicht** in den Sandkasten
  durch — beide sind in `~/.xinitrc` gesetzt und stehen im Environment von
  i3, in der Sandbox sind sie trotzdem leer. Zweitens muss das Thema an
  einem der beiden `/run/host`-Pfade liegen (siehe oben). Drittens wird
  `XCURSOR_PATH` ausdrücklich auf genau diese beiden Pfade gesetzt — ohne
  die Variable sucht libXcursor im Sandkasten unter `/usr/share/icons`, und
  das ist dort die Runtime und nicht das Wirtssystem. Alle drei erledigt
  `flatpak override --user --env=…` (global, ohne App-Name, für alle
  Flatpaks).

  Findet Chromium/Electron das Thema nicht, fällt es auf **eingebaute
  Zeiger** zurück: die Größe stimmt dann (die kommt aus `XCURSOR_SIZE` bzw.
  den GTK-Einstellungen), das Aussehen nicht. „Richtige Größe, falscher
  Zeiger" ist also genau das Zeichen für ein Thema, das nicht gefunden wird
  — nicht für eine falsche Größenangabe.

* **Die Größenangabe eines Themas ist nicht die Pixelgröße.** Colloid bringt
  die Nenngrößen 24/30/36/48 mit, die zugehörigen Pixmaps sind aber
  32/40/48/64 px — der Pfeil füllt seine Fläche nicht aus. Nordzy dagegen
  zeichnet bei Nenngröße 48 auch 48 px. Dasselbe `XCURSOR_SIZE=48` sieht in
  Colloid deshalb rund ein Drittel größer aus. Wer die Größen zweier Themen
  vergleicht, misst die **Tinte** (Alpha-Bounding-Box der Pixmap), nicht die
  Nenngröße: Nordzy@48 ergibt 21×40 px, Colloid@36 ergibt 20×30 px,
  Colloid@48 wäre 26×40 px. Und: nur bei den gebauten Nenngrößen wird nicht
  skaliert — ein Zwischenwert wie 32 wäre unscharf.

* **Den Zeiger nachmessen geht nicht per Screenshot** — er ist ein Overlay
  des X-Servers und fehlt in `import` und `xwd`. `XFixesGetCursorImage` über
  `ctypes` liefert dagegen das Bild, das gerade angezeigt wird. Am
  zuverlässigsten vergleicht man es **pixelweise** gegen die Xcursor-Dateien
  beider Themen (Chunk-Typ `0xfffd0002`: Breite/Höhe/Hotspot ab Byte 16,
  ARGB-Daten ab Byte 36) — dann steht da nicht „48x48", sondern
  `Nordzy-cursors/left_ptr`. Der Hotspot allein reicht nicht: Pfeil und
  Textcursor unterscheiden sich stärker voneinander als dasselbe Symbol in
  zwei Themen (`left_ptr` 5,4 gegen 6,2 — `xterm` dagegen 22,22 gegen 22,24).
* **`xdotool mousemove` allein ändert den Zeiger nicht.** Ein reiner Warp
  lässt viele Anwendungen den Cursor nicht neu setzen — gemessen wird dann
  der alte. Eine winzige Relativbewegung hinterher (`mousemove_relative 3 3`
  und zurück) erzeugt das nötige Motion-Event.
* **Ein Themenwechsel ist in der laufenden Sitzung nicht nachmessbar.** Der
  X-Server hält den einmal geladenen Zeiger; i3 lädt seinen beim Start und
  setzt ihn auf Wurzelfenster und Rahmen. Fenster, die selbst keinen Zeiger
  setzen (PCManFM etwa), erben ihn von dort — dort steht nach einem Wechsel
  also weiter der **alte** Pfeil, obwohl das alte Thema schon gelöscht ist.
  Was der Wechsel gebracht hat, prüft man deshalb nicht am Bildschirm,
  sondern an der Auflösung: `XcursorGetTheme`/`XcursorGetDefaultSize` und
  `XcursorLibraryLoadImage` über `ctypes`, mit genau der Umgebung, die die
  neue Sitzung setzen wird — das ist derselbe Aufruf, den i3 macht.
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
