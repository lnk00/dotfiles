{ lib, pkgs, theme, variant, ... }:

let
  # served over http rather than packed as an extension: Tridactyl can't run on another extension's pages
  port = 7380;
  url = "http://127.0.0.1:${toString port}/";

  # time over date on the palette's bg, sized and spaced like the desktop clock (clock.nix)
  site = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="color-scheme" content="${variant}">
      <!-- already in the palette; Dark Reader would recolour the greys -->
      <meta name="darkreader-lock">
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
      <script>
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
      </script>
    </body>
    </html>
  '';
in
{
  # no-store: store files all date from 1970, so a cached page would never look stale to the browser
  systemd.user.services.zen-home = {
    Unit.Description = "Zen's home page";
    Service.ExecStart = lib.escapeShellArgs [
      (lib.getExe pkgs.darkhttpd)
      site
      "--addr" "127.0.0.1"
      "--port" (toString port)
      "--no-listing"
      "--no-server-id"
      "--header" "Cache-Control: no-store"
    ];
    Install.WantedBy = [ "default.target" ];
  };

  programs.zen-browser.policies = {
    # open the page on launch, instead of restoring the last session
    Homepage = {
      URL = url;
      StartPage = "homepage";
      Locked = true;
    };

    # the page used to be this unsigned extension; blocking uninstalls it from the profile
    ExtensionSettings."home@lnk0".installation_mode = "blocked";
  };

  # Ctrl+T lands on Tridactyl's new tab page, which forwards to this
  xdg.configFile."tridactyl/tridactylrc".text = "set newtab ${url}";

  # Ctrl+T opens a tab, not Zen's floating URL bar. Policies refuse zen.* prefs, so it goes
  # in user.js; the profile is Zen's own, as an HM profile would take over profiles.ini
  xdg.configFile."zen/o7sqv0ch.Default Profile/user.js".text = ''
    user_pref("zen.urlbar.replace-newtab", false);
  '';
}
