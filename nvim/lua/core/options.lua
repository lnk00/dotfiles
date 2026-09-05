-- Core editor settings. Loaded first: the leader keys must be set before any
-- plugin is added, or the mappings they create bind to the wrong prefix.

-- Cache compiled Lua modules for a faster startup.
vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

vim.o.number = true
vim.o.relativenumber = true

-- The mode already shows in the statusline.
vim.o.showmode = false

vim.o.breakindent = true

-- Indentation: match Helix's tab width (4) instead of Vim's default 8.
--  Tabs are kept as tabs; only how wide they render changes.
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = false

-- Undo/redo survives closing and reopening a file.
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = "yes"
vim.o.updatetime = 250
vim.o.timeoutlen = 300

vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type.
vim.o.inccommand = "split"

vim.o.cursorline = true
vim.o.scrolloff = 10

-- Prompt to save instead of failing on `:q` with unsaved changes.
vim.o.confirm = true

-- Insert-mode completion behavior. Used by the built-in LSP completion
-- enabled on `LspAttach` in lua/plugins/lsp/init.lua.
--  menuone  - show the popup menu even when there is only one match
--  noselect - never preselect an item, so autotrigger can't hijack your typing
--  popup    - show item documentation in a floating window
--  fuzzy    - fuzzy-match the menu instead of requiring a prefix match
-- See `:help 'completeopt'`
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
