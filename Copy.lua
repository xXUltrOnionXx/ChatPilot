local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Read-only copy window (links and chat text)
-------------------------------------------------------------------------------
local copy

local function CreateCopy()
	local f = UI.Window("ChatPilotCopy", L.COPY_TITLE, 600, 380)
	local box = CreateFrame("Frame", nil, f.content)
	box:SetPoint("TOPLEFT", 14, -14)
	box:SetPoint("BOTTOMRIGHT", -14, 52)
	UI.Fill(box, C.panel)
	UI.Border(box)

	local scroll = UI.ScrollArea(box)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)

	local eb = CreateFrame("EditBox", nil, scroll.child)
	eb:SetPoint("TOPLEFT")
	eb:SetPoint("RIGHT", scroll.child, "RIGHT")
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal)
	eb:SetScript("OnEscapePressed", function() f:Hide() end)
	-- read-only: typing restores the original text
	eb:SetScript("OnTextChanged", function(self, userInput)
		if userInput and f.content_text then
			self:SetText(f.content_text)
			self:HighlightText()
		end
		scroll.child:SetHeight(math.max(self:GetHeight(), 10))
	end)
	eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
		y = -y
		if y < top then scroll:SetVerticalScroll(y)
		elseif y + h > top + height then scroll:SetVerticalScroll(math.min(y + h - height, scroll:GetVerticalScrollRange())) end
	end)
	scroll:SetScript("OnSizeChanged", function(_, width)
		scroll.child:SetWidth(width)
		eb:SetWidth(width)
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() eb:SetFocus() end)

	f.hint = UI.Text(f.content, "GameFontHighlightSmall", C.muted)
	f.hint:SetPoint("BOTTOMLEFT", 16, 20)
	local done = UI.Button(f.content, CLOSE or "Close", 110, 28)
	done:SetPoint("BOTTOMRIGHT", -14, 12)
	done:SetScript("OnClick", function() f:Hide() end)

	f.eb, f.scroll, f.box = eb, scroll, box
	return f
end

function ns:ShowCopy(text, title, small)
	copy = copy or CreateCopy()
	copy.title:SetText(title or L.COPY_TITLE)
	copy:SetHeight(small and 170 or 420)
	copy.hint:SetText(small and L.COPY_HINT_SMALL or L.COPY_HINT)
	copy.content_text = text
	copy.eb:SetText(text)
	copy:Show()
	copy:Raise()
	copy.eb:SetFocus()
	copy.eb:HighlightText()
	C_Timer.After(0, function()
		copy.scroll.child:SetHeight(math.max(copy.eb:GetHeight(), 10))
		copy.scroll:SetVerticalScroll(small and 0 or copy.scroll:GetVerticalScrollRange())
	end)
end

function ns:CopyChat(frame)
	frame = frame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	if not frame or not frame.GetNumMessages then return end
	local n = frame:GetNumMessages()
	local lines = {}
	for i = math.max(1, n - 300), n do
		local text = frame:GetMessageInfo(i)
		if type(text) == "string" and not ns.IsSecret(text) then
			lines[#lines + 1] = ns.StripEscapes(text)
		end
	end
	self:ShowCopy(table.concat(lines, "\n"), L.COPY_CHAT_TITLE)
end

-------------------------------------------------------------------------------
-- Button bar on every chat window: [@ mentions] [copy] [settings]
-------------------------------------------------------------------------------
local bars = {}
local IDLE_ALPHA = 0.35

local function GearIcon(tex)
	if C_Texture and C_Texture.GetAtlasInfo then
		for _, atlas in ipairs({ "QuestLog-icon-setting", "GM-icon-settings", "Options_GearIcon" }) do
			if C_Texture.GetAtlasInfo(atlas) then
				tex:SetAtlas(atlas)
				return
			end
		end
	end
	tex:SetTexture("Interface\\WorldMap\\Gear_64Grey")
end

local function BarButton(bar, tip, onClick)
	local b = CreateFrame("Button", nil, bar)
	b:SetSize(20, 20)
	b.bg = UI.Fill(b, { 0.05, 0.06, 0.09, 0.75 })
	b:SetAlpha(IDLE_ALPHA)
	b:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		self.bg:SetColorTexture(unpack(C.rowHover))
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(0.05, 0.06, 0.09, 0.75)
		self:SetAlpha(self.keepVisible and 1 or IDLE_ALPHA)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	return b
end

function ns:UpdateChatButtons()
	local unread = self.unread or 0
	for _, bar in ipairs(bars) do
		bar:SetShown(self.S.copyButton)
		local m = bar.mentions
		m.keepVisible = unread > 0
		m:SetAlpha(unread > 0 and 1 or IDLE_ALPHA)
		m.badge:SetShown(unread > 0)
		m.badge.text:SetText(unread > 9 and "9+" or tostring(unread))
	end
end

ns.OnChatFrame(function(frame)
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetSize(66, 20)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	bar:SetFrameLevel(frame:GetFrameLevel() + 5)

	local gear = BarButton(bar, L.BTN_SETTINGS, function() ns:ToggleOptions() end)
	gear:SetPoint("RIGHT")
	gear.icon = gear:CreateTexture(nil, "ARTWORK")
	gear.icon:SetSize(14, 14)
	gear.icon:SetPoint("CENTER")
	GearIcon(gear.icon)

	local copyBtn = BarButton(bar, L.COPY_BUTTON_TIP, function() ns:CopyChat(frame) end)
	copyBtn:SetPoint("RIGHT", gear, "LEFT", -3, 0)
	copyBtn.icon = copyBtn:CreateTexture(nil, "ARTWORK")
	copyBtn.icon:SetSize(14, 14)
	copyBtn.icon:SetPoint("CENTER")
	copyBtn.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")

	local m = BarButton(bar, L.BTN_MENTIONS, function() ns:ShowMentions() end)
	m:SetPoint("RIGHT", copyBtn, "LEFT", -3, 0)
	m.icon = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	m.icon:SetPoint("CENTER", 0, 1)
	m.icon:SetText("@")
	m.icon:SetTextColor(unpack(C.accent))
	m.badge = CreateFrame("Frame", nil, m)
	m.badge:SetSize(14, 12)
	m.badge:SetPoint("TOPRIGHT", 5, 4)
	UI.Fill(m.badge, C.orange, "OVERLAY")
	m.badge.text = m.badge:CreateFontString(nil, "OVERLAY", _G.SystemFont_Tiny and "SystemFont_Tiny" or "GameFontHighlightSmall")
	m.badge.text:SetPoint("CENTER", 0, 0)
	m.badge.text:SetTextColor(unpack(C.dark))
	m.badge:Hide()
	bar.mentions = m

	bars[#bars + 1] = bar
	if ns.S then ns:UpdateChatButtons() end
end)
