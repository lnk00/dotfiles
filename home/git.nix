{ ... }:

{
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

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };
}
