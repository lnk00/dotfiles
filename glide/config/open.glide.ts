/**
 * qutebrowser-style url opening.
 *
 *   o    open a url / search in the current tab
 *   O    ... in a new tab
 *   t    ... in a new tab (qutebrowser alias for O)
 *   go   edit the current url, open in the current tab
 *   gO   edit the current url, open in a new tab
 *
 * The commandline's first row is always `-> <what you typed>`, so <Enter>
 * navigates to exactly the input. <Tab>/<Down> reaches the completions
 * below it (bookmarks, then history).
 *
 * <Enter> on an empty input opens glide.o.newtab_url (config/blank.html).
 */

/**
 * Turn commandline input into a URL, or `null` when it should be treated
 * as a search query instead.
 */
function as_url(text: string): string | null {
  const input = text.trim();
  if (!input) return null;

  // explicit scheme, e.g. https://…, about:config, file:///…
  if (/^[a-z][a-z0-9+.-]*:/i.test(input)) return input;

  // no whitespace + looks like a host, e.g. example.com/foo, localhost:3000
  if (!/\s/.test(input)) {
    if (/^localhost(:\d+)?([/?#]|$)/.test(input)) return `http://${input}`;
    if (/^[^\s/?#]+\.[^\s/?#]+/.test(input)) return `https://${input}`;
  }

  return null;
}

async function open_input(input: string, new_tab: boolean): Promise<void> {
  const query = input.trim();

  // <Enter> straight after o / O, with nothing typed: fall back to the
  // configured new tab page. Read at keypress time rather than hardcoded,
  // so it tracks whatever prefs.glide.ts set.
  const url = query ? as_url(query) : glide.o.newtab_url;

  if (url) {
    if (new_tab) {
      await browser.tabs.create({ active: true, url });
    } else {
      const tab = await glide.tabs.active();
      await browser.tabs.update(tab.id, { url });
    }
    return;
  }

  if (new_tab) {
    await browser.search.query({ text: query, disposition: "NEW_TAB" });
  } else {
    const tab = await glide.tabs.active();
    await browser.search.query({ text: query, tabId: tab.id });
  }
}

type OpenEntry = { title: string; url: string; bookmark: boolean };

/** Bookmarks first, then history, deduped by url. */
async function open_completions(): Promise<OpenEntry[]> {
  const [bookmarks, history] = await Promise.all([
    browser.bookmarks.getRecent(100).catch(() => []),
    browser.history
      .search({ text: "", maxResults: 300, startTime: 0 })
      .catch(() => []),
  ]);

  const seen = new Set<string>();
  const entries: OpenEntry[] = [];

  for (const bookmark of bookmarks) {
    if (!bookmark.url || seen.has(bookmark.url)) continue;
    seen.add(bookmark.url);
    entries.push({
      title: bookmark.title || bookmark.url,
      url: bookmark.url,
      bookmark: true,
    });
  }

  for (const item of history) {
    if (!item.url || seen.has(item.url)) continue;
    seen.add(item.url);
    entries.push({
      title: item.title || item.url,
      url: item.url,
      bookmark: false,
    });
  }

  return entries;
}

function matches_terms(input: string, haystack: string): boolean {
  const terms = input.toLowerCase().split(/\s+/).filter(Boolean);
  const target = haystack.toLowerCase();
  return terms.every((term) => target.includes(term));
}

async function show_open_commandline(opts: {
  new_tab: boolean;
  prefill?: string;
}): Promise<void> {
  const entries = await open_completions();

  // Kept first & always visible so that <Enter> opens exactly what was
  // typed, like qutebrowser. Tab/<Down> to reach a completion instead.
  // shown on the first row when nothing has been typed, matching what
  // <Enter> would then do
  const EMPTY_LABEL = "blank page";

  const typed_label = DOM.create_element("span", [
    opts.prefill ?? EMPTY_LABEL,
  ], { style: { color: "#888" } });

  glide.commandline.show({
    title: opts.new_tab ? "open (new tab)" : "open",
    input: opts.prefill,
    options: [
      {
        label: "open",
        matches({ input }) {
          typed_label.textContent = input.trim() || EMPTY_LABEL;
          return true;
        },
        render() {
          return DOM.create_element("div", {
            style: { display: "flex", alignItems: "center", gap: "8px" },
            children: [
              DOM.create_element("span", ["→"], { style: { color: "#888" } }),
              typed_label,
            ],
          });
        },
        execute({ input }) {
          void open_input(input, opts.new_tab);
        },
      },
      ...entries.map((entry) => ({
        label: entry.title,
        description: entry.url,
        matches: ({ input }: { input: string }) =>
          matches_terms(input, `${entry.title} ${entry.url}`),
        render: () =>
          DOM.create_element("div", {
            style: {
              display: "flex",
              alignItems: "baseline",
              gap: "8px",
              overflow: "hidden",
            },
            children: [
              DOM.create_element("span", [entry.bookmark ? "★" : "·"], {
                style: { color: entry.bookmark ? "#e0af68" : "#555" },
              }),
              DOM.create_element("span", [entry.title]),
              DOM.create_element("span", [entry.url], {
                style: {
                  color: "#777",
                  fontSize: "0.9em",
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                },
              }),
            ],
          }),
        execute: () => {
          void open_input(entry.url, opts.new_tab);
        },
      })),
    ],
  });
}

glide.keymaps.set(
  "normal",
  "o",
  () => show_open_commandline({ new_tab: false }),
  { description: "[o]pen a url in the current tab" },
);

glide.keymaps.set(
  "normal",
  "O",
  () => show_open_commandline({ new_tab: true }),
  { description: "[O]pen a url in a new tab" },
);

glide.keymaps.set(
  "normal",
  "t",
  () => show_open_commandline({ new_tab: true }),
  { description: "Open a url in a new [t]ab" },
);

glide.keymaps.set(
  "normal",
  "go",
  async () => {
    const tab = await glide.tabs.active();
    await show_open_commandline({ new_tab: false, prefill: tab.url });
  },
  { description: "Edit the current url and open it in the current tab" },
);

glide.keymaps.set(
  "normal",
  "gO",
  async () => {
    const tab = await glide.tabs.active();
    await show_open_commandline({ new_tab: true, prefill: tab.url });
  },
  { description: "Edit the current url and open it in a new tab" },
);
