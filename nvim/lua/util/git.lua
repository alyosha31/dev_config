local M = {}

local function first_line(cmd)
	local out = vim.fn.systemlist(cmd)
	if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
		return out[1]
	end
end

-- Best guess at what the current branch was cut from, for "review the
-- whole branch" style diffs.
function M.base_rev()
	local head = first_line({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
	if head then
		return head
	end

	for _, name in ipairs({ "origin/main", "origin/master", "main", "master" }) do
		if first_line({ "git", "rev-parse", "--verify", "--quiet", name }) then
			return name
		end
	end
end

-- The commit that last touched the cursor line. Blames the buffer as it is
-- now, not the file on disk, so unsaved edits above the cursor do not shift
-- the line. On a fugitive or diffview line that already shows a hash, that
-- hash wins -- there the commit under the cursor is the point, not the blame.
function M.commit_at_cursor()
	local hash_fts = { fugitive = true, fugitiveblame = true, git = true, DiffviewFileHistory = true }
	if hash_fts[vim.bo.filetype] then
		local hash = vim.fn.matchstr(vim.fn.getline("."), [[\<\x\{7,40}\>]])
		if hash ~= "" then
			return hash
		end
	end

	local file = vim.api.nvim_buf_get_name(0)
	if file == "" or vim.bo.buftype ~= "" then
		vim.notify("Nothing to blame in this buffer", vim.log.levels.WARN)
		return
	end

	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local out = vim.fn.system({
		"git",
		"-C",
		vim.fs.dirname(file),
		"blame",
		"-L",
		lnum .. "," .. lnum,
		"--porcelain",
		"--contents",
		"-",
		"--",
		file,
	}, vim.api.nvim_buf_get_lines(0, 0, -1, false))

	if vim.v.shell_error ~= 0 then
		vim.notify(vim.trim(out), vim.log.levels.WARN)
		return
	end

	local sha = out:match("^(%x+)")
	if not sha or sha:match("^0+$") then
		vim.notify("This line is not committed yet", vim.log.levels.INFO)
		return
	end

	return sha
end

-- Look up the pull request that brought a commit in. The gh call hits the
-- network, so this is async: on_pr runs a moment later with { number, url },
-- or with nil when the commit landed without one.
local function find_pr(sha, cwd, on_pr)
	if vim.fn.executable("gh") == 0 then
		vim.notify("gh is not installed", vim.log.levels.WARN)
		return
	end

	vim.notify("Looking up " .. sha:sub(1, 7) .. " on GitHub...")

	vim.system(
		{ "gh", "pr", "list", "--search", sha, "--state", "all", "--json", "url,number", "--limit", "1" },
		{ cwd = cwd, text = true },
		function(result)
			local ok, prs = pcall(vim.json.decode, result.stdout or "")
			local pr = ok and prs and prs[1]

			vim.schedule(function()
				on_pr(pr)
			end)
		end
	)
end

-- Open a commit on GitHub, preferring the pull request that brought it in --
-- that is where the review and the discussion are. Falls back to the commit
-- page when it landed without one.
function M.browse_commit(sha)
	local cwd = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
	if cwd == "" then
		cwd = vim.uv.cwd()
	end

	find_pr(sha, cwd, function(pr)
		if pr then
			vim.notify("PR #" .. pr.number .. " for " .. sha:sub(1, 7))
			vim.ui.open(pr.url)
			return
		end

		vim.notify("No PR for " .. sha:sub(1, 7) .. " -- opening the commit")
		vim.system({ "gh", "browse", sha }, { cwd = cwd })
	end)
end

-- Go through the pull request that brought a commit in, in tuicr. It runs
-- from the repo root, so tuicr finds the repo, and when this checkout is the
-- PR's head `e` there opens the real files. Inside tmux it gets a window of
-- its own, which closes when tuicr quits and drops you back here; outside, a
-- terminal tab that does the same.
function M.review_commit_pr(sha)
	if vim.fn.executable("tuicr") == 0 then
		vim.notify("tuicr is not installed", vim.log.levels.WARN)
		return
	end

	local root = vim.fs.root(0, ".git") or vim.uv.cwd()

	find_pr(sha, root, function(pr)
		if not pr then
			vim.notify("No PR for " .. sha:sub(1, 7), vim.log.levels.WARN)
			return
		end

		local cmd = { "tuicr", "pr", tostring(pr.number) }

		if vim.env.TMUX then
			-- Given more than one argument, tmux runs tuicr directly rather
			-- than through a shell.
			vim.system(vim.list_extend({ "tmux", "new-window", "-n", "tuicr", "-c", root }, cmd))
			return
		end

		vim.cmd.tabnew()
		local buf = vim.api.nvim_get_current_buf()
		vim.fn.jobstart(cmd, {
			term = true,
			cwd = root,
			on_exit = function()
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(buf) then
						vim.api.nvim_buf_delete(buf, { force = true })
					end
				end)
			end,
		})
		vim.cmd.startinsert()
	end)
end

return M
