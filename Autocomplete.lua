local _, ns = ...
local L = ns.L

-- The autocomplete only ever changes the text in YOUR input box.
-- It never sends anything: you still press Enter yourself.

local ROW_H, WIDTH = 20, 290
local SRC_LABEL = {
	group = L.SRC_GROUP, target = L.SRC_TARGET, chat = L.SRC_CHAT,
	friend = L.SRC_FRIEND, guild = L.SRC_GUILD, community = L.SRC_COMMUNITY,
	icon = L.SRC_ICON, snippet = L.SRC_SNIPPET,
}
local WHISPER_CMDS = {
	["/w"] = true, ["/whisper"] = true, ["/t"] = true, ["/tell"] = true, ["/send"] = true,
	["/flüstern"] = true, ["/fl"] = true,
	["/inv"] = true, ["/invite"] = true, ["/einladen"] = true,
	["/who"] = true, ["/wer"] = true,
}

local state         -- active suggestion state or nil

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
popup:SetBackdropColor(0.04, 0.05, 0.08, 0.94)
popup:SetBackdropBorderColor(0.31, 0.79, 1, 0.6)
popup:Hide()

popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
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
	r.sel:SetColorTexture(0.31, 0.79, 1, 0.22)

	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)

	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(16, 16)
	r.icon:SetPoint("LEFT", 4, 0)

	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)

	r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.tag:SetPoint("RIGHT", -6, 0)
	r.name:SetPoint("RIGHT", r.tag, "LEFT", -6, 0)

	r:SetScript("OnClick", function(self) Accept(self.index) end)
	r:SetScript("OnEnter", function(self)
		if state then state.index = self.index; ns.RenderPopup() end
	end)
	rows[i] = r
	return r
end

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
		if item.snippet then
			r.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
			r.icon:SetTexCoord(0, 1, 0, 1)
			r.name:SetText(item.short .. "  |cff8a94a6" .. item.snippet .. "|r")
			r.name:SetTextColor(0.31, 0.79, 1)
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
		r.tag:SetText(SRC_LABEL[item.tag] or "")
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

local function Update(box)
	if not ns.S then return end
	if Restricted() then return HidePopup() end
	local mode, startPos, partial, whisper = GetContext(box)
	if not mode then return HidePopup() end

	local items
	if mode == "icon" then items = IconItems(partial)
	elseif mode == "snippet" then items = ns.SnippetItems(partial)
	else items = ns:GetCandidates(partial, ns.S.maxRows) end
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

function Accept(index)
	local st = state
	if not st or Restricted() then return HidePopup() end
	local item = st.items[index or st.index]
	if not item then return end
	local box, text, cursor = st.box, st.text, st.cursor

	local insert
	if item.snippet then
		insert = item.snippet
	elseif item.code then
		insert = item.code
	elseif st.whisper then
		insert = item.key
	else
		local name = item.short
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

	HidePopup()
	box:SetText(text:sub(1, st.startPos - 1) .. insert .. after)
	box:SetCursorPosition(st.startPos - 1 + #insert)
	if not box:HasFocus() then
		box:Show()
		box:SetFocus()
	end
end

local function Active(box)
	return state and state.box == box and popup:IsShown()
end

-------------------------------------------------------------------------------
-- Character counter
-------------------------------------------------------------------------------
local function UpdateCounter(box)
	local fs = box.ChatPilotCounter
	if not fs then return end
	local len = #(box:GetText() or "")
	if not ns.S or not ns.S.charCounter or len == 0 then fs:Hide() return end
	local max = (box.GetMaxBytes and box:GetMaxBytes()) or 255
	if not max or max <= 0 then max = 255 end
	fs:SetText(len .. "/" .. max)
	if len >= max then fs:SetTextColor(1, 0.25, 0.25)
	elseif len >= max * 0.8 then fs:SetTextColor(1, 0.65, 0.1)
	else fs:SetTextColor(0.55, 0.55, 0.55) end
	fs:Show()
end

-------------------------------------------------------------------------------
-- Hooking input boxes (HookScript only: Blizzard's own handlers stay untouched)
-------------------------------------------------------------------------------
function ns.HookEditBox(box)
	if not box or hooked[box] or not box.HookScript then return end
	hooked[box] = true

	box.ChatPilotCounter = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	box.ChatPilotCounter:SetPoint("RIGHT", box, "RIGHT", -10, 0)
	box.ChatPilotCounter:Hide()

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

	box:HookScript("OnEnterPressed", function(self) if state and state.box == self then HidePopup() end end)
	box:HookScript("OnEscapePressed", function(self) if state and state.box == self then HidePopup() end end)
	box:HookScript("OnHide", function(self)
		if state and state.box == self then HidePopup() end
		UpdateCounter(self)
	end)
	box:HookScript("OnEditFocusLost", function(self)
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
