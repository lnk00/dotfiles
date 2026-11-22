{ config, lib, pkgs, theme, ... }:

let
  cursor = config.home.pointerCursor;

  # foot lets the wallpaper through (termAlpha < 1), meant to be seen blurred;
  # at termAlpha 1 there would be nothing to blur
  frosted = theme.termAlpha < 1;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";

  # new foot in the cwd of the focused foot's shell, else $HOME
  footHere = pkgs.writeShellApplication {
    name = "foot-here";
    runtimeInputs = with pkgs; [ foot jq procps coreutils ];
    text = ''
      dir=$HOME
      pid=$(${hyprctl} activewindow -j | jq -r 'select(.class == "foot") | .pid') || true
      if [ -n "$pid" ] && child=$(pgrep -nP "$pid"); then
        dir=$(readlink "/proc/$child/cwd") || dir=$HOME
      fi
      [ -d "$dir" ] || dir=$HOME
      exec foot --working-directory="$dir"
    '';
  };

  # pick a window by class and title, focus it
  windowPick = pkgs.writeShellApplication {
    name = "window-pick";
    runtimeInputs = with pkgs; [ fuzzel jq ];
    text = ''
      # fuzzel exits non-zero on Esc; show the label column, keep the address for focus
      entry=$(${hyprctl} clients -j \
        | jq -r '.[] | select(.mapped) | "\(.address)\t\(.class): \(.title)"' \
        | fuzzel --dmenu --with-nth 2 --prompt "window ") || exit 0
      addr=''${entry%%$'\t'*}
      ${hyprctl} dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
    '';
  };

  rgba = c: "rgba(${c}ff)";
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # configuration.nix's programs.hyprland installs both
    package = null;
    portalPackage = null;

    # Hyprland 0.57 reads only hyprland.lua; HM's own settings would map every
    # attribute to an hl.* call, so this is the Lua itself
    extraConfig = ''
      local mod = "SUPER"

      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

      -- theme.nix's pointer; Hyprland reads XCURSOR_THEME at startup, and apps it spawns inherit it
      hl.env("XCURSOR_THEME", "${cursor.name}")
      hl.env("XCURSOR_SIZE", "${toString cursor.size}")

      hl.config({
        general = {
          -- a scroller: columns at 0.65 of the screen, the focused one centred, edge to edge
          -- with no gaps
          layout = "scrolling",
          -- minus half of border_size: the border sits inside each tile, so neighbours overlap
          -- and their two borders merge into one line as thick as the screen-edge ones. Only
          -- clean because every border has the same colour. frame.nix closes the screen
          -- edges, where the scroller cuts the side columns off, with a matching line
          gaps_in = -${toString (theme.borderWidth / 2)},
          gaps_out = 0,
          border_size = ${toString theme.borderWidth},
          col = {
            -- one colour for every window: the focused column is centred, so the border
            -- needn't mark it. fgSubtle, not fg, so the frame isn't stark
            active_border = "${rgba theme.fgSubtle}",
            inactive_border = "${rgba theme.fgSubtle}",
          },
        },
        scrolling = {
          column_width = 0.65,
          focus_fit_method = "center",
          -- SUPER+H/L stop at the first and last column instead of wrapping round
          wrap_focus = false,
          -- a lone window keeps that width
          fullscreen_on_one_column = false,
        },
        -- no shadows. Glass only when the palette is translucent, frosted without a colour
        -- boost (vibrancy 0)
        decoration = {
          rounding = ${toString theme.radius},
          active_opacity = 1.0,
          inactive_opacity = 1.0,
          shadow = { enabled = false },
          blur = {
            enabled = ${lib.boolToString frosted},
            size = 8,
            passes = 3,
            noise = 0.035,
            brightness = 1.05,
            contrast = 0.9,
            vibrancy = 0,
          },
        },
        -- groups are the tabs foot lacks: a new window opened from a grouped one joins it
        -- (auto_group), and the bar above lists them. Grouped windows keep the same side
        -- borders; the tabs are glass like foot, the active one paler (colours set by
        -- reading mode below)
        group = {
          col = {
            border_active = "${rgba theme.fgSubtle}",
            border_inactive = "${rgba theme.fgSubtle}",
          },
          groupbar = {
            font_family = "JetBrainsMono Nerd Font Mono",
            font_size = 10,
            height = 18,
            -- filled tabs instead of a strip under each title
            gradients = true,
            indicator_height = 0,
            rounding = ${toString theme.radius},
            gradient_rounding = ${toString theme.radius},
            gaps_out = 0,
            keep_upper_gap = false,
            blur = ${lib.boolToString frosted},
            text_color = "${rgba theme.fg}",
            text_color_inactive = "${rgba theme.fgSubtle}",
          },
        },
        -- no motion: focus, swapcol and colresize jump straight to their place
        animations = { enabled = false },
        input = {
          repeat_rate = 75,
          repeat_delay = 200,
          -- focus follows clicks only
          follow_mouse = "disabled",
          -- Magic Trackpad: slower scrolling, and a press (not a tap) to click
          touchpad = {
            scroll_factor = 0.5,
            tap_to_click = false,
          },
        },
        cursor = {
          -- seconds still before the pointer hides
          inactive_timeout = 3,
          -- software cursor: the screen is on nouveau, which refuses atomic modesetting, and on
          -- aquamarine's legacy DRM path the hardware cursor vanished as soon as it stopped
          -- moving. "Auto" (2) only goes software on NVIDIA's proprietary driver.
          no_hardware_cursors = 1,
        },
        misc = {
          background_color = "${rgba theme.bgInset}",
          disable_hyprland_logo = true,
          disable_splash_rendering = true,
          force_default_wallpaper = 0,
        },
        ecosystem = {
          no_update_news = true,
          no_donation_nag = true,
        },
      })

      -- fuzzel and mako are translucent like foot (theme.glass), so frost them too while blur is
      -- on; ignore_alpha leaves any fully clear pixels around them unblurred
      hl.layer_rule({ name = "frost-launcher", match = { namespace = "^launcher$" }, blur = true, ignore_alpha = 0.5 })
      hl.layer_rule({ name = "frost-notifications", match = { namespace = "^notifications$" }, blur = true, ignore_alpha = 0.5 })

      -- Reading mode: snes19xx's e-ink shader over the whole screen (reading_mode.glsl).
      -- On from login; SUPER+e drops it for colour work. A config reload (every
      -- rebuild) turns it back on.
      -- Paper isn't see-through, so while it is on foot and the group tabs are solid.
      -- force_rgbx draws foot without its alpha channel; it stays off other windows
      -- because it covers their popups too, and would blacken menus' clear corners.
      -- foot's bg is premultiplied, so it comes out termAlpha darker, which the
      -- shader's paper curve all but absorbs
      local reading = "${./reading_mode.glsl}"
      local solid = hl.window_rule({ name = "reading-solid", match = { class = "^foot$" }, force_rgbx = true })
      local function readingMode(on)
        hl.config({
          decoration = { screen_shader = on and reading or "" },
          group = { groupbar = { col = {
            active = on and "${rgba theme.bg}" or "rgba(${theme.bg}${theme.glass})",
            inactive = on and "${rgba theme.bgInset}" or "rgba(${theme.bgInset}${theme.glass})",
          } } },
        })
        solid:set_enabled(on)
      end
      local readingOn = true
      readingMode(readingOn)
      hl.bind(mod .. " + E", function()
        readingOn = not readingOn
        readingMode(readingOn)
      end, { description = "toggle e-ink reading mode" })

      hl.on("hyprland.start", function()
        hl.exec_cmd("wallpaper --restore")
        hl.exec_cmd("${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store")
      end)

      hl.bind(mod .. " + T", hl.dsp.exec_cmd("${footHere}/bin/foot-here"))
      hl.bind(mod .. " + D", hl.dsp.window.close())
      hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen-beta"))
      hl.bind(mod .. " + M", hl.dsp.exit())
      hl.bind(mod .. " + H", hl.dsp.layout("focus l"))
      hl.bind(mod .. " + L", hl.dsp.layout("focus r"))
      hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
      hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
      -- column width in screen fractions, 5% a step
      hl.bind(mod .. " + CTRL + H", hl.dsp.layout("colresize -0.05"), { repeating = true })
      hl.bind(mod .. " + CTRL + L", hl.dsp.layout("colresize +0.05"), { repeating = true })
      -- tabs: G makes the focused window a group (or dissolves its group), Y/O step through it
      hl.bind(mod .. " + G", hl.dsp.group.toggle())
      hl.bind(mod .. " + Y", hl.dsp.group.prev())
      hl.bind(mod .. " + O", hl.dsp.group.next())
      hl.bind(mod .. " + S", hl.dsp.exec_cmd("screenshot full"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("screenshot region"))
      hl.bind(mod .. " + space", hl.dsp.exec_cmd("fuzzel"))
      hl.bind(mod .. " + V", hl.dsp.exec_cmd("clipboard-pick"))
      hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("${windowPick}/bin/window-pick"))
      -- dictation (voxtype.nix): hold SUPER+R and speak, the text is typed on release.
      -- voxtype reads that chord from the keyboard itself, since a release bind here misses R
      -- when SUPER comes up first; it's bound only so apps never see it. SUPER+W starts and
      -- stops a hands-free take (any SUPER+…+R would also start the push-to-talk one)
      hl.bind(mod .. " + R", function() end)
      hl.bind(mod .. " + W", hl.dsp.exec_cmd("voxtype record toggle"))
    '';
  };
}
