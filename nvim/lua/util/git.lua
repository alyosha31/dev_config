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

return M
