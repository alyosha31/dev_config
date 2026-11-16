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

-- Print "(3 of 9): <note>" for the current stop, cut to fit on one line so it
-- never asks you to press Enter. Redraw first: jumping to another file
-- repaints the screen, which would wipe a message printed before it.
local function show_stop()
	local list = vim.fn.getqflist({ idx = 0, size = 0 })
	local item = vim.fn.getqflist({ idx = list.idx, items = 0 }).items[1]
	if not item then
		return
	end
	local message = ("(%d of %d): %s"):format(list.idx, list.size, item.text)
	vim.cmd.redraw()
	vim.api.nvim_echo({ { vim.fn.strcharpart(message, 0, math.max(vim.v.echospace, 1)) } }, false, {})
end

local function jump(cmd, count)
	local ok, err = pcall(vim.cmd, { cmd = cmd, count = count })
	if not ok then
		vim.notify(err:match("E%d+: .*") or err, vim.log.levels.WARN)
		return
	end
	show_stop()
end

-- Step through the current quickfix list with a count, as ]q and [q do, and
-- print the stop's note. Neovim's own ]q and [q move without printing it, so a
-- walkthrough's note stayed on the first stop.
function M.step(cmd)
	jump(cmd, vim.v.count1)
end

-- <CR> in the quickfix window: open the stop under the cursor, as the built-in
-- <CR> does, and print its note, which the built-in one doesn't either.
function M.open_under_cursor()
	jump("cc", vim.fn.line("."))
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
	show_stop()
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
