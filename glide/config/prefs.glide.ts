/**
 * Firefox preferences (the about:config layer).
 */

// A blank page that is #111111 rather than about:blank's hardcoded white.
// Note: this path assumes the config lives at ~/.config/glide.
const BLANK_PAGE = `file://${glide.path.home_dir}/.config/glide/config/blank.html`;
// const BLANK_PAGE = `https://duckduckgo.com`;

// Home page: the Home button, <Alt-Home>, and startup
// (browser.startup.page is 1 = open homepage).
glide.prefs.set("browser.startup.homepage", BLANK_PAGE);

// New tabs: <C-t>, the + button, and Glide's own tab_new / t / O.
// This sets AboutNewTab.newTabURL, which is what BROWSER_NEW_TAB_URL reads.
glide.o.newtab_url = BLANK_PAGE;

// Belt and braces: should anything still land on about:newtab directly,
// render the blank tab instead of the activity stream.
glide.prefs.set("browser.newtabpage.enabled", false);
