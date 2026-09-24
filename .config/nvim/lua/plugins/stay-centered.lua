-- stay-centered.nvim -- keep the cursor line in the middle of the window,
-- even at the end of the buffer. Relies on a low 'scrolloff' (core.options).
vim.pack.add({ "https://github.com/arnamak/stay-centered.nvim" })
require("stay-centered").setup({})
