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
