local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- Step-by-step tour of ChatPilot Forever. Opens once after an update with new
-- features and can be watched again any time (/chatpilot tutorial, or the
-- button in the settings). It only shows information.

local TUTORIAL_VERSION = 5 -- raise when the tour gets new steps: shows once more after the update
local W, H = 540, 330
local tut, spot, overlay
local saved, Undock, Dock
local index = 1

-------------------------------------------------------------------------------
-- Tiny tween helper (smooth fades and slides)
-------------------------------------------------------------------------------
local function Ease(t) return 1 - (1 - t) ^ 3 end

local function Tween(frame, duration, fn, done)
	frame.tweenT = 0
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.tweenT = self.tweenT + elapsed
		local p = math.min(1, self.tweenT / duration)
		fn(Ease(p))
		if p >= 1 then
			self:SetScript("OnUpdate", nil)
			if done then done() end
		end
	end)
end

-------------------------------------------------------------------------------
-- Pictures for the steps (drawn with simple shapes, so they follow the design)
-------------------------------------------------------------------------------
local function KeyChip(parent, text, x, y)
	local k = CreateFrame("Frame", nil, parent)
	k:SetSize(math.max(34, #text * 9 + 16), 28)
	k:SetPoint("CENTER", parent, "CENTER", x, y)
	UI.Fill(k, C.row)
	UI.Border(k, C.accent)
	local fs = UI.Text(k, "GameFontHighlight", C.text)
	fs:SetPoint("CENTER")
	fs:SetText(text)
	return k
end

local function Lines(parent, color, list)
	for _, l in ipairs(list) do
		local t = parent:CreateTexture(nil, "ARTWORK")
		t:SetSize(l[1], l[2])
		t:SetPoint("CENTER", parent, "CENTER", l[3] or 0, l[4] or 0)
		if l[5] then t:SetRotation(math.rad(l[5])) end
		UI.Paint(t, color)
	end
end

local PICTURES
PICTURES = {
	set_design = function(p) PICTURES.design(p) end,
	welcome = function(p)
		local b = UI.Badge(p, 64)
		b:SetPoint("CENTER")
	end,
	typing = function(p)
		KeyChip(p, "@", -44, 18)
		KeyChip(p, "Enter", 22, 18)
		KeyChip(p, "Tab", -26, -18)
		KeyChip(p, "#", 22, -18)
	end,
	mentions = function(p)
		local b = UI.Badge(p, 56)
		b:SetPoint("CENTER", -6, 0)
		local dot = CreateFrame("Frame", nil, p)
		dot:SetSize(18, 16)
		dot:SetPoint("CENTER", 24, 22)
		UI.Fill(dot, C.orange)
		local n = UI.Text(dot, "GameFontHighlightSmall", C.dark)
		n:SetPoint("CENTER")
		n:SetText("3")
	end,
	whispers = function(p)
		local t = p:CreateTexture(nil, "ARTWORK")
		t:SetSize(56, 56)
		t:SetPoint("CENTER")
		t:SetTexture("Interface\\ChatFrame\\UI-ChatWhisperIcon")
	end,
	notes = function(p)
		local s = p:CreateTexture(nil, "ARTWORK")
		s:SetSize(52, 60)
		s:SetPoint("CENTER")
		s:SetColorTexture(1, 0.82, 0.30, 1)
		for i = 1, 4 do
			local l = p:CreateTexture(nil, "OVERLAY")
			l:SetColorTexture(0.05, 0.07, 0.10, 0.75)
			l:SetSize(i == 4 and 18 or 34, 2)
			l:SetPoint("TOPLEFT", s, "TOPLEFT", 9, -12 - (i - 1) * 10)
		end
	end,
	windows = function(p)
		for i = 0, 1 do
			local f = CreateFrame("Frame", nil, p)
			f:SetSize(62, 46)
			f:SetPoint("CENTER", -14 + i * 26, 10 - i * 22)
			UI.Fill(f, C.panel)
			UI.Border(f, i == 1 and C.accent or C.border)
			local bar = f:CreateTexture(nil, "ARTWORK")
			bar:SetPoint("TOPLEFT", 1, -1)
			bar:SetPoint("TOPRIGHT", -1, -1)
			bar:SetHeight(9)
			UI.Paint(bar, C.row)
		end
		local plus = CreateFrame("Frame", nil, p)
		plus:SetSize(20, 20)
		plus:SetPoint("CENTER", 34, 30)
		UI.Fill(plus, C.btn)
		UI.Border(plus, C.accent)
		Lines(plus, C.accent, { { 10, 2 }, { 2, 10 } })
	end,
	names = function(p)
		local line = CreateFrame("Frame", nil, p)
		line:SetSize(120, 22)
		line:SetPoint("CENTER", 0, 30)
		UI.Fill(line, C.row)
		local t = UI.Text(line, "GameFontHighlight", C.text)
		t:SetPoint("LEFT", 8, 0)
		t:SetText("|cff3fc7eb[Frost W.]|r: hi!")
		local card = CreateFrame("Frame", nil, p)
		card:SetSize(112, 52)
		card:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 14, -6)
		UI.Fill(card, C.bg)
		UI.Border(card, C.accent)
		local n = UI.Text(card, "GameFontHighlightSmall", C.text)
		n:SetPoint("TOPLEFT", 7, -6)
		n:SetText("|cff3fc7ebFrost Winterborn|r")
		local l = UI.Text(card, "GameFontHighlightSmall", C.muted)
		l:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -4)
		l:SetText(L.PI_LEVEL:format(18) .. " · " .. ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.MAGE) or "Mage"))
	end,
	writing = function(p)
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(96, 26)
		row:SetPoint("CENTER", 0, -8)
		UI.Fill(row, C.btn)
		UI.Border(row, C.accent)
		local chip = CreateFrame("Frame", nil, p)
		chip:SetSize(52, 22)
		chip:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 6)
		UI.Fill(chip, C.row)
		UI.Border(chip, C.border)
		local t = UI.Text(chip, "GameFontHighlightSmall", C.accent)
		t:SetPoint("CENTER")
		t:SetText("@Lia")
		local caret = row:CreateTexture(nil, "OVERLAY")
		caret:SetSize(2, 14)
		caret:SetPoint("LEFT", 10, 0)
		UI.Paint(caret, C.text)
	end,
	design = function(p)
		for i, name in ipairs(UI.THEME_ORDER) do
			local th = UI.THEMES[name]
			local f = CreateFrame("Frame", nil, p)
			f:SetSize(40, 56)
			f:SetPoint("CENTER", (i - 1.5) * 48, 0)
			local bg = f:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(unpack(th.bg))
			local a = f:CreateTexture(nil, "ARTWORK")
			a:SetPoint("TOPLEFT", 4, -6)
			a:SetPoint("TOPRIGHT", -4, -6)
			a:SetHeight(6)
			a:SetColorTexture(unpack(th.accent))
			local b = f:CreateTexture(nil, "ARTWORK")
			b:SetPoint("TOPLEFT", 4, -16)
			b:SetSize(16, 6)
			b:SetColorTexture(unpack(th.glowB))
		end
	end,
	sounds = function(p)
		KeyChip(p, "A", -46, 18)
		KeyChip(p, "S", -10, 18)
		KeyChip(p, "D", 26, 18)
		KeyChip(p, "<", -20, -20)
		KeyChip(p, ">", 20, -20)
		for i = 1, 3 do
			local w = p:CreateTexture(nil, "ARTWORK")
			w:SetSize(3, 6 + i * 5)
			w:SetPoint("CENTER", 52 + i * 7, 18)
			UI.Paint(w, C.accent)
		end
	end,
	tabs = function(p)
		local x = -58
		for i, label in ipairs({ "Gilde", "Handel-Leute" }) do
			local t = CreateFrame("Frame", nil, p)
			t:SetSize(i == 1 and 46 or 62, 22)
			t:SetPoint("LEFT", p, "CENTER", x, 6)
			x = x + (i == 1 and 48 or 64)
			UI.Fill(t, C.btn)
			if i == 1 then
				local line = t:CreateTexture(nil, "OVERLAY")
				line:SetPoint("BOTTOMLEFT", 3, 0)
				line:SetPoint("BOTTOMRIGHT", -3, 0)
				line:SetHeight(2)
				UI.Paint(line, C.accent)
			end
			local fs = UI.Text(t, "GameFontHighlightSmall", i == 1 and C.text or C.muted)
			fs:SetPoint("LEFT", 6, 0)
			fs:SetWidth((i == 1 and 46 or 62) - 10)
			fs:SetWordWrap(false)
			fs:SetText(label)
		end
		local d = CreateFrame("Frame", nil, p)
		d:SetSize(20, 20)
		d:SetPoint("LEFT", p, "CENTER", x + 8, 6)
		UI.Fill(d, C.row)
		UI.Border(d, C.border)
		Lines(d, C.accent, { { 6, 2, -2, 0, -45 }, { 6, 2, 2, 0, 45 } })
		local tip = UI.Text(p, "GameFontHighlightSmall", C.accent)
		tip:SetPoint("CENTER", 0, -22)
		tip:SetText(L.TUT_RIGHTCLICK)
	end,
	enter = function(p)
		KeyChip(p, "Enter", -22, 22)
		local box = CreateFrame("Frame", nil, p)
		box:SetSize(112, 24)
		box:SetPoint("CENTER", 0, -22)
		UI.Fill(box, C.btn)
		UI.Border(box, C.accent)
		local caret = box:CreateTexture(nil, "OVERLAY")
		caret:SetSize(2, 14)
		caret:SetPoint("LEFT", 10, 0)
		UI.Paint(caret, C.text)
		Lines(p, C.accent, { { 2, 12, 36, 2 }, { 8, 2, 33, -4, -45 }, { 8, 2, 39, -4, 45 } })
	end,
	scroll = function(p)
		for i = 1, 3 do
			local r = CreateFrame("Frame", nil, p)
			r:SetSize(112, 10)
			r:SetPoint("CENTER", 0, 38 - i * 16)
			UI.Fill(r, C.row)
		end
		local chip = CreateFrame("Frame", nil, p)
		chip:SetSize(96, 24)
		chip:SetPoint("CENTER", 0, -30)
		UI.Fill(chip, C.accent)
		local t = UI.Text(chip, "GameFontHighlightSmall", C.dark)
		t:SetPoint("CENTER")
		t:SetText("\226\150\188 3")
	end,
	backup = function(p)
		for i = 0, 1 do
			local f = CreateFrame("Frame", nil, p)
			f:SetSize(52, 64)
			f:SetPoint("CENTER", -14 + i * 22, 6 - i * 6)
			UI.Fill(f, i == 1 and C.panel or C.row)
			UI.Border(f, i == 1 and C.accent or C.border)
		end
		Lines(p, C.accent, { { 24, 2, 14, 2 }, { 24, 2, 14, -8 }, { 16, 2, 10, -18 } })
	end,
	tidy = function(p)
		for i = 1, 3 do
			local r = CreateFrame("Frame", nil, p)
			r:SetSize(104, 14)
			r:SetPoint("CENTER", -8, 24 - i * 18)
			UI.Fill(r, i == 2 and C.accentDim or C.row)
		end
		local b = CreateFrame("Frame", nil, p)
		b:SetSize(22, 22)
		b:SetPoint("CENTER", 58, 6)
		UI.Fill(b, C.btn)
		UI.Border(b, C.orange)
		Lines(b, C.orange, { { 12, 2, 0, 0, 45 }, { 12, 2, 0, 0, -45 } })
	end,
	search = function(p)
		local box = CreateFrame("Frame", nil, p)
		box:SetSize(112, 26)
		box:SetPoint("CENTER", 0, 26)
		UI.Fill(box, C.btn)
		UI.Border(box, C.accent)
		local fs = UI.Text(box, "GameFontHighlightSmall", C.text)
		fs:SetPoint("LEFT", 8, 0)
		fs:SetText("onyxia")
		for i = 1, 3 do
			local r = CreateFrame("Frame", nil, p)
			r:SetSize(112, 12)
			r:SetPoint("CENTER", 0, 26 - i * 22)
			UI.Fill(r, i == 1 and C.accentDim or C.row)
		end
	end,
	settings = function(p)
		local f = CreateFrame("Frame", nil, p)
		f:SetSize(104, 78)
		f:SetPoint("CENTER")
		UI.Fill(f, C.bg)
		UI.Border(f, C.accent)
		local side = f:CreateTexture(nil, "ARTWORK")
		side:SetPoint("TOPLEFT", 1, -1)
		side:SetPoint("BOTTOMLEFT", 1, 1)
		side:SetWidth(30)
		UI.Paint(side, C.panel)
		for i = 1, 4 do
			local b = f:CreateTexture(nil, "OVERLAY")
			b:SetSize(20, 3)
			b:SetPoint("TOPLEFT", 6, -10 - (i - 1) * 12)
			UI.Paint(b, i == 1 and C.accent or C.muted)
		end
		for i = 1, 3 do
			local r = f:CreateTexture(nil, "ARTWORK")
			r:SetSize(58, 12)
			r:SetPoint("TOPLEFT", 38, -8 - (i - 1) * 20)
			UI.Paint(r, C.row)
			local tg = f:CreateTexture(nil, "OVERLAY")
			tg:SetSize(10, 6)
			tg:SetPoint("TOPRIGHT", -10, -11 - (i - 1) * 20)
			UI.Paint(tg, i ~= 3 and C.accent or C.border)
		end
	end,
	set_names = function(p)
		local line = CreateFrame("Frame", nil, p)
		line:SetSize(128, 24)
		line:SetPoint("CENTER", 0, 4)
		UI.Fill(line, C.row)
		local t = UI.Text(line, "GameFontHighlightSmall", C.text)
		t:SetPoint("LEFT", 6, 0)
		t:SetText("|cff3fc7eb[Frost W.|r |cff4ade80+5m|r|cff3fc7eb]|r")
		local l2 = CreateFrame("Frame", nil, p)
		l2:SetSize(128, 24)
		l2:SetPoint("CENTER", 0, -26)
		UI.Fill(l2, C.row)
		local t2 = UI.Text(l2, "GameFontHighlightSmall", C.text)
		t2:SetPoint("LEFT", 6, 0)
		t2:SetText("|cff3fc7eb[Mira F.|r |cff7ab8ff>2h|r|cff3fc7eb]|r")
	end,
	set_safety = function(p)
		local box = CreateFrame("Frame", nil, p)
		box:SetSize(124, 40)
		box:SetPoint("CENTER", 0, 6)
		UI.Fill(box, C.row)
		UI.Border(box, { 1, 0.42, 0.35, 1 })
		local t = UI.Text(box, "GameFontHighlightSmall", { 1, 0.42, 0.35 })
		t:SetPoint("CENTER")
		t:SetText("[!] " .. (L.SCAM_FAKE or "fake link"))
		t:SetWidth(112)
		t:SetWordWrap(false)
	end,
	set_stream = function(p)
		local live = CreateFrame("Frame", nil, p)
		live:SetSize(84, 28)
		live:SetPoint("CENTER", 0, 20)
		local bg = live:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.9, 0.2, 0.2, 1)
		local t = UI.Text(live, "GameFontHighlight", { 1, 1, 1 })
		t:SetPoint("CENTER")
		t:SetText("\226\151\143 LIVE")
		local h = UI.Text(p, "GameFontHighlightSmall", C.muted)
		h:SetPoint("CENTER", 0, -22)
		h:SetText("*****")
	end,
	set_pilot = function(p)
		local a = UI.Badge(p, 34)
		a:SetPoint("CENTER", -34, 0)
		local b = UI.Badge(p, 34)
		b:SetPoint("CENTER", 34, 0)
		Lines(p, C.accent, { { 22, 2, 0, 0 } })
		local dot = p:CreateTexture(nil, "OVERLAY")
		dot:SetSize(10, 10)
		dot:SetPoint("CENTER", 52, 18)
		dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
		dot:SetVertexColor(0.35, 0.65, 1)
	end,
	done = function(p)
		local ring = CreateFrame("Frame", nil, p)
		ring:SetSize(60, 60)
		ring:SetPoint("CENTER")
		UI.Fill(ring, C.accentDim)
		UI.Border(ring, C.accent)
		Lines(ring, C.accent, { { 14, 4, -9, -3, -45 }, { 28, 4, 6, 3, 45 } })
	end,
}

-------------------------------------------------------------------------------
-- Spotlight: a soft pulsing frame around the button a step talks about
-------------------------------------------------------------------------------
local function Spotlight()
	if spot then return spot end
	spot = CreateFrame("Frame", nil, UIParent)
	spot:SetFrameStrata("FULLSCREEN_DIALOG")
	spot:EnableMouse(false)
	local edges = {}
	for i = 1, 4 do
		local t = spot:CreateTexture(nil, "OVERLAY")
		UI.Paint(t, C.accent)
		edges[i] = t
	end
	edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
	edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
	edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(2)
	edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(2)
	spot.glow = spot:CreateTexture(nil, "BACKGROUND")
	spot.glow:SetAllPoints()
	UI.Paint(spot.glow, C.accentDim)
	spot.t = 0
	spot:SetScript("OnUpdate", function(self, e)
		self.t = self.t + e
		self:SetAlpha(0.55 + 0.45 * math.abs(math.sin(self.t * 2.6)))
	end)
	spot:Hide()
	return spot
end

-- darkens the whole screen except a hole around the highlighted button
local function LayoutDim(target)
	if not overlay or not overlay.dim then return end
	local d = overlay.dim
	for _, t in ipairs(d) do t:ClearAllPoints() end
	if not target then
		d[1]:SetAllPoints(overlay)
		for k = 2, 4 do d[k]:Hide() end
		d[1]:Show()
		return
	end
	local pad = 6
	-- top, bottom, left, right of the hole
	d[1]:SetPoint("TOPLEFT", overlay, "TOPLEFT")
	d[1]:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")
	d[1]:SetPoint("BOTTOM", target, "TOP", 0, pad)
	d[2]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT")
	d[2]:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT")
	d[2]:SetPoint("TOP", target, "BOTTOM", 0, -pad)
	d[3]:SetPoint("TOPLEFT", d[1], "BOTTOMLEFT")
	d[3]:SetPoint("BOTTOMLEFT", d[2], "TOPLEFT")
	d[3]:SetPoint("RIGHT", target, "LEFT", -pad, 0)
	d[4]:SetPoint("TOPRIGHT", d[1], "BOTTOMRIGHT")
	d[4]:SetPoint("BOTTOMRIGHT", d[2], "TOPRIGHT")
	d[4]:SetPoint("LEFT", target, "RIGHT", pad, 0)
	for _, t in ipairs(d) do t:Show() end
end

local function ShowSpot(target)
	local s = Spotlight()
	if not target or not target.IsVisible or not target:IsVisible() then
		s:Hide()
		LayoutDim(nil)
		return
	end
	s:ClearAllPoints()
	s:SetPoint("TOPLEFT", target, "TOPLEFT", -5, 5)
	s:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 5, -5)
	s:Show()
	LayoutDim(target)
end

-------------------------------------------------------------------------------
-- Steps
-------------------------------------------------------------------------------
local STEPS = {
	{ key = "welcome", ch = "basics" },
	{ key = "typing", ch = "basics" },
	{ key = "sounds", ch = "basics" },
	{ key = "mentions", ch = "alerts", target = function() return ns.ChatBarButton and ns.ChatBarButton("mentions") end },
	{ key = "whispers", ch = "alerts", target = function() return ns.ChatBarButton and ns.ChatBarButton("whispers") end },
	{ key = "notes", ch = "alerts", target = function() return ns.ChatBarButton and ns.ChatBarButton("notes") end },
	{ key = "names", ch = "windows" },
	{ key = "windows", ch = "windows", target = function() return ns._cwPlus and ns._cwPlus() end },
	{ key = "writing", ch = "windows" },
	{ key = "tabs", ch = "windows" },
	{ key = "search", ch = "windows" },
	{ key = "settings", ch = "settings", page = 1, row = "nav" },
	{ key = "set_names", ch = "settings", page = 4, row = "presenceTag" },
	{ key = "set_safety", ch = "settings", page = 4, row = "scamWarn" },
	{ key = "set_stream", ch = "settings", page = 4, row = "stream" },
	{ key = "set_pilot", ch = "settings", page = 4, row = "pilotLink" },
	{ key = "set_design", ch = "settings", page = 5 },
	{ key = "done", ch = "settings" },
}
ns.TUTORIAL_STEPS = STEPS

local function Build()
	overlay = CreateFrame("Frame", nil, UIParent)
	overlay:SetAllPoints(UIParent)
	overlay:SetFrameStrata("DIALOG")
	overlay:EnableMouse(false)
	-- strong dim made of four pieces, so the button a step talks about can stay bright
	overlay.dim = {}
	for k = 1, 4 do
		local t = overlay:CreateTexture(nil, "BACKGROUND")
		t:SetColorTexture(0, 0, 0, 0.72)
		overlay.dim[k] = t
	end
	overlay:Hide()

	tut = UI.Window("ChatPilotTutorial", L.TUT_TITLE, W, H)
	tut:SetFrameStrata("FULLSCREEN_DIALOG")
	local c = tut.content

	tut.stage = CreateFrame("Frame", nil, c)
	tut.stage:SetPoint("TOPLEFT", 0, 0)
	tut.stage:SetPoint("BOTTOMRIGHT", 0, 58)

	tut.pages = {}
	for i, step in ipairs(STEPS) do
		local page = CreateFrame("Frame", nil, tut.stage)
		page:SetSize(W - 2, H - 43 - 58)
		page:SetPoint("TOPLEFT", 0, 0)
		local pic = CreateFrame("Frame", nil, page)
		pic:SetSize(150, 150)
		pic:SetPoint("LEFT", 22, 4)
		UI.Fill(pic, C.panel)
		UI.Border(pic, C.border)
		local draw = PICTURES[step.key]
		if draw then draw(pic) end
		local title = UI.Text(page, "GameFontHighlightLarge")
		title:SetPoint("TOPLEFT", pic, "TOPRIGHT", 22, -6)
		title:SetPoint("RIGHT", page, "RIGHT", -22, 0)
		title:SetText(L["TUT_" .. step.key .. "_T"])
		local body = UI.Text(page, "GameFontHighlight", C.muted)
		body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
		body:SetPoint("RIGHT", page, "RIGHT", -22, 0)
		body:SetSpacing(4)
		body:SetText(L["TUT_" .. step.key .. "_B"])
		page:Hide()
		tut.pages[i] = page
	end

	-- footer: progress dots, step counter, back / next
	local foot = CreateFrame("Frame", nil, c)
	foot:SetPoint("BOTTOMLEFT")
	foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(58)
	UI.Fill(foot, C.panel)
	local line = foot:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT")
	line:SetPoint("TOPRIGHT")
	line:SetHeight(1)
	UI.Paint(line, C.border)
	tut.dots = {}
	for i = 1, #STEPS do
		local d = foot:CreateTexture(nil, "ARTWORK")
		d:SetHeight(6)
		tut.dots[i] = d
	end
	tut.count = UI.Text(foot, "GameFontHighlightSmall", C.muted)
	tut.count:SetPoint("LEFT", 22, -10)
	tut.next = UI.Button(foot, L.TUT_NEXT, 130, 32, "accent")
	tut.next:SetPoint("RIGHT", -16, 0)
	tut.back = UI.Button(foot, L.TUT_BACK, 100, 32)
	tut.back:SetPoint("RIGHT", tut.next, "LEFT", -8, 0)
	tut.next:SetScript("OnClick", function()
		if index >= #STEPS then tut:Hide() else ns:TutorialGo(index + 1) end
	end)
	tut.back:SetScript("OnClick", function() if index > 1 then ns:TutorialGo(index - 1) end end)
	tut:HookScript("OnHide", function()
		Undock()
		overlay:Hide()
		if spot then spot:Hide() end
		if ns.tutorialPaused then return end -- closed by a fight: not done yet
		if ns.db then ns.db.tutorial = TUTORIAL_VERSION end
	end)
end

-- Settings steps: the settings window opens next to the tour (or above it on
-- small screens) and everything goes back afterwards.
function Undock()
	if not saved then return end
	local s = saved
	saved = nil
	local ow = ns.OptionsWindow and ns:OptionsWindow()
	if ow then
		if not s.wasShown then ow:Hide() end
		if s.strata then ow:SetFrameStrata(s.strata) end
		if s.opt and s.opt[1] then ow:ClearAllPoints(); ow:SetPoint(unpack(s.opt)) end
	end
	if tut and s.tour and s.tour[1] then tut:ClearAllPoints(); tut:SetPoint(unpack(s.tour)) end
end

function Dock(wasShown)
	local ow = ns.OptionsWindow and ns:OptionsWindow()
	if not ow then return end
	if not saved then
		saved = { wasShown = wasShown, strata = ow:GetFrameStrata(), opt = { ow:GetPoint() }, tour = { tut:GetPoint() } }
	end
	local sw = UIParent:GetWidth() or 0
	local ow_w = ow:GetWidth() or 760
	ow:ClearAllPoints()
	tut:ClearAllPoints()
	if sw >= ow_w + W + 60 then
		ow:SetPoint("CENTER", UIParent, "CENTER", -(W + 20) / 2, 20)
		tut:SetPoint("CENTER", UIParent, "CENTER", (ow_w + 20) / 2, 20)
	else
		ow:SetPoint("TOP", UIParent, "TOP", 0, -24)
		tut:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 24)
	end
	ow:SetFrameStrata("FULLSCREEN_DIALOG")
	ow:Raise()
	tut:Raise()
end

local function LayoutDots()
	local x = 22
	for i, d in ipairs(tut.dots) do
		local active = i == index
		d:SetWidth(active and 22 or 6)
		d:ClearAllPoints()
		d:SetPoint("LEFT", tut.dots[1]:GetParent(), "LEFT", x, 10)
		UI.Paint(d, active and C.accent or (i < index and C.muted or C.border))
		x = x + (active and 22 or 6) + 6
	end
end

function ns:TutorialGo(i)
	if not tut then Build() end
	local old = tut.pages[index]
	local dir = i >= index and 1 or -1
	index = math.max(1, math.min(#STEPS, i))
	local page = tut.pages[index]
	for j, p in ipairs(tut.pages) do if p ~= old and p ~= page then p:Hide() end end

	-- smooth: old page slides out and fades, new page slides in
	if old and old ~= page and old:IsShown() then
		Tween(old, 0.18, function(p)
			old:SetAlpha(1 - p)
			old:ClearAllPoints()
			old:SetPoint("TOPLEFT", -40 * p * dir, 0)
		end, function() old:Hide(); old:SetAlpha(1); old:ClearAllPoints(); old:SetPoint("TOPLEFT", 0, 0) end)
	end
	page:Show()
	page:SetAlpha(0)
	Tween(page, 0.26, function(p)
		page:SetAlpha(p)
		page:ClearAllPoints()
		page:SetPoint("TOPLEFT", 40 * (1 - p) * dir, 0)
	end)

	local chapter = L["TUT_CH_" .. (STEPS[index].ch or "")]
	tut.count:SetText((chapter and (chapter .. "  |  ") or "") .. L.TUT_STEP:format(index, #STEPS))
	tut.back:SetShown(index > 1)
	tut.next.label:SetText(index == #STEPS and L.TUT_DONE or L.TUT_NEXT)
	LayoutDots()
	local step = STEPS[index]
	local target
	if step.page then
		local before = ns.OptionsWindow and ns:OptionsWindow()
		before = before and before:IsShown() and true or false
		local ok, tg = pcall(function() return ns:OptionsFocus(step.page, step.row) end)
		target = ok and tg or nil
		Dock(before)
		-- the page needs a moment to settle before the frame can be framed
		C_Timer.After(0.12, function()
			if tut and tut:IsShown() and STEPS[index] == step and step.page then ShowSpot(target) end
		end)
	else
		Undock()
		target = step.target and step.target()
	end
	ShowSpot(target)
end

function ns:ShowTutorial(start)
	if not tut then Build() end
	overlay:Show()
	overlay:SetAlpha(0)
	tut:SetAlpha(0)
	tut:Show()
	tut:Raise()
	Tween(overlay, 0.25, function(p) overlay:SetAlpha(p); tut:SetAlpha(p) end)
	index = 1
	self:TutorialGo(start or 1)
end

local prevLogin = ns.OnLogin
function ns:OnLogin()
	if prevLogin then prevLogin(self) end
	if (self.db.tutorial or 0) < TUTORIAL_VERSION then
		C_Timer.After(4, function()
			if not InCombatLockdown or not InCombatLockdown() then ns:ShowTutorial() end
		end)
	end
end

function ns:TutorialShown() return tut and tut:IsShown() and true or false end

-- A fight starts: the tour (which darkens the screen) gets out of the way at
-- once and comes back a few seconds after the fight, at the same step.
local resumeAt
local fight = CreateFrame("Frame")
fight:RegisterEvent("PLAYER_REGEN_DISABLED")
fight:RegisterEvent("PLAYER_REGEN_ENABLED")
fight:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if tut and tut:IsShown() then
			resumeAt = index
			ns.tutorialPaused = true
			tut:Hide()
			ns.tutorialPaused = nil
		end
	elseif resumeAt then
		C_Timer.After(4, function()
			if resumeAt and not (InCombatLockdown and InCombatLockdown()) then
				local i = resumeAt
				resumeAt = nil
				ns:ShowTutorial(i)
			end
		end)
	end
end)
