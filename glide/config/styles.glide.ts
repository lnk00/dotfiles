/**
 * Browser chrome styling.
 */

glide.styles.add(
  css`
    :root {
      --toolbar-bgcolor: #111111 !important;
    }

    #navigator-toolbox,
    #nav-bar {
      background-color: #111111 !important;
      background-image: none !important;
    }

    #navigator-toolbox {
      border-bottom: none !important;
    }
  `,
  { id: "navbar-bg" },
);

glide.styles.add(
  css`
    /*
     * Hide the nav bar entirely — url entry goes through the o / t keymaps.
     *
     * visibility: collapse (rather than display: none) is what Glide itself
     * uses for #TabsToolbar, and keeps the element around as a panel anchor.
     *
     * Safe here only because browser.tabs.inTitlebar is 0, so the window
     * controls live in the system titlebar. With Firefox drawing its own
     * titlebar, glide.o.native_tabs = "hide" moves the buttonbox into
     * #nav-bar and this would hide close/minimise/maximise along with it.
     */
    #nav-bar {
      visibility: collapse !important;
    }
  `,
  { id: "navbar-hide" },
);

glide.styles.add(
  css`
    /*
     * Commandline + completion list. Glide defaults both to rgb(26, 27, 37).
     * !important is needed because glide.css also sets these inside a
     * @media (prefers-color-scheme: dark) block.
     */
    :root {
      --glide-cmdl-bg: #111111 !important;
      --glide-cmplt-bg: #111111 !important;
    }
  `,
  { id: "commandline-bg" },
);
