-- Use Kitty's native dark terminal palette instead of a separate GUI palette.
-- With termguicolors disabled, Neovim's default colors map directly to Kitty's
-- configured ANSI colors and automatically follow future Kitty theme changes.
vim.o.background = "dark"
vim.opt.termguicolors = false
vim.cmd.colorscheme("default")

-- Give modern Tree-sitter and LSP captures useful roles while retaining
-- Kitty's native ANSI palette (0-15). Neovim's default scheme leaves many of
-- these captures linked to plain Normal text, which makes code mostly white.
local highlights = {
	Comment = { ctermfg = 8, italic = true },
	String = { ctermfg = 2 },
	Character = { ctermfg = 2 },
	Number = { ctermfg = 3 },
	Boolean = { ctermfg = 3, bold = true },
	Float = { ctermfg = 3 },
	Identifier = { ctermfg = 7 },
	Function = { ctermfg = 11, bold = true },
	Statement = { ctermfg = 4, bold = true },
	Conditional = { ctermfg = 4, bold = true },
	Repeat = { ctermfg = 4, bold = true },
	Label = { ctermfg = 4 },
	Operator = { ctermfg = 6 },
	Keyword = { ctermfg = 4, bold = true },
	Exception = { ctermfg = 1, bold = true },
	PreProc = { ctermfg = 6 },
	Type = { ctermfg = 6 },
	Special = { ctermfg = 6 },
	Delimiter = { ctermfg = 8 },
	Todo = { ctermfg = 0, ctermbg = 11, bold = true },

	["@variable"] = { ctermfg = 7 },
	["@variable.builtin"] = { ctermfg = 6 },
	["@variable.parameter"] = { ctermfg = 14 },
	["@constant"] = { ctermfg = 14 },
	["@constant.builtin"] = { ctermfg = 6, bold = true },
	["@module"] = { ctermfg = 6 },
	["@string"] = { link = "String" },
	["@number"] = { link = "Number" },
	["@boolean"] = { link = "Boolean" },
	["@function"] = { link = "Function" },
	["@function.call"] = { ctermfg = 11 },
	["@function.builtin"] = { ctermfg = 4, bold = true },
	["@function.method"] = { ctermfg = 11 },
	["@constructor"] = { ctermfg = 14 },
	["@keyword"] = { link = "Keyword" },
	["@keyword.import"] = { ctermfg = 4 },
	["@keyword.return"] = { ctermfg = 4, bold = true },
	["@keyword.exception"] = { link = "Exception" },
	["@type"] = { link = "Type" },
	["@type.builtin"] = { ctermfg = 14, bold = true },
	["@property"] = { ctermfg = 14 },
	["@attribute"] = { ctermfg = 3 },
	["@operator"] = { link = "Operator" },
	["@punctuation"] = { ctermfg = 8 },
	["@comment"] = { link = "Comment" },

	DiagnosticError = { ctermfg = 9 },
	DiagnosticWarn = { ctermfg = 11 },
	DiagnosticInfo = { ctermfg = 12 },
	DiagnosticHint = { ctermfg = 14 },
}

for group, opts in pairs(highlights) do
	vim.api.nvim_set_hl(0, group, opts)
end
