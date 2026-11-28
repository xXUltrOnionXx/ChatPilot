local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Pilot Link: ChatPilot users find each other and share small signals through
-- invisible addon messages (not chat). Only other ChatPilot users receive them.
--   "V:1.10.0"  I use ChatPilot (guild, group, or a one-time reply to a whisper)
--   "T:1"       I am typing a whisper to you
--   "Z:Zone"    my zone (only if you switch it on; guild and group only)
-- Never sent inside instances or while the game restricts chat.
-------------------------------------------------------------------------------
local PREFIX = "ChatPilot"
local peers = {}                       -- key -> { name, v, zone, t }
local lastTyped, lastReply, lastCast = {}, {}, {}
local typingUntil = {}

local function On() return ns.S ~= nil and ns.S.pilotLink ~= false end

local function CanSend()
	if not On() then return false end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
	if IsInInstance and ns.SafeBool((IsInInstance()), true) then return false end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return false end
	return true
end

local function Send(text, channel, target)
	if CanSend() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel, target) end
end

local function Clean(s, max)
	s = tostring(s or ""):gsub("[%c|]", ""):sub(1, max or 40)
	return s
end

local function Seen(sender, version, zone)
	local key = ns.Normalize(sender)
	if not key or key == ns.playerKey then return nil end
	local p = peers[key] or {}
	p.name = Clean(sender, 60)
	p.t = GetTime()
	if version then p.v = version end
	if zone ~= nil then p.zone = zone ~= "" and zone or nil end
	peers[key] = p
	return key, p
end

-- what we know about a player (nil = not seen as a ChatPilot user)
function ns.PilotInfo(name)
	if type(name) ~= "string" then return nil end
	local key = ns.Normalize(name)
	if key and peers[key] then return peers[key] end
	local short = Ambiguate(name, "short"):lower()
	for k, p in pairs(peers) do
		if Ambiguate(k, "short"):lower() == short then return p end
	end
end

function ns.PilotTyping(name)
	if type(name) ~= "string" then return false end
	local key = ns.Normalize(name)
	local short = Ambiguate(name, "short"):lower()
	for k, untilT in pairs(typingUntil) do
		if untilT > GetTime() and (k == key or Ambiguate(k, "short"):lower() == short) then return true end
	end
	return false
end

-- you are typing a whisper to a ChatPilot user: tell their ChatPilot (at most every 4 seconds)
function ns.PilotSendTyping(name)
	if not On() or not ns.PilotInfo(name) then return end
	local key = ns.Normalize(name) or name
	local now = GetTime()
	if lastTyped[key] and now - lastTyped[key] < 4 then return end
	lastTyped[key] = now
	Send("T:1", "WHISPER", name)
end

local function Broadcast(withZone)
	local now = GetTime()
	if lastCast.t and now - lastCast.t < 60 then return end
	lastCast.t = now
	local channels = {}
	if IsInGuild and IsInGuild() then channels[#channels + 1] = "GUILD" end
	if IsInRaid and IsInRaid() then channels[#channels + 1] = "RAID"
	elseif IsInGroup and IsInGroup() then channels[#channels + 1] = "PARTY" end
	local zone = ns.S and ns.S.pilotZone and GetRealZoneText and GetRealZoneText() or nil
	for _, ch in ipairs(channels) do
		Send("V:" .. ns.version, ch)
		if zone and zone ~= "" then Send("Z:" .. Clean(zone), ch) end
	end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_ADDON", "CHAT_MSG_WHISPER" }) do
	ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, a, b, c, d)
	if not ns.S then return end
	if event == "PLAYER_LOGIN" then
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
		C_Timer.After(20, Broadcast)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
		lastCast.t = nil
		C_Timer.After(2, Broadcast)
	elseif event == "CHAT_MSG_WHISPER" then
		-- someone whispers you: they are online, so ask once whether they use ChatPilot too
		if On() and ns.Usable(b) and type(b) == "string" and ns.Usable(a) then
			local key = ns.Normalize(b)
			if key and key ~= ns.playerKey and not peers[key] and (not lastReply["probe" .. key] or GetTime() - lastReply["probe" .. key] > 600) then
				lastReply["probe" .. key] = GetTime()
				Send("V:" .. ns.version, "WHISPER", b)
			end
		end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, msg, channel, sender = a, b, c, d
		if not ns.Usable(prefix, msg, sender) or prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
		if not On() then return end
		local ver = msg:match("^V:([%d%.]+)$")
		if ver then
			local key = Seen(sender, ver:sub(1, 12))
			if key and channel == "WHISPER" and (not lastReply[key] or GetTime() - lastReply[key] > 300) then
				lastReply[key] = GetTime()
				Send("V:" .. ns.version, "WHISPER", sender)
			end
		elseif msg:sub(1, 2) == "T:" then
			local key = Seen(sender)
			if key and channel == "WHISPER" then
				typingUntil[key] = GetTime() + 5
				if ns.CW_RefreshStatus then ns.CW_RefreshStatus() end
				C_Timer.After(5.2, function() if ns.CW_RefreshStatus then ns.CW_RefreshStatus() end end)
			end
		elseif msg:sub(1, 2) == "Z:" and (channel == "GUILD" or channel == "PARTY" or channel == "RAID") then
			Seen(sender, nil, Clean(msg:sub(3)))
		end
	end
end)

-------------------------------------------------------------------------------
-- "ChatPilot users around you"
-------------------------------------------------------------------------------
local win
local function Ago(t)
	local s = math.max(0, GetTime() - t)
	if s < 90 then return L.PL_AGO_NOW end
	return L.PL_AGO:format(math.floor(s / 60))
end

local function Fill()
	local list = {}
	for key, p in pairs(peers) do list[#list + 1] = { key = key, p = p } end
	table.sort(list, function(x, y) return (x.p.t or 0) > (y.p.t or 0) end)
	win.msg:Clear()
	for _, e in ipairs(list) do
		local p = e.p
		local name = p.name or e.key
		local line = ("|Hplayer:%s|h[%s]|h"):format(name, Ambiguate(name, "none"))
			.. "  " .. UI.Hex(C.muted) .. "ChatPilot " .. (p.v or "?")
			.. (p.zone and (" · " .. p.zone) or "") .. " · " .. Ago(p.t or 0) .. "|r"
		win.msg:AddMessage(line, 0.86, 0.89, 0.93)
	end
	win.status:SetText(#list == 0 and L.PL_EMPTY or L.PL_COUNT:format(#list))
	win.msg:ScrollToTop()
end

function ns:ShowPilots()
	if not win then
		win = UI.Window("ChatPilotPilots", L.PL_TITLE, 560, 420)
		local box = CreateFrame("Frame", nil, win.content)
		box:SetPoint("TOPLEFT", 14, -12)
		box:SetPoint("BOTTOMRIGHT", -14, 52)
		UI.Fill(box, C.panel)
		UI.Border(box)
		local m = CreateFrame("ScrollingMessageFrame", nil, box)
		m:SetPoint("TOPLEFT", 10, -8)
		m:SetPoint("BOTTOMRIGHT", -10, 8)
		m:SetMaxLines(500)
		m:SetFading(false)
		m:SetJustifyH("LEFT")
		m:SetFontObject(UI.MessageFont())
		m:SetHyperlinksEnabled(true)
		m:EnableMouseWheel(true)
		m:SetScript("OnMouseWheel", function(self, delta)
			for _ = 1, 3 do if delta > 0 then self:ScrollUp() else self:ScrollDown() end end
		end)
		m:SetScript("OnHyperlinkClick", function(_, link, text, button)
			if SetItemRef then pcall(SetItemRef, link, text, button, DEFAULT_CHAT_FRAME) end
		end)
		win.msg = m
		win.status = UI.Text(win.content, "GameFontHighlight", C.accent)
		win.status:SetPoint("BOTTOMLEFT", 16, 24)
		local close = UI.Button(win.content, CLOSE or "Close", 100, 28)
		close:SetPoint("BOTTOMRIGHT", -14, 12)
		close:SetScript("OnClick", function() win:Hide() end)
	end
	win:Show()
	win:Raise()
	Fill()
end
