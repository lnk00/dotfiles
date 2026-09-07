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
			-- `autotrigger` only fires on the server's own `triggerCharacters` (`.`,
			-- `:`, ...), so typing a bare identifier shows nothing. Enable it for those,
			-- then add word characters ourselves below.
			vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })

			-- Word-character autotrigger.
			--
			-- NOTE: do *not* do this by appending letters to
			--  `client.server_capabilities.completionProvider.triggerCharacters`, the
			--  approach `:help lsp-autocompletion` suggests. Neovim then sends
			--  `triggerKind = TriggerCharacter` with that letter, and any server backed
			--  by tsserver (svelte, ts_ls) hands it to
			--  `getCompletionsAtPosition`, which validates it against TypeScript's own
			--  set (`.`, `"`, `'`, `` ` ``, `/`, `@`, `<`, `#`) and returns *nothing* for
			--  anything else. Result: completion only after `.`. lua_ls and gopls ignore
			--  the field, which is why it looks like it works.
			--
			-- `vim.lsp.completion.get()` sends `triggerKind = Invoked` instead, which
			-- every server answers. It also fetches the whole list at the word boundary
			-- once and lets Neovim filter it as you keep typing ('completeopt' has
			-- "fuzzy"), rather than a round-trip per keypress.
			local triggers = vim.tbl_get(client.server_capabilities, "completionProvider", "triggerCharacters") or {}
			local timer

			vim.api.nvim_create_autocmd("InsertCharPre", {
				-- One autotrigger per buffer, not one per client: a second LspAttach on
				-- the same buffer clears this group and re-registers. `get()` requests
				-- from every enabled client anyway.
				group = vim.api.nvim_create_augroup("lsp-word-autotrigger-" .. event.buf, { clear = true }),
				buffer = event.buf,
				desc = "Trigger LSP completion on word characters",
				callback = function()
					local char = vim.v.char
					-- Leave the server's own triggers to `autotrigger`, and don't fight the
					-- menu once it is up -- Neovim filters it from here.
					if not char:match("[%w_]") or vim.list_contains(triggers, char) or vim.fn.pumvisible() ~= 0 then
						return
					end
					if timer then
						timer:stop()
						if not timer:is_closing() then
							timer:close()
						end
					end
					-- InsertCharPre runs *before* the character lands in the buffer; the
					-- delay lets it (and any further keystrokes) get there first, so the
					-- request carries the real prefix. Mirrors Neovim's own 25ms.
					timer = assert(vim.uv.new_timer())
					timer:start(
						25,
						0,
						vim.schedule_wrap(function()
							if vim.api.nvim_get_current_buf() == event.buf and vim.fn.mode():find("i") then
								vim.lsp.completion.get()
							end
						end)
					)
				end,
			})

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
