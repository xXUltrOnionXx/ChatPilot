local _, ns = ...
local L = ns.L

-- Display-only chat filter for YOUR chat window:
--  * colours mentions of you
--  * turns web addresses into clickable links (opens a copy box)
--  * explains chat abbreviations on mouse-over
--  * dims (or hides) messages in a language your character can't read
--  * hides repeated spam in public channels
-- Nothing is ever sent, and the language barrier between factions is NOT
-- bypassed: the server only sends scrambled text, which stays scrambled.

local HL_COLOR = "ffff9a1f"
local ABBR_COLOR = "ffd4e8ff"
local LINK_URL = "garrmission:chatpilot:"
local LINK_ABBR = "garrmission:chatpilotabbr:"

local URL_PATTERNS = {
	"https?://[%w%-%._~:/%?#%[%]@!%$&'%*%+,;=%%]+",
	"www%.[%w%-]+%.[%w%-%._~:/%?#@!%$&%*%+,;=%%]+",
	"discord%.gg/[%w%-]+",
}

local function FindURL(text, init)
	local bs, be
	for _, pat in ipairs(URL_PATTERNS) do
		local s, e = text:find(pat, init)
		if s and (not bs or s < bs) then bs, be = s, e end
	end
	if not bs then return nil end
	-- trailing punctuation usually belongs to the sentence, not the link
	while be > bs and text:sub(be, be):find("[%.,!%?;:'%)]") do be = be - 1 end
	return bs, be
end

-------------------------------------------------------------------------------
-- Decorating plain text (mentions + abbreviations)
-------------------------------------------------------------------------------
local function Decorate(seg, doHl, doAbbr)
	local marks = {}
	if doHl and #ns.words > 0 then
		local lower = seg:lower()
		for _, w in ipairs(ns.words) do
			local pos = 1
			while true do
				local s, e = ns.FindWord(lower, w, pos)
				if not s then break end
				marks[#marks + 1] = { s, e, "hl" }
				pos = e + 1
			end
		end
	end
	if doAbbr then
		for s, word, e in seg:gmatch("()(%w+)()") do
			local before, after = seg:byte(s - 1), seg:byte(e)
			if not (before and before >= 128) and not (after and after >= 128) and ns.Explain(word) then
				marks[#marks + 1] = { s, e - 1, "abbr" }
			end
		end
	end
	if #marks == 0 then return seg, false end

	table.sort(marks, function(a, b) return a[1] < b[1] end)
	local out, pos = {}, 1
	for _, m in ipairs(marks) do
		local s, e, kind = m[1], m[2], m[3]
		if s >= pos then
			out[#out + 1] = seg:sub(pos, s - 1)
			local word = seg:sub(s, e)
			if kind == "hl" then
				out[#out + 1] = "|c" .. HL_COLOR .. word .. "|r"
			else
				out[#out + 1] = "|c" .. ABBR_COLOR .. "|H" .. LINK_ABBR .. word .. "|h" .. word .. "|h|r"
			end
			pos = e + 1
		end
	end
	out[#out + 1] = seg:sub(pos)
	return table.concat(out), true
end

local function ProcessPlain(seg, doUrl, doHl, doAbbr)
	local out, pos, changed = {}, 1, false
	while doUrl do
		local s, e = FindURL(seg, pos)
		if not s then break end
		local before, c = Decorate(seg:sub(pos, s - 1), doHl, doAbbr)
		local url = seg:sub(s, e)
		out[#out + 1] = before
		out[#out + 1] = "|cff4ec9ff|H" .. LINK_URL .. url .. "|h[" .. url .. "]|h|r"
		pos, changed = e + 1, true
	end
	local rest, c = Decorate(seg:sub(pos), doHl, doAbbr)
	out[#out + 1] = rest
	return table.concat(out), changed or c
end

-------------------------------------------------------------------------------
-- Languages your character understands
-------------------------------------------------------------------------------
local known = {}
local function RefreshLanguages()
	wipe(known)
	if type(GetNumLanguages) ~= "function" or type(GetLanguageByIndex) ~= "function" then return end
	for i = 1, GetNumLanguages() do
		local name = GetLanguageByIndex(i)
		if type(name) == "string" then known[name] = true end
	end
end
ns.RefreshLanguages = RefreshLanguages

local function IsForeign(language)
	if type(language) ~= "string" or language == "" or ns.IsSecret(language) then return false end
	if next(known) == nil then RefreshLanguages() end
	if next(known) == nil then return false end -- unknown API: never guess
	return not known[language]
end

local langFrame = CreateFrame("Frame")
langFrame:RegisterEvent("PLAYER_LOGIN")
langFrame:RegisterEvent("LANGUAGE_LIST_CHANGED")
langFrame:SetScript("OnEvent", RefreshLanguages)

-------------------------------------------------------------------------------
-- Repeated spam in public channels (per chat window)
-------------------------------------------------------------------------------
local seen = setmetatable({}, { __mode = "k" })
local function IsRepeat(frame, author, msg)
	if not frame or type(author) ~= "string" or ns.IsSecret(author) then return false end
	local t = seen[frame]
	if not t then
		t = { n = 0, map = {} }
		seen[frame] = t
	end
	local key, now = author .. "\0" .. msg, GetTime()
	local last = t.map[key]
	if last and now - last < 90 then return true end
	t.map[key] = now
	t.n = t.n + 1
	if t.n > 300 then
		for k, v in pairs(t.map) do if now - v >= 90 then t.map[k] = nil end end
		t.n = 0
	end
	return false
end

-------------------------------------------------------------------------------
-- The filter
-------------------------------------------------------------------------------
local function Filter(frame, event, msg, author, language, ...)
	local S = ns.S
	if not S or type(msg) ~= "string" or ns.IsSecret(msg) then return false end

	if S.markForeign and IsForeign(language) then
		if S.hideForeign then return true end
		return false, "|cff8a8a8a" .. msg .. "|r |cff666666" .. L.UNREADABLE .. "|r", author, language, ...
	end

	if S.hideRepeats and event == "CHAT_MSG_CHANNEL" and IsRepeat(frame, author, msg) then
		return true
	end

	local doUrl = S.urls
	local doHl = S.mentions and S.highlight
	local doAbbr = S.abbrevTips
	if doHl and ns.Usable(author) and ns.Normalize(author) == ns.playerKey then doHl = false end
	if doHl and not S.mentionPublic and ns.PUBLIC_EVENTS[event] then doHl = false end
	if not doUrl and not doHl and not doAbbr then return false end

	local parts = ns.SplitMessage(msg)
	local changed = false
	for _, part in ipairs(parts) do
		if part[1] then
			local c
			part[2], c = ProcessPlain(part[2], doUrl, doHl, doAbbr)
			changed = changed or c
		end
	end
	if not changed then return false end
	local out = {}
	for i, part in ipairs(parts) do out[i] = part[2] end
	return false, table.concat(out), author, language, ...
end
ns.Filter = Filter

local FILTER_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}

local AddFilter = ChatFrame_AddMessageEventFilter
	or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if AddFilter then
	for _, ev in ipairs(FILTER_EVENTS) do AddFilter(ev, Filter) end
end

-------------------------------------------------------------------------------
-- Link clicks and mouse-over
-------------------------------------------------------------------------------
ns.OnChatFrame(function(frame)
	frame:HookScript("OnHyperlinkClick", function(_, link)
		if type(link) ~= "string" then return end
		if link:sub(1, #LINK_URL) == LINK_URL then
			ns:ShowCopy(link:sub(#LINK_URL + 1), L.COPY_URL_TITLE, true)
		end
	end)
	frame:HookScript("OnHyperlinkEnter", function(self, link)
		if type(link) == "string" and link:sub(1, #LINK_ABBR) == LINK_ABBR then
			local word = link:sub(#LINK_ABBR + 1)
			local text = ns.Explain(word)
			if text then
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				GameTooltip:SetText(word:upper(), 0.83, 0.91, 1)
				GameTooltip:AddLine(text, 1, 1, 1, true)
				GameTooltip:Show()
				self.ChatPilotTip = true
			end
		end
	end)
	frame:HookScript("OnHyperlinkLeave", function(self)
		if self.ChatPilotTip then
			self.ChatPilotTip = nil
			GameTooltip:Hide()
		end
	end)
end)
