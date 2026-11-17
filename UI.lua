local _, ns = ...

-- Small flat UI kit so every ChatPilot window shares one clean, modern look.
local UI = {}
ns.UI = UI

local C = {
	bg        = { 0.067, 0.075, 0.102, 0.97 },
	panel     = { 0.090, 0.100, 0.135, 1 },
	row       = { 0.115, 0.127, 0.168, 1 },
	rowHover  = { 0.140, 0.155, 0.205, 1 },
	border    = { 0.190, 0.210, 0.275, 1 },
	accent    = { 0.31, 0.79, 1, 1 },
	accentHi  = { 0.50, 0.86, 1, 1 },
	accentDim = { 0.31, 0.79, 1, 0.16 },
	text      = { 0.93, 0.95, 0.98, 1 },
	muted     = { 0.56, 0.61, 0.69, 1 },
	dark      = { 0.05, 0.07, 0.10, 1 },
	orange    = { 1, 0.60, 0.12, 1 },
}
UI.C = C

function UI.Fill(frame, color, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(unpack(color))
	return t
end

-- 1px border made of four textures (no templates needed).
function UI.Border(frame, color)
	color = color or C.border
	local edges = {}
	local function edge(a, b, w, h)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(unpack(color))
		t:SetPoint(a)
		t:SetPoint(b)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		edges[#edges + 1] = t
	end
	edge("TOPLEFT", "TOPRIGHT", nil, 1)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	function frame:SetBorderColor(r, g, b, a)
		for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a or 1) end
	end
end

-- Flat look: no drop shadow under ChatPilot texts.
function UI.NoShadow(fs)
	fs:SetShadowOffset(0, 0)
	fs:SetShadowColor(0, 0, 0, 0)
	return fs
end

function UI.Text(parent, template, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
	UI.NoShadow(fs)
	fs:SetTextColor(unpack(color or C.text))
	fs:SetJustifyH("LEFT")
	return fs
end

-- Round-ish "@" badge (the ChatPilot logo).
function UI.Badge(parent, size)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(size, size)
	UI.Fill(b, C.accent, "ARTWORK")
	local fs = b:CreateFontString(nil, "OVERLAY", size >= 40 and "GameFontHighlightHuge" or "GameFontHighlightLarge")
	fs:SetPoint("CENTER", 0, 1)
	UI.NoShadow(fs)
	fs:SetText("@")
	fs:SetTextColor(unpack(C.dark))
	return b
end

function UI.CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(28, 28)
	local hl = UI.Fill(b, C.rowHover)
	hl:Hide()
	local lines = {}
	for i, rot in ipairs({ math.rad(45), math.rad(-45) }) do
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(unpack(C.muted))
		t:SetSize(13, 2)
		t:SetPoint("CENTER")
		t:SetRotation(rot)
		lines[i] = t
	end
	b:SetScript("OnEnter", function()
		hl:Show()
		for _, t in ipairs(lines) do t:SetColorTexture(unpack(C.text)) end
	end)
	b:SetScript("OnLeave", function()
		hl:Hide()
		for _, t in ipairs(lines) do t:SetColorTexture(unpack(C.muted)) end
	end)
	b:SetScript("OnClick", onClick)
	return b
end

-- Font for message texts in ChatPilot windows (size + normal/bold, no shadow).
local msgFont
function UI.MessageFont()
	if not msgFont then msgFont = CreateFont("ChatPilotMessageFont") end
	local path = (ChatFontNormal and ChatFontNormal:GetFont()) or STANDARD_TEXT_FONT
	local S = ns.S or {}
	msgFont:SetFont(path, S.textSize or 14, S.textBold and "OUTLINE" or "")
	msgFont:SetShadowOffset(0, 0)
	msgFont:SetShadowColor(0, 0, 0, 0)
	return msgFont
end

-- Movable window with a header bar. Escape closes it.
function UI.Window(name, title, w, h)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(w, h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	UI.Fill(f, C.bg)
	UI.Border(f)

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(42)
	UI.Fill(header, C.panel)
	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(unpack(C.border))
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

	local badge = UI.Badge(header, 24)
	badge:SetPoint("LEFT", 12, 0)
	f.title = UI.Text(header, "GameFontHighlightLarge")
	f.title:SetPoint("LEFT", badge, "RIGHT", 10, 0)
	f.title:SetText(title)
	f.subtitle = UI.Text(header, "GameFontHighlightSmall", C.muted)
	f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 8, -1)

	local close = UI.CloseButton(header, function() f:Hide() end)
	close:SetPoint("RIGHT", -7, 0)

	f.header = header
	f.content = CreateFrame("Frame", nil, f)
	f.content:SetPoint("TOPLEFT", 1, -43)
	f.content:SetPoint("BOTTOMRIGHT", -1, 1)

	f:Hide()
	tinsert(UISpecialFrames, name)
	return f
end

-- Flat button. style: nil (normal), "accent" or "ghost".
function UI.Button(parent, text, w, h, style)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 140, h or 28)
	local base = style == "accent" and C.accent or (style == "ghost" and C.bg or C.row)
	local hover = style == "accent" and C.accentHi or C.rowHover
	b.bg = UI.Fill(b, base)
	UI.Border(b, style == "accent" and C.accent or C.border)
	b.label = UI.NoShadow(b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	if style == "accent" then b.label:SetTextColor(unpack(C.dark)) end
	b:SetScript("OnEnter", function() b.bg:SetColorTexture(unpack(hover)) end)
	b:SetScript("OnLeave", function() b.bg:SetColorTexture(unpack(base)) end)
	b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 0, -1) end)
	b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER") end)
	function b:SetSelected(sel)
		base = sel and C.accent or C.row
		self.bg:SetColorTexture(unpack(base))
		self.label:SetTextColor(unpack(sel and C.dark or C.text))
	end
	return b
end

-- On/off switch.
function UI.Toggle(parent, onChange)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(40, 20)
	t.track = UI.Fill(t, C.border, "ARTWORK")
	t.knob = t:CreateTexture(nil, "OVERLAY")
	t.knob:SetSize(14, 14)
	function t:SetValue(v)
		self.value = v and true or false
		self.track:SetColorTexture(unpack(self.value and C.accent or C.border))
		self.knob:ClearAllPoints()
		if self.value then
			self.knob:SetPoint("RIGHT", -3, 0)
			self.knob:SetColorTexture(unpack(C.dark))
		else
			self.knob:SetPoint("LEFT", 3, 0)
			self.knob:SetColorTexture(unpack(C.muted))
		end
	end
	t:SetScript("OnClick", function(self)
		self:SetValue(not self.value)
		if onChange then onChange(self.value) end
	end)
	t:SetValue(false)
	return t
end

-- Flat single-line input with placeholder.
function UI.Input(parent, w, placeholder)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(w, 28)
	UI.Fill(holder, C.bg)
	UI.Border(holder)
	local eb = CreateFrame("EditBox", nil, holder)
	eb:SetPoint("TOPLEFT", 8, 0)
	eb:SetPoint("BOTTOMRIGHT", -8, 0)
	eb:SetFontObject(ChatFontNormal)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(60)
	local ph = UI.Text(holder, "GameFontHighlight", C.muted)
	ph:SetPoint("LEFT", 9, 0)
	ph:SetText(placeholder or "")
	local function upd() ph:SetShown(eb:GetText() == "" and not eb:HasFocus()) end
	eb:HookScript("OnTextChanged", upd)
	eb:HookScript("OnEditFocusGained", function() upd(); holder:SetBorderColor(unpack(C.accent)) end)
	eb:HookScript("OnEditFocusLost", function() upd(); holder:SetBorderColor(unpack(C.border)) end)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function() eb:SetFocus() end)
	holder.eb = eb
	return holder
end

-- Scroll area without a visible scrollbar (mouse wheel), returns the child frame.
function UI.ScrollArea(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(1, 1)
	sf:SetScrollChild(child)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, delta)
		local v = self:GetVerticalScroll() - delta * 40
		v = math.max(0, math.min(v, self:GetVerticalScrollRange()))
		self:SetVerticalScroll(v)
	end)
	sf:SetScript("OnSizeChanged", function(self, width) child:SetWidth(width) end)
	sf.child = child
	return sf
end
