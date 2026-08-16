#!/bin/bash
set -e

# ============================================================
# Termux i3 Minimal — alles in einem Skript
#
# Baut auf einem FRISCHEN Termux eine komplette i3-Sitzung:
#   Termux-X11  +  i3  +  xterm  +  Firefox  +  Startmenue
#
# Bewusst NICHT dabei: Desktop-Umgebung, Panel, Compositor,
# Theme-Dienst, Wallpaper, Launcher, Dateimanager.
# Es laufen genau zwei Programme in der Sitzung: xterm und Firefox.
#
# Aufruf:
#   curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-i3-minimal/setup_i3.sh | bash
#
# Getestet auf: Samsung Galaxy Z Fold 7 (Snapdragon / Adreno 830)
# ============================================================

# --- Sicherheitsnetz: nur in Termux laufen lassen -----------
# Auf einem normalen Linux-Rechner wuerde das Skript Unsinn anrichten
# (pkg gibt es dort nicht, und ~/.bashrc wuerde trotzdem angefasst).
case "${PREFIX:-}" in
  *com.termux*) : ;;
  *)
    echo "FEHLER: Das hier gehoert in Termux auf dem Handy, nicht hierher." >&2
    exit 1
    ;;
esac

MENU="$HOME/.termux-menu.sh"
CONF="$HOME/.termux-menu.conf"
START="$HOME/start-i3.sh"
I3CONF="$HOME/.config/i3/config"
TPROPS="$HOME/.termux/termux.properties"
# Nur noch da, um die Merkdatei aelterer Fassungen aufzuraeumen — eine
# Startseite wird bewusst nicht mehr gespeichert.
FFCONF="$HOME/.i3-firefox.conf"

echo "=== [1/8] System auf einen Stand bringen ==="
export DEBIAN_FRONTEND=noninteractive
pkg update -y

# Hinweis, wenn Termux sich den Spiegelserver selbst aussucht — das ging
# schon zweimal daneben (einmal Indien mit ~20 kB/s, einmal ein Spiegel mit
# einem halb kaputten Paketstand).
if ! grep -rqs 'termux' "$PREFIX/etc/apt/sources.list.d/" 2>/dev/null; then
  echo ""
  echo "  Hinweis: Es ist keine feste Spiegel-Gruppe gewaehlt. Bei langsamen"
  echo "  Downloads oder Paketfehlern hilft fast immer:"
  echo "      termux-change-repo    ->  Mirror group  ->  Europe"
  echo ""
fi

# --- Halb eingerichtete Pakete reparieren --------------------------------
# Bricht eine Installation mittendrin ab (kein Netz, abgewuergt, kaputtes
# Paket), bleibt dpkg in einem halben Zustand stehen. Jeder weitere Aufruf
# scheitert dann an diesem Rest, auch wenn er selbst voellig in Ordnung ist.
# Darum vor allem anderen aufraeumen. Beides darf fehlschlagen — wenn nichts
# kaputt ist, gibt es hier auch nichts zu tun.
dpkg --configure -a 2>/dev/null || true
apt-get -y --fix-broken install 2>/dev/null || true

# --- Rundum-Upgrade: PFLICHT, nicht Kuer ---------------------------------
# ⚠️ Termux vertraegt KEINE Teil-Aktualisierungen. Die Basis-Pakete aus der
# heruntergeladenen APK sind oft Monate alt, die Spiegelserver liefern immer
# den neuesten Stand. Mischt man beides, passen die C++-Bibliotheken nicht
# mehr zusammen und Programme lassen sich nicht mehr einrichten:
#
#   CANNOT LINK EXECUTABLE "ffmpeg": cannot locate symbol ...
#     referenced by "libplacebo.so"
#   dpkg: dependency problems prevent configuration of firefox
#
# Genau das ist am 16.8.2026 passiert, weil hier frueher bewusst NICHT
# aktualisiert wurde. Termux selbst nennt in der Fehlermeldung "pkg upgrade"
# als Loesung. Deshalb ist das Upgrade jetzt der Normalfall.
#
# Abschalten nur, wenn man weiss warum:  KEIN_UPGRADE=1 ./setup_i3.sh
if [ "${KEIN_UPGRADE:-0}" = "1" ]; then
  echo "  KEIN_UPGRADE=1 gesetzt — Rundum-Upgrade uebersprungen."
  echo "  ⚠️  Bei Fehlern wie 'cannot locate symbol' ist genau das die Ursache."
else
  echo "  Alle Pakete aktualisieren (Termux vertraegt keine Mischstaende)..."
  pkg upgrade -y -o Dpkg::Options::="--force-confnew" || {
    echo "  Upgrade unvollstaendig — versuche zu reparieren..."
    dpkg --configure -a 2>/dev/null || true
    apt-get -y --fix-broken install 2>/dev/null || true
  }
fi

# --- Installieren, ohne beim ersten Fehler alles hinzuwerfen -------------
# Frueher hat ein einziges kaputtes Paket den Lauf schon in Schritt 2 beendet
# — die i3-Konfiguration, das Startskript und das Menue wurden dann gar nicht
# mehr geschrieben. Das ist der schlechteste Ausgang: viel angefasst, nichts
# eingerichtet. Jetzt wird gemerkt was fehlt, der Rest laeuft durch, und am
# Ende steht eine Liste.
FEHLT=""
inst() {
  pkg install -y -o Dpkg::Options::="--force-confnew" "$@" && return 0
  echo "  ⚠️  fehlgeschlagen: $*"
  FEHLT="$FEHLT $*"
  # ⚠️ Hier MUSS 0 zurueckkommen, nicht 1.
  # Ganz oben steht "set -e": Sobald eine Funktion einen Fehlerwert liefert,
  # beendet die Shell das ganze Skript. Mit "return 1" waere der Lauf also
  # trotzdem abgebrochen — genau das, was diese Funktion verhindern soll.
  # Gemerkt wird der Fehlschlag stattdessen in FEHLT und am Ende gemeldet.
  return 0
}

# Prueft, ob ein Paket vorhin durchgefallen ist.
# Die Leerzeichen um beide Seiten sorgen dafuer, dass "firefox" nicht
# versehentlich in einem laengeren Paketnamen gefunden wird.
fehlt() {
  case " $FEHLT " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# Fuer Kuer-Pakete: darf fehlen, taucht am Ende NICHT als Mangel auf.
# (rxvt-unicode etwa gibt es in Termux gar nicht — das ist kein Fehler.)
inst_opt() {
  pkg install -y -o Dpkg::Options::="--force-confnew" "$@" 2>/dev/null && return 0
  echo "  Hinweis: nicht verfuegbar, uebersprungen: $*"
  return 0
}

echo "=== [2/8] X11-Repo freischalten ==="
inst x11-repo

echo "=== [3/8] Pakete installieren ==="
inst termux-x11-nightly
inst mesa mesa-vulkan-icd-freedreno
# i3 und Terminal zuerst und getrennt von Firefox: Firefox ist mit ~66 MB der
# mit Abstand groesste Brocken. Haengt oder scheitert der, soll die Sitzung
# trotzdem benutzbar sein.
# Das Terminal wird bewusst NICHT hier mitinstalliert, sondern erst weiter
# unten im eigenen Abschnitt — dort steht ausfuehrlich, warum "xterm" in
# Termux die falsche Wahl ist.
inst i3 openssh

echo "--- Firefox (~66 MB, der grosse Brocken) ---"
inst firefox
if fehlt firefox; then
  echo ""
  echo "  i3 wird trotzdem fertig eingerichtet und ist startbar."
  echo "  Zwei haeufige Ursachen:"
  echo "    - Sehr langsamer Spiegelserver -> termux-change-repo (Europe)"
  echo "    - 'cannot locate symbol' / dpkg-Fehler -> Mischstand der Pakete,"
  echo "      dann hilft:  pkg upgrade -y ; dpkg --configure -a"
  echo "  Danach nachholen mit:  pkg install firefox"
  echo ""
fi

# Kuer: schoener, aber nicht kriegsentscheidend.
#   ttf-dejavu      Schrift. htop und tmux auf dem Server zeichnen ihre Balken
#                   und Linien mit Sonderzeichen — ohne passende Schrift sieht
#                   das kaputt aus.
#   xorg-xsetroot   ersetzt den haesslichen X-Standard-Mauszeiger ("X") durch
#                   einen normalen Pfeil.
# ttf-dejavu steht weiter unten beim Terminal — dort ist es Pflicht, nicht Kuer.
inst_opt xorg-xsetroot

# --- Mauszeiger-Thema ----------------------------------------------------
# Der X-Standardzeiger ist winzig und altbacken. Die Groesse allein macht
# XCURSOR_SIZE im Startskript — das hier ist nur das Aussehen.
# Faellt der Download aus, ist das nicht schlimm: Ohne den Ordner nimmt X
# seinen Standardzeiger, und XCURSOR_SIZE wirkt trotzdem.
CURSOR_THEME="GoogleDot-Blue"
CURSOR_URL="https://github.com/ful1e5/Google_Cursor/releases/latest/download/GoogleDot-Blue.tar.gz"
if [ -d "$HOME/.icons/$CURSOR_THEME" ]; then
  echo "  Mauszeiger $CURSOR_THEME ist schon da."
else
  echo "--- Mauszeiger $CURSOR_THEME ---"
  CTMP="$(mktemp -d)"
  if curl -fsSL -o "$CTMP/cursor.tar.gz" "$CURSOR_URL" \
     && tar -xf "$CTMP/cursor.tar.gz" -C "$CTMP" \
     && [ -d "$CTMP/$CURSOR_THEME" ]; then
    mkdir -p "$HOME/.icons"
    mv "$CTMP/$CURSOR_THEME" "$HOME/.icons/"
    echo "  installiert nach ~/.icons/$CURSOR_THEME"
  else
    echo "  Hinweis: Download fehlgeschlagen — X nimmt seinen Standardzeiger."
  fi
  rm -rf "$CTMP"
fi

# --- Ein Terminal, das UTF-8 kann --------------------------------------
# ⚠️ DIE WICHTIGSTE STELLE IM GANZEN SKRIPT — hier lag lange ein Fehler.
#
# In Termux gibt es KEIN Paket namens "xterm". "xterm" ist nur ein virtueller
# Name, den das Paket ATERM bereitstellt (Provides: xterm). aterm ist ein Fork
# des alten rxvt von 1998, aus der Zeit VOR Unicode: klassische X-Core-Fonts,
# kein UTF-8. Umlaute, Rahmenlinien und die Sonderzeichen, mit denen htop
# seine Balken malt, kommen als Buchstabensalat heraus — und tmux ueber SSH
# ist damit praktisch unbenutzbar, weil dessen Trennlinien zerfallen.
#
# Frueher stand hier "inst_opt rxvt-unicode". Dieses Paket gibt es in Termux
# aber ueberhaupt nicht (nachgeprueft am 17.8.2026 in der Paketliste des
# x11-repo). inst_opt darf fehlschlagen und meldet nichts weiter — also fiel
# die Auswahl unten JEDES MAL still auf aterm zurueck. Genau deshalb sah das
# Terminal kaputt aus.
#
# Diese Terminals gibt es in Termux wirklich. Ausgewaehlt nach Eignung:
#   lxterminal      224 kB, braucht nur gtk3 + libvte  -> ERSTE WAHL
#                   VTE ist dieselbe Terminal-Technik wie in GNOME/XFCE:
#                   lupenreines UTF-8, frei skalierbare Schrift.
#   xfce4-terminal  552 kB, zieht zusaetzlich xfconf und libxfce4ui mit.
#                   xfconf ist ein Hintergrunddienst ueber D-Bus — in einer
#                   nackten i3-Sitzung ohne D-Bus ein unnoetiges Risiko.
#                   Darum nur zweite Wahl, obwohl technisch gleichwertig.
#   st              136 kB, echtes UTF-8, aber ohne Scrollback und nur zur
#                   Uebersetzungszeit einstellbar. Reserve.
#   aterm/xterm     der oben beschriebene Notnagel. Nur, wenn sonst nichts da
#                   ist — dann lieber ein kaputtes Terminal als gar keines.
echo "--- Terminal mit UTF-8-Faehigkeit ---"
inst lxterminal
# Schrift ist hier PFLICHT, nicht Kuer: VTE zeichnet ueber fontconfig. Ohne
# eine anstaendige Monospace-Schrift fehlen genau die Sonderzeichen wieder,
# derentwegen wir das Terminal ueberhaupt gewechselt haben.
inst ttf-dejavu fontconfig
# Notnagel, falls lxterminal nicht durchkommt. 188 kB — billiger als eine
# Sitzung ganz ohne Terminal.
inst_opt xterm

LXCONF="$HOME/.config/lxterminal/lxterminal.conf"
if command -v lxterminal >/dev/null 2>&1; then
  # --no-remote ist bei lxterminal PFLICHT: Ohne diese Option reicht ein
  # zweiter Aufruf die Anfrage an das schon laufende Fenster weiter und macht
  # dort nur einen neuen Reiter auf. In i3 will man aber ein eigenes Fenster,
  # das man auf eine eigene Arbeitsflaeche legen kann.
  TERMCMD="lxterminal --no-remote"
  echo "  Terminal: lxterminal (VTE, volles UTF-8)"
elif command -v xfce4-terminal >/dev/null 2>&1; then
  # --hide-menubar/-toolbar: die Leisten oben sind in einer Sitzung, die auf
  # Vollbild ausgelegt ist, nur verlorener Platz. Ohne diese Optionen muesste
  # man sie in jedem neuen Fenster von Hand wegklicken — die Einstellung
  # merkt sich xfce4-terminal naemlich nicht ueber Fenster hinweg.
  TERMCMD="xfce4-terminal --hide-menubar --hide-toolbar"
  echo "  Terminal: xfce4-terminal (VTE, volles UTF-8)"
elif command -v st >/dev/null 2>&1; then
  TERMCMD="st -f \"DejaVu Sans Mono:size=13\""
  echo "  Terminal: st (UTF-8, aber ohne Scrollback)"
else
  TERMCMD="xterm -bg rgb:1a/1a/1a -fg rgb:d0/d0/d0"
  echo ""
  echo "  ⚠️  WARNUNG: Nur aterm gefunden (das steckt hinter 'xterm')."
  echo "      Sonderzeichen, Umlaute und tmux-Linien werden falsch angezeigt."
  echo "      Nachholen mit:  pkg install lxterminal"
  echo ""
fi

# --- lxterminal einstellen ------------------------------------------------
# Wird bei jedem Lauf neu geschrieben, wie alles andere auch.
# Ohne diese Datei startet lxterminal weiss, mit Menueleiste und Bildlaufleiste.
if command -v lxterminal >/dev/null 2>&1; then
  mkdir -p "$(dirname "$LXCONF")"
  cat > "$LXCONF" <<'LXEOF'
[general]
fontname=DejaVu Sans Mono 12
selchars=-A-Za-z0-9,./?%&#:_
scrollback=10000
bgcolor=rgb(26,26,26)
fgcolor=rgb(208,208,208)
palette_color_0=rgb(26,26,26)
palette_color_8=rgb(85,85,85)
disallowbold=false
cursorblinks=false
cursorunderline=false
audiblebell=false
tabpos=top
geometry_columns=100
geometry_rows=30
hidescrollbar=true
hidemenubar=true
hideclosebutton=true
hidepointer=true
disablef10=false
disablealt=false
LXEOF
  echo "  geschrieben: $LXCONF (Schrift 12, dunkel, ohne Leisten)"
fi

echo "=== [4/8] i3-Konfiguration schreiben ==="
mkdir -p "$(dirname "$I3CONF")"
cat > "$I3CONF" <<'I3EOF'
# ~/.config/i3/config
# Erzeugt von setup_i3.sh (linuxrice/termux-i3-minimal).
#
# Grundgedanke: EIN Fenster pro Arbeitsflaeche, immer bildschirmfuellend.
# Kein Rahmen, keine Titelleiste, keine Statusleiste.

set $mod Mod4
# ^ Mod4 ist die Super-/Windows-Taste.
#
# FALLS SAMSUNG DeX DIE SUPER-TASTE SCHLUCKT: die Zeile oben mit einer Raute
# auskommentieren und stattdessen die naechste Zeile freigeben (Alt statt Super).
# Vorher pruefen — im xterm ausfuehren und Super druecken; kommt keine Zeile
# mit "Super_L", schluckt Android die Taste:
#     xev -event keyboard | grep -i keysym
# set $mod Mod1

# Schrift nur fuer i3s eigene Meldungen (Fehlerbalken). Titelleisten gibt es
# hier keine, darum ist die Wahl praktisch egal.
font pango:monospace 10

# Kein Rahmen, keine Titelleiste, keine Kante. Ein Fenster = ganzer Schirm.
default_border none
default_floating_border none
hide_edge_borders both

# Am DeX mit Maus: der Fokus soll NICHT wechseln, nur weil der Zeiger
# ueber ein anderes Fenster huscht.
focus_follows_mouse no

# Fenster mit gedrueckter Super-Taste ziehen/skalieren (nur fuer Ausnahmefaelle).
floating_modifier $mod

# --- Terminal -------------------------------------------------------------
# Diese Zeile setzt setup_i3.sh je nach dem, was auf dem Geraet vorhanden ist.
# Im Normalfall steht hier lxterminal — ein VTE-Terminal, das echtes UTF-8
# kann. Nur so werden Umlaute, tmux-Linien und die Balken von htop
# richtig dargestellt.
#
# Schrift, Farben und Bildlauf stehen NICHT hier, sondern in
#   ~/.config/lxterminal/lxterminal.conf
# Dort die Zahl hinter "fontname=DejaVu Sans Mono" aendern und ein neues
# Fenster oeffnen — ein i3-Neustart ist dafuer nicht noetig.
set $term @TERM@

# --- Tastenkuerzel --------------------------------------------------------
bindsym $mod+Return          exec $term
bindsym Control+Mod1+t       exec $term
bindsym $mod+f               exec firefox

# Fenster schliessen — bewusst die altbekannten Tasten aus jedem normalen
# Linux-Desktop, keine i3-Eigenheiten.
bindsym Control+q            kill
bindsym Mod1+F4              kill

# Vollbild liegt bewusst auf Shift+f, weil $mod+f hier Firefox startet.
# (In einer Standard-i3-Config waere $mod+f das Vollbild.)
bindsym $mod+Shift+f         fullscreen toggle

bindsym $mod+1               workspace 1
bindsym $mod+2               workspace 2
bindsym $mod+3               workspace 3

bindsym $mod+Shift+r         restart
# Beenden liegt absichtlich weit ab von allem anderen — sonst fliegt man
# irgendwann aus Versehen aus der Sitzung.
bindsym $mod+Shift+BackSpace exit

# --- Start ----------------------------------------------------------------
# Firefox landet immer auf Arbeitsflaeche 1, egal wann er startet.
assign [class="(?i)firefox"] 1

# Statt des X-Standardzeigers (ein schwarzes "X") ein normaler Pfeil.
exec --no-startup-id xsetroot -cursor_name left_ptr

exec --no-startup-id firefox
# Terminal auf Arbeitsflaeche 2 — und dort bleibt der Blick nach dem Start.
exec --no-startup-id i3-msg 'workspace 2; exec @TERM@'
I3EOF

# Den erkannten Terminal-Aufruf einsetzen. Als Trennzeichen fuer sed dient
# das Rohr, weil im Befehl selbst Schraegstriche vorkommen (rgb:1a/1a/1a).
sed -i "s|@TERM@|$TERMCMD|g" "$I3CONF"
echo "  geschrieben: $I3CONF"

echo "=== [5/8] Startskript schreiben ==="
cat > "$START" <<'STARTEOF'
#!/bin/bash
# Startet die i3-Sitzung. Erzeugt von setup_i3.sh.

# Reste einer abgewuergten Sitzung wegraeumen. Android beendet die X-Sitzung
# im Hintergrund gern selbst, waehrend die Termux-Shell weiterlaeuft.
# "aterm" muss mit in die Liste: was in Termux als xterm installiert wird,
# laeuft als Prozess unter dem Namen aterm — "killall xterm" fasst es nicht an.
killall -9 termux-x11 i3 lxterminal xfce4-terminal st xterm aterm 2>/dev/null
sleep 1

# WICHTIG: Das Startmenue setzt TERMUX_MENU_DONE und EXPORTIERT es, damit es
# sich nicht selbst endlos aufruft. Wird i3 aus dem Menue heraus gestartet,
# erbt jedes spaeter geoeffnete xterm diese Variable — und das Menue erscheint
# dort dann NIE. Darum hier abraeumen.
unset TERMUX_MENU_DONE

# GPU: Zink (OpenGL) ueber turnip (Vulkan/Adreno).
# Wirkt fuer Programme, die OpenGL ueber GLX ansprechen. Firefox nicht — der
# will EGL und rendert hier dauerhaft auf der CPU. Siehe README.
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
export MESA_NO_ERROR=1

# Dunkle Fensterrahmen und Menues in Firefox. Kostet nichts, braucht kein
# Paket und keinen Hintergrunddienst — Adwaita-dark steckt in GTK selbst.
# Fuer dunkle WEBSEITEN reicht das nicht, das macht die Firefox-Einstellung
# ui.systemUsesDarkTheme (siehe README).
export GTK_THEME=Adwaita:dark

# --- Mauszeiger ----------------------------------------------------------
# GROESSE: einfach die Zahl aendern, danach die Sitzung neu starten. Wirkt
# auch ganz ohne eigenes Zeiger-Thema. Der X-Standard ist winzig; auf dem
# Fold-Bildschirm sind 32 ein guter Wert, 40-48 gehen deutlich groesser.
export XCURSOR_SIZE=32

# AUSSEHEN: Der Name muss einem Ordner ~/.icons/<Name>/cursors/ entsprechen.
# Fehlt der Ordner, nimmt X einfach seinen Standardzeiger — es geht also
# nichts kaputt, wenn hier etwas Falsches steht.
export XCURSOR_THEME=GoogleDot-Blue

# Ohne eine UTF-8-Sprachumgebung zeigt auch ein moderner Terminal Umlaute und
# Rahmenlinien falsch an — er weiss dann schlicht nicht, dass die Bytes
# UTF-8 sind.
export LANG="${LANG:-en_US.UTF-8}"

termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0

exec i3
STARTEOF
chmod +x "$START"
echo "  geschrieben: $START"

echo "=== [6/8] Startmenue einrichten ==="

# --- Ziel-Rechner erfragen ------------------------------------------------
# Der Name des eigenen Servers steht bewusst NICHT im Repo, sondern nur hier
# lokal auf dem Handy. Das Repo bleibt damit neutral.
#
# Es wird bei JEDEM Lauf gefragt — das Skript soll alles neu schreiben, ohne
# Ausnahme. Der bisherige Wert steht als Vorschlag dabei: Enter uebernimmt ihn.
#
# Gelesen wird von /dev/tty, nicht von der Standardeingabe: bei
# "curl ... | bash" haengt an der Standardeingabe das Skript selbst, ein
# normales "read" wuerde die naechste Skriptzeile verschlucken.

# Bisheriges Ziel aus dem gespeicherten Befehl herausloesen, als Vorschlag.
ALT_ZIEL=""
if [ -f "$CONF" ]; then
  # Dieselbe optionsfeste Erkennung wie im Menue: Ohne die Liste der Optionen,
  # die selbst noch einen Wert nach sich ziehen, wuerde aus "ssh -p 2222 rechner"
  # die Zahl 2222 als Ziel herausfallen.
  ALT_ZIEL="$(grep -v '^[[:space:]]*#' "$CONF" 2>/dev/null | grep -v '^[[:space:]]*$' \
              | head -n 1 | awk '
      BEGIN { split("-b -c -D -E -e -F -I -i -J -L -l -m -O -o -p -Q -R -S -W -w", _o, " ")
              for (k in _o) argopt[_o[k]] = 1 }
      { for (i = 1; i <= NF; i++) if ($i == "ssh") {
          for (j = i + 1; j <= NF; j++) {
            if ($j ~ /^-/) { if ($j in argopt) j++; continue }
            print $j; exit
          } } }')"
fi

# ⚠️ AB HIER WIRD DER SERVERNAME NIE AUF DEN BILDSCHIRM GESCHRIEBEN.
#
# Der Grund ist keine Geheimniskraemerei um ihrer selbst willen: Terminal-
# Ausgaben landen erfahrungsgemaess in Chats, Fehlerberichten und Screenshots.
# Stand der Name als Vorschlag in der Zeile ("Eingabe [Enter = benutzer@rechner]"),
# wanderte er beim Kopieren jedes Mal mit. Das Skript bestaetigt darum nur noch,
# DASS ein Wert da ist — nie, WELCHER. In den Dateien steht er natuerlich
# weiterhin, sonst koennte sich das Menue ja nicht anmelden.
ZIEL=""
if [ -n "${ZIEL_VORGABE:-}" ]; then
  # Vorgabe von aussen:  ZIEL_VORGABE=benutzer@rechner ./setup_i3.sh
  # Damit laeuft das Setup auch ohne Tastatur komplett durch.
  ZIEL="$ZIEL_VORGABE"
  echo "  Server aus der Vorgabe uebernommen."
elif [ ! -r /dev/tty ]; then
  # Ohne Tastatur-Kanal kann nicht gefragt werden — dann bliebe stillschweigend
  # der alte Wert stehen. Genau das soll NICHT unbemerkt passieren.
  echo ""
  echo "  ⚠️  Keine Tastatureingabe moeglich (kein /dev/tty)."
  if [ -n "$ALT_ZIEL" ]; then
    echo "      Der bisher eingetragene Server bleibt stehen."
  else
    echo "      Es ist auch kein bisheriger Server eingetragen."
  fi
  echo "      Ohne Nachfrage setzen:  ZIEL_VORGABE=benutzer@rechner ./setup_i3.sh"
  echo ""
else
  printf '\n  Server fuer das Menue — bitte in der Form  benutzer@rechner\n'
  printf '\n'
  printf '  ⚠️  Der Benutzername ist hier PFLICHT, nicht Zierde.\n'
  printf '      Android gibt Termux einen kryptischen Benutzernamen (etwa u0_a123).\n'
  printf '      Laesst man den Benutzer weg, versucht ssh sich mit GENAU\n'
  printf '      diesem Namen anzumelden — den es auf dem Server nicht gibt.\n'
  printf '      Tailscale antwortet dann mit "user is not permitted".\n'
  printf '      Nach einer Neuinstallation von Termux aendert sich der Name.\n'
  printf '\n'
  # Der bisherige Wert wird bewusst NICHT angezeigt (siehe oben) — nur, dass
  # es einen gibt. Enter behaelt ihn trotzdem.
  if [ -n "$ALT_ZIEL" ]; then
    printf '  Eingabe [Enter = beim bisherigen bleiben]: '
  else
    printf '  Eingabe (leer = spaeter eintragen): '
  fi
  read -r ZIEL < /dev/tty || ZIEL=""
fi
# Enter gedrueckt -> beim Bisherigen bleiben.
[ -n "$ZIEL" ] || ZIEL="$ALT_ZIEL"

# Fehlt das @, laeuft es garantiert in den oben beschriebenen Fehler.
# Lieber sofort nachfragen als den Nutzer spaeter suchen lassen.
case "$ZIEL" in
  ""|*@*) : ;;
  *)
    echo ""
    echo "  ⚠️  In der Eingabe fehlt der Benutzername (kein @) — so wird die"
    echo "      Anmeldung fehlschlagen (siehe oben)."
    if [ -r /dev/tty ]; then
      printf '  Benutzername auf dem Server (leer = trotzdem so lassen): '
      read -r BENUTZER < /dev/tty || BENUTZER=""
      [ -n "$BENUTZER" ] && ZIEL="$BENUTZER@$ZIEL"
    fi
    ;;
esac

if [ -n "$ZIEL" ]; then
  printf '# Befehl fuer Menuepunkt 1 (SSH mit tmux-Sitzung "cc").\n' > "$CONF"
  printf 'ssh %s -t "tmux new -A -s cc"\n' "$ZIEL" >> "$CONF"
  echo "  Ziel gespeichert in: $CONF"

  # Denselben Benutzer auch fuer ein blankes "ssh rechner" hinterlegen —
  # sonst laeuft man in genau denselben Fehler, sobald man den Befehl
  # einmal von Hand tippt statt ueber das Menue zu gehen.
  case "$ZIEL" in
    *@*)
      SSH_USER="${ZIEL%@*}"
      SSH_HOST="${ZIEL#*@}"
      mkdir -p "$HOME/.ssh"
      touch "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
      # Einen vorhandenen Block fuer denselben Rechner ERSETZEN statt einen
      # zweiten anzuhaengen — sonst sammeln sich bei jedem Lauf Doppel an,
      # und ssh nimmt stillschweigend den ersten Treffer.
      #
      # tolower() statt IGNORECASE: Letzteres kennt nur gawk, und welches awk
      # in Termux steckt, ist nicht garantiert.
      # Die eigene Kommentarzeile wird mit weggefiltert, damit sie sich nicht
      # bei jedem Lauf erneut ansammelt.
      awk -v h="$SSH_HOST" '
        tolower($1) == "host" { drin = ($2 == h) }
        drin { next }
        /^# setup_i3.sh:/ { next }
        # Mehrere Leerzeilen hintereinander zu einer zusammenziehen, sonst
        # waechst die Datei bei jedem Lauf um eine weitere Leerzeile.
        /^[[:space:]]*$/ { if (leer) next; leer = 1; print; next }
        { leer = 0; print }
      ' "$HOME/.ssh/config" > "$HOME/.ssh/config.neu"
      {
        printf '\n# setup_i3.sh: Ohne diesen Eintrag meldet sich ssh mit dem Android-Namen.\n'
        printf 'Host %s\n    User %s\n' "$SSH_HOST" "$SSH_USER"
      } >> "$HOME/.ssh/config.neu"
      mv "$HOME/.ssh/config.neu" "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
      echo "  ~/.ssh/config gesetzt: ein blankes 'ssh <rechner>' nutzt jetzt"
      echo "  den richtigen Benutzernamen."
      ;;
  esac
else
  printf '# Befehl fuer Menuepunkt 1. Die Zeile unten anpassen und die\n' > "$CONF"
  printf '# fuehrende Raute entfernen:\n' >> "$CONF"
  printf '# ssh RECHNERNAME -t "tmux new -A -s cc"\n' >> "$CONF"
  echo "  Kein Ziel angegeben — bitte spaeter eintragen in: $CONF"
fi

# Das alte Menue vorher zur Seite legen. Es wird gleich ueberschrieben, und
# solange i3 nur getestet wird, will man notfalls zurueck koennen.
if [ -f "$MENU" ] && [ ! -f "$MENU.bak" ]; then
  cp "$MENU" "$MENU.bak"
  echo "  altes Menue gesichert: $MENU.bak"
fi

cat > "$MENU" <<'MENUEOF'
#!/bin/bash
# Startmenue. Erzeugt von setup_i3.sh (linuxrice/termux-i3-minimal).
# Den SSH-Befehl bitte in ~/.termux-menu.conf anpassen, nicht hier —
# diese Datei wird beim naechsten Setup ueberschrieben.

MENU_SSH="$(grep -v '^[[:space:]]*#' "$HOME/.termux-menu.conf" 2>/dev/null \
            | grep -v '^[[:space:]]*$' | head -n 1)"
[ -n "$MENU_SSH" ] || MENU_SSH=''

# Aus dem Befehl den reinen Rechnernamen ziehen: das erste Wort nach "ssh",
# das keine Option ist. So genuegt es, den Befehl an EINER Stelle zu pflegen.
#
# Die Liste unten sind die ssh-Optionen, die selbst noch einen Wert nach sich
# ziehen. Ohne sie wuerde aus "ssh -p 2222 rechner" die Zahl 2222 als
# Rechnername herausfallen — sie steht ja hinter keinem Minus.
MENU_HOST="$(printf '%s\n' "$MENU_SSH" | awk '
  BEGIN { split("-b -c -D -E -e -F -I -i -J -L -l -m -O -o -p -Q -R -S -W -w", _o, " ")
          for (k in _o) argopt[_o[k]] = 1 }
  { for (i = 1; i <= NF; i++) if ($i == "ssh") {
      for (j = i + 1; j <= NF; j++) {
        if ($j ~ /^-/) { if ($j in argopt) j++; continue }
        print $j; exit
      } } }')"

MENU_START="$HOME/start-i3.sh"

# Der alte XFCE-Starter. Solange er existiert, bleibt er als Menuepunkt
# stehen — so laesst sich i3 ausprobieren, ohne XFCE aufzugeben. Wer XFCE
# spaeter loswird, loescht die Datei und der Punkt verschwindet von selbst.
MENU_XFCE="$HOME/start-desktop.sh"

# Die Esc-Taste sendet genau ein Zeichen (0x1b). In einer Datei laesst es sich
# schlecht ablegen, darum wird es hier erzeugt und ueberall damit verglichen.
ESC="$(printf '\033')"

_menu_pause() {
  printf '\n  [Enter] zurueck zum Menue, [q] oder [Esc] Terminal: '
  read -rsn1 _a
  printf '\n'
  case "$_a" in q|Q|"$ESC") return 1 ;; *) return 0 ;; esac
}

_kein_ziel() {
  printf '\n  Es ist noch kein Server eingetragen.\n'
  printf '  Datei anlegen/anpassen: ~/.termux-menu.conf\n'
  printf '    ssh RECHNERNAME -t "tmux new -A -s cc"\n'
}

while true; do
  clear
  printf '\n'
  printf '  TERMUX\n'
  printf '  ------------------------------\n'
  printf '\n'
  printf '   1   Server      SSH + tmux "cc"\n'
  printf '   2   Server pur  SSH ohne tmux\n'
  printf '   3   Auslastung  htop auf dem Server\n'
  # Punkt 4 und 5 nur ausserhalb der grafischen Sitzung: in einem xterm laeuft
  # die Sitzung ja schon, ein zweiter Start wuerde die eigene abschiessen.
  if [ -z "${DISPLAY:-}" ]; then
    printf '   4   Desktop     i3 starten\n'
    [ -x "$MENU_XFCE" ] && printf '   5   Desktop alt XFCE starten\n'
  fi
  printf '\n'
  printf '  [Enter] = 1     [Esc] = nur die Shell\n'
  printf '\n'
  printf '  Auswahl: '

  # Eine EINZELNE Taste, ohne Enter (-n1) und ohne Anzeige (-s).
  # Nur so laesst sich Esc ueberhaupt erkennen: "read -r" gibt die Zeile erst
  # beim Enter heraus, eine allein gedrueckte Esc-Taste kaeme dort nie an.
  if ! read -rsn1 wahl; then
    # Kein Eingabekanal (z.B. Skriptaufruf) -> einfach Terminal
    clear
    break
  fi

  # Pfeil- und Funktionstasten senden Esc und danach noch "[A" o.ae.
  # Ohne dieses Nachfassen wuerde ein Verrutscher auf die Pfeiltaste als Esc
  # gelten und das Menue schliessen. Kommt also sofort noch etwas hinterher,
  # war es keine echte Esc-Taste: Rest wegwerfen und als Fehleingabe werten.
  if [ "$wahl" = "$ESC" ]; then
    while read -rsn1 -t 0.05 _rest; do wahl='?'; done
  fi

  case "$wahl" in
    ''|1)
      clear
      if [ -n "$MENU_SSH" ]; then eval "$MENU_SSH" || true; else _kein_ziel; fi
      _menu_pause || { clear; break; }
      ;;
    2)
      # Ein blankes "ssh" genuegt nicht: die ~/.bashrc auf dem Server springt
      # bei jeder Anmeldung von selbst in die tmux-Sitzung "cc".
      # KEIN_TMUX=1 schaltet genau diese Automatik ab.
      clear
      if [ -n "$MENU_HOST" ]; then
        ssh "$MENU_HOST" -t "KEIN_TMUX=1 bash" || true
      else _kein_ziel; fi
      _menu_pause || { clear; break; }
      ;;
    3)
      # htop laeuft AUF dem Server, nicht auf dem Handy — nur so sieht man die
      # Auslastung, die einen wirklich interessiert. Das "-t" ist Pflicht,
      # sonst bekommt htop kein richtiges Terminal und startet nicht.
      #
      # Vorher wird nachgeschaut, OB es htop dort ueberhaupt gibt. Sonst
      # blitzt nur ein "command not found" auf und ist gleich wieder weg —
      # so steht stattdessen der Installationsbefehl da.
      # Der Rechnername steht in keiner dieser Meldungen — Menue-Ausgaben
      # landen in Screenshots und Chats. Wer ihn braucht, schaut in die Conf.
      clear
      if [ -z "$MENU_HOST" ]; then
        _kein_ziel
      else
        ssh "$MENU_HOST" 'command -v htop >/dev/null 2>&1'
        _rc=$?
        if [ "$_rc" = 0 ]; then
          ssh "$MENU_HOST" -t htop || true
        elif [ "$_rc" = 255 ]; then
          # 255 kommt von ssh selbst: Server nicht erreichbar, Anmeldung
          # abgelehnt und aehnliches. Das ist KEIN fehlendes htop.
          printf '\n  Der Server war nicht erreichbar.\n'
        else
          printf '\n  Auf dem Server ist kein htop installiert.\n'
          printf '  Dort einmal ausfuehren:\n'
          printf '    sudo apt install htop\n'
        fi
      fi
      _menu_pause || { clear; break; }
      ;;
    4)
      clear
      if [ -n "${DISPLAY:-}" ]; then
        printf '\n  Die Sitzung laeuft bereits.\n'
        sleep 1
      elif [ -x "$MENU_START" ]; then
        "$MENU_START" || true
      else
        printf '\n  Kein Starter gefunden: %s\n' "$MENU_START"
        printf '  (Setup: setup_i3.sh aus dem linuxrice-Repo)\n'
      fi
      _menu_pause || { clear; break; }
      ;;
    5)
      clear
      if [ -n "${DISPLAY:-}" ]; then
        printf '\n  Die Sitzung laeuft bereits.\n'
        sleep 1
      elif [ -x "$MENU_XFCE" ]; then
        "$MENU_XFCE" || true
      else
        printf '\n  Kein XFCE-Starter gefunden: %s\n' "$MENU_XFCE"
      fi
      _menu_pause || { clear; break; }
      ;;
    q|Q|"$ESC")
      # Esc (und weiterhin q) fuehren direkt in die Shell — dafuer gibt es
      # keinen eigenen Menuepunkt mehr.
      clear
      break
      ;;
    *)
      printf '\n  Bitte eine Zahl aus der Liste.\n'
      sleep 1
      ;;
  esac
done
MENUEOF
chmod +x "$MENU"
echo "  geschrieben: $MENU"

# --- Menue und Alias in die .bashrc haengen ------------------------------
# ⚠️ Wird bei JEDEM Lauf neu geschrieben. Frueher wurde der Block nur angelegt,
# wenn er noch fehlte ("ruft das Menue schon auf — unveraendert gelassen").
# Auf einem bereits eingerichteten Handy kam damit KEINE Verbesserung an
# diesen Zeilen jemals an — man haette die .bashrc von Hand aufraeumen muessen.
# Jetzt wird der alte Block herausgeschnitten und ein frischer angehaengt.
#
# Die Wache aus drei Bedingungen im Block selbst bleibt wichtig:
#   TERMUX_MENU_DONE  -> ruft sich sonst endlos selbst auf
#   -t 0 / -t 1       -> nur bei echtem Terminal, nicht bei "ssh handy befehl"
touch "$HOME/.bashrc"
awk '
  # 1. Block aus dieser Fassung: sauber zwischen zwei Markierungen.
  /^# >>> setup_i3\.sh$/ { drin = 1; next }
  /^# <<< setup_i3\.sh$/ { drin = 0; next }
  drin { next }

  # 2. Block aus aelteren Fassungen (ohne Markierungen). Er begann immer mit
  #    dieser Kommentarzeile und endete beim ersten "fi" ganz links.
  #    Der Zaehler ist ein Sicherheitsnetz: Fehlt das "fi" (weil jemand von
  #    Hand darin herumgeschnitten hat), wuerde sonst der gesamte Rest der
  #    Datei verschluckt. Der Block war immer 6 Zeilen lang.
  /^# Zeigt beim Oeffnen eines Terminals das Startmenue\.$/ { alt = 8; next }
  alt > 0 { alt--; if ($0 == "fi") alt = 0; next }

  # 3. Der Alias stand frueher lose irgendwo dazwischen.
  /^alias desk=/ { next }

  # Mehrere Leerzeilen hintereinander zu einer zusammenziehen, sonst waechst
  # die Datei bei jedem Lauf um eine weitere Leerzeile.
  /^[[:space:]]*$/ { if (leer) next; leer = 1; print; next }
  { leer = 0; print }
' "$HOME/.bashrc" > "$HOME/.bashrc.neu"
{
  printf '\n# >>> setup_i3.sh\n'
  printf '# Alles zwischen diesen beiden Markierungen schreibt setup_i3.sh bei\n'
  printf '# jedem Lauf neu. Eigene Zeilen bitte AUSSERHALB davon ablegen.\n'
  printf '\n'
  printf '# Zeigt beim Oeffnen eines Terminals das Startmenue.\n'
  printf 'if [ -z "${TERMUX_MENU_DONE:-}" ] && [ -t 0 ] && [ -t 1 ] \\\n'
  printf '   && [ -f "$HOME/.termux-menu.sh" ]; then\n'
  printf '  export TERMUX_MENU_DONE=1\n'
  printf '  . "$HOME/.termux-menu.sh"\n'
  printf 'fi\n'
  printf '\n'
  printf "alias desk='~/start-i3.sh'\n"
  printf '# <<< setup_i3.sh\n'
} >> "$HOME/.bashrc.neu"
mv "$HOME/.bashrc.neu" "$HOME/.bashrc"
echo "  ~/.bashrc: Menue-Block und Alias neu geschrieben."

echo "=== [7/8] Termux-Tastenleiste (zwei Reihen) ==="

# Die Leiste ueber der Bildschirmtastatur. Ab Werk zeigt Termux dort eine
# einzige Reihe (ESC TAB CTRL ALT - DOWN UP). Auf dem Fold7 ist Platz fuer
# zwei, und ohne die zweite fehlen genau die Tasten, die man im Terminal
# staendig braucht:
#
#   S-TAB   Shift+Tab, als Escape-Sequenz "ESC [ Z" verschickt. Die SHIFT-
#           Taste der Leiste taugt dafuer NICHT — sie ist kein echter
#           Modifier, Shift+Tab kam damit nie an (z. B. der Moduswechsel
#           in Claude Code). Darum das Makro.
#   V|  H-  tmux-Fenster teilen, senkrecht bzw. waagrecht.
#   EXIT    tippt "exit" und Enter — Sitzung beenden ohne Tastatur.
#   HOME END DEL | und die vier Pfeile.
#
# Die Datei wird NICHT ueberschrieben: es fliegen nur der eigene Block
# zwischen den Markierungen und eine eventuell von Hand gesetzte
# extra-keys-Zeile raus. Alles andere (Farben, Lautstaerketaste, Schrift,
# Termux:Boot) bleibt unangetastet stehen.
mkdir -p "$HOME/.termux"
touch "$TPROPS"
awk '
  # 1. Eigener Block aus einem frueheren Lauf.
  /^# >>> setup_i3\.sh$/ { drin = 1; next }
  /^# <<< setup_i3\.sh$/ { drin = 0; next }
  drin { next }

  # 2. Eine lose extra-keys-Zeile von Hand. Sie darf sich ueber mehrere
  #    Zeilen ziehen — dann endet jede Fortsetzung auf "\", und die
  #    muessen alle mit weg, sonst bleibt ein Rumpf stehen, den Termux
  #    als kaputte Einstellung liest.
  #    "extra-keys-style" und "extra-keys-text-all-caps" sind eigene
  #    Schluessel und bleiben ausdruecklich erhalten.
  /^[[:space:]]*extra-keys[[:space:]]*=/ {
    while ($0 ~ /\\[[:space:]]*$/) { if ((getline) <= 0) break }
    next
  }

  # Mehrere Leerzeilen hintereinander zu einer zusammenziehen.
  /^[[:space:]]*$/ { if (leer) next; leer = 1; print; next }
  { leer = 0; print }
' "$TPROPS" > "$TPROPS.neu"
cat >> "$TPROPS.neu" <<'TASTENEOF'

# >>> setup_i3.sh
# Alles zwischen diesen beiden Markierungen schreibt setup_i3.sh bei jedem
# Lauf neu. Eigene Zeilen bitte AUSSERHALB davon ablegen.
#
# Reihe 1:  ESC  TAB  S-TAB  ALT  -  V|  UP  H-
# Reihe 2:  HOME  END  |  EXIT  DEL  LEFT  DOWN  RIGHT
extra-keys = [['ESC','TAB',{macro: 'ESC [ Z', display: 'S-TAB'},'ALT','-',{macro: 'CTRL b %', display:'V|'},'UP',{macro: 'CTRL b "', display: 'H-'}],['HOME','END','|',{macro: 'e x i t ENTER', display:'EXIT'},'DEL','LEFT','DOWN','RIGHT']]
# <<< setup_i3.sh
TASTENEOF
mv "$TPROPS.neu" "$TPROPS"
echo "  geschrieben: $TPROPS"

# Uebernimmt die Leiste sofort — ohne das hier sieht man sie erst, wenn
# Termux einmal komplett geschlossen und neu geoeffnet wurde.
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings || true
  echo "  Tastenleiste neu geladen — sie ist sofort da."
else
  echo "  Hinweis: termux-reload-settings fehlt. Termux einmal komplett"
  echo "  schliessen und neu oeffnen, dann ist die Leiste da."
fi

echo "=== [8/8] Firefox-Grundeinstellungen ==="

# ⚠️ KEINE Startseite mehr. Das Skript fragt sie nicht, speichert sie nicht und
# schreibt sie nicht in die user.js. Eine Startseite ist eine Adresse aus dem
# eigenen Netz — die hat in einem oeffentlichen Repo nichts verloren, auch nicht
# als Beispiel. Wer eine will, stellt sie in Firefox selbst ein; das ueberlebt
# auch den naechsten Setup-Lauf, weil user.js diese Einstellung nicht anfasst.
#
# Eine Startseite aus einer frueheren Fassung wird aufgeraeumt: Die alte
# Merkdatei kommt weg, und die user.js unten wird ohnehin neu geschrieben —
# ohne die beiden startup-Zeilen.
if [ -f "$FFCONF" ]; then
  rm -f "$FFCONF"
  echo "  alte Startseiten-Merkdatei entfernt: $FFCONF"
fi

# Profil suchen. Firefox legt es unter einem zufaelligen Namen an, der echte
# Pfad steht in profiles.ini. Zuerst das als Standard markierte nehmen.
FFDIR="$HOME/.mozilla/firefox"
FFPROFIL=""
if [ -f "$FFDIR/profiles.ini" ]; then
  # Gibt es mehrere Profile, steht das aktive im Abschnitt [Install...] unter
  # "Default=". Die Abfrage auf "1" schliesst den alten Eintrag "Default=1"
  # aus, der kein Pfad ist, sondern nur eine Markierung.
  FFPROFIL="$(awk -F= '/^Default=/ && $2 != "1" { print $2; exit }' "$FFDIR/profiles.ini")"
  [ -n "$FFPROFIL" ] || \
    FFPROFIL="$(awk -F= '/^Path=/ { print $2; exit }' "$FFDIR/profiles.ini")"
fi

# Noch kein Profil da (frisches Termux)? Dann eines anlegen lassen. Das geht
# ohne Bildschirm, Firefox beendet sich dabei sofort wieder.
if [ -z "$FFPROFIL" ] && command -v firefox >/dev/null 2>&1; then
  MOZ_HEADLESS=1 firefox -CreateProfile default >/dev/null 2>&1 || true
  [ -f "$FFDIR/profiles.ini" ] && \
    FFPROFIL="$(awk -F= '/^Path=/ { print $2; exit }' "$FFDIR/profiles.ini")"
fi

if [ -n "$FFPROFIL" ] && [ -d "$FFDIR/$FFPROFIL" ]; then
  # user.js statt prefs.js: prefs.js schreibt Firefox beim Beenden selbst neu
  # und wuerde alles ueberbuegeln. Die Werte in user.js gelten dagegen bei
  # jedem Start — der Preis ist, dass Aenderungen ueber die Oberflaeche nur
  # bis zum naechsten Start halten. Zum Rueckgaengigmachen: Datei loeschen.
  {
    printf '// Erzeugt von setup_i3.sh (linuxrice/termux-i3-minimal).\n'
    printf '// Diese Werte werden bei JEDEM Firefox-Start neu gesetzt.\n'
    printf '// Rueckgaengig machen: diese Datei loeschen.\n\n'
    printf '// Vertikale Tabs. Seit Firefox 136 eingebaut, kein Add-on noetig.\n'
    printf '// Die waagrechte Tab-Leiste verschwindet dadurch von selbst.\n'
    printf 'user_pref("sidebar.revamp", true);\n'
    printf 'user_pref("sidebar.verticalTabs", true);\n\n'
    printf '// Dunkel — und zwar auch fuer WEBSEITEN (prefers-color-scheme).\n'
    printf '// Das ersetzt den Handgriff "Einstellungen -> Design -> Dunkel".\n'
    printf 'user_pref("ui.systemUsesDarkTheme", 1);\n\n'
    printf '// Menueleiste aus (auf Linux ohnehin der Normalfall).\n'
    printf 'user_pref("browser.menubarVisible", false);\n\n'
    printf '// Die Startseite wird hier BEWUSST nicht gesetzt — die stellt man\n'
    printf '// in Firefox selbst ein, und sie bleibt dort auch erhalten.\n'
  } > "$FFDIR/$FFPROFIL/user.js"
  echo "  geschrieben: $FFDIR/$FFPROFIL/user.js"
  echo "  (ohne Startseite — die stellst du in Firefox selbst ein)"
else
  echo "  Kein Firefox-Profil gefunden — uebersprungen."
  echo "  Firefox einmal starten und dieses Skript danach erneut ausfuehren."
fi

echo ""
echo "--- Bei diesem Lauf neu geschrieben ---"
echo "  $I3CONF"
echo "  $START"
echo "  $MENU"
echo "  $CONF"
[ -f "$LXCONF" ] && echo "  $LXCONF"
echo "  ~/.bashrc  (nur der Block zwischen den setup_i3.sh-Markierungen)"
echo "  $TPROPS  (nur der Block zwischen den Markierungen)"
echo "  ~/.ssh/config  (nur der Abschnitt fuer den eingetragenen Rechner)"
echo "  Firefox user.js  (sofern ein Profil da war)"
echo ""
echo "  Nicht angetastet: der Mauszeiger in ~/.icons (nur ein Download —"
echo "  zum Erneuern den Ordner loeschen und das Skript nochmal starten)."

if [ -n "$FEHLT" ]; then
  echo ""
  echo "============================================"
  echo "  ⚠️  NICHT INSTALLIERT:$FEHLT"
  echo "============================================"
  echo "  Alles andere ist eingerichtet. Nachholen mit:"
  echo "      pkg upgrade -y ; dpkg --configure -a ; pkg install$FEHLT"
  echo ""
fi

cat <<'FERTIG'

============================================
  Fertig.
============================================

Naechste Schritte:

  1. source ~/.bashrc
  2. Menuepunkt 5 waehlen (oder einfach:  desk  )

Firefox ist vorkonfiguriert (vertikale Tabs, dunkel, ohne Menueleiste).
Rueckgaengig machen: die Datei user.js im Firefox-Profil loeschen.

Die Tastenleiste ueber der Bildschirmtastatur hat jetzt zwei Reihen:

  Reihe 1:  ESC  TAB  S-TAB  ALT  -  V|  UP  H-
  Reihe 2:  HOME  END  |  EXIT  DEL  LEFT  DOWN  RIGHT

  S-TAB   Shift+Tab (z. B. Moduswechsel in Claude Code)
  V|  H-  tmux-Fenster teilen, senkrecht bzw. waagrecht
  EXIT    tippt "exit" + Enter

Rueckgaengig machen: in ~/.termux/termux.properties den Block zwischen
den setup_i3.sh-Markierungen loeschen, dann termux-reload-settings.

Tastenkuerzel:

  Super + 1 / 2 / 3     Arbeitsflaeche wechseln  (1 = Firefox, 2 = Terminal)
  Super + Return        neues Terminal
  Strg + Alt + T        neues Terminal
  Super + F             Firefox
  Super + Q             Fenster schliessen
  Super + Shift + F     Vollbild an/aus
  Super + Shift + R     i3 neu laden
  Super + Shift + Rueck i3 beenden

Reagiert die Super-Taste nicht, schluckt Samsung DeX sie.
Dann in ~/.config/i3/config den Block "set $mod" umstellen (steht dort erklaert).

FERTIG
