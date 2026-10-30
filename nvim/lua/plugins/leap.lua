-- Leap: `s` plus the two characters at the spot you're looking at, then a
-- label if more than one place matches. `S` does the same across the other
-- split windows. Leap loads itself lazily, and its README warns that lazy.nvim
-- `keys` can break it, so the mappings are set in config instead.
--
-- This takes over the built-in `s` (same as `cl`) and `S` (same as `cc`).

return {
	"https://codeberg.org/andyg/leap.nvim",
	config = function()
		vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap)", { desc = "Leap" })
		vim.keymap.set("n", "S", "<Plug>(leap-from-window)", { desc = "Leap to another window" })
	end,
}
