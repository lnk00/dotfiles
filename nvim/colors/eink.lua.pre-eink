-- e-ink for Neovim -- an E Ink Carta panel simulated on an emissive display.
-- GENERATED from ~/.config/theme/eink.toml by build.py -- do not edit by hand
--
-- 4-bit panel: 16 gray levels, no more. Reflective, so the range stops at
-- 14.15:1 -- neither pure white nor pure black appears. Paper is matched
-- to the desktop wallpaper exactly; the warm cast tapers from chroma
-- 0.0217 at paper to 0.003 at ink, so the page is cream and the text on it
-- stays near-neutral, as on real stock. Large fills ghost on repaint, so
-- weight, rule and proofreader's mark carry signal instead of slabs.

vim.cmd.highlight("clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd.syntax("reset")
end

-- A 16-level ramp needs 24-bit colour; there is no 256-colour degradation of
-- this theme, and asking for one would mean inventing values off the ramp.
vim.o.termguicolors = true
vim.o.background = "light"
vim.g.colors_name = "eink"

-- 16-step Carta ramp: oklch(L 0.275 -> 0.9847, C 0.0217, h 92.5).
--
--   ink        L0   #282826  14.15:1  AAA
--   charcoal   L2   #41403c   9.94:1  AAA
--   slate      L4   #5b5954   6.70:1  AA
--   muted      L5   #686661   5.49:1  AA
--   faint      L9   #a29f95   2.54:1  decoration
--   rule       L11  #c0bcb0   1.82:1  decoration
--   selection  L12  #cfcbbf   1.55:1  decoration
--   highlight  L13  #dfdbcd   1.33:1  decoration
--   cursorline L14  #efeadb   1.15:1  decoration
--   paper      L15  #fffaea  -------  the page itself
--   error      off  #833f39   7.35:1  AAA
--   warning    off  #8f6737   4.83:1  AA; always bold + dashed
--
-- The two accents are the only off-ramp values and the only hue in the
-- system, separated by luminance (1.52:1) so they survive being read
-- as pure gray.
local p = {
	ink = "#282826",
	charcoal = "#41403c",
	slate = "#5b5954",
	muted = "#686661",
	faint = "#a29f95",
	rule = "#c0bcb0",
	selection = "#cfcbbf",
	highlight = "#dfdbcd",
	cursorline = "#efeadb",
	paper = "#fffaea",
	error = "#833f39",
	warning = "#8f6737",
}

local groups = {
	-- Editor surface. Every panel is paper; separation is hairline and
	-- weight, never a second shade of gray behind a whole region.
	Normal = { fg = p.ink, bg = p.paper },
	NormalNC = { fg = p.ink, bg = p.paper },
	NormalFloat = { fg = p.ink, bg = p.paper },
	FloatBorder = { fg = p.rule, bg = p.paper },
	FloatTitle = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },
	FloatFooter = { fg = p.muted, bg = p.paper },
	WinSeparator = { fg = p.rule, bg = p.paper },
	VertSplit = { link = "WinSeparator" },
	EndOfBuffer = { fg = p.faint },
	Folded = { fg = p.slate, bg = p.cursorline, italic = true },
	FoldColumn = { fg = p.faint, bg = p.paper },
	SignColumn = { fg = p.muted, bg = p.paper },
	ColorColumn = { bg = p.cursorline },
	Conceal = { fg = p.faint },
	Directory = { fg = p.ink, bold = true },
	Title = { fg = p.ink, bold = true },
	Question = { fg = p.ink, bold = true },
	ModeMsg = { fg = p.ink, bold = true },
	MoreMsg = { fg = p.ink, bold = true },
	MsgArea = { fg = p.ink, bg = p.paper },
	MsgSeparator = { fg = p.rule, bg = p.paper },
	ErrorMsg = { fg = p.error, bold = true },
	WarningMsg = { fg = p.warning, bold = true },

	-- Whitespace marks sit at the decoration end of the ramp: present when
	-- looked for, invisible when read past.
	NonText = { fg = p.faint },
	Whitespace = { fg = p.faint },
	SpecialKey = { fg = p.faint },

	-- Gutter
	LineNr = { fg = p.muted, bg = p.paper },
	LineNrAbove = { fg = p.faint, bg = p.paper },
	LineNrBelow = { fg = p.faint, bg = p.paper },
	CursorLineNr = { fg = p.ink, bg = p.cursorline, bold = true },
	CursorLine = { bg = p.cursorline },
	CursorColumn = { bg = p.cursorline },
	CursorLineSign = { bg = p.cursorline },
	CursorLineFold = { bg = p.cursorline },

	-- A solid block is the one high-contrast element e-ink renders well: it
	-- reads as an inked mark rather than as a repaint.
	Cursor = { fg = p.paper, bg = p.ink },
	lCursor = { fg = p.paper, bg = p.ink },
	CursorIM = { fg = p.paper, bg = p.ink },
	TermCursor = { fg = p.paper, bg = p.ink },
	TermCursorNC = { fg = p.paper, bg = p.slate },

	-- Selection and search separate by fill weight, and text stays legible
	-- inside all of them. Only the search cursor inverts.
	Visual = { bg = p.selection },
	VisualNOS = { bg = p.highlight },
	Search = { fg = p.ink, bg = p.highlight },
	CurSearch = { fg = p.paper, bg = p.ink, bold = true },
	IncSearch = { fg = p.paper, bg = p.ink, bold = true },
	Substitute = { fg = p.ink, bg = p.selection, bold = true },
	MatchParen = { fg = p.ink, bg = p.highlight, bold = true },
	QuickFixLine = { bg = p.highlight, bold = true },
	SnippetTabstop = { fg = p.ink, bg = p.highlight },

	-- Statusline, tabline, winbar. Mode is a mark, not a fill: see the
	-- MiniStatusline groups at the bottom for the four styles.
	StatusLine = { fg = p.ink, bg = p.paper, bold = true },
	StatusLineNC = { fg = p.muted, bg = p.paper },
	StatusLineTerm = { link = "StatusLine" },
	StatusLineTermNC = { link = "StatusLineNC" },
	WinBar = { fg = p.ink, bg = p.paper, bold = true },
	WinBarNC = { fg = p.muted, bg = p.paper },
	TabLine = { fg = p.muted, bg = p.paper },
	TabLineFill = { bg = p.paper },
	TabLineSel = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },

	-- Completion menu. The selected row fills; the matched substring is
	-- marked with weight so it survives being read as pure gray.
	Pmenu = { fg = p.ink, bg = p.paper },
	PmenuSel = { fg = p.ink, bg = p.highlight, bold = true },
	PmenuKind = { fg = p.slate, bg = p.paper },
	PmenuKindSel = { fg = p.slate, bg = p.highlight },
	PmenuExtra = { fg = p.muted, bg = p.paper },
	PmenuExtraSel = { fg = p.muted, bg = p.highlight },
	PmenuMatch = { fg = p.ink, bg = p.paper, bold = true },
	PmenuMatchSel = { fg = p.ink, bg = p.highlight, bold = true },
	PmenuSbar = { bg = p.cursorline },
	PmenuThumb = { bg = p.rule },
	WildMenu = { link = "PmenuSel" },

	-- Spelling: style first, hue only where one exists.
	SpellBad = { sp = p.error, undercurl = true },
	SpellCap = { sp = p.slate, underdashed = true },
	SpellLocal = { sp = p.slate, underdotted = true },
	SpellRare = { sp = p.muted, underdotted = true },

	-- Diff windows. Added sits two ramp levels lighter than removed, the
	-- same weight ordering hunk and lazygit use, so the three states are
	-- ranked rather than merely different.
	DiffAdd = { bg = p.cursorline },
	DiffChange = { bg = p.highlight },
	DiffDelete = { fg = p.slate, bg = p.selection },
	DiffText = { bg = p.rule, bold = true },

	-- Diff TEXT, as opposed to diff windows: proofreader's marks, because
	-- there is no green or red to lean on and bold-vs-dim alone is too weak
	-- to scan down a gutter.
	diffAdded = { fg = p.ink, underline = true, sp = p.ink },
	diffRemoved = { fg = p.slate, strikethrough = true },
	diffChanged = { fg = p.charcoal, bold = true },
	diffNewFile = { fg = p.ink, bold = true },
	diffOldFile = { fg = p.slate, bold = true },
	diffFile = { fg = p.ink, bold = true },
	diffLine = { fg = p.muted },
	diffIndexLine = { fg = p.muted },
	Added = { fg = p.ink, bold = true },
	Removed = { fg = p.slate, bold = true },
	Changed = { fg = p.charcoal, bold = true },

	-- Diagnostics: underline style is the primary carrier, weight second,
	-- hue last. Read as gray, curl-vs-dash-vs-dot still tells them apart.
	DiagnosticError = { fg = p.error, bold = true },
	DiagnosticWarn = { fg = p.warning, bold = true },
	DiagnosticInfo = { fg = p.slate },
	DiagnosticHint = { fg = p.muted, italic = true },
	DiagnosticOk = { fg = p.charcoal },
	DiagnosticUnderlineError = { sp = p.error, undercurl = true },
	DiagnosticUnderlineWarn = { sp = p.warning, underdashed = true },
	DiagnosticUnderlineInfo = { sp = p.slate, underdotted = true },
	DiagnosticUnderlineHint = { sp = p.muted, underdotted = true },
	DiagnosticUnderlineOk = { sp = p.charcoal, underdotted = true },
	DiagnosticVirtualTextError = { fg = p.error, italic = true },
	DiagnosticVirtualTextWarn = { fg = p.warning, italic = true },
	DiagnosticVirtualTextInfo = { fg = p.slate, italic = true },
	DiagnosticVirtualTextHint = { fg = p.muted, italic = true },
	DiagnosticVirtualTextOk = { fg = p.charcoal, italic = true },
	DiagnosticFloatingError = { fg = p.error, bold = true },
	DiagnosticFloatingWarn = { fg = p.warning, bold = true },
	DiagnosticFloatingInfo = { fg = p.slate },
	DiagnosticFloatingHint = { fg = p.muted, italic = true },
	DiagnosticFloatingOk = { fg = p.charcoal },
	DiagnosticSignError = { fg = p.error, bg = p.paper, bold = true },
	DiagnosticSignWarn = { fg = p.warning, bg = p.paper, bold = true },
	DiagnosticSignInfo = { fg = p.slate, bg = p.paper },
	DiagnosticSignHint = { fg = p.muted, bg = p.paper },
	DiagnosticSignOk = { fg = p.charcoal, bg = p.paper },
	DiagnosticDeprecated = { fg = p.slate, strikethrough = true },
	DiagnosticUnnecessary = { fg = p.muted, italic = true },

	-- LSP
	LspReferenceText = { bg = p.highlight },
	LspReferenceRead = { bg = p.highlight },
	LspReferenceWrite = { bg = p.selection, bold = true },
	LspReferenceTarget = { bg = p.highlight },
	LspSignatureActiveParameter = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	LspInlayHint = { fg = p.muted, bg = p.paper, italic = true },
	LspCodeLens = { fg = p.muted, italic = true },
	LspCodeLensSeparator = { fg = p.rule },
	LspInfoBorder = { fg = p.rule, bg = p.paper },

	-- Syntax, legacy vocabulary. Hierarchy comes from four text tones plus
	-- bold and italic; there is no fifth tone and no hue.
	Comment = { fg = p.muted, italic = true },
	Constant = { fg = p.charcoal, bold = true },
	String = { fg = p.charcoal },
	Character = { fg = p.charcoal },
	Number = { fg = p.charcoal },
	Float = { fg = p.charcoal },
	Boolean = { fg = p.charcoal, bold = true },
	Identifier = { fg = p.ink },
	Function = { fg = p.ink, bold = true },
	Statement = { fg = p.ink, bold = true },
	Conditional = { fg = p.ink, bold = true },
	Repeat = { fg = p.ink, bold = true },
	Label = { fg = p.ink, bold = true },
	Operator = { fg = p.charcoal, bold = true },
	Keyword = { fg = p.ink, bold = true },
	Exception = { fg = p.ink, bold = true },
	PreProc = { fg = p.charcoal, bold = true },
	Include = { fg = p.charcoal, bold = true, italic = true },
	Define = { fg = p.charcoal, bold = true },
	Macro = { fg = p.charcoal, bold = true, italic = true },
	PreCondit = { fg = p.charcoal, bold = true },
	Type = { fg = p.ink, bold = true },
	StorageClass = { fg = p.ink, bold = true },
	Structure = { fg = p.ink, bold = true },
	Typedef = { fg = p.ink, bold = true },
	Special = { fg = p.ink, bold = true },
	SpecialChar = { fg = p.ink, bold = true },
	Tag = { fg = p.ink, bold = true },
	Delimiter = { fg = p.slate },
	SpecialComment = { fg = p.slate, bold = true, italic = true },
	Debug = { fg = p.warning, bold = true },
	Underlined = { underline = true, sp = p.rule },
	Ignore = { fg = p.faint },
	Error = { fg = p.error, bold = true },
	Todo = { fg = p.ink, bg = p.highlight, bold = true },

	-- Syntax, treesitter vocabulary. Mirrors the Helix scope table one to
	-- one, so the same file reads identically in either editor.
	["@variable"] = { fg = p.ink },
	["@variable.builtin"] = { fg = p.charcoal, italic = true },
	["@variable.parameter"] = { fg = p.charcoal, italic = true },
	["@variable.parameter.builtin"] = { fg = p.charcoal, italic = true },
	["@variable.member"] = { fg = p.charcoal },
	["@constant"] = { fg = p.charcoal, bold = true },
	["@constant.builtin"] = { fg = p.ink, bold = true, italic = true },
	["@constant.macro"] = { fg = p.charcoal, bold = true },
	["@module"] = { fg = p.charcoal, italic = true },
	["@module.builtin"] = { fg = p.charcoal, bold = true, italic = true },
	["@label"] = { fg = p.ink, bold = true },
	["@string"] = { fg = p.charcoal },
	["@string.documentation"] = { fg = p.slate, italic = true },
	["@string.regexp"] = { fg = p.ink, italic = true },
	["@string.escape"] = { fg = p.ink, bold = true },
	["@string.special"] = { fg = p.ink, bold = true },
	["@string.special.symbol"] = { fg = p.charcoal },
	["@string.special.path"] = { fg = p.charcoal, italic = true },
	["@string.special.url"] = { fg = p.ink, underline = true, sp = p.ink },
	["@character"] = { fg = p.charcoal },
	["@character.special"] = { fg = p.ink, bold = true },
	["@boolean"] = { fg = p.charcoal, bold = true },
	["@number"] = { fg = p.charcoal },
	["@number.float"] = { fg = p.charcoal },
	["@type"] = { fg = p.ink, bold = true },
	["@type.builtin"] = { fg = p.ink, bold = true, italic = true },
	["@type.definition"] = { fg = p.ink, bold = true },
	["@attribute"] = { fg = p.charcoal, italic = true },
	["@attribute.builtin"] = { fg = p.charcoal, italic = true },
	["@property"] = { fg = p.charcoal },
	["@function"] = { fg = p.ink, bold = true },
	["@function.builtin"] = { fg = p.charcoal, bold = true, italic = true },
	["@function.call"] = { fg = p.ink, bold = true },
	["@function.macro"] = { fg = p.charcoal, bold = true, italic = true },
	["@function.method"] = { fg = p.ink, bold = true },
	["@function.method.call"] = { fg = p.ink, bold = true },
	["@constructor"] = { fg = p.ink, bold = true },
	["@operator"] = { fg = p.charcoal, bold = true },
	["@keyword"] = { fg = p.ink, bold = true },
	["@keyword.coroutine"] = { fg = p.ink, bold = true },
	["@keyword.function"] = { fg = p.ink, bold = true, italic = true },
	["@keyword.operator"] = { fg = p.charcoal, bold = true },
	["@keyword.import"] = { fg = p.charcoal, bold = true, italic = true },
	["@keyword.type"] = { fg = p.ink, bold = true },
	["@keyword.modifier"] = { fg = p.ink, bold = true },
	["@keyword.repeat"] = { fg = p.ink, bold = true },
	["@keyword.return"] = { fg = p.ink, bold = true },
	["@keyword.debug"] = { fg = p.warning, bold = true },
	["@keyword.exception"] = { fg = p.ink, bold = true },
	["@keyword.conditional"] = { fg = p.ink, bold = true },
	["@keyword.conditional.ternary"] = { fg = p.charcoal, bold = true },
	["@keyword.directive"] = { fg = p.charcoal, bold = true, italic = true },
	["@keyword.directive.define"] = { fg = p.charcoal, bold = true, italic = true },
	["@punctuation.delimiter"] = { fg = p.muted },
	["@punctuation.bracket"] = { fg = p.ink },
	["@punctuation.special"] = { fg = p.charcoal, bold = true },
	["@comment"] = { fg = p.muted, italic = true },
	["@comment.documentation"] = { fg = p.slate, italic = true },
	["@comment.error"] = { fg = p.error, bold = true },
	["@comment.warning"] = { fg = p.warning, bold = true },
	["@comment.todo"] = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	["@comment.note"] = { fg = p.slate, bold = true },
	["@tag"] = { fg = p.ink, bold = true },
	["@tag.builtin"] = { fg = p.ink, bold = true },
	["@tag.attribute"] = { fg = p.charcoal, italic = true },
	["@tag.delimiter"] = { fg = p.slate },

	-- Markup follows print convention: heading rank descends by weight,
	-- then by tone. Only rank 1 takes a rule under it.
	["@markup.heading"] = { fg = p.ink, bold = true },
	["@markup.heading.1"] = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	["@markup.heading.2"] = { fg = p.ink, bold = true },
	["@markup.heading.3"] = { fg = p.charcoal, bold = true },
	["@markup.heading.4"] = { fg = p.charcoal, bold = true, italic = true },
	["@markup.heading.5"] = { fg = p.slate, bold = true },
	["@markup.heading.6"] = { fg = p.slate, italic = true },
	["@markup.strong"] = { fg = p.ink, bold = true },
	["@markup.italic"] = { fg = p.charcoal, italic = true },
	["@markup.strikethrough"] = { fg = p.muted, strikethrough = true },
	["@markup.underline"] = { underline = true, sp = p.rule },
	["@markup.quote"] = { fg = p.slate, italic = true },
	["@markup.math"] = { fg = p.charcoal },
	["@markup.link"] = { fg = p.ink },
	["@markup.link.label"] = { fg = p.ink },
	["@markup.link.url"] = { fg = p.charcoal, underline = true, sp = p.rule },
	["@markup.raw"] = { fg = p.charcoal },
	["@markup.raw.block"] = { fg = p.charcoal },
	["@markup.list"] = { fg = p.slate, bold = true },
	["@markup.list.checked"] = { fg = p.ink, bold = true },
	["@markup.list.unchecked"] = { fg = p.muted },
	["@diff.plus"] = { fg = p.ink, underline = true, sp = p.ink },
	["@diff.minus"] = { fg = p.slate, strikethrough = true },
	["@diff.delta"] = { fg = p.charcoal, bold = true, underdotted = true, sp = p.charcoal },

	-- Semantic tokens. Neovim already links @lsp.type.* to the treesitter
	-- captures above; only the two that disagree with a parser are pinned.
	["@lsp.type.comment"] = {},
	["@lsp.mod.deprecated"] = { strikethrough = true },

	-- gitsigns. The gutter signs are "+", "~", "_" characters, so tone and
	-- weight are all that is left to rank them by.
	GitSignsAdd = { fg = p.ink, bg = p.paper, bold = true },
	GitSignsChange = { fg = p.charcoal, bg = p.paper, bold = true },
	GitSignsDelete = { fg = p.slate, bg = p.paper, bold = true },
	GitSignsTopdelete = { link = "GitSignsDelete" },
	GitSignsChangedelete = { link = "GitSignsChange" },
	GitSignsUntracked = { fg = p.muted, bg = p.paper },
	GitSignsAddLn = { bg = p.cursorline },
	GitSignsChangeLn = { bg = p.highlight },
	GitSignsDeleteLn = { bg = p.selection },
	GitSignsAddInline = { bg = p.highlight },
	GitSignsChangeInline = { bg = p.highlight },
	GitSignsDeleteInline = { bg = p.selection, strikethrough = true },
	GitSignsCurrentLineBlame = { fg = p.faint, italic = true },

	-- telescope. Borders are square (set in init.lua), so the rule tone is
	-- doing real work here.
	TelescopeNormal = { fg = p.ink, bg = p.paper },
	TelescopeBorder = { fg = p.rule, bg = p.paper },
	TelescopePromptNormal = { fg = p.ink, bg = p.paper },
	TelescopePromptBorder = { fg = p.rule, bg = p.paper },
	TelescopePromptPrefix = { fg = p.ink, bold = true },
	TelescopePromptCounter = { fg = p.muted },
	TelescopeTitle = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },
	TelescopePromptTitle = { link = "TelescopeTitle" },
	TelescopeResultsTitle = { link = "TelescopeTitle" },
	TelescopePreviewTitle = { link = "TelescopeTitle" },
	TelescopeSelection = { fg = p.ink, bg = p.highlight, bold = true },
	TelescopeSelectionCaret = { fg = p.ink, bg = p.highlight, bold = true },
	TelescopeMultiSelection = { fg = p.ink, bg = p.selection },
	TelescopeMultiIcon = { fg = p.ink, bold = true },
	TelescopeMatching = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	TelescopePreviewLine = { bg = p.cursorline },
	TelescopeResultsComment = { fg = p.muted, italic = true },
	TelescopeResultsDiffAdd = { fg = p.ink, bold = true },
	TelescopeResultsDiffChange = { fg = p.charcoal, bold = true },
	TelescopeResultsDiffDelete = { fg = p.slate, bold = true },
	TelescopeResultsDiffUntracked = { fg = p.muted },

	-- which-key
	WhichKey = { fg = p.ink, bold = true },
	WhichKeyGroup = { fg = p.charcoal, bold = true },
	WhichKeyDesc = { fg = p.ink },
	WhichKeySeparator = { fg = p.rule },
	WhichKeyValue = { fg = p.muted },
	WhichKeyIcon = { fg = p.slate },
	WhichKeyNormal = { fg = p.ink, bg = p.paper },
	WhichKeyBorder = { fg = p.rule, bg = p.paper },
	WhichKeyTitle = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },

	-- oil
	OilDir = { fg = p.ink, bold = true },
	OilDirIcon = { fg = p.slate },
	OilFile = { fg = p.ink },
	OilLink = { fg = p.slate, italic = true },
	OilLinkTarget = { fg = p.slate, italic = true },
	OilSocket = { fg = p.charcoal, italic = true },
	OilCreate = { fg = p.ink, bold = true },
	OilCopy = { fg = p.charcoal, bold = true },
	OilMove = { fg = p.charcoal, bold = true },
	OilChange = { fg = p.charcoal, bold = true },
	OilDelete = { fg = p.slate, bold = true, strikethrough = true },
	OilPurge = { fg = p.error, bold = true },
	OilTrash = { fg = p.slate, bold = true },
	OilTrashSourcePath = { fg = p.muted, italic = true },
	OilRestore = { fg = p.ink, bold = true },

	-- fidget
	FidgetTitle = { fg = p.ink, bold = true },
	FidgetTask = { fg = p.muted },

	-- mason
	MasonHeader = { fg = p.paper, bg = p.ink, bold = true },
	MasonHeaderSecondary = { fg = p.paper, bg = p.slate, bold = true },
	MasonHighlight = { fg = p.ink, bold = true },
	MasonHighlightBlock = { fg = p.ink, bg = p.highlight, bold = true },
	MasonHighlightBlockBold = { fg = p.ink, bg = p.selection, bold = true },
	MasonMuted = { fg = p.muted },
	MasonMutedBlock = { fg = p.slate, bg = p.cursorline },
	MasonError = { fg = p.error, bold = true },
	MasonWarning = { fg = p.warning, bold = true },
	MasonHeading = { fg = p.ink, bold = true, underline = true, sp = p.ink },

	-- mini.statusline. The mode chip repaints on every mode switch, which is
	-- exactly the small high-frequency fill that ghosts, so mode is carried
	-- by underline STYLE on paper -- the same trick the Helix statusline
	-- uses, extended to cover Neovim's six modes.
	MiniStatuslineModeNormal = { fg = p.ink, bg = p.paper, bold = true },
	MiniStatuslineModeInsert = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },
	MiniStatuslineModeVisual = { fg = p.ink, bg = p.paper, bold = true, italic = true },
	MiniStatuslineModeReplace = { fg = p.ink, bg = p.paper, bold = true, undercurl = true, sp = p.ink },
	MiniStatuslineModeCommand = { fg = p.ink, bg = p.paper, bold = true, underdouble = true, sp = p.ink },
	MiniStatuslineModeOther = { fg = p.ink, bg = p.paper, bold = true, underdotted = true, sp = p.ink },
	MiniStatuslineDevinfo = { fg = p.slate, bg = p.paper },
	MiniStatuslineFilename = { fg = p.charcoal, bg = p.paper },
	MiniStatuslineFileinfo = { fg = p.muted, bg = p.paper },
	MiniStatuslineInactive = { fg = p.muted, bg = p.paper },

	-- mini.surround / mini.icons. The icon groups are named after hues this
	-- palette does not have; each is folded onto the nearest text tone so a
	-- nerd font cannot smuggle colour back in.
	MiniSurround = { fg = p.ink, bg = p.highlight, bold = true },
	MiniIconsAzure = { fg = p.slate },
	MiniIconsBlue = { fg = p.slate },
	MiniIconsCyan = { fg = p.slate },
	MiniIconsGreen = { fg = p.charcoal },
	MiniIconsGrey = { fg = p.muted },
	MiniIconsOrange = { fg = p.charcoal },
	MiniIconsPurple = { fg = p.charcoal },
	MiniIconsRed = { fg = p.ink },
	MiniIconsYellow = { fg = p.slate },
}

for group, spec in pairs(groups) do
	vim.api.nvim_set_hl(0, group, spec)
end

-- todo-comments is deliberately absent: its TODO/FIX/NOTE groups are derived
-- from the Diagnostic* groups above, so it follows the palette on its own.
-- It is set to `keyword = "wide_fg"` in init.lua for the same reason every
-- other surface here avoids fills -- a coloured slab behind a keyword is the
-- one thing a panel repaints worst.

-- :terminal, bound to the same ANSI table Ghostty gets, so a command run
-- inside Neovim and the same command run in the bare terminal are coloured
-- identically.
vim.g.terminal_color_0 = "#282826"
vim.g.terminal_color_1 = "#833f39"
vim.g.terminal_color_2 = "#41403c"
vim.g.terminal_color_3 = "#8f6737"
vim.g.terminal_color_4 = "#5b5954"
vim.g.terminal_color_5 = "#41403c"
vim.g.terminal_color_6 = "#5b5954"
vim.g.terminal_color_7 = "#c0bcb0"
vim.g.terminal_color_8 = "#686661"
vim.g.terminal_color_9 = "#833f39"
vim.g.terminal_color_10 = "#282826"
vim.g.terminal_color_11 = "#8f6737"
vim.g.terminal_color_12 = "#282826"
vim.g.terminal_color_13 = "#5b5954"
vim.g.terminal_color_14 = "#686661"
vim.g.terminal_color_15 = "#282826"
