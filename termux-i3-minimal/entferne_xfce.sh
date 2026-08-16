#!/bin/bash
set -e

# ============================================================
# XFCE restlos entfernen — nachdem i3 sich bewaehrt hat.
#
# Aufruf (IN DER TERMUX-APP, nicht in der laufenden Sitzung):
#   curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-i3-minimal/entferne_xfce.sh | bash
#
# Das Skript ist absichtlich vorsichtig: Es zeigt vorher, was verschwinden
# wuerde, und fragt nach. Nichts passiert ohne ausdrueckliches Ja.
# ============================================================

case "${PREFIX:-}" in
  *com.termux*) : ;;
  *)
    echo "FEHLER: Das hier gehoert in Termux auf dem Handy, nicht hierher." >&2
    exit 1
    ;;
esac

# NICHT aus der laufenden Sitzung heraus: Das Terminal, in dem das Skript
# laeuft, koennte dabei selbst unter den Haenden wegbrechen.
if [ -n "${DISPLAY:-}" ]; then
  echo "FEHLER: Bitte in der Termux-App ausfuehren, nicht in der i3-Sitzung." >&2
  echo "        i3 vorher beenden: Super + Shift + Ruecktaste" >&2
  exit 1
fi

echo "=== [1/5] Was gebraucht wird, vor dem Aufraeumen schuetzen ==="
# Kern des Ganzen: "apt autoremove" wirft spaeter alles weg, was nur als
# Abhaengigkeit von XFCE dasteht. xfce4-terminal IST so eine Abhaengigkeit —
# ohne diesen Schutz waere nach dem Aufraeumen das Terminal weg, und damit
# die Sitzung unbrauchbar. "manual" heisst: bewusst gewollt, nicht wegwerfen.
SCHUETZEN="xfce4-terminal i3 termux-x11-nightly mesa mesa-vulkan-icd-freedreno
           firefox openssh ttf-dejavu xorg-xsetroot"
for p in $SCHUETZEN; do
  if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then
    apt-mark manual "$p" >/dev/null 2>&1 || true
    echo "  geschuetzt: $p"
  fi
done

echo ""
echo "=== [2/5] XFCE-Bestandteile suchen ==="
# Nur das entfernen, was auch wirklich installiert ist — sonst bricht apt
# ueber unbekannte Paketnamen ab.
KANDIDATEN="xfce4 xfce4-session xfce4-panel xfdesktop xfwm4 xfce4-settings
            xfconf xfce4-appfinder xfce4-taskmanager thunar mousepad
            rofi sxhkd papirus-icon-theme"
ENTFERNEN=""
for p in $KANDIDATEN; do
  if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then
    ENTFERNEN="$ENTFERNEN $p"
  fi
done

if [ -z "$ENTFERNEN" ]; then
  echo "  Nichts gefunden — XFCE ist offenbar schon weg."
else
  echo "  Gefunden:$ENTFERNEN"
  echo ""
  echo "=== [3/5] Probelauf (es wird noch nichts entfernt) ==="
  apt-get -s remove $ENTFERNEN 2>/dev/null | grep -E '^(Remv|REMOVING|[0-9]+ upgraded)' || true

  echo ""
  printf 'Wirklich entfernen? [ja/NEIN]: '
  ANTWORT="nein"
  [ -r /dev/tty ] && { read -r ANTWORT < /dev/tty || ANTWORT="nein"; }
  case "$ANTWORT" in
    ja|JA|Ja|j|J) : ;;
    *) echo "Abgebrochen. Es wurde nichts veraendert."; exit 0 ;;
  esac

  echo ""
  echo "=== [4/5] Entfernen ==="
  pkg uninstall -y $ENTFERNEN
  apt autoremove -y
fi

echo ""
echo "=== [5/5] Reste aufraeumen ==="
# ACHTUNG: ~/.config/xfce4/terminal bleibt BEWUSST stehen! Dort liegen
# Schrift, Schriftgroesse und Farben des Terminals — genau die Einstellungen,
# die in der i3-Sitzung weiter benutzt werden. Nur die Desktop-Reste gehen weg.
rm -rf "$HOME/.config/xfce4/xfconf" \
       "$HOME/.config/xfce4/panel" \
       "$HOME/.config/xfce4/panel-template.xml" \
       "$HOME/.config/xfce4/desktop" \
       "$HOME/.cache/sessions" \
       "$HOME/.config/rofi" \
       "$HOME/.config/sxhkd" 2>/dev/null || true
echo "  Desktop-Reste geloescht (Terminal-Einstellungen bleiben erhalten)."

# Damit verschwindet Menuepunkt 6 von selbst.
rm -f "$HOME/start-desktop.sh"
echo "  ~/start-desktop.sh entfernt — Menuepunkt 6 ist damit weg."

echo ""
echo "=== Kontrolle ==="
FEHLT=""
for p in i3 xfce4-terminal firefox termux-x11; do
  if command -v "$p" >/dev/null 2>&1; then
    echo "  ok:     $p"
  else
    echo "  FEHLT:  $p"
    FEHLT="$FEHLT $p"
  fi
done

echo ""
if [ -n "$FEHLT" ]; then
  echo "ACHTUNG: Es fehlt etwas:$FEHLT"
  echo "Nachinstallieren mit:  pkg install$FEHLT"
else
  echo "Alles da. Sitzung starten mit:  desk"
fi
