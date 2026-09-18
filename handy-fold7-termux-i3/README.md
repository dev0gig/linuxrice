# Handy Fold 7 — Termux i3 Minimal

Minimales Setup für das Samsung Galaxy Z Fold 7: Termux + Termux:X11 + i3 + Firefox + SSH.

Das Setup ist bewusst einfach gehalten. Keine Desktop-Umgebung, kein Panel, kein Compositor, kein Wallpaper, kein Cursor-Theme und keine Firefox-Sonderkonfiguration.

## Installation

Auf einem frischen Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/handy-fold7-termux-i3/setup_i3.sh | bash
```

Das Skript aktualisiert Termux und installiert Termux:X11, i3, OpenSSH, Firefox, lxterminal und die nötigen Basis-Pakete. Danach fragt es nach dem SSH-Ziel im Format `benutzer@host`.

Anschließend:

```bash
source ~/.bashrc
```

## Startmenü

Beim Öffnen eines interaktiven Termux-Terminals erscheint:

```text
TERMUX
------------------------------

 1   Server     SSH zu Odin
 2   Desktop    i3 starten
 3   tmux       Sessions

 [Enter] = 1   [Esc] = Shell
```

**Server** öffnet eine normale SSH-Shell. Auf Odin wird weder tmux noch Claude automatisch gestartet.

**Desktop** startet Termux:X11 mit i3. Firefox liegt auf Workspace 1, das Terminal auf Workspace 2.

**tmux** zeigt die aktuell auf Odin vorhandenen Sessions. Sessions können geöffnet, neu erstellt oder nach Bestätigung beendet werden. Ein eingebauter Spickzettel zeigt die wichtigsten tmux-Befehle.

## Termux Extra Keys

Die zwei Reihen bleiben für die Bedienung auf dem Fold erhalten:

```text
ESC  TAB  S-TAB  ALT  -  V|  UP    H-
HOME END  |      EXIT DEL LEFT DOWN RIGHT
```

- `V|` → tmux-Pane vertikal teilen
- `H-` → tmux-Pane horizontal teilen
- `S-TAB` → Shift+Tab
- `EXIT` → `exit` + Enter

## i3 und Firefox

i3 bleibt absichtlich sehr nah am Standard. Das Setup definiert nur die wenigen nötigen Start- und Navigations-Tasten sowie die Zuordnung von Firefox und Terminal.

Firefox erhält **keine user.js und keine Browser-Sonderkonfiguration**.

Optisch setzt das Startskript nur:

- `GTK_THEME=Adwaita:dark`
- `XCURSOR_SIZE=32`

Es wird kein eigenes Cursor-Theme installiert.

## Zusammenspiel mit Odin

Odin soll bei einer normalen SSH-Anmeldung nur eine normale Bash starten. tmux wird ausschließlich bewusst gestartet — entweder über Menüpunkt 3 auf dem Fold oder manuell auf Odin. Dadurch gibt es keine doppelte tmux-/Claude-Automatik mehr.
