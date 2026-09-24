-- Keep the cursor line in the middle of the window, even at the end of the
-- buffer. 'scrolloff' (in core.options) centers everywhere else, but it will not
-- scroll past the last line, so `zz` covers that part.

local function center()
	if vim.bo.buftype ~= "" then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	-- Only re-center on line changes, so horizontal motions leave a manual
	-- `zt`/`zb` alone.
	if vim.w.centered_line == cursor[1] then
		return
	end
	vim.w.centered_line = cursor[1]
	vim.cmd("normal! zz")
	-- `:normal` clamps the column to the last character, which would pull an
	-- insert-mode cursor back from the end of the line.
	vim.api.nvim_win_set_cursor(0, cursor)
end

local group = vim.api.nvim_create_augroup("centered-cursor", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	group = group,
	callback = center,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "VimResized" }, {
	group = group,
	callback = function()
		vim.w.centered_line = nil
		center()
	end,
})
