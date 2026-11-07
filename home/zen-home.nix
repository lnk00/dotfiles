{ lib, pkgs, theme, variant, ... }:

let
  id = "home@lnk0";

  # time over date on the palette's bg, sized and spaced like the desktop clock (clock.nix).
  # A packed extension, not a file: only autoconfig can point the new tab at a file:// page,
  # and Zen's launcher execs the unwrapped binary, so the wrapper's mozilla.cfg is never read
  page = {
    "home.html" = ''
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="${variant}">
        <title>home</title>
        <style>
          html, body { height: 100%; margin: 0; }
          body {
            display: grid;
            place-items: center;
            overflow: hidden;
            cursor: default;
            user-select: none;
            background: #${theme.bg};
            color: #${theme.fg};
            font-family: "JetBrainsMono Nerd Font", monospace;
            /* the time's size; the date and spacing scale with it */
            --size: min(240px, 18vw, 30vh);
          }
          main {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: calc(var(--size) * 0.12);
          }
          /* the negative margins trim the font's line box down to the glyphs */
          #time { font-size: var(--size); margin: -0.24em 0 -0.3em; }
          #date {
            font-size: calc(var(--size) / 5);
            margin-top: -0.25em;
            /* halfway from fgDim to fg: set apart from the time, but not by much */
            color: color-mix(in srgb, #${theme.fgDim}, #${theme.fg});
          }
        </style>
      </head>
      <body>
        <main><div id="time"></div><div id="date"></div></main>
        <!-- extension pages forbid inline scripts -->
        <script src="home.js"></script>
      </body>
      </html>
    '';

    "home.js" = ''
      const time = document.getElementById("time");
      const date = document.getElementById("date");
      const pad = n => String(n).padStart(2, "0");
      const name = (d, part) => d.toLocaleString("en-GB", part).toLowerCase();

      function render() {
        const d = new Date();
        time.textContent = `''${pad(d.getHours())}:''${pad(d.getMinutes())}`;
        date.textContent = `''${name(d, { weekday: "long" })} ''${d.getDate()} ''${name(d, { month: "long" })}`;
      }

      // redraw on each minute, and on coming back to the tab: background tabs throttle timers
      function tick() {
        render();
        setTimeout(tick, 60000 - (Date.now() % 60000));
      }
      tick();
      document.addEventListener("visibilitychange", render);
    '';
  };

  manifest = {
    manifest_version = 2;
    name = "Home";
    browser_specific_settings.gecko.id = id;
    chrome_url_overrides.newtab = "home.html";
    chrome_settings_overrides.homepage = "home.html";
  };

  # Firefox redoes a file:// install only when the version changes, so it follows the content
  version = "1.${toString (lib.fromHexString (builtins.substring 0 7 (builtins.hashString "sha256" (builtins.toJSON [ manifest page ]))))}";

  files = page // { "manifest.json" = builtins.toJSON (manifest // { inherit version; }); };

  xpi = pkgs.runCommand "zen-home.xpi" { nativeBuildInputs = [ pkgs.zip ]; } ''
    cd ${pkgs.linkFarm "zen-home" (lib.mapAttrs pkgs.writeText files)}
    zip -qX $out *
  '';
in
{
  programs.zen-browser.policies = {
    ExtensionSettings.${id} = {
      installation_mode = "force_installed";
      install_url = "file://${xpi}";
    };

    # the xpi is unsigned, and Zen checks signatures by default; unlike release Firefox
    # it's built to honour turning that off (MOZ_REQUIRE_SIGNING is false)
    Preferences."xpinstall.signatures.required" = {
      Value = false;
      Status = "locked";
    };

    # open the homepage on launch, instead of restoring the last session
    Preferences."browser.startup.page" = {
      Value = 1;
      Status = "locked";
    };
  };

  # Ctrl+T opens a tab on the page above, not Zen's floating URL bar. Policies refuse zen.*
  # prefs, so it goes in user.js; the profile is Zen's own, as an HM profile would take over profiles.ini
  xdg.configFile."zen/o7sqv0ch.Default Profile/user.js".text = ''
    user_pref("zen.urlbar.replace-newtab", false);
  '';
}
