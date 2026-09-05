-- todo-comments.nvim -- highlight TODO, FIX, NOTE and friends in comments.
--
-- `wide_fg` marks the keyword and its comment leader in colour rather
-- than behind a filled block -- see ~/.config/theme/README.md. The
-- TODO/FIX/NOTE tones themselves come from the Diagnostic* groups the
-- e-ink colorscheme defines, so they follow the palette already.
vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })
require("todo-comments").setup({ signs = false, highlight = { keyword = "wide_fg" } })
