#!/bin/bash
set -e

# Fold 7 / Termux / i3 — bewusst minimales Setup.
# Ziel: frisches Termux -> X11 + i3 + Firefox + Terminal + SSH/tmux-Menü.
case "${PREFIX:-}" in *com.termux*) ;; *) echo "Dieses Skript muss in Termux laufen." >&2; exit 1;; esac

MENU="$HOME/.termux-menu.sh"
CONF="$HOME/.termux-menu.conf"
START="$HOME/start-i3.sh"
I3CONF="$HOME/.config/i3/config"
TPROPS="$HOME/.termux/termux.properties"

echo "==> Termux aktualisieren"
pkg update -y
pkg upgrade -y -o Dpkg::Options::="--force-confnew"
dpkg --configure -a || true
apt-get -y --fix-broken install || true

echo "==> Pakete installieren"
pkg install -y x11-repo
pkg install -y termux-x11-nightly i3 openssh firefox lxterminal ttf-dejavu fontconfig xorg-xsetroot

echo "==> SSH-Ziel"
ALT_ZIEL=""
[ -f "$CONF" ] && ALT_ZIEL="$(grep '^ZIEL=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2-)"
if [ -n "${ZIEL_VORGABE:-}" ]; then
  ZIEL="$ZIEL_VORGABE"
elif [ -r /dev/tty ]; then
  if [ -n "$ALT_ZIEL" ]; then
    printf 'Server (Enter = bisherigen behalten): '
  else
    printf 'Server als benutzer@host: '
  fi
  read -r ZIEL </dev/tty || ZIEL=""
else
  ZIEL="$ALT_ZIEL"
fi
[ -n "$ZIEL" ] || ZIEL="$ALT_ZIEL"
printf 'ZIEL=%s\n' "$ZIEL" > "$CONF"
chmod 600 "$CONF"

echo "==> i3"
mkdir -p "$(dirname "$I3CONF")"
cat > "$I3CONF" <<'EOF'
set $mod Mod4
font pango:monospace 10
set $term lxterminal --no-remote

bindsym $mod+Return exec $term
bindsym Control+Mod1+t exec $term
bindsym $mod+f exec firefox
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+Shift+r restart
bindsym $mod+Shift+BackSpace exit

assign [class="(?i)firefox"] 1
exec --no-startup-id firefox
exec --no-startup-id i3-msg 'workspace 2; exec lxterminal --no-remote'
EOF

cat > "$START" <<'EOF'
#!/bin/bash
killall -9 termux-x11 i3 lxterminal 2>/dev/null || true
sleep 1
export GTK_THEME=Adwaita:dark
export XCURSOR_SIZE=32
export LANG="${LANG:-en_US.UTF-8}"
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
exec i3
EOF
chmod +x "$START"

echo "==> Termux-Menü"
cat > "$MENU" <<'EOF'
#!/bin/bash
CONF="$HOME/.termux-menu.conf"
ZIEL="$(grep '^ZIEL=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2-)"
ESC="$(printf '\033')"

pause() { printf '\n[Enter] zurück '; read -r _; }

tmux_hilfe() {
  clear
  cat <<'HILFE'
TMUX — SPICKZETTEL
------------------------------
Ctrl+B  D       Session verlassen (läuft weiter)
Ctrl+B  C       Neues Fenster
Ctrl+B  N       Nächstes Fenster
Ctrl+B  P       Voriges Fenster
Ctrl+B  W       Fensterübersicht
Ctrl+B  Pfeil   Pane wechseln
Ctrl+B  X       Pane schließen

V|              Pane vertikal teilen
H-              Pane horizontal teilen

tmux ls         Sessions anzeigen
tmux new -s X   Session X erstellen
tmux attach -t X
HILFE
  pause
}

tmux_manager() {
  while true; do
    clear
    printf 'TMUX — ODIN\n------------------------------\n'
    if [ -z "$ZIEL" ]; then printf 'Kein Server konfiguriert.\n'; pause; return; fi

    mapfile -t SESSIONS < <(ssh "$ZIEL" "tmux list-sessions -F '#{session_name}|#{session_windows}|#{?session_attached,attached,detached}' 2>/dev/null" || true)
    if [ "${#SESSIONS[@]}" -eq 0 ]; then
      printf '\nKeine aktiven Sessions.\n'
    else
      printf '\nAKTIVE SESSIONS\n\n'
      i=1
      for s in "${SESSIONS[@]}"; do
        IFS='|' read -r name windows state <<<"$s"
        printf ' %d   %-16s %s Fenster   %s\n' "$i" "$name" "$windows" "$state"
        i=$((i+1))
      done
    fi

    printf '\n [1-9] Öffnen   [N] Neu   [K] Beenden\n [H] Hilfe       [R] Neu laden   [Q] Zurück\n\n Auswahl: '
    read -rsn1 w; printf '\n'
    case "$w" in
      [1-9])
        idx=$((w-1))
        [ "$idx" -lt "${#SESSIONS[@]}" ] || continue
        name="${SESSIONS[$idx]%%|*}"
        ssh -t "$ZIEL" "tmux attach-session -t '$name'" || true
        ;;
      n|N)
        printf 'Name der neuen Session: '; read -r name
        case "$name" in ""|*[!A-Za-z0-9._-]*) printf 'Nur Buchstaben, Zahlen, Punkt, _ und - verwenden.\n'; sleep 2; continue;; esac
        ssh -t "$ZIEL" "tmux new-session -s '$name'" || true
        ;;
      k|K)
        [ "${#SESSIONS[@]}" -gt 0 ] || continue
        printf '\nWelche Session beenden?\n\n'
        i=1
        for s in "${SESSIONS[@]}"; do
          IFS='|' read -r sname windows state <<<"$s"
          printf ' %d   %-16s %s Fenster   %s\n' "$i" "$sname" "$windows" "$state"
          i=$((i+1))
        done
        printf '\nNummer: '
        read -r nr
        case "$nr" in *[!0-9]*|'') continue;; esac
        idx=$((nr-1))
        [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SESSIONS[@]}" ] || continue
        selected="${SESSIONS[$idx]}"
        IFS='|' read -r name _windows _state <<<"$selected"
        printf 'Session "%s" wirklich beenden? [j/N] ' "$name"
        read -rsn1 ok; printf '\n'
        [ "$ok" = j ] || [ "$ok" = J ] || continue
        ssh "$ZIEL" "tmux kill-session -t '$name'" || true
        ;;
      h|H) tmux_hilfe ;;
      r|R) ;;
      q|Q|"$ESC") return ;;
    esac
  done
}

while true; do
  clear
  printf 'TERMUX\n------------------------------\n\n'
  printf ' 1   Server     SSH zu Odin\n'
  printf ' 2   Desktop    i3 starten\n'
  printf ' 3   tmux       Sessions\n\n'
  printf ' [Enter] = 1   [Esc] = Shell\n\n Auswahl: '
  read -rsn1 wahl || break
  case "$wahl" in
    ''|1) clear; [ -n "$ZIEL" ] && ssh "$ZIEL" || printf 'Kein Server konfiguriert.\n'; pause ;;
    2) clear; "$HOME/start-i3.sh"; pause ;;
    3) tmux_manager ;;
    q|Q|"$ESC") clear; break ;;
  esac
done
EOF
chmod +x "$MENU"

echo "==> Shell-Start"
touch "$HOME/.bashrc"
awk '
/^# >>> setup_i3\.sh$/ {skip=1; next}
/^# <<< setup_i3\.sh$/ {skip=0; next}
!skip {print}
' "$HOME/.bashrc" > "$HOME/.bashrc.neu"
cat >> "$HOME/.bashrc.neu" <<'EOF'

# >>> setup_i3.sh
if [ -z "${TERMUX_MENU_DONE:-}" ] && [ -t 0 ] && [ -t 1 ] && [ -f "$HOME/.termux-menu.sh" ]; then
  export TERMUX_MENU_DONE=1
  . "$HOME/.termux-menu.sh"
fi
alias desk='~/start-i3.sh'
# <<< setup_i3.sh
EOF
mv "$HOME/.bashrc.neu" "$HOME/.bashrc"

echo "==> Termux Extra Keys"
mkdir -p "$HOME/.termux"
touch "$TPROPS"
awk '
/^# >>> setup_i3\.sh$/ {skip=1; next}
/^# <<< setup_i3\.sh$/ {skip=0; next}
skip {next}
/^[[:space:]]*extra-keys[[:space:]]*=/ {next}
{print}
' "$TPROPS" > "$TPROPS.neu"
cat >> "$TPROPS.neu" <<'EOF'

# >>> setup_i3.sh
extra-keys = [['ESC','TAB',{macro:'ESC [ Z',display:'S-TAB'},'ALT','-',{macro:'CTRL b %',display:'V|'},'UP',{macro:'CTRL b "',display:'H-'}],['HOME','END','|',{macro:'e x i t ENTER',display:'EXIT'},{macro:'CTRL b d',display:'DETACH'},'LEFT','DOWN','RIGHT']]
# <<< setup_i3.sh
EOF
mv "$TPROPS.neu" "$TPROPS"
termux-reload-settings 2>/dev/null || true

cat <<'EOF'

Fertig.

Neu laden:
  source ~/.bashrc

Menü:
  1 Server  — normales SSH, keine tmux-/Claude-Automatik
  2 Desktop — minimales i3
  3 tmux    — Sessions anzeigen, öffnen, erstellen, beenden + Spickzettel

i3/Firefox bleiben absichtlich weitgehend Standard.
Einzige optische Vorgaben: GTK-Darkmode und XCURSOR_SIZE=32.
EOF
