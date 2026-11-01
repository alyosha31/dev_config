local M = {}

-- Saved quickfix lists, such as the walkthroughs Claude writes. They live in
-- the checkout's own git folder (`git rev-parse --git-path qf`): never
-- committed, one set per worktree, and gone when the worktree is removed.
-- Each file is a "# <title>" line followed by one stop per line:
--   /abs/path/file.py:412:5: 1. entry point, the cancel button lands here

local efm = "%f:%l:%c: %m,%f:%l: %m"

function M.dir()
	local root = vim.fs.root(0, ".git") or vim.uv.cwd()
	local out = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--path-format=absolute", "--git-path", "qf" })
	if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
		return out[1]
	end
end

-- The title from the first "#" line, else the file name, and the stops.
local function read(path)
	local title, stops = nil, {}
	for _, line in ipairs(vim.fn.readfile(path)) do
		if line:match("^#") then
			title = title or vim.trim(line:sub(2))
		elseif line:match("%S") then
			table.insert(stops, line)
		end
	end
	return title or vim.fn.fnamemodify(path, ":t:r"), stops
end

local function age(mtime)
	local seconds = os.time() - mtime
	if seconds < 3600 then
		return math.max(1, math.floor(seconds / 60)) .. "m ago"
	elseif seconds < 86400 then
		return math.floor(seconds / 3600) .. "h ago"
	end
	return math.floor(seconds / 86400) .. "d ago"
end

-- Make a saved list the current quickfix list, open the quickfix window, and
-- put the cursor on the first stop. ]q and [q step from there.
function M.load(path)
	local title, stops = read(path)
	vim.fn.setqflist({}, " ", { title = title, lines = stops, efm = efm })
	if not pcall(vim.cmd.cfirst) then
		vim.notify("No stops in " .. path, vim.log.levels.WARN)
		return
	end
	vim.cmd("botright copen")
	vim.cmd.wincmd("p")
end

-- Pick one of this checkout's saved lists, newest first, with its stops in
-- the preview.
function M.pick()
	local dir = M.dir()
	if not dir then
		vim.notify("Not in a git checkout", vim.log.levels.WARN)
		return
	end

	local lists = {}
	for _, path in ipairs(vim.fn.glob(dir .. "/*.qf", false, true)) do
		local title, stops = read(path)
		table.insert(lists, { path = path, title = title, stops = stops, mtime = vim.fn.getftime(path) })
	end
	if #lists == 0 then
		vim.notify("No saved quickfix lists in this checkout", vim.log.levels.INFO)
		return
	end
	table.sort(lists, function(a, b)
		return a.mtime > b.mtime
	end)

	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Quickfix lists",
			finder = require("telescope.finders").new_table({
				results = lists,
				entry_maker = function(list)
					return {
						value = list,
						display = string.format(
							"%s  (%d %s, %s)",
							list.title,
							#list.stops,
							#list.stops == 1 and "stop" or "stops",
							age(list.mtime)
						),
						ordinal = list.title,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = require("telescope.previewers").new_buffer_previewer({
				title = "Stops",
				define_preview = function(self, entry)
					local rows = {}
					for _, stop in ipairs(entry.value.stops) do
						local file, lnum, note = stop:match("^(.-):(%d+):%d+: ?(.*)$")
						if not file then
							file, lnum, note = stop:match("^(.-):(%d+): ?(.*)$")
						end
						table.insert(rows, file and (vim.fn.fnamemodify(file, ":~:.") .. "|" .. lnum .. "| " .. note) or stop)
					end
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, rows)
					vim.bo[self.state.bufnr].syntax = "qf"
					vim.wo[self.state.winid].wrap = true
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						M.load(selection.value.path)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
