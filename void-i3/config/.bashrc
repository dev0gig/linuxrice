# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
@@REMOTE_ALIAS@@

# Claude Code aktualisiert sich nicht selbst (siehe /etc/profile.d/claude-code.sh)
export DISABLE_AUTOUPDATER=1

# Editor und Pager.
# EDITOR/VISUAL gelten fuer alles, was sich einen Editor holt: git commit,
# crontab, visudo. Yazi geht seit dem [opener] in ~/.config/yazi/yazi.toml
# absichtlich NICHT diesen Weg -- Enter auf einer Textdatei startet Helix dort
# in einem eigenen Alacritty, damit der Dateimanager daneben stehen bleibt
# statt dahinter zu verschwinden.
export EDITOR=hx
export VISUAL=hx
# bat als Pager: wie less, aber mit Syntaxhervorhebung. -F beendet sich bei
# kurzen Dateien selbst, -R laesst Farben durch.
export PAGER=less
export BAT_PAGER='less -FR'

alias cat='bat --paging=never'
alias catp='bat'
alias md='glow -p'
alias fm='yazi'
