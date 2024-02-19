# Exports
export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
export PATH=$PATH:$HOME/dev/flutter/bin
export PATH=$PATH:$HOME/.pub-cache/bin
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:/Users/damiendumontet/Library/Android/sdk/build-tools/33.0.0
export ANDROID_HOME=$HOME/Library/Android/sdk
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
export EDITOR="hx"

# Config
ZSH_THEME="gallois"
ENABLE_CORRECTION="true"
plugins=(git)

# Aliases
alias zshconf="hx ~/.zshrc"
alias zshsource="source ~/.zshrc"
alias hxconf="hx ~/.config/helix/config.toml"
alias hxtheme="hx ~/.config/helix/themes/catppuccin-lnk0.toml"
alias hxlang="hx ~/.config/helix/languages.toml"
alias m1="arch -x86_64"
alias tt="tree -I 'node_modules|build'"

# Homebrew setup
eval "$(/opt/homebrew/bin/brew shellenv)"

# Source
source $ZSH/oh-my-zsh.sh
