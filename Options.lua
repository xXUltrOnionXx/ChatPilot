local ADDON, ns = ...
local L = ns.L

local panel = CreateFrame("Frame")
panel.name = "ChatPilot"
panel:Hide()

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -4)
scroll:SetPoint("BOTTOMRIGHT", -28, 4)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(600, 760)
scroll:SetScrollChild(content)

local checks = {}
local y = -16

local function Header(text)
	local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	y = y - 26
end

local function Check(key, label, indent, onChange)
	local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", 16 + (indent or 0), y)
	local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(label)
	cb:SetScript("OnClick", function(self)
		ns.S[key] = self:GetChecked() and true or false
		if onChange then onChange() end
	end)
	cb.key = key
	checks[#checks + 1] = cb
	y = y - 24
end

local function Button(text, x, fn)
	local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	b:SetSize(150, 24)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", fn)
	return b
end

local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
title:SetPoint("TOPLEFT", 16, y)
title:SetText("|cff4ec9ffChat|rPilot")
y = y - 36

Header(L.OPT_HEADER_INPUT)
Check("autocomplete", L.OPT_AUTOCOMPLETE)
Check("keepAt", L.OPT_KEEPAT, 20)
Check("whisperNames", L.OPT_WHISPERNAMES)
Check("raidIcons", L.OPT_RAIDICONS)
Check("charCounter", L.OPT_COUNTER)
y = y - 8

Header(L.OPT_HEADER_MENTIONS)
Check("mentions", L.OPT_MENTIONS)
Check("highlight", L.OPT_HIGHLIGHT, 20)
Check("mentionSound", L.OPT_SOUND, 20)
Check("mentionFlash", L.OPT_FLASH, 20)
Check("mentionToast", L.OPT_TOAST, 20)
Check("mentionPublic", L.OPT_PUBLIC, 20)

local kwLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
kwLabel:SetPoint("TOPLEFT", 20, y - 4)
kwLabel:SetText(L.OPT_KEYWORDS)
y = y - 22
local kw = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
kw:SetSize(360, 20)
kw:SetPoint("TOPLEFT", 26, y)
kw:SetAutoFocus(false)
kw:SetMaxLetters(200)
local function SaveKeywords()
	local list = {}
	for w in (kw:GetText() or ""):gmatch("[^,]+") do
		w = strtrim(w)
		if w ~= "" then list[#list + 1] = w end
	end
	ns.S.keywords = list
	ns:RebuildWords()
end
kw:SetScript("OnEnterPressed", function(self) SaveKeywords(); self:ClearFocus() end)
kw:SetScript("OnEditFocusLost", SaveKeywords)
kw:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
y = y - 22
local kwHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
kwHint:SetPoint("TOPLEFT", 22, y)
kwHint:SetText(L.OPT_KEYWORDS_HINT)
y = y - 22

Header(L.OPT_HEADER_MISC)
Check("urls", L.OPT_URLS)
Check("copyButton", L.OPT_COPYBTN, 0, function() ns:UpdateCopyButtons() end)
Check("abbrevTips", L.OPT_ABBR)
Check("markForeign", L.OPT_MARKFOREIGN)
Check("hideForeign", L.OPT_HIDEFOREIGN, 20)
Check("hideRepeats", L.OPT_REPEATS)
y = y - 10

Button(L.OPT_SHOW_MENTIONS, 16, function() ns:ShowMentions() end)
Button(L.OPT_COPY_CHAT, 172, function() ns:CopyChat() end)
Button(L.OPT_TEST, 328, function() ns:TestAlert() end)
y = y - 30
Button(L.OPT_FEEDBACK, 16, function() ns:ShowFeedback() end)

panel:SetScript("OnShow", function()
	for _, cb in ipairs(checks) do cb:SetChecked(ns.S[cb.key]) end
	kw:SetText(table.concat(ns.S.keywords, ", "))
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
end

function ns:OpenOptions()
	if category and Settings and Settings.OpenToCategory then
		local id = category.GetID and category:GetID() or category.ID
		if not pcall(Settings.OpenToCategory, id) then pcall(Settings.OpenToCategory, panel.name) end
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_CHATPILOT1 = "/chatpilot"
SLASH_CHATPILOT2 = "/cpilot"
SlashCmdList.CHATPILOT = function(input)
	local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "options" or cmd == "config" then
		ns:OpenOptions()
	elseif cmd == "mentions" or cmd == "m" then
		ns:ShowMentions()
	elseif cmd == "copy" then
		ns:CopyChat()
	elseif cmd == "feedback" or cmd == "fb" then
		ns:ShowFeedback()
	elseif cmd == "test" then
		ns:TestAlert()
	elseif cmd == "add" and rest ~= "" then
		table.insert(ns.S.keywords, rest)
		ns:RebuildWords()
		ns.Print(L.KW_ADDED, rest)
	elseif (cmd == "del" or cmd == "remove") and rest ~= "" then
		for i = #ns.S.keywords, 1, -1 do
			if ns.S.keywords[i]:lower() == rest:lower() then table.remove(ns.S.keywords, i) end
		end
		ns:RebuildWords()
		ns.Print(L.KW_REMOVED, rest)
	elseif cmd == "list" then
		local kws = #ns.S.keywords > 0 and table.concat(ns.S.keywords, ", ") or L.NONE
		ns.Print(L.KW_LIST, kws)
	else
		ns.Print(L.HELP)
	end
end

-- Hook the community window if it was already loaded before us.
local prevLogin = ns.OnLogin
function ns:OnLogin()
	if prevLogin then prevLogin(self) end
	if CommunitiesFrame and CommunitiesFrame.ChatEditBox then ns.HookEditBox(CommunitiesFrame.ChatEditBox) end
	self:UpdateCopyButtons()
end
