local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Streamer mode: nothing private ends up on stream.
--  * whispers show only "hidden while streaming" (hover the line to peek)
--  * BattleTag numbers, other players' last names and web links are masked
--  * a red LIVE badge: left-click = panic (clears the chat view and hides all
--    ChatPilot windows, click again to bring everything back), right-click = settings
-- Only what is shown on screen changes. Nothing that you type or send is touched.
-------------------------------------------------------------------------------
ns.LINK_STREAM = "garrmission:chatpilotstream:"
local WHISPER_EVENTS = {
	CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true,
	CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true,
}

function ns.StreamOn() return ns.S ~= nil and ns.S.stream == true end

-- the texts of hidden whispers stay in memory only (never saved) so you can peek by hovering
local vault, vaultN = {}, 0
function ns.StreamHideWhisper(event, msg)
	if not (ns.StreamOn() and ns.S.streamWhispers ~= false and WHISPER_EVENTS[event]) then return nil end
	if type(msg) ~= "string" then return nil end
	vaultN = vaultN + 1
	vault[vaultN] = msg
	vault[vaultN - 60] = nil
	return "|cff8a8a8a|H" .. ns.LINK_STREAM .. vaultN .. "|h[" .. L.ST_HIDDEN .. "]|h|r"
end

function ns.StreamPeek(frame, link)
	if type(link) ~= "string" or link:sub(1, #ns.LINK_STREAM) ~= ns.LINK_STREAM then return false end
	local text = vault[tonumber(link:sub(#ns.LINK_STREAM + 1))]
	GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
	GameTooltip:SetText(L.ST_PEEK, 1, 0.45, 0.4)
	GameTooltip:AddLine(text and ns.StripEscapes(text) or L.ST_GONE, 1, 1, 1, true)
	GameTooltip:Show()
	frame.ChatPilotTip = true
	return true
end

-- "Player 1", "Player 2" ...: the same person keeps the same number while you stream
local anon, anonN = {}, 0
local function AnonName(name)
	local key = ns.Normalize and ns.Normalize(name) or name
	if key == ns.playerKey then return L.ST_ME end
	if not anon[key] then anonN = anonN + 1; anon[key] = L.ST_PLAYER:format(anonN) end
	return anon[key]
end

-- first name only inside player links: "[Frost Winterborn]" / "[Frost W.]" -> "[Frost]"
local function MaskNames(text)
	return (text:gsub("(|Hplayer:([^|]*)|h)(.-)|h", function(open, data, inner)
		local name = data:match("^([^:]+)")
		if not name then return nil end
		local full = (name:gsub("%-", " "))
		local first = full:match("^(%S+)%s")
		if not first then return nil end
		if ns.S.streamAnon then first = AnonName(name) end
		local out = inner
		local cands = { full }
		local short = ns.ShortenName and ns.ShortenName(full)
		if short then cands[#cands + 1] = short end
		for _, c in ipairs(cands) do
			local a, b = out:find(c, 1, true)
			if a then
				out = out:sub(1, a - 1) .. first .. out:sub(b + 1)
				break
			end
		end
		if out == inner then return nil end
		return open .. out .. "|h"
	end))
end

-- every line the chat writes goes through here while streaming
function ns.StreamMask(text)
	local S = ns.S
	if not S or not S.stream or type(text) ~= "string" then return text end
	if S.streamTags ~= false then
		text = text:gsub("([^%s|:%[%]]+)#(%d%d%d%d%d?%d?)%f[%D]", "%1#****")
	end
	if (S.streamNames ~= false or S.streamAnon) and text:find("|Hplayer:", 1, true) then
		text = MaskNames(text)
	end
	if S.streamLinks ~= false then
		local hidden = "|cff8a8a8a[" .. L.ST_LINK .. "]|r"
		text = text:gsub("|c%x%x%x%x%x%x%x%x|Hgarrmission:chatpilot:.-|h%[.-%]|h|r", hidden)
		text = text:gsub("[Hh][Tt][Tt][Pp][Ss]?://[^%s|]+", hidden)
		text = text:gsub("[Dd][Ii][Ss][Cc][Oo][Rr][Dd]%.gg/[^%s|]+", hidden)
		text = text:gsub("[Ww][Ww][Ww]%.[%w%-_%.]+%.%a%a%a?%a?[^%s|]*", hidden)
	end
	return text
end

-------------------------------------------------------------------------------
-- Panic: clear the chat view and hide every ChatPilot window
-------------------------------------------------------------------------------
local panic = false
local hiddenFrames = {}
local WINDOWS = { "ChatPilotOptions", "ChatPilotWhispers", "ChatPilotMentions", "ChatPilotCopy", "ChatPilotArchive",
	"ChatPilotSearchWindow", "ChatPilotBackupWindow", "ChatPilotFeedback", "ChatPilotSend", "ChatPilotTutorial" }

function ns:StreamPanic(force)
	if force == nil then force = not panic end
	if force == panic then return end
	panic = force
	if panic then
		wipe(hiddenFrames)
		for i = 1, (NUM_CHAT_WINDOWS or 10) do
			local f = _G["ChatFrame" .. i]
			if f and f.Clear and i ~= 2 then pcall(f.Clear, f) end -- the view only; ChatPilot keeps its own copy
		end
		for _, name in ipairs(WINDOWS) do
			local f = _G[name]
			if f and f:IsShown() then hiddenFrames[#hiddenFrames + 1] = f; f:Hide() end
		end
		if ns.NotesShown and ns:NotesShown() then
			ns.panicNotes = true
			ns:HideNotes()
		end
		if ns._cw then
			for _, g in ipairs(ns._cw.groups) do
				if g.frame:IsShown() then hiddenFrames[#hiddenFrames + 1] = g.frame; g.frame:Hide() end
			end
		end
		ns.Print(L.ST_PANIC_ON)
	else
		for _, f in ipairs(hiddenFrames) do f:Show() end
		wipe(hiddenFrames)
		if ns.panicNotes then ns.panicNotes = nil; if ns.ShowNotes then ns:ShowNotes() end end
		if ns.RefreshMainChat then ns:RefreshMainChat() end
		ns.Print(L.ST_PANIC_OFF)
	end
	if ns.UpdateStreamBadge then ns:UpdateStreamBadge() end
end

-------------------------------------------------------------------------------
-- LIVE badge
-------------------------------------------------------------------------------
local badge
local function BuildBadge()
	badge = CreateFrame("Button", "ChatPilotStreamBadge", UIParent)
	badge:SetSize(92, 24)
	badge:SetFrameStrata("HIGH")
	badge:SetClampedToScreen(true)
	badge:SetMovable(true)
	badge:EnableMouse(true)
	badge:RegisterForDrag("LeftButton")
	badge:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	badge.bg = UI.Fill(badge, { 0.75, 0.12, 0.12, 0.95 })
	UI.Border(badge, { 1, 0.45, 0.4, 1 })
	badge.text = UI.Text(badge, "GameFontHighlightSmall")
	badge.text:SetPoint("CENTER")
	local pos = ns.db and ns.db.streamBadge
	badge:SetPoint(pos and pos.p or "TOP", UIParent, pos and pos.rp or "TOP", pos and pos.x or 0, pos and pos.y or -8)
	badge:SetScript("OnDragStart", function(self) self:StartMoving() end)
	badge:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint()
		if ns.db then ns.db.streamBadge = { p = p, rp = rp, x = x, y = y } end
	end)
	badge:SetScript("OnClick", function(_, button)
		if button == "RightButton" then ns:OpenOptions() else ns:StreamPanic() end
	end)
	badge:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L.ST_BADGE_TITLE, 1, 0.45, 0.4)
		GameTooltip:AddLine(L.ST_BADGE_TIP, 1, 1, 1, true)
		if (ns.streamBlocked or 0) > 0 then GameTooltip:AddLine(L.ST_BLOCKED:format(ns.streamBlocked), 0.55, 0.85, 0.65) end
		GameTooltip:Show()
	end)
	badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return badge
end

function ns:UpdateStreamBadge()
	if not self.S then return end
	if not self.S.stream then
		if badge then badge:Hide() end
		return
	end
	badge = badge or BuildBadge()
	badge.text:SetText(panic and L.ST_BADGE_PANIC or L.ST_BADGE)
	badge:Show()
end

-- switching the mode on or off (also from the settings switch and the slash command)
function ns:SetStream(on)
	self.S.stream = on and true or false
	if not on and panic then self:StreamPanic(false) end
	self:UpdateStreamBadge()
	if self.RefreshMainChat then self:RefreshMainChat() end
	ns.Print(on and L.ST_ON or L.ST_OFF)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	if ns.S and ns.S.stream then C_Timer.After(1, function() ns:UpdateStreamBadge() end) end
end)
