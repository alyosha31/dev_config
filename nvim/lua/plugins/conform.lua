return {
	"stevearc/conform.nvim",
	opts = {
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
	},
}
