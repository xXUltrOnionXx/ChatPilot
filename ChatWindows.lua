local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- ChatPilot's own chat windows. Each window shows only the kinds of chat you
-- pick (whispers, guild, say, General ...). Windows can be moved freely,
-- docked together as tabs (drop one onto the title bar of another) and snap
-- onto the top of the main chat window. They only display messages.

local HEADER_H = 24
local MIN_W, MIN_H, MAX_W, MAX_H = 220, 110, 900, 700
local MAX_SAVED_LINES = 200
local MAX_ARCHIVE = 3000 -- older lines of a window, kept as plain text

-------------------------------------------------------------------------------
-- Categories
-------------------------------------------------------------------------------
local CATS = {
	{ key = "whisper", events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" } },
	{ key = "guild", events = { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_GUILD_ACHIEVEMENT" } },
	{ key = "party", events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" } },
	{ key = "raid", events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" } },
	{ key = "say", events = { "CHAT_MSG_SAY" } },
	{ key = "yell", events = { "CHAT_MSG_YELL" } },
	{ key = "emote", events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" } },
	{ key = "general", channel = true },
	{ key = "trade", channel = true },
	{ key = "channels", channel = true },
	{ key = "community", events = { "CHAT_MSG_COMMUNITIES_CHANNEL" } },
	{ key = "system", events = { "CHAT_MSG_SYSTEM" } },
	{ key = "presence", events = {} }, -- "X has come online." / "X has gone offline." (arrives as a system message)
}
ns.CW_CATS = CATS
local EVENT_CAT = {}
for _, c in ipairs(CATS) do
	for _, ev in ipairs(c.events or {}) do EVENT_CAT[ev] = c.key end
end

local function ChannelCat(zoneChannelID, channelNumber)
	if zoneChannelID == 1 or (not zoneChannelID or zoneChannelID == 0) and channelNumber == 1 then return "general" end
	if zoneChannelID == 2 or (not zoneChannelID or zoneChannelID == 0) and channelNumber == 2 then return "trade" end
	return "channels"
end

-------------------------------------------------------------------------------
-- Formatting a chat event into one line (like the normal chat does)
-------------------------------------------------------------------------------
local FORMATS = {
	SAY = "CHAT_SAY_GET", YELL = "CHAT_YELL_GET", EMOTE = "CHAT_EMOTE_GET",
	WHISPER = "CHAT_WHISPER_GET", WHISPER_INFORM = "CHAT_WHISPER_INFORM_GET",
	BN_WHISPER = "CHAT_BN_WHISPER_GET", BN_WHISPER_INFORM = "CHAT_BN_WHISPER_INFORM_GET",
	GUILD = "CHAT_GUILD_GET", OFFICER = "CHAT_OFFICER_GET",
	PARTY = "CHAT_PARTY_GET", PARTY_LEADER = "CHAT_PARTY_LEADER_GET",
	RAID = "CHAT_RAID_GET", RAID_LEADER = "CHAT_RAID_LEADER_GET", RAID_WARNING = "CHAT_RAID_WARNING_GET",
	INSTANCE_CHAT = "CHAT_INSTANCE_CHAT_GET", INSTANCE_CHAT_LEADER = "CHAT_INSTANCE_CHAT_LEADER_GET",
}
local FALLBACK = {
	SAY = "%s: ", YELL = "%s: ", EMOTE = "%s ", WHISPER = "%s: ", WHISPER_INFORM = "> %s: ",
	BN_WHISPER = "%s: ", BN_WHISPER_INFORM = "> %s: ",
	GUILD = "[G] %s: ", OFFICER = "[O] %s: ", PARTY = "[P] %s: ", PARTY_LEADER = "[P] %s: ",
	RAID = "[R] %s: ", RAID_LEADER = "[R] %s: ", RAID_WARNING = "[RW] %s: ",
	INSTANCE_CHAT = "[I] %s: ", INSTANCE_CHAT_LEADER = "[I] %s: ",
}

local function TypeColor(chatType, channelNumber)
	local info = ChatTypeInfo and (chatType == "CHANNEL" and channelNumber and ChatTypeInfo["CHANNEL" .. channelNumber] or ChatTypeInfo[chatType])
	if info and info.r then return info.r, info.g, info.b end
	return 1, 1, 1
end

local function Timestamp()
	local fmt = CHAT_TIMESTAMP_FORMAT
	if type(fmt) == "string" and fmt ~= "" and BetterDate then
		local ok, s = pcall(BetterDate, fmt, time())
		if ok and s then return UI.Hex(C.muted) .. s .. "|r" end
	end
	return ""
end

local function ResolveChannel(channelString, baseName)
	local resolve = ChatFrame_ResolveChannelName or (ChatFrameUtil and ChatFrameUtil.ResolveChannelName)
	if resolve and channelString then
		local ok, name = pcall(resolve, channelString)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	if type(baseName) == "string" and baseName ~= "" then return baseName end
	return channelString or "?"
end

local styleOwn = false -- set while formatting one of your own messages

local function PlayerLink(chatType, author, lineID, guid, bnID, channelNumber)
	if styleOwn and not chatType:find("_INFORM$") then
		return ("|Hplayer:%s:%s:%s:|h[%s]|h"):format(author, tostring(lineID or 0), chatType, UI.Hex(C.accent) .. L.WH_YOU .. "|r")
	end
	if chatType:find("^BN_") then
		return ("|HBNplayer:%s:%s:%s:%s:%s|h[%s]|h"):format(author, tostring(bnID or 0), tostring(lineID or 0),
			chatType, author, author)
	end
	local short = Ambiguate and Ambiguate(author, "none") or author
	local class
	if guid and guid ~= "" and GetPlayerInfoByGUID then
		local ok, _, englishClass = pcall(GetPlayerInfoByGUID, guid)
		if ok then class = englishClass end
	end
	local target = chatType == "CHANNEL" and tostring(channelNumber or "") or ""
	return ("|Hplayer:%s:%s:%s:%s|h[%s]|h"):format(author, tostring(lineID or 0), chatType, target,
		ns.ClassColorText(short, class))
end

local function Format(event, msg, author, language, channelString, target, flags, zoneChannelID,
	channelNumber, baseName, languageID, lineID, guid, bnID)
	local chatType = event:sub(10)
	local r, g, b = TypeColor(chatType, channelNumber)
	local ts = Timestamp()
	ts = ts ~= "" and (ts .. " ") or ""

	if chatType == "SYSTEM" or chatType == "TEXT_EMOTE" then
		return ts .. msg, r, g, b
	end
	local link = (author and author ~= "") and PlayerLink(chatType, author, lineID, guid, bnID, channelNumber) or ""
	if chatType == "GUILD_ACHIEVEMENT" then
		local ok, out = pcall(string.format, msg, link)
		return ts .. (ok and out or msg), r, g, b
	end

	local prefix
	if chatType == "CHANNEL" then
		local cname = (type(baseName) == "string" and baseName ~= "") and baseName or ResolveChannel(channelString, baseName)
		prefix = ("[%s. %s] %%s: "):format(tostring(channelNumber or "?"), (tostring(cname):gsub("%%", "%%%%")))
	elseif chatType == "COMMUNITIES_CHANNEL" then
		prefix = "[" .. (tostring(ResolveChannel(channelString, baseName)):gsub("%%", "%%%%")) .. "] %s: "
	else
		local global = FORMATS[chatType] and _G[FORMATS[chatType]]
		prefix = type(global) == "string" and global or FALLBACK[chatType] or "%s: "
	end
	local lang = ""
	if type(language) == "string" and language ~= "" and GetDefaultLanguage
		and language ~= GetDefaultLanguage("player") and chatType ~= "EMOTE" then
		lang = "[" .. language .. "] "
	end
	local ok, head = pcall(string.format, prefix, link)
	if not ok then head = link .. ": " end
	local text = ts .. head .. lang .. msg
	if (ns.S.showLevels or ns.S.shortSurnames) and ns.AddLevels then
		local ok2, out = pcall(ns.AddLevels, text)
		if ok2 and out then text = out end
	end
	return text, r, g, b
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local wins, groups = {}, {}   -- runtime objects: wins[id], groups[list]
local Data                    -- ns.db.cwin
local menu                    -- filter menu (shared)
local dragging                -- group being dragged

local function WindowName(w)
	-- your own name for the tab wins
	local title = w.data.title
	if type(title) == "string" and title:match("%S") then return title end
	local partner = w.data.partner
	if partner then return "@" .. (partner.label or partner.name or "?") end
	local names = {}
	for _, c in ipairs(CATS) do
		if w.data.cats[c.key] then names[#names + 1] = L["CAT_" .. c.key] end
	end
	if #names == 0 then return L.CW_EMPTY end
	if #names > 2 then return names[1] .. ", " .. names[2] .. " +" .. (#names - 2) end
	return table.concat(names, ", ")
end

local function GroupData(g) return g.data end

local function Save(g)
	local f, d = g.frame, g.data
	if not f:GetLeft() then return end
	if not d.snap then
		d.x, d.y = math.floor(f:GetLeft() + 0.5), math.floor(f:GetTop() + 0.5)
	end
	d.w, d.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

local function MainChat()
	-- Blizzard hides the default frame when another dock tab is selected.
	-- Use the visible dock window for both drop detection and placement.
	local selected = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
	if selected and selected:IsVisible() then return selected end
	return DEFAULT_CHAT_FRAME or ChatFrame1
end

local UpdateLaunchers -- forward (tabs of windows docked into the main chat)

local function Place(g)
	local f, d = g.frame, g.data
	f:ClearAllPoints()
	local main = MainChat()
	if g.bg then UI.Paint(g.bg, (d.main and main) and C.bg or C.chatBg) end
	local docked = d.main and main and true or false
	-- Docked: the window is hung onto the chat itself, so it is always exactly
	-- one step above the chat (no flicker) - and bank, bags, vendors and other
	-- game windows still open on top of it as usual. Its size comes from the
	-- chat, so there is no resize grip.
	if g.grip then g.grip:SetShown(not docked) end
	if docked then
		local host = main
		f:SetToplevel(false)
		if f:GetParent() ~= host then f:SetParent(host) end
		f:SetFrameStrata(host.GetFrameStrata and host:GetFrameStrata() or "LOW")
		f:SetFrameLevel(((host.GetFrameLevel and host:GetFrameLevel()) or 1) + 20)
		-- docked into the main chat: lies exactly over it, opened by its tab
		f:SetPoint("TOPLEFT", host, "TOPLEFT", -4, 4)
		f:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 4, -6)
		f:SetShown(g.mainOpen and true or false)
		return
	end
	if f:GetParent() ~= UIParent then f:SetParent(UIParent) end
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	if d.snap and main then
		f:SetPoint("BOTTOMLEFT", main, "TOPLEFT", -4, 34)
		f:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 4, 34)
		f:SetHeight(d.h or 180)
	else
		f:SetSize(d.w or 360, d.h or 180)
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.x or 300, d.y or 500)
	end
end

-------------------------------------------------------------------------------
-- Writing: where a message typed in a window goes ("target")
-- Only text you type yourself and send with Enter is ever sent.
-------------------------------------------------------------------------------
local CAT_TARGETS = {
	guild = { { type = "GUILD" } },
	party = { { type = "PARTY" } },
	raid = { { type = "RAID" }, { type = "INSTANCE_CHAT" } },
	say = { { type = "SAY" } },
	yell = { { type = "YELL" } },
	emote = { { type = "EMOTE" } },
}
local TYPE_LABEL = {
	GUILD = "CAT_guild", OFFICER = "CAT_guild", PARTY = "CAT_party", RAID = "CAT_raid", INSTANCE_CHAT = "CAT_raid",
	SAY = "CAT_say", YELL = "CAT_yell", EMOTE = "CAT_emote",
}
local SLASH = { GUILD = "/g ", OFFICER = "/o ", PARTY = "/p ", RAID = "/ra ", INSTANCE_CHAT = "/i ",
	SAY = "/s ", YELL = "/y ", EMOTE = "/e " }

local function SameTarget(a, b)
	return a and b and a.type == b.type and a.name == b.name and a.number == b.number
end

local function ShortChannel(name)
	-- "2. Торговля - Москва" -> "Торговля". Plain byte comparisons only (no pattern classes),
	-- so letters of any alphabet and any system language behave the same.
	local full = tostring(name or "")
	local short = full
	local dot = short:find(".", 1, true)
	if dot and dot > 1 and dot <= 4 then
		local digits = true
		for i = 1, dot - 1 do
			local b = short:byte(i)
			if b < 48 or b > 57 then digits = false break end
		end
		if digits then
			local i = dot + 1
			while short:byte(i) == 32 or short:byte(i) == 9 do i = i + 1 end
			short = short:sub(i)
		end
	end
	local sep = short:find(" - ", 1, true)
	if sep and sep > 1 then short = short:sub(1, sep - 1) end
	return short ~= "" and short or full
end

local function TargetLabel(t)
	if not t then return L.CW_NO_TARGET end
	if t.type == "WHISPER" or t.type == "BN_WHISPER" then
		local n = t.type == "WHISPER" and Ambiguate and Ambiguate(t.name, "none") or t.name
		return "@" .. n
	elseif t.type == "CHANNEL" then
		-- "Allgemein - Sturmwind" -> "Allgemein" (short enough for the button)
		local n = ShortChannel(t.name or "")
		return tostring(t.number) .. ". " .. n
	end
	return L[TYPE_LABEL[t.type] or ""] or t.type
end

local function TargetColor(t)
	if not t then return 0.6, 0.6, 0.6 end
	local key = t.type == "CHANNEL" and ("CHANNEL" .. tostring(t.number)) or t.type
	local info = ChatTypeInfo and (ChatTypeInfo[key] or ChatTypeInfo[t.type])
	if info and info.r then return info.r, info.g, info.b end
	return 1, 1, 1
end

-- all places this window can write to: recent ones first, then by filter
local function Targets(w)
	local list = {}
	local function add(t)
		for _, o in ipairs(list) do if SameTarget(o, t) then return end end
		list[#list + 1] = t
	end
	for _, t in ipairs(w.recent or {}) do add(t) end
	for _, c in ipairs(CATS) do
		if w.data.cats[c.key] then
			for _, t in ipairs(CAT_TARGETS[c.key] or {}) do add(t) end
		end
	end
	return list
end

-- manual = chosen by you (button, /command, name click); otherwise it came
-- from a received message and becomes the automatic reply target
local function Remember(w, t, manual)
	w.recent = w.recent or {}
	for i, o in ipairs(w.recent) do
		if SameTarget(o, t) then table.remove(w.recent, i) break end
	end
	table.insert(w.recent, 1, t)
	while #w.recent > 8 do table.remove(w.recent) end
	if not manual then w.data.last = t end
end

-- target of a received message (so "reply" goes back where it came from)
local function TargetOf(event, author, channelNumber, baseName, bnID)
	local chatType = event:sub(10)
	if chatType == "WHISPER" or chatType == "WHISPER_INFORM" then
		return { type = "WHISPER", name = author }
	elseif chatType == "BN_WHISPER" or chatType == "BN_WHISPER_INFORM" then
		if bnID and bnID ~= 0 then return { type = "BN_WHISPER", name = author, id = bnID } end
	elseif chatType == "CHANNEL" then
		return { type = "CHANNEL", number = channelNumber, name = baseName }
	elseif chatType == "GUILD" or chatType == "OFFICER" or chatType == "PARTY" or chatType == "SAY" or chatType == "YELL" then
		return { type = chatType }
	elseif chatType == "PARTY_LEADER" then return { type = "PARTY" }
	elseif chatType == "RAID" or chatType == "RAID_LEADER" or chatType == "RAID_WARNING" then return { type = "RAID" }
	elseif chatType:find("^INSTANCE_CHAT") then return { type = "INSTANCE_CHAT" }
	end
end

local function Locked()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

-- hand the text to the game's own input box (slash commands, restricted times)
local function HandOver(t, text)
	local prefix = ""
	if t then
		if t.type == "WHISPER" then prefix = "/w " .. t.name .. " "
		elseif t.type == "CHANNEL" then prefix = "/" .. tostring(t.number) .. " "
		elseif SLASH[t.type] then prefix = SLASH[t.type] end
	end
	if text:sub(1, 1) == "/" then prefix = "" end
	local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
	if open then open(prefix .. text) end
end

local function Send(t, text)
	if t.type == "BN_WHISPER" then
		local bn = BNSendWhisper or (C_BattleNet and C_BattleNet.SendWhisper)
		if bn then bn(t.id, text) end
		return
	end
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return end
	if t.type == "WHISPER" then
		send(text, "WHISPER", nil, t.name)
	elseif t.type == "CHANNEL" then
		send(text, "CHANNEL", nil, t.number)
	else
		send(text, t.type)
	end
end

-------------------------------------------------------------------------------
-- Chat commands typed into a window ("/w Name ", "/g ", "/2 " ...): like the
-- game's own chat they turn into the target button, so the text you type next
-- stays in this window. Other /commands (e.g. /dance) go to the game's chat.
-------------------------------------------------------------------------------
local CMD_TYPE = {
	s = "SAY", say = "SAY", sagen = "SAY",
	y = "YELL", yell = "YELL", sh = "YELL", shout = "YELL", schreien = "YELL",
	g = "GUILD", gu = "GUILD", guild = "GUILD", gilde = "GUILD",
	o = "OFFICER", officer = "OFFICER", offizier = "OFFICER",
	p = "PARTY", party = "PARTY", gruppe = "PARTY",
	ra = "RAID", raid = "RAID", schlachtzug = "RAID",
	i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT", instanz = "INSTANCE_CHAT",
	e = "EMOTE", em = "EMOTE", emote = "EMOTE", me = "EMOTE",
}
local CMD_WHISPER = { w = true, whisper = true, t = true, tell = true, send = true,
	["flüstern"] = true, fl = true }
local CMD_REPLY = { r = true, reply = true, antworten = true }

local function ChannelTarget(n)
	n = tonumber(n)
	if not n then return nil end
	local name
	if GetChannelName then
		local ok, id, cname = pcall(GetChannelName, n)
		if ok and id and id ~= 0 then name = cname end
	end
	return { type = "CHANNEL", number = n, name = name or "" }
end

-- /r: like the game, the person who last whispered you (falls back to this window's last partner)
local function LastTell(w)
	local get = ChatEdit_GetLastTellTarget or (ChatFrameUtil and ChatFrameUtil.GetLastTellTarget)
	if get then
		local ok, name = pcall(get)
		if ok and type(name) == "string" and name ~= "" and ns.Usable(name) then return { type = "WHISPER", name = name } end
	end
	for _, t in ipairs(w and w.recent or {}) do
		if t.type == "WHISPER" or t.type == "BN_WHISPER" then return t end
	end
end

-- Parses the start of the input. complete = true means "Enter was pressed".
-- Returns target, rest-of-text   or nil when it is not a chat command we handle.
local function ParseCommand(w, text, complete)
	local cmd, after = text:match("^/(%S+)(.*)$")
	if not cmd then return nil end
	cmd = cmd:lower()
	if CMD_WHISPER[cmd] then
		local name, rest = after:match("^%s+(%S+)(.*)$")
		if not name then return nil end
		-- like the game: the name is taken once a space follows it (or on Enter)
		if rest == "" and not complete then return nil end
		return { type = "WHISPER", name = name }, (rest:gsub("^%s", ""))
	end
	local needSpace = not complete
	if needSpace and after:sub(1, 1) ~= " " then return nil end
	if after ~= "" and after:sub(1, 1) ~= " " then return nil end
	local rest = after:gsub("^%s", "")
	if CMD_REPLY[cmd] then
		local t = LastTell(w)
		if t then return t, rest end
		return nil
	end
	if CMD_TYPE[cmd] then return { type = CMD_TYPE[cmd] }, rest end
	if cmd:match("^%d+$") then
		local t = ChannelTarget(cmd)
		if t then return t, rest end
	end
	return nil
end

-- glowing light on a tab's unread dot: pulls in when it turns on, then breathes
local function DotGlow(btn, on)
	if not btn or not btn.dot then return end
	on = on and ns.S and ns.S.notifyGlow ~= false or false
	btn.orb = rawget(btn, "orb") or UI.Orb(btn.dot, 14, C.orange)
	local was = rawget(btn, "glowOn")
	btn.glowOn = on
	if on and not was then btn.orb:Pop() else btn.orb:SetActive(on) end
end

-------------------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------------------
local LayoutTabs, Select, StartDrag -- forward

-- Long tab names run slowly from left to right and back (like a news ticker),
-- so the whole name can be read. Short names stand still.
local MQ_SPEED, MQ_PAUSE = 22, 1.4

-- one fixed width for every tab: room for 10 characters plus padding
local SAMPLE10 = "Abcdefghij"
local function FixedTabWidth(fs, pad)
	local old = fs:GetText()
	fs:SetText(SAMPLE10)
	local w = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 60
	fs:SetText(old)
	return math.floor((w or 60) + pad + 0.5)
end

-- full width of a text, even when the text box itself is narrower
local function FullWidth(fs)
	if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() or 0 end
	return fs:GetStringWidth() or 0
end
local function MarqueeText(btn, left, right, font)
	local mq = CreateFrame("Frame", nil, btn)
	mq:SetPoint("TOPLEFT", left, 0)
	mq:SetPoint("BOTTOMRIGHT", -right, 0)
	if mq.SetClipsChildren then mq:SetClipsChildren(true) end
	local text = UI.Text(mq, font or "GameFontHighlightSmall", C.muted)
	text:SetPoint("LEFT", mq, "LEFT", 0, 0)
	text:SetWordWrap(false)
	text:SetJustifyH("LEFT")
	btn.mq = mq
	local t, dir, wait = 0, 1, MQ_PAUSE
	local function Tick(_, elapsed)
		local over = FullWidth(text) - (mq:GetWidth() or 0)
		if over <= 1 then text:SetPoint("LEFT", mq, "LEFT", 0, 0); mq:SetScript("OnUpdate", nil) return end
		if wait > 0 then wait = wait - elapsed return end
		t = t + dir * elapsed * MQ_SPEED
		if t >= over then t, dir, wait = over, -1, MQ_PAUSE
		elseif t <= 0 then t, dir, wait = 0, 1, MQ_PAUSE end
		text:SetPoint("LEFT", mq, "LEFT", -t, 0)
	end
	-- call after the text or the size changed. Names longer than 10 characters
	-- (spaces count too) show 10 characters at a time and run through.
	local busy
	function btn:UpdateMarquee()
		if busy then return end
		busy = true
		local full = text:GetText() or ""
		local chars = {}
		for ch in full:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
		local inner = math.max(10, (btn:GetWidth() or 0) - left - right)
		if #chars > 10 then
			-- the visible window is as wide as the first 10 characters
			text:SetText(table.concat(chars, "", 1, 10))
			local w10 = (FullWidth(text) or inner) + 1
			text:SetText(full)
			mq:ClearAllPoints()
			mq:SetPoint("LEFT", btn, "LEFT", left, 0)
			mq:SetSize(math.min(inner, w10), btn:GetHeight() or 20)
		else
			mq:ClearAllPoints()
			mq:SetPoint("TOPLEFT", left, 0)
			mq:SetPoint("BOTTOMRIGHT", -right, 0)
		end
		text:SetWidth(FullWidth(text) + 2)
		local over = FullWidth(text) - (mq:GetWidth() or 0)

		if over > 1 then
			if not mq:GetScript("OnUpdate") then t, dir, wait = 0, 1, MQ_PAUSE; mq:SetScript("OnUpdate", Tick) end
		else
			mq:SetScript("OnUpdate", nil)
			text:SetPoint("LEFT", mq, "LEFT", 0, 0)
		end
		busy = nil
	end
	mq:SetScript("OnSizeChanged", function() btn:UpdateMarquee() end)
	return text
end

-- Rename a tab: right-click it, type, Enter. Empty = the automatic name again.
local renameBox
local function StartRename(w, over)
	if not renameBox then
		renameBox = CreateFrame("EditBox", "ChatPilotTabRename", UIParent)
		renameBox:SetFrameStrata("DIALOG")
		renameBox:SetAutoFocus(false)
		renameBox:SetMaxLetters(32)
		renameBox:SetFontObject(GameFontHighlightSmall)
		renameBox:SetTextInsets(6, 6, 0, 0)
		UI.Fill(renameBox, C.bg)
		UI.Border(renameBox, C.accent)
		local function Done(self, save)
			local target = self.target
			self.target = nil
			self:ClearFocus()
			self:Hide()
			if not save or not target then return end
			local name = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
			target.data.title = name ~= "" and name or nil
			if target.group then LayoutTabs(target.group); ns:CW_UpdateChip(target.group) end
			UpdateLaunchers()
		end
		renameBox:SetScript("OnEnterPressed", function(self) Done(self, true) end)
		renameBox:SetScript("OnEscapePressed", function(self) Done(self, false) end)
		renameBox:SetScript("OnEditFocusLost", function(self) if self.target then Done(self, true) end end)
	end
	local b = renameBox
	b.target = w
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", over, "TOPLEFT", 0, 0)
	b:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT", 0, 0)
	if (over:GetWidth() or 0) < 120 then b:SetWidth(120) end
	b:SetText(WindowName(w))
	b:Show()
	b:SetFocus()
	b:HighlightText()
	return b
end

local function CreateTab(w)
	local t = CreateFrame("Button", nil, UIParent)
	t:SetHeight(HEADER_H)
	t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	t:RegisterForDrag("LeftButton")
	t.hl = t:CreateTexture(nil, "HIGHLIGHT")
	t.hl:SetAllPoints()
	UI.Paint(t.hl, C.accentDim)
	t.line = UI.Glow(t, "OVERLAY")
	t.line:SetPoint("BOTTOMLEFT", 4, 1)
	t.line:SetPoint("BOTTOMRIGHT", -4, 1)
	t.line:SetHeight(2)
	t.text = MarqueeText(t, 10, 8)
	t.dot = t:CreateTexture(nil, "OVERLAY")
	t.dot:SetSize(5, 5)
	t.dot:SetPoint("RIGHT", -4, 4)
	UI.Paint(t.dot, C.orange)
	t.dot:Hide()
	-- whisper windows: green = online, grey = offline or unknown
	t.status = t:CreateTexture(nil, "OVERLAY")
	t.status:SetSize(6, 6)
	t.status:SetPoint("LEFT", 3, 0)
	t.status:Hide()
	t:SetScript("OnClick", function(self, button)
		if button == "RightButton" then return StartRename(w, self) end
		ns.cwLast = w.group
		Select(w.group, w)
	end)
	t:SetScript("OnDragStart", function() StartDrag(w.group, w) end)
	t:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(WindowName(w))
		if w.data.partner and ns.CW_PartnerOnline then
			if ns.CW_PartnerOnline(w.data.partner) then
				GameTooltip:AddLine(L.CW_ST_ON, 0.3, 0.85, 0.45)
			else
				GameTooltip:AddLine(L.CW_ST_OFF, 0.6, 0.64, 0.7)
			end
		end
		GameTooltip:AddLine(L.CW_TAB_TIP, 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(L.CW_RENAME_TIP, 0.31, 0.79, 1, true)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	t:EnableMouseWheel(true)
	t:SetScript("OnMouseWheel", function(_, delta)
		local row = w.group and w.group.tabRow
		if row then row:ScrollBy(-delta * 60) end
	end)
	return t
end

-------------------------------------------------------------------------------
-- Scrollable tab rows. Tabs keep their full size; if they don't all fit, the
-- row scrolls (mouse wheel over the tabs, or the small arrows) and the active
-- tab is always brought into view.
-------------------------------------------------------------------------------
local TAB_GAP, TAB_MAX, TAB_MIN = 2, 200, 64


-- clip: frame that cuts off what is outside; strip: holds the tabs
-- Dropdown with all tabs of a row: full names, active marked, unread dot.
-- Click = select, drag an entry out = undock it (like dragging the tab).
local dropMenu
local function ShowTabDropdown(anchor, items, onPick, onDrag)
	if not dropMenu then
		dropMenu = CreateFrame("Frame", "ChatPilotTabDropdown", UIParent)
		dropMenu:SetFrameStrata("DIALOG")
		dropMenu:SetClampedToScreen(true)
		dropMenu:EnableMouse(true)
		UI.Fill(dropMenu, C.bg)
		UI.Border(dropMenu, C.border)
		local glow = UI.Glow(dropMenu)
		glow:SetPoint("TOPLEFT", 1, -1)
		glow:SetPoint("TOPRIGHT", -1, -1)
		glow:SetHeight(2)
		dropMenu.hint = UI.Text(dropMenu, "GameFontHighlightSmall", C.muted)
		dropMenu.hint:SetPoint("BOTTOMLEFT", 10, 7)
		dropMenu.hint:SetPoint("RIGHT", -10, 0)
		dropMenu.hint:SetText(L.CW_DROP_HINT)
		dropMenu.rows = {}
		tinsert(UISpecialFrames, "ChatPilotTabDropdown")
		dropMenu:Hide()
	end
	if dropMenu:IsShown() and dropMenu.anchor == anchor then dropMenu:Hide() return end
	dropMenu.anchor = anchor
	local width = 200
	for i, it in ipairs(items) do
		local r = dropMenu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, dropMenu)
			r:SetHeight(24)
			r:SetPoint("TOPLEFT", 4, -6 - (i - 1) * 24)
			r:SetPoint("TOPRIGHT", -4, -6 - (i - 1) * 24)
			r:RegisterForDrag("LeftButton")
			r.hl = r:CreateTexture(nil, "BACKGROUND")
			r.hl:SetAllPoints()
			UI.Paint(r.hl, C.rowHover)
			r.sel = r:CreateTexture(nil, "BORDER")
			r.sel:SetPoint("TOPLEFT")
			r.sel:SetPoint("BOTTOMLEFT")
			r.sel:SetWidth(3)
			UI.Paint(r.sel, C.accent)
			r.text = UI.Text(r, "GameFontHighlight", C.text)
			r.text:SetPoint("LEFT", 12, 0)
			r.text:SetWordWrap(false)
			r.dot = r:CreateTexture(nil, "OVERLAY")
			r.dot:SetSize(6, 6)
			r.dot:SetPoint("RIGHT", -8, 0)
			UI.Paint(r.dot, C.orange)
			r:SetScript("OnEnter", function(self) self.hl:Show() end)
			r:SetScript("OnLeave", function(self) if not self.active then self.hl:Hide() end end)
			dropMenu.rows[i] = r
		end
		r.active = it.active
		r.hl:SetShown(it.active and true or false)
		r.sel:SetShown(it.active and true or false)
		r.text:SetText(it.label)
		UI.Ink(r.text, it.active and C.text or C.muted)
		r.dot:SetShown(it.unread and not it.active or false)
		width = math.max(width, (r.text:GetStringWidth() or 100) + 40)
		r:SetScript("OnClick", function() dropMenu:Hide(); onPick(it) end)
		r:SetScript("OnDragStart", function() dropMenu:Hide(); if onDrag then onDrag(it) end end)
		r:Show()
	end
	for i = #items + 1, #dropMenu.rows do dropMenu.rows[i]:Hide() end
	dropMenu:SetSize(math.min(width, 360), #items * 24 + 12 + 22)
	dropMenu:ClearAllPoints()
	dropMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	dropMenu:Show()
end

-- Scrollable tab row with a dropdown. Tabs keep their full size; when they
-- don't all fit, a small ▾ button at the end lists every tab with its full
-- name. The mouse wheel over the tabs still scrolls the row, and the active
-- tab is always brought into view.
local DROP_W = 20
local function TabRow(parent)
	local clip = CreateFrame("Frame", nil, parent)
	if clip.SetClipsChildren then clip:SetClipsChildren(true) end
	clip.strip = CreateFrame("Frame", nil, clip)
	clip.strip:SetSize(1, 1)
	clip.scroll, clip.width = 0, 0

	-- ▾ button (outside the clipped area, so it is never cut off)
	local drop = CreateFrame("Button", nil, parent)
	drop:SetSize(DROP_W, 20)
	drop.bg = UI.Fill(drop, C.row)
	UI.Border(drop, C.border)
	for k = -1, 1, 2 do
		local t = drop:CreateTexture(nil, "OVERLAY")
		t:SetSize(6, 2)
		t:SetPoint("CENTER", k * 2, 0)
		t:SetRotation(math.rad(k * -45))
		UI.Paint(t, C.accent)
	end
	drop.dot = drop:CreateTexture(nil, "OVERLAY")
	drop.dot:SetSize(5, 5)
	drop.dot:SetPoint("TOPRIGHT", -2, -2)
	UI.Paint(drop.dot, C.orange)
	drop:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 1)
	drop:SetScript("OnEnter", function(self)
		UI.Paint(self.bg, C.rowHover)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.CW_DROP_TIP)
		GameTooltip:Show()
	end)
	drop:SetScript("OnLeave", function(self) UI.Paint(self.bg, C.row); GameTooltip:Hide() end)
	drop:SetScript("OnClick", function(self)
		GameTooltip:Hide()
		if clip.items then ShowTabDropdown(self, clip.items(), clip.onPick, clip.onDrag) end
	end)
	drop:Hide()
	clip.drop = drop

	function clip:Overflow() return self.forceDrop or self.width > (self:GetWidth() or 0) + 0.5 end
	function clip:View()
		local v = self:GetWidth() or 0
		if self:Overflow() and not self.dropOutside then v = v - DROP_W - 4 end
		return math.max(0, v)
	end
	function clip:Apply()
		local over = self:Overflow()
		local maxScroll = math.max(0, self.width - self:View())
		self.scroll = math.max(0, math.min(self.scroll, maxScroll))
		self.strip:ClearAllPoints()
		self.strip:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -self.scroll, 0)
		self.strip:SetSize(math.max(1, self.width), self:GetHeight() or 22)
		self.drop:SetShown(over and self:IsShown())
		self.drop:SetFrameStrata(self:GetFrameStrata())
		self.drop:SetFrameLevel(self:GetFrameLevel() + 8)
		local unreadHidden = false
		if over and self.items then
			for _, it in ipairs(self.items()) do if it.unread and not it.active then unreadHidden = true end end
		end
		self.drop.dot:SetShown(unreadHidden)
		DotGlow(self.drop, unreadHidden)
	end
	-- tabs are never shown half: the row always starts at a tab, and a tab that
	-- doesn't fit completely is left out (it is in the ▾ list)
	local function Snap(self)
		local spans = self.spans
		if not spans or #spans == 0 then return end
		local best = 0
		for _, sp in ipairs(spans) do if sp[2] <= self.scroll + 0.5 then best = sp[2] end end
		self.scroll = best
	end
	local function Mask(self)
		local spans = self.spans
		if not spans then return end
		local view, any = self:View(), false
		for _, sp in ipairs(spans) do
			local full = sp[2] >= self.scroll - 0.5 and sp[3] <= self.scroll + view + 0.5
			any = any or full
			sp.vis = full
			sp[1]:SetAlpha(full and 1 or 0)
			if sp[1].EnableMouse then sp[1]:EnableMouse(full) end
		end
		-- the selected tab is always shown, even if the row is (still) too narrow
		for _, sp in ipairs(spans) do
			if sp.active and not sp.vis then
				any = true
				sp.vis = true
				sp[1]:SetAlpha(1)
				if sp[1].EnableMouse then sp[1]:EnableMouse(true) end
			end
		end
		if not any and spans[1] then
			-- very narrow: show the first tab anyway
			for _, sp in ipairs(spans) do
				if sp[2] >= self.scroll - 0.5 then sp.vis = true; sp[1]:SetAlpha(1); if sp[1].EnableMouse then sp[1]:EnableMouse(true) end break end
			end
		end
		-- the ▾ sits at the right edge of the row, or just outside it (main chat)
		self.drop:ClearAllPoints()
		if self.dropOutside then
			-- outside the chat, in the same column as the buttons next to it (⚙ @ …)
			local x = 6
			local bar = ns.ChatBarFrame and ns.ChatBarFrame()
			if bar and bar:IsShown() and (bar:GetWidth() or 99) < 40 and bar:GetCenter() and self:GetRight() then
				local bx = bar:GetCenter() * (bar:GetEffectiveScale() or 1) / (self:GetEffectiveScale() or 1)
				x = bx - self:GetRight() - DROP_W / 2
			end
			self.drop:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", x, 1)
		else
			self.drop:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 1)
		end
	end
	local apply = clip.Apply
	function clip:Apply()
		local maxScroll = math.max(0, self.width - self:View())
		self.scroll = math.max(0, math.min(self.scroll, maxScroll))
		Snap(self)
		apply(self)
		Mask(self)
	end
	function clip:ScrollBy(dx)
		local spans = self.spans
		if spans and #spans > 0 then
			-- one tab further, left or right
			local target = self.scroll
			if dx > 0 then
				for _, sp in ipairs(spans) do if sp[2] > self.scroll + 0.5 then target = sp[2] break end end
			else
				for _, sp in ipairs(spans) do if sp[2] < self.scroll - 0.5 then target = sp[2] end end
			end
			if dx > 0 and target > math.max(0, self.width - self:View()) + 0.5 then
				-- the end is reached once the last tab fits
				local last = spans[#spans]
				if last[3] <= self.scroll + self:View() + 0.5 then target = self.scroll end
			end
			self.scroll = target
			apply(self)
			Mask(self)
			return
		end
		self.scroll = self.scroll + dx
		self:Apply()
	end
	-- make sure the tab from x1 to x2 is visible
	function clip:Reveal(x1, x2)
		local view = self:View()
		if x1 < self.scroll then
			self.scroll = x1
		elseif x2 > self.scroll + view then
			local want, best = x2 - view, x1
			for _, sp in ipairs(self.spans or {}) do
				if sp[2] >= want - 0.5 then best = sp[2] break end
			end
			self.scroll = best
		end
		local spans = self.spans
		self.spans = nil -- keep exactly this start
		local maxScroll = math.max(0, self.width - view)
		if self.scroll > maxScroll and x1 <= maxScroll then self.scroll = maxScroll end
		apply(self)
		self.spans = spans
		Mask(self)
	end
	clip:EnableMouseWheel(true)
	clip:SetScript("OnMouseWheel", function(self, delta) self:ScrollBy(-delta * 60) end)
	clip:SetScript("OnSizeChanged", function(self)
		-- the real width is known now: lay the tabs out again (once)
		if self.Relayout and not self.relaying then
			self.relaying = true
			pcall(self.Relayout)
			self.relaying = nil
		else
			self:Apply()
		end
	end)
	clip:HookScript("OnHide", function(self) self.drop:Hide() end)
	clip:HookScript("OnShow", function(self) self:Apply() end)
	return clip
end

function LayoutTabs(g)
	if not g.data then return end
	if not g.tabRow then
		g.tabRow = TabRow(g.header)
		g.tabRow:SetPoint("BOTTOMLEFT", g.header, "BOTTOMLEFT", 4, 0)
		g.tabRow:SetPoint("TOPRIGHT", g.bell, "TOPLEFT", -4, 0)
		g.tabRow.items = function()
			local list = {}
			for _, id in ipairs(g.data and g.data.order or {}) do
				local w = wins[id]
				if w then list[#list + 1] = { label = WindowName(w), w = w, unread = w.unread, active = g.data.active == id } end
			end
			return list
		end
		g.tabRow.onPick = function(it) ns.cwLast = g; Select(g, it.w) end
		g.tabRow.Relayout = function() LayoutTabs(g) end
		g.tabRow.onDrag = function(it) if it.w.group then StartDrag(it.w.group, it.w) end end
	end
	local row = g.tabRow
	local x, ax1, ax2 = 0, nil, nil
	local spans = {}
	local widths, total = {}, 0
	for i, id in ipairs(g.data.order) do
		local t = wins[id].tab
		t.text:SetText(WindowName(wins[id]))
		-- every tab the same size, whatever the name; longer names run through
		widths[i] = FixedTabWidth(t.text, 10 + 8 + 2)
		total = total + widths[i] + (i > 1 and TAB_GAP or 0)
	end
	for i, id in ipairs(g.data.order) do
		local w = wins[id]
		local t = w.tab
		t:SetParent(row.strip)
		t:SetFrameLevel(row.strip:GetFrameLevel() + 2)
		local width = widths[i]
		t:SetWidth(width)
		if t.UpdateMarquee then t:UpdateMarquee() end
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", row.strip, "BOTTOMLEFT", x, 0)
		local active = g.data.active == id
		if active then ax1, ax2 = x, x + width end
		spans[#spans + 1] = { t, x, x + width, active = active }
		x = x + width + TAB_GAP
		t.line:SetShown(active)
		UI.Ink(t.text, active and C.text or C.muted)
		t.dot:SetShown(not active and w.unread and true or false)
		DotGlow(t, not active and w.unread)
		t:Show()
	end
	row.width = math.max(0, x - TAB_GAP)
	row.spans = spans
	if ax1 then row:Reveal(ax1, ax2) else row:Apply() end
end

function Select(g, w)
	g.data.active = w.data.id
	w.unread = false
	for _, id in ipairs(g.data.order) do
		local o = wins[id]
		o.msg:SetShown(o == w)
	end
	LayoutTabs(g)
	ns:CW_UpdateChip(g)
	ns:CW_UpdateBell(g)
	if g.data.main and UpdateLaunchers then UpdateLaunchers() end
	-- once more on the next frame, when all sizes are settled
	C_Timer.After(0, function()
		if g.data then LayoutTabs(g) end
		if g.data and g.data.main and UpdateLaunchers then UpdateLaunchers() end
	end)
	if menu and menu:IsShown() and menu.group == g then ns:CW_OpenMenu(g) end
end

-------------------------------------------------------------------------------
-- Group frame (one window or several docked as tabs)
-------------------------------------------------------------------------------
local function HeaderButton(g, tip, onClick)
	local b = CreateFrame("Button", nil, g.header)
	b:SetSize(22, 20)
	b.lines = {}
	-- hover background sits BEHIND the icon (a HIGHLIGHT layer would cover it)
	local hl = b:CreateTexture(nil, "BACKGROUND")
	hl:SetAllPoints()
	UI.Paint(hl, C.rowHover)
	hl:Hide()
	b.tip = tip
	b:SetScript("OnEnter", function(self)
		hl:Show()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
	b:SetScript("OnClick", onClick)
	return b
end

local function IconLine(b, w, h, rot, x, y)
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetSize(w, h)
	t:SetPoint("CENTER", x or 0, y or 0)
	if rot then t:SetRotation(math.rad(rot)) end
	UI.Paint(t, C.muted)
	b.lines[#b.lines + 1] = t
	return t
end

local NewGroup -- forward

local function CreateGroupFrame(g)
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H); f:SetMaxResize(MAX_W, MAX_H) end
	f:EnableMouse(true)
	g.bg = UI.Fill(f, C.chatBg)
	UI.Border(f, C.border)
	g.frame = f
	-- clicking anywhere in the window = the next Enter belongs to it
	f:HookScript("OnMouseDown", function() ns.cwLast = g end)

	local header = CreateFrame("Button", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_H)
	UI.Fill(header, C.panel)
	local glow = UI.Glow(header)
	glow:SetPoint("BOTTOMLEFT")
	glow:SetPoint("BOTTOMRIGHT")
	glow:SetHeight(1)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() StartDrag(g) end)
	g.header = header
	g.dropHl = header:CreateTexture(nil, "OVERLAY")
	g.dropHl:SetAllPoints()
	UI.Paint(g.dropHl, C.accentDim)
	g.dropHl:Hide()

	-- × deletes the active window (second click if it has messages)
	g.close = HeaderButton(g, L.CW_DELETE, function(self)
		local w = wins[g.data.active]
		if not w then return end
		local armed = rawget(self, "armed")
		if w.count and w.count > 0 and not (armed and GetTime() - armed < 3) then
			self.armed = GetTime()
			for _, t in ipairs(self.lines) do t:SetColorTexture(1, 0.3, 0.3, 1) end
			self.tip = L.CW_DELETE_CONFIRM
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip)
			GameTooltip:Show()
			C_Timer.After(3, function()
				local a = rawget(self, "armed")
				if a and GetTime() - a >= 2.9 then
					self.armed = nil
					for _, t in ipairs(self.lines) do UI.Paint(t, C.muted) end
					self.tip = L.CW_DELETE
				end
			end)
			return
		end
		self.armed = nil
		for _, t in ipairs(self.lines) do UI.Paint(t, C.muted) end
		self.tip = L.CW_DELETE
		GameTooltip:Hide()
		ns:CW_Delete(w)
	end)
	g.close:SetPoint("RIGHT", -2, 0)
	IconLine(g.close, 11, 2, 45)
	IconLine(g.close, 11, 2, -45)

	g.new = HeaderButton(g, L.CW_NEW_TIP, function() ns:CW_New(nil, g) end)
	g.new:SetPoint("RIGHT", g.close, "LEFT", -1, 0)
	IconLine(g.new, 10, 2)
	IconLine(g.new, 2, 10)

	-- filter (funnel made of three lines)
	g.filter = HeaderButton(g, L.CW_FILTER_TIP, function() ns:CW_ToggleMenu(g) end)
	g.filter:SetPoint("RIGHT", g.new, "LEFT", -1, 0)
	IconLine(g.filter, 12, 2, nil, 0, 4)
	IconLine(g.filter, 8, 2, nil, 0, 0)
	IconLine(g.filter, 4, 2, nil, 0, -4)

	-- bell: notify me about new messages in this window (on/off)
	g.bell = HeaderButton(g, L.CW_BELL_OFF, function() ns:CW_ToggleBell(g) end)
	g.bell:SetPoint("RIGHT", g.filter, "LEFT", -1, 0)
	-- a real bell icon from the game (smooth at any UI scale), cropped to the bell
	g.bell.icon = g.bell:CreateTexture(nil, "ARTWORK")
	g.bell.icon:SetSize(15, 15)
	g.bell.icon:SetPoint("CENTER")
	g.bell.icon:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
	g.bell.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	g.bell.slash = g.bell:CreateTexture(nil, "OVERLAY")
	g.bell.slash:SetSize(16, 2)
	g.bell.slash:SetPoint("CENTER")
	g.bell.slash:SetRotation(math.rad(-45))
	UI.Paint(g.bell.slash, C.muted)

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 6, -HEADER_H - 4)
	body:SetPoint("BOTTOMRIGHT", -6, 36)
	g.body = body

	-- input row: [target] [text ...........]
	local row = CreateFrame("Frame", nil, f)
	row:SetPoint("BOTTOMLEFT", 6, 6)
	row:SetPoint("BOTTOMRIGHT", -16, 6)
	row:SetHeight(26)
	g.row = row
	local chip = CreateFrame("Button", nil, row)
	chip:SetPoint("TOPLEFT")
	chip:SetPoint("BOTTOMLEFT")
	chip.bg = UI.Fill(chip, C.row)
	UI.Border(chip, C.border)
	chip.text = UI.NoShadow(chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	chip.text:SetPoint("LEFT", 8, 0)
	chip.text:SetWordWrap(false)
	chip:SetScript("OnClick", function() ns:CW_TargetMenu(g) end)
	chip:SetScript("OnEnter", function(self)
		UI.Paint(self.bg, C.rowHover)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.CW_TARGET_TIP)
		GameTooltip:Show()
	end)
	chip:SetScript("OnLeave", function(self) UI.Paint(self.bg, C.row); GameTooltip:Hide() end)
	g.chip = chip

	local holder = CreateFrame("Frame", nil, row)
	g.inputHolder = holder
	holder:SetPoint("TOPLEFT", chip, "TOPRIGHT", 4, 0)
	holder:SetPoint("BOTTOMRIGHT")
	UI.Fill(holder, C.btn)
	UI.Border(holder, C.border)
	local eb = CreateFrame("EditBox", nil, holder)
	eb:SetPoint("TOPLEFT", 8, 0)
	eb:SetPoint("BOTTOMRIGHT", -8, 0)
	eb:SetFontObject(ChatFontNormal or UI.MessageFont())
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(255)
	if eb.SetMaxBytes then eb:SetMaxBytes(256) end -- same limit as the game's chat (255 bytes)
	eb:SetTextInsets(0, 52, 0, 0)                  -- room for the "123/255" counter
	eb:SetAltArrowKeyMode(false)
	local ph = UI.Text(holder, "GameFontHighlightSmall", C.muted)
	ph:SetPoint("LEFT", 9, 0)
	ph:SetText(L.CW_WRITE)
	local function upd() ph:SetShown(eb:GetText() == "" and not eb:HasFocus()) end
	eb:SetScript("OnEditFocusGained", function() ns.cwLast = g; ns.cwFocusEB = eb; upd(); holder:SetBorderColor(unpack(C.accent)) end)
	eb:SetScript("OnEditFocusLost", function() ns.cwLostAt = GetTime(); upd(); holder:SetBorderColor(unpack(C.border)) end)
	eb:SetScript("OnTextChanged", function(self)
		upd()
		local text = self:GetText() or ""
		if text:sub(1, 1) ~= "/" then return end
		local w = wins[g.data and g.data.active]
		local t, rest = ParseCommand(w, text, false)
		if t then
			ns:CW_SetTarget(g, t)
			self:SetText(rest or "")
			if ns.HidePopup then ns.HidePopup() end
		end
	end)
	-- Backspace in an empty box drops the chosen target as a whole (never letter by letter)
	eb:HookScript("OnKeyDown", function(self, key)
		if key == "BACKSPACE" and (self:GetText() or "") == "" then ns:CW_ResetTarget(g) end
	end)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnEnterPressed", function(self) ns:CW_Submit(g) end)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() eb:SetFocus() end)
	g.input = eb
	g.holder = holder
	if ns.HookEditBox then ns.HookEditBox(eb) end -- @ names, #snippets, {raid icons}

	local grip = CreateFrame("Button", nil, f)
	g.grip = grip
	grip:SetSize(12, 12)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetFrameLevel(f:GetFrameLevel() + 5)
	for i = 1, 2 do
		local t = grip:CreateTexture(nil, "OVERLAY")
		t:SetSize(i == 1 and 10 or 5, 1)
		t:SetPoint("BOTTOMRIGHT", -1, i == 1 and 4 or 1)
		t:SetRotation(math.rad(45))
		UI.Paint(t, C.muted)
	end
	grip:SetScript("OnMouseDown", function()
		if g.data.main then return end
		if g.data.snap then
			-- snapped windows keep the chat's width: only the height changes
			Save(g); g.data.snap = false; Place(g)
		end
		f:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		if g.data.main then return end
		f:StopMovingOrSizing()
		Save(g)
		LayoutTabs(g)
	end)
	f:SetScript("OnSizeChanged", function() if g.data then LayoutTabs(g) end end)
	return f
end

local CheckBottom -- defined further down (the message frame needs it)
local function CreateMessageFrame(w)
	local m = CreateFrame("ScrollingMessageFrame", nil, UIParent)
	m:SetFontObject(UI.MessageFont())
	m:SetJustifyH("LEFT")
	m:SetMaxLines(1000)
	m:SetFading(false)
	if m.SetSpacing then m:SetSpacing(2) end
	if m.SetIndentedWordWrap then m:SetIndentedWordWrap(false) end
	if m.SetHyperlinksEnabled then m:SetHyperlinksEnabled(true) end
	if ns.DecorateMessages then ns.DecorateMessages(m, function() return ns.S.chatStyle ~= false end) end
	m:HookScript("OnMouseDown", function() if w.group then ns.cwLast = w.group end end)
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
		else
			if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
		end
		pcall(CheckBottom, w)
	end)
	if m.SetOnScrollChangedCallback then m:SetOnScrollChangedCallback(function() pcall(CheckBottom, w) end) end
	m:SetScript("OnHyperlinkClick", function(self, link, text, button)
		if ns.LinkClick(link) then return end
		local cid = ns.CensorID(link)
		if cid then ns:CW_Reveal(cid) return end
		local name = type(link) == "string" and link:match("^player:([^:]+)")
		if name and button == "LeftButton" and not IsModifierKeyDown() and w.group then
			-- click a name: whisper that person right here
			ns:CW_SetTarget(w.group, { type = "WHISPER", name = name })
			w.group.input:SetFocus()
			return
		end
		if SetItemRef then SetItemRef(link, text, button, DEFAULT_CHAT_FRAME) end
	end)
	m:SetScript("OnHyperlinkEnter", function(self, link)
		if ns.LinkEnter(self, link) then return end
		local kind = type(link) == "string" and link:match("^(%a+):")
		if kind and kind ~= "player" and kind ~= "BNplayer" and kind ~= "channel" and kind ~= "garrmission" then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
				GameTooltip:Show()
				self.ChatPilotTip = true
			else
				GameTooltip:Hide()
			end
		end
	end)
	m:SetScript("OnHyperlinkLeave", function(self) ns.LinkLeave(self) end)
	return m
end

local function Attach(g, w)
	w.group = g
	w.msg:SetParent(g.body)
	w.msg:ClearAllPoints()
	w.msg:SetAllPoints(g.body)
	w.msg:SetShown(g.data.active == w.data.id)
	w.tab:SetParent(g.header)
end

function NewGroup(gdata)
	local g = { data = gdata }
	CreateGroupFrame(g)
	groups[#groups + 1] = g
	Place(g)
	for _, id in ipairs(gdata.order) do
		local w = wins[id]
		if w then Attach(g, w) end
	end
	if not gdata.main then g.frame:Show() end
	LayoutTabs(g)
	return g
end

local function RemoveGroup(g)
	g.frame:Hide()
	for i, o in ipairs(groups) do if o == g then table.remove(groups, i) break end end
	for i, d in ipairs(Data.groups) do if d == g.data then table.remove(Data.groups, i) break end end
	g.data = nil
end

local function RemoveFromGroup(g, w)
	for i, id in ipairs(g.data.order) do
		if id == w.data.id then table.remove(g.data.order, i) break end
	end
	if #g.data.order == 0 then
		RemoveGroup(g)
	else
		if g.data.active == w.data.id then g.data.active = g.data.order[1] end
		Select(g, wins[g.data.active])
	end
end

-------------------------------------------------------------------------------
-- Dragging: move a window, undock a tab, dock onto another window, snap
-------------------------------------------------------------------------------
local dragFrame = CreateFrame("Frame")
dragFrame:Hide()

local function DropTarget(g)
	for _, o in ipairs(groups) do
		if o ~= g and o.frame:IsVisible() and MouseIsOver and MouseIsOver(o.header) then return o end
	end
end

local function NearMainChat(g)
	local main = MainChat()
	if not main or not main:IsShown() or not main:GetLeft() then return false end
	local f = g.frame
	local dy = (f:GetBottom() or 0) - ((main:GetTop() or 0) + 34)
	local dx = (f:GetLeft() or 0) - (main:GetLeft() or 0)
	return math.abs(dy) < 28 and math.abs(dx) < 60
end

local function FinishDrag(g)
	dragging = nil
	dragFrame:Hide()
	g.frame:StopMovingOrSizing()
	for _, o in ipairs(groups) do o.dropHl:Hide() end
	if ns.ShowMainDrop then ns:ShowMainDrop(false) end
	-- An explicit title-bar target takes precedence over the chat behind it.
	local target = #g.data.order == 1 and DropTarget(g)
	local overMain = not target and ns.OverMainChat and ns:OverMainChat()
	if target and #g.data.order == 1 then
		-- dock as a tab
		local w = wins[g.data.order[1]]
		g.data.order = {}
		RemoveGroup(g)
		table.insert(target.data.order, w.data.id)
		Attach(target, w)
		Select(target, w)
		return
	end
	if overMain then
		g.data.snap = false
		g.data.main = true
		ns:CW_OpenMain(g)
		local aw = wins[g.data.active]
		ns.Print(L.CW_DOCKED_MAIN, aw and WindowName(aw) or "")
		return
	end
	if NearMainChat(g) then
		g.data.snap = true
		g.data.h = math.floor(g.frame:GetHeight() + 0.5)
	else
		g.data.snap = false
		Save(g)
	end
	Place(g)
	LayoutTabs(g)
end

dragFrame:SetScript("OnUpdate", function()
	local g = dragging
	if not g then dragFrame:Hide() return end
	if not IsMouseButtonDown("LeftButton") then return FinishDrag(g) end
	local target = #g.data.order == 1 and DropTarget(g)
	local overMain = not target and ns:OverMainChat()
	for _, o in ipairs(groups) do o.dropHl:SetShown(o == target) end
	if ns.ShowMainDrop then ns:ShowMainDrop(overMain) end
end)

function StartDrag(g, w)
	if w and #g.data.order > 1 then
		-- pull this tab out into its own window under the mouse
		local f = g.frame
		local scale = UIParent:GetEffectiveScale() or 1
		local cx, cy = GetCursorPosition()
		cx, cy = cx / scale, cy / scale
		RemoveFromGroup(g, w)
		local d = { order = { w.data.id }, active = w.data.id, w = math.floor(f:GetWidth()), h = math.floor(f:GetHeight()),
			x = math.floor(cx - 40), y = math.floor(cy + 10) }
		Data.groups[#Data.groups + 1] = d
		g = NewGroup(d)
		Select(g, w)
	end
	if g.data.main then
		-- pulled out of the main chat: becomes a free window under the mouse
		local scale = UIParent:GetEffectiveScale() or 1
		local cx, cy = GetCursorPosition()
		g.data.main = false
		g.mainOpen = false
		g.data.w, g.data.h = math.floor(g.frame:GetWidth()), math.floor(g.frame:GetHeight())
		g.data.x, g.data.y = math.floor(cx / scale - 40), math.floor(cy / scale + 10)
		Place(g)
		g.frame:Show()
		if UpdateLaunchers then UpdateLaunchers() end
	end
	if g.data.snap then
		Save(g)
		g.data.snap = false
		g.data.x, g.data.y = math.floor(g.frame:GetLeft() + 0.5), math.floor(g.frame:GetTop() + 0.5)
		Place(g)
	end
	g.frame:StartMoving()
	dragging = g
	dragFrame:Show()
end

-------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------
local getFilters = ChatFrame_GetMessageEventFilters or (ChatFrameUtil and ChatFrameUtil.GetMessageEventFilters)

local function RunFilters(frame, event, ...)
	local args, n = { ... }, select("#", ...)
	local list = getFilters and getFilters(event)
	if not list then return args, n end
	for _, filter in ipairs(list) do
		local res = { pcall(filter, frame, event, unpack(args, 1, n)) }
		if res[1] then
			if res[2] then return nil end
			if res[3] ~= nil then
				args = {}
				for i = 3, #res do args[i - 2] = res[i] end
				n = math.max(n, #res - 2)
			end
		end
	end
	return args, n
end

local MAX_LIVE = 1000

-- glowing hint at the bottom while you read further up and new lines arrive
local function HideNewHint(w) if w.newHint then w.newHint:Hide() end end
function CheckBottom(w)
	local m = w.msg
	if w.newHint and w.newHint:IsShown() and m.AtBottom and m:AtBottom() == true then w.newHint:Hide() end
end
local function ShowNewHint(w)
	local b = w.newHint
	if not b then
		b = UI.Button(w.msg, L.CW_NEWMSG, 130, 20, "accent")
		b:SetPoint("BOTTOM", w.msg, "BOTTOM", 0, 3)
		b:SetFrameLevel(w.msg:GetFrameLevel() + 12)
		local width = tonumber(b.label:GetStringWidth())
		if width then b:SetWidth(width + 26) end
		b:SetScript("OnClick", function() w.msg:ScrollToBottom(); b:Hide() end)
		b:SetScript("OnUpdate", function(self)
			self:SetAlpha(0.72 + 0.28 * math.sin(GetTime() * 4))
		end)
		w.newHint = b
	end
	b:Show()
end

-- every line shown in a window (so a hidden message can be released later)
local function Live(w, text, r, g, b, cid, ph)
	local live = w.live
	if not live then live = {}; w.live = live end
	live[#live + 1] = { text, r, g, b, cid, ph }
	if #live > MAX_LIVE then table.remove(live, 1) end
end

local function ReplacePlain(text, old, new)
	local a, b = text:find(old, 1, true)
	if not a then return text end
	return text:sub(1, a - 1) .. new .. text:sub(b + 1)
end

local function CensoredLine(lineID)
	if type(lineID) ~= "number" or not ns.Usable(lineID) then return false end
	local api = C_ChatInfo
	if not (api and api.IsChatLineCensored) then return false end
	local ok, hidden = pcall(api.IsChatLineCensored, lineID)
	return ok and hidden and true or false
end

-- lines that no longer fit the saved 200 move to the archive of their window (plain text)
local function ArchivePlain(text, t)
	local s = tostring(text)
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " ")
	s = s:gsub("||", "\1"):gsub("|", ""):gsub("\1", "|")
	return date("%d.%m. %H:%M", tonumber(t) or time()) .. "  " .. s
end

local function Archive(w, line)
	if type(line) ~= "table" or line[6] or type(line[1]) ~= "string" then return end -- not a hidden-message placeholder
	local a = w.data.archive
	if not a then a = {}; w.data.archive = a end
	a[#a + 1] = ArchivePlain(line[1], line[5])
	if #a > MAX_ARCHIVE + 100 then
		local n = {}
		for i = #a - MAX_ARCHIVE + 1, #a do n[#n + 1] = a[i] end
		w.data.archive = n
	end
	if ns.db and not ns.db.archiveTold then
		ns.db.archiveTold = true
		ns.Print(L.CW_ARCHIVED)
	end
end

local function AddLine(w, text, r, g, b, save, cid, ph)
	local away = w.msg.AtBottom and w.msg:AtBottom() == false
	w.msg:AddMessage(text, r, g, b)
	-- the hint is an extra: whatever goes wrong there must never cost a message
	if away then
		local okH, errH = pcall(ShowNewHint, w)
		if not okH and not ns.hintErrShown then
			ns.hintErrShown = true
			ns.Print("hint: " .. tostring(errH))
		end
	end
	Live(w, text, r, g, b, cid, ph)
	w.count = (w.count or 0) + 1
	if save then
		local lines = w.data.lines
		lines[#lines + 1] = { text, r, g, b, time(), cid, ph }
		while #lines > MAX_SAVED_LINES do pcall(Archive, w, table.remove(lines, 1)) end
	end
	if w.group and w.group.data and w.group.data.active ~= w.data.id then
		if not w.unread then
			w.unread = true
			LayoutTabs(w.group)
			if UpdateLaunchers then UpdateLaunchers() end
		end
	elseif w.group and w.group.data and w.group.data.main and not w.group.mainOpen and not w.unread then
		w.unread = true
		if UpdateLaunchers then UpdateLaunchers() end
	end
end

-------------------------------------------------------------------------------
-- Structured layout for ChatPilot's windows (classic WoW feel, but tidy):
--   (o) Name  21:17 · Trade        <- header: channel dot, name, small time, label
--       message text                <- the message, indented, calm colour
-- More messages from the same person right after: only the text lines.
-- System messages: a single muted line with a dot.
-------------------------------------------------------------------------------
local CALM = {
	WHISPER = { 0.86, 0.68, 1 }, WHISPER_INFORM = { 0.86, 0.68, 1 },
	BN_WHISPER = { 0.55, 0.80, 1 }, BN_WHISPER_INFORM = { 0.55, 0.80, 1 },
	GUILD = { 0.52, 0.89, 0.55 }, OFFICER = { 0.40, 0.80, 0.45 }, GUILD_ACHIEVEMENT = { 0.52, 0.89, 0.55 },
	PARTY = { 0.64, 0.72, 1 }, PARTY_LEADER = { 0.64, 0.72, 1 },
	RAID = { 1, 0.70, 0.45 }, RAID_LEADER = { 1, 0.70, 0.45 }, RAID_WARNING = { 1, 0.45, 0.30 },
	INSTANCE_CHAT = { 1, 0.70, 0.45 }, INSTANCE_CHAT_LEADER = { 1, 0.70, 0.45 },
	SAY = { 0.95, 0.95, 0.95 }, YELL = { 1, 0.48, 0.45 }, EMOTE = { 1, 0.66, 0.38 },
	CHANNEL = { 0.85, 0.85, 0.85 }, COMMUNITIES_CHANNEL = { 0.56, 0.88, 0.82 },
	SYSTEM = { 0.78, 0.83, 0.55 }, TEXT_EMOTE = { 1, 0.66, 0.38 },
}
local DOT_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local INDENT = "      "

local function Dot(c)
	return ("|T%s:9:9:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(DOT_TEX,
		math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- Message blocks: a header line and its text lines carry an invisible mark at the
-- start (an empty colour code + "|r|r"), so the block can get its soft background
-- and the coloured stripe on the left (see ChatLook.lua). The mark shows nothing.
local function HeadMark(c)
	return ("|cff%02x%02x%02x|r|r"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
local BODY = "|r|r"

-- "[Name]" -> "Name" inside a player link (calmer header)
local function PlainName(link)
	return (link:gsub("|h%[(.*)%]|h$", "|h%1|h"))
end

local function StripeColor(isOwn, mentioned, class, calm)
	if isOwn then return C.accent end
	if mentioned then return C.orange end
	local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if cc then return { cc.r, cc.g, cc.b } end
	return calm
end


-- label after the time: where the message was written
local function ChannelLabel(chatType, channelNumber, baseName, channelString, author)
	if chatType == "CHANNEL" then
		local n = ShortChannel(baseName ~= "" and baseName or channelString)
		return n ~= "" and n or tostring(channelNumber or "")
	elseif chatType == "WHISPER" or chatType == "BN_WHISPER" then return L.CAT_whisper
	elseif chatType == "WHISPER_INFORM" or chatType == "BN_WHISPER_INFORM" then
		local to = chatType == "WHISPER_INFORM" and Ambiguate and Ambiguate(author or "", "none") or author
		return L.CW_TO:format(to or "?")
	elseif chatType == "COMMUNITIES_CHANNEL" then return ResolveChannel(channelString, baseName)
	end
	local map = { GUILD = "guild", OFFICER = "guild", PARTY = "party", PARTY_LEADER = "party", RAID = "raid",
		RAID_LEADER = "raid", RAID_WARNING = "raid", INSTANCE_CHAT = "raid", INSTANCE_CHAT_LEADER = "raid",
		SAY = "say", YELL = "yell", EMOTE = "emote" }
	return map[chatType] and L["CAT_" .. map[chatType]] or nil
end

-- shared with the normal chat (same look there)
ns.ChatLook = { CALM = CALM, Dot = Dot, INDENT = INDENT, ChannelLabel = ChannelLabel, ShortChannel = ShortChannel,
	HeadMark = HeadMark, BODY = BODY, PlainName = PlainName, StripeColor = StripeColor }

-- "|Hplayer:Name|h[Name]|h has come online." / "Name has gone offline." -> name, online
local presencePatterns
local function PresenceOf(msg)
	if type(msg) ~= "string" then return end
	if not presencePatterns then
		presencePatterns = {}
		local function mk(fmt, state)
			if type(fmt) ~= "string" then return end
			local pat = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.-)")
			presencePatterns[#presencePatterns + 1] = { "^" .. pat .. "$", state }
		end
		mk(_G.ERR_FRIEND_ONLINE_SS, true)
		mk(_G.ERR_FRIEND_OFFLINE_S, false)
	end
	for _, p in ipairs(presencePatterns) do
		local a = msg:match(p[1])
		if a and a ~= "" then return a, p[2] end
	end
end

local function Deliver(event, ...)
	if #groups == 0 then return end
	local cat = EVENT_CAT[event]
	-- online / offline notices also go to windows that picked them
	local presence = event == "CHAT_MSG_SYSTEM" and ns.Usable((...)) and PresenceOf((...)) and true or false
	if event == "CHAT_MSG_CHANNEL" then
		local zoneChannelID, channelNumber = select(7, ...)
		if ns.Usable(zoneChannelID, channelNumber) then cat = ChannelCat(zoneChannelID, channelNumber) else cat = "channels" end
	end
	if not cat then return end

	local targets = {}
	for _, w in pairs(wins) do
		if (w.data.cats[cat] or (presence and w.data.cats.presence)) and w.group then
			-- a conversation window only takes whispers with its one person
			local p = w.data.partner
			local ok = true
			if p and cat == "whisper" then
				if p.bn then
					local bnID = select(13, ...)
					ok = event:find("^CHAT_MSG_BN_") and ns.Usable(bnID) and bnID == p.id
				else
					local author = select(2, ...)
					ok = not event:find("^CHAT_MSG_BN_") and ns.Usable(author) and ns.Normalize(author) == p.key
				end
			end
			if ok then targets[#targets + 1] = w end
		end
	end
	if #targets == 0 then return end

	local msg, author = ...
	if not ns.Usable(msg, author) then
		-- restricted (e.g. boss encounter): show the text as it is, untouched
		local r, g, b = TypeColor(event:sub(10))
		for _, w in ipairs(targets) do pcall(w.msg.AddMessage, w.msg, msg, r, g, b) end
		return
	end

	-- who wrote it (for grouping and the colour bar)
	local chatType = event:sub(10)
	local guid = select(12, ...)
	local channelNumber = select(8, ...)
	local isSystem = chatType == "SYSTEM" or chatType == "TEXT_EMOTE" or not author or author == ""
	local isOwn = not isSystem and (chatType:find("_INFORM$") or (Ambiguate and Ambiguate(author, "none") == UnitName("player")))
	local class
	if not isSystem and type(guid) == "string" and guid ~= "" and GetPlayerInfoByGUID then
		local okc, _, cf = pcall(GetPlayerInfoByGUID, guid)
		if okc then class = cf end
	end
	-- a hidden ("offensive") message: show a notice with a "Show" link, never the text itself
	local lineID = select(11, ...)
	local cid = (not isSystem and CensoredLine(lineID)) and lineID or nil
	local placeholder = cid and (UI.Hex(C.muted) .. L.CW_CENSORED .. " |Hcpcensor:" .. cid .. "|h[" .. L.CW_SHOW .. "]|h|r") or nil
	local mentioned = not cid and not isOwn and not isSystem and ns.FindMention and ns:FindMention(msg)
	local key = (isSystem and "~system" or tostring(ns.Normalize(author) or author)) .. "|" .. chatType .. "|" .. tostring(channelNumber or "")
	local styled = ns.S.chatStyle ~= false

	for _, w in ipairs(targets) do
		local args, n = RunFilters(w.msg, event, ...)
		if args then
			if cid then args[1] = placeholder end
			local ok, text, r, g, b
			if styled then
				ok = true
				local now = time()
				local calm = CALM[chatType] or { r or 1, g or 1, b or 1 }
				-- a calm divider after a longer pause
				if w.lastT and now - w.lastT > 900 then
					AddLine(w, UI.Hex(C.muted) .. "—  " .. date("%H:%M", now) .. "  —|r", 1, 1, 1, true)
					w.lastKey = nil
				end
				local body = args[1]
				if type(body) ~= "string" then body = tostring(body or "") end
				if chatType == "GUILD_ACHIEVEMENT" then
					-- "%s has earned ..." -> fill in the name, show it as a notice
					local okF, full = pcall(Format, event, unpack(args, 1, n))
					body = okF and full and full:gsub("^.-|r ", "") or body
					isSystem = true
				end
				if isSystem then
					-- system notice: one muted line with a dot
					text, r, g, b = Dot(calm) .. "  " .. body, calm[1], calm[2], calm[3]
					w.lastKey = nil
				else
					if not (w.lastKey == key and w.lastT and now - w.lastT <= 120) then
						-- header: dot, name (class colour / "You"), small time, label
						styleOwn = isOwn and true or false
						local link = PlayerLink(chatType, author, select(11, ...), guid, select(13, ...), channelNumber)
						styleOwn = false
						if chatType:find("_INFORM$") then
							link = ("|Hplayer:%s:%s:%s:|h[%s]|h"):format(UnitName("player") or "", tostring(select(11, ...) or 0), "WHISPER", UI.Hex(C.accent) .. L.WH_YOU .. "|r")
						end
						if (ns.S.showLevels or ns.S.shortSurnames) and ns.AddLevels then
							local okL, out = pcall(ns.AddLevels, link)
							if okL and out then link = out end
						end
						local stripe = StripeColor(isOwn, mentioned, class, calm)
						local label = ChannelLabel(chatType, channelNumber, select(9, ...), select(4, ...), author)
						local head = HeadMark(stripe) .. PlainName(link) .. "  " .. UI.Hex(C.muted) .. date("%H:%M", now)
							.. (label and (" · " .. label) or "") .. "|r"
						AddLine(w, head, 1, 1, 1, true)
					end
					local lang = select(3, ...)
					if type(lang) == "string" and lang ~= "" and GetDefaultLanguage and lang ~= GetDefaultLanguage("player") then
						body = "[" .. lang .. "] " .. body
					end
					if chatType == "EMOTE" then body = "* " .. body end
					if mentioned then
						text, r, g, b = BODY .. body, C.orange[1], C.orange[2], C.orange[3]
					else
						text, r, g, b = BODY .. body, calm[1], calm[2], calm[3]
					end
				end
				w.lastKey, w.lastT = key, now
			else
				ok, text, r, g, b = pcall(Format, event, unpack(args, 1, n))
			end
			if ok and text then
				AddLine(w, text, r, g, b, true, cid, placeholder)
				ns:CW_Notify(w, event, cid and "" or (...), select(2, ...))
				local a = { ... }
				local t = TargetOf(event, a[2], a[8], a[9], a[13])
				if t and not (t.type == "WHISPER" and Ambiguate and Ambiguate(t.name, "none") == UnitName("player")) then
					Remember(w, t)
					if w.group and w.group.data and w.group.data.active == w.data.id and not w.group.input:HasFocus() then
						ns:CW_UpdateChip(w.group)
					end
				end
			end
		end
	end
end

local evFrame = CreateFrame("Frame")
for ev in pairs(EVENT_CAT) do evFrame:RegisterEvent(ev) end
evFrame:RegisterEvent("CHAT_MSG_CHANNEL")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
-------------------------------------------------------------------------------
-- Is the person of a whisper window online? Only what the game tells us is used:
-- friends, Battle.net friends, guild, group, nearby/target, and who spoke to you lately.
-------------------------------------------------------------------------------
local seenWhisper = {} -- key -> { t = when we last heard from / delivered to them, offline = true when the game said so }

function ns.CW_PartnerOnline(p)
	if not p then return false end
	if p.bn then
		local ok, res = pcall(function()
			local acc = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(p.id)
			local g = acc and acc.gameAccountInfo
			return g and g.isOnline
		end)
		return ok and res and true or false
	end
	local key = p.key
	local st = seenWhisper[key]
	-- the game just said they left: believe that until the roster catches up
	if st and st.offline and GetTime() - st.t < 15 then return false end
	if ns.live and ns.live[key] then
		if st then st.offline = nil end
		return true
	end
	if st and not st.offline and GetTime() - st.t < 600 then return true end
	return false
end

local function RefreshStatus()
	for _, w in pairs(wins) do
		local p = w.data.partner
		local tab = w.tab
		if tab and tab.status then
			if p then
				local on = ns.CW_PartnerOnline(p)
				if on then tab.status:SetColorTexture(0.30, 0.85, 0.45, 1) else tab.status:SetColorTexture(0.45, 0.48, 0.54, 1) end
				tab.status:Show()
			else
				tab.status:Hide()
			end
		end
	end
end
ns.CW_RefreshStatus = RefreshStatus

-- "No player named 'X' is currently playing." -> X
local function NotFoundName(msg)
	local fmt = _G.ERR_CHAT_PLAYER_NOT_FOUND_S
	if type(fmt) ~= "string" or type(msg) ~= "string" then return end
	local pat = "^" .. fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"
	return msg:match(pat)
end

local function Offline(msg)
	if not ns.Usable(msg) then return end
	local name = NotFoundName(msg)
	if not name or name == "" then return end
	local key = ns.Normalize(name)
	local short = name:lower()
	for _, w in pairs(wins) do
		local p = w.data.partner
		if p and not p.bn and w.group and (p.key == key or Ambiguate(p.key, "short"):lower() == short or Ambiguate(p.name or "", "short"):lower() == short) then
			seenWhisper[p.key] = { t = GetTime(), offline = true }
			AddLine(w, UI.Hex(C.muted) .. L.CW_OFFLINE:format(Ambiguate(p.name or name, "none")) .. "|r", 0.62, 0.67, 0.74, false)
		end
	end
	RefreshStatus()
end

-- a person of a whisper window comes online / goes offline
local function Presence(msg)
	if not ns.Usable(msg) then return end
	local name, online = PresenceOf(msg)
	if not name then return end
	local key = ns.Normalize(name)
	local short = Ambiguate(name, "short"):lower()
	for _, w in pairs(wins) do
		local p = w.data.partner
		if p and not p.bn and w.group and (p.key == key or Ambiguate(p.key, "short"):lower() == short) then
			seenWhisper[p.key] = online and { t = GetTime() } or { t = GetTime(), offline = true }
			if not (w.data.cats.presence or w.data.cats.system) then
				local txt = (online and L.CW_NOW_ON or L.CW_NOW_OFF):format(Ambiguate(p.name or name, "none"))
				AddLine(w, UI.Hex(C.muted) .. txt .. "|r", 0.62, 0.67, 0.74, false)
			end
		end
	end
	RefreshStatus()
end

local stFrame = CreateFrame("Frame")
stFrame:RegisterEvent("CHAT_MSG_SYSTEM")
stFrame:RegisterEvent("CHAT_MSG_WHISPER")
stFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
stFrame:SetScript("OnEvent", function(_, event, msg, author)
	if not ns.loggedIn then return end
	if event == "CHAT_MSG_SYSTEM" then
		pcall(Offline, msg)
		pcall(Presence, msg)
	elseif ns.Usable(author) then
		local key = ns.Normalize(author)
		if key then seenWhisper[key] = { t = GetTime() } end
		pcall(RefreshStatus)
	end
end)
do
	local acc = 0
	stFrame:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 8 then return end
		acc = 0
		if next(wins) then
			if ns.RefreshLive then pcall(ns.RefreshLive, ns) end
			pcall(RefreshStatus)
		end
	end)
end
ns._cwOffline = Offline

evFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		-- a fight starts: give the keyboard back to the game if nothing is being typed
		for _, g in ipairs(groups) do
			local eb = g.input
			if eb and eb:HasFocus() and (eb:GetText() or "") == "" then eb:ClearFocus() end
		end
		if ns.ReleaseNoteFocus then ns:ReleaseNoteFocus() end
		return
	end
	if not ns.S or not ns.loggedIn then return end
	local ok, err = pcall(Deliver, event, ...)
	if not ok then ns.ReportError("window", err) end
end)

-------------------------------------------------------------------------------
-- Filter menu
-------------------------------------------------------------------------------
local function BuildMenu()
	menu = CreateFrame("Frame", "ChatPilotWindowMenu", UIParent)
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	UI.Fill(menu, C.bg)
	UI.Border(menu, C.border)
	local title = UI.Text(menu, "GameFontHighlight")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(L.CW_FILTER)
	local glow = UI.Glow(menu)
	glow:SetPoint("TOPLEFT", 1, -1)
	glow:SetPoint("TOPRIGHT", -1, -1)
	glow:SetHeight(2)
	menu.rows = {}
	for i, c in ipairs(CATS) do
		local r = CreateFrame("Frame", nil, menu)
		r:SetSize(220, 26)
		r:SetPoint("TOPLEFT", 8, -32 - (i - 1) * 27)
		r.label = UI.Text(r, "GameFontHighlight")
		r.label:SetPoint("LEFT", 6, 0)
		r.label:SetText(L["CAT_" .. c.key])
		r.toggle = UI.Toggle(r, function(v)
			local w = menu.group and wins[menu.group.data.active]
			if not w then return end
			w.data.cats[c.key] = v or nil
			LayoutTabs(menu.group)
			if not w.data.last then w.target = nil end
			ns:CW_UpdateChip(menu.group)
		end)
		r.toggle:SetPoint("RIGHT", -6, 0)
		menu.rows[c.key] = r
	end
	local hint = UI.Text(menu, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("TOPLEFT", 14, -32 - #CATS * 27 - 6)
	hint:SetWidth(210)
	hint:SetSpacing(2)
	hint:SetText(L.CW_MENU_HINT)
	local clear = UI.ConfirmButton(menu, L.CW_CLEAR, 210, 24, function()
		local w = menu.group and wins[menu.group.data.active]
		if w then ns:CW_ClearWindow(w) end
		menu:Hide()
	end)
	clear:SetPoint("TOPLEFT", 13, -32 - #CATS * 27 - 62)
	menu.clear = clear
	menu:SetSize(236, 32 + #CATS * 27 + 62 + 34)
	menu:Hide()
	tinsert(UISpecialFrames, "ChatPilotWindowMenu")
end

function ns:CW_OpenMenu(g)
	if not menu then BuildMenu() end
	local w = wins[g.data.active]
	if not w then return end
	menu.group = g
	for key, r in pairs(menu.rows) do r.toggle:SetValue(w.data.cats[key]) end
	menu:ClearAllPoints()
	local f = g.frame
	if (f:GetTop() or 0) + menu:GetHeight() + 10 < (UIParent:GetTop() or 768) then
		menu:SetPoint("BOTTOMRIGHT", g.filter, "TOPRIGHT", 0, 4)
	else
		menu:SetPoint("TOPRIGHT", g.filter, "BOTTOMRIGHT", 0, -4)
	end
	menu:Show()
end

function ns:CW_ToggleMenu(g)
	if menu and menu:IsShown() and menu.group == g then menu:Hide() else self:CW_OpenMenu(g) end
end

-------------------------------------------------------------------------------
-- Target chip, target list and sending
-------------------------------------------------------------------------------
local function Current(g)
	local w = g and g.data and wins[g.data.active]
	if not w then return end
	if not w.target then
		w.target = w.data.last or Targets(w)[1]
	end
	return w, w.target
end

function ns:CW_UpdateChip(g)
	local w, t = Current(g)
	if not w then return end
	if g.input:HasFocus() == false and w.data.last and not w.pinned then t = w.data.last; w.target = t end
	g.chip.text:SetText(TargetLabel(t))
	g.chip.text:SetTextColor(TargetColor(t))
	local width = math.min(math.max((g.chip.text:GetStringWidth() or 40) + 18, 50), 140)
	g.chip:SetWidth(width)
	g.chip.text:SetWidth(width - 12)
end

function ns:CW_SetTarget(g, t)
	local w = Current(g)
	if not w then return end
	w.target = t
	w.pinned = true -- chosen by you: stays until you pick another one
	Remember(w, t, true)
	self:CW_UpdateChip(g)
end

function ns:CW_ResetTarget(g)
	local w = Current(g)
	if not w or not w.pinned then return end
	w.pinned = nil
	-- back to the automatic target: where the last message came from, else the filter's default
	local def = w.data.last
	if not def then
		for _, c in ipairs(CATS) do
			if w.data.cats[c.key] and CAT_TARGETS[c.key] then def = CAT_TARGETS[c.key][1] break end
		end
	end
	w.target = def
	self:CW_UpdateChip(g)
end

local tmenu
function ns:CW_TargetMenu(g)
	local w = Current(g)
	if not w then return end
	if not tmenu then
		tmenu = CreateFrame("Frame", "ChatPilotTargetMenu", UIParent)
		tmenu:SetFrameStrata("DIALOG")
		tmenu:SetClampedToScreen(true)
		tmenu:EnableMouse(true)
		UI.Fill(tmenu, C.bg)
		UI.Border(tmenu, C.border)
		tmenu.rows = {}
		tinsert(UISpecialFrames, "ChatPilotTargetMenu")
		tmenu:Hide()
	end
	if tmenu:IsShown() and tmenu.group == g then tmenu:Hide() return end
	tmenu.group = g
	local list = Targets(w)
	for i, t in ipairs(list) do
		local r = tmenu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, tmenu)
			r:SetHeight(22)
			r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
			r:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * 22)
			local hl = r:CreateTexture(nil, "BACKGROUND")
			hl:SetAllPoints()
			UI.Paint(hl, C.rowHover)
			hl:Hide()
			r:SetScript("OnEnter", function() hl:Show() end)
			r:SetScript("OnLeave", function() hl:Hide() end)
			r.text = UI.NoShadow(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
			r.text:SetPoint("LEFT", 8, 0)
			tmenu.rows[i] = r
		end
		r.text:SetText(TargetLabel(t))
		r.text:SetTextColor(TargetColor(t))
		r:SetScript("OnClick", function()
			tmenu:Hide()
			ns:CW_SetTarget(g, t)
			g.input:SetFocus()
		end)
		r:Show()
	end
	for i = #list + 1, #tmenu.rows do tmenu.rows[i]:Hide() end
	if #list == 0 then
		ns.Print(L.CW_NO_TARGET_HINT)
		return
	end
	tmenu:SetSize(180, #list * 22 + 8)
	tmenu:ClearAllPoints()
	tmenu:SetPoint("BOTTOMLEFT", g.chip, "TOPLEFT", 0, 4)
	tmenu:Show()
end

-- "Show" on a hidden message: released by your click, then written again everywhere
function ns:CW_Reveal(cid)
	local api = C_ChatInfo
	if api and api.UncensorChatLine then pcall(api.UncensorChatLine, cid) end
	local text
	if api and api.GetChatLineText then
		local ok, t = pcall(api.GetChatLineText, cid)
		if ok and type(t) == "string" and ns.Usable(t) and t ~= "" then text = t end
	end
	local rep = text or (UI.Hex(C.muted) .. L.CW_CENSOR_GONE .. "|r")
	for _, w in pairs(wins) do
		local hit = false
		for _, e in ipairs(w.live or {}) do
			if e[5] == cid and e[6] then
				e[1] = ReplacePlain(e[1], e[6], rep)
				e[5], e[6] = nil, nil
				hit = true
			end
		end
		for _, l in ipairs(w.data.lines) do
			if l[6] == cid and l[7] then
				l[1] = ReplacePlain(l[1], l[7], rep)
				l[6], l[7] = nil, nil
			end
		end
		if hit then
			w.msg:Clear()
			for _, e in ipairs(w.live) do w.msg:AddMessage(e[1], e[2], e[3], e[4]) end
		end
	end
end

-- short flash on the input bar: the message left
function ns:CW_SendFlash(g)
	local holder = g.inputHolder
	if not holder then return end
	local fl = g.sendFlash
	if not fl then
		fl = CreateFrame("Frame", nil, holder)
		fl:SetAllPoints(holder)
		fl:SetFrameLevel(holder:GetFrameLevel() + 5)
		fl.tex = fl:CreateTexture(nil, "OVERLAY")
		fl.tex:SetAllPoints()
		fl.tex:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
		fl:SetScript("OnUpdate", function(self, dt)
			self.a = (self.a or 0) - (dt or 0.016) * 3.2
			if self.a <= 0 then self:Hide() return end
			self.tex:SetAlpha(self.a)
		end)
		g.sendFlash = fl
	end
	fl.a = 0.55
	fl.tex:SetAlpha(fl.a)
	fl:Show()
end

function ns:CW_Submit(g)
	local eb = g.input
	local text = eb:GetText() or ""
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then eb:ClearFocus() return end
	local w, t = Current(g)
	if text:sub(1, 1) == "/" then
		local ct, rest = ParseCommand(w, text, true)
		if ct then
			-- "/w Name" + Enter: just set the target (like the game); with text: send it here
			self:CW_SetTarget(g, ct)
			t = ct
			text = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if text == "" then eb:SetText(""); return end
		end
	end
	if text:sub(1, 1) == "/" or not t or Locked() then
		-- slash commands and restricted moments go through the game's own chat box
		eb:SetText("")
		eb:ClearFocus()
		HandOver(t, text)
		return
	end
	local ok = pcall(Send, t, text)
	if ok then
		-- first the input itself: empty it and give the keyboard back, then the extras
		if eb.AddHistoryLine then eb:AddHistoryLine(text) end
		eb:SetText("")
		-- like the normal chat: after sending, the keyboard goes back to the game
		-- (otherwise ability keys would end up in the input box in a fight)
		eb:ClearFocus()
		pcall(ns.CW_SendFlash, ns, g)
		if w and w.msg then pcall(function() w.msg:ScrollToBottom(); HideNewHint(w) end) end
		if t.type == "WHISPER" and ChatEdit_SetLastTellTarget and ns.Usable(t.name) then
			pcall(ChatEdit_SetLastTellTarget, t.name, "WHISPER")
		end
	else
		eb:SetText("")
		eb:ClearFocus()
		HandOver(t, text)
	end
end

-- Enter in the game opens its own input box. After you clicked into one of our
-- windows (sent something or not), the next Enter brings you back to the same
-- window and chat instead (its target is remembered there). Sending in the
-- game's own box ends this.
local function EnterToWindow(text)
	local g = ns.cwLast
	if not g or (type(text) == "string" and text ~= "") then return end
	if Locked() or not g.input or not g.frame or not g.frame:IsVisible() then return end
	if g.input:HasFocus() then return end
	local box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if box and box.GetAttribute then
		-- a game command that picked its own chat (e.g. reply) is left alone
		local okA, ct, st = pcall(function() return box:GetAttribute("chatType"), box:GetAttribute("stickyType") end)
		if okA and ct and st and ct ~= st then return end
	end
	if box and box.IsShown and box:IsShown() then
		if ChatEdit_DeactivateChat then pcall(ChatEdit_DeactivateChat, box) else box:Hide() end
	end
	g.input:SetFocus()
end
local function GameSent(editBox)
	ns.cwLast = nil
	-- sending jumps that game chat window to its newest line
	if type(editBox) == "table" then
		local cf = rawget(editBox, "chatFrame")
		if cf and cf.ScrollToBottom then pcall(cf.ScrollToBottom, cf) end
	end
end
-- clicking a game chat window hands Enter back to the game
ns.OnChatFrame(function(frame)
	pcall(frame.HookScript, frame, "OnMouseDown", GameSent)
	-- the game's input bar and its tabs too
	local name = frame.GetName and frame:GetName()
	local box = rawget(frame, "editBox") or (name and _G[name .. "EditBox"])
	if box and box.HookScript then pcall(box.HookScript, box, "OnMouseDown", GameSent) end
	local tab = name and _G[name .. "Tab"]
	if tab and tab.HookScript then pcall(tab.HookScript, tab, "OnMouseDown", GameSent) end
end)

local function HookFn(tbl, name, fn)
	if tbl and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) return true end
end
HookFn(_G, "ChatFrame_OpenChat", EnterToWindow)
HookFn(ChatFrameUtil, "OpenChat", EnterToWindow)
-- Shift-click an item (bag, chat link ...): the game puts the link into ITS box.
-- With one of our inputs in use, the link goes there instead.
local lastInsert, lastInsertAt
local function InsertToWindow(text)
	local eb = ns.cwFocusEB
	if not eb or type(text) ~= "string" or not ns.Usable(text) then return end
	local now = GetTime()
	if lastInsert == text and lastInsertAt == now then return end
	local mine = eb:HasFocus()
	if not mine and not (ns.cwLostAt and now - ns.cwLostAt < 0.25) then return end
	if Locked() then return end
	lastInsert, lastInsertAt = text, now
	if not mine then
		local box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
		if box then
			pcall(box.SetText, box, "")
			if ChatEdit_DeactivateChat then pcall(ChatEdit_DeactivateChat, box) end
		end
		eb:SetFocus()
	end
	eb:Insert(text)
end
ns.cwInsert = InsertToWindow
HookFn(_G, "ChatEdit_InsertLink", InsertToWindow)
HookFn(ChatFrameUtil, "InsertLink", InsertToWindow)
HookFn(_G, "ChatEdit_SendText", GameSent)
HookFn(ChatFrameUtil, "SendText", GameSent)

-------------------------------------------------------------------------------
-- Bell: sound + small notice for new messages in a window
-------------------------------------------------------------------------------
function ns:CW_UpdateBell(g)
	local w = g and g.data and wins[g.data.active]
	if not w then return end
	local on = w.data.bell and true or false
	if g.bell.icon.SetDesaturated then g.bell.icon:SetDesaturated(not on) end
	g.bell.icon:SetAlpha(on and 1 or 0.45)
	g.bell.slash:SetShown(not on)
	g.bell.tip = on and L.CW_BELL_ON or L.CW_BELL_OFF
end

function ns:CW_ToggleBell(g)
	local w = g and g.data and wins[g.data.active]
	if not w then return end
	w.data.bell = not w.data.bell or nil
	self:CW_UpdateBell(g)
	GameTooltip:SetOwner(g.bell, "ANCHOR_TOP")
	GameTooltip:SetText(g.bell.tip)
	GameTooltip:Show()
end

function ns:CW_Notify(w, event, msg, author)
	if not w.data.bell or not w.group or not w.group.data then return end
	if event:find("_INFORM$") then return end -- your own outgoing whispers
	if type(author) == "string" and ns.Usable(author) and Ambiguate
		and Ambiguate(author, "none") == UnitName("player") then return end
	local g = w.group
	if g.input:HasFocus() and g.data.active == w.data.id then return end
	local now = GetTime()
	if w.lastBell and now - w.lastBell < 3 then return end
	w.lastBell = now
	PlaySound((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master")
	if ns.ShowToast then
		local text = ""
		if type(msg) == "string" and ns.Usable(msg, author) then
			local who = Ambiguate and Ambiguate(author or "", "none") or author or ""
			text = (who ~= "" and (who .. ": ") or "") .. ns.StripEscapes(msg)
			if #text > 90 then text = text:sub(1, 88):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
		end
		ns:ShowToast(WindowName(w), text, function()
			g.frame:Show()
			Select(g, w)
			g.input:SetFocus()
		end, C.accent)
	end
end

-------------------------------------------------------------------------------
-- Create / delete / restore
-------------------------------------------------------------------------------
local function BuildWindow(wdata)
	local w = { data = wdata }
	w.msg = CreateMessageFrame(w)
	w.tab = CreateTab(w)
	wins[wdata.id] = w
	-- restore saved lines (last 3 days)
	local now = time()
	local restored = false
	for _, l in ipairs(wdata.lines) do
		if now - (l[5] or 0) < 3 * 86400 then
			local text = l[1]
			-- a hidden message from an earlier session can no longer be released
			if l[6] and l[7] then text = ReplacePlain(text, l[7], UI.Hex(C.muted) .. L.CW_CENSOR_GONE .. "|r") end
			w.msg:AddMessage(text, l[2], l[3], l[4])
			Live(w, text, l[2], l[3], l[4])
			restored = true
		end
	end
	if restored then
		local sep = UI.Hex(C.muted) .. "— " .. L.CW_HISTORY .. " —|r"
		w.msg:AddMessage(sep)
		Live(w, sep)
	end
	return w
end

-- cats: table of category keys (optional). into: dock into this group.
function ns:CW_New(cats, into)
	if not Data then return end
	if Data.hidden then
		Data.hidden = false
		for _, o in ipairs(groups) do o.frame:SetShown(not o.data.main or o.mainOpen or false) end
		UpdateLaunchers()
	end
	Data.nextId = (Data.nextId or 0) + 1
	local wdata = { id = Data.nextId, cats = {}, lines = {} }
	for k, v in pairs(cats or { whisper = true }) do wdata.cats[k] = v end
	Data.windows[#Data.windows + 1] = wdata
	local w = BuildWindow(wdata)
	local g
	if into and into.data then
		g = into
		table.insert(g.data.order, wdata.id)
		Attach(g, w)
	else
		local k = #Data.groups % 6
		local d = { order = { wdata.id }, active = wdata.id, w = 380, h = 200,
			x = math.floor((UIParent:GetWidth() or 1024) / 2 - 190 + k * 26), y = math.floor((UIParent:GetHeight() or 768) / 2 + 160 - k * 26) }
		Data.groups[#Data.groups + 1] = d
		g = NewGroup(d)
	end
	Select(g, w)
	self:CW_OpenMenu(g)
	return w
end

-- A whisper conversation as its own chat window (from "Missed whispers").
-- conv: { key, name, bn, c (class), msgs = { {t, m, o} } }. drag = start moving it under the mouse.
function ns:CW_OpenConversation(conv, drag)
	if not Data or not conv or not conv.key then return end
	local bnID = conv.bn and tonumber(tostring(conv.key):match("^bn:(%d+)$"))
	local partner = {
		key = conv.key, bn = conv.bn and true or nil, id = bnID,
		name = conv.target or conv.name, label = conv.name,
	}
	-- already open? just show it
	for _, w in pairs(wins) do
		local p = w.data.partner
		if p and p.key == partner.key then
			local g = w.group
			if g and g.data then
				if g.data.main then self:CW_OpenMain(g, w) else g.frame:Show(); Select(g, w) end
				if drag then StartDrag(g, w) end
			end
			return w
		end
	end
	Data.nextId = (Data.nextId or 0) + 1
	local wdata = { id = Data.nextId, cats = { whisper = true }, lines = {}, partner = partner }
	-- bring the conversation so far along
	local wr, wg, wb = TypeColor("WHISPER")
	local ir, ig, ib = TypeColor("WHISPER_INFORM")
	local who = conv.bn and ("|cff82c5ff" .. (conv.name or "?") .. "|r") or ns.ClassColorText(conv.name or "?", conv.c)
	local history = {}
	for _, m in ipairs(conv.msgs or {}) do
		local ts = UI.Hex(C.muted) .. date("%H:%M", m.t or time()) .. "|r "
		local head = m.o and ("> " .. who .. ": ") or (who .. ": ")
		history[#history + 1] = { ts .. head .. (m.m or ""), m.o and ir or wr, m.o and ig or wg, m.o and ib or wb, m.t or time() }
	end
	-- Battle.net names are only valid for this session, so those lines are not saved
	if not conv.bn then wdata.lines = history end
	Data.windows[#Data.windows + 1] = wdata
	local w = BuildWindow(wdata)
	if conv.bn then for _, l in ipairs(history) do w.msg:AddMessage(l[1], l[2], l[3], l[4]) end end
	local scale = UIParent:GetEffectiveScale() or 1
	local cx, cy = GetCursorPosition()
	local d = { order = { wdata.id }, active = wdata.id, w = 380, h = 220,
		x = math.floor(cx / scale - 60), y = math.floor(cy / scale + 12) }
	if not drag then
		d.x = math.floor((UIParent:GetWidth() or 1024) / 2 - 190)
		d.y = math.floor((UIParent:GetHeight() or 768) / 2 + 160)
	end
	Data.groups[#Data.groups + 1] = d
	if Data.hidden then Data.hidden = false end
	local g = NewGroup(d)
	Select(g, w)
	local t = conv.bn and bnID and { type = "BN_WHISPER", name = conv.name, id = bnID } or { type = "WHISPER", name = partner.name }
	self:CW_SetTarget(g, t)
	w.msg:ScrollToBottom()
	if drag then StartDrag(g) end
	return w
end

function ns:CW_Delete(w)
	local g = w.group
	if menu and menu:IsShown() then menu:Hide() end
	if g and g.data then RemoveFromGroup(g, w) end
	w.msg:Hide()
	w.tab:Hide()
	if w.launch then w.launch:Hide() end
	wins[w.data.id] = nil
	for i, d in ipairs(Data.windows) do if d == w.data then table.remove(Data.windows, i) break end end
	UpdateLaunchers()
end

function ns:CW_Count() return Data and #Data.windows or 0 end

-- empty one window: what is shown and what is saved for it
function ns:CW_ClearWindow(w)
	if not w then return end
	w.msg:Clear()
	w.live = nil
	if w.data.lines then wipe(w.data.lines) end
	w.data.archive = nil
	w.lastKey, w.lastT, w.count, w.unread = nil, nil, 0, nil
	if w.group then LayoutTabs(w.group) end
	UpdateLaunchers()
end

function ns:CW_ClearAll()
	for _, w in pairs(wins) do self:CW_ClearWindow(w) end
	-- also windows that are saved but not built right now
	if Data then for _, d in ipairs(Data.windows) do if d.lines then wipe(d.lines) end d.archive = nil end end
end

-- all own windows by name (for "empty when logging out")
function ns:CW_List()
	local list = {}
	if Data then
		for _, d in ipairs(Data.windows) do
			local w = wins[d.id]
			list[#list + 1] = { id = d.id, name = w and WindowName(w) or ("#" .. tostring(d.id)) }
		end
	end
	return list
end

function ns:CW_ClearById(id)
	local w = wins[id]
	if w then return self:CW_ClearWindow(w) end
	if Data then for _, d in ipairs(Data.windows) do if d.id == id then if d.lines then wipe(d.lines) end d.archive = nil end end end
end

-- archive of one window (list of plain text lines) and how many there are in all
function ns:CW_ArchiveGet(id)
	if Data then for _, d in ipairs(Data.windows) do if d.id == id then return d.archive or {} end end end
	return {}
end

function ns:CW_ArchiveCount()
	local n = 0
	if Data then for _, d in ipairs(Data.windows) do n = n + (d.archive and #d.archive or 0) end end
	return n
end

function ns:CW_ArchiveClear(id)
	if Data then for _, d in ipairs(Data.windows) do if d.id == id then d.archive = nil end end end
end

function ns:CW_SavedLines()
	local n = 0
	if Data then for _, d in ipairs(Data.windows) do n = n + (d.lines and #d.lines or 0) end end
	return n
end

function ns:CW_ToggleAll()
	if #groups == 0 then return self:CW_New() end
	local show = Data and Data.hidden or false
	for _, g in ipairs(groups) do
		if g.data.main then
			if not show then g.mainOpen = false end
			g.frame:SetShown(show and g.mainOpen or false)
		else
			g.frame:SetShown(show)
		end
	end
	if Data then Data.hidden = not show end
	UpdateLaunchers()
end

local function Restore()
	Data = ns.db.cwin
	-- drop broken references
	local byId = {}
	for _, wd in ipairs(Data.windows) do
		wd.cats = wd.cats or {}
		wd.lines = wd.lines or {}
		byId[wd.id] = wd
	end
	for _, wd in ipairs(Data.windows) do BuildWindow(wd) end
	local used = {}
	for i = #Data.groups, 1, -1 do
		local d = Data.groups[i]
		local order = {}
		for _, id in ipairs(d.order or {}) do
			if byId[id] and not used[id] then order[#order + 1] = id; used[id] = true end
		end
		d.order = order
		if #order == 0 then table.remove(Data.groups, i) end
	end
	-- windows without a group get their own
	for _, wd in ipairs(Data.windows) do
		if not used[wd.id] then
			Data.groups[#Data.groups + 1] = { order = { wd.id }, active = wd.id, w = 380, h = 200, x = 300, y = 500 }
		end
	end
	for _, d in ipairs(Data.groups) do
		if not byId[d.active] then d.active = d.order[1] end
		local g = NewGroup(d)
		Select(g, wins[d.active])
		if Data.hidden or d.main then g.frame:Hide() end
	end
end

-------------------------------------------------------------------------------
-- Docking into the main chat. A window dropped onto the main chat gets its own
-- tab next to the game's chat tabs; clicking it shows the window exactly over
-- the main chat, clicking one of the game's tabs switches back. (Addons cannot
-- put frames into the game's own tab bar, so this works alongside it.)
-------------------------------------------------------------------------------
local mainDrop

function ns:OverMainChat()
	local main = MainChat()
	if not main or not main.IsVisible or not main:IsVisible() or not main:GetLeft() then return false end
	-- ask the game first (works whatever the chat's scale is), incl. the tab row above it
	if MouseIsOver then
		local ok, over = pcall(MouseIsOver, main, 34, -8, -6, 6)
		if ok and over then return true end
		local tab = rawget(main, "tab") or (main.GetName and _G[(main:GetName() or "") .. "Tab"])
		if tab and tab.IsVisible and tab:IsVisible() then
			local ok2, overTab = pcall(MouseIsOver, tab)
			if ok2 and overTab then return true end
		end
	end
	-- fallback: compare in real screen pixels
	local s = (main.GetEffectiveScale and main:GetEffectiveScale()) or 1
	local x, y = GetCursorPosition()
	return x >= main:GetLeft() * s and x <= main:GetRight() * s
		and y >= main:GetBottom() * s and y <= (main:GetTop() + 34) * s
end

function ns:ShowMainDrop(on)
	local main = MainChat()
	if not main then return end
	if not mainDrop then
		mainDrop = CreateFrame("Frame", nil, UIParent)
		mainDrop:SetFrameStrata("DIALOG")
		local t = mainDrop:CreateTexture(nil, "OVERLAY")
		t:SetAllPoints()
		UI.Paint(t, C.accentDim)
		UI.Border(mainDrop, C.accent)
		mainDrop.text = UI.Text(mainDrop, "GameFontHighlightLarge", C.accent)
		mainDrop.text:SetPoint("CENTER")
		mainDrop.text:SetText(L.CW_DOCK_MAIN)
	end
	mainDrop:ClearAllPoints()
	mainDrop:SetPoint("TOPLEFT", main, "TOPLEFT", -4, 30)
	mainDrop:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 4, -6)
	mainDrop:SetShown(on and true or false)
end

local function CloseMainOverlays(except)
	local changed = false
	for _, g in ipairs(groups) do
		if g.data and g.data.main and g ~= except and g.mainOpen then
			g.mainOpen = false
			g.frame:Hide()
			changed = true
		end
	end
	return changed
end

function ns:CW_OpenMain(g, w)
	if not g or not g.data then return end
	CloseMainOverlays(g)
	g.mainOpen = true
	if Data then Data.hidden = false end
	Place(g)
	g.frame:Show()
	g.frame:Raise()
	Select(g, w or wins[g.data.active])
	UpdateLaunchers()
end

-- rightmost visible tab of the game's main chat dock
local function LastGameTab()
	local main = MainChat()
	local mainTab = main and (rawget(main, "tab") or (main.GetName and _G[(main:GetName() or "") .. "Tab"]))
	if not mainTab or not mainTab.GetBottom or not mainTab:GetBottom() then return mainTab end
	local best, right = mainTab, mainTab:GetRight() or 0
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local tab = _G["ChatFrame" .. i .. "Tab"]
		if tab and tab:IsVisible() and tab:GetRight() and math.abs((tab:GetBottom() or 0) - mainTab:GetBottom()) < 8
			and tab:GetRight() > right then
			best, right = tab, tab:GetRight()
		end
	end
	return best
end

local launchers = {}

local function CreateLauncher(w)
	local b = CreateFrame("Button", nil, UIParent)
	b:SetHeight(22)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b.bg = UI.Fill(b, C.btn)
	b.hl = b:CreateTexture(nil, "BORDER")
	b.hl:SetAllPoints()
	UI.Paint(b.hl, C.accentDim)
	b.hl:Hide()
	b.line = UI.Glow(b, "OVERLAY")
	b.line:SetPoint("BOTTOMLEFT", 3, 0)
	b.line:SetPoint("BOTTOMRIGHT", -3, 0)
	b.line:SetHeight(2)
	b.text = MarqueeText(b, 9, 7)
	b.dot = b:CreateTexture(nil, "OVERLAY")
	b.dot:SetSize(5, 5)
	b.dot:SetPoint("TOPRIGHT", -3, -3)
	UI.Paint(b.dot, C.orange)
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then return StartRename(w, self) end
		local g = w.group
		if not g then return end
		if g.mainOpen and g.data.active == w.data.id then return end
		ns:CW_OpenMain(g, w)
	end)
	b:SetScript("OnDragStart", function() if w.group then StartDrag(w.group, w) end end)
	b:SetScript("OnEnter", function(self)
		self.hl:Show()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(WindowName(w))
		GameTooltip:AddLine(L.CW_MAIN_TAB_TIP, 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(L.CW_RENAME_TIP, 0.31, 0.79, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
	b:EnableMouseWheel(true)
	b:SetScript("OnMouseWheel", function(_, delta) ns:CW_TabWheel(delta) end)
	return b
end

local launchRow -- scrollable row for our tabs in the main chat

function UpdateLaunchers()
	wipe(launchers)
	local main = MainChat()
	local hidden = Data and Data.hidden
	local gameTab = LastGameTab()
	if not launchRow and main then
		launchRow = TabRow(UIParent)
		launchRow:SetFrameStrata((main.GetFrameStrata and main:GetFrameStrata()) or "LOW")
		launchRow:SetHeight(22)
		launchRow.Relayout = function() UpdateLaunchers() end
	end
	if launchRow then
		launchRow:ClearAllPoints()
		if gameTab then
			launchRow:SetPoint("BOTTOMLEFT", gameTab, "BOTTOMRIGHT", 3, 0)
		else
			launchRow:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, 4)
		end
		-- up to the right edge of the chat; the "+" sits right after the last tab
		-- (and moves into the ▾ list when the tabs need the whole width)
		local mainL = main.GetLeft and main:GetLeft() or 0
		local mainR = main.GetRight and main:GetRight() or (mainL + 400)
		local startX = (gameTab and gameTab.GetRight and gameTab:GetRight()) and (gameTab:GetRight() + 3) or mainL
		launchRow:SetWidth(math.max(60, mainR - startX))
		launchRow.dropOutside = true -- the ▾ hangs just outside the chat's right edge
		if not launchRow.items then
			launchRow.items = function()
				local list = {}
				for _, w in ipairs(launchers) do
					local g = w.group
					list[#list + 1] = { label = WindowName(w), w = w, unread = w.unread,
						active = g and g.mainOpen and g.data and g.data.active == w.data.id }
				end
				if launchRow.plusInMenu then
					list[#list + 1] = { label = UI.Hex(C.accent) .. "+|r  " .. L.CW_NEW, isNew = true }
				end
				return list
			end
			launchRow.onPick = function(it)
				if it.isNew then return ns:CW_New() end
				if it.w.group then ns:CW_OpenMain(it.w.group, it.w) end
			end
			launchRow.onDrag = function(it) if it.w and it.w.group then StartDrag(it.w.group, it.w) end end
		end
	end
	local x, ax1, ax2 = 0, nil, nil
	local spans = {}
	-- natural widths first, then the tabs fill the room up to the ▾ at the right edge
	local list, widths, total = {}, {}, 0
	for _, g in ipairs(groups) do
		for _, id in ipairs(g.data and g.data.main and g.data.order or {}) do
			local w = wins[id]
			if w and launchRow then
				w.launch = w.launch or CreateLauncher(w)
				w.launch.text:SetText(WindowName(w))
				list[#list + 1] = { g = g, id = id, w = w }
				widths[#list] = FixedTabWidth(w.launch.text, 9 + 7 + 2) -- same size for every tab
				total = total + widths[#list] + (#list > 1 and 3 or 0)
			end
		end
	end

	for i, e in ipairs(list) do
		local g, id, w = e.g, e.id, e.w
		do
			do
				local b = w.launch
				b:SetParent(launchRow.strip)
				b:SetFrameLevel(launchRow.strip:GetFrameLevel() + 2)
				local width = widths[i]
				b:SetWidth(width)
				if b.UpdateMarquee then b:UpdateMarquee() end
				b:ClearAllPoints()
				b:SetPoint("BOTTOMLEFT", launchRow.strip, "BOTTOMLEFT", x, 0)
				local active = g.mainOpen and (not g.IsShown or g:IsShown()) and g.data.active == id
				if active then ax1, ax2 = x, x + width end
				spans[#spans + 1] = { b, x, x + width, active = active }
				x = x + width + 3
				b.line:SetShown(active)
				UI.Ink(b.text, active and C.text or C.muted)
				if active then w.unread = false end
				b.dot:SetShown(w.unread and not active or false)
				DotGlow(b, w.unread and not active)
				b:Show()
				launchers[#launchers + 1] = w
			end
		end
	end
	if launchRow then
		launchRow.width = math.max(0, x - 3)
		launchRow.spans = spans
		-- with tabs of ours here, the ▾ sits at the right edge and holds "+ New window"
		local fits = #launchers == 0
		launchRow.plusInMenu = not fits
		launchRow.forceDrop = not fits
		launchRow:SetShown(#launchers > 0 and not hidden)
		if ax1 then launchRow:Reveal(ax1, ax2) else launchRow:Apply() end
		if ns.CW_PlacePlus then ns:CW_PlacePlus(main, gameTab, launchRow, #launchers > 0 and not hidden, fits) end
	end
	-- windows that are no longer docked into the main chat lose their tab
	for _, w in pairs(wins) do
		if w.launch and not (w.group and w.group.data and w.group.data.main) then w.launch:Hide() end
	end
end
ns.CW_UpdateLaunchers = function() UpdateLaunchers() end

-- the game's tabs keep working: picking one of them hides our window again
local function OnGameTabSelected()
	CloseMainOverlays()
	-- always refresh: the marked tab must follow the tab you picked
	UpdateLaunchers()
	C_Timer.After(0, UpdateLaunchers)
end
if type(FCF_SelectDockFrame) == "function" then hooksecurefunc("FCF_SelectDockFrame", OnGameTabSelected) end
if type(FCF_Tab_OnClick) == "function" then
	hooksecurefunc("FCF_Tab_OnClick", function(_, button) if button ~= "RightButton" then OnGameTabSelected() end end)
end
-- The game moves its tabs now and then (new whisper tab, closed tab, docking).
-- A calm watcher re-lays out our tabs only when the game's last tab really moved.
local watch = CreateFrame("Frame")
local lastSig, elapsedSince = nil, 0
watch:SetScript("OnUpdate", function(_, e)
	elapsedSince = elapsedSince + e
	if elapsedSince < 0.4 then return end
	elapsedSince = 0
	if #launchers == 0 then return end
	local tab = LastGameTab()
	local main = MainChat()
	local sig = tostring(tab) .. ":" .. tostring(tab and tab.GetRight and math.floor((tab:GetRight() or 0) + 0.5))
		.. ":" .. tostring(main and main.GetRight and math.floor((main:GetRight() or 0) + 0.5))
	if sig ~= lastSig then
		lastSig = sig
		UpdateLaunchers()
	end
end)

-------------------------------------------------------------------------------
-- Mouse wheel over the chat tabs: flip through them (game tabs + our tabs)
-------------------------------------------------------------------------------
local function GameTabFrames()
	local list = {}
	local dock = GENERAL_CHAT_DOCK
	local frames = dock and FCFDock_GetChatFrames and FCFDock_GetChatFrames(dock)
	if type(frames) == "table" then
		for _, f in ipairs(frames) do
			local tab = rawget(f, "tab") or _G[(f:GetName() or "") .. "Tab"]
			if tab and tab:IsShown() then list[#list + 1] = f end
		end
	else
		local main = MainChat()
		if main then list[1] = main end
	end
	return list
end

function ns:CW_TabWheel(delta)
	if not self.S or not self.S.tabWheel then return end
	local frames = GameTabFrames()
	local entries = {}
	for _, f in ipairs(frames) do entries[#entries + 1] = { frame = f } end
	for _, w in ipairs(launchers) do
		if w.launch and w.launch:IsVisible() then entries[#entries + 1] = { win = w } end
	end
	if #entries < 2 then return end
	local cur = 1
	local sel = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
	for i, e in ipairs(entries) do
		if e.frame and e.frame == sel then cur = i end
	end
	for i, e in ipairs(entries) do
		local g = e.win and e.win.group
		if g and g.mainOpen and g.data.active == e.win.data.id then cur = i end
	end
	local nxt = math.max(1, math.min(#entries, cur - (delta > 0 and 1 or -1)))
	if nxt == cur then return end
	local e = entries[nxt]
	if e.win then
		self:CW_OpenMain(e.win.group, e.win)
	else
		OnGameTabSelected()
		if FCF_SelectDockFrame then pcall(FCF_SelectDockFrame, e.frame) end
		if FCFDock_ScrollToSelectedTab and GENERAL_CHAT_DOCK then pcall(FCFDock_ScrollToSelectedTab, GENERAL_CHAT_DOCK) end
	end
end

ns.OnChatFrame(function(frame)
	local tab = rawget(frame, "tab") or _G[(frame:GetName() or "") .. "Tab"]
	if not tab or rawget(tab, "ChatPilotWheel") then return end
	tab.ChatPilotWheel = true
	tab:EnableMouseWheel(true)
	tab:HookScript("OnMouseWheel", function(_, delta) ns:CW_TabWheel(delta) end)
end)

-------------------------------------------------------------------------------
-- "+" at the top right of the main chat: new chat window in one click
-------------------------------------------------------------------------------
local plus
local function BuildPlus()
	local main = ChatFrame1 or DEFAULT_CHAT_FRAME
	if plus or not main or not main.GetName then return end
	plus = CreateFrame("Button", nil, UIParent) -- not the chat itself: stays visible on every chat tab
	plus:SetSize(22, 22)
	plus:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 4, 6)
	plus:SetFrameStrata((main.GetFrameStrata and main:GetFrameStrata()) or "LOW") -- not above bank/bags
	plus.bg = UI.Fill(plus, C.btn)
	UI.Border(plus, C.border)
	plus.lines = {}
	IconLine(plus, 10, 2)
	IconLine(plus, 2, 10)
	for _, t in ipairs(plus.lines) do UI.Paint(t, C.accent) end
	plus:SetAlpha(0.85)
	plus:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		UI.Paint(self.bg, C.rowHover)
		self:SetBorderColor(unpack(C.accent))
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.CW_NEW)
		GameTooltip:AddLine(L.CW_PLUS_TIP, 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	plus:SetScript("OnLeave", function(self)
		self:SetAlpha(0.85)
		UI.Paint(self.bg, C.btn)
		self:SetBorderColor(unpack(C.border))
		GameTooltip:Hide()
	end)
	plus:SetScript("OnClick", function()
		GameTooltip:Hide()
		ns:CW_New()
	end)
end

-- the "+" is a little tab right after the last tab, so it never takes room
-- from the tab names; when the tabs need the whole width it is in the ▾ list
local plusPlace = { inMenu = false }
function ns:CW_PlacePlus(main, gameTab, row, rowShown, fits)
	if not plus then BuildPlus() end
	if not plus then return end
	plusPlace.inMenu = not fits
	plus:ClearAllPoints()
	if rowShown then
		plus:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", row.width + 4, 0)
	elseif gameTab then
		plus:SetPoint("BOTTOMLEFT", gameTab, "BOTTOMRIGHT", 4, 0)
	else
		plus:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 4, 6)
	end
	self:CW_UpdatePlus()
end

function ns:CW_UpdatePlus()
	if not plus then BuildPlus() end
	if plus then plus:SetShown(self.S.copyButton and not plusPlace.inMenu and true or false) end
end

UI.OnTheme(function()
	for _, g in ipairs(groups) do LayoutTabs(g) end
end)

local prevLogin = ns.OnLogin
function ns:OnLogin()
	if prevLogin then prevLogin(self) end
	self.db.cwin = self.db.cwin or {}
	local d = self.db.cwin
	d.windows = d.windows or {}
	d.groups = d.groups or {}
	pcall(Restore)
	self:CW_UpdatePlus()
	C_Timer.After(1, function() UpdateLaunchers() end)
end

ns._cwPlus = function() return plus end
ns._cwLaunchers = function() return launchers end
ns._cw = { wins = wins, groups = groups, Format = Format, Deliver = Deliver, FinishDrag = FinishDrag,
	StartDrag = StartDrag, ChannelCat = ChannelCat, Rename = StartRename, WindowName = WindowName,
	EnterToWindow = EnterToWindow, GameSent = GameSent, Offline = Offline, Presence = Presence, RefreshStatus = RefreshStatus, SeenWhisper = seenWhisper, CheckBottom = function(w) return CheckBottom(w) end } -- for tests
