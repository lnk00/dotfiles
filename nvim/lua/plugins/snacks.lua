-- snacks.nvim -- the fuzzy finder, and the pickers built on it.
--
-- snacks.nvim is a monorepo of small independent modules. Only the ones
--  named in `setup()` are enabled, so this pulls in the picker and nothing
--  else. See https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
--
-- Must load before project.nvim and neogit: both resolve their picker at
--  setup time and need snacks already on the runtimepath.
--
-- To see everything it knows how to find, press `<leader>ss` (or run
--  `:lua Snacks.picker()`): that lists every source and opens the one you pick.
--
-- The important keymap to use *inside* a picker is `?`, in either the input
--  or the list window. It toggles a window listing every mapping for the
--  current picker.
vim.pack.add({ "https://github.com/folke/snacks.nvim" })

require("snacks").setup({
	picker = {
		-- A bottom pane with no previewer. `ivy` is snacks' bottom-pane
		--  preset; dropping the preview leaves the input row and the list,
		--  framed by a single rule line along the top.
		--
		--  A handful of sources pin their own layout on purpose
		--  (`select`, `icons`, `colorschemes`, ...) and still override this.
		layout = { preset = "ivy", preview = false },

		-- Route `vim.ui.select` through the picker, so code actions and
		--  every other `vim.ui.select` caller land here too. This is what
		--  telescope-ui-select.nvim used to do. It is already the default;
		--  spelled out because it is the reason that plugin is gone.
		ui_select = true,

		-- `<Tab>`/`<S-Tab>` walk the list, nothing more.
		--
		--  Out of the box they are `select_and_next`/`select_and_prev`,
		--  which toggle the row into a multi-selection *and* move -- so
		--  tabbing down five rows to reach a file leaves all five marked,
		--  and `<CR>` then opens every one of them. (Telescope bound
		--  `toggle_selection + move_selection_worse` the same way; it just
		--  never drew a mark, so the behaviour went unnoticed.)
		--
		--  The toggle keeps a home on `<C-Space>`, and `<C-a>` still
		--  selects everything. Sources that give `<Tab>` a job of their own
		--  -- `git_status` and `git_diff` stage with it -- still win here,
		--  because source config is merged over this.
		win = {
			input = {
				keys = {
					["<Tab>"] = { "list_down", mode = { "i", "n" } },
					["<S-Tab>"] = { "list_up", mode = { "i", "n" } },
					["<C-Space>"] = { "select_and_next", mode = { "i", "n" } },
				},
			},
			list = {
				keys = {
					["<Tab>"] = { "list_down", mode = { "n", "x" } },
					["<S-Tab>"] = { "list_up", mode = { "n", "x" } },
					["<C-Space>"] = { "select_and_next", mode = { "n", "x" } },
				},
			},
		},
	},
})

-- Keymap callbacks are wrapped so that indexing `Snacks.picker` -- and with
--  it loading the picker -- is deferred to the first time a map is pressed
--  rather than happening here at startup.
---@param source string
---@param opts? snacks.picker.Config
local function pick(source, opts)
	return function()
		Snacks.picker.pick(source, opts)
	end
end

vim.keymap.set("n", "<leader>sh", pick("help"), { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", pick("keymaps"), { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", pick("files"), { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", pick("pickers"), { desc = "[S]earch [S]elect Picker" })
vim.keymap.set({ "n", "v" }, "<leader>sw", pick("grep_word"), { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", pick("grep"), { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", pick("diagnostics"), { desc = "[S]earch [D]iagnostics" })
-- NOTE: not `pick("resume")` -- that source *lists* resumable pickers.
--  `Snacks.picker.resume()` reopens the last one, like `builtin.resume` did.
vim.keymap.set("n", "<leader>sr", function()
	Snacks.picker.resume()
end, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", pick("recent"), { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set("n", "<leader>sc", pick("commands"), { desc = "[S]earch [C]ommands" })
vim.keymap.set("n", "<leader><leader>", pick("buffers"), { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>f", pick("files"), { desc = "[ ] Search Files" })
vim.keymap.set("n", "<leader>/", pick("lines"), { desc = "[/] Fuzzily search in current buffer" })

-- It's also possible to pass additional configuration options.
--  See the `grep_buffers` source in the picker docs for the particular keys.
vim.keymap.set(
	"n",
	"<leader>s/",
	pick("grep_buffers", { title = "Live Grep in Open Files" }),
	{ desc = "[S]earch [/] in Open Files" }
)

-- Shortcut for searching your Neovim configuration files
vim.keymap.set(
	"n",
	"<leader>sn",
	pick("files", { cwd = vim.fn.stdpath("config"), follow = true }),
	{ desc = "[S]earch [N]eovim files" }
)

-- Picker-based LSP mappings, added when an LSP attaches to a buffer.
--  These live here rather than in lua/plugins/lsp/ on purpose: they are the
--  picker's mappings, so switching picker plugins means editing this file only.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("picker-lsp-attach", { clear = true }),
	callback = function(event)
		local buf = event.buf

		-- Find references for the word under your cursor.
		vim.keymap.set("n", "grr", pick("lsp_references"), { buffer = buf, desc = "[G]oto [R]eferences" })

		-- Jump to the implementation of the word under your cursor.
		-- Useful when your language has ways of declaring types without an actual implementation.
		vim.keymap.set("n", "gri", pick("lsp_implementations"), { buffer = buf, desc = "[G]oto [I]mplementation" })

		-- Jump to the definition of the word under your cursor.
		-- This is where a variable was first declared, or where a function is defined, etc.
		-- To jump back, press <C-t>.
		vim.keymap.set("n", "grd", pick("lsp_definitions"), { buffer = buf, desc = "[G]oto [D]efinition" })

		-- Fuzzy find all the symbols in your current document.
		-- Symbols are things like variables, functions, types, etc.
		vim.keymap.set("n", "gO", pick("lsp_symbols"), { buffer = buf, desc = "Open Document Symbols" })

		-- Fuzzy find all the symbols in your current workspace.
		-- Similar to document symbols, except searches over your entire project.
		vim.keymap.set("n", "gW", pick("lsp_workspace_symbols"), { buffer = buf, desc = "Open Workspace Symbols" })

		-- Jump to the type of the word under your cursor.
		-- Useful when you're not sure what type a variable is and you want to see
		-- the definition of its *type*, not where it was *defined*.
		vim.keymap.set("n", "grt", pick("lsp_type_definitions"), { buffer = buf, desc = "[G]oto [T]ype Definition" })
	end,
})
