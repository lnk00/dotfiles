-- flash.nvim -- jump anywhere on screen by typing the characters you are aiming
-- at and then the label that appears next to the match. Also labels the built-in
-- `f`/`t`/`F`/`T` motions (and takes over `;`/`,` for repeating them) --
-- set `modes = { char = { enabled = false } }` below to keep those vanilla.
-- Labels during `/` search are off by default; `<C-s>` toggles them on.
--
-- flash owning bare `s` is why mini.surround sits on `gs`; see lua/plugins/mini.lua.
--
-- Unlike lazy.nvim specs, `vim.pack` has no `keys` table, so the keymaps
-- from the plugin's README are declared by hand here.
vim.pack.add({ "https://github.com/folke/flash.nvim" })
require("flash").setup({})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash" })
vim.keymap.set({ "n", "x", "o" }, "S", function()
	require("flash").treesitter()
end, { desc = "Flash Treesitter" })
-- Operate on a target elsewhere without moving the cursor there: `yr` then
-- flash to the region, e.g. `yriw` yanks a word across the screen.
vim.keymap.set("o", "r", function()
	require("flash").remote()
end, { desc = "Remote Flash" })
vim.keymap.set({ "o", "x" }, "R", function()
	require("flash").treesitter_search()
end, { desc = "Treesitter Search" })
-- Toggle flash labels on/off while already typing a `/` search.
vim.keymap.set("c", "<C-s>", function()
	require("flash").toggle()
end, { desc = "Toggle Flash Search" })
