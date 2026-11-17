local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

local GITHUB = "https://github.com/xXUltrOnionXx/ChatPilot"
local win
local rows = {}   -- toggle rows (for refresh / dependencies)
local pages, navButtons = {}, {}

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------
local function PageHeader(child, title, subtitle)
	local t = UI.Text(child, "GameFontHighlightHuge")
	t:SetPoint("TOPLEFT", 24, -20)
	t:SetText(title)
	local s = UI.Text(child, "GameFontHighlight", C.muted)
	s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
	s:SetPoint("RIGHT", child, "RIGHT", -24, 0)
	s:SetText(subtitle)
	return -78
end

local function RefreshRows()
	for _, r in ipairs(rows) do
		r.toggle:SetValue(ns.S[r.key])
		local on = not r.dep or ns.S[r.dep]
		r.toggle:SetEnabled(on and true or false)
		r:SetAlpha(on and 1 or 0.45)
	end
end

local function ToggleRow(child, y, key, dep, onChange)
	local indent = dep and 24 or 0
	local r = CreateFrame("Frame", nil, child)
	r:SetPoint("TOPLEFT", 24 + indent, y)
	r:SetPoint("RIGHT", child, "RIGHT", -24, 0)
	r:SetHeight(52)
	r.bg = UI.Fill(r, C.row)
	if dep then
		local bar = r:CreateTexture(nil, "ARTWORK")
		bar:SetColorTexture(unpack(C.border))
		bar:SetPoint("TOPLEFT")
		bar:SetPoint("BOTTOMLEFT")
		bar:SetWidth(2)
	end
	r.label = UI.Text(r, "GameFontHighlight")
	r.label:SetPoint("TOPLEFT", 14, -10)
	r.label:SetText(L["OPT_" .. key])
	r.desc = UI.Text(r, "GameFontHighlightSmall", C.muted)
	r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -5)
	r.desc:SetPoint("RIGHT", r, "RIGHT", -70, 0)
	r.desc:SetText(L["DESC_" .. key])
	r.desc:SetWordWrap(false)

	r.toggle = UI.Toggle(r, function(v)
		ns.S[key] = v
		if onChange then onChange(v) end
		RefreshRows()
	end)
	r.toggle:SetPoint("RIGHT", -14, 0)

	r:EnableMouse(true)
	r:SetScript("OnEnter", function() r.bg:SetColorTexture(unpack(C.rowHover)) end)
	r:SetScript("OnLeave", function() r.bg:SetColorTexture(unpack(C.row)) end)
	r:SetScript("OnMouseUp", function() if r.toggle:IsEnabled() then r.toggle:Click() end end)

	r.key, r.dep = key, dep
	rows[#rows + 1] = r
	return y - 58
end

local function Section(child, y, text)
	local t = UI.Text(child, "GameFontNormalSmall", C.accent)
	t:SetPoint("TOPLEFT", 24, y - 8)
	t:SetText(text:upper())
	return y - 30
end

-------------------------------------------------------------------------------
-- Keywords card (chips)
-------------------------------------------------------------------------------
local chipPool, kwCard = {}, nil

local function LayoutChips()
	if not kwCard then return end
	local area = kwCard.chips
	for _, c in ipairs(chipPool) do c:Hide() end
	local words = ns.S.keywords
	kwCard.empty:SetShown(#words == 0)
	local x, y, maxW = 0, 0, area:GetWidth()
	if not maxW or maxW < 50 then maxW = 420 end
	for i, word in ipairs(words) do
		local c = chipPool[i]
		if not c then
			c = CreateFrame("Button", nil, area)
			c:SetHeight(24)
			c.bg = UI.Fill(c, C.accentDim)
			UI.Border(c, C.accent)
			c.text = UI.Text(c, "GameFontHighlightSmall")
			c.text:SetPoint("LEFT", 9, 0)
			c.x = UI.Text(c, "GameFontHighlightSmall", C.muted)
			c.x:SetPoint("RIGHT", -8, 0)
			c.x:SetText("x")
			c:SetScript("OnEnter", function(self) self.x:SetTextColor(unpack(C.orange)) end)
			c:SetScript("OnLeave", function(self) self.x:SetTextColor(unpack(C.muted)) end)
			c:SetScript("OnClick", function(self)
				table.remove(ns.S.keywords, self.index)
				ns:RebuildWords()
				LayoutChips()
			end)
			chipPool[i] = c
		end
		c.index = i
		c.text:SetText(word)
		local w = c.text:GetStringWidth() + 34
		c:SetWidth(w)
		if x > 0 and x + w > maxW then x, y = 0, y - 30 end
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", area, "TOPLEFT", x, y)
		c:Show()
		x = x + w + 6
	end
	local h = (#words == 0) and 20 or (-y + 24)
	area:SetHeight(h)
	kwCard:SetHeight(110 + h)
end

local function AddKeywords(text)
	for w in (text or ""):gmatch("[^,]+") do
		w = strtrim(w)
		local exists = false
		for _, k in ipairs(ns.S.keywords) do if k:lower() == w:lower() then exists = true end end
		if w ~= "" and not exists then table.insert(ns.S.keywords, w) end
	end
	ns:RebuildWords()
	LayoutChips()
end

local function KeywordCard(child, y)
	local card = CreateFrame("Frame", nil, child)
	card:SetPoint("TOPLEFT", 24, y)
	card:SetPoint("RIGHT", child, "RIGHT", -24, 0)
	card:SetHeight(140)
	UI.Fill(card, C.row)
	local t = UI.Text(card, "GameFontHighlight")
	t:SetPoint("TOPLEFT", 14, -12)
	t:SetText(L.KW_TITLE)
	local d = UI.Text(card, "GameFontHighlightSmall", C.muted)
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
	d:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	d:SetText(L.KW_DESC)

	local input = UI.Input(card, 260, L.KW_PLACEHOLDER)
	input:SetPoint("TOPLEFT", 14, -54)
	local add = UI.Button(card, L.ADD, 110, 28, "accent")
	add:SetPoint("LEFT", input, "RIGHT", 8, 0)
	local function submit()
		AddKeywords(input.eb:GetText())
		input.eb:SetText("")
	end
	input.eb:SetScript("OnEnterPressed", function(self) submit(); self:ClearFocus() end)
	add:SetScript("OnClick", submit)

	card.chips = CreateFrame("Frame", nil, card)
	card.chips:SetPoint("TOPLEFT", 14, -94)
	card.chips:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	card.chips:SetHeight(20)
	card.empty = UI.Text(card.chips, "GameFontHighlightSmall", C.muted)
	card.empty:SetPoint("TOPLEFT", 0, -3)
	card.empty:SetText(L.KW_EMPTY)
	kwCard = card
	return card
end

-------------------------------------------------------------------------------
-- Snippets card (#shortcut -> text)
-------------------------------------------------------------------------------
local snCard, snRows = nil, {}

local function LayoutSnippets()
	if not snCard then return end
	local list = ns.db.snippets
	for _, r in ipairs(snRows) do r:Hide() end
	snCard.empty:SetShown(#list == 0)
	for i, sn in ipairs(list) do
		local r = snRows[i]
		if not r then
			r = CreateFrame("Frame", nil, snCard)
			r:SetHeight(26)
			UI.Fill(r, C.bg)
			r.text = UI.Text(r, "GameFontHighlight")
			r.text:SetPoint("LEFT", 10, 0)
			r.text:SetPoint("RIGHT", r, "RIGHT", -40, 0)
			r.text:SetWordWrap(false)
			r.del = CreateFrame("Button", nil, r)
			r.del:SetSize(26, 26)
			r.del:SetPoint("RIGHT")
			r.del.x = UI.Text(r.del, "GameFontHighlight", C.muted)
			r.del.x:SetPoint("CENTER")
			r.del.x:SetText("x")
			r.del:SetScript("OnEnter", function(self) self.x:SetTextColor(unpack(C.orange)) end)
			r.del:SetScript("OnLeave", function(self) self.x:SetTextColor(unpack(C.muted)) end)
			r.del:SetScript("OnClick", function(self)
				table.remove(ns.db.snippets, self:GetParent().index)
				LayoutSnippets()
			end)
			snRows[i] = r
		end
		r.index = i
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", snCard, "TOPLEFT", 14, -96 - (i - 1) * 30)
		r:SetPoint("RIGHT", snCard, "RIGHT", -14, 0)
		r.text:SetText("|cff4ec9ff#" .. sn.k .. "|r   " .. sn.t)
		r:Show()
	end
	snCard:SetHeight(110 + math.max(#list, 1) * 30)
	if snCard.onResize then snCard.onResize() end
end

local function SnippetCard(child, y)
	local card = CreateFrame("Frame", nil, child)
	card:SetPoint("TOPLEFT", 24, y)
	card:SetPoint("RIGHT", child, "RIGHT", -24, 0)
	card:SetHeight(140)
	UI.Fill(card, C.row)
	local t = UI.Text(card, "GameFontHighlight")
	t:SetPoint("TOPLEFT", 14, -12)
	t:SetText(L.SN_TITLE)
	local d = UI.Text(card, "GameFontHighlightSmall", C.muted)
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
	d:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	d:SetText(L.SN_DESC)

	local name = UI.Input(card, 110, L.SN_NAME_PH)
	name:SetPoint("TOPLEFT", 14, -54)
	name.eb:SetMaxLetters(20)
	local text = UI.Input(card, 250, L.SN_TEXT_PH)
	text:SetPoint("LEFT", name, "RIGHT", 6, 0)
	text:SetPoint("RIGHT", card, "RIGHT", -110, 0)
	text.eb:SetMaxLetters(255)
	local add = UI.Button(card, L.ADD, 90, 28, "accent")
	add:SetPoint("LEFT", text, "RIGHT", 6, 0)
	local function submit()
		local k = strtrim(name.eb:GetText() or ""):gsub("^#", ""):gsub("%s", "")
		local v = strtrim(text.eb:GetText() or "")
		if k == "" or v == "" then name.eb:SetFocus() return end
		for i = #ns.db.snippets, 1, -1 do
			if ns.db.snippets[i].k:lower() == k:lower() then table.remove(ns.db.snippets, i) end
		end
		table.insert(ns.db.snippets, { k = k, t = v })
		name.eb:SetText(""); text.eb:SetText("")
		name.eb:ClearFocus(); text.eb:ClearFocus()
		LayoutSnippets()
	end
	name.eb:SetScript("OnEnterPressed", function() text.eb:SetFocus() end)
	name.eb:SetScript("OnTabPressed", function() text.eb:SetFocus() end)
	text.eb:SetScript("OnEnterPressed", submit)
	add:SetScript("OnClick", submit)

	card.empty = UI.Text(card, "GameFontHighlightSmall", C.muted)
	card.empty:SetPoint("TOPLEFT", 14, -100)
	card.empty:SetText(L.SN_EMPTY)
	snCard = card
	return card
end

-------------------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------------------
local function NewPage(content)
	local sf = UI.ScrollArea(content)
	sf:SetPoint("TOPLEFT", 190, 0)
	sf:SetPoint("BOTTOMRIGHT", 0, 0)
	sf:Hide()
	pages[#pages + 1] = sf
	return sf, sf.child
end

local function BuildTyping(content)
	local sf, c = NewPage(content)
	local y = PageHeader(c, L.PAGE_TYPING, L.PAGE_TYPING_SUB)
	y = ToggleRow(c, y, "autocomplete")
	y = ToggleRow(c, y, "keepAt", "autocomplete")
	y = ToggleRow(c, y, "whisperNames")
	y = ToggleRow(c, y, "raidIcons")
	y = ToggleRow(c, y, "charCounter")
	y = ToggleRow(c, y, "snippets")
	local card = SnippetCard(c, y)
	card.onResize = function() c:SetHeight(-y + card:GetHeight() + 30) end
	sf:SetScript("OnShow", LayoutSnippets)
	return sf
end

local function BuildMentions(content)
	local sf, c = NewPage(content)
	local y = PageHeader(c, L.PAGE_MENTIONS, L.PAGE_MENTIONS_SUB)
	y = ToggleRow(c, y, "mentions")
	y = ToggleRow(c, y, "highlight", "mentions")
	y = ToggleRow(c, y, "mentionSound", "mentions")
	y = ToggleRow(c, y, "mentionFlash", "mentions")
	y = ToggleRow(c, y, "mentionToast", "mentions")
	y = ToggleRow(c, y, "mentionPublic", "mentions")
	y = Section(c, y - 6, L.KW_TITLE)
	local card = KeywordCard(c, y)

	local bar = CreateFrame("Frame", nil, c)
	bar:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -14)
	bar:SetSize(400, 28)
	local hist = UI.Button(bar, L.OPT_SHOW_MENTIONS, 170, 28)
	hist:SetPoint("LEFT")
	hist:SetScript("OnClick", function() ns:ShowMentions() end)
	local test = UI.Button(bar, L.OPT_TEST, 140, 28)
	test:SetPoint("LEFT", hist, "RIGHT", 8, 0)
	test:SetScript("OnClick", function() ns:TestAlert() end)

	sf:SetScript("OnShow", function()
		LayoutChips()
		c:SetHeight(-y + card:GetHeight() + 70)
	end)
	return sf
end

local function BuildWhispers(content)
	local sf, c = NewPage(content)
	local y = PageHeader(c, L.PAGE_WHISPERS, L.PAGE_WHISPERS_SUB)
	y = ToggleRow(c, y, "whispers", nil, function() ns:UpdateChatButtons() end)
	y = ToggleRow(c, y, "whisperSummary", "whispers")
	local open = UI.Button(c, L.WH_OPEN, 200, 30, "accent")
	open:SetPoint("TOPLEFT", 24, y - 8)
	open:SetScript("OnClick", function() ns:ShowWhispers() end)
	local hint = UI.Text(c, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)
	hint:SetPoint("RIGHT", c, "RIGHT", -24, 0)
	hint:SetSpacing(3)
	hint:SetText(L.WH_HINT)
	c:SetHeight(-y + 120)
	return sf
end

local function BuildChat(content)
	local sf, c = NewPage(content)
	local y = PageHeader(c, L.PAGE_CHAT, L.PAGE_CHAT_SUB)
	y = ToggleRow(c, y, "abbrevTips")
	y = ToggleRow(c, y, "showLevels")
	y = ToggleRow(c, y, "spamFilter")
	y = ToggleRow(c, y, "keepHistory")
	y = ToggleRow(c, y, "urls")
	y = ToggleRow(c, y, "markForeign")
	y = ToggleRow(c, y, "hideForeign", "markForeign")
	y = ToggleRow(c, y, "hideRepeats")
	y = ToggleRow(c, y, "copyButton", nil, function() ns:UpdateChatButtons() end)
	y = ToggleRow(c, y, "buttonsTop", "copyButton", function() ns:UpdateChatButtons() end)
	y = ToggleRow(c, y, "versionCheck")
	c:SetHeight(-y + 20)
	return sf
end

local function BuildAbout(content)
	local sf, c = NewPage(content)
	local badge = UI.Badge(c, 56)
	badge:SetPoint("TOPLEFT", 24, -24)
	local name = UI.Text(c, "GameFontHighlightHuge")
	name:SetPoint("TOPLEFT", badge, "TOPRIGHT", 16, -4)
	name:SetText(ns.TITLE)
	local ver = UI.Text(c, "GameFontHighlight", C.muted)
	ver:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
	ver:SetText("Version " .. ns.version .. "  -  MIT")

	local desc = UI.Text(c, "GameFontHighlight")
	desc:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -18)
	desc:SetPoint("RIGHT", c, "RIGHT", -24, 0)
	desc:SetSpacing(3)
	desc:SetText(L.ABOUT_DESC)

	local fb = UI.Button(c, L.OPT_FEEDBACK, 170, 30, "accent")
	fb:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
	fb:SetScript("OnClick", function() win:Hide(); ns:ShowFeedback() end)
	local gh = UI.Button(c, L.ABOUT_GITHUB, 170, 30)
	gh:SetPoint("LEFT", fb, "RIGHT", 8, 0)
	gh:SetScript("OnClick", function() ns:ShowCopy(GITHUB, L.COPY_URL_TITLE, true) end)

	local head = UI.Text(c, "GameFontNormalSmall", C.accent)
	head:SetPoint("TOPLEFT", fb, "BOTTOMLEFT", 0, -26)
	head:SetText(L.ABOUT_COMMANDS:upper())
	local cmds = UI.Text(c, "GameFontHighlight", C.muted)
	cmds:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
	cmds:SetSpacing(5)
	cmds:SetText(L.ABOUT_COMMAND_LIST)
	c:SetHeight(460)
	return sf
end

-------------------------------------------------------------------------------
-- Window with sidebar
-------------------------------------------------------------------------------
local function SelectPage(index)
	for i, p in ipairs(pages) do p:SetShown(i == index) end
	for i, b in ipairs(navButtons) do
		local sel = i == index
		b.bar:SetShown(sel)
		b.bg:SetShown(sel)
		b.label:SetTextColor(unpack(sel and C.text or C.muted))
	end
end

local function NavButton(sidebar, i, text)
	local b = CreateFrame("Button", nil, sidebar)
	b:SetHeight(38)
	b:SetPoint("TOPLEFT", 0, -12 - (i - 1) * 40)
	b:SetPoint("RIGHT")
	b.bg = UI.Fill(b, C.rowHover)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetColorTexture(unpack(C.accent))
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetWidth(3)
	b.label = UI.Text(b, "GameFontHighlight", C.muted)
	b.label:SetPoint("LEFT", 20, 0)
	b.label:SetText(text)
	b:SetScript("OnEnter", function(self) if not self.bar:IsShown() then self.label:SetTextColor(unpack(C.text)) end end)
	b:SetScript("OnLeave", function(self) if not self.bar:IsShown() then self.label:SetTextColor(unpack(C.muted)) end end)
	b:SetScript("OnClick", function() SelectPage(i) end)
	navButtons[i] = b
	return b
end

local function Build()
	win = UI.Window("ChatPilotOptions", ns.TITLE, 760, 580)
	win.subtitle:SetText(ns.version)
	local content = win.content

	local sidebar = CreateFrame("Frame", nil, content)
	sidebar:SetPoint("TOPLEFT")
	sidebar:SetPoint("BOTTOMLEFT")
	sidebar:SetWidth(190)
	UI.Fill(sidebar, C.panel)
	local sep = sidebar:CreateTexture(nil, "ARTWORK")
	sep:SetColorTexture(unpack(C.border))
	sep:SetPoint("TOPRIGHT")
	sep:SetPoint("BOTTOMRIGHT")
	sep:SetWidth(1)

	BuildTyping(content)
	BuildMentions(content)
	BuildWhispers(content)
	BuildChat(content)
	BuildAbout(content)
	NavButton(sidebar, 1, L.PAGE_TYPING)
	NavButton(sidebar, 2, L.PAGE_MENTIONS)
	NavButton(sidebar, 3, L.PAGE_WHISPERS)
	NavButton(sidebar, 4, L.PAGE_CHAT)
	NavButton(sidebar, 5, L.PAGE_ABOUT)

	local hint = UI.Text(sidebar, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("BOTTOMLEFT", 20, 16)
	hint:SetPoint("RIGHT", -12, 0)
	hint:SetText(L.SIDEBAR_HINT)

	win:SetScript("OnShow", RefreshRows)
	SelectPage(1)
end

function ns:OpenOptions(page)
	if not win then Build() end
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
	if page then SelectPage(page) end
	win:Show()
	win:Raise()
end

function ns:ToggleOptions()
	if win and win:IsShown() then win:Hide() else self:OpenOptions() end
end

-------------------------------------------------------------------------------
-- Entry in Blizzard's options (points to our window)
-------------------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "ChatPilot Forever"
panel:Hide()
do
	local badge = UI.Badge(panel, 48)
	badge:SetPoint("TOPLEFT", 20, -20)
	local t = UI.Text(panel, "GameFontHighlightHuge")
	t:SetPoint("TOPLEFT", badge, "TOPRIGHT", 14, -2)
	t:SetText(ns.TITLE)
	local d = UI.Text(panel, "GameFontHighlight", C.muted)
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
	d:SetText(L.SETTINGS_DESC)
	local b = UI.Button(panel, L.OPEN, 200, 32, "accent")
	b:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -20)
	b:SetScript("OnClick", function() ns:OpenOptions() end)
end
if Settings and Settings.RegisterCanvasLayoutCategory then
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
end

-- Minimap addon menu (Addon Compartment), declared in the .toc.
function ChatPilot_OnAddonCompartmentClick() ns:ToggleOptions() end
function ChatPilot_OnAddonCompartmentEnter(_, button)
	if type(button) ~= "table" or not button.GetObjectType then return end
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText(ns.TITLE)
	GameTooltip:AddLine(L.COMPARTMENT_TIP, 1, 1, 1)
	GameTooltip:Show()
end
function ChatPilot_OnAddonCompartmentLeave() GameTooltip:Hide() end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_CHATPILOT1 = "/chatpilot"
SLASH_CHATPILOT2 = "/cpilot"
SlashCmdList.CHATPILOT = function(input)
	local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "options" or cmd == "config" then
		ns:ToggleOptions()
	elseif cmd == "mentions" or cmd == "m" then
		ns:ShowMentions()
	elseif cmd == "whispers" or cmd == "w" then
		ns:ShowWhispers()
	elseif cmd == "copy" then
		ns:CopyChat()
	elseif cmd == "feedback" or cmd == "fb" then
		ns:ShowFeedback()
	elseif cmd == "test" then
		ns:TestAlert()
	elseif cmd == "add" and rest ~= "" then
		AddKeywords(rest)
		ns.Print(L.KW_ADDED, rest)
	elseif (cmd == "del" or cmd == "remove") and rest ~= "" then
		for i = #ns.S.keywords, 1, -1 do
			if ns.S.keywords[i]:lower() == rest:lower() then table.remove(ns.S.keywords, i) end
		end
		ns:RebuildWords()
		LayoutChips()
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
	self:UpdateChatButtons()
end
