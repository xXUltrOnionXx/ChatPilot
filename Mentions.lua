local _, ns = ...
local L = ns.L

local MAX_LOG = 100
local lastSound = 0

local function ChannelLabel(event, channelName)
	if event == "CHAT_MSG_CHANNEL" and type(channelName) == "string" and channelName ~= "" then
		return channelName
	end
	if event == "CHAT_MSG_COMMUNITIES_CHANNEL" then
		return (type(channelName) == "string" and channelName ~= "" and channelName) or L.SRC_COMMUNITY
	end
	local label = _G[event]
	if type(label) == "string" then return label end
	return (event:gsub("^CHAT_MSG_", ""))
end

-------------------------------------------------------------------------------
-- Toast
-------------------------------------------------------------------------------
local toast = CreateFrame("Button", "ChatPilotToast", UIParent, "BackdropTemplate")
toast:SetSize(420, 52)
toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
toast:SetFrameStrata("HIGH")
toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
toast:SetBackdropColor(0.04, 0.05, 0.08, 0.9)
toast:SetBackdropBorderColor(1, 0.6, 0.12, 0.9)
toast:Hide()

toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
toast.title:SetPoint("TOPLEFT", 10, -8)
toast.title:SetPoint("TOPRIGHT", -10, -8)
toast.title:SetJustifyH("LEFT")
toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
toast.text:SetPoint("TOPRIGHT", toast.title, "BOTTOMRIGHT", 0, -4)
toast.text:SetJustifyH("LEFT")
toast.text:SetWordWrap(false)

local fade = toast:CreateAnimationGroup()
local alpha = fade:CreateAnimation("Alpha")
alpha:SetFromAlpha(1)
alpha:SetToAlpha(0)
alpha:SetDuration(1)
alpha:SetStartDelay(5)
fade:SetScript("OnFinished", function() toast:Hide() end)

toast:SetScript("OnClick", function()
	toast:Hide()
	ns:ShowMentions()
end)
toast:SetScript("OnEnter", function() fade:Stop(); toast:SetAlpha(1) end)
toast:SetScript("OnLeave", function() fade:Play() end)

local function ShowToast(author, label, msg)
	toast.title:SetText(L.MENTION_TOAST:format(author, label))
	toast.text:SetText(msg)
	fade:Stop()
	toast:SetAlpha(1)
	toast:Show()
	fade:Play()
end

-------------------------------------------------------------------------------
-- Detection
-------------------------------------------------------------------------------
function ns:Alert(event, msg, author, channelName, guid)
	local S = self.S
	local plain = ns.StripEscapes(msg)
	local label = ChannelLabel(event, channelName)
	local short = Ambiguate(author, "short")
	local classFile
	if type(guid) == "string" and ns.Usable(guid) then
		local ok, _, cf = pcall(GetPlayerInfoByGUID, guid)
		if ok then classFile = cf end
	end
	local who = ns.ClassColorText(short, classFile)

	local log = self.db.mentions
	table.insert(log, { t = time(), a = short, c = classFile, ch = label, m = plain })
	while #log > MAX_LOG do table.remove(log, 1) end

	if S.mentionSound and GetTime() - lastSound > 2 then
		lastSound = GetTime()
		PlaySound((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master")
	end
	if S.mentionFlash and FlashClientIcon then FlashClientIcon() end
	if S.mentionToast then ShowToast(who, label, plain) end
	if self.mentionsFrame and self.mentionsFrame:IsShown() then self:FillMentions() end
end

ns:OnChat(function(event, msg, author, channelName, guid)
	local S = ns.S
	if not S.mentions or event == "CHAT_MSG_WHISPER" then return end -- whispers already alert you
	if not S.mentionPublic and ns.PUBLIC_EVENTS[event] then return end
	if type(author) ~= "string" or ns.Normalize(author) == ns.playerKey then return end
	-- only look at plain text, never inside item/quest links
	local plain = {}
	for _, part in ipairs(ns.SplitMessage(msg)) do
		if part[1] then plain[#plain + 1] = part[2] end
	end
	if ns:FindMention(table.concat(plain, " ")) then
		ns:Alert(event, msg, author, channelName, guid)
	end
end)

-------------------------------------------------------------------------------
-- Mentions log window
-------------------------------------------------------------------------------
local function CreateWindow(name, title, w, h)
	local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	f:SetSize(w, h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(0.04, 0.05, 0.08, 0.95)
	f:SetBackdropBorderColor(0.31, 0.79, 1, 0.6)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 12, -10)
	f.title:SetText(title)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	f:Hide()
	tinsert(UISpecialFrames, name) -- Escape closes it
	return f
end
ns.CreateWindow = CreateWindow

function ns:FillMentions()
	local smf = self.mentionsFrame.smf
	smf:Clear()
	local log = self.db.mentions
	if #log == 0 then
		smf:AddMessage(L.MENTIONS_EMPTY, 0.6, 0.6, 0.6)
		return
	end
	for _, e in ipairs(log) do
		smf:AddMessage(("|cff777777%s|r |cffaaaaaa[%s]|r %s: %s"):format(
			date("%d.%m. %H:%M", e.t), e.ch or "?", ns.ClassColorText(e.a or "?", e.c), e.m or ""))
	end
	smf:ScrollToBottom()
end

function ns:ShowMentions()
	if not self.mentionsFrame then
		local f = CreateWindow("ChatPilotMentions", L.MENTIONS_TITLE, 560, 300)
		local smf = CreateFrame("ScrollingMessageFrame", nil, f)
		smf:SetPoint("TOPLEFT", 12, -34)
		smf:SetPoint("BOTTOMRIGHT", -12, 40)
		smf:SetFontObject(ChatFontNormal)
		smf:SetJustifyH("LEFT")
		smf:SetFading(false)
		smf:SetMaxLines(MAX_LOG + 5)
		smf:EnableMouseWheel(true)
		smf:SetScript("OnMouseWheel", function(self, delta)
			if delta > 0 then self:ScrollUp() else self:ScrollDown() end
		end)
		f.smf = smf
		local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		clear:SetSize(100, 22)
		clear:SetPoint("BOTTOMRIGHT", -12, 10)
		clear:SetText(L.CLEAR)
		clear:SetScript("OnClick", function()
			wipe(ns.db.mentions)
			ns:FillMentions()
		end)
		self.mentionsFrame = f
	end
	self:FillMentions()
	self.mentionsFrame:Show()
end

function ns:TestAlert()
	local name = self.playerName or UnitName("player")
	self:Alert("CHAT_MSG_GUILD", L.TEST_MESSAGE:format(name), name, nil, UnitGUID("player"))
end
