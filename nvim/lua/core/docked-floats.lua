-- Hover and signature help, docked at the bottom of the screen.
--
-- Both go through `vim.lsp.util.open_floating_preview`, which anchors its
-- window to the cursor -- a popup sitting on top of the code you are reading.
-- Wrap that function and move the window it returns into a full-width pane
-- above the statusline, stacked on the completion menu when that is up
-- (`core.completion-menu` hands us the row to stop at).
--
-- The move happens inside the wrapper, before Neovim returns to the event
-- loop, so no frame is ever drawn with the window at the cursor.
--
-- Everything else the function does is left alone: the markdown conversion and
-- Treesitter highlighting, `q` to close, the close-on-move autocmds, and the
-- focus behaviour that lets a second `K` step into the pane to scroll it.
--
-- Diagnostic floats are deliberately not docked -- `[d`/`]d` open them at the
-- cursor, where the spatial link to the offending line is the point. They are
-- told apart by `focus_id`: hover and signature help set it to the LSP method,
-- while `vim.diagnostic` sets it to the float's scope. Add "cursor"/"line" to
-- `DOCKED` below to dock those too.

local menu = require("core.completion-menu")

local MAX_HEIGHT = 20
-- Above the completion menu's own doc pane (150), below the item list (200).
local ZINDEX = 160
local TOP_RULE = { "", "─", "", "", "", "", "", "" }

local DOCKED = {
	["textDocument/hover"] = true,
	["textDocument/signatureHelp"] = true,
}

---@param win integer window returned by `open_floating_preview`
local function dock(win)
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end

	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	-- Commit the width before measuring: it is what decides how the text wraps.
	-- No `relative` here, so this is a resize of the window where it stands.
	vim.api.nvim_win_set_config(win, { width = vim.o.columns })

	local top = menu.dock_top()
	local cap = math.min(MAX_HEIGHT, math.floor(vim.o.lines / 2))
	local height = math.min(vim.api.nvim_win_text_height(win).all, cap)
	height = math.max(1, math.min(height, top - 1))

	vim.api.nvim_win_set_config(win, {
		relative = "editor",
		row = top - height,
		col = 0,
		width = vim.o.columns,
		height = height,
		border = TOP_RULE,
		zindex = ZINDEX,
	})
end

local open_floating_preview = vim.lsp.util.open_floating_preview

---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
	if not (opts and DOCKED[opts.focus_id]) then
		return open_floating_preview(contents, syntax, opts)
	end

	opts = vim.tbl_extend("force", opts, {
		border = TOP_RULE,
		max_width = vim.o.columns,
		max_height = MAX_HEIGHT,
	})

	local buf, win = open_floating_preview(contents, syntax, opts)
	-- Best effort: a mistake in here must not swallow the hover itself.
	pcall(dock, win)
	return buf, win
end
