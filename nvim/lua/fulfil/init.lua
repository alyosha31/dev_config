-- Model-aware navigation for the Fulfil codebase.
--
-- Pyright can't see through Fulfil's ORM: `gd` on a record stops at
-- `SaleLine = Pool().get("sale.line")`, and `grt` on `self.party` lands in the
-- Many2One field class. These follow the ORM instead. nav.py, next to this
-- file, indexes every model's __name__, fields and methods and does the
-- working out; this side only sends it the buffer and the cursor.
--
--   gm   Go to the model of whatever is under the cursor: a pool variable
--        (SaleLine), a record (line, purchase), self, a field (purchase.lines,
--        line.product), or a model name string ("sale.line").
--   gM   Go to the field or method under the cursor -- purchase.lines,
--        line.product, sale.process -- on whichever model it belongs to.
--   :FulfilModel sale.line   Jump to a model by name, with completion.
--
-- It only guesses from a variable's name (an untyped `lines` parameter inside
-- purchase.purchase is probably purchase.line) when nothing else is known, and
-- the message says so. More than one answer goes to the quickfix list.

local M = {}

local script = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "nav.py")
local cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "fulfil-nav")
local model_names = {} -- root -> sorted model names, for :FulfilModel completion

-- The checkout or worktree a buffer belongs to: the directory holding fulfilio/.
local function root_of(buf)
	return vim.fs.root(buf, "fulfilio")
end

local function command(root, args)
	local venv = root .. "/.venv/bin/python"
	local python = vim.fn.executable(venv) == 1 and venv or "python3"
	return vim.list_extend({ python, "-I", script, args[1], root, cache_dir }, vim.list_slice(args, 2))
end

-- Run nav.py in the background and hand its answer to `on_done`. The first run
-- in a checkout builds the index, which takes a few seconds; later runs only
-- re-read files that changed.
local function run(root, args, stdin, on_done)
	local finished = false
	vim.defer_fn(function()
		if not finished then
			vim.notify("Indexing Fulfil models...")
		end
	end, 800)

	vim.system(command(root, args), { stdin = stdin, text = true }, function(result)
		finished = true
		vim.schedule(function()
			local ok, answer = pcall(vim.json.decode, result.stdout or "")
			if not ok or type(answer) ~= "table" then
				vim.notify("fulfil-nav failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
				return
			end
			on_done(answer)
		end)
	end)
end

local function show(answer)
	if not answer.ok then
		vim.notify(answer.message, vim.log.levels.WARN)
		return
	end

	local locations = answer.locations
	if #locations == 1 then
		local loc = locations[1]
		local buf = vim.fn.bufadd(loc.file)
		vim.cmd("normal! m'")
		vim.bo[buf].buflisted = true
		vim.api.nvim_win_set_buf(0, buf)
		vim.api.nvim_win_set_cursor(0, { loc.line, 0 })
		vim.cmd("normal! zz")
	else
		vim.fn.setqflist({}, " ", {
			title = answer.title,
			items = vim.tbl_map(function(loc)
				return { filename = loc.file, lnum = loc.line, text = loc.text }
			end, locations),
		})
		vim.cmd("botright copen")
	end

	if answer.note ~= "" then
		vim.notify(answer.label .. "  ←  " .. answer.note)
	end
end

local function resolve(mode)
	local root = root_of(0)
	if not root then
		vim.notify("Not inside a Fulfil checkout", vim.log.levels.WARN)
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	-- Send the buffer, not the file, so unsaved edits count.
	local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n"
	run(root, {
		"resolve",
		vim.api.nvim_buf_get_name(0),
		tostring(cursor[1]),
		tostring(cursor[2]),
		mode,
	}, text, show)
end

local function current_root()
	return root_of(0) or vim.fs.root(vim.fn.getcwd(), "fulfilio")
end

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("FulfilNav", { clear = true }),
		pattern = "python",
		callback = function(args)
			if not root_of(args.buf) then
				return
			end
			vim.keymap.set("n", "gm", function()
				resolve("model")
			end, { buffer = args.buf, desc = "Fulfil: go to model" })
			vim.keymap.set("n", "gM", function()
				resolve("member")
			end, { buffer = args.buf, desc = "Fulfil: go to field or method" })
		end,
	})

	vim.api.nvim_create_user_command("FulfilModel", function(opts)
		local root = current_root()
		if not root then
			vim.notify("Not inside a Fulfil checkout", vim.log.levels.WARN)
			return
		end
		run(root, { "goto", opts.args }, nil, show)
	end, {
		nargs = 1,
		desc = "Jump to a Fulfil model by name",
		complete = function(lead)
			local root = current_root()
			if not root then
				return {}
			end
			if not model_names[root] then
				local result = vim.system(command(root, { "models" }), { text = true }):wait()
				local ok, answer = pcall(vim.json.decode, result.stdout or "")
				model_names[root] = ok and answer.models or {}
			end
			return vim.tbl_filter(function(name)
				return name:find(lead, 1, true) ~= nil
			end, model_names[root])
		end,
	})
end

return M
