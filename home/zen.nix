{ zen-browser, ... }:

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
  };
}
