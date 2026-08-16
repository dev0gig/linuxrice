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

echo "=== [1/6] Paketlisten auffrischen ==="
export DEBIAN_FRONTEND=noninteractive
pkg update -y

# ACHTUNG: Hier wird BEWUSST kein "pkg upgrade" gemacht.
#
# Ein Rundum-Upgrade wuerde auch mesa und termux-x11 anfassen — genau die
# beiden Stuecke, an denen der Zink/turnip-Pfad haengt. Der ist offiziell gar
# nicht unterstuetzt und bricht bei solchen Updates gern. Wer i3 erst einmal
# NEBEN einem laufenden XFCE ausprobieren will, wuesste hinterher nicht, ob
# ein Problem von i3 kommt oder vom Upgrade.
#
# Wer trotzdem alles mitziehen will:  MIT_UPGRADE=1 ./setup_i3.sh
if [ "${MIT_UPGRADE:-0}" = "1" ]; then
  echo "  MIT_UPGRADE=1 gesetzt — es wird doch alles aktualisiert."
  pkg upgrade -y -o Dpkg::Options::="--force-confnew"
else
  echo "  (Rundum-Upgrade uebersprungen. Mit MIT_UPGRADE=1 erzwingbar.)"
fi

echo "=== [2/6] X11-Repo freischalten ==="
pkg install -y -o Dpkg::Options::="--force-confnew" x11-repo

echo "=== [3/6] Pakete installieren ==="
# Pflicht: ohne die laeuft nichts.
pkg install -y -o Dpkg::Options::="--force-confnew" termux-x11-nightly
pkg install -y -o Dpkg::Options::="--force-confnew" mesa mesa-vulkan-icd-freedreno
# i3 und Terminal zuerst und getrennt von Firefox installieren.
# Grund: Firefox ist mit ~66 MB der mit Abstand groesste Brocken. Haengt der
# Download (langsamer Spiegelserver), soll wenigstens die Sitzung schon
# benutzbar sein — Firefox laesst sich jederzeit nachinstallieren mit:
#     pkg install firefox
pkg install -y -o Dpkg::Options::="--force-confnew" i3 xterm openssh

echo "--- Firefox (~66 MB, der grosse Brocken) ---"
# Bricht der Download ab, laeuft das Setup trotzdem zu Ende: i3 ist dann fertig
# eingerichtet und startbar, nur der Browser fehlt noch.
if ! pkg install -y -o Dpkg::Options::="--force-confnew" firefox; then
  echo ""
  echo "  ACHTUNG: Firefox wurde NICHT installiert."
  echo "  i3 wird trotzdem fertig eingerichtet und ist startbar."
  echo "  Ist der Download sehr langsam, liegt es fast immer am Spiegelserver:"
  echo "      termux-change-repo      (dort eine Gruppe in Europa waehlen)"
  echo "  Danach nachholen mit:  pkg install firefox"
  echo ""
fi

# Kuer: schoener, aber nicht kriegsentscheidend. Darum darf das fehlschlagen,
# ohne das ganze Setup abzubrechen (set -e wuerde sonst hier aussteigen).
#   ttf-dejavu      Schrift. btop auf dem Server zeichnet seine Graphen mit
#                   Braille-Zeichen — ohne passende Schrift sieht das kaputt aus.
#   xorg-xsetroot   ersetzt den haesslichen X-Standard-Mauszeiger ("X") durch
#                   einen normalen Pfeil.
pkg install -y ttf-dejavu 2>/dev/null || echo "  Hinweis: ttf-dejavu nicht verfuegbar — uebersprungen."
pkg install -y xorg-xsetroot 2>/dev/null || echo "  Hinweis: xorg-xsetroot nicht verfuegbar — uebersprungen."

echo "=== [4/6] i3-Konfiguration schreiben ==="
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
# Die Farben stehen absichtlich direkt im Aufruf. Damit entfaellt eine
# ~/.Xresources UND das Paket xorg-xrdb — das Terminal startet sonst weiss.
# Geschrieben als rgb:xx/xx/xx statt #xxxxxx, weil die Raute in dieser Datei
# einen Kommentar einleiten wuerde.
#
# ⚠️ NUR -bg und -fg verwenden, sonst nichts.
# Was in Termux als "xterm" installiert wird, ist in Wirklichkeit ATERM (ein
# rxvt-Abkoemmling). Das kennt die Xft-Optionen -fa und -fs NICHT, bricht bei
# ihnen sofort mit "bad option" ab — und dann startet ueberhaupt kein Terminal
# mehr, auch nicht ueber die Tastenkuerzel. -bg und -fg verstehen beide.
# Fuer die Schrift kennt aterm nur -fn mit einem klassischen X-Fontnamen.
set $term xterm -bg rgb:1a/1a/1a -fg rgb:d0/d0/d0

# --- Tastenkuerzel --------------------------------------------------------
bindsym $mod+Return          exec $term
bindsym Control+Mod1+t       exec $term
bindsym $mod+f               exec firefox
bindsym $mod+q               kill

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
exec --no-startup-id i3-msg 'workspace 2; exec xterm -bg rgb:1a/1a/1a -fg rgb:d0/d0/d0'
I3EOF
echo "  geschrieben: $I3CONF"

echo "=== [5/6] Startskript schreiben ==="
cat > "$START" <<'STARTEOF'
#!/bin/bash
# Startet die i3-Sitzung. Erzeugt von setup_i3.sh.

# Reste einer abgewuergten Sitzung wegraeumen. Android beendet die X-Sitzung
# im Hintergrund gern selbst, waehrend die Termux-Shell weiterlaeuft.
# "aterm" muss mit in die Liste: was in Termux als xterm installiert wird,
# laeuft als Prozess unter dem Namen aterm — "killall xterm" fasst es nicht an.
killall -9 termux-x11 i3 xterm aterm 2>/dev/null
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

termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0

exec i3
STARTEOF
chmod +x "$START"
echo "  geschrieben: $START"

echo "=== [6/6] Startmenue einrichten ==="

# --- Ziel-Rechner erfragen ------------------------------------------------
# Der Name des eigenen Servers steht bewusst NICHT im Repo, sondern nur hier
# lokal auf dem Handy. Das Repo bleibt damit neutral.
#
# Gelesen wird von /dev/tty, nicht von der Standardeingabe: bei
# "curl ... | bash" haengt an der Standardeingabe das Skript selbst, ein
# normales "read" wuerde die naechste Skriptzeile verschlucken.
if [ ! -f "$CONF" ]; then
  ZIEL=""
  if [ -r /dev/tty ]; then
    printf '\n  Name oder Adresse deines Servers fuer das Menue\n'
    printf '  (z.B. rechnername oder benutzer@rechnername, leer = spaeter): '
    read -r ZIEL < /dev/tty || ZIEL=""
  fi
  if [ -n "$ZIEL" ]; then
    printf '# Befehl fuer Menuepunkt 1 (SSH mit tmux-Sitzung "cc").\n' > "$CONF"
    printf 'ssh %s -t "tmux new -A -s cc"\n' "$ZIEL" >> "$CONF"
    echo "  Ziel gespeichert in: $CONF"
  else
    printf '# Befehl fuer Menuepunkt 1. Die Zeile unten anpassen und die\n' > "$CONF"
    printf '# fuehrende Raute entfernen:\n' >> "$CONF"
    printf '# ssh RECHNERNAME -t "tmux new -A -s cc"\n' >> "$CONF"
    echo "  Kein Ziel angegeben — bitte spaeter eintragen in: $CONF"
  fi
else
  echo "  $CONF ist schon da — bleibt unveraendert."
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

_menu_pause() {
  printf '\n  [Enter] zurueck zum Menue, [q] Terminal: '
  read -r _a
  case "$_a" in q|Q) return 1 ;; *) return 0 ;; esac
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
  printf '   3   Auslastung  btop auf dem Server\n'
  printf '   4   Terminal    nur die Shell\n'
  # Punkt 5 und 6 nur ausserhalb der grafischen Sitzung: in einem xterm laeuft
  # die Sitzung ja schon, ein zweiter Start wuerde die eigene abschiessen.
  if [ -z "${DISPLAY:-}" ]; then
    printf '   5   Desktop     i3 starten\n'
    [ -x "$MENU_XFCE" ] && printf '   6   Desktop alt XFCE starten\n'
  fi
  printf '\n'
  printf '  Auswahl [1]: '

  if ! read -r wahl; then
    # Kein Eingabekanal (z.B. Skriptaufruf) -> einfach Terminal
    clear
    break
  fi

  case "${wahl:-1}" in
    1)
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
      # btop laeuft AUF dem Server, nicht auf dem Handy — nur so sieht man die
      # Auslastung, die einen wirklich interessiert. Das "-t" ist Pflicht,
      # sonst bekommt btop kein richtiges Terminal und startet nicht.
      clear
      if [ -z "$MENU_HOST" ]; then
        _kein_ziel
      elif ! ssh "$MENU_HOST" -t btop; then
        printf '\n  Das hat nicht geklappt. Falls btop auf %s noch fehlt,\n' "$MENU_HOST"
        printf '  dort einmal ausfuehren:\n'
        printf '    sudo apt install -y btop\n'
      fi
      _menu_pause || { clear; break; }
      ;;
    4)
      clear
      break
      ;;
    5)
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
    6)
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
    q|Q|exit)
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

# --- Menue in die .bashrc haengen ----------------------------------------
# Die Wache aus drei Bedingungen ist wichtig:
#   TERMUX_MENU_DONE  -> ruft sich sonst endlos selbst auf
#   -t 0 / -t 1       -> nur bei echtem Terminal, nicht bei "ssh handy befehl"
if ! grep -q 'termux-menu.sh' "$HOME/.bashrc" 2>/dev/null; then
  {
    printf '\n# Zeigt beim Oeffnen eines Terminals das Startmenue.\n'
    printf 'if [ -z "${TERMUX_MENU_DONE:-}" ] && [ -t 0 ] && [ -t 1 ] \\\n'
    printf '   && [ -f "$HOME/.termux-menu.sh" ]; then\n'
    printf '  export TERMUX_MENU_DONE=1\n'
    printf '  . "$HOME/.termux-menu.sh"\n'
    printf 'fi\n'
  } >> "$HOME/.bashrc"
  echo "  Menue in ~/.bashrc eingehaengt."
else
  echo "  ~/.bashrc ruft das Menue schon auf — unveraendert gelassen."
fi

# --- Bequemer Alias -------------------------------------------------------
if ! grep -q "alias desk=" "$HOME/.bashrc" 2>/dev/null; then
  echo "alias desk='~/start-i3.sh'" >> "$HOME/.bashrc"
fi

cat <<'FERTIG'

============================================
  Fertig.
============================================

Naechste Schritte:

  1. source ~/.bashrc
  2. Menuepunkt 5 waehlen (oder einfach:  desk  )

Einmalig im Firefox, fuer den Darkmode:

  Einstellungen -> Design -> Dunkel
  about:config  ->  ui.systemUsesDarkTheme  =  1
                    (erst das macht auch WEBSEITEN dunkel)

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
