{ zen-browser, frost, ... }:

let
  inherit (frost) hash;

  # Dark Reader reads no managed storage, so policies can't set its colours;
  # this is an import file instead. An import replaces the whole theme
  # object, hence every key, defaults included.
  darkReader = with frost.dark; {
    enabled = true;
    # recolour natively dark sites too: their surfaces stay dark, greys go neutral
    detectDarkTheme = false;
    theme = {
      mode = 1;
      brightness = 100;
      contrast = 100;
      grayscale = 0;
      sepia = 0;
      useFont = false;
      fontFamily = "Open Sans";
      textStroke = 0;
      engine = "dynamicTheme";
      stylesheet = "";
      darkSchemeBackgroundColor = hash bg;
      darkSchemeTextColor = hash brWhite;
      lightSchemeBackgroundColor = hash frost.light.bg;
      lightSchemeTextColor = hash frost.light.fg;
      scrollbarColor = "";
      selectionColor = hash sel;
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

  # Import once: Dark Reader settings → Import Settings
  xdg.configFile."darkreader/earl-grey.json".text = builtins.toJSON darkReader;
}
