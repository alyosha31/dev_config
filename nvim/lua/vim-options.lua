vim.g.mapleader = " "
vim.g.background = "light"

-- =========================================
-- Basic options
-- =========================================
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 200
-- Long enough to reach for shift mid-chord: <leader>gB and friends were
-- timing out at 300ms and falling through as literal keys. Terminal escape
-- sequences use ttimeoutlen (50ms), so this costs nothing there.
vim.opt.timeoutlen = 800
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.cursorline = true
-- lualine_a already shows the mode. Without this, Vim also draws its own
-- "-- INSERT --" in the command line under the statusline.
vim.opt.showmode = false
vim.opt.clipboard = "unnamedplus"
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  -- Paste from nvim's own register; OSC 52 reads hang when the terminal doesn't reply.
  paste = {
    ["+"] = function() return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") } end,
    ["*"] = function() return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") } end,
  },
}
vim.opt.mouse = "a"
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
