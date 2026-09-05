-- Neogit + diffview -- a full git interface in a buffer: stage hunks, write
--  commits, rebase, push, browse logs. `<leader>gg` opens the status view,
--  which is the entry point for everything else -- press `?` inside it for the map.
--
-- Loaded after snacks on purpose: Neogit picks its pickers at setup time, so
--  snacks.nvim has to already be on the runtimepath.
--
-- plenary.nvim is a hard dependency, and no longer comes in with anything
--  else now that telescope is gone, so it is listed explicitly below.
vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/sindrets/diffview.nvim",
	"https://github.com/NeogitOrg/neogit",
})

-- Neogit opens diffs through diffview, but diffview does not bind `q` to
--  anything outside of its option/help popups. Bind it in the diff view and
--  both file panels so leaving a diff feels like leaving Neogit's status
--  buffer: one `q` and the whole tabpage is gone.
local diffview_quit = { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } }
require("diffview").setup({
	keymaps = {
		view = { diffview_quit },
		file_panel = { diffview_quit },
		file_history_panel = { diffview_quit },
	},
})

require("neogit").setup({
	graph_style = "unicode",
	integrations = {
		snacks = true,
		diffview = true,
	},
})

vim.keymap.set("n", "<leader>gg", function()
	require("neogit").open()
end, { desc = "[G]it status (Neo[g]it)" })
