local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Search over all chats: the game's chat windows, your own windows and their
-- archives, in one place. Plain text only; it never sends anything.
-------------------------------------------------------------------------------
local win
local MAX_RESULTS = 1500

local function Plain(text)
	if type(text) ~= "string" or ns.IsSecret(text) then return nil end
	local ok, s = pcall(ns.StripEscapes, text)
	if not ok then return nil end
	s = s:gsub("|n", " ")
	return s
end

-- every saved line as { source name, plain text }
local function Collect()
	local all = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if i ~= 2 and f and f.GetNumMessages and f.GetMessageInfo then -- 2 = combat log
			local okN, name = pcall(GetChatWindowInfo, i)
			if not okN or type(name) ~= "string" or name == "" then name = "Chat " .. i end
			local okC, n = pcall(f.GetNumMessages, f)
			for j = 1, (okC and tonumber(n)) or 0 do
				local okM, text = pcall(f.GetMessageInfo, f, j)
				local plain = okM and Plain(text)
				if plain and plain ~= "" then all[#all + 1] = { name, plain } end
			end
		end
	end
	for _, src in ipairs(ns.CW_AllText and ns:CW_AllText() or {}) do
		for _, line in ipairs(src.lines) do all[#all + 1] = { src.name, line } end
	end
	return all
end

local function Fill(f)
	local q = (f.search.eb:GetText() or ""):lower()
	local all = f.all or {}
	f.msg:Clear()
	local hits = {}
	for _, e in ipairs(all) do
		if q == "" or e[2]:lower():find(q, 1, true) then hits[#hits + 1] = e end
	end
	local first = math.max(1, #hits - MAX_RESULTS + 1)
	for i = first, #hits do
		local e = hits[i]
		f.msg:AddMessage("|cff8c96a8[" .. e[1] .. "]|r " .. e[2], 0.86, 0.89, 0.93)
	end
	if #all == 0 then
		f.status:SetText(L.SR_EMPTY)
	elseif #hits == 0 then
		f.status:SetText(L.SR_NONE)
	else
		f.status:SetText(L.SR_COUNT:format(#hits, #all))
	end
	f.msg:ScrollToBottom()
end

local function Create()
	local f = UI.Window("ChatPilotSearchWindow", L.SR_TITLE, 700, 540)
	f.search = UI.Input(f.content, 320, L.AR_SEARCH)
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
	m:SetMaxLines(MAX_RESULTS + 50)
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
	return f
end

function ns:ShowSearch(query)
	win = win or Create()
	local ok, all = pcall(Collect)
	win.all = ok and all or {}
	if not ok then ns.ReportError("search", all) end
	win.search.eb:SetText(type(query) == "string" and query or "")
	win:Show()
	win:Raise()
	Fill(win)
end
