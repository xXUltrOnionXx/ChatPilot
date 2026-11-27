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
-- Advertising spam (gold selling, boosts for real money, websites)
-- Score based so normal trade chat ("WTS [item] 5g") is never hidden.
-------------------------------------------------------------------------------
local SPAM_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true,
	CHAT_MSG_WHISPER = true, CHAT_MSG_EMOTE = true }
local SPAM_RULES = {
	{ 2, { "www%.", "%.com", "%.net", "%.org", "%.ru", "%.cn", "d0t", "dot%s*com", "%[dot%]" } },
	{ 2, { "%$", "€", "usd", "eur%f[%A]", "dollar", "euro", "paypal", "btc", "crypto" } },
	{ 2, { "cheap gold", "buy gold", "gold for sale", "sell gold", "goldshop", "gold shop", "fast gold",
		"wts gold", "gold%s*%-%s*%d", "g2g", "mmoga", "gold kaufen", "billig gold" } },
	{ 1, { "boost", "carry", "power%s*level", "pl service", "piloted", "account" } },
	{ 1, { "discount", "%d+%s*%%%s*off", "rabatt", "24/7", "fast delivery", "instant delivery", "cheap",
		"coupon", "promo", "code:" } },
	{ 1, { "skype", "telegram", "whatsapp" } },
}
local function SpamScore(msg)
	local text = ns.StripEscapes(msg):lower()
	local score = 0
	for _, rule in ipairs(SPAM_RULES) do
		for _, pat in ipairs(rule[2]) do
			if text:find(pat) then score = score + rule[1]; break end
		end
	end
	return score
end
ns.SpamScore = SpamScore

local function Trusted(author)
	if type(author) ~= "string" or not ns.Usable(author) then return false end
	local key = ns.Normalize(author)
	if not key or key == ns.playerKey then return true end
	local e = ns.live and ns.live[key]
	return e and (e.src.friend or e.src.guild or e.src.group) or false
end

-- Fake links in whispers from strangers: community invitations (used to
-- advertise gold sellers) and item links whose shown name is not the real
-- item's name. 0 = nothing, 1 = a link from a stranger, 2 = suspicious.
local function ScamLevelRaw(msg)
	if msg:find("|HclubTicket:", 1, true) then return 2 end
	local level = 0
	for id, shown in msg:gmatch("|Hitem:(%d+)[^|]*|h%[([^%]]*)%]|h") do
		level = 1
		local real = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(tonumber(id))
		if type(real) == "string" and real ~= "" and ns.Usable(real) and shown:sub(1, #real) ~= real then
			return 2
		end
	end
	return level
end
function ns.ScamLevel(msg)
	if type(msg) ~= "string" or not ns.Usable(msg) then return 0 end
	local ok, level = pcall(ScamLevelRaw, msg)
	return ok and level or 0
end

local countedLines = {}
local function CountSpam(lineID)
	if lineID ~= nil and not ns.Usable(lineID) then lineID = nil end -- protected: just count
	if lineID and countedLines[lineID] then return end
	if lineID then countedLines[lineID] = true end
	ns.spamHidden = (ns.spamHidden or 0) + 1
	if ns.db then
		local today = date("%Y-%m-%d")
		local d = ns.db.spamDay
		if type(d) ~= "table" or d.day ~= today then d = { day = today, n = 0 }; ns.db.spamDay = d end
		d.n = d.n + 1
	end
end

-- spam messages hidden today (survives /reload)
function ns:SpamToday()
	local d = self.db and self.db.spamDay
	if type(d) == "table" and d.day == date("%Y-%m-%d") then return d.n end
	return 0
end

-------------------------------------------------------------------------------
-- The filter
-------------------------------------------------------------------------------
-- *bold*, _italic_, `code`, ~~strike~~ shown with colours (display only; the text that is sent stays as typed)
local function Markdown(seg)
	if not seg:find("[%*_`~]") then return seg, false end
	local n = 0
	local function sub(pat, color)
		local c
		seg, c = seg:gsub(pat, color .. "%1|r")
		n = n + c
	end
	sub("`([^`]+)`", "|cffffd479")
	sub("%*%*([^%*]+)%*%*", "|cffffffff")
	sub("~~([^~]+)~~", "|cff777777")
	sub("%f[%w_%*]%*([^%*%s][^%*]-)%*%f[^%w_%*]", "|cffb8c4ff")
	sub("%f[%w_]_([^_%s][^_]-)_%f[^%w_]", "|cffb8c4ff")
	return seg, n > 0
end

local function Filter(frame, event, msg, author, language, ...)
	local S = ns.S
	if not S or type(msg) ~= "string" or ns.IsSecret(msg) then return false end

	-- streamer mode: whispers show only a notice (hover to peek)
	if S.stream and S.streamStrangers ~= false and event == "CHAT_MSG_WHISPER" and not Trusted(author) then
		ns.streamBlocked = (ns.streamBlocked or 0) + 1
		return true
	end
	if S.stream and ns.StreamHideWhisper then
		local hidden = ns.StreamHideWhisper(event, msg)
		if hidden then return false, hidden, author, language, ... end
	end

	if S.markForeign and IsForeign(language) then
		if S.hideForeign then return true end
		if not ns.MainChatModern or ns.MainChatModern() then
			local new = "|cff8a8a8a" .. msg .. "|r |cff666666" .. L.UNREADABLE .. "|r"
			if type(frame) == "table" then frame.cpRaw = { orig = msg, new = new } end
			return false, new, author, language, ...
		end
		return false
	end

	if S.spamFilter and SPAM_EVENTS[event] and not Trusted(author) and SpamScore(msg) >= 3 then
		CountSpam((select(8, ...)))
		return true
	end

	if S.hideRepeats and event == "CHAT_MSG_CHANNEL" and IsRepeat(frame, author, msg) then
		return true
	end

	-- warning for links in whispers from strangers (never for friends, guild, group)
	local prefix = ""
	if S.scamWarn ~= false and event == "CHAT_MSG_WHISPER" and not Trusted(author) then
		local level = ns.ScamLevel(msg)
		if level == 2 and S.spamFilter and SpamScore(msg) >= 1 then
			CountSpam((select(8, ...)))
			return true
		end
		if level > 0 then
			prefix = "|cffff6a5a[!] " .. (level == 2 and L.SCAM_FAKE or L.SCAM_LINK) .. "|r "
		end
	end

	-- with the game's normal design ChatPilot doesn't change the chat text
	if ns.MainChatModern and not ns.MainChatModern() then return false end
	local doUrl = S.urls
	local doHl = S.mentions and S.highlight
	local doAbbr = S.abbrevTips
	local doMd = S.markdown
	if doHl and ns.Usable(author) and ns.Normalize(author) == ns.playerKey then doHl = false end
	if doHl and not S.mentionPublic and ns.PUBLIC_EVENTS[event] then doHl = false end
	if not doUrl and not doHl and not doAbbr and not doMd and prefix == "" then return false end

	local parts = ns.SplitMessage(msg)
	local changed = false
	for _, part in ipairs(parts) do
		if part[1] then
			local c, md
			if doMd then part[2], md = Markdown(part[2]) end
			part[2], c = ProcessPlain(part[2], doUrl, doHl, doAbbr)
			changed = changed or c or md
		end
	end
	if not changed and prefix == "" then return false end
	local out = {}
	for i, part in ipairs(parts) do out[i] = part[2] end
	local new = prefix .. table.concat(out)
	if type(frame) == "table" then frame.cpRaw = { orig = msg, new = new } end
	return false, new, author, language, ...
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
-- shared with ChatPilot's own chat windows
function ns.LinkClick(link)
	if type(link) ~= "string" then return false end
	if link:sub(1, #LINK_URL) == LINK_URL then
		ns:ShowCopy(link:sub(#LINK_URL + 1), L.COPY_URL_TITLE, true)
		return true
	end
	return link:sub(1, #LINK_ABBR) == LINK_ABBR
end

function ns.LinkEnter(frame, link)
	if ns.StreamPeek and ns.StreamPeek(frame, link) then return true end
	-- player card on mouse-over: full name, level, class, how you know them
	if type(link) == "string" and ns.S and link:sub(1, 7) == "player:" and (ns.S.playerInfo or ns.S.shortSurnames) then
		local full = link:match("^player:([^:]+)")
		if full and ns.Usable(full) then
			local info = ns.S.playerInfo and ns.PlayerInfo and ns:PlayerInfo(full)
			local c = info and info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
			if info or full:find("-", 1, true) then
				GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
				GameTooltip:SetText((full:gsub("%-", " ")), c and c.r or 1, c and c.g or 1, c and c.b or 1)
				if info then
					local className = info.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[info.class])
						or (info.class:sub(1, 1) .. info.class:sub(2):lower()))
					if info.level or className then
						local lvl = info.level and (ns.LevelColor(info.level) .. L.PI_LEVEL:format(info.level) .. "|r") or ""
						local cls = className and ((c and ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or "") .. className .. "|r") or ""
						GameTooltip:AddLine(lvl .. ((lvl ~= "" and cls ~= "") and "  " or "") .. cls)
					else
						GameTooltip:AddLine(L.PI_UNKNOWN, 0.6, 0.6, 0.6)
					end
					local tags = {}
					if info.src.group then tags[#tags + 1] = L.SRC_GROUP end
					if info.src.guild then tags[#tags + 1] = L.SRC_GUILD end
					if info.src.friend then tags[#tags + 1] = L.SRC_FRIEND end
					if info.src.community then tags[#tags + 1] = L.SRC_COMMUNITY end
					if #tags > 0 then GameTooltip:AddLine(table.concat(tags, " · "), 0.55, 0.85, 0.65) end
				end
				local ptxt, pkind = ns.PresenceText and ns.PresenceText(full)
				if ptxt then
					GameTooltip:AddLine(ptxt, pkind == "relog" and 1 or 0.3, pkind == "relog" and 0.66 or (pkind == "before" and 0.72 or 0.87), pkind == "before" and 1 or 0.5)
				end
				local pe = ns.PilotInfo and ns.PilotInfo(full)
				if pe then
					GameTooltip:AddLine(L.PL_USES:format(pe.v or "?") .. (pe.zone and (" · " .. pe.zone) or ""), 0.31, 0.79, 1)
				end
				GameTooltip:Show()
				frame.ChatPilotTip = true
				return false -- clicks and other handlers keep working
			end
		end
	end
	if type(link) == "string" and link:sub(1, #LINK_ABBR) == LINK_ABBR then
		local word = link:sub(#LINK_ABBR + 1)
		local text = ns.Explain(word)
		if text then
			GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
			GameTooltip:SetText(word:upper(), 0.83, 0.91, 1)
			GameTooltip:AddLine(text, 1, 1, 1, true)
			GameTooltip:Show()
			frame.ChatPilotTip = true
			return true
		end
	end
	return false
end

function ns.LinkLeave(frame)
	if rawget(frame, "ChatPilotTip") then
		frame.ChatPilotTip = nil
		GameTooltip:Hide()
	end
end

-- Hidden ("offensive") messages: the game shows a "Show" link. The click is
-- the game's own; afterwards ChatPilot makes sure the line really is released
-- and every chat window writes it again, whatever look the chat has.
function ns.CensorID(link)
	if type(link) ~= "string" then return nil end
	local id = link:match("^[Cc]ensored[Mm]essage:(%d+)") or link:match("^cpcensor:(%d+)")
	return id and tonumber(id) or nil
end

function ns.RevealBlizzard(id)
	if not id then return end
	local api = C_ChatInfo
	if api and api.IsChatLineCensored and api.UncensorChatLine then
		local ok, hidden = pcall(api.IsChatLineCensored, id)
		if ok and hidden then pcall(api.UncensorChatLine, id) end
	end
	local function Redraw()
		for i = 1, (NUM_CHAT_WINDOWS or 10) do
			local f = _G["ChatFrame" .. i]
			if f and f.RefreshDisplay then pcall(f.RefreshDisplay, f) end
		end
	end
	Redraw()
	if C_Timer and C_Timer.After then C_Timer.After(0.2, Redraw) end
end

ns.OnChatFrame(function(frame)
	frame:HookScript("OnHyperlinkClick", function(_, link)
		ns.LinkClick(link)
		local cid = ns.CensorID(link)
		if cid then ns.RevealBlizzard(cid) end
	end)
	frame:HookScript("OnHyperlinkEnter", function(self, link) ns.LinkEnter(self, link) end)
	frame:HookScript("OnHyperlinkLeave", function(self) ns.LinkLeave(self) end)
end)
