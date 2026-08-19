#!/bin/sh
# X-Session: Ressourcen laden, dann i3 starten

# xterm-Farben & Fonts einlesen
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# Dark Mode fuer GTK-Anwendungen (Firefox, GTK-Dialoge, ...)
export GTK_THEME=Adwaita:dark

# Cursor-Theme und -Groesse (Nordzy, siehe ~/.icons)
export XCURSOR_THEME=Nordzy-cursors
export XCURSOR_SIZE=48

exec i3
