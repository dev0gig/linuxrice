# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
alias odin='ssh patrick@odin'

# Claude Code aktualisiert sich nicht selbst (siehe /etc/profile.d/claude-code.sh)
export DISABLE_AUTOUPDATER=1

# Editor und Pager.
# EDITOR wirkt auch in yazi: dort oeffnet Enter auf einer Textdatei Helix
# direkt im selben Terminalfenster, ohne ein zweites Alacritty aufzumachen.
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
