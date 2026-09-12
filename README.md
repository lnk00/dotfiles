# dotfiles

`$HOME` for a Void Linux + Wayland machine. Jay, bash, Neovim, Alacritty and
qutebrowser, all on an e-ink-inspired monochrome palette.

## Layout

| | |
|---|---|
| `.bashrc` `.bash_profile` `.inputrc` | shell: aliases, PATH, and the dbus + pipewire session bootstrap |
| `.gitconfig` | identity and GPG signing |
| `.config/jay/` `.config/mako/` | Wayland compositor and notifications |
| `.config/alacritty/` `.config/nvim/` | terminal and editor, with themes |
| `.config/starship/` `.config/lazygit/` | prompt and git TUI |
| `.config/qutebrowser/` | browser: config, per-site permissions, quickmarks |
| `.config/wireplumber/` | bluetooth audio codecs |
| `.config/packages.txt` | every explicitly installed xbps package |

## Setup on a new machine

`$HOME` already exists on a fresh install, so `git clone` into it will refuse.
Attach a repo to the existing directory instead:

```bash
cd ~
git init -b main
git remote add origin git@github.com:lnk00/dotfiles.git
git fetch origin
git checkout -f main                  # -f: overwrite the distro defaults
```

`checkout -f` overwrites any `$HOME` file this repo tracks and leaves everything
else alone. Run `git checkout main` first without `-f` to see what it would
clobber — it will include `.bashrc`, `.bash_profile`, `.inputrc` and
`.gitconfig`.

Restore the package set:

```bash
sudo xbps-install -Sy $(cat ~/.config/packages.txt)
```

That is the `import-package` alias in `.bashrc`; `export-package` regenerates
the list from what is currently installed.

`.gitconfig` names GPG `signingkey = 6A1D9A8390E3D6F4` and sets
`commit.gpgsign = true`. Import the key, or every commit fails until you clear
those two lines.

Then work through the services below — none of them come up on their own.

## Services to launch

There is no display manager and no session manager here. Void's runit has no
user-service layer, so nothing in this session is supervised. Three tiers, in
the order they have to come up.

### 1. System services — enable once, runit supervises them after

Only `agetty-tty1..6` are enabled by the installer. The rest are manual:

```bash
for s in dbus udevd dhcpcd elogind polkitd bluetoothd; do
    sudo ln -s /etc/sv/$s /var/service/
done
```

| | |
|---|---|
| `dbus` | system bus — `elogind` and `polkitd` both sit on it |
| `udevd` | device hotplug: input devices and DRM |
| `dhcpcd` | network |
| `elogind` | seat and session, so Jay can take DRM master without root |
| `polkitd` | privileged actions requested from the desktop |
| `bluetoothd` | `bluetui`, and the headset select Jay runs at startup |

Check with `ls /var/service/`; a service is up when `sudo sv status <name>`
reports `run:`.

### 2. Session daemons — started by `.bash_profile` at login

Already in this repo, listed here because both are workarounds rather than
preferences, and removing either breaks something non-obvious:

- **A user D-Bus session bus** at `/run/user/$UID/bus`. Void has no
  `pam_systemd`/elogind hook that creates it, and Jay's portal helper hardcodes
  that exact path with no fallback. No bus, no screen sharing.
- **pipewire, wireplumber, pipewire-pulse**, followed by a wait loop on
  `/run/user/$UID/pipewire-0`. The loop is load-bearing: Jay's portal helper
  connects to PipeWire immediately and never retries. Starting PipeWire from
  Jay's `on-graphics-initialized` instead loses that race almost every time.

Both run before `jay run`, which is the whole reason they live in
`.bash_profile` and not `.bashrc`.

### 3. The compositor — by hand, every login

```bash
jay run
```

From bash on tty1. Nothing starts it automatically. Jay is installed with
`cargo install jay-compositor`, so it lives in `~/.cargo/bin`.

Once graphics are up, Jay's own `on-graphics-initialized` hook starts the rest:
`mako` for notifications, `jay randr` to mark the primary output, and a
`bluetoothctl` script that powers the right headset on and the other off.

### Portal registration — root-owned, so not in this repo

Because Jay came from `cargo`, nothing installed the xdg-desktop-portal files
it ships. Without them screen sharing in Meet and qutebrowser fails silently.
Recreate both on a new machine:

```bash
sudo tee /usr/share/xdg-desktop-portal/portals/jay.portal >/dev/null <<'EOF'
[portal]
DBusName=org.freedesktop.impl.portal.desktop.jay
Interfaces=org.freedesktop.impl.portal.ScreenCast;org.freedesktop.impl.portal.RemoteDesktop;
EOF

sudo tee /usr/share/xdg-desktop-portal/jay-portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=jay
org.freedesktop.impl.portal.RemoteDesktop=jay
org.freedesktop.impl.portal.Inhibit=none
org.freedesktop.impl.portal.FileChooser=gtk4
EOF
```

`xdg-desktop-portal` itself needs no service — D-Bus activates it on demand.

When screen sharing breaks, check in this order:

```bash
jay log | grep -iE 'portal|dbus'      # D-Bus connection
cat ~/.local/share/jay/logs/portal/*.txt   # backend errors, e.g. PipeWire
busctl --user list | grep -i jay      # is the backend registered at all
```

`DBUS_SESSION_BUS_ADDRESS` must be exported in whatever shell runs `busctl`, or
it fails to connect and tells you nothing useful.

## What is deliberately not tracked

`.gitignore` is **deny-by-default**: everything under `$HOME` is ignored, and
each config is opted in explicitly. A newly installed app drops its files into
`~/.config` without ever appearing in `git status`.

To add a new config, un-ignore the directory *and* its contents:

```gitignore
!/.config/foo/
!/.config/foo/**
```

A negation cannot re-include a file whose parent directory is still ignored —
that is why every entry comes in pairs, and why `/.config/` itself has to be
un-ignored before anything beneath it can be. Check the result before
committing:

```bash
git add -A --dry-run
```

Held out on purpose: `.config/gh` (`hosts.yml` is a live OAuth token),
`.config/github-copilot` (`auth.db` is a Copilot token), `.config/pulse` (binary
auth cookie), `.config/go` (telemetry cache), `.config/qutebrowser/qsettings`
(Qt window geometry), and `.ssh` / `.gnupg` / `.claude`, which hold keys.
