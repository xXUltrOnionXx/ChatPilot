local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- "Thank you" window: pops up once after every update, with confetti, a warm
-- thank-you from xXUltrOnionXx and the highlights of the new version.
-- Can be opened again any time from the "Patch notes" page or /chatpilot thanks.

local WIDTH, HEIGHT = 500, 440
local MAXLINES = 14

-- "1.7.10" is newer than "1.7.9"
function ns.VersionNewer(a, b)
	local pa, pb = {}, {}
	for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
	for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then return x > y end
	end
	return false
end
local frame, confetti

-------------------------------------------------------------------------------
-- Confetti
-------------------------------------------------------------------------------
local PIECES, LIFE = 90, 5.5
local DOT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function Colors()
	return {
		C.accent, C.orange, { 1, 0.82, 0.25 }, { 0.42, 0.92, 0.72 },
		{ 1, 0.47, 0.72 }, { 0.62, 0.55, 1 }, { 1, 1, 1 },
	}
end

local function BuildConfetti()
	confetti = CreateFrame("Frame", nil, UIParent)
	confetti:SetAllPoints(UIParent)
	confetti:SetFrameStrata("FULLSCREEN_DIALOG")
	confetti:EnableMouse(false)
	confetti.p = {}
	for i = 1, PIECES do
		local t = confetti:CreateTexture(nil, "OVERLAY")
		confetti.p[i] = { tex = t }
	end
	confetti:Hide()
end

local function Burst()
	if not confetti then BuildConfetti() end
	confetti:SetFrameLevel((frame and frame:GetFrameLevel() or 100) + 20)
	local w, h = UIParent:GetWidth() or 1600, UIParent:GetHeight() or 900
	local cols = Colors()
	for i, p in ipairs(confetti.p) do
		local c = cols[math.random(#cols)]
		local round = math.random() < 0.3
		if round then
			p.tex:SetTexture(DOT)
			local s = math.random(5, 8)
			p.tex:SetSize(s, s)
		else
			p.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
			p.tex:SetSize(math.random(4, 7), math.random(9, 14))
		end
		p.tex:SetVertexColor(c[1], c[2], c[3], 1)
		-- two cannons left and right of the window, plus a light rain from above
		local side = i % 3
		if side == 0 then
			p.x, p.y = w / 2 + math.random(-260, 260), h / 2 + HEIGHT / 2 + math.random(0, 160)
			p.vx, p.vy = math.random(-40, 40), math.random(-60, 0)
		else
			local dir = side == 1 and -1 or 1
			p.x, p.y = w / 2 + dir * (WIDTH / 2 - 20), h / 2 - 40
			p.vx, p.vy = dir * math.random(120, 380), math.random(260, 520)
		end
		p.rot, p.vr = math.random() * 6.28, (math.random() - 0.5) * 9
		p.sway, p.phase = math.random(12, 30), math.random() * 6.28
		p.delay = (side == 0) and math.random() * 1.2 or math.random() * 0.25
		p.tex:Hide()
	end
	confetti.t = 0
	confetti:Show()
	confetti:SetScript("OnUpdate", function(self, el)
		self.t = self.t + el
		local fade = self.t > LIFE - 1 and math.max(0, LIFE - self.t) or 1
		for _, p in ipairs(self.p) do
			if self.t >= p.delay then
				p.vy = p.vy - 520 * el            -- gravity
				if p.vy < -150 then p.vy = -150 end -- paper floats down slowly
				p.vx = p.vx * (1 - 1.4 * el)       -- air
				p.x = p.x + p.vx * el
				p.y = p.y + p.vy * el
				p.rot = p.rot + p.vr * el
				local sx = math.sin(self.t * 3 + p.phase) * p.sway
				p.tex:ClearAllPoints()
				p.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x + sx, p.y)
				if p.tex.SetRotation then p.tex:SetRotation(p.rot) end
				p.tex:SetAlpha(fade)
				p.tex:Show()
			end
		end
		if self.t > LIFE then self:SetScript("OnUpdate", nil); self:Hide() end
	end)
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local function Build()
	local f = CreateFrame("Frame", "ChatPilotThanks", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER", 0, 40)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "ChatPilotThanks")
	UI.Paint(f:CreateTexture(nil, "BACKGROUND"), C.bg):SetAllPoints()
	UI.Border(f, C.accent)

	-- sunrise band at the top: fresh and hopeful
	local band = f:CreateTexture(nil, "BORDER")
	band:SetPoint("TOPLEFT", 1, -1)
	band:SetPoint("TOPRIGHT", -1, -1)
	band:SetHeight(150)
	band:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.band = band
	local glowA = f:CreateTexture(nil, "BORDER", nil, 1)
	glowA:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\GenericGlow64")
	glowA:SetBlendMode("ADD")
	glowA:SetSize(420, 220)
	glowA:SetPoint("TOP", 0, 60)
	f.glowA = glowA

	-- little sparkles in the band
	f.sparks = {}
	for i = 1, 14 do
		local s = f:CreateTexture(nil, "ARTWORK")
		s:SetTexture(DOT)
		local size = math.random(3, 6)
		s:SetSize(size, size)
		s:SetPoint("TOPLEFT", math.random(20, WIDTH - 20), -math.random(10, 130))
		s.base = math.random() * 6.28
		f.sparks[i] = s
	end

	local title = f:CreateFontString(nil, "OVERLAY")
	title:SetFont(STANDARD_TEXT_FONT, 26, "")
	title:SetPoint("TOP", 0, -36)
	title:SetWidth(WIDTH - 40)
	title:SetText(L.THX_TITLE)
	f.title = title

	local sub = f:CreateFontString(nil, "OVERLAY")
	sub:SetFont(STANDARD_TEXT_FONT, 14, "")
	sub:SetPoint("TOP", title, "BOTTOM", 0, -10)
	sub:SetWidth(WIDTH - 60)
	sub:SetText(L.THX_SUB)
	f.sub = sub

	local sign = f:CreateFontString(nil, "OVERLAY")
	sign:SetFont(STANDARD_TEXT_FONT, 13, "")
	sign:SetPoint("TOP", sub, "BOTTOM", 0, -10)
	sign:SetText(L.THX_SIGN)
	f.sign = sign

	-- what's new
	local badge = CreateFrame("Frame", nil, f)
	badge:SetSize(150, 22)
	badge:SetPoint("TOPLEFT", 28, -170)
	badge.bg = UI.Fill(badge, C.accent)
	badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	badge.text:SetPoint("CENTER")
	f.badge = badge

	-- the notes scroll (mouse wheel + slim bar) so long texts are never cut off
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -204)
	sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 66)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(WIDTH - 80, 10)
	sf:SetScrollChild(child)
	sf:EnableMouseWheel(true)
	f.scroll, f.child = sf, child

	local bar = f:CreateTexture(nil, "ARTWORK")
	bar:SetTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetWidth(4)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -204)
	bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 66)
	bar:SetVertexColor(1, 1, 1, 0.08)
	local thumb = f:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
	thumb:SetWidth(4)
	f.thumb = thumb
	f.bar = bar
	local function Sync()
		local range = sf:GetVerticalScrollRange() or 0
		local h = sf:GetHeight() or 1
		if range <= 0 then thumb:Hide() bar:Hide() return end
		bar:Show() thumb:Show()
		local th = math.max(24, h * h / (h + range))
		local y = (sf:GetVerticalScroll() / range) * (h - th)
		thumb:SetHeight(th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -204 - y)
	end
	f.SyncScroll = Sync
	sf:SetScript("OnMouseWheel", function(self, delta)
		local v = self:GetVerticalScroll() - delta * 30
		v = math.max(0, math.min(v, self:GetVerticalScrollRange() or 0))
		self:SetVerticalScroll(v)
		Sync()
	end)
	sf:SetScript("OnScrollRangeChanged", Sync)

	f.lines = {}
	for i = 1, MAXLINES do
		local dot = child:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(DOT)
		dot:SetSize(7, 7)
		local t = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetJustifyH("LEFT")
		t:SetWordWrap(true)
		t:SetWidth(WIDTH - 80 - 36)
		t:SetSpacing(2)
		if i == 1 then
			t:SetPoint("TOPLEFT", child, "TOPLEFT", 18, -4)
		else
			t:SetPoint("TOPLEFT", f.lines[i - 1].text, "BOTTOMLEFT", 0, -9)
		end
		dot:SetPoint("RIGHT", t, "TOPLEFT", -8, -6)
		f.lines[i] = { text = t, dot = dot }
	end

	local go = UI.Button(f, L.THX_GO, 170, 32)
	go:SetPoint("BOTTOMRIGHT", -24, 22)
	go:SetScript("OnClick", function() f:Hide() end)
	f.go = go
	local all = UI.Button(f, L.THX_ALL, 170, 32)
	all:SetPoint("BOTTOMLEFT", 24, 22)
	all:SetScript("OnClick", function() f:Hide(); ns:OpenOptions(8) end)

	local close = CreateFrame("Button", nil, f)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -8, -8)
	close.t = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	close.t:SetPoint("CENTER")
	close.t:SetText("×")
	close:SetScript("OnClick", function() f:Hide() end)

	-- gentle life: the glow breathes, the sparkles twinkle
	f:SetScript("OnUpdate", function(self, el)
		self.t = (self.t or 0) + el
		self.glowA:SetAlpha(0.35 + 0.2 * math.sin(self.t * 1.6))
		for _, s in ipairs(self.sparks) do s:SetAlpha(0.25 + 0.75 * math.abs(math.sin(self.t * 2 + s.base))) end
		if self.pop and self.pop < 1 then
			self.pop = math.min(1, self.pop + el / 0.35)
			local e = 1 - (1 - self.pop) ^ 3
			self:SetAlpha(e)
			self:SetScale(0.88 + 0.12 * e)
		end
	end)
	f:Hide()
	return f
end

local function Paint(f)
	-- colours follow the chosen design
	local a, o = C.accent, C.orange
	if f.band.SetGradient and CreateColor then
		f.band:SetGradient("VERTICAL", CreateColor(C.bg[1], C.bg[2], C.bg[3], 0), CreateColor(a[1], a[2], a[3], 0.38))
	else
		f.band:SetVertexColor(a[1], a[2], a[3], 0.25)
	end
	f.glowA:SetVertexColor(o[1], o[2], o[3])
	f.title:SetTextColor(1, 1, 1)
	f.sub:SetTextColor(C.text[1], C.text[2], C.text[3])
	f.sign:SetTextColor(o[1], o[2], o[3])
	for i, s in ipairs(f.sparks) do
		local c = (i % 2 == 0) and a or o
		s:SetVertexColor(c[1], c[2], c[3])
	end
	UI.Paint(f.badge.bg, a)
	f.badge.text:SetTextColor(C.dark[1], C.dark[2], C.dark[3])
	for _, l in ipairs(f.lines) do l.dot:SetVertexColor(a[1], a[2], a[3]) end
end

function ns:ShowThanks()
	frame = frame or Build()
	Paint(frame)
	frame.badge.text:SetText(L.THX_NEW:format(ns.version or ""))
	frame.badge:SetWidth(math.max(150, (frame.badge.text:GetStringWidth() or 120) + 24))
	-- everything that is new since the version you saw last (newest first, up to MAXLINES lines)
	local lines = {}
	local since = self.db and self.db.seenVersion
	for _, e in ipairs(ns.PATCHNOTES or {}) do
		if since and not ns.VersionNewer(e.v, since) then break end
		for _, l in ipairs(ns:PatchLines(e)) do
			if #lines < MAXLINES then lines[#lines + 1] = l end
		end
		if not since or #lines >= MAXLINES then break end
	end
	if #lines == 0 and ns.PATCHNOTES and ns.PATCHNOTES[1] then lines = ns:PatchLines(ns.PATCHNOTES[1]) end -- opened again by hand
	for i, l in ipairs(frame.lines) do
		local s = lines[i]
		l.text:SetText(s or "")
		l.text:SetShown(s ~= nil)
		l.dot:SetShown(s ~= nil)
	end
	-- size the scroll child to the text (heights are known after the next layout pass)
	local function Fit()
		local h = 8
		for i, l in ipairs(frame.lines) do
			if lines[i] then h = h + (l.text:GetStringHeight() or 14) + 9 end
		end
		frame.child:SetHeight(h)
		frame.scroll:SetVerticalScroll(0)
		frame.SyncScroll()
	end
	Fit()
	if C_Timer and C_Timer.After then C_Timer.After(0.1, Fit) end
	frame.pop = 0
	frame:SetAlpha(0)
	frame:Show()
	frame:Raise()
	if PlaySound and SOUNDKIT and SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_UNLOCK then
		pcall(PlaySound, SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_UNLOCK, "SFX")
	end
	Burst()
	if self.db then self.db.seenVersion = ns.version end
end

-- once after every update (not after a fresh install: then the tour shows)
local prevLogin = ns.OnLogin
function ns:OnLogin()
	local fresh = self.db and self.db.tutorial == nil and self.db.seenVersion == nil
	if prevLogin then prevLogin(self) end
	if not self.db or not ns.version or ns.version == "?" then return end
	if fresh then self.db.seenVersion = ns.version return end
	if self.db.seenVersion == ns.version then return end
	local tries = 0
	local function Try()
		tries = tries + 1
		local busy = (InCombatLockdown and InCombatLockdown()) or (ns.TutorialShown and ns:TutorialShown())
		if busy and tries < 30 then return C_Timer.After(10, Try) end
		ns:ShowThanks()
	end
	C_Timer.After(5, Try)
end

-- never in the way in a fight
local fight = CreateFrame("Frame")
fight:RegisterEvent("PLAYER_REGEN_DISABLED")
fight:SetScript("OnEvent", function()
	if frame and frame:IsShown() then frame:Hide() end
	if confetti and confetti:IsShown() then confetti:SetScript("OnUpdate", nil); confetti:Hide() end
end)
