function update-system --wraps='sudo pacman -Syu' --description 'alias update-system=sudo pacman -Syu'
    sudo pacman -Syu $argv
end
