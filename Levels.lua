local _, ns = ...

-- Shows the player's level in front of names in chat, e.g. [18:Arthas].
-- Levels are only known for players the game has told us about: your group,
-- target, mouseover, nameplates, guild, friends and /who results.

local MAX_AGE, MAX_ENTRIES = 14 * 86400, 3000

local function Store() return ns.db.levels end

local shortIndex = {} -- first name -> { [fullKey] = true }

local function IndexShort(key)
	local short = Ambiguate(key, "short"):lower()
	shortIndex[short] = shortIndex[short] or {}
	shortIndex[short][key] = true
end

local function Set(name, realm, level)
	if type(level) ~= "number" or level <= 0 then return end
	local key = ns.Normalize(name, realm)
	if key then
		Store()[key] = { l = level, t = time() }
		IndexShort(key)
	end
end

local function FromUnit(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	local name, realm = UnitName(unit)
	local level = UnitLevel(unit)
	if ns.Usable(name, realm, level) then Set(name, realm, level) end
end

-- Ask the game directly (friends list, group) for a player we don't know yet.
local function LiveLevel(key)
	local short = Ambiguate(key, "short")
	if C_FriendList and C_FriendList.GetFriendInfo then
		for _, n in ipairs({ key, short }) do
			local ok, info = pcall(C_FriendList.GetFriendInfo, n)
			if ok and type(info) == "table" and type(info.level) == "number" and info.level > 0 then
				return info.level
			end
		end
	end
	for _, n in ipairs({ key, short }) do
		if UnitExists(n) and UnitIsPlayer(n) then
			local lv = UnitLevel(n)
			if ns.Usable(lv) and type(lv) == "number" and lv > 0 then return lv end
		end
	end
end

function ns:LevelOf(key)
	if not key then return nil end
	local e = Store()[key]
	if e then return e.l end
	local live = LiveLevel(key)
	if live then Store()[key] = { l = live, t = time() }; IndexShort(key); return live end
	-- different name format (e.g. with/without surname): use the first name if it is unique
	local keys = shortIndex[Ambiguate(key, "short"):lower()]
	if keys then
		local only
		for k in pairs(keys) do
			if only then return nil end
			only = k
		end
		local o = only and Store()[only]
		return o and o.l
	end
end

local function ScanGroup()
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	local prefix = IsInRaid and IsInRaid() and "raid" or "party"
	for i = 1, n do FromUnit(prefix .. i) end
end

local function ScanGuild()
	if not IsInGuild or not IsInGuild() then return end
	for i = 1, GetNumGuildMembers() do
		local name, _, _, level = GetGuildRosterInfo(i)
		if name then Set(name, nil, level) end
	end
end

local function ScanFriends()
	if not C_FriendList then return end
	for i = 1, C_FriendList.GetNumFriends() do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		if info and info.name then Set(info.name, nil, info.level) end
	end
end

local function ScanWho()
	if not C_FriendList or not C_FriendList.GetNumWhoResults then return end
	for i = 1, C_FriendList.GetNumWhoResults() do
		local info = C_FriendList.GetWhoInfo(i)
		if info and info.fullName then Set(info.fullName, nil, info.level) end
	end
end

local lastRoster = 0
local function RequestGuildRoster()
	if GetTime() - lastRoster < 10 then return end
	lastRoster = GetTime()
	if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
	if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
end
ns.RequestLevelRefresh = RequestGuildRoster

local function Prune()
	local cutoff, list = time() - MAX_AGE, {}
	for k, e in pairs(Store()) do
		if type(e) ~= "table" or (e.t or 0) < cutoff then Store()[k] = nil else list[#list + 1] = k end
	end
	if #list > MAX_ENTRIES then
		table.sort(list, function(a, b) return Store()[a].t > Store()[b].t end)
		for i = MAX_ENTRIES + 1, #list do Store()[list[i]] = nil end
	end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
	"NAME_PLATE_UNIT_ADDED", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "WHO_LIST_UPDATE", "UNIT_LEVEL" }) do
	ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, unit)
	if not ns.db then return end
	local ok = pcall(function()
		if event == "PLAYER_LOGIN" then
			Prune()
			for k in pairs(Store()) do IndexShort(k) end
			ScanGroup(); ScanGuild(); ScanFriends()
		elseif event == "GROUP_ROSTER_UPDATE" then ScanGroup()
		elseif event == "PLAYER_TARGET_CHANGED" then FromUnit("target")
		elseif event == "UPDATE_MOUSEOVER_UNIT" then FromUnit("mouseover")
		elseif event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_LEVEL" then
			if type(unit) == "string" then FromUnit(unit) end
		elseif event == "GUILD_ROSTER_UPDATE" then ScanGuild()
		elseif event == "FRIENDLIST_UPDATE" then ScanFriends()
		elseif event == "WHO_LIST_UPDATE" then ScanWho()
		end
	end)
	return ok
end)

-------------------------------------------------------------------------------
-- Display: rewrite "[Name]" in player links to "[18:Name]"
-------------------------------------------------------------------------------
local function LevelColor(level)
	if GetQuestDifficultyColor then
		local ok, c = pcall(GetQuestDifficultyColor, level)
		if ok and type(c) == "table" and c.r then
			return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
		end
	end
	return "|cffb0b0b0"
end

-------------------------------------------------------------------------------
-- Player info for the mouse-over card: level, class and how you know them
-------------------------------------------------------------------------------
function ns:PlayerInfo(name)
	local key = ns.Normalize(name)
	if not key then return nil end
	local live = ns.live and ns.live[key]
	local saved = ns.db and ns.db.names and ns.db.names[key]
	local info = {
		key = key,
		level = ns:LevelOf(key),
		class = (live and live.c) or (type(saved) == "table" and saved.c) or nil,
		src = live and live.src or {},
	}
	return info
end

function ns.LevelColor(level) return LevelColor(level) end

local function BNetLevel(data)
	local id = tonumber(data:match("|k:(%d+)") or data:match("^[^:]*:(%d+)"))
	if not id or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then return nil end
	local ok, acc = pcall(C_BattleNet.GetAccountInfoByID, id)
	local g = ok and acc and acc.gameAccountInfo
	local lv = g and g.characterLevel
	if type(lv) == "number" and lv > 0 then
		if g.characterName then Set(g.characterName, g.realmName, lv) end
		return lv
	end
end

local function AddBNetLevels(text)
	return (text:gsub("(|HBNplayer:(.-)|h)%[(.-)%]|h", function(open, data, inner)
		if inner:find("^|c%x+%d+|r:") then return nil end
		local level = BNetLevel(data)
		if not level then return nil end
		return open .. "[" .. LevelColor(level) .. level .. "|r:" .. inner .. "]|h"
	end))
end

-------------------------------------------------------------------------------
-- Short surnames: "Frost Winterborn" -> "Frost W." (display only; the link,
-- whispers, invites and clicks keep using the full name). If two people with
-- the same first name share an initial, the tag grows: "Frost Wi." / "Frost Wo."
-------------------------------------------------------------------------------
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local surnamesByFirst = {}  -- lower first name -> { surname = true }

local function Chars(s)
	local t = {}
	for c in s:gmatch(UTF8_CHAR) do t[#t + 1] = c end
	return t
end

local function SurnameTag(first, surname)
	local key = first:lower()
	local seen = surnamesByFirst[key]
	if not seen then seen = {}; surnamesByFirst[key] = seen end
	seen[surname] = true
	local mine = Chars(surname)
	local n = 1
	for other in pairs(seen) do
		if other ~= surname then
			local o = Chars(other)
			local same = 0
			while same < #mine and same < #o and mine[same + 1]:lower() == o[same + 1]:lower() do same = same + 1 end
			n = math.max(n, same + 1)
		end
	end
	if n >= #mine then return surname end
	return table.concat(mine, "", 1, n) .. "."
end
ns.SurnameTag = SurnameTag

local function ShortenName(name)
	local first, surname = name:match("^([^%s%-:|%[%]]+)[%s%-]([^%s%-:|%[%]]+)$")
	if not first then return nil end
	return first .. " " .. SurnameTag(first, surname)
end
ns.ShortenName = ShortenName

local function ShortenInner(inner)
	-- keep a level prefix ("|cff..18|r:") and class colour around the name
	local lvl, rest = inner:match("^(|c%x+%d+|r:)(.*)$")
	rest = rest or inner
	local c1, nm, c2 = rest:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
	local short
	if c1 then
		short = ShortenName(nm)
		short = short and (c1 .. short .. c2)
	else
		short = ShortenName(rest)
	end
	if not short then return inner end
	return (lvl or "") .. short
end

local function AddLevels(text)
	local S = ns.S or {}
	if S.showLevels and text:find("|HBNplayer:", 1, true) then text = AddBNetLevels(text) end
	return (text:gsub("(|Hplayer:([^|]*)|h)%[(.-)%]|h", function(open, data, inner)
		local out = inner
		if S.shortSurnames then out = ShortenInner(out) end
		if S.showLevels and not out:find("^|c%x+%d+|r:") then
			local name = data:match("^([^:]+)")
			local level = name and ns:LevelOf(ns.Normalize(name))
			if level then
				out = LevelColor(level) .. level .. "|r:" .. out
			else
				RequestGuildRoster() -- someone new: refresh the lists so the next line knows them
			end
		end
		if out == inner then return nil end
		return open .. "[" .. out .. "]|h"
	end))
end
ns.AddLevels = AddLevels

ns.OnChatFrame(function(frame)
	if frame.ChatPilotLevels or not frame.AddMessage then return end
	frame.ChatPilotLevels = true
	local orig = frame.AddMessage
	frame.AddMessage = function(self, text, ...)
		-- never touch secret (restricted) messages
		if ns.S and (ns.S.showLevels or ns.S.shortSurnames) and type(text) == "string" and not ns.IsSecret(text)
			and (text:find("|Hplayer:", 1, true) or text:find("|HBNplayer:", 1, true)) then
			local ok, out = pcall(AddLevels, text)
			if ok and out then text = out end
		end
		return orig(self, text, ...)
	end
end)
