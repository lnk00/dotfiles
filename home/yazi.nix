{ frost, theme, ... }:

let
  inherit (frost) hash;

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
in
{
  programs.yazi = {
    enable = true;
    # theme.toml overrides yazi's own dark/light pair, so — like helix — yazi
    # follows `variant` rather than the terminal's runtime light/dark toggle.
    theme = yaziTheme theme;
  };
}
