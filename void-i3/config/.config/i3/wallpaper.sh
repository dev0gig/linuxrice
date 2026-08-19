#!/bin/sh
# Setzt beim i3-Start das Hintergrundbild.
# feh merkt sich die letzte Wahl in ~/.fehbg -- das ist ein ausfuehrbares
# Shell-Skript, das genau denselben feh-Aufruf noch einmal absetzt.
# Gibt es das noch nicht, wird das erste Bild aus ~/Bilder/Wallpapers genommen.

if [ -x "$HOME/.fehbg" ]; then
    exec "$HOME/.fehbg"
fi

first=$(find "$HOME/Bilder/Wallpapers" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null |
        sort | head -n1)

[ -n "$first" ] && exec feh --bg-fill "$first"
exit 0
