/**
 * qutebrowser-style bookmark picker.
 *
 *   b          pick a bookmark, open it in the current tab
 *   B          pick a bookmark, open it in a new tab
 *   m          bookmark the current tab, prompting for a name
 *
 * Both keys were Glide's word-back motions, which move behind <leader>
 * (<Space>) the same way `d` / `u` did in tabs.glide.ts:
 *
 *   <leader>b  motion b
 *   <leader>B  motion B
 */

type Bookmark = { title: string; url: string; folder: string };

/** Every bookmark in the tree, in bookmark-menu order, with its folder path. */
async function collect_bookmarks(): Promise<Bookmark[]> {
  const tree = await browser.bookmarks.getTree();
  const found: Bookmark[] = [];

  const walk = (
    nodes: Browser.Bookmarks.BookmarkTreeNode[],
    folder: string,
  ): void => {
    for (const node of nodes) {
      if (node.children) {
        // the unnamed roots shouldn't contribute a path segment
        const path = node.title
          ? folder
            ? `${folder}/${node.title}`
            : node.title
          : folder;
        walk(node.children, path);
        continue;
      }

      // skips separators (no url) and smart folders (place: queries)
      if (!node.url || node.url.startsWith("place:")) continue;

      found.push({ title: node.title || node.url, url: node.url, folder });
    }
  };

  walk(tree, "");
  return found;
}

function matches_terms(input: string, haystack: string): boolean {
  const terms = input.toLowerCase().split(/\s+/).filter(Boolean);
  const target = haystack.toLowerCase();
  return terms.every((term) => target.includes(term));
}

async function open_bookmark(url: string, new_tab: boolean): Promise<void> {
  if (new_tab) {
    await browser.tabs.create({ active: true, url });
    return;
  }

  const tab = await glide.tabs.active();
  await browser.tabs.update(tab.id, { url });
}

async function show_bookmark_picker(new_tab: boolean): Promise<void> {
  const bookmarks = await collect_bookmarks();

  glide.commandline.show({
    title: new_tab ? "bookmarks (new tab)" : "bookmarks",
    options: bookmarks.map((bookmark) => ({
      label: bookmark.title,
      description: bookmark.url,
      matches: ({ input }: { input: string }) =>
        matches_terms(
          input,
          `${bookmark.folder} ${bookmark.title} ${bookmark.url}`,
        ),
      render: () =>
        DOM.create_element("div", {
          style: {
            display: "flex",
            alignItems: "baseline",
            gap: "8px",
            overflow: "hidden",
          },
          children: [
            DOM.create_element("span", ["★"], { style: { color: "#e0af68" } }),
            DOM.create_element("span", [bookmark.title]),
            DOM.create_element("span", [bookmark.url], {
              style: {
                color: "#777",
                fontSize: "0.9em",
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
              },
            }),
            ...(bookmark.folder
              ? [
                DOM.create_element("span", [bookmark.folder], {
                  style: {
                    color: "#555",
                    fontSize: "0.85em",
                    marginLeft: "auto",
                    whiteSpace: "nowrap",
                  },
                }),
              ]
              : []),
          ],
        }),
      execute: () => {
        void open_bookmark(bookmark.url, new_tab);
      },
    })),
  });
}

/**
 * Glide has no prompt API, so the commandline stands in for one: a single
 * always-matching row, prefilled with the page title, whose execute() reads
 * whatever ended up in the input.
 */
async function bookmark_current_tab(): Promise<void> {
  const tab = await glide.tabs.active();
  const url = tab.url;
  if (!url) return;

  glide.commandline.show({
    title: "bookmark name",
    input: tab.title || url,
    options: [
      {
        label: "save bookmark",
        description: url,
        matches: () => true,
        execute({ input }) {
          void browser.bookmarks.create({ title: input.trim() || url, url });
        },
      },
    ],
  });
}

glide.keymaps.set("normal", "m", () => bookmark_current_tab(), {
  description: "Book[m]ark the current tab",
});

glide.keymaps.set("normal", "b", () => show_bookmark_picker(false), {
  description: "Open a [b]ookmark in the current tab",
});

glide.keymaps.set("normal", "B", () => show_bookmark_picker(true), {
  description: "Open a [B]ookmark in a new tab",
});

// displaced motions
glide.keymaps.set("normal", "<leader>b", "motion b", {
  description: "Move back a word",
});

glide.keymaps.set("normal", "<leader>B", "motion B", {
  description: "Move back a WORD",
});
