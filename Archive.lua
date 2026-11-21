local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Archive of a chat window: the older lines that no longer fit the window.
-- Plain text, newest at the bottom, with a search box. It only shows text.
-------------------------------------------------------------------------------
local win

local function Fill(f)
	local list = ns:CW_ArchiveGet(f.id)
	local q = (f.search.eb:GetText() or ""):lower()
	f.msg:Clear()
	local n = 0
	for _, line in ipairs(list) do
		if q == "" or line:lower():find(q, 1, true) then
			f.msg:AddMessage(line, 0.86, 0.89, 0.93)
			n = n + 1
		end
	end
	f.status:SetText(#list == 0 and L.AR_EMPTY or L.AR_COUNT:format(n, #list))
	f.msg:ScrollToBottom()
end

local function Create()
	local f = UI.Window("ChatPilotArchive", L.AR_TITLE, 660, 540)
	f.search = UI.Input(f.content, 300, L.AR_SEARCH)
	f.search:SetPoint("TOPLEFT", 14, -12)
	f.search.eb:SetMaxLetters(80)
	f.search.eb:HookScript("OnTextChanged", function(_, user) if user then Fill(f) end end)

	local box = CreateFrame("Frame", nil, f.content)
	box:SetPoint("TOPLEFT", 14, -50)
	box:SetPoint("BOTTOMRIGHT", -14, 52)
	UI.Fill(box, C.panel)
	UI.Border(box)
	local m = CreateFrame("ScrollingMessageFrame", nil, box)
	m:SetPoint("TOPLEFT", 10, -8)
	m:SetPoint("BOTTOMRIGHT", -10, 8)
	m:SetMaxLines(5000)
	m:SetFading(false)
	m:SetJustifyH("LEFT")
	m:SetFontObject(UI.MessageFont())
	m:SetIndentedWordWrap(true)
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseWheel", function(self, delta)
		for _ = 1, 3 do if delta > 0 then self:ScrollUp() else self:ScrollDown() end end
	end)
	f.msg = m

	f.status = UI.Text(f.content, "GameFontHighlight", C.accent)
	f.status:SetPoint("BOTTOMLEFT", 16, 24)
	f.close = UI.Button(f.content, CLOSE or "Close", 100, 28)
	f.close:SetPoint("BOTTOMRIGHT", -14, 12)
	f.close:SetScript("OnClick", function() f:Hide() end)
	f.clear = UI.ConfirmButton(f.content, L.AR_CLEAR, 200, 28, function()
		if f.id and ns.CW_ArchiveClear then ns:CW_ArchiveClear(f.id) end
		Fill(f)
	end)
	f.clear:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
	return f
end

function ns:ShowArchive(id)
	win = win or Create()
	if not id then
		-- no window given: the first one that has an archive
		for _, w in ipairs(self.CW_List and self:CW_List() or {}) do
			if #self:CW_ArchiveGet(w.id) > 0 then id = w.id; break end
		end
	end
	win.id = id
	local name
	for _, w in ipairs(self.CW_List and self:CW_List() or {}) do if w.id == id then name = w.name end end
	win.title:SetText(name and (L.AR_TITLE .. " - " .. name) or L.AR_TITLE)
	win.search.eb:SetText("")
	win:Show()
	win:Raise()
	Fill(win)
end
