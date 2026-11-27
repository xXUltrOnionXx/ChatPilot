local _, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Online time at the end of a name (guild and friends).
--   +5m   just logged in, 5 minutes ago (green)
--   R5m   logged out and back in (relog), 5 minutes ago (orange)
--   >2h   was already online before you logged in, at least that long (blue)
-- Answers "did this person already say hello earlier?". Display only: the
-- game's own guild roster and "has come online" messages are all it uses.
-------------------------------------------------------------------------------
local state = {}      -- key -> { since = time, kind = "fresh"|"relog"|"before" }
local offlineAt = {}  -- key -> time the person went offline
local baselined = { guild = false, friends = false }
local loginTime = time()
local RELOG_WINDOW = 15 * 60

local function On() return ns.S ~= nil and ns.S.presenceTag ~= false end

local function Key(name)
	if type(name) ~= "string" or name == "" then return nil end
	local k = ns.Normalize and ns.Normalize(name) or name
	if not k then return nil end
	k = k:gsub("%s+", "-"):lower() -- "First Last" and "First-Last" are the same person
	local me = ns.playerKey and ns.playerKey:gsub("%s+", "-"):lower()
	if k == me then return nil end
	return k
end

local function GoOnline(key, baseline)
	if state[key] then return end
	if baseline then
		state[key] = { since = loginTime, kind = "before" }
		return
	end
	local off = offlineAt[key]
	offlineAt[key] = nil
	if off and time() - off <= RELOG_WINDOW then
		state[key] = { since = time(), kind = "relog" }
	else
		state[key] = { since = time(), kind = "fresh" }
	end
end

local function GoOffline(key)
	if state[key] then offlineAt[key] = time() end
	state[key] = nil
end

-- the whole list: who is online now (and who is not any more)
local function Sync(group, onlineSet)
	local first = not baselined[group]
	baselined[group] = true
	for key in pairs(onlineSet) do GoOnline(key, first) end
	for key in pairs(state) do
		if onlineSet[key] == nil and state[key].group == group then GoOffline(key) end
	end
	for key in pairs(onlineSet) do if state[key] then state[key].group = group end end
end

local function ScanGuild()
	if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
	local n = GetNumGuildMembers() or 0
	if n == 0 then return end
	local set = {}
	for i = 1, n do
		local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
		local key = online and Key(name)
		if key then set[key] = true end
	end
	Sync("guild", set)
end

local function ScanFriends()
	if not (C_FriendList and C_FriendList.GetNumFriends) then return end
	local set = {}
	for i = 1, C_FriendList.GetNumFriends() do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		local key = info and info.connected and Key(info.name)
		if key then set[key] = true end
	end
	Sync("friends", set)
end

-- "X has come online." / "X has gone offline." arrive at once, between two list updates
local patterns
local function Parse(msg)
	if not patterns then
		patterns = {}
		local function mk(fmt, online)
			if type(fmt) ~= "string" then return end
			local pat = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.-)")
			patterns[#patterns + 1] = { "^" .. pat .. "$", online }
		end
		mk(_G.ERR_FRIEND_ONLINE_SS, true)
		mk(_G.ERR_FRIEND_OFFLINE_S, false)
	end
	for _, p in ipairs(patterns) do
		local a = msg:match(p[1])
		if a and a ~= "" then return (a:match("^([^:|]+)")), p[2] end
	end
end

local lastAsk = 0
local function AskLists()
	if GetTime() - lastAsk < 25 then return end
	lastAsk = GetTime()
	if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
	if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
end

local function Fmt(sec)
	local m = math.floor(sec / 60)
	if m < 1 then return "<1m" end
	if m < 60 then return m .. "m" end
	return ("%dh%02d"):format(math.floor(m / 60), m % 60)
end

local COLORS = { fresh = "ff4ade80", relog = "ffffa94d", before = "ff7ab8ff" }
local MARK = { fresh = "+", relog = "R", before = ">" }

-- what the name in the chat line gets at its end (nil = nothing)
function ns.PresenceTag(name)
	if not On() then return nil end
	local key = Key(name)
	local e = key and state[key]
	if not e then return nil end
	return "|c" .. COLORS[e.kind] .. MARK[e.kind] .. Fmt(time() - e.since) .. "|r"
end

-- sentence for the name tooltip
function ns.PresenceText(name)
	if not On() then return nil end
	local key = Key(name)
	local e = key and state[key]
	if not e then return nil end
	local fmt = e.kind == "relog" and L.PR_RELOG or e.kind == "before" and L.PR_BEFORE or L.PR_FRESH
	return fmt:format(Fmt(time() - e.since)), e.kind
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "CHAT_MSG_SYSTEM" }) do
	ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, msg)
	if not ns.db or not On() then return end
	pcall(function()
		if event == "PLAYER_LOGIN" then
			loginTime = time()
			AskLists()
		elseif event == "GUILD_ROSTER_UPDATE" then ScanGuild()
		elseif event == "FRIENDLIST_UPDATE" then ScanFriends()
		elseif event == "CHAT_MSG_SYSTEM" and type(msg) == "string" and ns.Usable(msg) then
			local name, online = Parse(msg)
			local key = name and Key(name)
			if key then
				if online then GoOnline(key, false) else GoOffline(key) end
			end
		end
	end)
end)

-- keep the lists fresh once in a while (cheap, and the game allows it)
local acc = 0
ev:SetScript("OnUpdate", function(_, el)
	acc = acc + (el or 0)
	if acc < 60 then return end
	acc = 0
	if On() then AskLists() end
end)

ns._presence = { state = state, offlineAt = offlineAt, scanGuild = ScanGuild, scanFriends = ScanFriends, parse = Parse, onEvent = function(...) return ev:GetScript("OnEvent")(ev, ...) end }
