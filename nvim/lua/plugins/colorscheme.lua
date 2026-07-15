return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false,
        priority = 1000,

        config = function()
            require("fluoromachine").setup({
                theme = "retrowave",
                glow = true,
                transparent = false,
                brightness = 0.05,
            })
        end,
    },

    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "fluoromachine",
        },
    },
}
