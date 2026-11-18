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
	-- search (chat mode only)
	f.search = UI.Input(f.content, 300, L.SEARCH_PLACEHOLDER)
	f.search:SetPoint("TOPLEFT", 14, -12)
	f.search:SetPoint("RIGHT", f.content, "RIGHT", -14, 0)
	f.searchCount = UI.Text(f.search, "GameFontHighlightSmall", C.muted)
	f.searchCount:SetPoint("RIGHT", -10, 0)

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
	eb:SetFontObject(UI.MessageFont())
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

	local function ApplySearch()
		if not f.lines then return end
		local q = strtrim(f.search.eb:GetText() or ""):lower()
		local out = {}
		for _, line in ipairs(f.lines) do
			if q == "" or line:lower():find(q, 1, true) then out[#out + 1] = line end
		end
		f.content_text = table.concat(out, "\n")
		eb:SetText(f.content_text)
		f.searchCount:SetText(q ~= "" and ("%d / %d"):format(#out, #f.lines) or "")
		C_Timer.After(0, function() scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end)
	end
	f.search.eb:HookScript("OnTextChanged", ApplySearch)
	f.search.eb:SetScript("OnEnterPressed", function() eb:SetFocus(); eb:HighlightText() end)
	return f
end

function ns:ShowCopy(text, title, small, lines)
	copy = copy or CreateCopy()
	copy.lines = lines
	copy.search:SetShown(lines ~= nil)
	copy.box:SetPoint("TOPLEFT", 14, lines and -48 or -14)
	if lines then copy.search.eb:SetText("") end
	copy.title:SetText(title or L.COPY_TITLE)
	copy:SetHeight(small and 170 or 420)
	copy.hint:SetText(small and L.COPY_HINT_SMALL or L.COPY_HINT)
	copy.content_text = text
	copy.eb:SetText(text)
	copy:Show()
	copy:Raise()
	if not lines then
		copy.eb:SetFocus()
		copy.eb:HighlightText()
	end
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
	self:ShowCopy(table.concat(lines, "\n"), L.COPY_CHAT_TITLE, false, lines)
	if copy and copy.search then copy.search.eb:SetFocus() end
end

-------------------------------------------------------------------------------
-- Button bar on every chat window: settings, mentions (@), copy.
-- Default: stacked vertically right next to the chat window, bottom-aligned
-- (close to the input box). Optional: in a row above the chat window.
-------------------------------------------------------------------------------
local bars = {}
local SIZE, GAP = 24, 4
local IDLE_ALPHA = 0.9
local BTN_BG = { 0.11, 0.125, 0.17, 0.92 }

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

-- Background + border behind the buttons (optional; off = icons only).
local function ApplyIdleStyle(b)
	if ns.S and ns.S.buttonBackground == false then
		b.bg:SetColorTexture(0, 0, 0, 0)
		b:SetBorderColor(0, 0, 0, 0)
	else
		b.bg:SetColorTexture(unpack(BTN_BG))
		b:SetBorderColor(unpack(C.border))
	end
end

local function BarButton(bar, tip, onClick)
	local b = CreateFrame("Button", nil, bar)
	b:SetSize(SIZE, SIZE)
	b.bg = UI.Fill(b, BTN_BG)
	UI.Border(b, C.border)
	b:SetAlpha(IDLE_ALPHA)
	ApplyIdleStyle(b)
	b:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		self.bg:SetColorTexture(unpack(C.rowHover))
		self:SetBorderColor(unpack(C.accent))
		GameTooltip:SetOwner(self, ns.S.buttonsTop and "ANCHOR_TOP" or "ANCHOR_RIGHT")
		GameTooltip:SetText(tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		ApplyIdleStyle(self)
		self:SetAlpha(IDLE_ALPHA)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	return b
end

local function Layout(bar)
	local frame = bar.chatFrame
	local list = {}
	for _, b in ipairs(bar.order) do
		if (b ~= bar.whispers or ns.S.whispers) and (b ~= bar.notes or ns.S.notes) then list[#list + 1] = b end
	end
	bar:ClearAllPoints()
	if ns.S.buttonsTop then
		bar:SetSize(#list * SIZE + (#list - 1) * GAP, SIZE)
		bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 6)
		for i, b in ipairs(list) do
			b:ClearAllPoints()
			b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (SIZE + GAP), 0)
		end
	else
		bar:SetSize(SIZE, #list * SIZE + (#list - 1) * GAP)
		bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 6, -2)
		for i, b in ipairs(list) do
			b:ClearAllPoints()
			b:SetPoint("TOP", bar, "TOP", 0, -(i - 1) * (SIZE + GAP))
		end
	end
end

local function AddBadge(b)
	b.badge = CreateFrame("Frame", nil, b)
	b.badge:SetSize(15, 13)
	b.badge:SetPoint("TOPRIGHT", 5, 5)
	b.badge:SetFrameLevel(b:GetFrameLevel() + 2)
	UI.Fill(b.badge, C.orange, "OVERLAY")
	b.badge.text = ns.UI.NoShadow(b.badge:CreateFontString(nil, "OVERLAY", _G.SystemFont_Tiny and "SystemFont_Tiny" or "GameFontHighlightSmall"))
	b.badge.text:SetPoint("CENTER", 0, 0)
	b.badge.text:SetTextColor(unpack(C.dark))
	b.badge:Hide()
end

local function SetBadge(b, n)
	b.badge:SetShown(n > 0)
	b.badge.text:SetText(n > 9 and "9+" or tostring(n))
end

function ns:UpdateChatButtons()
	local unread = self.unread or 0
	for _, bar in ipairs(bars) do
		bar:SetShown(self.S.copyButton)
		Layout(bar)
		for _, b in ipairs(bar.order) do ApplyIdleStyle(b) end
		local m = bar.mentions
		SetBadge(m, unread)
		m.icon:SetTextColor(unpack(unread > 0 and C.orange or C.accent))
		local w = bar.whispers
		w:SetShown(self.S.whispers)
		SetBadge(w, self.S.whispers and self.WhisperUnread and self:WhisperUnread() or 0)
		bar.notes:SetShown(self.S.notes)
		bar.notes.active:SetShown(self.NotesShown and self:NotesShown() or false)
	end
end

ns.OnChatFrame(function(frame)
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetFrameStrata("MEDIUM")
	bar.chatFrame = frame

	local gear = BarButton(bar, L.BTN_SETTINGS, function() ns:ToggleOptions() end)
	gear.icon = gear:CreateTexture(nil, "ARTWORK")
	gear.icon:SetSize(16, 16)
	gear.icon:SetPoint("CENTER")
	GearIcon(gear.icon)

	local m = BarButton(bar, L.BTN_MENTIONS, function() ns:ShowMentions() end)
	m.icon = ns.UI.NoShadow(m:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"))
	m.icon:SetPoint("CENTER", 0, 1)
	m.icon:SetText("@")
	m.icon:SetTextColor(unpack(C.accent))
	AddBadge(m)
	bar.mentions = m

	local w = BarButton(bar, L.BTN_WHISPERS, function() ns:ToggleWhispers() end)
	w.icon = w:CreateTexture(nil, "ARTWORK")
	w.icon:SetSize(16, 16)
	w.icon:SetPoint("CENTER")
	w.icon:SetTexture("Interface\\ChatFrame\\UI-ChatWhisperIcon")
	AddBadge(w)
	bar.whispers = w

	-- notes: a small flat sticky-note icon (yellow sheet with lines)
	local nb = BarButton(bar, L.BTN_NOTES .. "\n|cff8a94a6" .. L.NOTES_TIP .. "|r", function(_, button)
		if button == "RightButton" then ns:NewNote() else ns:ToggleNotes() end
		ns:UpdateChatButtons()
	end)
	nb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local sheet = nb:CreateTexture(nil, "ARTWORK")
	sheet:SetSize(13, 15)
	sheet:SetPoint("CENTER")
	sheet:SetColorTexture(1, 0.82, 0.30, 1)
	for i = 1, 3 do
		local l = nb:CreateTexture(nil, "OVERLAY")
		l:SetColorTexture(0.05, 0.07, 0.10, 0.8)
		l:SetSize(i == 3 and 5 or 8, 1)
		l:SetPoint("TOPLEFT", sheet, "TOPLEFT", 2, -3 - (i - 1) * 3)
	end
	nb.active = nb:CreateTexture(nil, "OVERLAY")       -- small dot: notes are open
	nb.active:SetSize(4, 4)
	nb.active:SetPoint("BOTTOMRIGHT", -2, 2)
	nb.active:SetColorTexture(unpack(C.accent))
	nb.active:Hide()
	bar.notes = nb

	local copyBtn = BarButton(bar, L.COPY_BUTTON_TIP, function() ns:CopyChat(frame) end)
	copyBtn.icon = copyBtn:CreateTexture(nil, "ARTWORK")
	copyBtn.icon:SetSize(16, 16)
	copyBtn.icon:SetPoint("CENTER")
	copyBtn.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")

	bar.order = { gear, m, w, nb, copyBtn }
	bars[#bars + 1] = bar
	if ns.S then ns:UpdateChatButtons() end
end)
