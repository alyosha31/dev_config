-- Catppuccin Mocha, the same palette Kitty runs (kitty/current-theme.conf), so
-- the editor and the terminal around it read as one thing.

return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,
	opts = {
		flavour = "mocha",
		-- Leave Normal's background unset so Kitty's background_opacity still
		-- shows through; a painted #1E1E2E would be an opaque cell colour.
		transparent_background = true,
		float = { transparent = false, solid = false },
		integrations = {
			blink_cmp = true,
			diffview = true,
			gitsigns = true,
			markview = true,
			mason = true,
			native_lsp = { enabled = true },
			telescope = { enabled = true },
			treesitter = true,
		},
		custom_highlights = function(C)
			local blend = require("catppuccin.utils.colors").blend

			-- Diffs: removals red, additions green, as the base tinted 20% for
			-- the line and 30% for the changed words. No foreground, so syntax
			-- highlighting survives inside a changed line, and the tints stay
			-- dark enough that punctuation (overlay2) is still readable.
			local added = blend(C.green, C.base, 0.20)
			local added_text = blend(C.green, C.base, 0.30)
			local removed = blend(C.red, C.base, 0.20)
			local removed_text = blend(C.red, C.base, 0.30)

			return {
				-- Side-aware groups: plugins/diffview.lua remaps each window's
				-- Diff* groups onto these so the old side is red and the new
				-- side green.
				GitDiffAdded = { bg = added },
				GitDiffAddedText = { bg = added_text, bold = true },
				GitDiffRemoved = { bg = removed },
				GitDiffRemovedText = { bg = removed_text, bold = true },
				GitDiffFiller = { fg = C.surface1 },

				-- Vim's diff mode is per-window: DiffAdd means "this line isn't
				-- in the other buffer", so one group paints removed lines on the
				-- left and added lines on the right. These are the fallback for
				-- plain :diffsplit and fugitive, where a side-neutral colour for
				-- changes is the honest choice.
				DiffAdd = { link = "GitDiffAdded" },
				DiffChange = { bg = blend(C.yellow, C.base, 0.15) },
				DiffText = { bg = blend(C.yellow, C.base, 0.30), bold = true },
				DiffDelete = { link = "GitDiffFiller" },

				-- gitsigns' in-file diff (<leader>gi) in the same colours.
				GitSignsAddLn = { link = "GitDiffAdded" },
				GitSignsChangeLn = { link = "GitDiffAdded" },
				GitSignsDeleteLn = { link = "GitDiffRemoved" },
				GitSignsAddInline = { link = "GitDiffAddedText" },
				GitSignsChangeInline = { link = "GitDiffAddedText" },
				GitSignsDeleteInline = { link = "GitDiffRemovedText" },
				GitSignsDeleteVirtLn = { link = "GitDiffRemoved" },
				GitSignsDeleteVirtLnInLine = { link = "GitDiffRemovedText" },
				GitSignsVirtLnum = { fg = C.overlay0, bg = removed },
			}
		end,
	},
}
