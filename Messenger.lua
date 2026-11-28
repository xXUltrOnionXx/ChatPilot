local _, ns = ...

-------------------------------------------------------------------------------
-- Magical Messenger
-- A small summoned bird of light carries every incoming chat message to the chat
-- window it belongs to. Drawn from one texture sheet (wing frames, body, glow, sparks);
-- nothing here can take clicks, and nothing runs while no bird is in the air.
-------------------------------------------------------------------------------
local L = ns.L

local TEX = "Interface\\AddOns\\ChatPilot\\textures\\messenger.tga"
local MAX_BIRDS = 3      -- in the air at the same time
local MAX_SPARKS = 72    -- particle pool size
local BIRD = 46      -- size of the bird body on screen (UI units) at 100 %
local FLAP_FPS = 36
local SEQ = { 1, 3, 5, 7, 8, 6, 4, 2 } -- wing frames: up ... down ... up (about 4.5 beats a second)

-- chat types that can send a bird (same keys as the chat window categories)
ns.MSG_TYPES = { "whisper", "guild", "party", "raid", "say", "yell", "emote", "general", "trade", "channels", "community" }
local TYPE_OK = {}
for _, k in ipairs(ns.MSG_TYPES) do TYPE_OK[k] = true end

-- colours of the magic
local COLOR = {
	whisper = { 0.72, 0.45, 1.00 },  -- arcane violet
	guild = { 0.30, 0.95, 0.55 },    -- emerald nature magic
	party = { 0.40, 0.65, 1.00 },    -- blue
	raid = { 1.00, 0.62, 0.18 },     -- gold-orange
	general = { 1.00, 0.93, 0.70 },  -- white-gold
	trade = { 1.00, 0.82, 0.22 },    -- gold
	community = { 0.55, 0.78, 1.00 },
}

-- sprite sheet: 4 x 4 cells
local CELLS = {
	wing = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } },
	body = { 0, 2 }, orb = { 1, 2 }, star = { 2, 2 }, dot = { 3, 2 }, ring = { 0, 3 }, streak = { 1, 3 },
}
local function Coords(cell, flip)
	local u0, v0 = cell[1] * 0.25, cell[2] * 0.25
	local u1, v1 = u0 + 0.25, v0 + 0.25
	if flip then return u1, u0, v0, v1 end
	return u0, u1, v0, v1
end
local function SetCell(tex, cell, flip)
	tex:SetTexCoord(Coords(cell, flip))
end

local function Num(v, default) return tonumber(v) or default end
local function Clamp(v, a, b) return v < a and a or (v > b and b or v) end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local layer                       -- one frame over the screen (never takes the mouse)
local freeBirds, liveBirds = {}, {}
local freeSparks, liveSparks = {}, {}
local lastAt = -100
local stats = { sent = 0, skipped = 0 }
ns.messengerStats = stats

local function Settings()
	local S = ns.S or {}
	return {
		size = Clamp(Num(S.msgSize, 100), 30, 300) / 100,
		speed = Clamp(Num(S.msgSpeed, 100), 30, 300) / 100,
		alpha = Clamp(Num(S.msgAlpha, 85), 10, 100) / 100,
		particles = Clamp(Num(S.msgParticles, 100), 0, 300) / 100,
	}
end

local function ScreenSize()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	return (w and w > 0) and w or 1920, (h and h > 0) and h or 1080
end

-- centre / top of a frame in screen (UIParent) units
local function FramePoint(f, aboveCentre)
	if not f or not f.GetCenter then return end
	local cx, cy = f:GetCenter()
	if not cx or not cy then return end
	local s = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	if s <= 0 then s = 1 end
	local h = (f:GetHeight() or 0) * s
	if aboveCentre and h > 90 then
		local top = f:GetTop()
		if top then return cx * s, top * s - 22 end
	end
	return cx * s, cy * s
end

-------------------------------------------------------------------------------
-- Sparks (pooled textures)
-------------------------------------------------------------------------------
local function SparkAlloc()
	local sp = table.remove(freeSparks)
	if sp then return sp end
	if #liveSparks >= MAX_SPARKS then return nil end
	local t = layer:CreateTexture(nil, "OVERLAY")
	t:SetTexture(TEX)
	t:SetBlendMode("ADD")
	return { tex = t }
end

local KIND_CELL = { dot = CELLS.dot, star = CELLS.star, ring = CELLS.ring, streak = CELLS.streak }

local function Spark(kind, x, y, vx, vy, life, s0, s1, r, g, b, a0, spin)
	if #liveSparks >= MAX_SPARKS then return end
	local sp = SparkAlloc()
	if not sp then return end
	sp.x, sp.y, sp.vx, sp.vy = x, y, vx, vy
	sp.life, sp.age = life, 0
	sp.s0, sp.s1 = s0, s1
	sp.a0 = a0
	sp.spin, sp.rot = spin or 0, math.random() * 6.28
	sp.tex:SetTexCoord(Coords(KIND_CELL[kind] or CELLS.dot))
	sp.tex:SetVertexColor(r, g, b)
	sp.tex:SetAlpha(0)
	sp.tex:Show()
	liveSparks[#liveSparks + 1] = sp
end

local function UpdateSparks(e, alpha)
	local i = 1
	while i <= #liveSparks do
		local sp = liveSparks[i]
		sp.age = sp.age + e
		if sp.age >= sp.life then
			sp.tex:Hide()
			sp.tex:ClearAllPoints()
			table.remove(liveSparks, i)
			freeSparks[#freeSparks + 1] = sp
		else
			local f = sp.age / sp.life
			sp.x = sp.x + sp.vx * e
			sp.y = sp.y + sp.vy * e
			sp.vy = sp.vy - 16 * e
			local s = sp.s0 + (sp.s1 - sp.s0) * f
			sp.tex:ClearAllPoints()
			sp.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sp.x, sp.y)
			sp.tex:SetSize(s, s)
			if sp.spin ~= 0 then sp.tex:SetRotation(sp.rot + sp.spin * sp.age) end
			sp.tex:SetAlpha(sp.a0 * alpha * (1 - f) ^ 1.3)
			i = i + 1
		end
	end
end

-------------------------------------------------------------------------------
-- Birds (pooled frames)
-------------------------------------------------------------------------------
local function NewBird()
	local b = table.remove(freeBirds)
	if b then return b end
	local f = CreateFrame("Frame", nil, layer)
	f:SetSize(8, 8)
	f:EnableMouse(false)
	b = { frame = f }
	b.halo = f:CreateTexture(nil, "BACKGROUND")
	b.halo:SetTexture(TEX); b.halo:SetBlendMode("ADD"); SetCell(b.halo, CELLS.orb)
	b.wingB = f:CreateTexture(nil, "ARTWORK", nil, 1)
	b.wingB:SetTexture(TEX); b.wingB:SetBlendMode("ADD")
	b.body = f:CreateTexture(nil, "ARTWORK", nil, 2)
	b.body:SetTexture(TEX)
	b.wingF = f:CreateTexture(nil, "ARTWORK", nil, 3)
	b.wingF:SetTexture(TEX); b.wingF:SetBlendMode("ADD")
	return b
end

local function Place(tex, x, y, size, rot)
	tex:ClearAllPoints()
	tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	tex:SetSize(size, size)
	tex:SetRotation(rot)
end

local function Release(b)
	b.frame:Hide()
	for i = #liveBirds, 1, -1 do
		if liveBirds[i] == b then table.remove(liveBirds, i) end
	end
	b.dest = nil
	freeBirds[#freeBirds + 1] = b
end

local function Bezier(b, u, tx, ty)
	local x0, y0 = b.sx, b.sy
	local dx, dy = tx - x0, ty - y0
	local dist = math.sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / (dist + 0.001), dx / (dist + 0.001)
	local cx = x0 + dx * 0.5 + nx * dist * b.arc
	local cy = y0 + dy * 0.5 + ny * dist * b.arc
	local v = 1 - u
	local x = v * v * x0 + 2 * v * u * cx + u * u * tx
	local y = v * v * y0 + 2 * v * u * cy + u * u * ty
	local ddx = 2 * v * (cx - x0) + 2 * u * (tx - cx)
	local ddy = 2 * v * (cy - y0) + 2 * u * (ty - cy)
	return x, y, ddx, ddy, nx, ny
end

local function Ease(t) return 1 - (1 - t) ^ 1.8 end

local function Draw(b, x, y, tilt, face, fade, scale, cfg, wingSpeed)
	local S = BIRD * cfg.size * scale
	local rot = face > 0 and tilt or -tilt
	local cs, sn = math.cos(rot), math.sin(rot)
	-- wing roots sit on the shoulder; a wing sprite is centred on its root
	local ox, oy = -4 / 128 * S * face, 10 / 128 * S
	local rx, ry = ox * cs - oy * sn, ox * sn + oy * cs
	local idx = SEQ[(math.floor(b.phase) % #SEQ) + 1]
	local idxB = SEQ[(math.floor(b.phase + 1.5) % #SEQ) + 1]
	local flip = face < 0
	local a = cfg.alpha * fade
	local r, g, bl = b.r, b.g, b.b
	Place(b.halo, x, y, S * 1.9, 0)
	b.halo:SetVertexColor(r, g, bl)
	b.halo:SetAlpha(a * 0.55)
	SetCell(b.wingB, CELLS.wing[idxB], flip)
	Place(b.wingB, x + rx, y + ry + 2, S * 1.7, rot)
	b.wingB:SetVertexColor(r * 0.8, g * 0.8, bl * 0.8)
	b.wingB:SetAlpha(a * 0.4)
	SetCell(b.body, CELLS.body, flip)
	Place(b.body, x, y, S, rot)
	b.body:SetVertexColor(r * 0.6 + 0.4, g * 0.6 + 0.4, bl * 0.6 + 0.4)
	b.body:SetAlpha(a)
	SetCell(b.wingF, CELLS.wing[idx], flip)
	Place(b.wingF, x + rx, y + ry, S * 1.7, rot)
	b.wingF:SetVertexColor(r, g, bl)
	b.wingF:SetAlpha(a * 0.75)
	-- where the tail ends (for the trail)
	local tx, ty = -52 / 128 * S * face, -10 / 128 * S
	return x + tx * cs - ty * sn, y + tx * sn + ty * cs, S
end

local function Burst(x, y, n, r, g, b, speed, size)
	for _ = 1, n do
		local a = math.random() * 6.283
		local sp = (0.4 + math.random() * 0.8) * speed
		Spark(math.random() < 0.35 and "star" or "dot", x, y, math.cos(a) * sp, math.sin(a) * sp,
			0.5 + math.random() * 0.6, size * (0.5 + math.random() * 0.6), size * 0.15, r, g, b, 0.95, (math.random() - 0.5) * 4)
	end
end

local function UpdateBirds(e, cfg)
	local i = 1
	while i <= #liveBirds do
		local b = liveBirds[i]
		local done = false
		b.age = b.age + e
		b.phase = b.phase + e * FLAP_FPS * (b.state == "fly" and 1 or 0.55)
		-- the window may have moved or been closed meanwhile
		local tx, ty = b.tx, b.ty
		if b.dest and b.dest.IsVisible and b.dest:IsVisible() then
			local px, py = FramePoint(b.dest, b.aboveCentre)
			if px then tx, ty = px, py; b.tx, b.ty = px, py end
		end
		if b.state == "fly" then
			b.t = b.t + e / b.dur
			local t = Clamp(b.t, 0, 1)
			local u = Ease(t)
			local x, y, ddx, ddy, nx, ny = Bezier(b, u, tx, ty)
			-- gentle bobbing across the path, fading out towards the landing
			local bob = math.sin(b.age * 7 + b.seed) * 5 * cfg.size * (1 - t)
			x, y = x + nx * bob, y + ny * bob
			local face = ddx >= 0 and 1 or -1
			local tilt = Clamp(math.atan2(ddy, math.abs(ddx) + 0.001), -0.7, 0.7) * 0.8
			local fade = Clamp(b.age / 0.3, 0, 1)
			local tailX, tailY, S = Draw(b, x, y, tilt, face, fade, 1, cfg)
			-- magical trail
			b.trail = b.trail + e * 46 * cfg.particles
			while b.trail >= 1 do
				b.trail = b.trail - 1
				local kind = math.random() < 0.22 and "star" or "dot"
				Spark(kind, tailX + (math.random() - 0.5) * 6, tailY + (math.random() - 0.5) * 6,
					(math.random() - 0.5) * 16 - face * 10, (math.random() - 0.5) * 16 - 6,
					0.45 + math.random() * 0.5, S * (0.16 + math.random() * 0.16), S * 0.04, b.r, b.g, b.b, 0.85, (math.random() - 0.5) * 3)
			end
			b.x, b.y, b.tilt, b.faceNow = x, y, tilt, face
			if b.t >= 1 then
				b.state = "dissolve"
				b.dt = 0
				Burst(x, y, math.floor(14 * cfg.particles + 0.5), b.r, b.g, b.b, 95 * cfg.size, BIRD * cfg.size * 0.3)
				if cfg.particles > 0 then
					Spark("ring", tx, ty, 0, 0, 0.55, 18 * cfg.size, 96 * cfg.size, b.r, b.g, b.b, 0.8, 0)
				end
			end
		else
			b.dt = b.dt + e
			local k = Clamp(b.dt / 0.55, 0, 1)
			Draw(b, b.x, b.y + 14 * k, b.tilt, b.faceNow, 1 - k, 1 + 0.25 * k, cfg)
			if k >= 1 then done = true end
		end
		if done then
			Release(b)
		else
			i = i + 1
		end
	end
end

local function Tick(_, e)
	if e > 0.05 then e = 0.05 end
	local cfg = Settings()
	UpdateBirds(e, cfg)
	UpdateSparks(e, cfg.alpha)
	if #liveBirds == 0 and #liveSparks == 0 then layer:Hide() end
end

local function EnsureLayer()
	if layer then return end
	layer = CreateFrame("Frame", "ChatPilotMessenger", UIParent)
	layer:SetAllPoints(UIParent)
	layer:SetFrameStrata("TOOLTIP")
	layer:EnableMouse(false)
	layer:SetScript("OnUpdate", Tick)
	layer:Hide()
end

-------------------------------------------------------------------------------
-- Sending a bird
-------------------------------------------------------------------------------
-- dest: the frame to fly to; r, g, b: colour of the magic
function ns:MessengerFly(dest, r, g, b, opts)
	if #liveBirds >= MAX_BIRDS then return false end
	local tx, ty = FramePoint(dest, true)
	if not tx then return false end
	EnsureLayer()
	local cfg = Settings()
	local W, H = ScreenSize()
	-- start: off to the side the window is not on, up in the air
	local dir = tx < W / 2 and 1 or -1
	local sx = Clamp(tx + dir * (320 + math.random() * 240), 50, W - 50)
	local sy = Clamp(ty + 150 + math.random() * 170, 60, H - 60)
	if math.abs(sx - tx) < 140 then sx = Clamp(tx - dir * 220, 50, W - 50) end
	local dist = math.sqrt((tx - sx) ^ 2 + (ty - sy) ^ 2)
	local bd = NewBird()
	bd.dest = dest
	bd.aboveCentre = true
	bd.sx, bd.sy, bd.tx, bd.ty = sx, sy, tx, ty
	bd.arc = (math.random() < 0.5 and -1 or 1) * (0.16 + math.random() * 0.14)
	bd.dur = Clamp(dist / (380 * cfg.speed), 0.9, 3.2)
	bd.t, bd.age, bd.phase, bd.trail, bd.seed = 0, 0, math.random() * 10, 0, math.random() * 6.28
	bd.state = "fly"
	bd.face = 1
	bd.r, bd.g, bd.b = r, g, b
	bd.frame:Show()
	liveBirds[#liveBirds + 1] = bd
	-- summoned out of a little spell flash
	Burst(sx, sy, math.floor(7 * cfg.particles + 0.5), r, g, b, 55 * cfg.size, BIRD * cfg.size * 0.28)
	layer:Show()
	return true
end

-- colour of the magic for a chat message
local function ColorFor(cat, event, ...)
	local c = COLOR[cat]
	if c then return c[1], c[2], c[3] end
	local info
	if event == "CHAT_MSG_CHANNEL" then
		local n = select(8, ...)
		if ns.Usable(n) and n then info = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. tostring(n)] end
	end
	if not info and ChatTypeInfo then info = ChatTypeInfo[event:sub(10)] end
	if info and info.r then return info.r, info.g, info.b end
	return 0.9, 0.8, 0.8
end

local function InCombat()
	return ns.SafeBool(InCombatLockdown and InCombatLockdown(), true) or ns.SafeBool(UnitAffectingCombat and UnitAffectingCombat("player"), true)
end

-- Called for every incoming chat message of the supported types.
-- targets: the chat windows (ChatPilot's own) that take the message, or nil = the game's chat
function ns.MessengerNotify(event, cat, targets, ...)
	local S = ns.S
	if not S or not S.messenger or not TYPE_OK[cat] then return end
	if S["msg_" .. cat] == false then return end
	if S.msgNoCombat ~= false and InCombat() then return end
	local now = GetTime()
	if now - lastAt < Clamp(Num(S.msgCooldown, 2), 0, 30) then stats.skipped = stats.skipped + 1 return end
	if #liveBirds >= MAX_BIRDS then return end

	-- never for something we wrote ourselves; texts under restriction are not looked at
	local author, guid = select(2, ...), select(12, ...)
	if not ns.Usable(author, guid) then return end
	if event:find("_INFORM$") then return end
	if type(guid) == "string" and guid ~= "" and guid == UnitGUID("player") then return end
	if type(author) == "string" and author ~= "" and Ambiguate and Ambiguate(author, "none") == UnitName("player") then return end

	-- where does it go?
	local dest, read
	if targets and #targets > 0 and ns.CW_Destination then
		for _, w in ipairs(targets) do
			local f, rd = ns.CW_Destination(w)
			if f then dest, read = f, rd break end
		end
	end
	if not dest then
		local main = ns.CW_MainChat and ns.CW_MainChat()
		if main and main.IsVisible and main:IsVisible() then
			dest = main
			read = main.AtBottom and main:AtBottom() or false
		end
	end
	if not dest then return end
	if S.msgUnread and read then return end

	local r, g, b = ColorFor(cat, event, ...)
	if ns:MessengerFly(dest, r, g, b) then
		lastAt = now
		stats.sent = stats.sent + 1
	end
end

-- Preview (settings page): two birds in different colours to the chat, ignoring the rules above
function ns:MessengerPreview()
	local dest
	local g = ns._cw and ns._cw.groups and ns._cw.groups[1]
	if g and g.frame and g.frame:IsVisible() then dest = g.frame end
	if not dest then
		local main = ns.CW_MainChat and ns.CW_MainChat()
		if main and main.IsVisible and main:IsVisible() then dest = main end
	end
	dest = dest or UIParent
	local r1, g1, b1 = unpack(COLOR.whisper)
	ns:MessengerFly(dest, r1, g1, b1)
	C_Timer.After(0.6, function()
		local r2, g2, b2 = unpack(COLOR.guild)
		ns:MessengerFly(dest, r2, g2, b2)
	end)
end

function ns:MessengerReset()
	local D = ns.defaults or {}
	for _, k in ipairs({ "messenger", "msgNoCombat", "msgUnread", "msgSize", "msgSpeed", "msgAlpha", "msgParticles", "msgCooldown" }) do
		ns.S[k] = D[k]
	end
	for _, t in ipairs(ns.MSG_TYPES) do ns.S["msg_" .. t] = D["msg_" .. t] end
end

-- for the tests / /chatpilot diag
function ns:MessengerState()
	return #liveBirds, #freeBirds, #liveSparks, #freeSparks, layer and layer:IsShown() or false
end
