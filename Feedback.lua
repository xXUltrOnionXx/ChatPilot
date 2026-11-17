local ADDON, ns = ...
local L = ns.L

-- In-game feedback: addons cannot access the internet, so the report is saved
-- locally and shown as copyable text that the player can post on the addon page.
-- The window only opens when the player asks for it (no pop-ups, no nagging).

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local function FeedbackURL()
	return (GetMeta and GetMeta(ADDON, "X-Feedback")) or "https://github.com/xXUltrOnionXx/ChatPilot/issues/new/choose"
end

local TYPES = { { key = "bug", label = L.FB_BUG }, { key = "idea", label = L.FB_IDEA }, { key = "praise", label = L.FB_PRAISE } }
local fb

local function BuildReport(entry)
	local version, build, _, iface = GetBuildInfo()
	local on, off = {}, {}
	for k, v in pairs(ns.S) do
		if type(v) == "boolean" then
			if v then on[#on + 1] = k else off[#off + 1] = k end
		end
	end
	table.sort(on)
	table.sort(off)
	local typeLabel = entry.kind
	for _, t in ipairs(TYPES) do if t.key == entry.kind then typeLabel = t.label end end
	return table.concat({
		"[ChatPilot Feedback]",
		"Type: " .. typeLabel .. "   Rating: " .. string.rep("*", entry.rating) .. string.rep("-", 5 - entry.rating) .. " (" .. entry.rating .. "/5)",
		"Addon: " .. ns.version .. "   Client: " .. tostring(version) .. " (" .. tostring(build) .. ", " .. tostring(iface) .. ")   Locale: " .. GetLocale(),
		"Enabled: " .. (#on > 0 and table.concat(on, ", ") or "-"),
		"Disabled: " .. (#off > 0 and table.concat(off, ", ") or "-"),
		"Date: " .. date("%Y-%m-%d %H:%M", entry.t),
		"",
		entry.text,
	}, "\n")
end

local UI, C = ns.UI, ns.UI.C

local function Refresh()
	for _, b in ipairs(fb.typeButtons) do b:SetSelected(b.key == fb.kind) end
	for i, s in ipairs(fb.stars) do
		s.tex:SetDesaturated(i > fb.rating)
		s.tex:SetAlpha(i > fb.rating and 0.3 or 1)
	end
	fb.count:SetText(L.FB_HISTORY:format(#ns.db.feedback))
end

local function Label(parent, text, anchor, y)
	local t = UI.Text(parent, "GameFontNormalSmall", C.accent)
	t:SetPoint("TOPLEFT", anchor or parent, anchor and "BOTTOMLEFT" or "TOPLEFT", anchor and 0 or 20, y)
	t:SetText(text:upper())
	return t
end

local function Create()
	local f = UI.Window("ChatPilotFeedback", L.FB_TITLE, 520, 470)
	f.kind, f.rating = "idea", 5
	local c = f.content

	local intro = UI.Text(c, "GameFontHighlight", C.muted)
	intro:SetPoint("TOPLEFT", 20, -18)
	intro:SetPoint("RIGHT", c, "RIGHT", -20, 0)
	intro:SetSpacing(3)
	intro:SetText(L.FB_INTRO)

	local typeLabel = Label(c, L.FB_TYPE, intro, -18)
	f.typeButtons = {}
	for i, t in ipairs(TYPES) do
		local b = UI.Button(c, t.label, 110, 30)
		b:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", (i - 1) * 116, -8)
		b.key = t.key
		b:SetScript("OnClick", function() f.kind = t.key; Refresh() end)
		f.typeButtons[i] = b
	end

	local rl = Label(c, L.FB_RATING, typeLabel, -50)
	f.stars = {}
	for i = 1, 5 do
		local s = CreateFrame("Button", nil, c)
		s:SetSize(24, 24)
		s:SetPoint("TOPLEFT", rl, "BOTTOMLEFT", (i - 1) * 28, -8)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		s.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		s:SetScript("OnClick", function() f.rating = i; Refresh() end)
		f.stars[i] = s
	end

	local tl = Label(c, L.FB_TEXT, rl, -46)
	local box = CreateFrame("Frame", nil, c)
	box:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, -8)
	box:SetPoint("BOTTOMRIGHT", -20, 60)
	UI.Fill(box, C.panel)
	UI.Border(box)
	local scroll = UI.ScrollArea(box)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	local eb = CreateFrame("EditBox", nil, scroll.child)
	eb:SetPoint("TOPLEFT")
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(1500)
	eb:SetFontObject(ChatFontNormal)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnTextChanged", function(self) scroll.child:SetHeight(math.max(self:GetHeight(), 10)) end)
	eb:HookScript("OnEditFocusGained", function() box:SetBorderColor(unpack(C.accent)) end)
	eb:HookScript("OnEditFocusLost", function() box:SetBorderColor(unpack(C.border)) end)
	scroll:SetScript("OnSizeChanged", function(_, width) scroll.child:SetWidth(width); eb:SetWidth(width) end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() eb:SetFocus() end)
	f.eb = eb

	f.count = UI.Text(c, "GameFontHighlightSmall", C.muted)
	f.count:SetPoint("BOTTOMLEFT", 20, 22)

	local save = UI.Button(c, L.FB_SAVE, 170, 30, "accent")
	save:SetPoint("BOTTOMRIGHT", -20, 14)
	save:SetScript("OnClick", function()
		local text = strtrim(eb:GetText() or "")
		if text == "" then
			ns.Print(L.FB_EMPTY)
			eb:SetFocus()
			return
		end
		local entry = { t = time(), kind = f.kind, rating = f.rating, text = text, v = ns.version }
		table.insert(ns.db.feedback, entry)
		while #ns.db.feedback > 20 do table.remove(ns.db.feedback, 1) end
		eb:SetText("")
		f:Hide()
		ns.Print(L.FB_SAVED)
		ns.Print(L.FB_WHERE, FeedbackURL())
		ns:ShowCopy(BuildReport(entry) .. "\n\n" .. L.FB_WHERE:format(FeedbackURL()), L.COPY_TITLE)
	end)
	return f
end

function ns:ShowFeedback()
	fb = fb or Create()
	Refresh()
	fb:Show()
	fb:Raise()
	fb.eb:SetFocus()
end
