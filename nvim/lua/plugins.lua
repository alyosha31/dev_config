-- =========================================
-- Plugins
-- =========================================
require("lazy").setup({
	-- theme
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		lazy = false,
	},

	-- {
	-- 	"folke/tokyonight.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	opts = {},
	-- },
	-- {
	-- 	"rose-pine/neovim",
	-- 	name = "rose-pine",
	-- 	priority = 1000,
	-- },
	-- {
	-- 	"maxmx03/fluoromachine.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- },
	-- {
	-- 	"catppuccin/nvim",
	-- 	name = "catppuccin",
	-- 	priority = 1000,
	-- 	lazy = false,
	-- },

	-- yazi
	-- {
	-- 	"mikavilpas/yazi.nvim",
	-- 	event = "VeryLazy",
	-- 	opts = {
	-- 		open_for_directories = true,
	-- 	},
	-- },

	-- Lazygit
	{
		"kdheepak/lazygit.nvim",
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},

	-- search / picker
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-file-browser.nvim",
		},
	},

	-- statusline
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
	},

	-- smooth scrolling
	{
		"karb94/neoscroll.nvim",
	},

	-- git signs
	{
		"lewis6991/gitsigns.nvim",
	},

	-- autopairs
	{
		"echasnovski/mini.pairs",
		version = false,
	},

	-- formatter
	{
		"stevearc/conform.nvim",
	},

	-- LSP + tooling
	{
		"mason-org/mason.nvim",
	},
	{
		"neovim/nvim-lspconfig",
	},
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {},
	},

	-- java support
	{
		"mfussenegger/nvim-jdtls",
	},

	-- nvim-treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"go",
					"gomod",
					"gosum",
					"gowork",
					"lua",
					"json",
					"yaml",
					"markdown",
					"python",
					"javascript",
					"typescript",
					"java",
					"c",
					"cpp",
				},

				sync_install = false,
				auto_install = false,
				ignore_install = {},
				modules = {},

				highlight = {
					enable = true,
				},

				indent = {
					enable = true,
                    disable = { "c", "cpp" },
				},
			})
		end,
	},

	-- completion
	{
		"saghen/blink.cmp",
		version = "*",
		dependencies = {
			"rafamadriz/friendly-snippets",
		},
		opts = {
			keymap = {
				preset = "default",

				["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
				["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

				["<C-n>"] = { "select_next", "fallback" },
				["<C-p>"] = { "select_prev", "fallback" },
			},
			appearance = {
				nerd_font_variant = "mono",
			},
			completion = {
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
				},
				menu = {
					auto_show = true,
				},
			},
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
			fuzzy = {
				implementation = "prefer_rust_with_warning",
			},
		},
	},
})

-- =========================================
-- Plugin setup
-- =========================================
require("mini.pairs").setup()

require("gitsigns").setup()

require("lualine").setup({
	options = {
		theme = "auto",
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = {
			{
				function()
					return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
				end,
				icon = "",
			},
		},
		lualine_c = { "filename" },
		lualine_x = { "encoding", "fileformat", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
})

require("neoscroll").setup({
	mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
	hide_cursor = true,
	stop_eof = true,
	respect_scrolloff = false,
	cursor_scrolls_alone = true,
})

require("telescope").setup({
	defaults = {
		layout_config = {
			prompt_position = "top",
		},
		sorting_strategy = "ascending",
		winblend = 0,
	},
})
require("telescope").load_extension("file_browser")

require("mason").setup()

require("conform").setup({
	format_on_save = nil,
	formatters_by_ft = {
		lua = { "stylua" },
		c = { "clang_format" },
		cpp = { "clang_format" },
		go = { "gofmt", "goimports" },
		python = { "ruff_format" },
		javascript = { "prettier" },
		typescript = { "prettier" },
		java = { "google-java-format" },
		json = { "prettier" },
		yaml = { "prettier" },
		markdown = { "prettier" },
		javascriptreact = { "prettier" },
		typescriptreact = { "prettier" },
		tsx = { "prettier" },
	},
})
