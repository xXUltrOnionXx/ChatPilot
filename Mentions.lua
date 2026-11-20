local _, ns = ...
local L = ns.L

local MAX_LOG = 200
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
local UI, C = ns.UI, ns.UI.C
local toast = CreateFrame("Button", "ChatPilotToast", UIParent)
toast:SetSize(440, 58)
toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
toast:SetFrameStrata("HIGH")
UI.Fill(toast, C.bg)
UI.Border(toast)
local stripe = toast:CreateTexture(nil, "ARTWORK")
stripe:SetColorTexture(unpack(C.orange))
stripe:SetPoint("TOPLEFT", 1, -1)
stripe:SetPoint("BOTTOMLEFT", 1, 1)
stripe:SetWidth(3)
local tb = UI.Badge(toast, 30)
tb:SetPoint("LEFT", 14, 0)
toast:Hide()

toast.title = UI.Text(toast, "GameFontHighlight")
toast.title:SetPoint("TOPLEFT", tb, "TOPRIGHT", 12, 2)
toast.title:SetPoint("RIGHT", toast, "RIGHT", -12, 0)
toast.text = UI.Text(toast, "GameFontHighlightSmall", C.muted)
toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -5)
toast.text:SetPoint("RIGHT", toast, "RIGHT", -12, 0)
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
	if toast.onClick then toast.onClick() end
end)
toast:SetScript("OnEnter", function() fade:Stop(); toast:SetAlpha(1) end)
toast:SetScript("OnLeave", function() fade:Play() end)

-- Generic toast: title, text, click handler, stripe colour.
function ns:ShowToast(title, text, onClick, color)
	stripe:SetColorTexture(unpack(color or C.orange))
	toast.onClick = onClick
	toast.title:SetText(title)
	toast.text:SetText(text or "")
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
	if S.mentionToast then
		self:ShowToast(L.MENTION_TOAST:format(who, label), plain, function() ns:ShowMentions() end)
	end
	if self.mentionsFrame and self.mentionsFrame:IsShown() then
		self:FillMentions()
	else
		self.unread = (self.unread or 0) + 1
	end
	if self.UpdateChatButtons then self:UpdateChatButtons() end
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
function ns:FillMentions()
	local f = self.mentionsFrame
	local smf = f.smf
	smf:Clear()
	local log = self.db.mentions
	f.empty:SetShown(#log == 0)
	f.count:SetText(L.MENTIONS_COUNT:format(#log))
	for _, e in ipairs(log) do
		smf:AddMessage(("|cff6b7383%s|r  |cff4ec9ff%s|r  %s: %s"):format(
			date("%d.%m. %H:%M", e.t), e.ch or "?", ns.ClassColorText(e.a or "?", e.c), e.m or ""))
	end
	smf:ScrollToBottom()
end

function ns:ShowMentions()
	if not self.mentionsFrame then
		local f = UI.Window("ChatPilotMentions", L.MENTIONS_TITLE, 620, 380)
		local box = CreateFrame("Frame", nil, f.content)
		box:SetPoint("TOPLEFT", 14, -14)
		box:SetPoint("BOTTOMRIGHT", -14, 52)
		UI.Fill(box, C.panel)
		UI.Border(box)
		local smf = CreateFrame("ScrollingMessageFrame", nil, box)
		smf:SetPoint("TOPLEFT", 12, -10)
		smf:SetPoint("BOTTOMRIGHT", -12, 10)
		smf:SetFontObject(UI.MessageFont())
		smf:SetJustifyH("LEFT")
		smf:SetFading(false)
		smf:SetSpacing(4)
		smf:SetMaxLines(MAX_LOG + 5)
		smf:EnableMouseWheel(true)
		smf:SetScript("OnMouseWheel", function(self, delta)
			if delta > 0 then self:ScrollUp() else self:ScrollDown() end
		end)
		f.smf = smf
		f.empty = UI.Text(box, "GameFontHighlight", C.muted)
		f.empty:SetPoint("CENTER")
		f.empty:SetText(L.MENTIONS_EMPTY)

		f.count = UI.Text(f.content, "GameFontHighlightSmall", C.muted)
		f.count:SetPoint("BOTTOMLEFT", 16, 20)
		local clear = UI.Button(f.content, L.CLEAR, 110, 28)
		clear:SetPoint("BOTTOMRIGHT", -14, 12)
		clear:SetScript("OnClick", function()
			wipe(ns.db.mentions)
			ns:FillMentions()
		end)
		local opts = UI.Button(f.content, L.BTN_SETTINGS, 130, 28)
		opts:SetPoint("RIGHT", clear, "LEFT", -8, 0)
		opts:SetScript("OnClick", function() ns:OpenOptions(2) end)
		self.mentionsFrame = f
	end
	self.unread = 0
	if self.UpdateChatButtons then self:UpdateChatButtons() end
	self:FillMentions()
	self.mentionsFrame:Show()
	self.mentionsFrame:Raise()
end

function ns:TestAlert()
	local name = self.playerName or UnitName("player")
	self:Alert("CHAT_MSG_GUILD", L.TEST_MESSAGE:format(name), name, nil, UnitGUID("player"))
end
