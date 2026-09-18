#!/bin/sh
# X-Session: Ressourcen laden, dann i3 starten

# xterm-Farben & Fonts einlesen
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# Dark Mode fuer GTK-Anwendungen (GTK-Dialoge, PCManFM, ...)
export GTK_THEME=Adwaita:dark

# Cursor-Theme und -Groesse. Das Theme liegt systemweit unter
# /usr/share/icons/Colloid-dark-cursors ("dark" = heller Zeiger fuer dunkle
# Oberflaechen). 36 ist eine im Theme eingebaute Groesse (48-px-Pixmap),
# wird also nicht skaliert.
export XCURSOR_THEME=Colloid-dark-cursors
export XCURSOR_SIZE=36

# Sitzung mit eigenem D-Bus starten -- WirePlumber und andere Dienste
# finden den Bus sonst nur ueber den X11-Autolaunch (mehrere Busse).
exec dbus-run-session i3
