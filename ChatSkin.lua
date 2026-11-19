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

local function Clear(tex)
	if tex and tex.SetTexture and not rawget(tex, "ChatPilot") then
		tex:SetTexture(nil)
		if tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
		tex:SetAlpha(0)
	end
end

local function Mine(tex)
	tex.ChatPilot = true
	return tex
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
	if text and text.SetShadowOffset then UI.NoShadow(text) end
	tab.ChatPilotSkin = skin

	-- selected tab: accent line underneath
	local function Update()
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

function ns:SkinAllChats()
	for _, frame in ipairs(pending) do local ok, err = pcall(SkinFrame, frame); if not ok and ns.DEBUG then print(err) end end
	UpdateTabs()
end

ns.OnChatFrame(function(frame)
	pending[#pending + 1] = frame
	if ns.S and ns.S.chatSkin and ns.loggedIn then pcall(SkinFrame, frame) end
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
