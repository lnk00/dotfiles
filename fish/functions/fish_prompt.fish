function fish_prompt
    set_color --bold $fish_color_cwd
    echo -n (path basename $PWD)
    echo -n ' ➜ '
    set_color --reset
end
