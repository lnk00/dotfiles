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
require("core.autocmds")

require("plugins.guess-indent")
require("plugins.gitsigns")
require("plugins.which-key")
require("plugins.todo-comments")
require("plugins.mini") -- mocks nvim-web-devicons for the plugins below
require("plugins.flash")

-- >>> eink theme (generated -- edit ~/.config/theme/eink.toml) >>>
-- The colorscheme itself is generated into nvim/colors/eink.lua and is
-- loaded by name like any other theme. Nothing to configure here.
vim.cmd.colorscheme("eink")

-- Frame every float that does not bring its own border, so hover (K),
-- signature help and the diagnostic float get the rule tone drawn around
-- them. Square, to match the snacks pickers below.
vim.o.winborder = "single"
-- <<< eink theme <<<

require("plugins.snacks") -- must precede project.nvim and neogit
require("plugins.project")
require("plugins.oil")
require("plugins.git")
require("plugins.fidget")
require("plugins.lsp")
require("plugins.conform")
require("plugins.treesitter")

-- Last, so an editor keymap wins a collision with a plugin's own mapping.
require("core.keymaps")

if vim.g.neovide then
	require("core.neovide")
end
