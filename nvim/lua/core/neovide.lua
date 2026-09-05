-- Neovide-only settings. Required from init.lua behind an `if vim.g.neovide`
-- guard, so nothing here runs in a terminal Neovim.

vim.o.guifont = "GeistMono Nerd Font Mono:h12"
vim.g.neovide_floating_shadow = false
vim.g.neovide_refresh_rate = 144

vim.keymap.set({ "n", "v" }, "<C-S-s>", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set({ "i", "c" }, "<C-v>", "<C-r>+", { desc = "Paste from system clipboard" })
vim.keymap.set("t", "<C-v>", '<C-\\><C-n>"+pi', { desc = "Paste from system clipboard" })
vim.keymap.set("n", "<C-S-v>", '"+p', { desc = "Paste from system clipboard" })
