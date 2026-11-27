local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- Modern look for the game's own chat windows: flat background, flat tabs
-- and a flat input box in the colours of the chosen design.
-- Only textures are changed (no Blizzard functions are replaced), so the chat
-- itself, its tabs, docking and all menus keep working exactly as before.

local skinned = {}
local pending = {}

local FRAME_TEXTURES = {
	"Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
	"LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
	"ButtonFrameBackground", "ButtonFrameTopLeftTexture", "ButtonFrameBottomLeftTexture",
	"ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
	"ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture",
}
local TAB_KEYS = {
	"Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
	"leftSelectedTexture", "middleSelectedTexture", "rightSelectedTexture",
	"leftHighlightTexture", "middleHighlightTexture", "rightHighlightTexture",
}
local TAB_SUFFIX = { "Left", "Middle", "Right", "SelectedLeft", "SelectedMiddle", "SelectedRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight" }
local EDIT_KEYS = { "Left", "Mid", "Right", "focusLeft", "focusMid", "focusRight",
	"FocusLeft", "FocusMid", "FocusRight" }
local EDIT_SUFFIX = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

-- Everything is reversible: the game's textures are remembered before they are
-- emptied, and put back when you switch to the normal WoW design.
local saved = setmetatable({}, { __mode = "k" })
local own = {}
local active = false

local function Clear(tex)
	if tex and tex.SetTexture and not rawget(tex, "ChatPilot") then
		if not saved[tex] then
			local atlas = tex.GetAtlas and tex:GetAtlas()
			saved[tex] = { file = tex.GetTexture and tex:GetTexture(), atlas = atlas, alpha = tex.GetAlpha and tex:GetAlpha() or 1 }
		end
		tex:SetTexture(nil)
		if tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
		tex:SetAlpha(0)
	end
end

local function Restore(tex, o)
	if o.atlas and tex.SetAtlas then
		pcall(tex.SetAtlas, tex, o.atlas)
	elseif o.file then
		tex:SetTexture(o.file)
	end
	tex:SetAlpha(o.alpha or 1)
end

local function Mine(tex)
	tex.ChatPilot = true
	own[#own + 1] = tex
	return tex
end

local shadows = setmetatable({}, { __mode = "k" })
local function KeepShadow(text)
	if text and text.GetShadowOffset and not shadows[text] then
		local x, y = text:GetShadowOffset()
		local r, g, b, a = text:GetShadowColor()
		shadows[text] = { x, y, r, g, b, a }
	end
end

local function SkinTab(tab, frame)
	if not tab or rawget(tab, "ChatPilotSkin") then return end
	local name = tab:GetName() or ""
	for _, k in ipairs(TAB_KEYS) do Clear(rawget(tab, k)) end
	for _, s in ipairs(TAB_SUFFIX) do Clear(_G[name .. s]) end

	local skin = {}
	skin.hl = Mine(tab:CreateTexture(nil, "HIGHLIGHT"))
	skin.hl:SetPoint("TOPLEFT", 2, -6)
	skin.hl:SetPoint("BOTTOMRIGHT", -2, 2)
	UI.Paint(skin.hl, C.accentDim)
	skin.line = Mine(UI.Glow(tab, "OVERLAY"))
	skin.line:SetPoint("BOTTOMLEFT", 4, 2)
	skin.line:SetPoint("BOTTOMRIGHT", -4, 2)
	skin.line:SetHeight(2)
	skin.line:Hide()
	local text = rawget(tab, "Text") or _G[name .. "Text"]
	if text and text.SetShadowOffset then KeepShadow(text); UI.NoShadow(text) end
	skin.text = text
	tab.ChatPilotSkin = skin

	-- selected tab: accent line underneath
	local function Update()
		if not active then skin.line:Hide() return end
		local sel
		local dock = GENERAL_CHAT_DOCK
		if frame.isDocked and dock and FCFDock_GetSelectedWindow then
			sel = FCFDock_GetSelectedWindow(dock) == frame
		else
			sel = frame:IsShown()
		end
		skin.line:SetShown(sel and true or false)
	end
	skin.Update = Update
	tab:HookScript("OnClick", function() C_Timer.After(0, Update) end)
	tab:HookScript("OnShow", Update)
	Update()
end

local function SkinEditBox(box)
	if not box or rawget(box, "ChatPilotSkin") then return end
	local name = box:GetName() or ""
	for _, k in ipairs(EDIT_KEYS) do Clear(rawget(box, k)) end
	for _, s in ipairs(EDIT_SUFFIX) do Clear(_G[name .. s]) end

	local bg = Mine(box:CreateTexture(nil, "BACKGROUND"))
	bg:SetPoint("TOPLEFT", 2, -3)
	bg:SetPoint("BOTTOMRIGHT", -2, 3)
	UI.Paint(bg, C.btn)
	local edges = {}
	local function Edge(a, b, w, h)
		local t = Mine(box:CreateTexture(nil, "BORDER"))
		t:SetPoint(a, bg, a)
		t:SetPoint(b, bg, b)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		edges[#edges + 1] = UI.Paint(t, C.border)
	end
	Edge("TOPLEFT", "TOPRIGHT", nil, 1)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	local function Focus(on)
		for _, t in ipairs(edges) do UI.Paint(t, on and C.accent or C.border) end
	end
	box:HookScript("OnEditFocusGained", function() Focus(true) end)
	box:HookScript("OnEditFocusLost", function() Focus(false) end)
	box.ChatPilotSkin = { bg = bg }
end

local function SkinFrame(frame)
	if skinned[frame] then return end
	active = true
	local name = frame:GetName()
	if not name then return end
	skinned[frame] = true

	local list = type(CHAT_FRAME_TEXTURES) == "table" and CHAT_FRAME_TEXTURES or FRAME_TEXTURES
	for _, s in ipairs(list) do Clear(_G[name .. s]) end
	for _, s in ipairs(FRAME_TEXTURES) do Clear(_G[name .. s]) end
	local bf = rawget(frame, "buttonFrame") or _G[name .. "ButtonFrame"]
	if bf and bf.GetRegions then
		for _, r in ipairs({ bf:GetRegions() }) do
			if r.IsObjectType and r:IsObjectType("Texture") then Clear(r) end
		end
	end

	-- our flat background: textures on the chat frame itself, in its lowest
	-- layer, so they are always drawn underneath the chat text
	local skin = {}
	local bg = Mine(frame:CreateTexture(nil, "BACKGROUND", nil, -8))
	bg:SetPoint("TOPLEFT", -4, 4)
	bg:SetPoint("BOTTOMRIGHT", 4, -6)
	UI.Paint(bg, C.chatBg)
	skin.bg = bg
	local function Edge(a, b, w, h)
		local t = Mine(frame:CreateTexture(nil, "BACKGROUND", nil, -7))
		t:SetPoint(a, bg, a)
		t:SetPoint(b, bg, b)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		UI.Paint(t, C.border)
	end
	Edge("TOPLEFT", "TOPRIGHT", nil, 1)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	local glow = Mine(UI.Glow(frame, "BACKGROUND"))
	glow:SetDrawLayer("BACKGROUND", -6)
	glow:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
	glow:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -1, -1)
	glow:SetHeight(1)
	glow:SetAlpha(0.7)
	frame.ChatPilotSkin = skin

	SkinTab(rawget(frame, "tab") or _G[name .. "Tab"], frame)
	SkinEditBox(rawget(frame, "editBox") or _G[name .. "EditBox"])
end

local function UpdateTabs()
	for frame in pairs(skinned) do
		local tab = rawget(frame, "tab") or _G[(frame:GetName() or "") .. "Tab"]
		local s = tab and rawget(tab, "ChatPilotSkin")
		if s then s.Update() end
	end
end

-- Other addons that restyle the chat window. If one of them is active,
-- ChatPilot leaves the chat's look alone so the two don't fight.
local SKIN_ADDONS = { "prat", "chatter", "elvui", "glass", "primechat", "gudachat", "bloomchat",
	"mcawesome", "chatforever", "chat_forever", "foreverchat", "forever_chat", "betterforeverchat",
	"foreverchatbox", "luxchat", "tukui", "basicchatmods" }

function ns:ChatSkinConflict()
	if ns.S and ns.S.skinForce then return nil end -- /chatpilot skin force: style the chat anyway
	local get = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
	local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if not get or not info or not loaded then return nil end
	for i = 1, get() do
		local name, title = info(i)
		if name and loaded(name) then
			local low = name:lower():gsub("[%s%-%.]", "")
			for _, pat in ipairs(SKIN_ADDONS) do
				if low:find(pat:gsub("_", ""), 1, true) then
					return (type(title) == "string" and title ~= "" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or name
				end
			end
		end
	end
end

function ns:SkinAllChats()
	local other = self:ChatSkinConflict()
	if other then
		self.skinConflict = other
		ns.Print(L.CHATSKIN_CONFLICT, other)
		ns.Print("/chatpilot skin force  -  apply the modern look anyway")
		return
	end
	if not active and next(saved) then
		-- switched back on: empty the game's textures again, show ours
		active = true
		for tex in pairs(saved) do
			tex:SetTexture(nil)
			if tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
			tex:SetAlpha(0)
		end
		for _, t in ipairs(own) do if rawget(t, "cpWasShown") ~= false then t:Show() end end
		for text in pairs(shadows) do UI.NoShadow(text) end
	end
	active = true
	for _, frame in ipairs(pending) do local ok, err = pcall(SkinFrame, frame); if not ok and ns.DEBUG then print(err) end end
	UpdateTabs()
end

-- back to the game's normal design, right away (no /reload needed)
function ns:UnskinAllChats()
	if not active then return end
	active = false
	for _, t in ipairs(own) do
		t.cpWasShown = t:IsShown() and true or false
		t:Hide()
	end
	for tex, o in pairs(saved) do pcall(Restore, tex, o) end
	for text, sh in pairs(shadows) do
		pcall(text.SetShadowOffset, text, sh[1], sh[2])
		if sh[3] then pcall(text.SetShadowColor, text, sh[3], sh[4], sh[5], sh[6]) end
	end
	UpdateTabs()
end

ns.OnChatFrame(function(frame)
	pending[#pending + 1] = frame
	if ns.S and ns.S.chatSkin and ns.loggedIn and not ns.skinConflict then pcall(SkinFrame, frame) end
end)

if type(FCF_SelectDockFrame) == "function" then
	hooksecurefunc("FCF_SelectDockFrame", function() UpdateTabs() end)
end
if type(FCFTab_UpdateColors) == "function" then
	hooksecurefunc("FCFTab_UpdateColors", function() UpdateTabs() end)
end

-- design (theme) is applied first, then the chat windows get their skin
local prevLogin = ns.OnLogin
function ns:OnLogin()
	UI.ApplyTheme(self.S.theme)
	if prevLogin then prevLogin(self) end
	self.loggedIn = true
	if self.S.chatSkin then self:SkinAllChats() end
end

function ns:SetTheme(name)
	if not UI.THEMES[name] then return end
	self.S.theme = name
	UI.ApplyTheme(name)
	if self.UpdateChatButtons then self:UpdateChatButtons() end
end

ns._skinned = skinned -- for tests
