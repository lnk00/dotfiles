-- project.nvim -- sets the cwd to the root of the project the current buffer
--  belongs to (LSP root first, `patterns` as a fallback), and keeps a
--  history of every project visited so they can be jumped back into.
--
-- `:Project` opens an interactive menu, `:checkhealth project` explains
--  what the detection did. See `:help project.txt`.
--
-- Loaded after snacks on purpose: the extension below checks for
--  snacks.nvim at setup time, so it has to already be on the runtimepath.
vim.pack.add({ "https://github.com/DrKJeff16/project.nvim" })
require("project").setup({
	snacks = {
		-- Registers project.nvim's own snacks source, reachable as
		--  `:Project snacks` or `project.extensions.snacks.pick()`
		--  (bound to `<leader>sp` below). It reads the same project
		--  history the telescope extension read.
		enabled = true,
		-- Show `~/dev/foo` instead of `/home/lnk0/dev/foo` in the picker.
		tilde = true,
		opts = {
			-- Match every other picker, instead of the centred `select`
			--  dropdown this extension defaults to.
			layout = "ivy",
		},
	},
})

-- In the projects picker: `<CR>` chdir then find files, `<C-w>` change cwd
--  only, `<C-r>` rename, `<C-d>` forget. See `:help project.txt`.
vim.keymap.set("n", "<leader>sp", function()
	require("project.extensions.snacks").pick()
end, { desc = "[S]earch [P]rojects" })
