return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		options = {
			theme = "auto",
			-- lualine only redraws when one of these events fires; the
			-- interval below is just a backstop. Its default event list
			-- leaves out everything this statusline actually shows, so
			-- components sat stale until a keypress happened to repaint
			-- the screen.
			--
			-- The whole list has to be spelled out, defaults included:
			-- opts.refresh is merged with vim.tbl_deep_extend("force"),
			-- which for a list merges index-by-index, so a short list
			-- would overwrite the first few defaults and silently keep
			-- the rest.
			refresh = {
				statusline = 200,
				events = {
					-- lualine's defaults
					"WinEnter",
					"BufEnter",
					"BufWritePost",
					"SessionLoadPost",
					"FileChangedShellPost",
					"VimResized",
					"Filetype",
					"CursorMoved",
					"CursorMovedI",
					"ModeChanged",
					-- The cwd component in lualine_b. Nothing in the
					-- defaults covers :cd, so yazi and telescope jumps
					-- left the old directory on screen.
					"DirChanged",
					-- filename's [+] flag: CursorMovedI misses an edit
					-- that doesn't move the cursor, like a paste.
					"TextChanged",
					"TextChangedI",
					-- No OptionSet here, tempting as it looks for the
					-- encoding/fileformat components: every refresh sets
					-- &statusline itself, so OptionSet would retrigger the
					-- refresh that fired it and spin forever. Filetype
					-- covers the filetype component; the interval above
					-- picks up a manual :set fileformat.
					-- Repaint the window losing focus as inactive right
					-- away rather than on the next tick.
					"WinLeave",
					"WinClosed",
					"TabEnter",
					"TermOpen",
					"TermClose",
					"TermEnter",
					"TermLeave",
				},
			},
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = {
				{
					function()
						return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
					end,
					icon = "",
				},
			},
			lualine_c = { "filename" },
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	},
}
