# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

# Use bash-completion, if available, and avoid double-sourcing
[[ $PS1 &&
  ! ${BASH_COMPLETION_VERSINFO:-} &&
  -f /usr/share/bash-completion/bash_completion ]] &&
    . /usr/share/bash-completion/bash_completion

export BROWSER=qutebrowser
export EDITOR=nvim
export STARSHIP_CONFIG="$HOME/.config/starship/config.toml"

alias cd='z'
alias ls='ls --color=auto'
alias n='nvim'
alias nv='nvim'
alias hx='nvim'
alias cat='bat'
alias grep='ripgrep'
alias ff='yazi'
alias gg='lazygit'
alias sys-update='sudo xbps-install -Su'
alias sys-install='sudo xbps-install -S'
alias sys-remove='sudo xbps-remove'
alias reboot='sudo reboot now'
alias ls='eza -l --git --icons'
alias la='eza -l -a --git --icons'
alias tree='eza -l --git --icons -T'
alias export-package='xbps-query -m | xargs -n1 xbps-uhelper getpkgname | sort > packages.txt'
alias import-package='sudo xbps-install -Sy $(cat packages.txt)'
alias ss='source ~/.bashrc'

eval "$(starship init bash)"
eval "$(zoxide init bash)"
