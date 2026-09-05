-- Editor autocommands. Plugin-driven ones live with their plugin.

-- Highlight when yanking (copying) text. Try it with `yap` in normal mode.
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	---@diagnostic disable-next-line: deprecated
	callback = function()
		vim.hl.hl_op()
	end,
})
