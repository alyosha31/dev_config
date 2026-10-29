-- Loaded eagerly (no lazy triggers) so signs are there as soon as a file opens.
-- Keymaps live in lua/keymaps.lua with the rest of the git bindings.
return {
	"lewis6991/gitsigns.nvim",
	opts = {
		current_line_blame = false,
		-- Put the PR number next to the sha in the <leader>gb float, as a real
		-- hyperlink -- Kitty's cmd+click opens it. Needs the gh CLI, and costs a
		-- network call, so the float redraws with the PR a moment after it opens.
		gh = true,
	},
}
