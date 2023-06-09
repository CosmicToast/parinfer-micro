VERSION = '0.1.0'
-- TODO: tabstops

local micro  = import 'micro'
local config = import 'micro/config'
local util   = import 'micro/util'

-- sadly require doesn't seem to work
config.AddRuntimeFile("parinfer", config.RTPlugin, "parinfer-lua/parinfer.lua")
local parinfer_src = config.ReadRuntimeFile(config.RTPlugin, "parinfer")
local parinfer
if _VERSION == 'Lua 5.1' then -- futureproof in case gopher-lua does >5.1
	parinfer = loadstring(parinfer_src)()
else
	parinfer = load(parinfer_src)()
end
micro.Log(parinfer.version)

-- options
-- note that parinfer.enabled as a setlocal is meant for disabling, not enabling, due to autoclose
config.RegisterCommonOption("parinfer", "enabled", true)
config.RegisterCommonOption("parinfer", "filetypes", {'janet', 'lisp'})
-- smart mode false by default, it may have bugs
config.RegisterCommonOption("parinfer", "smart", false)
local function isEnabled(b)
	-- globally disabled
	if not b.Settings["parinfer.enabled"] then return false end
	local ft = b:FileType()
	-- unspecified filetype, just checking for the global option
	if not ft then return true end
	-- is it in the set of filetypes?
	for _, v in b.Settings["parinfer.filetypes"]() do
		if v == ft then return true end
	end
	-- it's disabled due to no matching filetypes
	return false
end
local function isSmart(b)
	return b.Settings["parinfer.smart"]
end

local oldcur = nil
-- can't use indexes because tableSize uses pairs
local changes = setmetatable({}, {min=10, max=20})
local function run(bp, lineindent)
	local b = bp.Buf
	if not isEnabled(bp.Buf) then return false end
	micro.Log("ran")

	local old = util.String(b:Bytes())
	local cur = b:GetActiveCursor()

	local options = {
		cursorLine = cur.Y + 1,
		cursorX    = cur.X + 1,
	}

	if oldcur ~= nil then
		options.prevCursorLine = oldcur.Y + 1
		options.prevCursorX    = oldcur.X + 1
	end
	oldcur = cur

	if #changes > 0 then
		options.changes = changes
	end

	local new
	if isSmart(b) then
		new = parinfer.smartMode(old, options)
	else
		if lineindent == nil then
			options.partialResult = true
			new = parinfer.parenMode(old, options)
		else
			new = parinfer.indentMode(old, options)
		end
	end

	if #changes == getmetatable(changes).max then
		repeat
			table.remove(changes, 1)
		until #changes == getmetatable(changes).min
	end
	table.insert(changes, {
		x       = cur.X + 1,
		lineNo  = cur.Y + 1,
		oldText = old,
		newText = new.text,
	})

	b:ApplyDiff(new.text)
	if new.cursorX ~= cur.X or new.cursorLine ~= cur.Y then
		cur.X = new.cursorX    - 1
		cur.Y = new.cursorLine - 1
	end
	return false
end

function onBufferOpen(b)
	if not isEnabled(b) then return end
	b:SetOption('autoclose',  'false')
	-- run paren mode before indentmode
	local old = util.String(b:Bytes())
	local new = parinfer.parenMode(old)
	b:ApplyDiff(new.text)
end

function onInsertNewline(b)
	run(b, true)
end
onRune             = run
onCursorUp         = run
onCursorDown       = run
onCursorPageDown   = run
onCursorLeft       = run
onCursorRight      = run
onIndentSelection  = run
onOutdentSelection = run
onOutdentLine      = run
onIndentLine       = run
onDeleteWordLeft   = run
onDeleteWordRight  = run
onDelete           = run
onDeleteLine       = run
onBackspace        = run
onInsertNewline    = run
onInsertTab        = run
