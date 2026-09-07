-- mini.nvim -- a collection of small independent modules, installed as one
-- plugin. Only the modules set up below are active.
--
-- Loaded before snacks/oil/neogit: `mock_nvim_web_devicons` has to run before
-- anything that draws devicons.
vim.pack.add({ "https://github.com/nvim-mini/mini.nvim" })

-- If a nerd font is available, load the icons module for pretty icons in various plugins.
if vim.g.have_nerd_font then
	require("mini.icons").setup()
	-- Used for backwards compatibility with plugins that require `nvim-web-devicons`
	MiniIcons.mock_nvim_web_devicons()
end

-- [[ mini.ai ]] Better Around/Inside textobjects
--
-- Examples:
--  - va)  - [V]isually select [A]round [)]paren
--  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
--  - ci'  - [C]hange [I]nside [']quote
require("mini.ai").setup({
	-- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
	mappings = {
		around_next = "aa",
		inside_next = "ii",
	},
	n_lines = 500,
})

-- [[ mini.surround ]] Add/delete/replace surroundings (brackets, quotes, etc.)
--
-- NOTE: these live under the `gs` prefix, not the upstream `s`, because
-- flash.nvim claims bare `s` for jumping. Sharing `s` would make
-- every flash jump wait `timeoutlen` to see if `sa`/`sd`/`sr` follows.
-- This is the same split LazyVim uses.
--
-- - gsaiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
-- - gsd'   - [S]urround [D]elete [']quotes
-- - gsr)'  - [S]urround [R]eplace [)] [']
require("mini.surround").setup({
	mappings = {
		add = "gsa",
		delete = "gsd",
		find = "gsf",
		find_left = "gsF",
		highlight = "gsh",
		replace = "gsr",
		update_n_lines = "gsn",
	},
})

-- [[ mini.statusline ]]
local statusline = require("mini.statusline")
statusline.setup({ use_icons = vim.g.have_nerd_font })

-- Show the cursor position as LINE:COLUMN.
---@diagnostic disable-next-line: duplicate-set-field
statusline.section_location = function()
	return "%2l:%-2v"
end

-- [[ mini.bufremove ]] no setup needed, just the map.
--
-- Close the current buffer without tearing down the window layout.
-- mini.bufremove keeps the split alive and swaps in the alternate buffer,
-- unlike a plain `:bdelete` which closes the window along with the buffer.
vim.keymap.set("n", "<leader>bc", function()
	require("mini.bufremove").delete(0, false)
end, { desc = "[B]uffer [C]lose" })

-- [[ mini.pairs ]] Autoclose brackets and quotes
--
-- Insert the closing half as you type the opening one, step over the closer
-- when you type it yourself, and delete both halves with a single <BS>.
--
-- Defaults, worth knowing:
--  * Quotes (`"`, `'`, `` ` ``) are "closeopen": the same key opens and steps
--    over, so typing `'` right after `''` lands past the pair rather than
--    nesting a third quote.
--  * Nothing pairs after a backslash, so `\(` in a regex stays `\(`, and `'`
--    does not pair after a letter, so `don't` and Rust lifetimes (`&'a`) are
--    typed as written.
--  * <BS> only eats both halves when the cursor sits *between* them; a lone
--    closer is deleted on its own.
--
-- Set `vim.b.minipairs_disable = true` to switch it off for one buffer;
-- `vim.g.minipairs_disable` for the session. mini.pairs already does that for
-- the Telescope and fzf prompts.
require("mini.pairs").setup()

-- Prompt buffers: a picker query is a search pattern, not code, so a typed
-- `(` should stay a lone `(`. snacks and neogit both prompt in a real buffer,
-- which is where mini.pairs would otherwise pair.
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "snacks_picker_input", "snacks_input", "NeogitCommitMessage" },
	callback = function()
		vim.b.minipairs_disable = true
	end,
	desc = "mini.pairs: off in prompt buffers",
})
