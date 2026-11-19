local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- The game's own chat in the same tidy look as ChatPilot's windows:
--   (o) Name  21:17 · Trade
--       message text
-- Only while "Modern chat window" is on. With the game's normal design, ChatPilot
-- leaves the chat exactly as Blizzard writes it.

function ns.MainLookActive()
	local S = ns.S
	return (S and S.chatStyle ~= false and S.chatSkin and not ns.skinConflict) and true or false
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
}

local function Note(frame, event, ...)
	if type(frame) ~= "table" then return false end
	frame.cpHint = nil
	if not ns.MainLookActive() then return false end
	local msg, author = ...
	local chanString, chanNum, chanBase = select(4, ...), select(8, ...), select(9, ...)
	if not ns.Usable(msg, author, chanString, chanNum, chanBase) then return false end
	frame.cpHint = {
		event = event, msg = msg, author = author, chan = chanString,
		chanNum = chanNum, chanBase = chanBase, t = GetTime(),
	}
	return false
end

local AddFilter = ChatFrame_AddMessageEventFilter
	or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if AddFilter then
	for _, ev in ipairs(EVENTS) do AddFilter(ev, Note) end
end

-- Rebuilds one line. Returns true when it wrote the line itself.
function ns.StyleMainLine(frame, text, orig, r, g, b, ...)
	local h = rawget(frame, "cpHint")
	frame.cpHint = nil
	local look = ns.ChatLook
	if not h or not look or h.t ~= GetTime() then return false end

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

	-- who: the name as the game links it (class colour, right-click menu), "You" for yourself
	local who, label = link, nil
	if inform then
		who = you
		label = L.CW_TO:format(link)
	elseif isOwn then
		local open = link:match("^(|H.-|h)")
		who = open and (open .. "[" .. you .. "]|h") or you
	end
	if not label then
		-- keep the game's channel link (clickable), just without the brackets
		local co, cin, cc = prefix:match("(|Hchannel:[^|]+|h)%[(.-)%](|h)")
		if co then
			label = co .. look.ShortChannel(cin) .. cc
		else
			label = look.ChannelLabel(chatType, h.chanNum, h.chanBase or "", h.chan, h.author)
		end
	end

	local now = time()
	local lastT, lastKey = rawget(frame, "cpLastT"), rawget(frame, "cpLastKey")
	local key = tostring(h.author) .. "|" .. chatType .. "|" .. tostring(h.chanNum or "")
	if lastT and now - lastT > 900 then
		orig(frame, UI.Hex(C.muted) .. "—  " .. date("%H:%M", now) .. "  —|r", 1, 1, 1)
		lastKey = nil
	end
	if not (lastKey == key and lastT and now - lastT <= 120) then
		local dotc = isOwn and C.accent or mentioned and C.orange or calm
		local head = look.Dot(dotc) .. "  " .. who .. "  " .. UI.Hex(C.muted) .. date("%H:%M", now)
			.. (label and (" · " .. label) or "") .. "|r"
		orig(frame, head, 1, 1, 1, ...)
	end
	frame.cpLastKey, frame.cpLastT = key, now
	local c = mentioned and C.orange or calm
	orig(frame, look.INDENT .. body, c[1], c[2], c[3], ...)
	return true
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
		f.cpLastKey, f.cpLastT = nil, nil
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
