-- Bottom-docked completion menu.
--
-- Neovim's own popup menu is anchored to the cursor and there is no option to
-- move it; `ext_popupmenu` is the supported way out. It hands the *rendering*
-- of `popupmenu-completion` (and the cmdline 'wildmenu') to us as UI events,
-- so the built-in popup is never drawn and we paint the item list into a
-- full-width float pinned above the statusline instead.
--
-- Selection, filtering and insertion are untouched: the real completion is
-- still driven by `ins-completion` (<c-n>/<c-p>/<c-y>/<c-e>), only the
-- drawing changes. See `:help vim.ui_attach()` and `:help ui-popupmenu`.
--
-- Trade-offs, since we now own the drawing:
--  * "popup" in 'completeopt' has no effect -- Neovim delivers the item's
--    documentation to us (as `info`) rather than opening its own window. The
--    first line is shown in the right-hand column.
--  * 'pumblend', 'pumwidth', 'pummaxwidth' and 'pumborder' no longer apply.
--    'pumheight' still does; it caps this window's height.
--  * `vim.ui_attach` is flagged experimental upstream. If a Neovim update
--    breaks it, deleting this file (and its `require` in init.lua) restores
--    the stock cursor-anchored popup.

local ns = vim.api.nvim_create_namespace("bottom-completion-menu")

-- The cmdline 'wildmenu' also travels over ext_popupmenu. Keep it on the
-- classic one-line-at-the-bottom wildmenu rather than routing it through this
-- window, so completing a `:` command does not resize a float under the
-- prompt.
vim.opt.wildoptions:remove("pum")

local DEFAULT_HEIGHT = 10
local MAX_WORD_WIDTH = 40

local state = { items = {}, selected = -1 }
local buf, win

local function scratch_buf()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "completionmenu"
	return buf
end

local function close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	win = nil
end

-- Every `complete-items` field is free-form server text: LSP `detail` and
-- `documentation` routinely carry newlines (and the odd carriage return or
-- tab), and `nvim_buf_set_lines` rejects those outright. Flatten to a single
-- line before anything reaches the buffer.
local function oneline(text)
	if not text or text == "" then
		return ""
	end
	local flat = tostring(text):gsub("[\r\n\t]", " "):gsub("%s%s+", " ")
	return (vim.trim(flat))
end

-- One text column per `complete-items` field, padded so the kinds line up.
local function format(items)
	local words = {}
	local word_width = 0
	for i, item in ipairs(items) do
		words[i] = oneline(item[1])
		word_width = math.max(word_width, vim.fn.strdisplaywidth(words[i]))
	end
	word_width = math.min(word_width, MAX_WORD_WIDTH)

	local lines = {}
	for i, item in ipairs(items) do
		local word = words[i]
		local kind = oneline(item[2])
		-- `menu` is the LSP detail (a type signature, an import path); `info`
		-- is the documentation. Only a one-line summary of either fits here.
		local extra = oneline(item[3])
		if extra == "" then
			extra = oneline(vim.split(item[4] or "", "\n", { plain = true })[1])
		end
		lines[i] = table.concat({
			" ",
			word,
			string.rep(" ", math.max(1, word_width - vim.fn.strdisplaywidth(word) + 1)),
			kind ~= "" and (kind .. "  ") or "",
			extra,
		})
	end
	return lines
end

local function render()
	local items = state.items
	if #items == 0 then
		close()
		return
	end

	local lines = format(items)
	local bufnr = scratch_buf()
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false

	local cap = vim.o.pumheight > 0 and vim.o.pumheight or DEFAULT_HEIGHT
	local height = math.min(#lines, cap)
	-- Row 0 of the editor grid is the top line; the statusline and the cmdline
	-- sit at the bottom, so back off past both.
	local row = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - height
	if row < 0 then
		close()
		return
	end

	local config = {
		relative = "editor",
		row = row,
		col = 0,
		width = vim.o.columns,
		height = height,
		style = "minimal",
		-- A rule along the top only: the statusline already closes it below.
		border = { "", "─", "", "", "", "", "", "" },
		focusable = false,
		noautocmd = true,
		zindex = 200,
	}

	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_config(win, config)
	else
		win = vim.api.nvim_open_win(bufnr, false, config)
		vim.wo[win].winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel"
		vim.wo[win].wrap = false
	end

	-- Selection is drawn with 'cursorline' so a list longer than the window
	-- scrolls the selected item into view for free.
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	if state.selected >= 0 and state.selected < #lines then
		vim.wo[win].cursorline = true
		vim.api.nvim_win_set_cursor(win, { state.selected + 1, 0 })
	else
		vim.wo[win].cursorline = false
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end
end

-- UI events can arrive in a fast context, where the API is off limits, and
-- several land per keystroke. Coalesce them into one scheduled redraw.
local pending = false
local function schedule_render()
	if pending then
		return
	end
	pending = true
	vim.schedule(function()
		pending = false
		render()
		vim.cmd.redraw()
	end)
end

vim.ui_attach(ns, { ext_popupmenu = true }, function(event, ...)
	if event == "popupmenu_show" then
		local items, selected = ...
		state.items, state.selected = items, selected
		schedule_render()
	elseif event == "popupmenu_select" then
		state.selected = ...
		schedule_render()
	elseif event == "popupmenu_hide" then
		state.items, state.selected = {}, -1
		schedule_render()
	end
end)

-- Belt and braces: a mode change that skips popupmenu_hide (an interrupted
-- insert, a plugin closing completion by hand) must not leave the float up.
vim.api.nvim_create_autocmd({ "InsertLeave", "CompleteDone" }, {
	group = vim.api.nvim_create_augroup("bottom-completion-menu", { clear = true }),
	callback = function()
		state.items, state.selected = {}, -1
		schedule_render()
	end,
})
