-- Loaded eagerly (no lazy triggers) so signs are there as soon as a file opens.
-- Keymaps live in lua/keymaps.lua with the rest of the git bindings.
return {
	"lewis6991/gitsigns.nvim",
	opts = {
		current_line_blame = false,
	},
}
