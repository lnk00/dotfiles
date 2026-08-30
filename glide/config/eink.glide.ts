/**
 * e-ink browser chrome. GENERATED from ~/.config/theme/eink.toml by build.py -- do not edit by hand
 *
 * Loaded after styles.glide.ts so it wins on the surfaces both touch.
 */

glide.styles.add(
  css`
    :root {
      /* Generic ------------------------------------------------------- */
      --glide-bg: #fffaea !important;
      --glide-fg: #282826 !important;

      /* Commandline input row ----------------------------------------- */
      --glide-cmdl-bg: #fffaea !important;
      --glide-cmdl-fg: #282826 !important;

      /* Completion list ----------------------------------------------- */
      --glide-cmplt-bg: #fffaea !important;
      --glide-cmplt-fg: #282826 !important;
      --glide-cmplt-border-top: 1px solid #c0bcb0 !important;

      /* Section headers. These default to #111 -- a black slab across the
         top of the sheet, and the reason this file exists. */
      --glide-header-first-bg: #efeadb !important;
      --glide-header-second-bg: #dfdbcd !important;
      --glide-header-third-bg: #cfcbbf !important;
      --glide-header-border-bottom: 1px solid #c0bcb0 !important;

      /* Focused option. Glide inverts to #fff, which on paper is very
         nearly invisible; a fill reads correctly and matches every other
         selected row in the system. */
      --glide-of-bg: #dfdbcd !important;
      --glide-of-fg: #282826 !important;

      /* URLs. Default is a saturated green in both schemes. */
      --glide-url-fg: #5b5954 !important;
      --glide-url-bg: transparent !important;
      --glide-url-text-decoration: none !important;

      /* Mode indicator. The defaults are seven saturated hues; here each
         mode gets its own step on the ramp, so they separate by value the
         way the rest of the system does. */
      --glide-status-bg: #fffaea !important;
      --glide-status-fg: #282826 !important;
      --glide-status-border: 1px solid #c0bcb0 !important;
      --glide-mode-normal: #282826 !important;
      --glide-mode-insert: #41403c !important;
      --glide-mode-visual: #5b5954 !important;
      --glide-mode-command: #76746d !important;
      --glide-mode-hint: #686661 !important;
      --glide-mode-op-pending: #939087 !important;
      --glide-mode-ignore: #a29f95 !important;
      --glide-fallback-mode: #fffaea !important;

      /* Search + link hints. The hint tag keeps a full invert on purpose:
         it is the one element that must be unmissable, exactly as the jump
         label does in the editor. */
      --glide-search-highlight-color: #cfcbbf !important;
      --glide-hintspan-fg: #fffaea !important;
      --glide-hintspan-bg: #282826 !important;
      --glide-hintspan-border-color: #c0bcb0 !important;
      --glide-hint-active-fg: #282826 !important;
      --glide-hint-active-bg: #dfdbcd !important;
      --glide-hint-active-outline: 1px solid #282826 !important;
      --glide-hint-bg: #efeadb !important;
      --glide-hint-outline: 1px solid #c0bcb0 !important;
      --glide-hint-color: #282826 !important;
      --glide-hint-border: solid 1px #c0bcb0 !important;
      --glide-hint-background: #dfdbcd !important;

      /* Scrollbar + the JS-link hint tint: both default to raw greys that
         sit off the ramp. */
      --glide-scrollbar-color: #686661 #efeadb !important;
      --glide-hintspan-js-background: #5b5954 !important;

      /* :viewsource and the new-tab spoiler box */
      --glide-vs-bg: #fffaea !important;
      --glide-vs-fg: #282826 !important;
      --glide-highlight-box-bg: #efeadb !important;
      --glide-highlight-box-fg: #282826 !important;

      /* Berkeley Mono is not installed on this machine, so the commandline
         was falling back to an arbitrary monospace. Match the terminal. */
      --glide-cmdl-font-family: "GeistMono Nerd Font Mono", monospace !important;
      --glide-cmplt-font-family: "GeistMono Nerd Font Mono", monospace !important;
    }

    /* ---- Rules that read no variable at all ------------------------- */

    /* White-at-low-alpha borders: invisible on paper. */
    [anonid="glide-commandline-holder"] {
      border-top: 1px solid #c0bcb0 !important;
    }

    /* Hover was hsla(0,0%,100%,0.05) -- a white wash over white. */
    [anonid="glide-commandline-completions"] .gcl-option:not(.focused):hover {
      background: #efeadb !important;
    }

    /* URL and tab-group greys are hardcoded to a pale blue-grey literal,
       which lands near 2.4:1 on this paper. Both move onto the ramp. */
    .gcl-option:not(.focused) .url,
    [anonid="glide-commandline-completions"] table tr td.tgroup {
      color: #686661 !important;
    }

    /* The prefix column carries bookmark/history markers. Setting color
       covers a text glyph; the grayscale filter covers the emoji case,
       where the glyph paints itself and ignores color entirely. */
    [anonid="glide-commandline-completions"] table tr td.prefix {
      color: #5b5954 !important;
      filter: grayscale(1) !important;
    }

    .FindCompletionOption .match {
      color: #fffaea !important;
      background: #282826 !important;
    }

    /* Chrome surfaces. #nav-bar is collapsed by styles.glide.ts; these keep
       it correct if it is ever shown again. */
    :root {
      --toolbar-bgcolor: #fffaea !important;
    }

    #navigator-toolbox,
    #nav-bar {
      background-color: #fffaea !important;
      background-image: none !important;
      color: #282826 !important;
    }
  `,
  { id: "eink-chrome" },
);
