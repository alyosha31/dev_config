return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	dependencies = {
		"neovim-treesitter/treesitter-parser-registry",
	},
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local languages = {
			"go",
			"gomod",
			"gosum",
			"gowork",
			"lua",
			"json",
			"yaml",
			"markdown",
			"markdown_inline",
			"python",
			"javascript",
			"typescript",
			"java",
			"c",
			"cpp",
		}

		require("nvim-treesitter").install(languages)
		vim.api.nvim_create_autocmd("FileType", {
			pattern = languages,
			callback = function()
				vim.treesitter.start()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
