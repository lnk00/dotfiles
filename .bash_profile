# .bash_profile

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

if [ ! -S "/run/user/$(id -u)/bus" ]; then
    dbus-daemon --session --address="unix:path=/run/user/$(id -u)/bus" --fork
fi
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

if [ ! -S "/run/user/$(id -u)/pipewire-0" ]; then
    pipewire       >"/run/user/$(id -u)/pipewire.log"       2>&1 &
    wireplumber    >"/run/user/$(id -u)/wireplumber.log"    2>&1 &
    pipewire-pulse >"/run/user/$(id -u)/pipewire-pulse.log" 2>&1 &
    for i in $(seq 1 50); do
        [ -S "/run/user/$(id -u)/pipewire-0" ] && break
        sleep 0.1
    done
fi

# Get the aliases and functions
[ -f $HOME/.bashrc ] && . $HOME/.bashrc
