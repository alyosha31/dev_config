-- -- -- =========================================
-- -- -- Theme
-- -- -- =========================================
-- --
-- -- -- require("rose-pine").setup({
-- -- --   variant = "main",
-- -- --   dark_variant = "main",
-- -- --   styles = {
-- -- --     transparency = false,
-- -- --   },
-- -- -- })
-- -- --
-- -- -- vim.cmd("colorscheme rose-pine")
-- --
-- -- vim.opt.termguicolors = true
-- -- vim.o.background = "dark"
-- --
-- -- require("catppuccin").setup({
-- -- 	flavour = "mocha", -- latte, frappe, macchiato, mocha
-- -- 	transparent_background = false,
-- -- 	term_colors = true,
-- --
-- -- 	styles = {
-- -- 		comments = { "italic" },
-- -- 		conditionals = {},
-- -- 		loops = {},
-- -- 		functions = {},
-- -- 		keywords = {},
-- -- 		strings = {},
-- -- 		variables = {},
-- -- 		numbers = {},
-- -- 		booleans = {},
-- -- 		properties = {},
-- -- 		types = {},
-- -- 	},
-- --
-- -- 	integrations = {
-- -- 		treesitter = true,
-- -- 		native_lsp = {
-- -- 			enabled = true,
-- -- 		},
-- -- 		telescope = {
-- -- 			enabled = true,
-- -- 		},
-- -- 		gitsigns = true,
-- -- 		mason = true,
-- -- 		blink_cmp = true,
-- -- 	},
-- -- })
-- --
-- -- vim.cmd.colorscheme("catppuccin")
--
-- -- theme.lua
--
-- -- vim.opt.termguicolors = true
-- -- vim.o.background = "dark"
-- --
-- -- require("fluoromachine").setup({
-- --   theme = "retrowave",
-- --   glow = true,
-- --   transparent = false,
-- --   brightness = 0.05,
-- -- })
-- --
-- -- vim.cmd.colorscheme("fluoromachine")
--
-- -- =========================================
-- -- Theme
-- -- =========================================
-- --
-- vim.opt.termguicolors = true
-- vim.o.background = "dark"
--
-- require("tokyonight").setup({
-- 	style = "night",
-- 	transparent = false,
--
-- 	styles = {
-- 		comments = { italic = true },
-- 		keywords = {},
-- 		functions = {},
-- 		variables = {},
-- 	},
-- })
--
-- vim.cmd.colorscheme("tokyonight-night")
-- -- vim.opt.termguicolors = true
-- -- vim.o.background = "dark"
-- --
-- -- vim.cmd.colorscheme("default")
vim.opt.termguicolors = true
vim.o.background = "dark"

require("gruvbox").setup({
	contrast = "hard",
	transparent_mode = false,
	italic = {
		strings = false,
		emphasis = false,
		comments = true,
		operators = false,
		folds = true,
	},
})

vim.cmd.colorscheme("gruvbox")
