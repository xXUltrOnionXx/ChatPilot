local _, ns = ...
local L = ns.L
local UI, C = ns.UI, ns.UI.C

-- Missed whispers: every incoming whisper you haven't answered yet counts as
-- unread. Answering (or opening the list) marks it as read. ChatPilot never
-- answers for you: "Reply" only opens your input box with the right target.

local MAX_CONV, MAX_MSG = 30, 25
local session = { count = 0, names = {}, secret = 0 }   -- missed while AFK / in combat
local win

local function Store() return ns.db.whispers end

local function IsAway()
	return (UnitIsAFK and UnitIsAFK("player")) or (InCombatLockdown and InCombatLockdown())
end

function ns:WhisperUnread()
	local n = 0
	for _, c in pairs(Store()) do n = n + (c.unread or 0) end
	return n + (self.whisperSecret or 0)
end

local function Prune()
	local list = {}
	for key, c in pairs(Store()) do list[#list + 1] = { key, c.last or 0 } end
	if #list <= MAX_CONV then return end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	for i = MAX_CONV + 1, #list do Store()[list[i][1]] = nil end
end

local function Conversation(key, display, bn)
	local c = Store()[key]
	if not c then
		c = { name = display, bn = bn, msgs = {}, unread = 0, last = time() }
		Store()[key] = c
		Prune()
	end
	c.name = display or c.name
	return c
end

local function AddMsg(c, text, outgoing)
	table.insert(c.msgs, { t = time(), m = text, o = outgoing or nil })
	while #c.msgs > MAX_MSG do table.remove(c.msgs, 1) end
	c.last = time()
end

local function Changed()
	if ns.UpdateChatButtons then ns:UpdateChatButtons() end
	if win and win:IsShown() then ns:RefreshWhispers() end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:RegisterEvent("CHAT_MSG_BN_WHISPER")
ev:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
ev:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")

local function SummaryToast()
	if not ns.S.whisperSummary then return end
	if session.count == 0 and session.secret == 0 then return end
	local names = table.concat(session.names, ", ")
	local text = names
	if session.secret > 0 then
		text = (names ~= "" and (names .. "  ") or "") .. L.WH_SECRET:format(session.secret)
	end
	ns:ShowToast(L.WH_SUMMARY:format(session.count + session.secret), text,
		function() ns:ShowWhispers() end, C.accent)
	session.count, session.secret = 0, 0
	wipe(session.names)
end

ev:SetScript("OnEvent", function(_, event, ...)
	if not ns.S then return end
	if event == "PLAYER_LOGIN" then
		local n = ns:WhisperUnread()
		if n > 0 and ns.S.whispers then ns.Print(L.WH_LOGIN, n) end
		return
	elseif event == "PLAYER_FLAGS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		if not IsAway() then SummaryToast() end
		return
	end
	if not ns.S.whispers then return end

	local msg, author = ...
	local incoming = (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER")
	local bn = (event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM")

	-- In restricted situations (e.g. boss fights) the game may hide whisper text.
	-- We can't read it then, so we only count it and point to the chat.
	if not ns.Usable(msg, author) or type(author) ~= "string" then
		if incoming then
			ns.whisperSecret = (ns.whisperSecret or 0) + 1
			session.secret = session.secret + 1
			Changed()
		end
		return
	end

	local key, display
	if bn then
		local bnID = select(13, ...)
		key = "bn:" .. tostring(bnID or author)
		display = author -- protected Battle.net name, shown as-is
	else
		key = ns.Normalize(author)
		display = Ambiguate(author, "short")
	end
	if not key then return end
	local c = Conversation(key, display, bn)
	if not bn then
		c.target = key
		local guid = select(12, ...)
		if incoming and type(guid) == "string" and ns.Usable(guid) then
			local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
			if ok and classFile then c.c = classFile end
		end
	end
	AddMsg(c, ns.StripEscapes(msg), not incoming)

	if incoming then
		c.unread = (c.unread or 0) + 1
		if IsAway() then
			session.count = session.count + 1
			local seen = false
			for _, n in ipairs(session.names) do if n == display then seen = true end end
			if not seen and #session.names < 4 and not bn then table.insert(session.names, display) end
		end
	else
		c.unread = 0 -- you answered: read
	end
	Changed()
end)

-------------------------------------------------------------------------------
-- Reply (opens your input box; you send it yourself)
-------------------------------------------------------------------------------
local function Reply(c)
	if not c then return end
	if c.bn then
		local f = ChatFrame_SendBNetTell or (ChatFrameUtil and ChatFrameUtil.SendBNetTell)
		if f and pcall(f, c.name) then return end
	else
		local f = ChatFrame_SendTell or (ChatFrameUtil and ChatFrameUtil.SendTell)
		if f and pcall(f, c.target or c.name) then return end
		local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
		if open then pcall(open, "/w " .. (c.target or c.name) .. " ") end
	end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local rows, selected = {}, nil

local function Sorted()
	local list = {}
	for key, c in pairs(Store()) do list[#list + 1] = { key = key, c = c } end
	table.sort(list, function(a, b)
		local ua, ub = (a.c.unread or 0) > 0, (b.c.unread or 0) > 0
		if ua ~= ub then return ua end
		return (a.c.last or 0) > (b.c.last or 0)
	end)
	return list
end

local function NameText(c)
	if c.bn then return "|cff82c5ff" .. (c.name or "?") .. "|r" end
	return ns.ClassColorText(c.name or "?", c.c)
end

local function ShowConversation(key)
	selected = key
	local c = Store()[key]
	local smf = win.smf
	smf:Clear()
	win.reply:SetShown(c ~= nil)
	win.del:SetShown(c ~= nil)
	win.popout:SetShown(c ~= nil)
	win.convName:SetText(c and NameText(c) or "")
	if not c then return end
	if (c.unread or 0) > 0 then
		c.unread = 0
		Changed()
	end
	for _, m in ipairs(c.msgs) do
		local who = m.o and ("|cff8a94a6" .. L.WH_YOU .. "|r") or NameText(c)
		smf:AddMessage(("|cff6b7383%s|r  %s: %s"):format(date("%H:%M", m.t), who, m.m or ""))
	end
	smf:ScrollToBottom()
end

local function Row(i)
	if rows[i] then return rows[i] end
	local list = win.list
	local r = CreateFrame("Button", nil, list.child)
	r:SetHeight(48)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * 50)
	r:SetPoint("RIGHT", list.child, "RIGHT")
	r.bg = UI.Fill(r, C.row)
	r.bar = r:CreateTexture(nil, "ARTWORK")
	r.bar:SetColorTexture(unpack(C.accent))
	r.bar:SetPoint("TOPLEFT")
	r.bar:SetPoint("BOTTOMLEFT")
	r.bar:SetWidth(3)
	r.name = UI.Text(r, "GameFontHighlight")
	r.name:SetPoint("TOPLEFT", 12, -8)
	r.name:SetPoint("RIGHT", r, "RIGHT", -46, 0)
	r.name:SetWordWrap(false)
	r.prev = UI.Text(r, "GameFontHighlightSmall", C.muted)
	r.prev:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
	r.prev:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.prev:SetWordWrap(false)
	r.time = UI.Text(r, "GameFontHighlightSmall", C.muted)
	r.time:SetPoint("TOPRIGHT", -10, -9)
	r.badge = CreateFrame("Frame", nil, r)
	r.badge:SetSize(18, 14)
	r.badge:SetPoint("TOPRIGHT", -10, -26)
	UI.Fill(r.badge, C.orange, "ARTWORK")
	r.badge.text = ns.UI.NoShadow(r.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	r.badge.text:SetPoint("CENTER")
	r.badge.text:SetTextColor(unpack(C.dark))
	r:SetScript("OnEnter", function(self) if self.key ~= selected then self.bg:SetColorTexture(unpack(C.rowHover)) end end)
	r:SetScript("OnLeave", function(self) if self.key ~= selected then self.bg:SetColorTexture(unpack(C.row)) end end)
	r:SetScript("OnClick", function(self) ShowConversation(self.key); ns:RefreshWhispers() end)
	r:SetScript("OnDoubleClick", function(self) Reply(Store()[self.key]) end)
	-- drag a conversation out of the list: it becomes its own chat window
	r:RegisterForDrag("LeftButton")
	r:SetScript("OnDragStart", function(self)
		local c = Store()[self.key]
		if c and ns.CW_OpenConversation then
			local conv = { key = self.key, name = c.name, target = c.target, bn = c.bn, c = c.c, msgs = c.msgs }
			ns:CW_OpenConversation(conv, true)
			c.unread = 0
			Changed()
		end
	end)
	rows[i] = r
	return r
end

function ns:RefreshWhispers()
	if not win then return end
	local list = Sorted()
	if selected and not Store()[selected] then selected = nil end
	for i, item in ipairs(list) do
		local r, c = Row(i), item.c
		r.key = item.key
		local sel = item.key == selected
		r.bg:SetColorTexture(unpack(sel and C.rowHover or C.row))
		r.bar:SetShown(sel)
		r.name:SetText(NameText(c))
		local lastMsg = c.msgs[#c.msgs]
		r.prev:SetText(lastMsg and ((lastMsg.o and (L.WH_YOU .. ": ") or "") .. (lastMsg.m or "")) or "")
		r.time:SetText(date("%H:%M", c.last or 0))
		local u = c.unread or 0
		r.badge:SetShown(u > 0)
		r.badge.text:SetText(u > 9 and "9+" or tostring(u))
		r:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	win.list.child:SetHeight(math.max(#list * 50, 10))
	win.empty:SetShown(#list == 0)
	local secret = self.whisperSecret or 0
	win.secret:SetShown(secret > 0)
	win.secret:SetText(L.WH_SECRET_HINT:format(secret))
	if not selected and list[1] then ShowConversation(list[1].key); return self:RefreshWhispers() end
	if not selected then ShowConversation(nil) end
end

local function Build()
	win = UI.Window("ChatPilotWhispers", L.WH_TITLE, 720, 460)
	local c = win.content

	local left = CreateFrame("Frame", nil, c)
	left:SetPoint("TOPLEFT", 14, -14)
	left:SetPoint("BOTTOMLEFT", 14, 52)
	left:SetWidth(240)
	win.list = UI.ScrollArea(left)
	win.list:SetAllPoints()
	win.empty = UI.Text(c, "GameFontHighlight", C.muted)
	win.empty:SetPoint("CENTER")
	win.empty:SetText(L.WH_EMPTY)

	local right = CreateFrame("Frame", nil, c)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
	right:SetPoint("BOTTOMRIGHT", -14, 52)
	UI.Fill(right, C.panel)
	UI.Border(right)
	-- name on its own line (full width, never covered), the buttons in a row below it
	win.convName = UI.Text(right, "GameFontHighlightLarge")
	win.convName:SetPoint("TOPLEFT", 14, -12)
	win.convName:SetPoint("RIGHT", right, "RIGHT", -14, 0)
	win.convName:SetJustifyH("LEFT")
	win.convName:SetWordWrap(false)
	win.reply = UI.Button(right, L.WH_REPLY, 110, 26, "accent")
	win.reply:SetPoint("TOPRIGHT", -10, -40)
	win.reply:SetScript("OnClick", function() Reply(Store()[selected]); win:Hide() end)
	win.del = UI.Button(right, L.WH_DELETE, 90, 26)
	win.del:SetPoint("RIGHT", win.reply, "LEFT", -6, 0)
	-- open this conversation as its own chat window
	win.popout = UI.Button(right, L.WH_POPOUT, 130, 26)
	win.popout:SetPoint("RIGHT", win.del, "LEFT", -6, 0)
	win.popout:SetScript("OnClick", function()
		local c = selected and Store()[selected]
		if c and ns.CW_OpenConversation then
			ns:CW_OpenConversation({ key = selected, name = c.name, target = c.target, bn = c.bn, c = c.c, msgs = c.msgs })
			c.unread = 0
			Changed()
			win:Hide()
		end
	end)
	win.popout:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.WH_POPOUT)
		GameTooltip:AddLine(L.WH_POPOUT_TIP, 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	win.popout:HookScript("OnLeave", function() GameTooltip:Hide() end)
	win.del:SetScript("OnClick", function()
		if selected then Store()[selected] = nil; selected = nil; Changed(); ns:RefreshWhispers() end
	end)
	local line = right:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(unpack(C.border))
	line:SetPoint("TOPLEFT", 1, -72)
	line:SetPoint("TOPRIGHT", -1, -72)
	line:SetHeight(1)

	local smf = CreateFrame("ScrollingMessageFrame", nil, right)
	smf:SetPoint("TOPLEFT", 14, -78)
	smf:SetPoint("BOTTOMRIGHT", -14, 10)
	smf:SetFontObject(UI.MessageFont())
	smf:SetJustifyH("LEFT")
	smf:SetFading(false)
	smf:SetSpacing(4)
	smf:SetMaxLines(MAX_MSG + 5)
	smf:EnableMouseWheel(true)
	smf:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
	win.smf = smf

	win.secret = UI.Text(c, "GameFontHighlightSmall", C.orange)
	win.secret:SetPoint("BOTTOMLEFT", 16, 20)
	local clear = UI.Button(c, L.WH_CLEAR_ALL, 120, 28)
	clear:SetPoint("BOTTOMRIGHT", -14, 12)
	clear:SetScript("OnClick", function()
		wipe(Store()); selected = nil; ns.whisperSecret = 0; Changed(); ns:RefreshWhispers()
	end)
	local readAll = UI.Button(c, L.WH_READ_ALL, 150, 28)
	readAll:SetPoint("RIGHT", clear, "LEFT", -8, 0)
	readAll:SetScript("OnClick", function()
		for _, conv in pairs(Store()) do conv.unread = 0 end
		ns.whisperSecret = 0
		Changed()
	end)
	local opts = UI.Button(c, L.BTN_SETTINGS, 130, 28)
	opts:SetPoint("RIGHT", readAll, "LEFT", -8, 0)
	opts:SetScript("OnClick", function() ns:OpenOptions(3) end)
end

function ns:WhisperCount()
	local n = 0
	for _ in pairs(Store()) do n = n + 1 end
	return n
end

-- empty the whole whisper log (Options > Good to know)
function ns:ClearWhisperLog()
	wipe(Store()); selected = nil; ns.whisperSecret = 0; Changed()
end

function ns:ShowWhispers()
	if not win then Build() end
	selected = nil
	self.whisperSecret = 0
	win:Show()
	win:Raise()
	self:RefreshWhispers()
	Changed()
end

function ns:ToggleWhispers()
	if win and win:IsShown() then win:Hide() else self:ShowWhispers() end
end
