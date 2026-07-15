vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.termguicolors = true
vim.o.background = "dark"


require("vim-options")
require("keymaps")

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1


vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})


-- bootstrap lazy first
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(require("plugins"))
require("theme")



-- =========================================
-- LSP
-- =========================================
local capabilities = require("blink.cmp").get_lsp_capabilities()

local function get_python_path()
  local cwd = vim.fn.getcwd()
  local venv_python = cwd .. "/.venv/bin/python"

  if vim.fn.executable(venv_python) == 1 then
    return venv_python
  end

  return "python3"
end

-- shared capabilities for all servers
vim.lsp.config("*", {
  capabilities = capabilities,
})

vim.lsp.config("pyright", {
  settings = {
    python = {
      pythonPath = get_python_path(),
      analysis = {
        typeCheckingMode = "off",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

vim.lsp.config("clangd", {})
vim.lsp.config("gopls", {})
vim.lsp.config("ts_ls", {})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      completion = {
        callSnippet = "Replace",
      },
    },
  },
})

vim.lsp.enable({
  "pyright",
  "clangd",
  "gopls",
  "ts_ls",
  "lua_ls",
})

-- Java: start jdtls only for Java buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
    local jdtls = require("jdtls")
    local root_dir = require("jdtls.setup").find_root({
      "gradlew",
      "mvnw",
      ".git",
      "pom.xml",
      "build.gradle",
      "build.gradle.kts",
    })

    if not root_dir then
      return
    end

    local project_name = vim.fn.fnamemodify(root_dir, ":p:t")
    local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

    local config = {
      cmd = { "jdtls", "-data", workspace_dir },
      root_dir = root_dir,
      capabilities = capabilities,
    }

    jdtls.start_or_attach(config)
  end,
})

require("config.autocmds")
