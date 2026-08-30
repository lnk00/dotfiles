/**
 * qutebrowser-style tab lifecycle.
 *
 *   d          close the current tab, or blank it if it's the last one
 *   u          reopen the last closed tab
 *   J / K      next / previous tab
 *
 * Both keys are taken from Glide's vim text editing, which qutebrowser
 * doesn't have. Their original behaviour moves behind <leader> (<Space>):
 *
 *   <leader>d  the `d` delete operator (<leader>dw, <leader>diw, …)
 *   <leader>u  undo the most recent text edit
 *
 * Untouched: `c` is still the change operator, and visual-mode `d` still
 * deletes the selection.
 */

/**
 * Closing the only tab in a window would take the window (and, with one
 * window open, Glide) down with it. Blank that tab instead.
 *
 * newtab_url is read at keypress time so it tracks prefs.glide.ts.
 */
async function close_or_blank_tab(): Promise<void> {
  const tabs = await glide.tabs.query({ currentWindow: true });

  if (tabs.length > 1) {
    await glide.excmds.execute("tab_close");
    return;
  }

  const tab = await glide.tabs.active();
  await browser.tabs.update(tab.id, { url: glide.o.newtab_url });
}

glide.keymaps.set("normal", "d", () => close_or_blank_tab(), {
  description: "Close the current tab, or blank it if it's the last one",
});

glide.keymaps.set("normal", "u", "tab_reopen", {
  description: "Reopen the last closed tab",
});

// Glide binds <C-j> / <C-k> to these by default; J / K replace them.
glide.keymaps.del(["normal", "insert"], "<C-j>");
glide.keymaps.del(["normal", "insert"], "<C-k>");

// Both wrap around.
glide.keymaps.set("normal", "J", "tab_next", {
  description: "Switch to the next tab",
});

glide.keymaps.set("normal", "K", "tab_prev", {
  description: "Switch to the previous tab",
});

// `<leader>d` was tab_close, which `d` now covers.
glide.keymaps.set("normal", "<leader>d", "mode_change op-pending --operator=d", {
  retain_key_display: true,
  description: "Delete operator",
});

glide.keymaps.set("normal", "<leader>u", "undo", {
  description: "Undo the most recent edit",
});
