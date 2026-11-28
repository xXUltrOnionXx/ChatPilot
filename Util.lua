local _, ns = ...

-- Problems are kept (and told once) instead of vanishing silently.
-- ns.errors: this session's short list. ns.db.errorLog: saved list with counts, so a
-- problem that happened yesterday can still be looked at (debug button / /chatpilot errors).
ns.errors = {}
local ERR_KEEP = 30

local function Store(kind, where, msg, stack)
	local log
	if ns.db then
		ns.db.errorLog = ns.db.errorLog or {}
		log = ns.db.errorLog
		if ns._errBuf then
			for _, e in ipairs(ns._errBuf) do log[#log + 1] = e end
			ns._errBuf = nil
		end
	else
		ns._errBuf = ns._errBuf or {}
		log = ns._errBuf
	end
	local key = kind .. "|" .. where .. "|" .. msg:sub(1, 160)
	for _, e in ipairs(log) do
		if e.key == key then
			e.count = (e.count or 1) + 1
			e.last = time()
			return
		end
	end
	log[#log + 1] = { key = key, kind = kind, where = where, msg = msg, stack = stack, count = 1, first = time(), last = time(), ver = ns.version }
	while #log > ERR_KEEP do table.remove(log, 1) end
end

local function Told()
	if ns.UpdateDebugBadge then pcall(ns.UpdateDebugBadge) end
	if not ns.errorTold and ns.Print then
		ns.errorTold = true
		ns.Print(ns.L and ns.L.ERR_TOLD or "A problem was caught. Type /chatpilot errors to see it.")
	end
end

function ns.ReportError(where, err)
	local list = ns.errors
	local msg = tostring(err):gsub("|", "||"):sub(1, 300)
	list[#list + 1] = date("%H:%M:%S") .. " " .. where .. ": " .. msg
	if #list > 20 then table.remove(list, 1) end
	pcall(Store, "caught", where, msg)
	Told()
end

-- The saved list (oldest first)
function ns.ErrorLog()
	local out = {}
	for _, e in ipairs(ns.db and ns.db.errorLog or {}) do out[#out + 1] = e end
	for _, e in ipairs(ns._errBuf or {}) do out[#out + 1] = e end
	return out
end

function ns.ErrorClear()
	if ns.db then ns.db.errorLog = {} end
	ns._errBuf = nil
	wipe(ns.errors)
	ns.errorTold = nil
	if ns.UpdateDebugBadge then pcall(ns.UpdateDebugBadge) end
end

-- Every Lua error that comes from ChatPilot's own files is noted automatically (the
-- game's normal error handling still runs afterwards, nothing is hidden or swallowed).
local function IsOurs(text)
	return text:find("ChatPilot[/\\][%w_]+%.lua") ~= nil
end

local function Capture(err)
	if ns.IsSecret and ns.IsSecret(err) then return end
	local text = tostring(err)
	if not IsOurs(text) then return end
	local stack
	if debugstack then
		local okS, s = pcall(debugstack, 3, 8, 0)
		if okS and type(s) == "string" then stack = s:sub(1, 700) end
	end
	Store("lua", "error", text:gsub("|", "||"):sub(1, 400), stack)
	Told()
end

local handlerFrame = CreateFrame("Frame")
local function Install()
	if not (geterrorhandler and seterrorhandler) then return end
	local cur = geterrorhandler()
	if cur == ns._errHandler then return end
	local prev = cur
	local function ours(err)
		pcall(Capture, err)
		if prev then return prev(err) end
	end
	ns._errHandler = ours
	seterrorhandler(ours)
end
ns.InstallErrorHandler = Install
handlerFrame:RegisterEvent("PLAYER_LOGIN")
handlerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
handlerFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
handlerFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
handlerFrame:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		if a1 == "ChatPilot" then
			local okB = pcall(Store, "blocked", event:gsub("ADDON_ACTION_", ""):lower(), tostring(a2 or "?"))
			if okB then Told() end
		end
		return
	end
	Install()
end)
-- other addons may replace the handler later: look again now and then
local recheck = 0
handlerFrame:SetScript("OnUpdate", function(_, e)
	recheck = recheck + e
	if recheck < 60 then return end
	recheck = 0
	Install()
end)
Install()

-- Midnight-era clients can hand addons "secret" values (e.g. chat text in
-- restricted situations). Those must never be inspected, so every handler
-- checks them first and simply does nothing if a value is secret.
local issecret = issecretvalue or function() return false end
ns.IsSecret = issecret

function ns.Usable(...)
	for i = 1, select("#", ...) do
		if issecret((select(i, ...))) then return false end
	end
	return true
end

-- A yes/no value from the game that may be restricted ("secret") at the moment: a secret
-- value cannot be tested, so the caller says what to assume then.
function ns.SafeBool(v, whenSecret)
	if issecret(v) then return whenSecret and true or false end
	return v and true or false
end

function ns.Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9ffChatPilot Forever|r: " .. msg)
end

-- A "word byte" is an ASCII letter/digit or any byte of a UTF-8 multibyte
-- character (so names like "Jäger" are treated as one word).
local function IsWordByte(b)
	return b ~= nil and (b >= 128 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122))
end

-- Finds `word` (already lower case) as a whole word in `text` (already lower case).
function ns.FindWord(text, word, init)
	if word == "" then return nil end
	init = init or 1
	while true do
		local s, e = text:find(word, init, true)
		if not s then return nil end
		if not IsWordByte(text:byte(s - 1)) and not IsWordByte(text:byte(e + 1)) then
			return s, e
		end
		init = s + 1
	end
end

-- Escape sequences that must never be modified (links, textures, colors ...).
local ESCAPES = {
	"^|H.-|h.-|h",
	"^|T.-|t",
	"^|A.-|a",
	"^|K.-|k",
	"^|c%x%x%x%x%x%x%x%x",
	"^|cn[^:|]*:",
	"^|r",
	"^||",
}

-- Splits a chat message into { isPlain, text } parts.
function ns.SplitMessage(msg)
	local parts, pos, bufStart, len = {}, 1, 1, #msg
	while true do
		local p = msg:find("|", pos, true)
		if not p then break end
		local stop
		for i = 1, #ESCAPES do
			local _, e = msg:find(ESCAPES[i], p)
			if e then stop = e break end
		end
		if stop then
			if p > bufStart then parts[#parts + 1] = { true, msg:sub(bufStart, p - 1) } end
			parts[#parts + 1] = { false, msg:sub(p, stop) }
			pos = stop + 1
			bufStart = pos
		else
			pos = p + 1
		end
	end
	if bufStart <= len then parts[#parts + 1] = { true, msg:sub(bufStart) } end
	return parts
end

-- Removes formatting so text can be read/copied as plain text.
function ns.StripEscapes(text)
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|A.-|a", "")
	text = text:gsub("|K.-|k", "?")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|cn[^:|]*:", "")
	text = text:gsub("|r", "")
	text = text:gsub("||", "|")
	return text
end

function ns.ClassColorText(text, classFile)
	local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if c then
		return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, text)
	end
	return text
end

-- Calls fn for every chat frame, including whisper windows opened later.
local chatFrameCallbacks, seenFrames = {}, {}
local function VisitFrame(frame)
	if not frame or seenFrames[frame] then return end
	seenFrames[frame] = true
	for _, fn in ipairs(chatFrameCallbacks) do pcall(fn, frame) end
end

function ns.ScanChatFrames()
	if CHAT_FRAMES then
		for _, name in ipairs(CHAT_FRAMES) do VisitFrame(_G[name]) end
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do VisitFrame(_G["ChatFrame" .. i]) end
end

function ns.OnChatFrame(fn)
	chatFrameCallbacks[#chatFrameCallbacks + 1] = fn
	for frame in pairs(seenFrames) do pcall(fn, frame) end
end

if type(FCF_OpenTemporaryWindow) == "function" then
	hooksecurefunc("FCF_OpenTemporaryWindow", function() ns.ScanChatFrames() end)
end
