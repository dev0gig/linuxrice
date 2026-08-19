# Arbeitsflaeche 4 -- Vitals-Dashboard

Ein festes Systemmonitor-Dashboard auf Arbeitsflaeche 4 unter i3: ein
Alacritty-Fenster ohne Rahmen, darin eine zellij-Sitzung mit fuenf Panes.

```
+--------------------------------+----------------------+
|                                |  Datum + Uhr   (11)  |
|                                +-----------+----------+
|   btop                         | Daten-    | Sensoren |
|   volle Hoehe, 138 Spalten     | traeger   |          |  17
|                                |   (27)    |   (27)   |
|                                +-----------+----------+
|                                |  Netzverkehr   (15)  |
+--------------------------------+----------------------+
         138 Spalten                    54 Spalten
```

Ausgelegt auf 1920x1080 bei i3bar-Hoehe 30 und Red Hat Mono 13, was
**192x43 Zellen** ergibt. Alle Groessen im Layout sind ganze Zellen und
muessen exakt aufgehen -- siehe unten.

## Bestandteile

| Datei | Zweck |
| --- | --- |
| `home/.config/zellij/layouts/dashboard.kdl` | das Layout, Herzstueck |
| `home/.config/zellij/config.kdl` | zellij als reiner Dashboard-Halter (Locked Mode, keine Sitzungswiederherstellung) |
| `home/.local/bin/vitals` | Startskript, haengt eine laufende Sitzung wieder an |
| `home/.local/bin/vitals-clock` | Pane "Uhr": Datum oben, Uhrzeit in Siebensegment-Bloecken |
| `home/.local/bin/vitals-datentraeger` | Pane "Datentraeger": glances mit `fs` und `diskio` |
| `home/.local/bin/vitals-sensoren` | Pane "Sensoren": glances mit `sensors` |
| `home/.config/glances/*.conf` | Aliasse und Filter fuer die glances-Panes |
| `home/.config/btop/btop.conf` | btop, wichtig ist `theme_background = False` |
| `i3/vitals-auszug.conf` | die Zeilen aus der i3-Config, die dazugehoeren |

## Voraussetzungen

Void Linux: `xbps-install zellij btop glances bandwhich alacritty`

`bandwhich` braucht kein sudo -- das Void-Paket setzt dem Binary bereits
`cap_net_raw`, `cap_net_admin`, `cap_sys_ptrace` und `cap_dac_read_search`
als File-Capabilities.

## Einspielen

Am einfachsten ueber [`../setup.sh`](../) -- das richtet das Dashboard
zusammen mit dem Rest der Arbeitsumgebung ein und setzt dabei auch die
absoluten Pfade richtig.

Von Hand geht es so:

```sh
cp -r home/.config/*  ~/.config/
cp    home/.local/bin/vitals* ~/.local/bin/
chmod 755 ~/.local/bin/vitals*

# KDL kennt kein $HOME -- die Pfade im Layout muessen absolut sein
sed -i "s|/home/user|$HOME|g" ~/.config/zellij/layouts/dashboard.kdl \
                              ~/.local/bin/vitals-sensoren
```

Dann die Zeilen aus `i3/vitals-auszug.conf` in `~/.config/i3/config`
uebernehmen und `i3-msg restart`.

## Was man wissen muss, bevor man Zahlen aendert

Die Groessen im Layout sind nicht Geschmack, sondern nachgemessen. Drei
Dinge stehen dahinter:

### 1. zellij 0.44 und Groessenangaben

* Hat ein Container eine eigene Groesse, braucht **jedes** Kind eine.
  Fehlt eine, bricht zellij mit `Implicit sizing within fixed-size panes
  is not supported` ab und das Terminal schliesst sich sofort wieder.
* In der Verschachtelung greifen nur **ganze Zahlen**, keine Prozente.
  Durchgehende Prozentangaben ueber zwei Ebenen werden still verworfen:
  aus 75/25 wurde 50/50, aus 24/56/20 wurde 33/33/33.
* Die Summen muessen die Terminalgroesse exakt treffen. 138+54 = 192
  Spalten, 11+17+15 = 43 Zeilen. Eine Zeilensumme von 42 genuegte schon
  zum Abbruch.

Kontrolle: `zellij --session vitals action dump-layout` -- der `tab`-Block
zeigt die tatsaechlichen Groessen, nicht die gewuenschten.

### 2. glances braucht 25 nutzbare Spalten

Darunter laesst es die Wertspalte **komplett** weg und zeigt nur die
Beschriftungen -- Sensoren ohne Temperaturen, Datentraeger ohne `W/s` und
`Total`. Grund steht in `glances/plugins/sensors/__init__.py`: die
Beschriftung wird auf `Panebreite - 12` aufgefuellt, der Wert danach
rechtsbuendig in ein fest 14 Zeichen breites Feld gesetzt. Beides ohne
Konfigurationsschalter, der Abstand dazwischen ist also nicht einstellbar.

Der zellij-Panerahmen kostet zwei weitere Spalten, das Pane muss also
mindestens **27** breit sein. Zwei davon sind 54 -- darum bekommt btop 138
von 192 Spalten (72 %) und nicht die glatten drei Viertel.

In der Hoehe braucht die Sensorliste **15 Zeilen Innenraum**; bei 13 fielen
`Luefter 2` und `Akku` still weg, obwohl Zeilen frei blieben.

### 3. Die Uhr zeichnet sich selbst

`vitals-clock` ist ein kleines Python-Skript und kein `tty-clock` mehr.
tty-clock kann das Datum nur **unter** die Ziffern setzen -- ohne `-x`
faellt es in die letzte Ziffernzeile, mit `-x` kommen zwei Kaesten dazu --
und es zeichnet die Datumszeile nach einer Terminal-Groessenaenderung gar
nicht mehr. Genau eine solche Aenderung macht zellij beim Start, weil es
das Pane erst in Vorgabegroesse anlegt und dann auf die Layoutgroesse
zieht.

Zwei Fallstricke beim Selberzeichnen im Pane:

* **Absolut positionieren** mit `ESC[Zeile;SpalteH`. Mit Zeilenumbruechen
  gezeichnet schiebt die letzte Zeile das Bild weiter.
* **Niemals `ESC[2J`.** zellij schiebt das Geloeschte in den Rueckscroll
  und schreibt `SCROLL: 0/9` in den Panetitel, bei jedem Minutenwechsel
  ein Stueck mehr. `ESC[3J` raeumt das auch nicht weg. Stattdessen jede
  Zeile ueber ihre volle Breite ueberschreiben.

### Terminalgroesse messen statt raten

```sh
alacritty -e sh -c 'stty size > /tmp/size.txt; sleep 2'
```

Ergab 43x192 -- nicht die zunaechst vermuteten 50 Zeilen. Nach jeder
Aenderung an Schriftgroesse oder i3bar-Hoehe neu messen und die
Layoutzahlen anpassen.

### Ausprobieren, ohne den Desktop anzufassen

Ein Pseudoterminal fester Groesse aufmachen (`pty.fork` plus `TIOCSWINSZ`)
und darin `zellij --new-session-with-layout` starten. Damit lassen sich
Panebreiten und -hoehen durchprobieren, bevor die echte Sitzung neu
startet.
