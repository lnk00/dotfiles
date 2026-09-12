-- which-key.nvim -- shows pending keybinds after a prefix.
--
-- The `spec` below only names the groups; the mappings themselves live in
-- lua/core/keymaps.lua and in each plugin's own file.
vim.pack.add({ "https://github.com/folke/which-key.nvim" })
require("which-key").setup({
	-- Delay between pressing a key and opening which-key (milliseconds)
	delay = 0,
	icons = { mappings = vim.g.have_nerd_font },
	-- Document existing key chains
	spec = {
		{ "<leader>s", group = "[S]earch", mode = { "n", "v" } },
		{ "<leader>t", group = "[T]oggle" },
		{ "<leader>b", group = "[B]uffer" },
		{ "<leader>g", group = "[G]it" },
		{ "<leader>h", group = "Git [H]unk", mode = { "n", "v" } }, -- Enable gitsigns recommended keymaps first
		{ "gr", group = "LSP Actions", mode = { "n" } },
		{ "gs", group = "[S]urround", mode = { "n", "x" } },
	},
})
