-- Editor keymaps: the ones that need no plugin loaded.
--
-- Plugin keymaps live next to their plugin in lua/plugins/, so removing a
-- plugin file takes its mappings with it. Required last from init.lua, so
-- anything here wins a collision with a plugin's own map.
--
-- See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- [[ Multicursors ]]

-- Clear multicursors. The stock <C-l> default mapping does this (see
-- `:help CTRL-L-default`), but the window-navigation map above shadows it,
-- so rebind the multicursor part to <C-,>. Requires a terminal that sends
-- distinct keycodes for <C-,> (kitty keyboard protocol, e.g. ghostty).
vim.keymap.set({ "n", "i" }, "<C-,>", function()
	vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("nvim.multicursor"), 0, -1)
end, { desc = "Clear multicursors" })

-- Drop a multicursor on every match of a pattern inside the visual selection.
-- `\%V` restricts the search to the last visual area (`:help /\%V`) and `1Q`
-- places a cursor at every match of the last search pattern (`:help Q`).
--
-- This leaves visual mode and opens the real `/` cmdline prefilled with `\%V`
-- (so incremental highlighting, history and `<C-r><C-w>` all still work), then
-- places the cursors once the search is accepted. Leaving visual mode first is
-- required: `/` while visual is active extends the selection instead of
-- searching. Charwise/linewise both work, and `<C-v>` restricts by column too.
--
-- Clear the cursors with <C-,>, restore them with `gQ`.
--
-- NOTE: several cursors on one line lose edits when the edit shifts columns
-- (`:help mcursor-limitations`); use `:'<,'>s/\%Vpat//g` for that case.
vim.keymap.set("x", "<leader>m", function()
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		once = true,
		callback = function()
			-- Skip when the search was cancelled, or left empty (`\%V` alone).
			if vim.v.event.abort or vim.fn.getcmdline() == [[\%V]] then
				return
			end
			-- The search itself only runs after the cmdline closes, so `1Q` has to
			-- be queued rather than called here. The "i" flag puts it at the head
			-- of the typeahead, ahead of anything typed right after <CR>.
			vim.api.nvim_feedkeys("1Q", "ni", false)
		end,
	})
	return [[<Esc>/\%V]]
end, { expr = true, desc = "[M]ulticursor at matches in selection" })

-- [[ Completion Keymaps ]]
-- <Tab>/<S-Tab> cycle the popup menu and <CR> accepts the selected item.
--
-- These are global rather than buffer-local so they behave identically for
-- every popup menu, not just LSP completion (e.g. <c-x><c-f> for filenames).
--
-- Each one falls through in priority order so no key is ever stolen:
--   1. popup menu visible  -> cycle / accept
--   2. snippet placeholder -> jump. This is Neovim's default <Tab> binding
--      and must be preserved, because accepting an LSP item can expand a
--      snippet. See `:help vim.snippet.jump()`
--   3. otherwise           -> the key's normal meaning
local function complete_key(pum_key, direction, fallback)
	return function()
		if vim.fn.pumvisible() == 1 then
			return pum_key
		end
		if vim.snippet.active({ direction = direction }) then
			return string.format("<Cmd>lua vim.snippet.jump(%d)<CR>", direction)
		end
		return fallback
	end
end

-- NOTE: Mapped for select mode too, since snippet placeholders are selected.
vim.keymap.set({ "i", "s" }, "<Tab>", complete_key("<C-n>", 1, "<Tab>"), {
	expr = true,
	silent = true,
	desc = "Completion: next item, else snippet jump, else Tab",
})

vim.keymap.set({ "i", "s" }, "<S-Tab>", complete_key("<C-p>", -1, "<S-Tab>"), {
	expr = true,
	silent = true,
	desc = "Completion: previous item, else snippet jump, else S-Tab",
})

-- Accept only when an item is actually selected. 'completeopt' has "noselect",
-- so an untouched menu leaves <CR> as a plain newline -- meaning <CR> never
-- swallows your line break just because the menu happens to be open.
--  TIP: To make <CR> accept the top item without pressing <Tab> first, swap
--  "noselect" for "noinsert" in 'completeopt' (lua/core/options.lua).
vim.keymap.set("i", "<CR>", function()
	if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
		return "<C-y>"
	end
	return "<CR>"
end, {
	expr = true,
	silent = true,
	desc = "Completion: accept selected item, else newline",
})
