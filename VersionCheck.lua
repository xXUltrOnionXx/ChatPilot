local _, ns = ...
local L = ns.L

-- "New version available" notice without internet: ChatPilot users in your
-- guild or group invisibly exchange their version number (addon messages,
-- not chat). Sent rarely, never inside instances, at most once a minute.

local PREFIX = "ChatPilot"
local THROTTLE = 60
local lastSent, notified = {}, false

local function Parse(v)
	local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.?(%d*)")
	if not a then return nil end
	return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end

local function Send(channel)
	if not ns.S or not ns.S.versionCheck then return end
	if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
	if IsInInstance and IsInInstance() then return end -- addon comms are restricted there
	local now = GetTime()
	if lastSent[channel] and now - lastSent[channel] < THROTTLE then return end
	lastSent[channel] = now
	pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V:" .. ns.version, channel)
end

local function Broadcast()
	if IsInGuild and IsInGuild() then Send("GUILD") end
	if IsInRaid and IsInRaid() then Send("RAID")
	elseif IsInGroup and IsInGroup() then Send("PARTY") end
end

local function Notify(newer)
	if notified then return end
	notified = true
	ns.newerVersion = newer
	ns.Print(L.UPDATE_AVAILABLE, newer, ns.version)
	if ns.ShowToast then
		ns:ShowToast(L.UPDATE_TOAST:format(newer), L.UPDATE_TOAST_TEXT, nil, ns.UI.C.accent)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
	if event == "PLAYER_LOGIN" then
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
		end
		C_Timer.After(15, Broadcast)
	elseif event == "GROUP_ROSTER_UPDATE" then
		Broadcast()
	elseif event == "CHAT_MSG_ADDON" then
		if not ns.Usable(prefix, msg) or prefix ~= PREFIX or type(msg) ~= "string" then return end
		if not ns.S or not ns.S.versionCheck then return end
		local theirs = msg:match("^V:(.+)$")
		local t, mine = Parse(theirs), Parse(ns.version)
		if not t or not mine then return end
		if t > mine then
			Notify(theirs)
		elseif t < mine and (channel == "GUILD" or channel == "PARTY" or channel == "RAID") then
			Send(channel) -- let older versions know an update exists
		end
	end
end)
