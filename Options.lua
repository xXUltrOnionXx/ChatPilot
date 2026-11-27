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
		it.f.flowY = vis and y or nil
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
	frame.flowParent = parent
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
	local ts = ToggleRow(flow, "typeSounds", nil, function(v) if v and ns.PlayTypeSound then ns.PlayTypeSound("key1") end end)
	do -- which sound (two rows of buttons)
		local r = CreateFrame("Frame", nil, flow.child)
		r:SetHeight(42 + math.ceil(#(ns.TYPE_SOUNDS or {}) / 5) * 28)
		UI.Fill(r, C.row)
		local label = UI.Text(r, "GameFontHighlight")
		label:SetPoint("TOPLEFT", 14, -10)
		label:SetText(L.SOUND_KIND)
		local seg = {}
		local function Mark()
			local cur = ns.KIND and ns.KIND[ns.S.typeSound] and ns.S.typeSound or "own"
			for v, b in pairs(seg) do UI.Ink(b.label, cur == v and C.accent or C.muted) end
		end
		local names = {
			own = L.SOUND_OWN .. " 1", own2 = L.SOUND_OWN .. " 2", metal = L.SOUND_METAL, real = L.SOUND_REAL, mech = L.SOUND_MECH, soft = L.SOUND_SOFT,
			creamy = "Creamy", thocky = "Thocky", clacky = "Clacky", poppy = "Poppy", clicky = "Clicky", lego = "Lego", blue = "Blue Switch",
		}
		for i, v in ipairs(ns.TYPE_SOUNDS or {}) do
			local b = UI.Button(r, names[v] or v, 80, 24)
			local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
			b:SetPoint("TOPLEFT", r, "TOPLEFT", 14 + col * 84, -34 - row * 28)
			b:SetScript("OnClick", function()
				ns.S.typeSound = v
				Mark()
				if ns.PlayTypeSound then ns.PlayTypeSound("key1", true) end -- a sample right away
			end)
			seg[v] = b
		end
		-- volume
		local nRows = math.ceil(#(ns.TYPE_SOUNDS or {}) / 5)
		local vl = UI.Text(r, "GameFontHighlight")
		vl:SetPoint("TOPLEFT", 14, -40 - nRows * 28)
		vl:SetText(L.SOUND_VOLUME)
		local vols = {}
		local function MarkVol()
			local cur = tonumber(ns.S.typeVolume) or 3
			for n, b in pairs(vols) do UI.Ink(b.label, cur == n and C.accent or C.muted) end
		end
		for n, txt in ipairs({ L.VOL_1, L.VOL_2, L.VOL_3, L.VOL_4 }) do
			local b = UI.Button(r, txt, 80, 24)
			b:SetPoint("TOPLEFT", r, "TOPLEFT", 14 + (n - 1) * 84, -62 - nRows * 28)
			b:SetScript("OnClick", function()
				ns.S.typeVolume = n
				MarkVol()
				if ns.PlayTypeSound then ns.PlayTypeSound("key1", true) end
			end)
			vols[n] = b
		end
		r:SetHeight(42 + nRows * 28 + 62)
		r:SetScript("OnShow", function() Mark(); MarkVol() end)
		Mark(); MarkVol()
		FlowAdd(flow, r, ts)
		MakeExpandable(ts, ts.toggle, -14)
	end
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
	ToggleRow(flow, "showLevels", nil, function() ns:RefreshMainChat() end)
	ToggleRow(flow, "shortSurnames", nil, function() ns:RefreshMainChat() end)
	ToggleRow(flow, "presenceTag", nil, function() ns:RefreshMainChat() end)
	ToggleRow(flow, "playerInfo")
	local spamRow = ToggleRow(flow, "spamFilter")
	ToggleRow(flow, "scamWarn")
	ToggleRow(flow, "mentionInitial")
	ToggleRow(flow, "markdown", nil, function() ns:RefreshMainChat() end)
	local streamRow = ToggleRow(flow, "stream", nil, function(v)
		if ns.SetStream then ns:SetStream(v) end
	end)
	ToggleRow(flow, "streamWhispers", streamRow)
	ToggleRow(flow, "streamTags", streamRow)
	ToggleRow(flow, "streamNames", streamRow)
	ToggleRow(flow, "streamLinks", streamRow)
	ToggleRow(flow, "streamStrangers", streamRow)
	ToggleRow(flow, "streamAnon", streamRow)
	ToggleRow(flow, "keepHistory")
	ToggleRow(flow, "urls")
	local foreign = ToggleRow(flow, "markForeign")
	ToggleRow(flow, "hideForeign", foreign)
	ToggleRow(flow, "hideRepeats")
	ToggleRow(flow, "notes", nil, function(v)
		if not v and ns.HideNotes then ns:HideNotes() end
		ns:UpdateChatButtons()
	end)
	ToggleRow(flow, "tabWheel")
	local btn = ToggleRow(flow, "copyButton", nil, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "buttonsTop", btn, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "buttonBackground", btn, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "versionCheck")
	local pilotRow = ToggleRow(flow, "pilotLink")
	ToggleRow(flow, "pilotZone", pilotRow)
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

	ToggleRow(flow, "notifyGlow", nil, function() ns:UpdateChatButtons() end)
	ToggleRow(flow, "chatStyle", nil, function() ns:RefreshMainChat() end)
	local skinRow = ToggleRow(flow, "chatSkin", nil, function(v)
		-- switches right away, old lines included (no /reload needed)
		if v then ns:SkinAllChats(); ns:InstallMainChatHooks() else ns:UnskinAllChats() end
		ns:RefreshMainChat()
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

-- "Good to know": what ChatPilot keeps, how to empty it, and a few plain facts
local function InfoBox(flow, c, title, text, extra)
	local box = CreateFrame("Frame", nil, c)
	UI.Fill(box, C.row)
	local head = UI.Text(box, "GameFontNormalSmall", C.accent)
	head:SetPoint("TOPLEFT", 14, -12)
	head:SetText(title:upper())
	local body = UI.Text(box, "GameFontHighlight")
	body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
	body:SetWidth(470)
	body:SetJustifyH("LEFT")
	body:SetSpacing(3)
	body:SetText(text)
	box.body = body
	FlowAdd(flow, box, nil, { gap = 10, height = function()
		local e = type(extra) == "function" and extra() or extra or 0
		return 12 + 14 + 8 + (body:GetStringHeight() or 40) + 14 + e
	end })
	return box
end

local function BuildInfo(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_INFO, L.PAGE_INFO_SUB))

	local store = InfoBox(flow, c, L.INFO_STORAGE, L.INFO_STORAGE_TEXT, 26 + 4 * 34)
	local counts = UI.Text(store, "GameFontHighlightSmall", C.muted)
	counts:SetPoint("TOPLEFT", store.body, "BOTTOMLEFT", 0, -10)
	counts:SetWidth(470)
	counts:SetJustifyH("LEFT")
	local function Count()
		counts:SetText(L.INFO_COUNTS:format(ns:SavedChatLines(), ns.CW_SavedLines and ns:CW_SavedLines() or 0,
			ns:WhisperCount(), #(ns.db.mentions or {})))
	end
	local function Done(what)
		ns.Print(L.CLEARED, what)
		Count()
	end
	local b1 = UI.ConfirmButton(store, L.CLEAR_MAIN, 230, 28, function() ns:ClearMainChat(); Done(L.CLEAR_MAIN) end)
	b1:SetPoint("TOPLEFT", counts, "BOTTOMLEFT", 0, -12)
	local b2 = UI.ConfirmButton(store, L.CLEAR_WINDOWS, 230, 28, function() ns:CW_ClearAll(); Done(L.CLEAR_WINDOWS) end)
	b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
	local b3 = UI.ConfirmButton(store, L.CLEAR_WHISPERS, 230, 28, function() ns:ClearWhisperLog(); Done(L.CLEAR_WHISPERS) end)
	b3:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -6)
	local b4 = UI.ConfirmButton(store, L.CLEAR_MENTIONS, 230, 28, function() ns:ClearMentionLog(); Done(L.CLEAR_MENTIONS) end)
	b4:SetPoint("LEFT", b3, "RIGHT", 8, 0)
	local b5 = UI.ConfirmButton(store, L.CLEAR_ALL, 468, 28, function() ns:ClearEverything(); Done(L.CLEAR_ALL) end)
	b5:SetPoint("TOPLEFT", b3, "BOTTOMLEFT", 0, -10)
	store:SetScript("OnShow", Count)

	-- archive of the older lines of every window
	local arRows = {}
	local ar = InfoBox(flow, c, L.INFO_ARCHIVE, L.INFO_ARCHIVE_TEXT, function() return 14 + math.max(1, #arRows) * 32 end)
	local function FillArchive()
		local list = ns.CW_List and ns:CW_List() or {}
		for i, w in ipairs(list) do
			local r = arRows[i]
			if not r then
				r = UI.Button(ar, "", 468, 28)
				r:SetPoint("TOPLEFT", ar.body, "BOTTOMLEFT", 0, -10 - (i - 1) * 32)
				arRows[i] = r
			end
			r.id = w.id
			r.label:SetText(L.AR_ROW:format(w.name, #ns:CW_ArchiveGet(w.id)))
			r:SetScript("OnClick", function() ns:ShowArchive(w.id) end)
			r:Show()
		end
		for i = #list + 1, #arRows do arRows[i]:Hide() end
	end

	-- search over every chat
	local sr = InfoBox(flow, c, L.INFO_SEARCH, L.INFO_SEARCH_TEXT, 46)
	local sb = UI.Button(sr, L.SR_OPEN, 468, 28, "accent")
	sb:SetPoint("TOPLEFT", sr.body, "BOTTOMLEFT", 0, -12)
	sb:SetScript("OnClick", function() ns:ShowSearch() end)

	-- ChatPilot users around you
	local pl = InfoBox(flow, c, L.INFO_PILOTS, L.INFO_PILOTS_TEXT, 46)
	local plb = UI.Button(pl, L.PL_OPEN, 468, 28, "accent")
	plb:SetPoint("TOPLEFT", pl.body, "BOTTOMLEFT", 0, -12)
	plb:SetScript("OnClick", function() ns:ShowPilots() end)

	-- back up / move your data
	local bk = InfoBox(flow, c, L.INFO_BACKUP, L.INFO_BACKUP_TEXT, 46)
	local be = UI.Button(bk, L.BK_EXPORT, 230, 28, "accent")
	be:SetPoint("TOPLEFT", bk.body, "BOTTOMLEFT", 0, -12)
	be:SetScript("OnClick", function() ns:ShowBackup("export") end)
	local bi = UI.Button(bk, L.BK_IMPORT, 230, 28)
	bi:SetPoint("LEFT", be, "RIGHT", 8, 0)
	bi:SetScript("OnClick", function() ns:ShowBackup("import") end)

	-- removing the addon does not remove the data
	local rm = InfoBox(flow, c, L.INFO_REMOVE, L.INFO_REMOVE_TEXT, 46)
	local bw = UI.ConfirmButton(rm, L.BK_WIPE, 468, 28, function() ns:WipeAllData() end)
	bw:SetPoint("TOPLEFT", rm.body, "BOTTOMLEFT", 0, -12)

	-- empty chosen chats when logging out
	local autoRows, autoCount = {}, 0
	local auto = InfoBox(flow, c, L.INFO_AUTO, L.INFO_AUTO_TEXT, function() return 8 + autoCount * 28 end)
	local function AutoRow(i)
		local r = autoRows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, auto)
		r:SetSize(470, 26)
		r:SetPoint("TOPLEFT", auto.body, "BOTTOMLEFT", 0, -10 - (i - 1) * 28)
		r.label = UI.Text(r, "GameFontHighlight")
		r.label:SetPoint("LEFT", 52, 0)
		r.toggle = UI.Toggle(r, function(v) if r.set then r.set(v) end end)
		r.toggle:SetPoint("LEFT", 0, 0)
		autoRows[i] = r
		return r
	end
	local function FillAuto()
		local a = ns:AutoClear()
		local items = {}
		for _, t in ipairs(ns:MainTabs()) do
			items[#items + 1] = { label = L.AUTO_MAIN:format(t.name), get = function() return a.main[t.id] end, set = function(v) a.main[t.id] = v or nil end }
		end
		for _, w in ipairs(ns.CW_List and ns:CW_List() or {}) do
			items[#items + 1] = { label = L.AUTO_WIN:format(w.name), get = function() return a.win[w.id] end, set = function(v) a.win[w.id] = v or nil end }
		end
		items[#items + 1] = { label = L.CLEAR_WHISPERS:gsub("^%s+", ""), get = function() return a.whispers end, set = function(v) a.whispers = v or nil end, plain = L.AUTO_WHISPERS }
		items[#items + 1] = { label = L.AUTO_MENTIONS, get = function() return a.mentions end, set = function(v) a.mentions = v or nil end }
		for i, it in ipairs(items) do
			local r = AutoRow(i)
			r.label:SetText(it.plain or it.label)
			r.toggle:SetValue(it.get() and true or false)
			r.set = it.set
			r:Show()
		end
		for i = #items + 1, #autoRows do autoRows[i]:Hide() end
		autoCount = #items
	end

	InfoBox(flow, c, L.INFO_DESIGN, L.INFO_DESIGN_TEXT)
	InfoBox(flow, c, L.INFO_SAFE, L.INFO_SAFE_TEXT)
	InfoBox(flow, c, L.INFO_CMDS, L.INFO_CMDS_TEXT)

	sf:SetScript("OnShow", function() Count(); FillAuto(); FillArchive(); Relayout(flow) end)
	return sf
end

-- Patch notes: every update so far, newest first, in the client's language
local function BuildPatch(content)
	local sf, c = NewPage(content)
	local flow = NewFlow(c, PageHeader(c, L.PAGE_PATCH, L.PAGE_PATCH_SUB))
	local top = CreateFrame("Frame", nil, c)
	top:SetHeight(40)
	local b = UI.Button(top, L.THX_SHOW, 220, 30)
	b:SetPoint("LEFT", 0, 0)
	b:SetScript("OnClick", function() if ns.ShowThanks then ns:ShowThanks() end end)
	FlowAdd(flow, top)
	for i, e in ipairs(ns.PATCHNOTES or {}) do
		local lines = {}
		for _, l in ipairs(ns:PatchLines(e)) do lines[#lines + 1] = "•  " .. l end
		local box = InfoBox(flow, c, L.PATCH_VERSION:format(e.v) .. (i == 1 and ("  ·  " .. L.PATCH_NEWEST) or ""), table.concat(lines, "\n"))
		if i == 1 then box.body:SetTextColor(1, 1, 1) end
	end
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

	-- debug button for the whole addon (bug icon, red dot while problems were caught)
	local dbg = CreateFrame("Button", nil, win.header)
	dbg:SetSize(28, 28)
	dbg:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
	local dhl = UI.Fill(dbg, C.rowHover)
	dhl:Hide()
	dbg.icon = dbg:CreateTexture(nil, "ARTWORK")
	dbg.icon:SetSize(16, 16)
	dbg.icon:SetPoint("CENTER")
	dbg.icon:SetTexture("Interface\\Icons\\INV_Misc_Bug_01")
	dbg.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	dbg.icon:SetAlpha(0.8)
	dbg.dot = dbg:CreateTexture(nil, "OVERLAY")
	dbg.dot:SetSize(7, 7)
	dbg.dot:SetPoint("TOPRIGHT", -3, -3)
	dbg.dot:SetColorTexture(1, 0.3, 0.3, 1)
	dbg.dot:Hide()
	dbg:SetScript("OnEnter", function(self)
		dhl:Show()
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L.DBG_TIP)
		if (self.n or 0) > 0 then GameTooltip:AddLine(L.DBG_ERRS:format(self.n), 1, 0.45, 0.45, true) end
		GameTooltip:Show()
	end)
	dbg:SetScript("OnLeave", function() dhl:Hide(); GameTooltip:Hide() end)
	dbg:SetScript("OnClick", function() ns:ShowDebug() end)
	win.dbg = dbg
	win:HookScript("OnShow", function() ns.UpdateDebugBadge() end)
	ns.UpdateDebugBadge()

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
	BuildInfo(content)
	BuildPatch(content)
	BuildAbout(content)
	NavButton(sidebar, 1, L.PAGE_TYPING)
	NavButton(sidebar, 2, L.PAGE_MENTIONS)
	NavButton(sidebar, 3, L.PAGE_WHISPERS)
	NavButton(sidebar, 4, L.PAGE_CHAT)
	NavButton(sidebar, 5, L.PAGE_DESIGN)
	NavButton(sidebar, 6, L.PAGE_INFO)
	NavButton(sidebar, 7, L.PAGE_PATCH)
	NavButton(sidebar, 8, L.PAGE_ABOUT)

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

-- Used by the tour: opens the window on a page, scrolls to a row and returns
-- the frame to highlight ("nav" = the whole sidebar).
function ns:OptionsFocus(page, key)
	if not win then Build() end
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
	page = page or 1
	SelectPage(page)
	win:Show()
	RefreshRows()
	RelayoutAll()
	local sf = pages[page]
	local target
	if key == "nav" then
		target = navButtons[1] and navButtons[1]:GetParent()
	elseif key then
		for _, r in ipairs(rows) do if r.key == key then target = r break end end
	else
		target = navButtons[page]
	end
	-- a row inside a collapsed group: open the group first
	if target and key and key ~= "nav" then
		local p, changed = rawget(target, "flowParent"), false
		while p do
			if not IsExpanded(p) then SetExpanded(p, true); changed = true end
			p = rawget(p, "flowParent")
		end
		if changed then RefreshRows(); RelayoutAll() end
	end
	if sf and sf.child then
		-- the row's place is known from the layout (no waiting for the game to place frames)
		local function Scroll()
			if not sf.SetVerticalScroll then return end
			local want = 0
			local y = target and rawget(target, "flowY")
			if type(y) == "number" and key and key ~= "nav" then
				local maxScroll = math.max(0, (sf.child:GetHeight() or 0) - (sf:GetHeight() or 0))
				want = math.max(0, math.min(-y - 60, maxScroll))
			end
			sf:SetVerticalScroll(want)
		end
		Scroll()
		C_Timer.After(0.05, Scroll)
		C_Timer.After(0.2, Scroll)
	end
	return target
end

function ns:OptionsWindow() return win end

-- is this row inside the visible part of its scrolling page? (for the tour's frame)
function ns:OptionsRowInView(r)
	local flow = r and rawget(r, "flow")
	local child = type(flow) == "table" and flow.child
	local sf = child and child:GetParent()
	if not (sf and sf.GetTop and r.GetTop) then return true end
	local rt, rb, st, sb = r:GetTop(), r:GetBottom(), sf:GetTop(), sf:GetBottom()
	if not (rt and rb and st and sb) then return true end
	return rt <= st + 2 and rb >= sb - 2
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


-- Report for the debug button, /chatpilot diag and /chatpilot debug: a list of lines
function ns:DebugReport()
	-- a short report for bug reports (what the chat look and docking see right now)
	local out = {}
	local function P(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
	local skinned = 0
	for _ in pairs(ns._skinned or {}) do skinned = skinned + 1 end
	local main = ns.CW_MainChat and ns.CW_MainChat()
	local dockSel = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
	P("%s, interface %s", tostring(ns.version), tostring(select(4, GetBuildInfo()) or "?"))
	P("chatSkin=%s chatStyle=%s conflict=%s hooks=%s skinnedFrames=%d",
		tostring(ns.S.chatSkin), tostring(ns.S.chatStyle), tostring(ns.skinConflict), tostring(ns.mainHooks), skinned)
	P("mainChat=%s visible=%s dockSelected=%s", main and tostring(main.GetName and main:GetName()) or "nil",
		tostring(main and main.IsVisible and main:IsVisible()), dockSel and tostring(dockSel.GetName and dockSel:GetName()) or "nil")
	local names = {}
	for i = 1, (NUM_CHAT_WINDOWS or 0) do
		local f = _G["ChatFrame" .. i]
		if f then names[#names + 1] = i .. (f:IsShown() and "" or "(hidden)") .. (rawget(f, "cpDeco") and "*" or "") end
	end
	P("chatFrames: %s  (* = ChatPilot look active)", table.concat(names, " "))
	local ok, over = pcall(function() return ns:OverMainChat() end)
	P("mouse over the main chat right now: %s (hold the mouse over it and run again)", ok and tostring(over) or "error")
	local loaded = {}
	if C_AddOns and C_AddOns.GetNumAddOns then
		for i = 1, C_AddOns.GetNumAddOns() do
			local n = C_AddOns.GetAddOnInfo(i)
			if n and C_AddOns.IsAddOnLoaded(n) and not tostring(n):find("^Blizzard_") then loaded[#loaded + 1] = n end
		end
	end
	local st = ns.cwStats or {}
	P("custom chats: shown %d, hidden by a filter %d, restricted text shown %d (failed %d), no window for event %d, kept open %d, caught errors %d",
		st.shown or 0, st.filtered or 0, st.secret or 0, st.secretFail or 0, st.noTarget or 0, st.keptOpen or 0, #(ns.errors or {}))
	local nGroups, nShown = 0, 0
	for _, g in ipairs(ns._cw and ns._cw.groups or {}) do
		nGroups = nGroups + 1
		if g.frame:IsVisible() then nShown = nShown + 1 end
	end
	P("custom windows: %d (visible %d)", nGroups, nShown)
	-- settings (only on/off and number values, never texts or names)
	local flags = {}
	for k, v in pairs(ns.S or {}) do
		if type(v) == "boolean" then flags[#flags + 1] = k .. "=" .. (v and "on" or "off")
		elseif type(v) == "number" then flags[#flags + 1] = k .. "=" .. tostring(v) end
	end
	table.sort(flags)
	P("settings: %s", #flags > 0 and table.concat(flags, " ") or "-")
	-- custom windows one by one
	for _, g in ipairs(ns._cw and ns._cw.groups or {}) do
		local names = {}
		for _, id in ipairs(g.data and g.data.order or {}) do
			local w = ns._cw.wins and ns._cw.wins[id]
			if w then names[#names + 1] = tostring(ns._cw.WindowName and ns._cw.WindowName(w) or id) .. "(" .. tostring(w.count or 0) .. ")" end
		end
		P("window group: %s docked=%s open=%s visible=%s", table.concat(names, "+"), tostring(g.data and g.data.main or false),
			tostring(g.mainOpen or false), tostring(g.frame and g.frame:IsVisible() or false))
	end
	-- saved problems
	local log = ns.ErrorLog and ns.ErrorLog() or {}
	P("saved problems: %d", #log)
	for i = math.max(1, #log - 7), #log do
		local e = log[i]
		P("  [%s/%s] x%d (first %s, last %s, v%s): %s", tostring(e.kind), tostring(e.where), e.count or 1,
			e.first and date("%d.%m. %H:%M", e.first) or "?", e.last and date("%d.%m. %H:%M", e.last) or "?", tostring(e.ver), tostring(e.msg))
		if e.stack and i == #log then P("  stack: %s", (e.stack:gsub("\n", " | "))) end
	end
	P("other addons: %s", #loaded > 0 and table.concat(loaded, ", ") or "-")
	return out
end

function ns:ShowDebug()
	local ok, lines = pcall(function() return ns:DebugReport() end)
	local text = ok and table.concat(lines, "\n") or ("error: " .. tostring(lines))
	if ns.ShowCopy then ns:ShowCopy(text, L.DBG_TITLE, false) else ns.Print(text) end
end

-- red dot on the debug button while there are saved problems
function ns.UpdateDebugBadge()
	local b = win and win.dbg
	if not b then return end
	local n = ns.ErrorLog and #ns.ErrorLog() or 0
	b.dot:SetShown(n > 0)
	b.n = n
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
	elseif cmd == "clear" or cmd == "leeren" then
		if rest:lower() == "all" or rest:lower() == "alle" then
			ns:ClearMainChat()
		else
			ns:ClearMainChat(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
		end
		ns.Print(L.CLEARED, L.CLEAR_MAIN)
	elseif cmd == "info" then
		ns:OpenOptions(6)
	elseif cmd == "errors" or cmd == "fehler" then
		if rest:lower() == "clear" or rest:lower() == "leeren" then
			ns.ErrorClear()
			ns.Print(L.ERR_CLEARED)
		else
			local log = ns.ErrorLog()
			if #log == 0 then ns.Print(L.ERR_NONE) end
			for _, e in ipairs(log) do
				ns.Print("[%s] x%d %s: %s", tostring(e.kind), e.count or 1, e.last and date("%d.%m. %H:%M", e.last) or "?", tostring(e.msg))
			end
		end
	elseif cmd == "stream" or cmd == "streamer" or cmd == "live" then
		local want
		if rest == "on" then want = true elseif rest == "off" then want = false else want = not ns.S.stream end
		ns:SetStream(want)
	elseif cmd == "panic" then
		if not ns.S.stream then ns:SetStream(true) end
		ns:StreamPanic()
	elseif cmd == "skin" then
		-- /chatpilot skin force = apply the modern chat look even if another chat addon is found
		if rest == "force" then
			ns.S.skinForce = true
			ns.skinConflict = nil
			ns.S.chatSkin = true
			ns:SkinAllChats()
			ns:InstallMainChatHooks()
			ns:RefreshMainChat()
			ns.Print("Modern chat look: forced on (/chatpilot skin auto = back to automatic).")
		elseif rest == "auto" then
			ns.S.skinForce = nil
			ns.Print("Modern chat look: automatic again (takes effect after /reload).")
		else
			ns.Print("/chatpilot skin force  |  /chatpilot skin auto")
		end
	elseif (cmd == "diag" or cmd == "diagnose") and rest == "hover" then
		-- put the mouse over the chat (or drag a window over it) during the 5 seconds
		ns.Print("[diag] hold the mouse over the chat or drag a window above it - report in 5 seconds ...")
		C_Timer.After(5, function() local okd, errd = pcall(function()
			local function P(fmt, ...) ns.Print("[diag] " .. fmt, ...) end
			local main = ns.CW_MainChat and ns.CW_MainChat()
			if not main then P("no main chat") return end
			local cx, cy = GetCursorPosition()
			local function R(v) return type(v) == "number" and ("%.0f"):format(v) or tostring(v) end
			P("main %s: left %s right %s bottom %s top %s, scale %s (UIParent %s)", tostring(main:GetName()),
				R(main:GetLeft()), R(main:GetRight()), R(main:GetBottom()), R(main:GetTop()),
				tostring(main:GetEffectiveScale()), tostring(UIParent:GetEffectiveScale()))
			P("cursor %s, %s", R(cx), R(cy))
			local a = MouseIsOver and select(2, pcall(MouseIsOver, main))
			local b = MouseIsOver and select(2, pcall(MouseIsOver, main, 34, -8, -6, 6))
			P("MouseIsOver plain=%s with margins=%s, ChatPilot own check=%s", tostring(a), tostring(b), tostring(ns:OverMainChat()))
			local over = {}
			for _, g in ipairs(ns._cw and ns._cw.groups or {}) do
				if g.frame and g.frame:IsVisible() then
					over[#over + 1] = (g.data and g.data.main and "main" or "free") .. ":" .. tostring(ns.CW_Over and ns.CW_Over(g.header))
				end
			end
			P("ChatPilot windows (title bar under mouse): %s", #over > 0 and table.concat(over, " ") or "none open")
		end); if not okd then ns.Print("[diag] error: " .. tostring(errd)) end end)
	elseif cmd == "diag" or cmd == "diagnose" then
		for _, line in ipairs(ns:DebugReport()) do ns.Print("[diag] " .. line) end
	elseif cmd == "debug" then
		ns:ShowDebug()
	elseif cmd == "pilots" or cmd == "piloten" or cmd == "users" then
		ns:ShowPilots()
	elseif cmd == "archive" or cmd == "archiv" then
		ns:ShowArchive()
	elseif cmd == "search" or cmd == "suche" or cmd == "find" or cmd == "history" or cmd == "verlauf" then
		ns:ShowSearch(rest)
	elseif cmd == "export" or cmd == "import" or cmd == "backup" then
		ns:ShowBackup(cmd == "import" and "import" or "export")
	elseif cmd == "thanks" or cmd == "danke" or cmd == "news" or cmd == "patchnotes" then
		if ns.ShowThanks then ns:ShowThanks() end
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
