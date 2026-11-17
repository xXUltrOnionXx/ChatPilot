local _, ns = ...

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

function ns.Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9ffChatPilot|r: " .. msg)
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
