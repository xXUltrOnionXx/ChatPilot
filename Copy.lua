local _, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Read-only copy box (links and chat text)
-------------------------------------------------------------------------------
local copy

local function CreateCopy()
	local f = ns.CreateWindow("ChatPilotCopy", L.COPY_TITLE, 560, 340)
	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local eb = CreateFrame("EditBox", nil, scroll)
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal)
	eb:SetWidth(500)
	eb:SetScript("OnEscapePressed", function() f:Hide() end)
	-- read-only: typing restores the original text
	eb:SetScript("OnTextChanged", function(self, userInput)
		if userInput and f.content then
			self:SetText(f.content)
			self:HighlightText()
		end
	end)
	eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top = scroll:GetVerticalScroll()
		local height = scroll:GetHeight()
		y = -y
		if y < top then scroll:SetVerticalScroll(y)
		elseif y + h > top + height then scroll:SetVerticalScroll(y + h - height) end
	end)
	scroll:SetScrollChild(eb)
	f.eb, f.scroll = eb, scroll
	return f
end

function ns:ShowCopy(text, title, small)
	copy = copy or CreateCopy()
	copy.title:SetText(title or L.COPY_TITLE)
	copy:SetHeight(small and 110 or 340)
	copy.content = text
	copy.eb:SetText(text)
	copy:Show()
	copy.eb:SetFocus()
	copy.eb:HighlightText()
	if not small then
		C_Timer.After(0, function() copy.scroll:SetVerticalScroll(copy.scroll:GetVerticalScrollRange()) end)
	end
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
-- Small copy button on every chat window
-------------------------------------------------------------------------------
local buttons = {}

function ns:UpdateCopyButtons()
	for _, b in ipairs(buttons) do b:SetShown(self.S.copyButton) end
end

ns.OnChatFrame(function(frame)
	local b = CreateFrame("Button", nil, frame)
	b:SetSize(18, 18)
	b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	b:SetFrameLevel(frame:GetFrameLevel() + 5)
	b:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
	b:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "ADD")
	b:SetAlpha(0.25)
	b:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(L.COPY_BUTTON_TIP)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		self:SetAlpha(0.25)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function() ns:CopyChat(frame) end)
	buttons[#buttons + 1] = b
	if ns.S then b:SetShown(ns.S.copyButton) end
end)
