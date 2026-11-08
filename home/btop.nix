{ lib, frost, variant, ... }:

let
  inherit (frost) hash;

  # Same restraint as helix and yazi: box outlines and dividers recede to the
  # border grey, the lavender accent carries hotkeys, the process banner and
  # the low end of every load graph, and the hues appear only where btop
  # encodes meaning — heat, memory kinds, traffic direction.
  btopTheme = v:
    let
      # a gradient runs over a meter's length or a graph's height, so a quiet
      # system shows only `start`
      gradient = name: start: mid: end: {
        "${name}_start" = start;
        "${name}_mid" = mid;
        "${name}_end" = end;
      };
      # one hue, lifted at the top of its range
      ramp = name: c: br: gradient name c c br;

      colors = {
        main_bg = v.bg;
        main_fg = v.fg;
        title = v.fg;
        hi_fg = v.accent;
        selected_bg = v.selStrong;
        selected_fg = v.brWhite;
        inactive_fg = v.fgSubtle;
        graph_text = v.fgDim;
        # the empty track of a meter
        meter_bg = v.sel;
        proc_misc = v.accent;
        cpu_box = v.border;
        mem_box = v.border;
        net_box = v.border;
        proc_box = v.border;
        div_line = v.border;

        # mirrors helix's statusline modes: lavender "doing", blue follow, red stop
        proc_banner_bg = v.accent;
        proc_banner_fg = v.bg;
        proc_follow_bg = v.blue;
        proc_pause_bg = v.red;
        followed_bg = v.blue;
        followed_fg = v.bg;
      }
      # load: calm lavender, rising through magenta to red
      // gradient "cpu" v.accent v.magenta v.red
      // gradient "process" v.accent v.magenta v.red
      // gradient "temp" v.green v.yellow v.red
      // ramp "used" v.red v.brRed
      // ramp "available" v.yellow v.brYellow
      // ramp "cached" v.blue v.brBlue
      // ramp "free" v.green v.brGreen
      // ramp "download" v.blue v.brBlue
      // ramp "upload" v.magenta v.brMagenta;
    in
    lib.concatStrings (lib.mapAttrsToList (k: c: ''theme[${k}]="${hash c}"'' + "\n") colors);
in
{
  programs.btop = {
    enable = true;
    settings = {
      # like helix, follows `variant` rather than foot's runtime toggle
      color_theme = "frost-${variant}";
      # like helix's bg-less ui.background: foot's translucency shows through
      theme_background = false;
    };
    themes = {
      frost-light = btopTheme frost.light;
      frost-dark = btopTheme frost.dark;
      frost-eink = btopTheme frost.eink;
    };
  };
}
