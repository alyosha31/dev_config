vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "*.c",
    callback = function()
        local template_path =
            vim.fn.expand("~/.config/nvim/templates/skeleton.c")

        local lines = vim.fn.readfile(template_path)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

        vim.api.nvim_win_set_cursor(0, {5, 4})
    end,
})

vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "*.h",
    callback = function(args)
        local filename = vim.fn.fnamemodify(args.file, ":t")
        local guard = filename
            :upper()
            :gsub("[^A-Z0-9]", "_")

        local lines = {
            "#ifndef " .. guard,
            "#define " .. guard,
            "",
            "",
            "",
            "#endif /* " .. guard .. " */",
        }

        vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, { 4, 0 })
    end,
})

vim.api.nvim_create_user_command("Template", function()
    local extension = vim.fn.expand("%:e")

    if extension == "c" then
        local template_path =
            vim.fn.expand("~/.config/nvim/templates/skeleton.c")

        if vim.fn.filereadable(template_path) ~= 1 then
            vim.notify(
                "Template not found: " .. template_path,
                vim.log.levels.ERROR
            )
            return
        end

        local lines = vim.fn.readfile(template_path)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, { 5, 4 })

    elseif extension == "h" then
        local filename = vim.fn.expand("%:t")
        local guard = filename
            :upper()
            :gsub("[^A-Z0-9]", "_")

        local lines = {
            "#ifndef " .. guard,
            "#define " .. guard,
            "",
            "",
            "",
            "#endif /* " .. guard .. " */",
        }

        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, { 4, 0 })

    else
        vim.notify(
            "No template configured for ." .. extension,
            vim.log.levels.WARN
        )
    end
end, {})

-- Git keymap cheatsheet: :GitKeys or <leader>g?
vim.api.nvim_create_user_command("GitKeys", function()
    local path = vim.fn.stdpath("config") .. "/GIT-KEYMAPS.md"

    if vim.fn.filereadable(path) ~= 1 then
        vim.notify("Cheatsheet not found: " .. path, vim.log.levels.ERROR)
        return
    end

    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
    vim.bo.modifiable = false
    vim.keymap.set("n", "q", "<cmd>tabclose<CR>", { buffer = 0, desc = "Close cheatsheet" })
end, { desc = "Git keymap cheatsheet" })

-- Saved quickfix lists, such as Claude's walkthroughs: :qflist or <leader>fq.
vim.api.nvim_create_user_command("QfList", function()
    require("util.qflists").pick()
end, { desc = "Pick a saved quickfix list" })

-- User commands must start with a capital, so :qflist is an abbreviation that
-- becomes :QfList when it is the whole command line.
vim.keymap.set("ca", "qflist", function()
    if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "qflist" then
        return "QfList"
    end
    return "qflist"
end, { expr = true, desc = ":qflist runs :QfList" })

-- Flash what was just yanked, so it's clear what `yi(` or `yap` actually took.
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.hl.on_yank()
    end,
})
