{ lib, variant, ... }:

let
  # starship hides a group whose variables are all empty, so git_status uses
  # an invisible-but-present symbol: a dirty tree then shows a bare "*".
  zwsp = builtins.fromJSON ''"\u200b"'';
  # nf-linux-nixos from the Nerd Font foot uses
  nixos = builtins.fromJSON ''"\uf313"'';
in
{
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
        "$nix_shell"
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
      nix_shell = {
        format = "[$symbol]($style) ";
        symbol = nixos;
        style = "blue";
      };
    };
  };

  programs.bash = {
    enable = true;
    # /etc/nixos is owned by lnk0: evaluate as the user, sudo only to activate
    shellAliases.sys-rebuild = "nixos-rebuild switch --flake /etc/nixos#nixos --sudo";
    shellAliases.sys-edit = "hx /etc/nixos";
    shellAliases.cat = "bat";
    shellAliases.grep = "rg";
    shellAliases.gg = "lazygit";
    shellAliases.ff = "yazi";
    shellAliases.dd = "lazydocker";
    shellAliases.qq = "lazysql";
    # like btop, follows `variant`; cliamp.nix ships frost-light and frost-dark
    shellAliases.music = "cliamp --provider ytmusic --start-theme frost-${variant}";
    shellAliases.diff = "hunk diff";
    shellAliases.ls = "eza -l --git --icons";
    shellAliases.la = "eza -l -a --git --icons";
    shellAliases.tree = "eza -l --git --icons -T";
    shellAliases.history = "history | fzf";
    # the sequences foot.nix sends for Ctrl+i/k/h/l: history up/down, cursor left/right
    initExtra = ''
      bind '"\e[105;5u": history-search-backward'
      bind '"\e[107;5u": history-search-forward'
      bind '"\e[104;5u": backward-char'
      bind '"\e[108;5u": forward-char'
    '';
  };
}
