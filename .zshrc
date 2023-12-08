export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
export PATH="$PATH:$HOME/Documents/flutter/bin"

ZSH_THEME="gallois"
ENABLE_CORRECTION="true"
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

alias zshconf="hx ~/.zshrc"
alias zshsource="source ~/.zshrc"
alias hxconf="hx ~/.config/helix/config.toml"
alias hxtheme="hx ~/.config/helix/themes/catppuccin-lnk0.toml"
alias hxlang="hx ~/.config/helix/languages.toml"
alias yabaiconf="hx ~/.yabairc"
alias skhdconf="hx ~/.skhdrc"
alias nv="/opt/homebrew/bin/nvim"
alias m1="arch -x86_64"
alias tt="tree -I 'node_modules|build'"
alias kali="docker run --rm --tty --interactive --cap-add=NET_ADMIN -p 127.0.0.1:1080:1080 -e DISPLAY=host.docker.internal:0 --device=/dev/net/tun --sysctl net.ipv6.conf.all.disable_ipv6=0 -v /Users/damiendumontet/Documents/kali:/shared lnk0l/kali"
alias rr="ranger"
alias x11="xhost + 127.0.0.1"

eval "$(/opt/homebrew/bin/brew shellenv)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export EDITOR="hx"
