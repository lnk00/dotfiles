if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -g fish_greeting
set -g fish_key_bindings fish_vi_key_bindings
set -g EDITOR helix

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
set -gx GPG_TTY (tty)

zoxide init fish | source

# Make Herdr use OSC 52 instead of blocking on wl-copy under Wayland.
function herdr
    set -lx SSH_TTY 1
    command herdr $argv
end

# Proton Pass helpers
function pp
    if test (count $argv) -ne 2
        echo "Usage: pp {username|email|password|totp} ITEM" >&2
        return 2
    end

    set -l field $argv[1]
    set -l item $argv[2]

    switch $field
        case u user username
            set field username
        case e email
            set field email
        case p pass password
            set field password
        case otp totp
            set field totp
        case '*'
            echo "Usage: pp {username|email|password|totp} ITEM" >&2
            return 2
    end

    pass-cli item get --item-title "$item" --field "$field"
end

function pp-copy
    if test (count $argv) -ne 2
        echo "Usage: pp-copy {username|email|password|totp} ITEM" >&2
        return 2
    end

    set -l value (pp $argv)
    if test $status -ne 0
        return 1
    end

    if type -q wl-copy
        printf '%s' "$value" | jay run-tagged pp-clipboard wl-copy --trim-newline >/dev/null 2>&1 &
    else if type -q xclip
        printf '%s' "$value" | xclip -selection clipboard >/dev/null 2>&1 &
    else if type -q xsel
        printf '%s' "$value" | xsel --clipboard --input >/dev/null 2>&1 &
    else if type -q pbcopy
        printf '%s' "$value" | pbcopy >/dev/null 2>&1 &
    else
        echo "No clipboard utility found (tried wl-copy, xclip, xsel, pbcopy)." >&2
        return 1
    end

    echo "Copied $argv[1] for $argv[2] to the clipboard."
end
