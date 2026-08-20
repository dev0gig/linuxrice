# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
@@REMOTE_ALIAS@@

# Claude Code aktualisiert sich nicht selbst (siehe /etc/profile.d/claude-code.sh)
export DISABLE_AUTOUPDATER=1
