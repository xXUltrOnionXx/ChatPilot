local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- The game's own chat in the same tidy look as ChatPilot's windows:
--   (o) Name  21:17 · Trade
--       message text
-- Only while "Modern chat window" is on. With the game's normal design, ChatPilot
-- leaves the chat exactly as Blizzard writes it.

-- "Modern chat window" on: ChatPilot may change how the normal chat looks
-- (levels, short names, short channel names, links). Off = the game's design.
function ns.MainChatModern()
	local S = ns.S
	return (S and S.chatSkin and not ns.skinConflict) and true or false
end

-- ... and the two-line message blocks on top of that
function ns.MainLookActive()
	return ns.MainChatModern() and ns.S.chatStyle ~= false
end

-- Chat filters run right before the game writes a line into a chat window. We only
-- note who wrote it (nothing is changed or blocked here); the line itself is then
-- rebuilt in that window's AddMessage.
local EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_SYSTEM", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
}

local function Note(frame, event, ...)
	if type(frame) ~= "table" then return false end
	frame.cpHint = nil
	local msg, author = ...
	local chanString, chanNum, chanBase, guid = select(4, ...), select(8, ...), select(9, ...), select(12, ...)
	if not ns.Usable(msg, author, chanString, chanNum, chanBase, guid) then return false end
	frame.cpHint = {
		event = event, msg = msg, author = author, chan = chanString,
		chanNum = chanNum, chanBase = chanBase, guid = guid, t = GetTime(), time = time(),
	}
	-- the message as the player wrote it (before ChatPilot's links/highlights)
	local raw = rawget(frame, "cpRaw")
	if raw and raw.new == msg then frame.cpHint.raw = raw.orig end
	frame.cpRaw = nil
	return false
end

local AddFilter = ChatFrame_AddMessageEventFilter
	or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)

-- ChatPilot only hooks into the game's chat windows once the modern chat look
-- is wanted. With the game's normal design it stays completely out of them.
function ns:InstallMainChatHooks()
	if ns.mainHooks or not ns.MainChatModern() then return end
	ns.mainHooks = true
	if AddFilter then
		for _, ev in ipairs(EVENTS) do AddFilter(ev, Note) end
	end
	-- Register only when enabled. OnChatFrame immediately visits already-seen
	-- frames as well as future ones; rescanning alone skips the login frames.
	ns.OnChatFrame(function(frame)
		ns.InstallMainChatFrame(frame)
		ns.DecorateMessages(frame, ns.MainLookActive)
	end)
	if ns.ScanChatFrames then ns.ScanChatFrames() end
end

local prevLogin = ns.OnLogin
function ns:OnLogin()
	if prevLogin then prevLogin(self) end
	if ns.MainChatModern() then self:InstallMainChatHooks() end
end

local SOFT = {
	SYSTEM = { 0.62, 0.67, 0.74 },     -- online/offline and other notices: quiet grey
	EMOTE = { 0.86, 0.72, 0.55 }, TEXT_EMOTE = { 0.86, 0.72, 0.55 },
}

-- Rebuilds one line. Returns true when it wrote the line itself.
function ns.StyleMainLine(frame, text, orig, r, g, b, ...)
	local h = rawget(frame, "cpHint")
	frame.cpHint = nil
	local look = ns.ChatLook
	if not h or not look or h.t ~= GetTime() then return false end

	local soft = SOFT[h.event:sub(10)]
	if soft then
		-- notices and emotes: one calm line between the message blocks
		frame.cpLastKey = nil
		orig(frame, text, soft[1], soft[2], soft[3], ...)
		return true
	end

	-- the first player link is the author (for "To X:" the person you wrote to)
	local s, e = text:find("|HB?N?player:[^|]*|h.-|h")
	if not s then return false end
	local link = text:sub(s, e)
	local prefix, rest = text:sub(1, s - 1), text:sub(e + 1)
	local colon = rest:find(":%s")
	if not colon or colon > 60 then return false end
	local body = rest:sub(colon + 2)

	local chatType = h.event:sub(10)
	local inform = chatType:find("_INFORM$") and true or false
	local me = UnitName and UnitName("player")
	local isOwn = inform or (me and Ambiguate and h.author and Ambiguate(h.author, "none") == me) or false
	local mentioned = not isOwn and ns.FindMention and ns:FindMention(h.msg)
	local calm = look.CALM[chatType] or { r or 1, g or 1, b or 1 }
	local you = UI.Hex(C.accent) .. L.WH_YOU .. "|r"
	local class
	if not isOwn and type(h.guid) == "string" and h.guid ~= "" and GetPlayerInfoByGUID then
		local okc, _, cf = pcall(GetPlayerInfoByGUID, h.guid)
		if okc then class = cf end
	end

	-- who: the name as the game links it (class colour, right-click menu), "You" for yourself
	local who, label = look.PlainName(link), nil
	if inform then
		who = you
		label = L.CW_TO:format(look.PlainName(link))
	elseif isOwn then
		local open = link:match("^(|H.-|h)")
		who = open and (open .. you .. "|h") or you
	end
	if not label then
		-- keep the game's channel link (clickable), just without the brackets
		local co, cin, cc = prefix:match("(|Hchannel:[^|]+|h)%[(.-)%](|h)")
		if co then
			local sh = look.ShortChannel(cin)
			label = co .. (sh ~= "" and sh or cin) .. cc
		else
			label = look.ChannelLabel(chatType, h.chanNum, h.chanBase or "", h.chan, h.author)
		end
	end

	local now = h.time or time()
	local lastT, lastKey = rawget(frame, "cpLastT"), rawget(frame, "cpLastKey")
	local key = tostring(h.author) .. "|" .. chatType .. "|" .. tostring(h.chanNum or "")
	if lastT and now - lastT > 900 then
		orig(frame, UI.Hex(C.muted) .. "—  " .. date("%H:%M", now) .. "  —|r", 1, 1, 1)
		lastKey = nil
	end
	if not (lastKey == key and lastT and now - lastT <= 120) then
		local stripe = look.StripeColor(isOwn, mentioned, class, calm)
		local head = look.HeadMark(stripe) .. who .. "  " .. UI.Hex(C.muted) .. date("%H:%M", now)
			.. (label and (" · " .. label) or "") .. "|r"
		orig(frame, head, 1, 1, 1, ...)
	end
	frame.cpLastKey, frame.cpLastT = key, now
	local c = mentioned and C.orange or calm
	orig(frame, look.BODY .. body, c[1], c[2], c[3], ...)
	return true
end

-------------------------------------------------------------------------------
-- Message blocks: a soft background and a coloured stripe on the left for every
-- header + text block. Drawn after the game has laid out the visible lines
-- (secure hook: the chat itself is never changed by this).
-------------------------------------------------------------------------------
local GAP = 5 -- space between two blocks

local function Block(frame, deco, k)
	local b = deco.pool[k]
	if not b then
		b = { bg = frame:CreateTexture(nil, "BORDER"), bar = frame:CreateTexture(nil, "ARTWORK") }
		b.bg:SetColorTexture(1, 1, 1, 1)
		b.bar:SetColorTexture(1, 1, 1, 1)
		b.bar:SetWidth(2)
		deco.pool[k] = b
	end
	return b
end

-- only the part of a block that is inside the chat area (the game keeps lines
-- ready above the visible area; those must not get a block)
local function Inside(frame, top, bottom)
	local ft, fb = frame:GetTop(), frame:GetBottom()
	local tt, bb = top:GetTop(), bottom:GetBottom()
	if not (ft and fb and tt and bb) then return true, false, false end
	if bb >= ft - 1 or tt <= fb + 1 then return false end
	return true, tt > ft, bb < fb
end

local function Place(frame, deco, k, top, bottom, r, g, bl)
	local ok, clipTop, clipBottom = Inside(frame, top, bottom)
	if not ok then return false end
	local b = Block(frame, deco, k)
	b.top = top
	b.bg:ClearAllPoints()
	if clipTop then b.bg:SetPoint("TOP", frame, "TOP", 0, 0) else b.bg:SetPoint("TOP", top, "TOP", 0, 1) end
	if clipBottom then b.bg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0) else b.bg:SetPoint("BOTTOM", bottom, "BOTTOM", 0, 0) end
	b.bg:SetPoint("LEFT", frame, "LEFT", -6, 0)
	b.bg:SetPoint("RIGHT", frame, "RIGHT", 2, 0)
	b.bar:ClearAllPoints()
	b.bar:SetPoint("TOPLEFT", b.bg, "TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT", b.bg, "BOTTOMLEFT")
	b.bar:SetVertexColor(r, g, bl)
	b.r, b.g, b.b = r, g, bl
	b.bg:SetVertexColor(1, 1, 1)
	b.bg:Show(); b.bar:Show()
	return true
end

local function Fade(deco)
	-- follow the game's line fading, so no empty boxes stay behind
	for k = 1, deco.used do
		local b = deco.pool[k]
		local a = b.top and b.top.GetAlpha and b.top:GetAlpha() or 1
		if b.top and b.top.IsShown and not b.top:IsShown() then a = 0 end
		b.bg:SetAlpha(0.055 * a)
		b.bar:SetAlpha(0.9 * a)
	end
end

local function Redraw(frame)
	local deco = rawget(frame, "cpDeco")
	if not deco then return end
	local lines = rawget(frame, "visibleLines")
	local n = 0
	if deco.active() and type(lines) == "table" then
		local bottom, top -- lowest and highest text line of the block being collected
		for i = 1, #lines do -- 1 = newest line at the bottom
			local fs = lines[i]
			local info = fs and fs:IsShown() and rawget(fs, "messageInfo")
			local msg = type(info) == "table" and info.message
			local kind, hr, hg, hb
			if type(msg) == "string" and not ns.IsSecret(msg) then
				if msg:sub(1, 4) == "|r|r" then
					kind = "body"
				else
					hr, hg, hb = msg:match("^|cff(%x%x)(%x%x)(%x%x)|r|r")
					if hr then kind = "head" end
				end
			end
			if kind == "body" then
				bottom = bottom or fs
				top = fs
			elseif kind == "head" then
				if Place(frame, deco, n + 1, fs, bottom or fs, tonumber(hr, 16) / 255, tonumber(hg, 16) / 255, tonumber(hb, 16) / 255) then n = n + 1 end
				bottom, top = nil, nil
			elseif bottom then
				-- text lines whose header is not on screen
				if Place(frame, deco, n + 1, top, bottom, C.muted[1], C.muted[2], C.muted[3]) then n = n + 1 end
				bottom, top = nil, nil
			end
		end
		if bottom and Place(frame, deco, n + 1, top, bottom, C.muted[1], C.muted[2], C.muted[3]) then n = n + 1 end
	end
	for k = n + 1, #deco.pool do deco.pool[k].bg:Hide(); deco.pool[k].bar:Hide(); deco.pool[k].top = nil end
	deco.used = n
	Fade(deco)
	-- a little room between blocks, and wrapped lines flush with the first one
	-- (no indent), while the look is on; put back exactly as it was otherwise
	local on = deco.active()
	if frame.SetSpacing and frame.GetSpacing then
		if on then
			if not deco.spacing then deco.spacing = frame:GetSpacing() or 0 end
			if (frame:GetSpacing() or 0) < GAP then frame:SetSpacing(GAP) end
		elseif deco.spacing then
			frame:SetSpacing(deco.spacing)
			deco.spacing = nil
		end
	end
	if frame.SetIndentedWordWrap and frame.GetIndentedWordWrap then
		if on then
			if deco.indent == nil then deco.indent = frame:GetIndentedWordWrap() and true or false end
			if frame:GetIndentedWordWrap() then frame:SetIndentedWordWrap(false) end
		elseif deco.indent ~= nil then
			frame:SetIndentedWordWrap(deco.indent)
			deco.indent = nil
		end
	end
end

function ns.DecorateMessages(frame, active)
	if not frame or rawget(frame, "cpDeco") or not frame.RefreshDisplay then return end
	local deco = { pool = {}, used = 0, active = active }
	frame.cpDeco = deco
	hooksecurefunc(frame, "RefreshDisplay", function(self) pcall(Redraw, self) end)
	if frame.HookScript then
		local acc = 0
		frame:HookScript("OnUpdate", function(self, elapsed)
			acc = acc + (elapsed or 0)
			if acc < 0.15 then return end
			acc = 0
			-- re-align now and then: the game may move lines after drawing them
			if deco.used > 0 or deco.active() or deco.spacing or deco.indent ~= nil then pcall(Redraw, self) end
		end)
	end
end

-------------------------------------------------------------------------------
-- Emptying chats (memory): the game's chat windows and what ChatPilot saved
-------------------------------------------------------------------------------
local function ChatFrames()
	local list = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if i ~= 2 and f and f.Clear then list[#list + 1] = f end -- 2 = combat log
	end
	return list
end

function ns:ClearMainChat(frame)
	local frames = frame and { frame } or ChatFrames()
	for _, f in ipairs(frames) do
		pcall(f.Clear, f)
		f.cpLastKey, f.cpLastT, f.cpLog = nil, nil, nil
	end
	-- the copy kept for after a reload (for all your characters when everything is emptied)
	local db = self.db and self.db.history
	if not db then return end
	if frame then
		local h = self.playerKey and db[self.playerKey]
		local id = frame.GetID and frame:GetID()
		if h and h.frames and id then h.frames[id] = nil end
	else
		wipe(db)
	end
end

function ns:SavedChatLines()
	local n = 0
	if self.db and self.db.history then
		for _, h in pairs(self.db.history) do
			for _, lines in pairs(h.frames or {}) do n = n + #lines end
		end
	end
	return n
end

function ns:ClearMentionLog()
	if self.db and self.db.mentions then wipe(self.db.mentions) end
	self.unread = 0
	if self.mentionsFrame and self.mentionsFrame:IsShown() and self.FillMentions then self:FillMentions() end
	if self.UpdateChatButtons then self:UpdateChatButtons() end
end

function ns:ClearEverything()
	self:ClearMainChat()
	if self.db and self.db.history then wipe(self.db.history) end
	if self.CW_ClearAll then self:CW_ClearAll() end
	self:ClearWhisperLog()
	self:ClearMentionLog()
end

-------------------------------------------------------------------------------
-- Empty chosen chats automatically when you log out (not on /reload)
-------------------------------------------------------------------------------
if type(ReloadUI) == "function" then hooksecurefunc("ReloadUI", function() ns.reloading = true end) end
if C_UI and type(C_UI.Reload) == "function" then hooksecurefunc(C_UI, "Reload", function() ns.reloading = true end) end

function ns:AutoClear()
	local S = self.S
	if not S then return {} end
	S.autoClear = S.autoClear or {}
	local a = S.autoClear
	a.main = a.main or {}
	a.win = a.win or {}
	return a
end

-- the game's chat tabs that are in use (combat log left out)
function ns:MainTabs()
	local list = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		if i ~= 2 and _G["ChatFrame" .. i] then
			local name, shown, docked
			if GetChatWindowInfo then
				local n, _, _, _, _, _, sh, _, dk = GetChatWindowInfo(i)
				name, shown, docked = n, sh, dk
			end
			if (name and name ~= "" and (shown or docked)) or i == 1 then
				list[#list + 1] = { id = i, name = (name and name ~= "") and name or ("Chat " .. i) }
			end
		end
	end
	return list
end

function ns:AutoClearOnLogout()
	if self.reloading then return end
	local a = self.S and self.S.autoClear
	if not a then return end
	local h = self.db and self.db.history and self.playerKey and self.db.history[self.playerKey]
	for id, on in pairs(a.main or {}) do
		if on and h and h.frames then h.frames[id] = nil end
	end
	for id, on in pairs(a.win or {}) do
		if on and self.CW_ClearById then pcall(self.CW_ClearById, self, id) end
	end
	if a.whispers and self.ClearWhisperLog then pcall(self.ClearWhisperLog, self) end
	if a.mentions and self.db and self.db.mentions then wipe(self.db.mentions) end
end
