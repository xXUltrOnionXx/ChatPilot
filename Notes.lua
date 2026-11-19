local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-- Small sticky notes: free to move, resize and minimize. Saved per account.
-- Plain frames only (no secure code), so they also work in combat.

local YELLOW   = { 1, 0.82, 0.30, 1 }
local YELLOWHI = { 1, 0.88, 0.48, 1 }
local HEADER_H = 22
local MIN_W, MIN_H, MAX_W, MAX_H = 150, 90, 520, 520
local MIN_WIDTH_SMALL = 170

local frames = {}  -- note data -> frame
local pool = {}

local function Notes() return ns.db and ns.db.notes or {} end

local function FirstLine(text)
	local line = (text or ""):match("^%s*([^\n]*)") or ""
	line = line:gsub("%s+$", "")
	if line == "" then return nil end
	if #line > 40 then line = line:sub(1, 38):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
	return line
end

local function SavePosition(f)
	local n = rawget(f, "note")
	if not n or not f:GetLeft() then return end
	n.x, n.y = math.floor(f:GetLeft() + 0.5), math.floor(f:GetTop() + 0.5)
	if not n.min then
		n.w, n.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
	end
end

-- Header icons are drawn with plain lines, so they look the same in every
-- client language and font.
local function Line(b, w, h, rot, x, y)
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetColorTexture(unpack(C.dark))
	t:SetSize(w, h)
	t:SetPoint("CENTER", x or 0, y or 0)
	if rot then t:SetRotation(math.rad(rot)) end
	b.lines[#b.lines + 1] = t
	return t
end

local function SetLineColor(b, r, g, bl)
	for _, t in ipairs(b.lines) do t:SetColorTexture(r, g, bl, 1) end
end

local function HeaderButton(header, tip, onClick)
	local b = CreateFrame("Button", nil, header)
	b:SetSize(20, 18)
	b.lines = {}
	local hl = UI.Fill(b, YELLOWHI)
	hl:Hide()
	b.tip = tip
	b:SetScript("OnEnter", function(self)
		hl:Show()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
	b:SetScript("OnClick", onClick)
	return b
end

local Apply -- forward

local function CreateNoteFrame()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H); f:SetMaxResize(MAX_W, MAX_H) end
	f:EnableMouse(true)
	UI.Fill(f, C.bg)
	UI.Border(f, C.border)

	-- header: drag to move, double-click to minimize
	local header = CreateFrame("Button", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_H)
	UI.Fill(header, YELLOW)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SavePosition(f) end)
	header:SetScript("OnDoubleClick", function() ns:ToggleNoteMinimized(rawget(f, "note")) end)
	f.header = header

	f.del = HeaderButton(header, L.NOTE_DELETE, function(self)
		local n = rawget(f, "note")
		if not n then return end
		if (n.text or "") == "" or (rawget(self, "armed") and GetTime() - rawget(self, "armed") < 3) then
			ns:DeleteNote(n)
			return
		end
		self.armed = GetTime()
		SetLineColor(self, 0.75, 0.1, 0.1)
		self.tip = L.NOTE_DELETE_CONFIRM
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.tip)
		GameTooltip:Show()
		C_Timer.After(3, function()
			if rawget(self, "armed") and GetTime() - rawget(self, "armed") >= 2.9 then
				self.armed = nil
				SetLineColor(self, unpack(C.dark))
				self.tip = L.NOTE_DELETE
			end
		end)
	end)
	f.del:SetPoint("RIGHT", -2, 0)
	Line(f.del, 11, 2, 45)
	Line(f.del, 11, 2, -45)

	f.min = HeaderButton(header, L.NOTE_MINIMIZE, function() ns:ToggleNoteMinimized(rawget(f, "note")) end)
	f.min:SetPoint("RIGHT", f.del, "LEFT", -1, 0)
	f.min.dash = Line(f.min, 10, 2, nil, 0, -3)
	f.min.box = {                      -- shown while minimized: "expand" square
		Line(f.min, 10, 1, nil, 0, 4), Line(f.min, 10, 1, nil, 0, -4),
		Line(f.min, 1, 9, nil, -5, 0), Line(f.min, 1, 9, nil, 5, 0),
	}

	f.new = HeaderButton(header, L.NOTE_NEW, function() ns:NewNote(f) end)
	f.new:SetPoint("RIGHT", f.min, "LEFT", -1, 0)
	Line(f.new, 10, 2)
	Line(f.new, 2, 10)

	f.title = UI.Text(header, "GameFontHighlightSmall", C.dark)
	f.title:SetPoint("LEFT", 7, 0)
	f.title:SetPoint("RIGHT", f.new, "LEFT", -4, 0)
	f.title:SetWordWrap(false)

	-- body: scrollable multi-line text
	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 1, -HEADER_H - 1)
	body:SetPoint("BOTTOMRIGHT", -1, 1)
	f.body = body

	local scroll = UI.ScrollArea(body)
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -8, 12)

	local eb = CreateFrame("EditBox", nil, scroll.child)
	eb:SetPoint("TOPLEFT")
	eb:SetPoint("RIGHT", scroll.child, "RIGHT")
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(2000)
	eb:SetFontObject(UI.MessageFont())
	eb:SetTextColor(unpack(C.text))
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnTextChanged", function(self, userInput)
		scroll.child:SetHeight(math.max(self:GetHeight(), 10))
		local n = rawget(f, "note")
		if userInput and n then
			n.text = self:GetText()
			f.title:SetText(FirstLine(n.text) or L.NOTE_TITLE)
		end
		f.placeholder:SetShown(self:GetText() == "" and not self:HasFocus())
	end)
	eb:SetScript("OnEditFocusGained", function() f.placeholder:Hide() end)
	eb:SetScript("OnEditFocusLost", function(self) f.placeholder:SetShown(self:GetText() == "") end)
	eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
		y = -y
		if y < top then scroll:SetVerticalScroll(y)
		elseif y + h > top + height then scroll:SetVerticalScroll(math.min(y + h - height, scroll:GetVerticalScrollRange())) end
	end)
	scroll:SetScript("OnSizeChanged", function(_, width)
		scroll.child:SetWidth(width)
		eb:SetWidth(width)
	end)
	f.eb = eb

	f.placeholder = UI.Text(body, "GameFontHighlightSmall", C.muted)
	f.placeholder:SetPoint("TOPLEFT", 9, -8)
	f.placeholder:SetText(L.NOTE_PLACEHOLDER)

	body:EnableMouse(true)
	body:SetScript("OnMouseDown", function() eb:SetFocus() end)

	-- resize grip (bottom right)
	local grip = CreateFrame("Button", nil, body)
	grip:SetSize(12, 12)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	for i = 1, 2 do
		local t = grip:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(unpack(C.muted))
		t:SetSize(i == 1 and 10 or 5, 1)
		t:SetPoint("BOTTOMRIGHT", -1, i == 1 and 4 or 1)
		t:SetRotation(math.rad(45))
	end
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); SavePosition(f) end)
	f.grip = grip

	return f
end

function Apply(f)
	local n = rawget(f, "note")
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", n.x, n.y)
	f.title:SetText(FirstLine(n.text) or L.NOTE_TITLE)
	if f.eb:GetText() ~= (n.text or "") then f.eb:SetText(n.text or "") end
	f.placeholder:SetShown((n.text or "") == "" and not f.eb:HasFocus())
	f.eb:SetFontObject(UI.MessageFont())
	f.min.dash:SetShown(not n.min)
	for _, t in ipairs(f.min.box) do t:SetShown(n.min and true or false) end
	if n.min then
		f:SetSize(math.max(MIN_WIDTH_SMALL, math.min(n.w or 220, 240)), HEADER_H + 2)
		f.body:Hide()
	else
		f:SetSize(n.w or 220, n.h or 160)
		f.body:Show()
	end
end

local function FrameFor(n)
	local f = frames[n]
	if not f then
		f = table.remove(pool) or CreateNoteFrame()
		f.note = n
		frames[n] = f
	end
	return f
end

local function ShowNote(n)
	local f = FrameFor(n)
	Apply(f)
	f:Show()
	return f
end

function ns:NotesShown()
	return self.db and self.db.notesShown and #Notes() > 0 or false
end

function ns:ShowNotes()
	if #Notes() == 0 then return self:NewNote() end
	self.db.notesShown = true
	for _, n in ipairs(Notes()) do ShowNote(n) end
end

function ns:HideNotes()
	if self.db then self.db.notesShown = false end
	for n, f in pairs(frames) do
		f.eb:ClearFocus()
		f:Hide()
	end
end

function ns:ToggleNotes()
	if self:NotesShown() then self:HideNotes() else self:ShowNotes() end
end

function ns:NewNote(from)
	local list = Notes()
	if not self.db then return end
	local x, y
	if from and from.GetLeft and from:GetLeft() then
		x, y = from:GetLeft() + 24, from:GetTop() - 24
	else
		local w, h = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
		local k = #list % 8
		x, y = math.floor(w / 2 - 110 + k * 24), math.floor(h / 2 + 120 - k * 24)
	end
	local n = { text = "", x = math.floor(x), y = math.floor(y), w = 220, h = 160, min = false }
	list[#list + 1] = n
	self.db.notesShown = true
	for _, other in ipairs(list) do if other ~= n then ShowNote(other) end end
	local f = ShowNote(n)
	f.eb:SetFocus()
	return n
end

function ns:DeleteNote(n)
	local list = Notes()
	for i, other in ipairs(list) do
		if other == n then table.remove(list, i) break end
	end
	local f = frames[n]
	if f then
		frames[n] = nil
		f.eb:ClearFocus()
		f:Hide()
		f.note = nil
		f.del.armed = nil
		SetLineColor(f.del, unpack(C.dark))
		f.del.tip = L.NOTE_DELETE
		pool[#pool + 1] = f
	end
	GameTooltip:Hide()
	if #list == 0 and self.db then self.db.notesShown = false end
	if self.UpdateChatButtons then self:UpdateChatButtons() end
end

function ns:ToggleNoteMinimized(n)
	if not n then return end
	local f = frames[n]
	if f then SavePosition(f) end
	n.min = not n.min
	if f then
		if n.min then f.eb:ClearFocus() end
		Apply(f)
	end
end

-- A fight starts: stop typing in notes (the text is already saved).
function ns:ReleaseNoteFocus()
	for _, f in pairs(frames) do
		if f.eb:HasFocus() then f.eb:ClearFocus() end
	end
end

-- Font size / bold from the settings also applies to notes.
function ns:RefreshNotesFont()
	for _, f in pairs(frames) do f.eb:SetFontObject(UI.MessageFont()) end
end

local prevLogin = ns.OnLogin
function ns:OnLogin()
	if prevLogin then prevLogin(self) end
	self.db.notes = self.db.notes or {}
	if self.S.notes and self.db.notesShown then
		C_Timer.After(1, function() if ns.S.notes and ns.db.notesShown then ns:ShowNotes() end end)
	end
end

ns._noteFrames = frames -- for tests
