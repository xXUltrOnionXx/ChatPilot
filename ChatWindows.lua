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
local MAX_SAVED_LINES = 100

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
	return baseName ~= "" and baseName or channelString or "?"
end

local function PlayerLink(chatType, author, lineID, guid, bnID, channelNumber)
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
		prefix = ("[%s. %s] %%s: "):format(tostring(channelNumber or "?"), baseName ~= "" and baseName or ResolveChannel(channelString, baseName))
	elseif chatType == "COMMUNITIES_CHANNEL" then
		prefix = "[" .. ResolveChannel(channelString, baseName) .. "] %s: "
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
	if ns.S.showLevels and ns.AddLevels then
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

local function MainChat() return DEFAULT_CHAT_FRAME or ChatFrame1 end

local function Place(g)
	local f, d = g.frame, g.data
	f:ClearAllPoints()
	local main = MainChat()
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
-- Tabs
-------------------------------------------------------------------------------
local LayoutTabs, Select, StartDrag -- forward

local function CreateTab(w)
	local t = CreateFrame("Button", nil, UIParent)
	t:SetHeight(HEADER_H)
	t:RegisterForClicks("LeftButtonUp")
	t:RegisterForDrag("LeftButton")
	t.hl = t:CreateTexture(nil, "HIGHLIGHT")
	t.hl:SetAllPoints()
	UI.Paint(t.hl, C.accentDim)
	t.line = UI.Glow(t, "OVERLAY")
	t.line:SetPoint("BOTTOMLEFT", 4, 1)
	t.line:SetPoint("BOTTOMRIGHT", -4, 1)
	t.line:SetHeight(2)
	t.text = UI.Text(t, "GameFontHighlightSmall", C.muted)
	t.text:SetPoint("LEFT", 10, 0)
	t.dot = t:CreateTexture(nil, "OVERLAY")
	t.dot:SetSize(5, 5)
	t.dot:SetPoint("RIGHT", -4, 4)
	UI.Paint(t.dot, C.orange)
	t.dot:Hide()
	t:SetScript("OnClick", function() Select(w.group, w) end)
	t:SetScript("OnDragStart", function() StartDrag(w.group, w) end)
	t:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(WindowName(w))
		GameTooltip:AddLine(L.CW_TAB_TIP, 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return t
end

function LayoutTabs(g)
	local x = 4
	local maxW = math.max(60, (g.frame:GetWidth() or 300) - 90)
	local n = #g.data.order
	for _, id in ipairs(g.data.order) do
		local w = wins[id]
		local t = w.tab
		t:SetParent(g.header)
		t:SetFrameLevel(g.header:GetFrameLevel() + 2)
		t.text:SetText(WindowName(w))
		local width = math.min((t.text:GetStringWidth() or 60) + 22, math.max(60, maxW / n))
		t:SetWidth(width)
		t.text:SetWidth(width - 16)
		t.text:SetWordWrap(false)
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", g.header, "BOTTOMLEFT", x, 0)
		x = x + width + 2
		local active = g.data.active == id
		t.line:SetShown(active)
		UI.Ink(t.text, active and C.text or C.muted)
		t.dot:SetShown(not active and w.unread and true or false)
		t:Show()
	end
end

function Select(g, w)
	g.data.active = w.data.id
	w.unread = false
	for _, id in ipairs(g.data.order) do
		local o = wins[id]
		o.msg:SetShown(o == w)
	end
	LayoutTabs(g)
	if menu and menu:IsShown() and menu.group == g then ns:CW_OpenMenu(g) end
end

-------------------------------------------------------------------------------
-- Group frame (one window or several docked as tabs)
-------------------------------------------------------------------------------
local function HeaderButton(g, tip, onClick)
	local b = CreateFrame("Button", nil, g.header)
	b:SetSize(22, 20)
	b.lines = {}
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	UI.Paint(hl, C.rowHover)
	b.tip = tip
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
	UI.Fill(f, C.chatBg)
	UI.Border(f, C.border)
	g.frame = f

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

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 6, -HEADER_H - 4)
	body:SetPoint("BOTTOMRIGHT", -6, 6)
	g.body = body

	local grip = CreateFrame("Button", nil, f)
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
		if g.data.snap then
			-- snapped windows keep the chat's width: only the height changes
			Save(g); g.data.snap = false; Place(g)
		end
		f:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		Save(g)
		LayoutTabs(g)
	end)
	f:SetScript("OnSizeChanged", function() if g.data then LayoutTabs(g) end end)
	return f
end

local function CreateMessageFrame(w)
	local m = CreateFrame("ScrollingMessageFrame", nil, UIParent)
	m:SetFontObject(UI.MessageFont())
	m:SetJustifyH("LEFT")
	m:SetMaxLines(500)
	m:SetFading(false)
	if m.SetHyperlinksEnabled then m:SetHyperlinksEnabled(true) end
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
		else
			if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
		end
	end)
	m:SetScript("OnHyperlinkClick", function(self, link, text, button)
		if ns.LinkClick(link) then return end
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
	g.frame:Show()
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
		if o ~= g and o.frame:IsShown() and MouseIsOver and MouseIsOver(o.header) then return o end
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
	local target = DropTarget(g)
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
	for _, o in ipairs(groups) do o.dropHl:SetShown(o == target) end
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

local function AddLine(w, text, r, g, b, save)
	w.msg:AddMessage(text, r, g, b)
	w.count = (w.count or 0) + 1
	if save then
		local lines = w.data.lines
		lines[#lines + 1] = { text, r, g, b, time() }
		while #lines > MAX_SAVED_LINES do table.remove(lines, 1) end
	end
	if w.group and w.group.data and w.group.data.active ~= w.data.id then
		if not w.unread then
			w.unread = true
			LayoutTabs(w.group)
		end
	end
end

local function Deliver(event, ...)
	if #groups == 0 then return end
	local cat = EVENT_CAT[event]
	if event == "CHAT_MSG_CHANNEL" then
		local zoneChannelID, channelNumber = select(7, ...)
		if ns.Usable(zoneChannelID, channelNumber) then cat = ChannelCat(zoneChannelID, channelNumber) else cat = "channels" end
	end
	if not cat then return end

	local targets = {}
	for _, w in pairs(wins) do
		if w.data.cats[cat] and w.group then targets[#targets + 1] = w end
	end
	if #targets == 0 then return end

	local msg, author = ...
	if not ns.Usable(msg, author) then
		-- restricted (e.g. boss encounter): show the text as it is, untouched
		local r, g, b = TypeColor(event:sub(10))
		for _, w in ipairs(targets) do pcall(w.msg.AddMessage, w.msg, msg, r, g, b) end
		return
	end

	for _, w in ipairs(targets) do
		local args, n = RunFilters(w.msg, event, ...)
		if args then
			local ok, text, r, g, b = pcall(Format, event, unpack(args, 1, n))
			if ok and text then AddLine(w, text, r, g, b, true) end
		end
	end
end

local evFrame = CreateFrame("Frame")
for ev in pairs(EVENT_CAT) do evFrame:RegisterEvent(ev) end
evFrame:RegisterEvent("CHAT_MSG_CHANNEL")
evFrame:SetScript("OnEvent", function(_, event, ...)
	if not ns.S or not ns.loggedIn then return end
	local ok = pcall(Deliver, event, ...)
	if not ok then return end
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
		end)
		r.toggle:SetPoint("RIGHT", -6, 0)
		menu.rows[c.key] = r
	end
	local hint = UI.Text(menu, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("TOPLEFT", 14, -32 - #CATS * 27 - 6)
	hint:SetWidth(210)
	hint:SetSpacing(2)
	hint:SetText(L.CW_MENU_HINT)
	menu:SetSize(236, 32 + #CATS * 27 + 62)
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
			w.msg:AddMessage(l[1], l[2], l[3], l[4])
			restored = true
		end
	end
	if restored then w.msg:AddMessage(UI.Hex(C.muted) .. "— " .. L.CW_HISTORY .. " —|r") end
	return w
end

-- cats: table of category keys (optional). into: dock into this group.
function ns:CW_New(cats, into)
	if not Data then return end
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

function ns:CW_Delete(w)
	local g = w.group
	if menu and menu:IsShown() then menu:Hide() end
	if g and g.data then RemoveFromGroup(g, w) end
	w.msg:Hide()
	w.tab:Hide()
	wins[w.data.id] = nil
	for i, d in ipairs(Data.windows) do if d == w.data then table.remove(Data.windows, i) break end end
end

function ns:CW_Count() return Data and #Data.windows or 0 end

function ns:CW_ToggleAll()
	if #groups == 0 then return self:CW_New() end
	local show = not groups[1].frame:IsShown()
	for _, g in ipairs(groups) do g.frame:SetShown(show) end
	if Data then Data.hidden = not show end
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
		if Data.hidden then g.frame:Hide() end
	end
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
end

ns._cw = { wins = wins, groups = groups, Format = Format, Deliver = Deliver, FinishDrag = FinishDrag,
	StartDrag = StartDrag, ChannelCat = ChannelCat } -- for tests
