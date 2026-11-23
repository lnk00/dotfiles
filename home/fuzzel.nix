{ ... }:

{
  programs.fuzzel = {
    enable = true;
    # for .desktop entries with Terminal=true
    settings.main.terminal = "foot";
  };
}
