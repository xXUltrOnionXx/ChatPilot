local _, ns = ...

-- Shows the player's level in front of names in chat, e.g. [18:Arthas].
-- Levels are only known for players the game has told us about: your group,
-- target, mouseover, nameplates, guild, friends and /who results.

local MAX_AGE, MAX_ENTRIES = 14 * 86400, 3000

local function Store() return ns.db.levels end

local function Set(name, realm, level)
	if type(level) ~= "number" or level <= 0 then return end
	local key = ns.Normalize(name, realm)
	if key then Store()[key] = { l = level, t = time() } end
end

local function FromUnit(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	local name, realm = UnitName(unit)
	local level = UnitLevel(unit)
	if ns.Usable(name, realm, level) then Set(name, realm, level) end
end

function ns:LevelOf(key)
	local e = key and Store()[key]
	return e and e.l
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
		if event == "PLAYER_LOGIN" then Prune(); ScanGroup(); ScanGuild(); ScanFriends()
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

local function AddLevels(text)
	return (text:gsub("(|Hplayer:([^|]*)|h)%[(.-)%]|h", function(open, data, inner)
		if inner:find("^|c%x+%d+|r:") then return nil end -- already has a level
		local name = data:match("^([^:]+)")
		local level = name and ns:LevelOf(ns.Normalize(name))
		if not level then return nil end
		return open .. "[" .. LevelColor(level) .. level .. "|r:" .. inner .. "]|h"
	end))
end
ns.AddLevels = AddLevels

ns.OnChatFrame(function(frame)
	if frame.ChatPilotLevels or not frame.AddMessage then return end
	frame.ChatPilotLevels = true
	local orig = frame.AddMessage
	frame.AddMessage = function(self, text, ...)
		-- never touch secret (restricted) messages
		if ns.S and ns.S.showLevels and type(text) == "string" and not ns.IsSecret(text)
			and text:find("|Hplayer:", 1, true) then
			local ok, out = pcall(AddLevels, text)
			if ok and out then text = out end
		end
		return orig(self, text, ...)
	end
end)
