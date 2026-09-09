-- Diffview: review commits and branches without juggling splits.
--
-- Entry points (all leader-g):
--   gd  working tree diff          gl  repo commit log (the "tree")
--   gh  history of current file    gm  everything on this branch vs its base
--   gc  a single commit by revision/hash
--   gq / q  close the whole diffview tab in one go
--
-- Inside a diffview:
--   <cr>/o on an entry  open its diff        <tab>/<s-tab>  next/prev file
--   ]c/[c  next/prev hunk                    ]h/[h  same, centred
--   zM  collapse to hunks only               zR / zi  back to the whole file
--   za/zo/zc  fold a commit open to see the files it touched
--   D (log panel)  open that commit as a full file tree
--   gf  jump to the real file here           gF  same, and point gitsigns at
--                                            this revision so LSP + the same
--                                            hunks are both available
--   L  commit message   y  copy hash         <leader>b  toggle panel   g?  help

local function diff_branch()
	local base = require("util.git").base_rev()
	if not base then
		vim.notify("Could not work out a base branch", vim.log.levels.WARN)
		return
	end
	-- Three dots: only what this branch added, ignoring base moving on.
	vim.cmd("DiffviewOpen " .. base .. "...HEAD")
end

local function diff_commit()
	vim.ui.input({ prompt = "Diff commit (hash/tag/HEAD~2): " }, function(rev)
		if rev and rev ~= "" then
			-- `^!` is "this commit against its parent".
			vim.cmd("DiffviewOpen " .. rev .. "^!")
		end
	end)
end

-- The commit shown in the left-hand window of the current diff, if any.
local function left_commit()
	local ok, lib = pcall(require, "diffview.lib")
	if not ok then
		return
	end

	local view = lib.get_current_view()
	local entry = view and view.cur_entry
	local win = entry and entry.layout and entry.layout.a
	local rev = win and win.file and win.file.rev

	return rev and rev.commit
end

-- History buffers are git blobs, so no LSP: `gd`/`gr` are dead there. This
-- jumps to the real file on disk at the same line and hands gitsigns the
-- revision we were diffing against, so the same hunks show up as signs in a
-- buffer where LSP, treesitter and `]h` all work.
local function goto_file_keep_base()
	local commit = left_commit()

	require("diffview.actions").goto_file_edit()

	if not commit then
		return
	end

	vim.schedule(function()
		local ok, gs = pcall(require, "gitsigns")
		if ok then
			gs.change_base(commit, false)
			vim.notify("gitsigns base: " .. commit:sub(1, 7) .. "  (<leader>gB to reset)")
		end
	end)
end

return {
	"sindrets/diffview.nvim",
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewRefresh",
		"DiffviewFileHistory",
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Diff working tree" },
		{ "<leader>gl", "<cmd>DiffviewFileHistory<CR>", desc = "Repo commit log" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Current file history" },
		{ "<leader>gm", diff_branch, desc = "Diff branch against its base" },
		{ "<leader>gc", diff_commit, desc = "Diff a single commit" },
		{ "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diffview" },
		-- In visual mode `:` already fills in the '<,'> range.
		{ "<leader>gh", ":DiffviewFileHistory<CR>", mode = "v", desc = "History of selected lines" },
	},
	init = function()
		-- Bridge from fugitive: put the cursor on any line showing a hash
		-- (`:Git log`, blame, status) and press gD to review that commit here.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "fugitive", "fugitiveblame", "git" },
			callback = function(args)
				vim.keymap.set("n", "gD", function()
					local hash = vim.fn.matchstr(vim.fn.getline("."), [[\<\x\{7,40}\>]])
					if hash == "" then
						vim.notify("No commit hash on this line", vim.log.levels.WARN)
						return
					end
					vim.cmd("DiffviewOpen " .. hash .. "^!")
				end, { buffer = args.buf, desc = "Open commit under cursor in Diffview" })
			end,
		})
	end,
	opts = function()
		local actions = require("diffview.actions")

		-- Close the entire tab — panel and every diff split at once.
		local close = { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } }

		-- Hunk navigation that keeps the hunk centred in both windows.
		local next_hunk = { "n", "]h", "]czz", { desc = "Next hunk" } }
		local prev_hunk = { "n", "[h", "[czz", { desc = "Previous hunk" } }

		return {
			enhanced_diff_hl = true,
			view = {
				default = { layout = "diff2_horizontal", winbar_info = true },
				merge_tool = { layout = "diff3_mixed", disable_diagnostics = true, winbar_info = true },
				file_history = { layout = "diff2_horizontal", winbar_info = true },
			},
			file_panel = {
				listing_style = "tree",
				tree_options = {
					flatten_dirs = true,
					folder_statuses = "only_folded",
				},
				win_config = { position = "left", width = 40 },
			},
			file_history_panel = {
				win_config = { position = "bottom", height = 18 },
			},
			hooks = {
				diff_buf_read = function()
					-- Diffs read better without wrapping or sign column jitter.
					vim.opt_local.wrap = false
					vim.opt_local.list = false
					vim.opt_local.relativenumber = false
					vim.opt_local.cursorline = true
				end,
				diff_buf_win_enter = function()
					-- `:diffthis` sets foldmethod=diff with foldlevel=0, which
					-- collapses everything that didn't change — the diff ends up
					-- showing hunks with no surrounding file. Open the folds so
					-- each hunk sits in the whole file; zM collapses them back.
					vim.opt_local.foldlevel = 99
				end,
			},
			keymaps = {
				view = {
					close,
					next_hunk,
					prev_hunk,
					{ "n", "gF", goto_file_keep_base, { desc = "Go to the real file, keeping this diff base" } },
				},
				file_panel = {
					close,
					{ "n", "<cr>", actions.select_entry, { desc = "Open the diff for this entry" } },
					{ "n", "<C-r>", actions.refresh_files, { desc = "Refresh entries" } },
					{ "n", "gF", goto_file_keep_base, { desc = "Go to the real file, keeping this diff base" } },
				},
				file_history_panel = {
					close,
					{ "n", "D", actions.open_in_diffview, { desc = "Open this commit as a file tree" } },
					{ "n", "gF", goto_file_keep_base, { desc = "Go to the real file, keeping this diff base" } },
				},
			},
		}
	end,
}
