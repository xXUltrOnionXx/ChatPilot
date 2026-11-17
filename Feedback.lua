local ADDON, ns = ...
local L = ns.L

-- In-game feedback: addons cannot access the internet, so the report is saved
-- locally and shown as copyable text that the player can post on the addon page.
-- The window only opens when the player asks for it (no pop-ups, no nagging).

-- One link does it all: the whole feedback is put into a pre-filled link.
-- Copy it once (Ctrl+C), paste it in the browser, press "Submit".
-- (Addons are not allowed to open a browser themselves.)
local GOOGLE = "https://docs.google.com/forms/d/e/1FAIpQLSdan5DKKfI7kOCmFSNnoznN_HcPc9rF2eIc3nxi8NmcwczUKA/viewform?usp=pp_url"
local G_TYPE, G_RATING, G_TEXT, G_REPORT = "entry.91383561", "entry.1596824034", "entry.98074855", "entry.1077065921"
local G_TYPE_VALUE = { bug = "Fehler / Bug", idea = "Idee / Idea", praise = "Lob / Praise" }
local GITHUB = "https://github.com/xXUltrOnionXx/ChatPilot/issues/new"

local function Enc(s)
	s = tostring(s or ""):gsub("\r", "")
	return (s:gsub("[^%w%-%._~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function Query(base, params)
	local parts = {}
	for _, kv in ipairs(params) do parts[#parts + 1] = kv[1] .. "=" .. Enc(kv[2]) end
	return base .. (base:find("?", 1, true) and "&" or "?") .. table.concat(parts, "&")
end

local TYPES = { { key = "bug", label = L.FB_BUG }, { key = "idea", label = L.FB_IDEA }, { key = "praise", label = L.FB_PRAISE } }
local fb

local function TechReport()
	local version, build, _, iface = GetBuildInfo()
	local off = {}
	for k, v in pairs(ns.S) do
		if v == false then off[#off + 1] = k end
	end
	table.sort(off)
	return ("ChatPilot %s | Client %s (%s, %s) | %s | Off: %s"):format(
		ns.version, tostring(version), tostring(build), tostring(iface), GetLocale(),
		#off > 0 and table.concat(off, ", ") or "-")
end

local function Title(text)
	local first = text:gsub("%s+", " "):sub(1, 60)
	return first
end

local function GoogleLink(e)
	return Query(GOOGLE, {
		{ G_TYPE, G_TYPE_VALUE[e.kind] }, { G_RATING, e.rating },
		{ G_TEXT, e.text }, { G_REPORT, TechReport() },
	})
end

local function GitHubLink(e)
	local report = TechReport()
	if e.kind == "bug" then
		return Query(GITHUB, { { "template", "bug_report.yml" }, { "title", "[Bug] " .. Title(e.text) },
			{ "version", ns.version }, { "what", e.text }, { "report", report } })
	elseif e.kind == "idea" then
		return Query(GITHUB, { { "template", "feature_request.yml" }, { "title", "[Idee] " .. Title(e.text) },
			{ "idea", e.text }, { "report", report } })
	end
	local stars = string.rep("★", e.rating) .. string.rep("☆", 5 - e.rating)
	return Query(GITHUB, { { "template", "feedback.yml" }, { "title", "[Feedback] " .. Title(e.text) },
		{ "rating", stars }, { "text", e.text .. "\n\n" .. report } })
end
ns.FeedbackLinks = { Google = GoogleLink, GitHub = GitHubLink, Enc = Enc }

-------------------------------------------------------------------------------
-- "Almost done" window: one highlighted link + 3 simple steps
-------------------------------------------------------------------------------
local send
local function ShowSend(entry)
	local UI, C = ns.UI, ns.UI.C
	if not send then
		send = UI.Window("ChatPilotSend", L.SEND_TITLE, 560, 300)
		local c = send.content
		send.steps = UI.Text(c, "GameFontHighlight")
		send.steps:SetPoint("TOPLEFT", 20, -18)
		send.steps:SetPoint("RIGHT", c, "RIGHT", -20, 0)
		send.steps:SetSpacing(6)
		send.steps:SetText(L.SEND_STEPS)

		send.anon = UI.Button(c, L.SEND_ANON, 220, 28)
		send.anon:SetPoint("TOPLEFT", send.steps, "BOTTOMLEFT", 0, -16)
		send.gh = UI.Button(c, L.SEND_GITHUB, 170, 28)
		send.gh:SetPoint("LEFT", send.anon, "RIGHT", 6, 0)

		local holder = UI.Input(c, 520, "")
		holder:SetPoint("TOPLEFT", send.anon, "BOTTOMLEFT", 0, -12)
		holder:SetPoint("RIGHT", c, "RIGHT", -20, 0)
		local eb = holder.eb
		eb:SetMaxLetters(0)
		eb:SetScript("OnTextChanged", function(self, user)
			if user and send.link then self:SetText(send.link); self:HighlightText() end
		end)
		eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
		eb:SetScript("OnEscapePressed", function() send:Hide() end)
		send.eb = eb

		send.note = UI.Text(c, "GameFontHighlightSmall", C.muted)
		send.note:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -8)
		send.note:SetPoint("RIGHT", c, "RIGHT", -20, 0)

		local done = UI.Button(c, L.SEND_DONE, 120, 28, "accent")
		done:SetPoint("BOTTOMRIGHT", -20, 14)
		done:SetScript("OnClick", function() send:Hide() end)

		function send:Use(which)
			self.which = which
			self.link = which == "github" and GitHubLink(self.entry) or GoogleLink(self.entry)
			self.anon:SetSelected(which ~= "github")
			self.gh:SetSelected(which == "github")
			self.note:SetText(which == "github" and L.SEND_GITHUB_NOTE or L.SEND_ANON_NOTE)
			self.eb:SetText(self.link)
			self.eb:SetCursorPosition(0)
			self.eb:SetFocus()
			self.eb:HighlightText()
		end
		send.anon:SetScript("OnClick", function() send:Use("anon") end)
		send.gh:SetScript("OnClick", function() send:Use("github") end)
	end
	send.entry = entry
	send:Show()
	send:Raise()
	send:Use(send.which or "anon")
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
	eb:SetMaxLetters(1200)
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

	local save = UI.Button(c, L.FB_SEND, 170, 30, "accent")
	save:SetPoint("BOTTOMRIGHT", -20, 14)
	save:SetScript("OnClick", function()
		local text = strtrim(eb:GetText() or "")
		if text == "" then
			ns.Print(L.FB_EMPTY)
			eb:SetFocus()
			return
		end
		text = text:sub(1, 1200)
		local entry = { t = time(), kind = f.kind, rating = f.rating, text = text, v = ns.version }
		table.insert(ns.db.feedback, entry)
		while #ns.db.feedback > 20 do table.remove(ns.db.feedback, 1) end
		eb:SetText("")
		f:Hide()
		ShowSend(entry)
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
