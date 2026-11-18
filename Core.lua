local ADDON, ns = ...
local L = ns.L

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(ADDON, "Version")) or "?"
ns.TITLE = "ChatPilot Forever"

ns.defaults = {
	autocomplete = true,
	keepAt = false,
	whisperNames = true,
	raidIcons = true,
	charCounter = true,
	mentions = true,
	highlight = true,
	mentionSound = true,
	mentionFlash = true,
	mentionToast = true,
	mentionPublic = true,
	urls = true,
	copyButton = true,
	notes = true,
	buttonsTop = false,
	buttonBackground = true,
	textSize = 14,
	textBold = false,
	expanded = {},
	whispers = true,
	whisperSummary = true,
	versionCheck = true,
	spamFilter = true,
	keepHistory = true,
	showLevels = true,
	snippets = true,
	abbrevTips = true,
	markForeign = true,
	hideForeign = false,
	hideRepeats = true,
	maxRows = 8,
	keywords = {},
}

-- Chat events we read (only to learn names and detect mentions; nothing is ever sent).
ns.CHAT_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_WHISPER",
}
ns.PUBLIC_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true }

-------------------------------------------------------------------------------
-- Name store
-------------------------------------------------------------------------------
-- Keys are "Name" for your own realm and "Name-Realm" otherwise.
ns.live = {}          -- refreshed from group / guild / friends / communities
local liveStamp, liveDirty = 0, true
local clubStamp, clubCache = 0, {}

function ns.Normalize(name, realm)
	if type(name) ~= "string" or name == "" or not ns.Usable(name) then return nil end
	if realm and realm ~= "" and not name:find("-", 1, true) then
		name = name .. "-" .. (realm:gsub("[%s%-]", ""))
	end
	return Ambiguate(name, "none")
end

local function ClassFromGUID(guid)
	if type(guid) ~= "string" or guid == "" or not ns.Usable(guid) then return nil end
	local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
	if ok then return classFile end
end

local function ClassFromID(classID)
	if not classID or not C_CreatureInfo or not C_CreatureInfo.GetClassInfo then return nil end
	local info = C_CreatureInfo.GetClassInfo(classID)
	return info and info.classFile
end

function ns:RecordSpeaker(author, guid)
	local key = ns.Normalize(author)
	if not key or key == ns.playerKey then return end
	local names = self.db.names
	local entry = names[key]
	if not entry then
		entry = {}
		names[key] = entry
	end
	entry.t = time()
	entry.c = ClassFromGUID(guid) or entry.c
end

local function AddLive(t, key, classFile, src)
	if not key or key == ns.playerKey then return end
	local e = t[key]
	if not e then
		e = { src = {} }
		t[key] = e
	end
	e.c = e.c or classFile
	e.src[src] = true
end

local function RefreshClubs()
	wipe(clubCache)
	if not C_Club or not C_Club.GetSubscribedClubs then return end
	local charType = Enum and Enum.ClubType and Enum.ClubType.Character or 1
	local offline = Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline
	for _, club in ipairs(C_Club.GetSubscribedClubs() or {}) do
		if club.clubType == charType then
			for _, memberId in ipairs(C_Club.GetClubMembers(club.clubId) or {}) do
				local m = C_Club.GetMemberInfo(club.clubId, memberId)
				if m and m.name and not m.isSelf and (offline == nil or m.presence ~= offline) then
					clubCache[#clubCache + 1] = { key = ns.Normalize(m.name), c = ClassFromID(m.classID) }
				end
			end
		end
	end
end

function ns:RefreshLive(force)
	local now = GetTime()
	if not force and not liveDirty and now - liveStamp < 20 then return end
	liveStamp, liveDirty = now, false
	local t = {}

	-- group / raid
	pcall(function()
		local n = GetNumGroupMembers()
		local prefix = IsInRaid() and "raid" or "party"
		for i = 1, n do
			local unit = prefix .. i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") then
				local name, realm = UnitName(unit)
				local _, classFile = UnitClass(unit)
				AddLive(t, ns.Normalize(name, realm), classFile, "group")
			end
		end
	end)

	-- target
	pcall(function()
		if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
			local name, realm = UnitName("target")
			local _, classFile = UnitClass("target")
			AddLive(t, ns.Normalize(name, realm), classFile, "target")
		end
	end)

	-- guild (online only)
	pcall(function()
		if IsInGuild() then
			for i = 1, GetNumGuildMembers() do
				local name, _, _, _, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
				if online then AddLive(t, ns.Normalize(name), classFile, "guild") end
			end
		end
	end)

	-- friends (online only)
	pcall(function()
		for i = 1, C_FriendList.GetNumFriends() do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info and info.connected then AddLive(t, ns.Normalize(info.name), nil, "friend") end
		end
	end)
	pcall(function()
		for i = 1, BNGetNumFriends() do
			local acc = C_BattleNet.GetFriendAccountInfo(i)
			local g = acc and acc.gameAccountInfo
			if g and g.isOnline and g.characterName and g.characterName ~= "" then
				AddLive(t, ns.Normalize(g.characterName, g.realmName), nil, "friend")
			end
		end
	end)

	-- communities (online members, refreshed less often)
	if force or now - clubStamp > 60 then
		clubStamp = now
		pcall(RefreshClubs)
	end
	for _, m in ipairs(clubCache) do AddLive(t, m.key, m.c, "community") end

	self.live = t
end

local SRC_SCORE = { group = 400, target = 350, friend = 150, guild = 120, community = 80 }
local SRC_ORDER = { "group", "target", "chat", "friend", "guild", "community" }

-- Returns sorted suggestion entries matching `partial`.
function ns:GetCandidates(partial, maxCount)
	self:RefreshLive()
	local p = (partial or ""):lower()
	local now = time()
	local merged = {}

	local function Consider(key, classFile, src, chatTime)
		local short = Ambiguate(key, "short")
		local lower = short:lower()
		local s = (p == "") and 1 or lower:find(p, 1, true)
		if not s then
			-- also allow matching against the realm part
			if p ~= "" and key:lower():find(p, 1, true) then s = 99 else return end
		end
		local e = merged[key]
		if not e then
			e = { key = key, short = short, src = {}, score = (s == 1) and 1000 or 0 }
			merged[key] = e
		end
		e.c = e.c or classFile
		if src then
			for name in pairs(src) do
				if not e.src[name] then
					e.src[name] = true
					e.score = e.score + (SRC_SCORE[name] or 0)
				end
			end
		end
		if chatTime and not e.src.chat then
			e.src.chat = true
			e.score = e.score + math.max(10, 300 - (now - chatTime) / 4)
		end
	end

	for key, e in pairs(self.live) do Consider(key, e.c, e.src) end
	for key, e in pairs(self.db.names) do Consider(key, e.c, nil, e.t) end

	local list = {}
	for _, e in pairs(merged) do
		for _, name in ipairs(SRC_ORDER) do
			if e.src[name] then e.tag = name break end
		end
		list[#list + 1] = e
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.short < b.short
	end)
	for i = #list, (maxCount or 8) + 1, -1 do list[i] = nil end
	return list
end

-------------------------------------------------------------------------------
-- Keywords for mention detection
-------------------------------------------------------------------------------
ns.words = {}
function ns:RebuildWords()
	wipe(self.words)
	local seen = {}
	local function add(w)
		w = w and strtrim(w):lower()
		if w and w ~= "" and not seen[w] then
			seen[w] = true
			self.words[#self.words + 1] = w
		end
	end
	add(self.playerName)
	for _, w in ipairs(self.S.keywords) do add(w) end
end

-- Returns start, end of the first keyword in msg (plain text only), or nil.
function ns:FindMention(msg)
	local lower = msg:lower()
	local bs, be
	for _, w in ipairs(self.words) do
		local s, e = ns.FindWord(lower, w)
		if s and (not bs or s < bs) then bs, be = s, e end
	end
	return bs, be
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
ns.chatListeners = {}
function ns:OnChat(fn) self.chatListeners[#self.chatListeners + 1] = fn end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == ADDON then
			ChatPilotDB = ChatPilotDB or {}
			local db = ChatPilotDB
			db.settings = db.settings or {}
			db.names = db.names or {}
			db.mentions = db.mentions or {}
			db.feedback = db.feedback or {}
			db.whispers = db.whispers or {}
			db.snippets = db.snippets or {}
			db.history = db.history or {}
			db.levels = db.levels or {}
			db.notes = db.notes or {}
			CopyDefaults(ns.defaults, db.settings)
			ns.db, ns.S = db, db.settings

			-- forget chat names older than 3 days, keep at most 400
			local cutoff, list = time() - 3 * 86400, {}
			for k, e in pairs(db.names) do
				if type(e) ~= "table" or not e.t or e.t < cutoff then db.names[k] = nil else list[#list + 1] = k end
			end
			if #list > 400 then
				table.sort(list, function(a, b) return db.names[a].t > db.names[b].t end)
				for i = 401, #list do db.names[list[i]] = nil end
			end
		end
		if ns.OnAddonLoaded then ns:OnAddonLoaded(name) end

	elseif event == "PLAYER_LOGIN" then
		ns.playerName = UnitName("player")
		ns.playerKey = ns.Normalize(ns.playerName)
		ns:RebuildWords()
		ns.ScanChatFrames()
		for _, ev in ipairs(ns.CHAT_EVENTS) do f:RegisterEvent(ev) end
		f:RegisterEvent("GROUP_ROSTER_UPDATE")
		f:RegisterEvent("GUILD_ROSTER_UPDATE")
		f:RegisterEvent("FRIENDLIST_UPDATE")
		f:RegisterEvent("BN_FRIEND_INFO_CHANGED")
		f:RegisterEvent("PLAYER_TARGET_CHANGED")
		if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
		if ns.OnLogin then ns:OnLogin() end
		ns.Print(L.LOADED, ns.version)

	elseif event:sub(1, 9) == "CHAT_MSG_" then
		local msg, author = ...
		if not ns.Usable(msg, author) or type(msg) ~= "string" then return end
		local channelName, guid = (select(4, ...)), (select(12, ...))
		if type(author) == "string" and author ~= "" then ns:RecordSpeaker(author, guid) end
		for _, fn in ipairs(ns.chatListeners) do
			pcall(fn, event, msg, author, channelName, guid)
		end

	else
		liveDirty = true
	end
end)
