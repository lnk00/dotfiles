-- Neovim configuration.
--
-- Everything lives in lua/: editor settings and editor-only keymaps under
-- lua/core/, one file per plugin under lua/plugins/. Plugin keymaps sit in
-- their plugin's file, so deleting the file takes its mappings with it.
--
-- The order below is load-bearing. `vim.pack.add` + `setup()` runs eagerly, so
-- a plugin that reads another at setup time has to come after it. Do not
-- replace this with a directory glob.

require("core.options") -- leader keys: must precede every vim.pack.add
require("core.pack") -- PackChanged build hooks: must precede every install
require("core.diagnostics")
require("core.completion-menu") -- ext_popupmenu: must come after 'completeopt' in core.options
require("core.docked-floats") -- hover/signature panes: stack on the menu above

require("plugins.guess-indent")
require("plugins.gitsigns")
require("plugins.which-key")
require("plugins.todo-comments")
require("plugins.mini") -- mocks nvim-web-devicons for the plugins below
require("plugins.flash")

vim.pack.add({'https://github.com/e-ink-colorscheme/e-ink.nvim'})
require('e-ink').setup()
vim.cmd.colorscheme("e-ink")

require("plugins.snacks") -- must precede project.nvim and neogit
require("plugins.project")
require("plugins.oil")
require("plugins.fidget")
require("plugins.lsp")
require("plugins.copilot")
require("plugins.conform")
require("plugins.treesitter")

require("core.keymaps")
