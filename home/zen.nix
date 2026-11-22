{ zen-browser, hash, theme, ... }:

let
  # Dark Reader reads no managed storage, so policies can't set its colours;
  # this is an import file instead. An import replaces the whole theme
  # object, hence every key, defaults included.
  darkReader = {
    enabled = true;
    # recolour natively dark sites too: every site turns to paper
    detectDarkTheme = false;
    theme = {
      # light
      mode = 0;
      brightness = 100;
      contrast = 100;
      grayscale = 0;
      sepia = 0;
      useFont = false;
      fontFamily = "Open Sans";
      textStroke = 0;
      engine = "dynamicTheme";
      stylesheet = "";
      # unused in light mode, but the import needs every key
      darkSchemeBackgroundColor = "#101010";
      darkSchemeTextColor = "#f0f0f0";
      lightSchemeBackgroundColor = hash theme.bg;
      lightSchemeTextColor = hash theme.fg;
      scrollbarColor = "";
      selectionColor = hash theme.sel;
      styleSystemControls = false;
      lightColorScheme = "Default";
      darkColorScheme = "Default";
      immediateModify = false;
    };
  };
in
{
  imports = [ zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    # Ignore the HTML autofocus attribute; Tridactyl's allowautofocus only blocks JS .focus()
    policies.Preferences."browser.autofocus" = {
      Value = false;
      Status = "locked";
    };

    policies.ExtensionSettings."addon@darkreader.org" = {
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
    };
  };

  # Pages fill the window edge to edge, without Zen's 8px frame, rounded corners or shadow.
  # Merges with zen-home.nix's user.js, since policies refuse zen.* prefs
  xdg.configFile."zen/o7sqv0ch.Default Profile/user.js".text = ''
    user_pref("zen.theme.content-element-separation", 0);
  '';

  # Import once: Dark Reader settings → Import Settings
  xdg.configFile."darkreader/earl-grey.json".text = builtins.toJSON darkReader;
}
