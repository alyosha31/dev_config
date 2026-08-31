-- Use Kitty's native dark terminal palette instead of a separate GUI palette.
-- With termguicolors disabled, Neovim's default colors map directly to Kitty's
-- configured ANSI colors and automatically follow future Kitty theme changes.
vim.o.background = "dark"
vim.opt.termguicolors = false
vim.cmd.colorscheme("default")
