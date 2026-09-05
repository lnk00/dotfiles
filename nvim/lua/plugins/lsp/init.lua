-- LSP: the per-buffer setup that runs on `LspAttach`, plus enabling the
-- servers from servers.lua.
--
-- Servers are listed in lua/plugins/lsp/servers.lua and installed by
-- lua/plugins/lsp/mason.lua. Picker-backed mappings (grr, grd, gri, gO, gW,
-- grt) live in lua/plugins/snacks.lua under their own LspAttach autocmd.

vim.pack.add({ "https://github.com/neovim/nvim-lspconfig" })

--  This function gets run when an LSP attaches to a particular buffer.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		-- Rename the variable under your cursor.
		--  Most Language Servers support renaming across files, etc.
		map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

		-- Execute a code action, usually your cursor needs to be on top of an error
		-- or a suggestion from your LSP for this to activate.
		map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

		-- WARN: This is not Goto Definition, this is Goto Declaration.
		--  For example, in C this would take you to the header.
		map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

		-- Highlight references of the word under the cursor when it rests there
		-- for a little while, and clear them when it moves.
		--    See `:help CursorHold`
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client:supports_method("textDocument/documentHighlight", event.buf) then
			local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
				end,
			})
		end

		-- [[ Autocompletion ]]
		-- Neovim has a built-in LSP completion engine, so no plugin is needed.
		--  See `:help lsp-completion` and `:help lsp-autocompletion`
		--
		-- Usage (all standard `ins-completion` mappings, `:help ins-completion`):
		--  <c-n>/<c-p> - select next/previous item
		--  <c-y>       - accept the selected item. This applies LSP side effects
		--                like snippet expansion and auto-import text edits.
		--                NOTE: 'completeopt' has "noselect", so nothing is
		--                preselected -- press <c-n> first, then <c-y>.
		--  <c-e>       - cancel completion and restore what you typed
		--  <c-space>   - trigger completion manually (mapped below)
		--
		-- The <Tab>/<S-Tab>/<CR> mappings are global; see lua/core/keymaps.lua.
		if client and client:supports_method("textDocument/completion", event.buf) then
			-- By default `autotrigger` only fires on the server's `triggerCharacters`
			-- (e.g. `.` and `:`), so typing a bare identifier shows nothing. Extend the
			-- trigger set with word characters to get a menu on every keypress of a word.
			--
			-- NOTE: This must happen *before* `vim.lsp.completion.enable`.
			--  Only word characters are added here -- servers advertise their own
			--  triggers on top (lua_ls, for instance, already includes space and
			--  tab). Drop this block if you'd rather only complete after `.` and
			--  the server's own triggers, or if a chatty server feels slow.
			local provider = client.server_capabilities.completionProvider
			if provider then
				local triggers = provider.triggerCharacters or {}
				for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):gmatch(".") do
					table.insert(triggers, char)
				end
				provider.triggerCharacters = triggers
			end

			vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })

			-- Trigger completion on demand, for when autotrigger hasn't fired.
			map("<C-Space>", function()
				vim.lsp.completion.get()
			end, "Trigger Completion", "i")
		end

		-- Show a signature help window while typing function arguments.
		--  NOTE: This shadows insert-mode <c-k> (digraphs, `:help i_CTRL-K`).
		--  Remove the map if you use digraphs.
		if client and client:supports_method("textDocument/signatureHelp", event.buf) then
			map("<C-k>", vim.lsp.buf.signature_help, "Signature Help", "i")
		end

		-- Toggle inlay hints, if the language server supports them.
		-- This may be unwanted, since they displace some of your code.
		if client and client:supports_method("textDocument/inlayHint", event.buf) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
			end, "[T]oggle Inlay [H]ints")
		end
	end,
})

require("plugins.lsp.mason")

for name, server in pairs(require("plugins.lsp.servers")) do
	vim.lsp.config(name, server)
	vim.lsp.enable(name)
end
