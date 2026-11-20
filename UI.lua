local _, ns = ...

-- Small flat UI kit so every ChatPilot window shares one clean, modern look.
local UI = {}
ns.UI = UI

-------------------------------------------------------------------------------
-- Designs (themes). Every colour lives in the table C. Switching the design
-- changes the values inside C and repaints everything that was painted with
-- them, so the new look appears at once without a reload.
-------------------------------------------------------------------------------
local THEMES = {
	-- cool dark blue, the original ChatPilot look
	modern = {
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
		btn       = { 0.11, 0.125, 0.17, 0.92 },
		chatBg    = { 0.035, 0.04, 0.06, 0.84 },
		popup     = { 0.04, 0.05, 0.08, 0.94 },
		glowA     = { 0.31, 0.79, 1, 1 },
		glowB     = { 0.31, 0.79, 1, 1 },
	},
	-- "Forever": cheerful, fresh and hopeful. Deep sea teal with fresh mint
	-- and a warm sunrise gold.
	forever = {
		bg        = { 0.047, 0.118, 0.133, 0.97 },
		panel     = { 0.063, 0.153, 0.169, 1 },
		row       = { 0.082, 0.196, 0.212, 1 },
		rowHover  = { 0.110, 0.255, 0.271, 1 },
		border    = { 0.165, 0.341, 0.349, 1 },
		accent    = { 0.38, 0.93, 0.68, 1 },
		accentHi  = { 0.58, 0.98, 0.80, 1 },
		accentDim = { 0.38, 0.93, 0.68, 0.16 },
		text      = { 0.97, 0.99, 0.95, 1 },
		muted     = { 0.62, 0.77, 0.74, 1 },
		dark      = { 0.03, 0.09, 0.10, 1 },
		orange    = { 1, 0.76, 0.28, 1 },
		btn       = { 0.075, 0.180, 0.196, 0.92 },
		chatBg    = { 0.025, 0.075, 0.085, 0.84 },
		popup     = { 0.030, 0.090, 0.100, 0.95 },
		glowA     = { 0.38, 0.93, 0.68, 1 },
		glowB     = { 1, 0.78, 0.36, 1 },
	},
}
UI.THEMES = THEMES
UI.THEME_ORDER = { "modern", "forever" }

local C = {}
for k, v in pairs(THEMES.modern) do C[k] = { unpack(v) } end
UI.C = C
UI.theme = "modern"

-- everything painted with a colour from C, so it can be repainted
local painted = setmetatable({}, { __mode = "k" })  -- texture -> colour table
local inked = setmetatable({}, { __mode = "k" })    -- fontstring -> colour table
local glows = setmetatable({}, { __mode = "k" })    -- accent lines with a gradient
local themeCallbacks = {}

function UI.Paint(tex, color)
	painted[tex] = color
	tex:SetColorTexture(unpack(color))
	return tex
end

function UI.Ink(fs, color)
	inked[fs] = color
	fs:SetTextColor(unpack(color))
	return fs
end

-- A thin accent line: plain in "Modern", a mint-to-gold gradient in "Forever".
local function PaintGlow(t)
	t:SetColorTexture(1, 1, 1, 1)
	if t.SetGradient and CreateColor then
		local a, b = C.glowA, C.glowB
		local ok = pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(a[1], a[2], a[3], a[4]), CreateColor(b[1], b[2], b[3], b[4]))
		if ok then return end
	end
	t:SetColorTexture(unpack(C.glowA))
end
function UI.Glow(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	glows[t] = true
	PaintGlow(t)
	return t
end

function UI.OnTheme(fn) themeCallbacks[#themeCallbacks + 1] = fn end

function UI.ApplyTheme(name)
	local theme = THEMES[name] or THEMES.modern
	UI.theme = THEMES[name] and name or "modern"
	for k, v in pairs(theme) do
		local t = C[k]
		if t then for i = 1, 4 do t[i] = v[i] end else C[k] = { unpack(v) } end
	end
	for tex, color in pairs(painted) do pcall(tex.SetColorTexture, tex, unpack(color)) end
	for fs, color in pairs(inked) do pcall(fs.SetTextColor, fs, unpack(color)) end
	for t in pairs(glows) do pcall(PaintGlow, t) end
	for _, fn in ipairs(themeCallbacks) do pcall(fn, UI.theme) end
end

-- colour as a |c escape, e.g. for chat lines
function UI.Hex(color)
	return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

function UI.Fill(frame, color, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	t:SetAllPoints()
	return UI.Paint(t, color)
end

-- 1px border made of four textures (no templates needed).
function UI.Border(frame, color)
	color = color or C.border
	local edges = {}
	local function edge(a, b, w, h)
		local t = frame:CreateTexture(nil, "BORDER")
		UI.Paint(t, color)
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
	UI.Ink(fs, color or C.text)
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
	UI.Ink(fs, C.dark)
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
		UI.Paint(t, C.muted)
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
	local line = UI.Glow(header)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(2)
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
	if style == "accent" then UI.Ink(b.label, C.dark) end
	b:SetScript("OnEnter", function() b.bg:SetColorTexture(unpack(hover)) end)
	b:SetScript("OnLeave", function() b.bg:SetColorTexture(unpack(base)) end)
	b:SetScript("OnMouseDown", function() b.label:SetPoint("CENTER", 0, -1) end)
	b:SetScript("OnMouseUp", function() b.label:SetPoint("CENTER") end)
	function b:SetSelected(sel)
		base = sel and C.accent or C.row
		UI.Paint(self.bg, base)
		UI.Ink(self.label, sel and C.dark or C.text)
	end
	return b
end

-- Button that needs a second click within 3 seconds (for things that delete).
function UI.ConfirmButton(parent, text, w, h, onConfirm, confirmText)
	local b = UI.Button(parent, text, w, h)
	local function Reset()
		b.armed = nil
		b.label:SetText(text)
		UI.Ink(b.label, C.text)
	end
	b:SetScript("OnClick", function()
		if not b.armed then
			b.armed = GetTime()
			b.label:SetText(confirmText or (ns.L and ns.L.CLEAR_CONFIRM) or "?")
			UI.Ink(b.label, C.orange)
			local stamp = b.armed
			C_Timer.After(3, function() if b.armed == stamp then Reset() end end)
			return
		end
		Reset()
		onConfirm(b)
	end)
	b:HookScript("OnHide", Reset)
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
	UI.OnTheme(function() t:SetValue(t.value) end)
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

-------------------------------------------------------------------------------
-- Notification orb: a soft ball of light that pulls itself into a badge or
-- dot when something new arrives, flashes once and then gently "breathes"
-- while it stays unread. Pure textures and one OnUpdate - nothing protected.
-------------------------------------------------------------------------------
local GLOW_TEX = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64"
local BALL_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function Ease(t) return 1 - (1 - t) ^ 3 end

-- target: the region the light pulls into (badge or dot). size: resting glow size.
function UI.Orb(target, size, color)
	size = size or 26
	local o = CreateFrame("Frame", nil, target:GetParent() or target)
	o:SetPoint("CENTER", target, "CENTER")
	o:SetSize(1, 1)
	o:SetFrameLevel(math.max(0, (target.GetFrameLevel and target:GetFrameLevel() or 1) - 1))
	o:EnableMouse(false)
	o.color = color or C.orange
	o.halo = o:CreateTexture(nil, "BACKGROUND")
	o.halo:SetTexture(GLOW_TEX)
	o.halo:SetBlendMode("ADD")
	o.halo:SetPoint("CENTER")
	o.ball = o:CreateTexture(nil, "ARTWORK")
	o.ball:SetTexture(BALL_TEX)
	o.ball:SetBlendMode("ADD")
	o.ball:SetPoint("CENTER")
	o.size, o.t, o.mode = size, 0, "off"
	local function Tint(tex, a)
		local c = o.color
		tex:SetVertexColor(c[1], c[2], c[3], a)
	end
	o:SetScript("OnUpdate", function(self, e)
		self.t = self.t + e
		if self.mode == "pull" then
			-- big faint light rushes in and becomes bright and small
			local p = math.min(1, self.t / 0.45)
			local k = Ease(p)
			local s = self.size * (3.2 - 2.2 * k)
			self.halo:SetSize(s * 1.6, s * 1.6)
			Tint(self.halo, 0.25 + 0.75 * k)
			local b = self.size * (1.8 - 1.35 * k)
			self.ball:SetSize(b, b)
			Tint(self.ball, 0.15 + 0.6 * k)
			if p >= 1 then self.mode, self.t = "flash", 0 end
		elseif self.mode == "flash" then
			-- short bright flash in the badge
			local p = math.min(1, self.t / 0.25)
			local s = self.size * (1 + 0.5 * math.sin(p * math.pi))
			self.halo:SetSize(s * 1.6, s * 1.6)
			Tint(self.halo, 1)
			self.ball:SetSize(self.size * 0.45, self.size * 0.45)
			Tint(self.ball, 0.75 * (1 - p))
			if p >= 1 then self.mode, self.t = "breathe", 0 end
		elseif self.mode == "breathe" then
			-- calm pulse while unread
			local w = 0.5 + 0.5 * math.sin(self.t * 3)
			local s = self.size * (1.15 + 0.25 * w)
			self.halo:SetSize(s * 1.4, s * 1.4)
			Tint(self.halo, 0.35 + 0.45 * w)
			Tint(self.ball, 0)
		else
			self:Hide()
		end
	end)
	-- something new arrived: play the pull-in
	function o:Pop()
		self.mode, self.t = "pull", 0
		self:Show()
	end
	-- unread or not (keeps breathing, or switches off)
	function o:SetActive(on)
		if on then
			if self.mode == "off" then self.mode, self.t = "breathe", 0 end
			self:Show()
		else
			self.mode = "off"
			self:Hide()
		end
	end
	o:Hide()
	return o
end

-------------------------------------------------------------------------------
-- Conversation look for chat lines: a thin colour bar in front of each
-- message. Colour = the sender (class colour), your own messages use the
-- design's accent colour, mentions of you are orange. Colour is never the only
-- hint: names / "You" stay in the text.
-------------------------------------------------------------------------------
function UI.Bar(r, g, b, width)
	return ("|TInterface\\Buttons\\WHITE8X8:0:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t "):format(width or 3,
		math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

-- own messages and mentions get a wide bar, so they stand out by shape too
-- (a mage's blue or a druid's orange can look similar to the accent colours)
function UI.BarFor(kind, classFile, r, g, b)
	if kind == "own" then return UI.Bar(C.accent[1], C.accent[2], C.accent[3], 6) end
	if kind == "mention" then return UI.Bar(C.orange[1], C.orange[2], C.orange[3], 6) end
	if kind == "system" then return UI.Bar(C.muted[1], C.muted[2], C.muted[3]) end
	local cc = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if cc then return UI.Bar(cc.r, cc.g, cc.b) end
	return UI.Bar(r, g, b)
end

