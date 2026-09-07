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
-- The documentation window ("popup" in 'completeopt') stays Neovim's: it owns
-- the lazy `completionItem/resolve` round-trip, the markdown Treesitter
-- highlighting and the fit-to-content sizing, and none of that is worth
-- reimplementing. We only move it, into a second pane stacked above the item
-- list -- see `anchor_doc`.
--
-- Trade-offs, since we now own the drawing:
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
local MAX_DOC_HEIGHT = 12

-- The list draws over the doc pane, so a pane Neovim has resized taller than
-- our cap is hidden behind it rather than spilling across the statusline.
local LIST_ZINDEX = 200
local DOC_ZINDEX = 150

-- A rule along the top edge only. Each pane is closed off below by whatever
-- sits under it -- the next pane, or the statusline.
local TOP_RULE = { "", "─", "", "", "", "", "", "" }

local state = { items = {}, selected = -1 }
local buf, win
local list_top --- first text row of the list window; where the doc pane stops

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
	list_top = nil
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
		-- `menu` is the LSP detail: a type signature, an import path. The
		-- documentation (`info`) is not repeated here; it gets the pane above,
		-- in full.
		local extra = oneline(item[3])
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

-- Neovim opens the documentation window itself, sized to its content and
-- anchored beside the cursor -- which, with the item list now at the bottom of
-- the screen, leaves the docs floating over the code being edited.
-- `complete_info()` hands us its window id, so move it into a pane directly
-- above the list.
--
-- Nothing announces that window. It is opened by `nvim__complete_set` from
-- inside `vim.lsp.completion`'s debounced `completionItem/resolve` callback,
-- long after the popupmenu events that drive everything else here, and with no
-- autocmd of its own -- not `WinNew`, and not `WinResized`/`WinScrolled`, which
-- floats never fire. Hence the poll below.
--
---@param list_top integer first *text* row of the item list; its rule sits above
---@param doc_win? integer the window, when the caller already has it
---@return boolean changed whether the window had to be moved
local function anchor_doc(list_top, doc_win)
	-- Neovim only fills "preview_winid" in when "selected" is asked for too --
	-- see `:help complete_info()`, and how `vim.lsp.completion` reads it back.
	doc_win = doc_win or vim.fn.complete_info({ "selected", "preview_winid" }).preview_winid
	if not doc_win or doc_win <= 0 or not vim.api.nvim_win_is_valid(doc_win) then
		return false
	end

	-- Full width like the list, so a wrapped signature gets the whole line. The
	-- width has to be committed before the height can be measured: it is what
	-- decides how the text wraps.
	local cfg = vim.api.nvim_win_get_config(doc_win)
	if cfg.width ~= vim.o.columns then
		vim.api.nvim_win_set_config(doc_win, { width = vim.o.columns })
		cfg = vim.api.nvim_win_get_config(doc_win)
	end

	-- Sit clear of the list's own rule, and keep this pane's rule on screen.
	local top = list_top - 1
	local height = math.min(vim.api.nvim_win_text_height(doc_win).all, MAX_DOC_HEIGHT)
	height = math.max(1, math.min(height, top - 1))
	local row = top - height

	if cfg.relative == "editor" and cfg.row == row and cfg.col == 0 and cfg.height == height then
		return false
	end

	vim.wo[doc_win].wrap = true
	vim.wo[doc_win].linebreak = true
	vim.api.nvim_win_set_config(doc_win, {
		relative = "editor",
		row = row,
		col = 0,
		width = vim.o.columns,
		height = height,
		border = TOP_RULE,
		zindex = DOC_ZINDEX,
	})
	return true
end

-- The poll. Runs only while a completion menu is up, and does nothing beyond a
-- config read once the pane is where we want it.
local watch
local function stop_watch()
	if watch then
		watch:stop()
		if not watch:is_closing() then
			watch:close()
		end
		watch = nil
	end
end

local function start_watch()
	if watch then
		return
	end
	watch = vim.uv.new_timer()
	watch:start(
		50,
		50,
		vim.schedule_wrap(function()
			if not list_top or not (win and vim.api.nvim_win_is_valid(win)) then
				return stop_watch()
			end
			if anchor_doc(list_top) then
				vim.cmd.redraw()
			end
		end)
	)
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
	list_top = row

	local config = {
		relative = "editor",
		row = row,
		col = 0,
		width = vim.o.columns,
		height = height,
		style = "minimal",
		border = TOP_RULE,
		focusable = false,
		noautocmd = true,
		zindex = LIST_ZINDEX,
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

	anchor_doc(row)
	start_watch()
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
local group = vim.api.nvim_create_augroup("bottom-completion-menu", { clear = true })

vim.api.nvim_create_autocmd({ "InsertLeave", "CompleteDone" }, {
	group = group,
	callback = function()
		state.items, state.selected = {}, -1
		schedule_render()
	end,
})

-- Markdown highlighting for the doc pane, which Neovim would otherwise apply
-- itself. Mirrors `update_popup_window` in `vim/lsp/completion.lua`; we do it
-- here because the interception below hides the window from that function.
local function highlight_doc(doc_buf, doc_win)
	local info = vim.fn.complete_info({ "selected", "items" })
	local item = info.items and info.items[info.selected + 1]
	if not item or vim.tbl_get(item, "user_data", "nvim", "lsp", "info_kind") ~= "markdown" then
		return
	end
	vim.wo[doc_win].conceallevel = 2
	pcall(vim.treesitter.start, doc_buf, "markdown")
end

-- Placing the pane without a visible flash.
--
-- The poll above cannot help with the *first* frame: it necessarily runs after
-- the window has been drawn beside the cursor, and under Neovide that first
-- position is then animated across the screen. So intercept the call that
-- creates the window -- `nvim__complete_set`, whose only caller in the runtime
-- is `vim/lsp/completion.lua` -- and place the pane inside it. That happens
-- before Neovim returns to the event loop, so no frame is ever flushed with
-- the window at its original position.
--
-- Dropping `winid` from the result is deliberate: `vim.lsp.completion` calls
-- `update_popup_window` with it the moment we return, which would resize the
-- pane to the full, uncapped content height and redo the highlighting we just
-- applied. With no `winid` that call is a no-op (it starts with a validity
-- check), and the poll stays as the fallback for everything else -- including
-- the case where a Neovim update changes this internal function out from under
-- us and the interception stops running.
local complete_set = vim.api.nvim__complete_set

---@diagnostic disable-next-line: duplicate-set-field
vim.api.nvim__complete_set = function(index, opts)
	local windata = complete_set(index, opts)
	if not (list_top and windata and windata.winid and vim.api.nvim_win_is_valid(windata.winid)) then
		return windata
	end

	-- Best effort: a mistake in here must not break the completion itself.
	pcall(anchor_doc, list_top, windata.winid)
	pcall(highlight_doc, windata.bufnr, windata.winid)
	return { bufnr = windata.bufnr }
end
