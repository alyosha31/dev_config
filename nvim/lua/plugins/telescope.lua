return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		defaults = {
			layout_config = {
				prompt_position = "top",
			},
			sorting_strategy = "ascending",
			winblend = 0,
		},
	},
}
