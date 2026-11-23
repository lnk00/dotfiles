{ ... }:

{
  programs.fastfetch = {
    enable = true;
    settings.modules = [
      "title"
      "separator"
      "os"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "wm"
      "terminal"
      "cpu"
      "gpu"
      "memory"
      "disk"
      "break"
      # foot's 16 ANSI slots. "block" draws foreground glyphs; the default
      # background style sends SGR 5 for the bright row, which foot renders as
      # blinking
      {
        type = "colors";
        symbol = "block";
      }
    ];
  };
}
