#!/bin/sh
# X-Session: Ressourcen laden, dann i3 starten

# xterm-Farben & Fonts einlesen
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# Dark Mode fuer GTK-Anwendungen (GTK-Dialoge, PCManFM, ...)
export GTK_THEME=Adwaita:dark

# Cursor-Theme und -Groesse (Nordzy, siehe ~/.icons)
export XCURSOR_THEME=Nordzy-cursors
export XCURSOR_SIZE=48

# Sitzung mit eigenem D-Bus starten -- WirePlumber und andere Dienste
# finden den Bus sonst nur ueber den X11-Autolaunch (mehrere Busse).
exec dbus-run-session i3
