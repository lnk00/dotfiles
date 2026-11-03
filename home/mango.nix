{ lib, pkgs, mangowm, frost, theme, ... }:

let
  inherit (frost) opaque withAlpha;
in
{
  imports = [ mangowm.hmModules.mango ];

  wayland.windowManager.mango = {
    enable = true;
    package = pkgs.mango;
    systemd.enable = false;
    autostart_sh = ''
      ${pkgs.swaybg}/bin/swaybg -m fill -i ${../wallpapers/alone-cloud_dark.png} &
      ${pkgs.quickshell}/bin/quickshell -c clock &
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
      # layers that must stay sharp: slurp ("selection") and the wallpaper clock
      layer_rule = [
        "layer_name:^selection$,no_blur:1"
        "layer_name:^clock$,no_blur:1"
      ];

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
        "SUPER,s,spawn,screenshot full"
        "SUPER+SHIFT,s,spawn,screenshot region"
        "SUPER,space,spawn,fuzzel"
      ];
    };
  };
}
