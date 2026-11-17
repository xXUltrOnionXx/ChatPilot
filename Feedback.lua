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

local function Refresh()
	for _, b in ipairs(fb.typeButtons) do
		b:SetAlpha(b.key == fb.kind and 1 or 0.45)
	end
	for i, s in ipairs(fb.stars) do
		s.tex:SetDesaturated(i > fb.rating)
		s.tex:SetAlpha(i > fb.rating and 0.35 or 1)
	end
	fb.count:SetText(L.FB_HISTORY:format(#ns.db.feedback))
end

local function Create()
	local f = ns.CreateWindow("ChatPilotFeedback", L.FB_TITLE, 460, 360)
	f.kind, f.rating = "idea", 5

	local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	intro:SetPoint("TOPLEFT", 12, -34)
	intro:SetPoint("TOPRIGHT", -12, -34)
	intro:SetJustifyH("LEFT")
	intro:SetText(L.FB_INTRO)

	f.typeButtons = {}
	for i, t in ipairs(TYPES) do
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(110, 24)
		b:SetPoint("TOPLEFT", 12 + (i - 1) * 116, -70)
		b:SetText(t.label)
		b.key = t.key
		b:SetScript("OnClick", function() f.kind = t.key; Refresh() end)
		f.typeButtons[i] = b
	end

	local rl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rl:SetPoint("TOPLEFT", 12, -108)
	rl:SetText(L.FB_RATING)
	f.stars = {}
	for i = 1, 5 do
		local s = CreateFrame("Button", nil, f)
		s:SetSize(22, 22)
		s:SetPoint("LEFT", rl, "RIGHT", 8 + (i - 1) * 24, 0)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		s.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		s:SetScript("OnClick", function() f.rating = i; Refresh() end)
		f.stars[i] = s
	end

	local tl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tl:SetPoint("TOPLEFT", 12, -140)
	tl:SetText(L.FB_TEXT)

	local bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
	bg:SetPoint("TOPLEFT", 12, -158)
	bg:SetPoint("BOTTOMRIGHT", -12, 48)
	bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	bg:SetBackdropColor(0, 0, 0, 0.5)
	bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	local scroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 6)
	local eb = CreateFrame("EditBox", nil, scroll)
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(1500)
	eb:SetFontObject(ChatFontNormal)
	eb:SetWidth(390)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(eb)
	bg:EnableMouse(true)
	bg:SetScript("OnMouseDown", function() eb:SetFocus() end)
	f.eb = eb

	f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.count:SetPoint("BOTTOMLEFT", 14, 18)

	local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	save:SetSize(150, 24)
	save:SetPoint("BOTTOMRIGHT", -12, 12)
	save:SetText(L.FB_SAVE)
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
	fb.eb:SetFocus()
end
