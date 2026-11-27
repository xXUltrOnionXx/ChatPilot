local _, ns = ...
local L = ns.L

-- The autocomplete only ever changes the text in YOUR input box.
-- It never sends anything: you still press Enter yourself.

local ROW_H, WIDTH = 20, 290
local SRC_LABEL = {
	group = L.SRC_GROUP, target = L.SRC_TARGET, chat = L.SRC_CHAT,
	friend = L.SRC_FRIEND, guild = L.SRC_GUILD, community = L.SRC_COMMUNITY,
	icon = L.SRC_ICON, snippet = L.SRC_SNIPPET,
	nearby = L.SRC_NEARBY, who = L.SRC_WHO,
}
local WHISPER_CMDS = {
	["/w"] = true, ["/whisper"] = true, ["/t"] = true, ["/tell"] = true, ["/send"] = true,
	["/flüstern"] = true, ["/fl"] = true,
	["/inv"] = true, ["/invite"] = true, ["/einladen"] = true,
	["/who"] = true, ["/wer"] = true,
}

local state         -- active suggestion state or nil
local pendingEnter  -- text parked while Enter picks an entry

-- During Blizzard's chat restrictions (e.g. boss encounters) addons must not
-- change the input box. Then ChatPilot simply stays out of the way.
local function Restricted()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

-- WoW: Forever names have two parts ("First-Surname"). Show the second part
-- in the list so players with the same first name can be told apart.
local function SecondName(key)
	local rest = key and key:match("^[^-]+%-(.+)$")
	return rest
end
local hooked = {}

-------------------------------------------------------------------------------
-- Popup UI
-------------------------------------------------------------------------------
local popup = CreateFrame("Frame", "ChatPilotPopup", UIParent, "BackdropTemplate")
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetClampedToScreen(true)
popup:SetWidth(WIDTH)
popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
local function PaintPopup()
	local C = ns.UI.C
	popup:SetBackdropColor(unpack(C.popup))
	popup:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
end
PaintPopup()
popup:Hide()

popup.hint = ns.UI.NoShadow(popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
popup.hint:SetPoint("BOTTOMLEFT", 6, 4)
popup.hint:SetPoint("BOTTOMRIGHT", -6, 4)
popup.hint:SetJustifyH("LEFT")
popup.hint:SetText(L.HINT)

local rows = {}
local Accept -- forward

local function GetRow(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, popup)
	r:SetHeight(ROW_H)
	r:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ROW_H)
	r:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * ROW_H)
	r:RegisterForClicks("LeftButtonUp")

	r.sel = r:CreateTexture(nil, "BACKGROUND")
	r.sel:SetAllPoints()
	local A = ns.UI.C.accent
	r.sel:SetColorTexture(A[1], A[2], A[3], 0.22)

	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)

	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(16, 16)
	r.icon:SetPoint("LEFT", 4, 0)

	r.name = ns.UI.NoShadow(r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)

	r.tag = ns.UI.NoShadow(r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
	r.tag:SetPoint("RIGHT", -6, 0)
	r.name:SetPoint("RIGHT", r.tag, "LEFT", -6, 0)

	r:SetScript("OnClick", function(self) Accept(self.index) end)
	r:SetScript("OnEnter", function(self)
		if state then state.index = self.index; ns.RenderPopup() end
	end)
	rows[i] = r
	return r
end

ns.UI.OnTheme(function()
	PaintPopup()
	local A = ns.UI.C.accent
	for _, r in ipairs(rows) do r.sel:SetColorTexture(A[1], A[2], A[3], 0.22) end
end)

local function SetClassIcon(tex, classFile)
	if classFile and C_Texture and C_Texture.GetAtlasInfo then
		local atlas = "classicon-" .. classFile:lower()
		if C_Texture.GetAtlasInfo(atlas) then
			tex:SetAtlas(atlas)
			tex:Show()
			return
		end
	end
	tex:SetColorTexture(0.5, 0.5, 0.5, 0.35)
	tex:Show()
end

function ns.RenderPopup()
	if not state then popup:Hide() return end
	local items = state.items
	for i, item in ipairs(items) do
		local r = GetRow(i)
		r.index = i
		if item.who or item.whoBusy or item.whoNone then
			r.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
			r.icon:SetTexCoord(0, 1, 0, 1)
			r.name:SetText(item.short)
			if item.who then r.name:SetTextColor(unpack(ns.UI.C.accent)) else r.name:SetTextColor(unpack(ns.UI.C.muted)) end
		elseif item.snippet then
			r.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
			r.icon:SetTexCoord(0, 1, 0, 1)
			r.name:SetText(item.short .. "  |cff8a94a6" .. item.snippet .. "|r")
			r.name:SetTextColor(unpack(ns.UI.C.accent))
		elseif item.icon then
			r.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. item.icon)
			r.icon:SetTexCoord(0, 1, 0, 1)
			r.name:SetText(item.short)
			r.name:SetTextColor(1, 1, 1)
		else
			SetClassIcon(r.icon, item.c)
			local second = SecondName(item.key)
			r.name:SetText(second and (item.short .. " |cff8a94a6" .. second .. "|r") or item.short)
			local c = item.c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.c]
			if c then r.name:SetTextColor(c.r, c.g, c.b) else r.name:SetTextColor(1, 1, 1) end
		end
		local tag = SRC_LABEL[item.tag] or ""
		if item.key and ns.S and ns.S.playerInfo and ns.LevelOf then
			local lv = ns:LevelOf(item.key)
			if lv then tag = ns.LevelColor(lv) .. lv .. "|r" .. (tag ~= "" and ("  " .. tag) or "") end
		end
		r.tag:SetText(tag)
		r.sel:SetShown(i == state.index)
		r:Show()
	end
	for i = #items + 1, #rows do rows[i]:Hide() end
	popup:SetHeight(#items * ROW_H + 6 + 16)
	popup:ClearAllPoints()
	popup:SetPoint("BOTTOMLEFT", state.box, "TOPLEFT", 0, 4)
	popup:Show()
end

-------------------------------------------------------------------------------
-- Logic
-------------------------------------------------------------------------------
local function HidePopup()
	if state and state.box and state.prevAlt ~= nil and state.box.SetAltArrowKeyMode then
		state.box:SetAltArrowKeyMode(state.prevAlt)
	end
	state = nil
	popup:Hide()
end
ns.HidePopup = HidePopup

function ns.SnippetItems(partial)
	local p, items = (partial or ""):lower(), {}
	for _, sn in ipairs(ns.db.snippets) do
		if p == "" or sn.k:lower():find(p, 1, true) then
			items[#items + 1] = { short = "#" .. sn.k, snippet = sn.t, tag = "snippet" }
			if #items >= 8 then break end
		end
	end
	return items
end

local function IconItems(partial)
	local p, items = partial:lower(), {}
	for i = 1, 8 do
		local localized = _G["RAID_TARGET_" .. i] or ("rt" .. i)
		if p == "" or localized:lower():find(p, 1, true) or ("rt" .. i):find(p, 1, true) then
			items[#items + 1] = { icon = i, short = localized, code = "{rt" .. i .. "}", tag = "icon" }
		end
	end
	return items
end

-- Works out what is being typed at the cursor.
local function GetContext(box)
	local S = ns.S
	local text = box:GetText() or ""
	local cursor = box:GetCursorPosition() or #text
	local before = text:sub(1, cursor)

	if S.whisperNames then
		local cmd, partial = before:match("^(/%S+)%s+(%S*)$")
		if cmd and WHISPER_CMDS[cmd:lower()] then
			return "name", cursor - #partial + 1, partial, true
		end
	end
	if S.autocomplete then
		local pre, partial = before:match("^(.-)@([^%s@]*)$")
		if pre and (pre == "" or pre:find("%s$")) then
			return "name", #pre + 1, partial, false
		end
	end
	if S.snippets and ns.db and #ns.db.snippets > 0 then
		local pre, partial = before:match("^(.-)#([^%s#]*)$")
		if pre and (pre == "" or pre:find("%s$")) then
			return "snippet", #pre + 1, partial, false
		end
	end
	if S.raidIcons then
		local pre, partial = before:match("^(.-){(%w*)$")
		if pre then return "icon", #pre + 1, partial, false end
	end
end

-------------------------------------------------------------------------------
-- Server search (who list) for players nobody around you knows yet. It only
-- runs when you pick "Search on the server" yourself (click or Enter).
-------------------------------------------------------------------------------
local who = { last = -10, done = {} }
ns.whoFound = ns.whoFound or {}
local Update -- forward

local function WhoItem(partial)
	if not (C_FriendList and C_FriendList.SendWho) then return nil end
	local p = partial:gsub('"', ""):lower()
	if #p < 2 then return nil end
	if who.busy == p then return { whoBusy = true, short = L.WHO_BUSY, tag = "who" } end
	if who.done[p] == 0 then return { whoNone = true, short = L.WHO_NONE:format(partial), tag = "who" } end
	if who.done[p] then return nil end -- already searched: the players are in the list
	return { who = p, short = L.WHO_SEARCH:format(partial), tag = "who" }
end

local function WhoRefresh()
	local box = who.box
	if box and box:IsShown() and box:HasFocus() then Update(box) end
end

local function StartWho(p, box)
	who.box = box
	if who.busy or GetTime() - who.last < 5 then return WhoRefresh() end -- the server allows one search every few seconds
	who.busy, who.last = p, GetTime()
	who.friendsShown = FriendsFrame and FriendsFrame:IsShown() or false
	if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end -- results into the list, not into the chat
	local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social
	local ok = pcall(C_FriendList.SendWho, ('n-"%s"'):format(p), origin)
	if not ok then who.busy = nil end
	C_Timer.After(8, function()
		if who.busy == p then who.busy = nil; who.done[p] = who.done[p] or 0; WhoRefresh() end
	end)
	WhoRefresh()
end
ns.StartWho = StartWho -- for tests

-- every who result (also from your own /who) adds the players to the list
local whoEvents = CreateFrame("Frame")
whoEvents:RegisterEvent("WHO_LIST_UPDATE")
whoEvents:SetScript("OnEvent", function()
	local n = 0
	if C_FriendList and C_FriendList.GetNumWhoResults then
		for i = 1, (C_FriendList.GetNumWhoResults() or 0) do
			local info = C_FriendList.GetWhoInfo(i)
			local key = info and info.fullName and ns.Normalize(info.fullName)
			if key and key ~= ns.playerKey then
				ns.whoFound[key] = { c = info.filename, t = time() }
				n = n + 1
			end
		end
	end
	if who.busy then
		who.done[who.busy] = n
		who.busy = nil
		if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end -- the game's default again
		-- our search shouldn't leave the friends window open
		if not who.friendsShown and FriendsFrame and FriendsFrame:IsShown() and not InCombatLockdown() and HideUIPanel then
			pcall(HideUIPanel, FriendsFrame)
		end
	end
	if ns.MarkLiveDirty then ns:MarkLiveDirty() end
	WhoRefresh()
end)

function Update(box)
	if not ns.S then return end
	if Restricted() then return HidePopup() end
	local mode, startPos, partial, whisper = GetContext(box)
	if not mode then return HidePopup() end

	local items
	if mode == "icon" then items = IconItems(partial)
	elseif mode == "snippet" then items = ns.SnippetItems(partial)
	else
		items = ns:GetCandidates(partial, ns.S.maxRows)
		-- last row: look the name up on the server
		local wi = WhoItem(partial)
		if wi then
			if #items >= (ns.S.maxRows or 8) then items[#items] = wi else items[#items + 1] = wi end
		end
	end
	if #items == 0 then return HidePopup() end

	local prevAlt
	if state and state.box == box then
		prevAlt = state.prevAlt
	else
		HidePopup()
		if box.GetAltArrowKeyMode then
			prevAlt = box:GetAltArrowKeyMode()
			box:SetAltArrowKeyMode(false) -- arrows select instead of moving your character
		end
	end
	state = {
		box = box, text = box:GetText(), cursor = box:GetCursorPosition(),
		startPos = startPos, mode = mode, whisper = whisper,
		items = items, index = 1, prevAlt = prevAlt,
	}
	ns.RenderPopup()
end

-- Builds the new input text for the chosen entry (does not touch the box).
local function BuildText(st, index)
	local item = st.items[index or st.index]
	if not item or item.who or item.whoBusy or item.whoNone then return end
	local text, cursor = st.text, st.cursor

	local insert
	if item.snippet then
		insert = item.snippet
	elseif item.code then
		insert = item.code
	elseif st.whisper then
		insert = item.key
	else
		local name = item.short
		-- "Frost W." instead of just "Frost" (option)
		if ns.S.mentionInitial and SecondName(item.key) and ns.ShortenName then
			name = ns.ShortenName((item.key:gsub("%-", " "))) or name
		end
		-- same first name twice in the list? then insert the full name
		for _, other in ipairs(st.items) do
			if other ~= item and other.short == item.short and SecondName(item.key) then
				name = item.key:gsub("%-", " ")
				break
			end
		end
		insert = (ns.S.keepAt and "@" or "") .. name
	end
	local after = text:sub(cursor + 1)
	if after:sub(1, 1) ~= " " then insert = insert .. " " end
	return text:sub(1, st.startPos - 1) .. insert .. after, st.startPos - 1 + #insert
end
ns.BuildText = BuildText -- for tests

function Accept(index)
	local st = state
	if not st or Restricted() then return HidePopup() end
	local item = st.items[index or st.index]
	if item and (item.who or item.whoBusy or item.whoNone) then
		if item.who then StartWho(item.who, st.box) end
		return
	end
	local newText, newCursor = BuildText(st, index)
	if not newText then return end
	local box = st.box
	HidePopup()
	box:SetText(newText)
	box:SetCursorPosition(newCursor)
	if not box:HasFocus() then
		box:Show()
		box:SetFocus()
	end
end

local function Active(box)
	return state and state.box == box and popup:IsShown()
end
ns.AutocompleteActive = function(box) return Active(box) and true or false end

-------------------------------------------------------------------------------
-- Character counter
-------------------------------------------------------------------------------
-- Shows "used/limit" (the game allows 255 characters per chat message) as
-- soon as the box is active, so you always see how much room is left.
local CHAT_LIMIT = 255
local function UpdateCounter(box)
	local holder = rawget(box, "ChatPilotCounterFrame")
	local fs = rawget(box, "ChatPilotCounter")
	if not fs or not holder then return end
	local text = box:GetText() or ""
	local len = #text
	local active = box.HasFocus and box:HasFocus()
	if not ns.S or not ns.S.charCounter or (len == 0 and not active) or ns.IsSecret(text) then
		holder:Hide()
		return
	end
	local max = (box.GetMaxBytes and box:GetMaxBytes()) or 0
	if type(max) ~= "number" or max <= 0 or max > CHAT_LIMIT + 1 then max = CHAT_LIMIT end
	if max == CHAT_LIMIT + 1 then max = CHAT_LIMIT end
	fs:SetText(len .. "/" .. max)
	local C = ns.UI.C
	if len >= max then fs:SetTextColor(1, 0.3, 0.3)
	elseif len >= max * 0.8 then fs:SetTextColor(unpack(C.orange))
	else fs:SetTextColor(unpack(C.muted)) end
	holder:Show()
end

-------------------------------------------------------------------------------
-- Hooking input boxes (HookScript only: Blizzard's own handlers stay untouched)
-------------------------------------------------------------------------------
function ns.HookEditBox(box)
	if not box or hooked[box] or not box.HookScript then return end
	hooked[box] = true
	if ns.HookTyping then ns.HookTyping(box) end -- typing sounds, arrow keys move the cursor

	-- own little frame above the input box, so no texture can ever cover the counter
	local holder = CreateFrame("Frame", nil, box)
	holder:SetSize(56, 16)
	holder:SetPoint("RIGHT", box, "RIGHT", -8, 0)
	holder:SetFrameLevel((box:GetFrameLevel() or 1) + 5)
	box.ChatPilotCounter = ns.UI.NoShadow(holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	box.ChatPilotCounter:SetPoint("RIGHT")
	box.ChatPilotCounter:SetJustifyH("RIGHT")
	box.ChatPilotCounterFrame = holder
	holder:Hide()
	box:HookScript("OnEditFocusGained", function(self) UpdateCounter(self) end)
	box:HookScript("OnShow", function(self) UpdateCounter(self) end)

	box:HookScript("OnTextChanged", function(self, userInput)
		UpdateCounter(self)
		if userInput then Update(self) end
	end)

	box:HookScript("OnTabPressed", function(self)
		if Active(self) then Accept() end
	end)

	box:HookScript("OnArrowPressed", function(self, key)
		if not Active(self) then return end
		if Restricted() then return HidePopup() end
		if key == "UP" or key == "DOWN" then
			local n = #state.items
			if key == "UP" then
				state.index = state.index > 1 and state.index - 1 or n
			else
				state.index = state.index < n and state.index + 1 or 1
			end
			-- undo history / cursor movement caused by the arrow key
			local t, c = state.text, state.cursor
			local function restore()
				if self:GetText() ~= t then self:SetText(t) end
				self:SetCursorPosition(c)
			end
			restore()
			C_Timer.After(0, function() if state and state.box == self then restore() end end)
			ns.RenderPopup()
		else
			C_Timer.After(0, function() if self:HasFocus() then Update(self) end end)
		end
	end)

	-- Enter while the list is open picks the marked entry instead of sending.
	-- OnKeyDown runs before the input box handles Enter: the text is parked and
	-- the box is emptied, so Blizzard's own Enter handler has nothing to send.
	-- Right after it, the text comes back with the chosen name filled in.
	box:HookScript("OnKeyDown", function(self, key)
		if (key == "ENTER" or key == "NUMPADENTER") and Active(self) and not Restricted() then
			pendingEnter = { box = self, st = state }
			self:SetText("")
		end
	end)
	box:HookScript("OnEnterPressed", function(self)
		local p = pendingEnter
		pendingEnter = nil
		if p and p.box == self then
			local item = p.st.items[p.st.index]
			if item and (item.who or item.whoBusy or item.whoNone) then
				-- Enter on "Search on the server": the text stays, the search starts
				if not self:IsShown() then
					local open = ChatEdit_ActivateChat or (ChatFrameUtil and ChatFrameUtil.ActivateChat)
					if open then open(self) else self:Show() end
				end
				if not self:HasFocus() then self:SetFocus() end
				self:SetText(p.st.text)
				self:SetCursorPosition(p.st.cursor)
				if item.who then StartWho(item.who, self) else Update(self) end
				return
			end
			local newText, newCursor = BuildText(p.st)
			if state and state.box == self then HidePopup() end
			if not newText then return end
			if not self:IsShown() then
				local open = ChatEdit_ActivateChat or (ChatFrameUtil and ChatFrameUtil.ActivateChat)
				if open then open(self) else self:Show() end
			end
			if not self:HasFocus() then self:SetFocus() end
			self:SetText(newText)
			self:SetCursorPosition(newCursor)
			return
		end
		if state and state.box == self then HidePopup() end
	end)
	box:HookScript("OnEscapePressed", function(self) if state and state.box == self then HidePopup() end end)
	box:HookScript("OnHide", function(self)
		if state and state.box == self then HidePopup() end
		UpdateCounter(self)
	end)
	box:HookScript("OnEditFocusLost", function(self)
		UpdateCounter(self)
		C_Timer.After(0.2, function()
			if state and state.box == self and not self:HasFocus() then HidePopup() end
		end)
	end)
end

-- Tab key: Blizzard calls ChatEdit_CustomTabPressed (via securecall) before its
-- own tab logic. Answering it while our list is open stops Tab from also
-- cycling whisper targets. If it doesn't exist, the OnTabPressed hook above is used.
if type(ChatEdit_CustomTabPressed) == "function" then
	local orig = ChatEdit_CustomTabPressed
	ChatEdit_CustomTabPressed = function(self, ...)
		if Active(self) then
			Accept()
			return true
		end
		return orig(self, ...)
	end
end

ns.OnChatFrame(function(frame)
	local box = frame.editBox or _G[(frame:GetName() or "") .. "EditBox"]
	ns.HookEditBox(box)
end)

-- Community window has its own input box.
local prevAddonLoaded = ns.OnAddonLoaded
function ns:OnAddonLoaded(name)
	if prevAddonLoaded then prevAddonLoaded(self, name) end
	if name == "Blizzard_Communities" and CommunitiesFrame and CommunitiesFrame.ChatEditBox then
		ns.HookEditBox(CommunitiesFrame.ChatEditBox)
	end
end
