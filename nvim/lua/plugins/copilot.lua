-- copilot.lua -- GitHub Copilot as inline ghost text, drawn with virtual text
-- rather than in the completion menu. The pure-Lua replacement for
-- github/copilot.vim; talks to the native Copilot language server, which it
-- downloads on first use into `stdpath("data")/copilot.lua/lsp` (~100 MB).
-- Set `server = { type = "nodejs" }` below to run the Node build instead.
--
-- First run: `:Copilot auth` to sign in, `:Copilot status` to check it after.
--
-- Suggestions live *beside* the completion menu, not inside it: the ghost text
-- is hidden whenever `popupmenu-completion` is up (`hide_during_completion`,
-- on by default), so it never competes with the docked menu in
-- lua/core/completion-menu.lua. That also means <Tab> and <CR> keep their
-- meaning from lua/core/keymaps.lua and only ever drive the menu; the
-- suggestion is accepted with <M-l>.
--
-- Insert-mode maps, all buffer-local and only while Copilot is attached:
--   <M-l>   accept the whole suggestion
--   <M-w>   accept one word of it
--   <M-j>   accept one line of it
--   <M-]>   next suggestion            <M-[>  previous suggestion
--   <C-]>   dismiss                    <M-\>  toggle auto-trigger (this buffer)
--   <M-CR>  open the suggestion panel (also `:Copilot panel`)
--
-- Copilot stays off in yaml, markdown, help and the commit filetypes by
-- default; add `filetypes = { markdown = true }` to setup() to change that.
vim.pack.add({ "https://github.com/zbirenbaum/copilot.lua" })

require("copilot").setup({
	suggestion = {
		-- Suggest as you type, rather than only when <M-l>/<M-]> is pressed.
		auto_trigger = true,
		keymap = {
			-- Partial accepts are off upstream; both are worth having when the
			-- suggestion is right for a word or a line and wrong after that.
			accept_word = "<M-w>",
			accept_line = "<M-j>",
			toggle_auto_trigger = "<M-\\>",
		},
	},
})

-- Ghost text is `CopilotSuggestion`, which the plugin links to `Comment` when
-- the colorscheme leaves it undefined -- as the generated eink theme does. So
-- suggestions come out in the theme's muted italic, and nothing to set here.

-- The same toggle as <M-\>, from normal mode and under the <leader>t group.
vim.keymap.set("n", "<leader>tc", function()
	require("copilot.suggestion").toggle_auto_trigger()
	local on = vim.b.copilot_suggestion_auto_trigger
	vim.notify("Copilot auto-trigger " .. (on and "on" or "off") .. " (buffer)")
end, { desc = "[T]oggle [C]opilot auto-trigger" })
