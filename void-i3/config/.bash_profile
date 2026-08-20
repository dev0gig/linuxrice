# .bash_profile

# Get the aliases and functions
[ -f $HOME/.bashrc ] && . $HOME/.bashrc

# eigene Skripte (z. B. "wallpaper") -- muss vor dem startx-exec stehen,
# damit die grafische Sitzung den PATH erbt
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Touchscreen: Firefox echte XInput2-Touch-Events holen lassen (statt emulierter
# Maus). Erst damit scrollt Wischen mit Schwung, statt Bilder/Links zu ziehen.
# Muss vor dem startx-exec stehen, damit die grafische Sitzung die Variable erbt.
# export MOZ_USE_XINPUT2=1   # nur fuer Firefox; Chrome/Brave holen XInput2-Touch von selbst

# i3 automatisch starten - nur beim Login auf tty1 und wenn noch kein X laeuft
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && [ ! -e /tmp/.X11-unix/X0 ]; then
        exec startx
fi
