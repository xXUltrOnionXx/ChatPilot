local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

local GITHUB = "https://github.com/xXUltrOnionXx/ChatPilot"
local win
local rows = {}   -- toggle rows (for refresh / dependencies)
local pages, navButtons = {}, {}

-------------------------------------------------------------------------------
-- Flow layout with collapsible sub-menus
-- Every page is a list of items stacked from top to bottom. Items can belong
-- to a parent (row or card); they are only shown while the parent is expanded.
-------------------------------------------------------------------------------
local flows = {}

local function IsExpanded(f)
	local key = rawget(f, "expandKey")
	return key and ns.S.expanded and ns.S.expanded[key] and true or false
end

local function Relayout(flow)
	local y = flow.y0
	for _, it in ipairs(flow.items) do
		local p = it.parent
		local vis = not p or (rawget(p, "flowVisible") and IsExpanded(p))
		it.f.flowVisible = vis
		it.f:SetShown(vis)
		if vis then
			local h = it.height and it.height() or it.f:GetHeight()
			it.f:SetHeight(h)
			it.f:ClearAllPoints()
			it.f:SetPoint("TOPLEFT", flow.child, "TOPLEFT", 24 + it.indent, y)
			it.f:SetPoint("RIGHT", flow.child, "RIGHT", -24, 0)
			y = y - h - it.gap
		end
	end
	flow.child:SetHeight(-y + 24)
end

local function RelayoutAll() for _, fl in ipairs(flows) do Relayout(fl) end end
ns.RelayoutOptions = RelayoutAll
ns._optionFlows = flows -- for tests

local function NewFlow(child, y0)
	local flow = { child = child, y0 = y0, items = {} }
	flows[#flows + 1] = flow
	return flow
end

local function FlowAdd(flow, frame, parent, opts)
	opts = opts or {}
	flow.items[#flow.items + 1] = {
		f = frame, parent = parent, height = opts.height,
		indent = opts.indent or (parent and 24 or 0), gap = opts.gap or 6,
	}
	frame:SetParent(flow.child)
	frame.flow = flow
end

local function SetExpanded(f, value)
	ns.S.expanded = ns.S.expanded or {}
	ns.S.expanded[f.expandKey] = value and true or nil
	if type(rawget(f, "chevron")) == "table" then f.chevron:SetExpanded(value) end
	Relayout(f.flow)
end

local function ToggleExpanded(f) SetExpanded(f, not IsExpanded(f)) end

-- Small arrow button: > (collapsed) or v (expanded)
local function Chevron(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(28, 28)
	local hl = UI.Fill(b, C.rowHover)
	hl:SetAlpha(0)
	b.l1 = b:CreateTexture(nil, "OVERLAY")
	b.l2 = b:CreateTexture(nil, "OVERLAY")
	for _, t in ipairs({ b.l1, b.l2 }) do
		t:SetColorTexture(unpack(C.accent))
		t:SetSize(9, 2)
	end
	function b:SetExpanded(open)
		self.l1:ClearAllPoints(); self.l2:ClearAllPoints()
		if open then -- v
			self.l1:SetPoint("CENTER", -3, 0); self.l1:SetRotation(math.rad(-45))
			self.l2:SetPoint("CENTER", 3, 0); self.l2:SetRotation(math.rad(45))
		else -- >
			self.l1:SetPoint("CENTER", 0, 3); self.l1:SetRotation(math.rad(-45))
			self.l2:SetPoint("CENTER", 0, -3); self.l2:SetRotation(math.rad(45))
		end
	end
	b:SetScript("OnEnter", function() hl:SetAlpha(1) end)
	b:SetScript("OnLeave", function() hl:SetAlpha(0) end)
	b:SetExpanded(false)
	return b
end

-- Turns a row or card into a collapsible parent (arrow + number of sub-items).
local function MakeExpandable(f, anchorTo, xOff)
	if type(rawget(f, "subCount")) == "number" then
		f.subCount = f.subCount + 1
		f.countText:SetText(f.subCount)
		return
	end
	f.expandKey = f.key
	f.subCount = 1
	f.chevron = Chevron(f)
	f.chevron:SetPoint("RIGHT", anchorTo or f, anchorTo and "LEFT" or "RIGHT", xOff or -12, 0)
	f.chevron:SetScript("OnClick", function() ToggleExpanded(f) end)
	f.countText = UI.Text(f, "GameFontHighlightSmall", C.muted)
	f.countText:SetPoint("RIGHT", f.chevron, "LEFT", -2, 0)
	f.countText:SetText("1")
	if f.desc then f.desc:SetPoint("RIGHT", f, "RIGHT", -130, 0) end
	f.chevron:SetExpanded(IsExpanded(f))
end

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
		if type(rawget(r, "chevron")) == "table" then r.chevron:SetExpanded(IsExpanded(r)) end
	end
end

-- Toggle row. parentRow = row it belongs to (shown as collapsible sub-menu).
local function ToggleRow(flow, key, parentRow, onChange)
	local r = CreateFrame("Frame", nil, flow.child)
	r:SetHeight(52)
	r.bg = UI.Fill(r, C.row)
	if parentRow then
		local bar = r:CreateTexture(nil, "ARTWORK")
		bar:SetColorTexture(unpack(C.accent))
		bar:SetAlpha(0.6)
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

	r.key = key
	r.dep = parentRow and parentRow.key
	rows[#rows + 1] = r
	FlowAdd(flow, r, parentRow)
	if parentRow then MakeExpandable(parentRow, parentRow.toggle, -14) end
	return r
end

-- Card with a clickable header (title + description) that collapses its body.
local function Card(flow, id, title, desc, parentRow)
	local card = CreateFrame("Frame", nil, flow.child)
	UI.Fill(card, C.row)
	card.expandKey = id
	card.fullHeight = 120
	local header = CreateFrame("Button", nil, card)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(50)
	header:SetScript("OnClick", function() ToggleExpanded(card) end)
	local t = UI.Text(header, "GameFontHighlight")
	t:SetPoint("TOPLEFT", 14, -12)
	t:SetText(title)
	card.desc = UI.Text(header, "GameFontHighlightSmall", C.muted)
	card.desc:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
	card.desc:SetPoint("RIGHT", card, "RIGHT", -60, 0)
	card.desc:SetWordWrap(false)
	card.desc:SetText(desc)
	card.chevron = Chevron(card)
	card.chevron:SetPoint("TOPRIGHT", -12, -11)
	card.chevron:SetScript("OnClick", function() ToggleExpanded(card) end)
	card.chevron:SetExpanded(IsExpanded(card))
	card.body = CreateFrame("Frame", nil, card)
	card.body:SetPoint("TOPLEFT", 0, -50)
	card.body:SetPoint("BOTTOMRIGHT")
	FlowAdd(flow, card, parentRow, { height = function()
		local open = IsExpanded(card)
		card.body:SetShown(open)
		return open and card.fullHeight or 50
	end })
	if parentRow then MakeExpandable(parentRow, parentRow.toggle, -14) end
	return card
end

local function SetCardHeight(card, h)
	card.fullHeight = h
	if card.flow then Relayout(card.flow) end
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
	SetCardHeight(kwCard, 50 + 44 + h + 14)
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

local function KeywordCard(flow, parentRow)
	local card = Card(flow, "card_keywords", L.KW_TITLE, L.KW_DESC, parentRow)
	local b = card.body
	local input = UI.Input(b, 260, L.KW_PLACEHOLDER)
	input:SetPoint("TOPLEFT", 14, -4)
	local add = UI.Button(b, L.ADD, 110, 28, "accent")
	add:SetPoint("LEFT", input, "RIGHT", 8, 0)
	local function submit()
		AddKeywords(input.eb:GetText())
		input.eb:SetText("")
	end
	input.eb:SetScript("OnEnterPressed", function(self) submit(); self:ClearFocus() end)
	add:SetScript("OnClick", submit)
	card.chips = CreateFrame("Frame", nil, b)
	card.chips:SetPoint("TOPLEFT", 14, -44)
	card.chips:SetPoint("RIGHT", b, "RIGHT", -14, 0)
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
			r = CreateFrame("Frame", nil, snCard.body)
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
		r:SetPoint("TOPLEFT", snCard.body, "TOPLEFT", 14, -44 - (i - 1) * 30)
		r:SetPoint("RIGHT", snCard.body, "RIGHT", -14, 0)
		r.text:SetText("|cff4ec9ff#" .. sn.k .. "|r   " .. sn.t)
		r:Show()
	end
	SetCardHeight(snCard, 50 + 44 + math.max(#list, 1) * 30 + 10)
end

local function SnippetCard(flow, parentRow)
	local card = Card(flow, "card_snippets", L.SN_TITLE, L.SN_DESC, parentRow)
	local b = card.body
	local name = UI.Input(b, 110, L.SN_NAME_PH)
	name:SetPoint("TOPLEFT", 14, -4)
	name.eb:SetMaxLetters(20)
	local text = UI.Input(b, 250, L.SN_TEXT_PH)
	text:SetPoint("LEFT", name, "RIGHT", 6, 0)
	text:SetPoint("RIGHT", b, "RIGHT", -110, 0)
	text.eb:SetMaxLetters(255)
	local add = UI.Button(b, L.ADD, 90, 28, "accent")
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
	card.empty = UI.Text(b, "GameFontHighlightSmall", C.muted)
	card.empty:SetPoint("TOPLEFT", 14, -48)
	card.empty:SetText(L.SN_EMPTY)
	snCard = card
	return card
end

-------------------------------------------------------------------------------
-- Text style card: size stepper, normal/bold, live preview
-------------------------------------------------------------------------------
local function TextCard(flow)
	local card = Card(flow, "card_text", L.OPT_TEXT_TITLE, L.OPT_TEXT_DESC)
	card.fullHeight = 150
	local b = card.body
	local sizeLabel = UI.Text(b, "GameFontHighlight")
	sizeLabel:SetPoint("TOPLEFT", 14, -12)
	sizeLabel:SetText(L.OPT_TEXT_SIZE)
	local minus = UI.Button(b, "-", 30, 28)
	minus:SetPoint("LEFT", sizeLabel, "RIGHT", 12, 0)
	local value = UI.Text(b, "GameFontHighlight")
	value:SetPoint("LEFT", minus, "RIGHT", 10, 0)
	value:SetWidth(24)
	value:SetJustifyH("CENTER")
	local plus = UI.Button(b, "+", 30, 28)
	plus:SetPoint("LEFT", value, "RIGHT", 10, 0)
	local normal = UI.Button(b, L.OPT_TEXT_NORMAL, 100, 28)
	normal:SetPoint("LEFT", plus, "RIGHT", 30, 0)
	local bold = UI.Button(b, L.OPT_TEXT_BOLD, 100, 28)
	bold:SetPoint("LEFT", normal, "RIGHT", 6, 0)
	local preview = b:CreateFontString(nil, "OVERLAY")
	preview:SetPoint("TOPLEFT", 14, -58)
	preview:SetPoint("RIGHT", b, "RIGHT", -14, 0)
	preview:SetJustifyH("LEFT")
	preview:SetFontObject(UI.MessageFont())
	preview:SetText("|cff6b7383" .. date("%H:%M") .. "|r  |cff3fc7ebJalen|r: " .. L.OPT_TEXT_PREVIEW)

	local function Refresh()
		UI.MessageFont()
		value:SetText(tostring(ns.S.textSize))
		normal:SetSelected(not ns.S.textBold)
		bold:SetSelected(ns.S.textBold and true or false)
	end
	minus:SetScript("OnClick", function() ns.S.textSize = math.max(10, ns.S.textSize - 1); Refresh() end)
	plus:SetScript("OnClick", function() ns.S.textSize = math.min(20, ns.S.textSize + 1); Refresh() end)
	normal:SetScript("OnClick", function() ns.S.textBold = false; Refresh() end)
	bold:SetScript("OnClick", function() ns.S.textBold = true; Refresh() end)
	b:SetScript("OnShow", Refresh)
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
	local flow = NewFlow(c, PageHeader(c, L.PAGE_TYPING, L.PAGE_TYPING_SUB))
	local auto = ToggleRow(flow, "autocomplete")
	ToggleRow(flow, "keepAt", auto)
	ToggleRow(flow, "whisperNames")
	ToggleRow(flow, "raidIcons")
	ToggleRow(flow, "charCounter")
	local sn = ToggleRow(flow, "snippets")
	SnippetCard(flow, sn)
	sf:SetScript("OnShow", function() Relayout(flow); LayoutSnippets() end)
	return sf
end

local function BuildMentions(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_MENTIONS, L.PAGE_MENTIONS_SUB))
	local m = ToggleRow(flow, "mentions")
	ToggleRow(flow, "highlight", m)
	ToggleRow(flow, "mentionSound", m)
	ToggleRow(flow, "mentionFlash", m)
	ToggleRow(flow, "mentionToast", m)
	ToggleRow(flow, "mentionPublic", m)
	KeywordCard(flow, m)

	local bar = CreateFrame("Frame", nil, c)
	bar:SetHeight(28)
	local hist = UI.Button(bar, L.OPT_SHOW_MENTIONS, 170, 28)
	hist:SetPoint("LEFT")
	hist:SetScript("OnClick", function() ns:ShowMentions() end)
	local test = UI.Button(bar, L.OPT_TEST, 140, 28)
	test:SetPoint("LEFT", hist, "RIGHT", 8, 0)
	test:SetScript("OnClick", function() ns:TestAlert() end)
	FlowAdd(flow, bar, nil, { gap = 6 })

	sf:SetScript("OnShow", function() Relayout(flow); LayoutChips() end)
	return sf
end

local function BuildWhispers(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_WHISPERS, L.PAGE_WHISPERS_SUB))
	local w = ToggleRow(flow, "whispers", nil, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "whisperSummary", w)
	TextCard(flow)

	local box = CreateFrame("Frame", nil, c)
	box:SetHeight(110)
	local open = UI.Button(box, L.WH_OPEN, 200, 30, "accent")
	open:SetPoint("TOPLEFT", 0, -6)
	open:SetScript("OnClick", function() ns:ShowWhispers() end)
	local hint = UI.Text(box, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)
	hint:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	hint:SetSpacing(3)
	hint:SetText(L.WH_HINT)
	FlowAdd(flow, box)
	sf:SetScript("OnShow", function() Relayout(flow) end)
	return sf
end

local function BuildChat(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_CHAT, L.PAGE_CHAT_SUB))
	ToggleRow(flow, "abbrevTips")
	ToggleRow(flow, "showLevels")
	ToggleRow(flow, "shortSurnames")
	ToggleRow(flow, "playerInfo")
	local spamRow = ToggleRow(flow, "spamFilter")
	ToggleRow(flow, "keepHistory")
	ToggleRow(flow, "urls")
	local foreign = ToggleRow(flow, "markForeign")
	ToggleRow(flow, "hideForeign", foreign)
	ToggleRow(flow, "hideRepeats")
	ToggleRow(flow, "notes", nil, function(v)
		if not v and ns.HideNotes then ns:HideNotes() end
		ns:UpdateChatButtons()
	end)
	local btn = ToggleRow(flow, "copyButton", nil, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "buttonsTop", btn, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "buttonBackground", btn, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "versionCheck")
	sf:SetScript("OnShow", function()
		local n = ns.SpamToday and ns:SpamToday() or 0
		spamRow.desc:SetText(n > 0 and (L.DESC_spamFilter .. "  |cff8ad9a6" .. L.SPAM_TODAY:format(n) .. "|r") or L.DESC_spamFilter)
		Relayout(flow)
	end)
	return sf
end

local function ThemeTile(parent, name, onPick)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(236, 104)
	local th = UI.THEMES[name]
	local bg = t:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(unpack(th.bg))
	UI.Border(t, C.border)
	-- small preview: header strip with the accent line, two "chat lines"
	local head = t:CreateTexture(nil, "ARTWORK")
	head:SetPoint("TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", -1, -1)
	head:SetHeight(18)
	head:SetColorTexture(unpack(th.panel))
	local line = t:CreateTexture(nil, "OVERLAY")
	line:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
	line:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
	line:SetHeight(2)
	line:SetColorTexture(1, 1, 1, 1)
	if line.SetGradient and CreateColor then
		pcall(line.SetGradient, line, "HORIZONTAL", CreateColor(unpack(th.glowA)), CreateColor(unpack(th.glowB)))
	else
		line:SetColorTexture(unpack(th.glowA))
	end
	local x = 10
	for _, key in ipairs({ "accent", "glowB", "orange", "row" }) do
		local sw = t:CreateTexture(nil, "OVERLAY")
		sw:SetSize(14, 14)
		sw:SetPoint("TOPLEFT", x, -30)
		sw:SetColorTexture(unpack(th[key]))
		x = x + 18
	end
	local label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	UI.NoShadow(label)
	label:SetPoint("TOPLEFT", 10, -52)
	label:SetTextColor(unpack(th.text))
	label:SetText(L["THEME_" .. name])
	local desc = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	UI.NoShadow(desc)
	desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
	desc:SetPoint("RIGHT", -10, 0)
	desc:SetJustifyH("LEFT")
	desc:SetTextColor(unpack(th.muted))
	desc:SetText(L["THEME_" .. name .. "_DESC"])
	t.check = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	UI.NoShadow(t.check)
	t.check:SetPoint("TOPRIGHT", -8, -4)
	t.check:SetTextColor(unpack(th.dark))
	t:SetScript("OnClick", function() onPick(name) end)
	function t:SetPicked(on)
		self:SetBorderColor(unpack(on and th.accent or C.border))
		head:SetColorTexture(unpack(on and th.accent or th.panel))
		self.check:SetText(on and L.THEME_ACTIVE or "")
	end
	return t
end

local function BuildDesign(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_DESIGN, L.PAGE_DESIGN_SUB))

	-- design choice
	local box = CreateFrame("Frame", nil, c)
	box:SetHeight(196)
	UI.Fill(box, C.row)
	local title = UI.Text(box, "GameFontHighlight")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(L.DESIGN_THEME)
	local tiles = {}
	local function Pick(name)
		ns:SetTheme(name)
		for n, tile in pairs(tiles) do tile:SetPicked(n == name) end
		RefreshRows()
	end
	for i, name in ipairs(UI.THEME_ORDER) do
		local tile = ThemeTile(box, name, Pick)
		tile:SetPoint("TOPLEFT", 14 + (i - 1) * 248, -36)
		tiles[name] = tile
	end
	local hint = UI.Text(box, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("TOPLEFT", 14, -150)
	hint:SetPoint("RIGHT", box, "RIGHT", -150, 0)
	hint:SetText(L.DESIGN_RELOAD_HINT)
	local reload = UI.Button(box, L.DESIGN_RELOAD, 120, 26)
	reload:SetPoint("TOPRIGHT", -14, -146)
	reload:SetScript("OnClick", function()
		if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
	end)
	box:SetScript("OnShow", function() for n, tile in pairs(tiles) do tile:SetPicked(n == (ns.S.theme or "modern")) end end)
	FlowAdd(flow, box)

	local skinRow = ToggleRow(flow, "chatSkin", nil, function(v)
		if v then ns:SkinAllChats() else ns.Print(L.CHATSKIN_RELOAD) end
	end)
	skinRow:HookScript("OnShow", function()
		local other = ns.ChatSkinConflict and ns:ChatSkinConflict()
		skinRow.desc:SetText(other and ("|cffffb84d" .. L.CHATSKIN_CONFLICT:format(other) .. "|r") or L.DESC_chatSkin)
	end)

	-- own chat windows
	local cw = CreateFrame("Frame", nil, c)
	cw:SetHeight(170)
	UI.Fill(cw, C.row)
	local t2 = UI.Text(cw, "GameFontHighlight")
	t2:SetPoint("TOPLEFT", 14, -12)
	t2:SetText(L.CW_TITLE)
	local d2 = UI.Text(cw, "GameFontHighlightSmall", C.muted)
	d2:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", 0, -6)
	d2:SetPoint("RIGHT", cw, "RIGHT", -14, 0)
	d2:SetSpacing(3)
	d2:SetText(L.CW_DESC)
	local new = UI.Button(cw, L.CW_NEW, 190, 28, "accent")
	new:SetPoint("BOTTOMLEFT", 14, 14)
	local toggle = UI.Button(cw, L.CW_TOGGLE, 170, 28)
	toggle:SetPoint("LEFT", new, "RIGHT", 8, 0)
	local count = UI.Text(cw, "GameFontHighlightSmall", C.muted)
	count:SetPoint("LEFT", toggle, "RIGHT", 12, 0)
	local function Count() count:SetText(L.CW_COUNT:format(ns:CW_Count())) end
	new:SetScript("OnClick", function() ns:CW_New(); Count() end)
	toggle:SetScript("OnClick", function() ns:CW_ToggleAll(); Count() end)
	cw:SetScript("OnShow", Count)
	FlowAdd(flow, cw)

	sf:SetScript("OnShow", function() Relayout(flow) end)
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
	local tour = UI.Button(c, L.TUT_OPEN, 150, 30)
	tour:SetPoint("LEFT", gh, "RIGHT", 8, 0)
	tour:SetScript("OnClick", function() if win then win:Hide() end; ns:ShowTutorial() end)
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
		UI.Ink(b.label, sel and C.text or C.muted)
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
	BuildDesign(content)
	BuildAbout(content)
	NavButton(sidebar, 1, L.PAGE_TYPING)
	NavButton(sidebar, 2, L.PAGE_MENTIONS)
	NavButton(sidebar, 3, L.PAGE_WHISPERS)
	NavButton(sidebar, 4, L.PAGE_CHAT)
	NavButton(sidebar, 5, L.PAGE_DESIGN)
	NavButton(sidebar, 6, L.PAGE_ABOUT)

	local tourBtn = UI.Button(sidebar, L.TUT_OPEN, 150, 28)
	tourBtn:SetPoint("BOTTOMLEFT", 20, 58)
	tourBtn:SetScript("OnClick", function() win:Hide(); ns:ShowTutorial() end)
	local hint = UI.Text(sidebar, "GameFontHighlightSmall", C.muted)
	hint:SetPoint("BOTTOMLEFT", 20, 16)
	hint:SetPoint("RIGHT", -12, 0)
	hint:SetText(L.SIDEBAR_HINT)

	win:SetScript("OnShow", function() RefreshRows(); RelayoutAll() end)
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
	elseif cmd == "tutorial" or cmd == "tour" or cmd == "help" or cmd == "hilfe" then
		ns:ShowTutorial()
	elseif cmd == "window" or cmd == "fenster" then
		ns:CW_New()
	elseif cmd == "design" or cmd == "theme" then
		if rest ~= "" and ns.UI.THEMES[rest:lower()] then ns:SetTheme(rest:lower()) else ns:OpenOptions(5) end
	elseif cmd == "notes" or cmd == "note" then
		ns:ToggleNotes(); ns:UpdateChatButtons()
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
	UI.MessageFont()
end
