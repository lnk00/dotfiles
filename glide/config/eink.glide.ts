/**
 * e-ink browser chrome. GENERATED from ~/.config/theme/eink-dark.toml by build.py -- do not edit by hand
 *
 * Loaded after styles.glide.ts so it wins on the surfaces both touch.
 */

glide.styles.add(
  css`
    :root {
      /* Generic ------------------------------------------------------- */
      --glide-bg: #17150d !important;
      --glide-fg: #e3e3e1 !important;

      /* Commandline input row ----------------------------------------- */
      --glide-cmdl-bg: #17150d !important;
      --glide-cmdl-fg: #e3e3e1 !important;

      /* Completion list ----------------------------------------------- */
      --glide-cmplt-bg: #17150d !important;
      --glide-cmplt-fg: #e3e3e1 !important;
      --glide-cmplt-border-top: 1px solid #46443d !important;

      /* Section headers. These default to #111 -- a black slab across the
         top of the sheet, and the reason this file exists. */
      --glide-header-first-bg: #222018 !important;
      --glide-header-second-bg: #2e2b24 !important;
      --glide-header-third-bg: #3a3830 !important;
      --glide-header-border-bottom: 1px solid #46443d !important;

      /* Focused option. Glide inverts to #fff, which on paper is very
         nearly invisible; a fill reads correctly and matches every other
         selected row in the system. */
      --glide-of-bg: #2e2b24 !important;
      --glide-of-fg: #e3e3e1 !important;

      /* URLs. Default is a saturated green in both schemes. */
      --glide-url-fg: #a7a5a1 !important;
      --glide-url-bg: transparent !important;
      --glide-url-text-decoration: none !important;

      /* Mode indicator. The defaults are seven saturated hues; here each
         mode gets its own step on the ramp, so they separate by value the
         way the rest of the system does. */
      --glide-status-bg: #17150d !important;
      --glide-status-fg: #e3e3e1 !important;
      --glide-status-border: 1px solid #46443d !important;
      --glide-mode-normal: #17150d !important;
      --glide-mode-insert: #2e2b24 !important;
      --glide-mode-visual: #46443d !important;
      --glide-mode-command: #605e58 !important;
      --glide-mode-hint: #53514a !important;
      --glide-mode-op-pending: #7c7a74 !important;
      --glide-mode-ignore: #8a8883 !important;
      --glide-fallback-mode: #17150d !important;

      /* Search + link hints. The hint tag keeps a full invert on purpose:
         it is the one element that must be unmissable, exactly as the jump
         label does in the editor. */
      --glide-search-highlight-color: #3a3830 !important;
      --glide-hintspan-fg: #17150d !important;
      --glide-hintspan-bg: #e3e3e1 !important;
      --glide-hintspan-border-color: #46443d !important;
      --glide-hint-active-fg: #e3e3e1 !important;
      --glide-hint-active-bg: #2e2b24 !important;
      --glide-hint-active-outline: 1px solid #e3e3e1 !important;
      --glide-hint-bg: #222018 !important;
      --glide-hint-outline: 1px solid #46443d !important;
      --glide-hint-color: #e3e3e1 !important;
      --glide-hint-border: solid 1px #46443d !important;
      --glide-hint-background: #2e2b24 !important;

      /* Scrollbar + the JS-link hint tint: both default to raw greys that
         sit off the ramp. */
      --glide-scrollbar-color: #989792 #222018 !important;
      --glide-hintspan-js-background: #a7a5a1 !important;

      /* :viewsource and the new-tab spoiler box */
      --glide-vs-bg: #17150d !important;
      --glide-vs-fg: #e3e3e1 !important;
      --glide-highlight-box-bg: #222018 !important;
      --glide-highlight-box-fg: #e3e3e1 !important;

      /* Berkeley Mono is not installed on this machine, so the commandline
         was falling back to an arbitrary monospace. Match the terminal. */
      --glide-cmdl-font-family: "GeistMono Nerd Font Mono", monospace !important;
      --glide-cmplt-font-family: "GeistMono Nerd Font Mono", monospace !important;
    }

    /* ---- Rules that read no variable at all ------------------------- */

    /* White-at-low-alpha borders: invisible on paper. */
    [anonid="glide-commandline-holder"] {
      border-top: 1px solid #46443d !important;
    }

    /* Hover was hsla(0,0%,100%,0.05) -- a white wash over white. */
    [anonid="glide-commandline-completions"] .gcl-option:not(.focused):hover {
      background: #222018 !important;
    }

    /* URL and tab-group greys are hardcoded to a pale blue-grey literal,
       which lands near 2.4:1 on this paper. Both move onto the ramp. */
    .gcl-option:not(.focused) .url,
    [anonid="glide-commandline-completions"] table tr td.tgroup {
      color: #989792 !important;
    }

    /* The prefix column carries bookmark/history markers. Setting color
       covers a text glyph; the grayscale filter covers the emoji case,
       where the glyph paints itself and ignores color entirely. */
    [anonid="glide-commandline-completions"] table tr td.prefix {
      color: #a7a5a1 !important;
      filter: grayscale(1) !important;
    }

    .FindCompletionOption .match {
      color: #17150d !important;
      background: #e3e3e1 !important;
    }

    /* Chrome surfaces. #nav-bar is collapsed by styles.glide.ts; these keep
       it correct if it is ever shown again. */
    :root {
      --toolbar-bgcolor: #17150d !important;
    }

    #navigator-toolbox,
    #nav-bar {
      background-color: #17150d !important;
      background-image: none !important;
      color: #e3e3e1 !important;
    }
  `,
  { id: "eink-chrome" },
);
