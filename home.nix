{ lib, pkgs, mangowm, zen-browser, ... }:

let
  frost = import ./palette.nix;
  inherit (frost) hash opaque withAlpha;

  # The single system-wide switch: "light" or "dark". Everything below derives
  # from it, so changing this one word rethemes foot, helix and mango together.
  # foot still carries both palettes and can toggle at runtime.
  variant = "dark";
  theme = frost.${variant};

  footColors = v: {
    alpha = v.termAlpha;
    alpha-mode = "matching";
    background = v.bg;
    foreground = v.fg;
    cursor = "${v.bg} ${v.accent}";
    selection-background = v.sel;
    selection-foreground = v.fg;
    regular0 = v.black;
    regular1 = v.red;
    regular2 = v.green;
    regular3 = v.yellow;
    regular4 = v.blue;
    regular5 = v.magenta;
    regular6 = v.cyan;
    regular7 = v.white;
    bright0 = v.brBlack;
    bright1 = v.brRed;
    bright2 = v.brGreen;
    bright3 = v.brYellow;
    bright4 = v.brBlue;
    bright5 = v.brMagenta;
    bright6 = v.brCyan;
    bright7 = v.brWhite;
  };

  # ui.background deliberately carries no bg so the terminal's translucency —
  # and therefore mango's blur — shows through the editor.
  helixTheme = v: {
    "ui.background" = { fg = hash v.fg; };
    "ui.text" = { fg = hash v.fg; };
    "ui.text.focus" = { fg = hash v.fg; modifiers = [ "bold" ]; };
    "ui.window" = { fg = hash v.border; };
    "ui.cursor" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.cursor.primary" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.cursor.match" = { bg = hash v.sel; modifiers = [ "bold" ]; };
    "ui.selection" = { bg = hash v.sel; };
    "ui.selection.primary" = { fg = hash v.brWhite; bg = hash v.selStrong; };
    "ui.linenr" = { fg = hash v.fgSubtle; };
    "ui.linenr.selected" = { fg = hash v.accent; modifiers = [ "bold" ]; };
    "ui.gutter" = { };
    "ui.statusline" = { fg = hash v.fg; };
    "ui.statusline.inactive" = { fg = hash v.fgDim; };
    "ui.statusline.normal" = { fg = hash v.bg; bg = hash v.blue; };
    "ui.statusline.insert" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.statusline.select" = { fg = hash v.bg; bg = hash v.magenta; };
    "ui.popup" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.help" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.menu" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.menu.selected" = { fg = hash v.fg; bg = hash v.sel; };
    "ui.virtual.ruler" = { bg = hash v.bgAlt; };
    "ui.virtual.jump-label" = { fg = hash v.magenta; modifiers = [ "bold" ]; };
    "ui.highlight" = { bg = hash v.bgInset; };
    "ui.virtual.whitespace" = { fg = hash v.fgFaint; };
    "ui.virtual.indent-guide" = { fg = hash v.fgFaint; };
    "ui.virtual.inlay-hint" = { fg = hash v.fgDim; };

    # earl_grey's restraint: structure only. Types, keywords and functions
    # carry the whole signal; comments recede with "dim"; everything else —
    # variables, strings, constants, punctuation, tags — stays plain text.
    "comment" = { modifiers = [ "dim" ]; };
    "keyword" = { fg = hash v.accent; };
    "type" = { fg = hash v.yellow; };
    "function" = { modifiers = [ "bold" ]; };

    "markup.heading" = { modifiers = [ "bold" ]; };
    "markup.bold" = { modifiers = [ "bold" ]; };
    "markup.italic" = { modifiers = [ "italic" ]; };
    "markup.link.url" = { modifiers = [ "underlined" ]; };
    "markup.raw" = { fg = hash v.fgDim; };

    "diff.plus" = { fg = hash v.green; };
    "diff.minus" = { fg = hash v.red; };
    "diff.delta" = { fg = hash v.fgDim; };

    "error" = { fg = hash v.red; };
    "warning" = { fg = hash v.yellow; };
    "info" = { fg = hash v.fgDim; };
    "hint" = { fg = hash v.blue; };
    "diagnostic.error" = { underline = { color = hash v.red; style = "curl"; }; };
    "diagnostic.warning" = { underline = { color = hash v.yellow; style = "curl"; }; };
    "diagnostic.info" = { underline = { color = hash v.fgDim; style = "curl"; }; };
    "diagnostic.hint" = { underline = { color = hash v.blue; style = "curl"; }; };
  };

  # Same restraint as the editor: chrome recedes to the border/dim greys, the
  # lavender accent carries the cursor, the selection and the current tab, and
  # the hues appear only where yazi encodes meaning — permissions, progress,
  # file kinds. "reversed" is avoided throughout: it would paint an opaque
  # block over the terminal's translucency.
  yaziTheme = v: {
    mgr = {
      cwd = { fg = hash v.accent; };
      find_keyword = { fg = hash v.yellow; bold = true; };
      find_position = { fg = hash v.magenta; bold = true; };
      symlink_target = { fg = hash v.fgDim; italic = true; };
      marker_copied = { fg = hash v.green; bg = hash v.green; };
      marker_cut = { fg = hash v.red; bg = hash v.red; };
      marker_marked = { fg = hash v.cyan; bg = hash v.cyan; };
      marker_selected = { fg = hash v.accent; bg = hash v.accent; };
      count_copied = { fg = hash v.bg; bg = hash v.green; };
      count_cut = { fg = hash v.bg; bg = hash v.red; };
      count_selected = { fg = hash v.bg; bg = hash v.accent; };
      border_symbol = "│";
      border_style = { fg = hash v.border; };
    };

    tabs = {
      active = { fg = hash v.bg; bg = hash v.accent; bold = true; };
      inactive = { fg = hash v.fgDim; bg = hash v.bgInset; };
    };

    # mirrors helix's statusline modes: blue normal, lavender "doing", magenta select
    mode = {
      normal_main = { fg = hash v.bg; bg = hash v.blue; bold = true; };
      normal_alt = { fg = hash v.blue; bg = hash v.bgInset; };
      select_main = { fg = hash v.bg; bg = hash v.magenta; bold = true; };
      select_alt = { fg = hash v.magenta; bg = hash v.bgInset; };
      unset_main = { fg = hash v.bg; bg = hash v.red; bold = true; };
      unset_alt = { fg = hash v.red; bg = hash v.bgInset; };
    };

    indicator = {
      parent = { fg = hash v.fg; bg = hash v.sel; };
      current = { fg = hash v.brWhite; bg = hash v.selStrong; };
      preview = { fg = hash v.fg; bg = hash v.sel; };
    };

    status = {
      perm_sep = { fg = hash v.fgFaint; };
      perm_type = { fg = hash v.green; };
      perm_read = { fg = hash v.yellow; };
      perm_write = { fg = hash v.red; };
      perm_exec = { fg = hash v.cyan; };
      progress_label = { fg = hash v.fg; bold = true; };
      progress_normal = { fg = hash v.accent; bg = hash v.bgInset; };
      progress_error = { fg = hash v.red; bg = hash v.bgInset; };
    };

    which = {
      border = { fg = hash v.border; };
      cand = { fg = hash v.accent; };
      rest = { fg = hash v.fgDim; };
      desc = { fg = hash v.fg; };
      separator = "  ";
      separator_style = { fg = hash v.fgFaint; };
    };

    confirm = {
      border = { fg = hash v.border; };
      title = { fg = hash v.accent; };
      body = { fg = hash v.fg; };
      list = { fg = hash v.fgDim; };
      btn_yes = { fg = hash v.bg; bg = hash v.accent; bold = true; };
      btn_no = { fg = hash v.fgDim; };
    };

    spot = {
      border = { fg = hash v.border; };
      title = { fg = hash v.accent; };
      tbl_col = { fg = hash v.accent; };
      tbl_cell = { fg = hash v.brWhite; bg = hash v.selStrong; };
    };

    notify = {
      title_info = { fg = hash v.green; };
      title_warn = { fg = hash v.yellow; };
      title_error = { fg = hash v.red; };
    };

    pick = {
      border = { fg = hash v.border; };
      active = { fg = hash v.accent; bold = true; };
      inactive = { fg = hash v.fgDim; };
    };

    input = {
      border = { fg = hash v.border; };
      title = { fg = hash v.accent; };
      value = { fg = hash v.fg; };
      selected = { bg = hash v.sel; };
    };

    cmp = {
      border = { fg = hash v.border; };
      active = { fg = hash v.brWhite; bg = hash v.selStrong; };
      inactive = { fg = hash v.fgDim; };
    };

    tasks = {
      border = { fg = hash v.border; };
      title = { fg = hash v.accent; };
      hovered = { fg = hash v.brWhite; bg = hash v.selStrong; };
    };

    help = {
      border = { fg = hash v.border; };
      chord = { fg = hash v.accent; };
      action = { fg = hash v.fg; };
      hovered = { fg = hash v.brWhite; bg = hash v.selStrong; bold = true; };
    };

    # everything unlisted stays plain fg, the way unlisted syntax does in helix
    filetype.rules = [
      { mime = "**/image/*"; fg = hash v.yellow; }
      { mime = "**/{audio,video}/*"; fg = hash v.magenta; }
      {
        mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
        fg = hash v.red;
      }
      { mime = "**/application/{pdf,doc,rtf}"; fg = hash v.cyan; }
      { mime = "vfs/{absent,stale}"; fg = hash v.fgFaint; }
      { url = "*"; is = "orphan"; fg = hash v.bg; bg = hash v.red; }
      { url = "*"; is = "exec"; fg = hash v.green; }
      { url = "*"; is = "dummy"; fg = hash v.bg; bg = hash v.red; }
      { url = "*/"; is = "dummy"; fg = hash v.bg; bg = hash v.red; }
      { url = "*/"; fg = hash v.accent; }
    ];
  };

  # starship hides a group whose variables are all empty, so git_status uses
  # an invisible-but-present symbol: a dirty tree then shows a bare "*".
  zwsp = builtins.fromJSON ''"\u200b"'';
in
{
  imports = [
    mangowm.hmModules.mango
    zen-browser.homeModules.beta
  ];

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    bat
    lazygit
    lazydocker
    lazysql
    eza
  ];

  programs.git = {
    enable = true;
    signing = {
      key = "6A1D9A8390E3D6F4";
      signByDefault = true;
    };
    settings = {
      user.name = "Damien";
      user.email = "damien@fullenrich.com";
      init.defaultBranch = "main";
      tag.gpgSign = true;
      gpg.program = "gpg";
    };
  };

  programs.fzf = {
    enable = true;
    defaultOptions = [ "--height 40%" "--layout reverse" "--border" ];
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
  };

  # Only ANSI color names, so the prompt follows foot's palette and its
  # runtime light/dark toggle.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$character"
      ];
      directory.style = "bright-white";
      character = {
        success_symbol = "[❯](bright-white)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };
      git_branch = {
        format = "[$branch]($style)";
        truncation_length = 24;
        style = "bright-black";
      };
      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](bright-white) ($ahead_behind$stashed)]($style)";
        style = "bright-white";
        conflicted = zwsp;
        untracked = zwsp;
        modified = zwsp;
        staged = zwsp;
        renamed = zwsp;
        deleted = zwsp;
        stashed = "≡";
      };
      git_state = {
        format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        style = "bright-black";
      };
    };
  };

  programs.bash = {
    enable = true;
    shellAliases.sys-rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
    shellAliases.sys-edit = "sudo hx /etc/nixos";
    shellAliases.cat = "bat";
    shellAliases.grep = "rg";
    shellAliases.gg = "lazygit";
    shellAliases.ff = "yazi";
    shellAliases.dd = "lazydocker";
    shellAliases.qq = "lazysql";
    shellAliases.ls = "eza -l --git --icons";
    shellAliases.la = "eza -l -a --git --icons";
    shellAliases.tree = "eza -l --git --icons -T";
    shellAliases.history = "history | fzf";
    initExtra = ''
      bind '"\e[105;5u": history-search-backward'
      bind '"\e[107;5u": history-search-forward'
      bind '"\e[104;5u": backward-char'
      bind '"\e[108;5u": forward-char'
    '';
  };

  wayland.windowManager.mango = {
    enable = true;
    package = pkgs.mango;
    systemd.enable = false;
    autostart_sh = ''
      ${pkgs.swaybg}/bin/swaybg -m fill -i ${./wallpapers/alone-cloud_dark.png} &
    '';
    settings = {
      tag_rule = map (id: "id:${toString id},layout_name:scroller") (lib.range 1 9);
      scroller_focus_center = 1;
      scroller_default_proportion = 0.5;
      scroller_default_proportion_single = 0.5;
      repeat_rate = 75;
      repeat_delay = 200;

      # frozen glass: blur whatever shows through a translucent window, then frost it
      blur = 1;
      blur_layer = 1;
      blur_optimized = 1;
      blur_params_radius = 8;
      blur_params_num_passes = 3;
      blur_params_noise = 0.035;
      blur_params_brightness = 1.05;
      blur_params_contrast = 0.9;
      blur_params_saturation = 0.85;

      focused_opacity = 0.99;
      unfocused_opacity = 0.99;

      border_radius = 8;
      border_px = 2;
      border_color = withAlpha "cc" theme.border;
      focus_color = withAlpha "cc" theme.border;
      urgent_color = opaque theme.red;
      root_color = opaque theme.bgInset;

      shadows = 0;
      layer_shadows = 1;
      shadow_only_floating = 0;
      shadows_size = 14;
      shadows_blur = 20.0;
      shadows_color = withAlpha "aa" frost.dark.bg;

      gap_inner_horizontal = 8;
      gap_inner_vertical = 8;
      gap_outer_horizontal = 8;
      gap_outer_vertical = 8;

      sloppy_focus = 0;
      cursor_hide_timeout = 5;

      bind = [
        "SUPER,t,spawn,foot"
        "SUPER,d,killclient"
        "SUPER,f,togglemaximizescreen"
        "SUPER,b,spawn,zen-beta"
        "SUPER,m,quit"
        "SUPER,h,focusdir,left"
        "SUPER,l,focusdir,right"
        "SUPER+SHIFT,h,move_client,left"
        "SUPER+SHIFT,l,move_client,right"
        "SUPER+CTRL,h,resizewin,-50,0"
        "SUPER+CTRL,l,resizewin,+50,0"
      ];
    };
  };

  programs.foot = {
    enable = true;
    settings = {
      main.font = "JetBrainsMono Nerd Font Mono:size=10";
      main.font-bold = "JetBrainsMono Nerd Font Mono:style=Bold:size=10";
      main.font-italic = "JetBrainsMono Nerd Font Mono:style=Italic:size=10";
      main.font-bold-italic = "JetBrainsMono Nerd Font Mono:style=Bold Italic:size=10";
      main.pad = "14x14";
      main.initial-color-theme = variant;
      key-bindings.pipe-scrollback =
        ''[sh -c "f=$(mktemp --suffix=.log) && cat - > \"$f\" && foot hx \"$f\"; rm -f \"$f\""] Mod1+space'';
      key-bindings.color-theme-toggle = "Control+Shift+t";
      text-bindings."\\x1b[105;5u" = "Control+i";
      text-bindings."\\x1b[107;5u" = "Control+k";
      text-bindings."\\x1b[104;5u" = "Control+h";
      text-bindings."\\x1b[108;5u" = "Control+l";

      colors-light = footColors frost.light;
      colors-dark = footColors frost.dark;
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "frost-${variant}";
      editor = {
        true-color = true;
        color-modes = true;
        indent-guides.render = true;
        statusline.mode = { normal = "NORMAL"; insert = "INSERT"; select = "SELECT"; };
      };
    };
    themes = {
      frost-light = helixTheme frost.light;
      frost-dark = helixTheme frost.dark;
    };
  };


  programs.yazi = {
    enable = true;
    # theme.toml overrides yazi's own dark/light pair, so — like helix — yazi
    # follows `variant` rather than the terminal's runtime light/dark toggle.
    theme = yaziTheme theme;
  };
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  # The desktop-wide light/dark preference, served over the portal as
  # org.freedesktop.appearance color-scheme. Chromium, Electron and GTK apps
  # read it to pick their own variant, so it follows `variant` above.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if variant == "dark" then "prefer-dark" else "prefer-light";

  gtk.enable = true;
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
}
