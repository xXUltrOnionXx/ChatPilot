local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = UI.C

-------------------------------------------------------------------------------
-- Back up and move your data: export as text (JSON), import it again.
-- A game addon cannot write files, so the text is shown in a window to copy.
-- Everything that comes in is checked and cut down to safe shapes first.
-------------------------------------------------------------------------------
local FORMAT = 1
local MAX_INPUT = 12 * 1024 * 1024
local MAX_STRING = 8000
local MAX_NODES = 600000
local MAX_DEPTH = 10

-- JSON writer -----------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function Esc(s)
	return (s:gsub('[%c"\\]', function(c) return ESC[c] or string.format("\\u%04x", c:byte()) end))
end

local function Num(v)
	if v ~= v or v == math.huge or v == -math.huge then return "0" end
	if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
	return string.format("%.10g", v)
end

local function Enc(v, buf, depth)
	local t = type(v)
	if t == "string" then
		buf[#buf + 1] = '"' .. Esc(v) .. '"'
	elseif t == "number" then
		buf[#buf + 1] = Num(v)
	elseif t == "boolean" then
		buf[#buf + 1] = v and "true" or "false"
	elseif t == "table" and depth < MAX_DEPTH + 2 then
		local n, count = #v, 0
		for _ in pairs(v) do count = count + 1 end
		local sep = depth <= 4 and ",\n" or ","
		if n > 0 and n == count then
			buf[#buf + 1] = depth <= 4 and "[\n" or "["
			for i = 1, n do
				if i > 1 then buf[#buf + 1] = sep end
				Enc(v[i], buf, depth + 1)
			end
			buf[#buf + 1] = "]"
		else
			buf[#buf + 1] = depth <= 4 and "{\n" or "{"
			local first = true
			for k, val in pairs(v) do
				local key
				if type(k) == "string" then key = k
				elseif type(k) == "number" then key = "#n:" .. Num(k) end
				local vt = type(val)
				if key and (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
					if not first then buf[#buf + 1] = sep end
					first = false
					buf[#buf + 1] = '"' .. Esc(key) .. '":'
					Enc(val, buf, depth + 1)
				end
			end
			buf[#buf + 1] = "}"
		end
	else
		buf[#buf + 1] = "null"
	end
end

-- JSON reader -----------------------------------------------------------------
local function Utf8(cp)
	if cp < 0x80 then return string.char(cp) end
	if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
	if cp < 0x10000 then
		return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
	end
	return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64,
		0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local SIMPLE = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }

local function Decode(str)
	local pos, nodes = 1, 0
	local function fail(msg) error({ msg = msg .. " (" .. pos .. ")" }, 0) end
	local function skip() pos = str:find("[^ \t\r\n]", pos) or (#str + 1) end

	local function readString()
		local buf, i = {}, pos + 1
		while true do
			local j = str:find('["\\]', i)
			if not j then fail("string") end
			buf[#buf + 1] = str:sub(i, j - 1)
			if str:sub(j, j) == '"' then pos = j + 1 break end
			local c = str:sub(j + 1, j + 1)
			if c == "u" then
				local hex = str:match("^%x%x%x%x", j + 2)
				if not hex then fail("escape") end
				local cp = tonumber(hex, 16)
				i = j + 6
				if cp >= 0xD800 and cp < 0xDC00 then
					local lo = str:match("^\\u(%x%x%x%x)", i)
					local lov = lo and tonumber(lo, 16)
					if lov and lov >= 0xDC00 and lov < 0xE000 then
						cp = 0x10000 + (cp - 0xD800) * 1024 + (lov - 0xDC00)
						i = i + 6
					else
						cp = 0xFFFD
					end
				elseif cp >= 0xDC00 and cp < 0xE000 then
					cp = 0xFFFD
				end
				buf[#buf + 1] = Utf8(cp)
			elseif SIMPLE[c] then
				buf[#buf + 1] = SIMPLE[c]
				i = j + 2
			else
				fail("escape")
			end
		end
		return table.concat(buf)
	end

	local value
	function value(depth)
		if depth > MAX_DEPTH + 2 then fail("too deep") end
		nodes = nodes + 1
		if nodes > MAX_NODES then fail("too big") end
		skip()
		local c = str:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			skip()
			if str:sub(pos, pos) == "}" then pos = pos + 1 return t end
			while true do
				skip()
				if str:sub(pos, pos) ~= '"' then fail("key") end
				local k = readString()
				skip()
				if str:sub(pos, pos) ~= ":" then fail("colon") end
				pos = pos + 1
				local v = value(depth + 1)
				local num = k:match("^#n:(.+)$")
				if num and tonumber(num) then k = tonumber(num) end
				t[k] = v
				skip()
				local d = str:sub(pos, pos)
				pos = pos + 1
				if d == "}" then break end
				if d ~= "," then fail("comma") end
			end
			return t
		elseif c == "[" then
			local t = {}
			pos = pos + 1
			skip()
			if str:sub(pos, pos) == "]" then pos = pos + 1 return t end
			while true do
				t[#t + 1] = value(depth + 1)
				skip()
				local d = str:sub(pos, pos)
				pos = pos + 1
				if d == "]" then break end
				if d ~= "," then fail("comma") end
			end
			return t
		elseif c == '"' then
			return readString()
		elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local num = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
			if not num or num == "" then fail("value") end
			pos = pos + #num
			local n = tonumber(num)
			if not n then fail("number") end
			return n
		end
	end

	local ok, res = pcall(function()
		local v = value(0)
		skip()
		if pos <= #str then fail("trailing") end
		return v
	end)
	if ok then return res end
	return nil, type(res) == "table" and res.msg or "error"
end

ns.JSON = { encode = function(v) local b = {}; Enc(v, b, 0); return table.concat(b) end, decode = Decode }

-- cut incoming data down to plain, bounded values ------------------------------
local function CleanString(s)
	if #s > MAX_STRING then s = s:sub(1, MAX_STRING):gsub("[\192-\255][\128-\191]*$", "") end
	return s
end

local function Clean(v, depth, budget)
	local t = type(v)
	budget.n = budget.n + 1
	if budget.n > MAX_NODES then return nil end
	if t == "string" then return CleanString(v)
	elseif t == "number" then
		if v ~= v or math.abs(v) > 1e15 then return 0 end
		return v
	elseif t == "boolean" then return v
	elseif t == "table" and depth <= MAX_DEPTH then
		local out = {}
		for k, val in pairs(v) do
			local kt = type(k)
			if kt == "number" or (kt == "string" and #k <= 80) then
				local c = Clean(val, depth + 1, budget)
				if c ~= nil then out[k] = c end
			end
		end
		return out
	end
	return nil
end

local function CleanTable(v)
	if type(v) ~= "table" then return nil end
	return Clean(v, 0, { n = 0 })
end

local function Clamp(v, lo, hi, default)
	if type(v) ~= "number" then return default end
	return math.max(lo, math.min(hi, v))
end

-- what an export contains -------------------------------------------------------
local PARTS = { "settings", "notes", "chats" }

function ns:BackupBuild(parts)
	local db = self.db
	local out = { app = "ChatPilot", format = FORMAT, version = self.version, created = time() }
	if parts.settings then
		out.settings = db.settings
		out.snippets = db.snippets
	end
	if parts.notes then out.notes = db.notes end
	if parts.chats then
		out.chats = { windows = db.cwin, history = db.history, whispers = db.whispers, mentions = db.mentions }
	end
	-- one section per line: easy to read and to check in any text editor
	local lines = {}
	for _, key in ipairs({ "app", "format", "version", "created", "settings", "snippets", "notes", "chats" }) do
		if out[key] ~= nil then
			local b = {}
			Enc(out[key], b, 0)
			lines[#lines + 1] = '"' .. key .. '":' .. table.concat(b)
		end
	end
	return "{\n" .. table.concat(lines, ",\n") .. "\n}"
end

function ns:BackupParse(text)
	if type(text) ~= "string" then return nil, "empty" end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil, "empty" end
	if #text > MAX_INPUT then return nil, "too big" end
	local data, err = Decode(text)
	if type(data) ~= "table" or data.app ~= "ChatPilot" then return nil, err or "app" end
	if type(data.format) ~= "number" or data.format > FORMAT then return nil, "format" end
	local info = { version = type(data.version) == "string" and data.version or "?", created = tonumber(data.created) }
	info.settings = type(data.settings) == "table"
	info.notes = type(data.notes) == "table" and #data.notes or nil
	if type(data.chats) == "table" then
		local w = type(data.chats.windows) == "table" and data.chats.windows.windows
		info.chats = type(w) == "table" and #w or 0
	end
	return data, info
end

-- big exports: compressed, as short pages -------------------------------------
-- The game's text box shows nothing once the text gets too long, so a big
-- export is packed small and split into pages of PAGE characters.
local PAGE = 6000
local floor = math.floor
local unpackFn = unpack or table.unpack
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC, DEC = {}, {}
for i = 1, 64 do ENC[i - 1] = B64:sub(i, i); DEC[B64:byte(i)] = i - 1 end

local function B64Enc(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		out[#out + 1] = ENC[floor(n / 262144)] .. ENC[floor(n / 4096) % 64]
			.. (b and ENC[floor(n / 64) % 64] or "=") .. (c and ENC[n % 64] or "=")
	end
	return table.concat(out)
end

local function B64Dec(s)
	s = s:gsub("[^%w%+/]", "")
	local out = {}
	for i = 1, #s, 4 do
		local a, b, c, d = s:byte(i, i + 3)
		a, b = DEC[a], DEC[b]
		c, d = c and DEC[c], d and DEC[d]
		if not a or not b then return nil end
		local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
		out[#out + 1] = string.char(floor(n / 65536)) .. (c and string.char(floor(n / 256) % 256) or "") .. (d and string.char(n % 256) or "")
	end
	return table.concat(out)
end

-- LZ77: 1..127 = that many literal bytes follow; 128..255 = copy (len-3) from 2 byte offset
local function LZPack(s)
	local out, n, tbl = {}, #s, {}
	local i, litStart = 1, 1
	local function Flush(upto)
		local p = litStart
		while p <= upto do
			local e = math.min(upto, p + 126)
			out[#out + 1] = string.char(e - p + 1) .. s:sub(p, e)
			p = e + 1
		end
	end
	local function Add(k)
		local key = s:sub(k, k + 2)
		local c = tbl[key]
		if not c then c = {}; tbl[key] = c end
		c[#c + 1] = k
		if #c > 24 then table.remove(c, 1) end
	end
	while i <= n do
		local len, off = 0, 0
		if i + 2 <= n then
			local c = tbl[s:sub(i, i + 2)]
			if c then
				for ci = #c, 1, -1 do
					local j = c[ci]
					if i - j > 65535 then break end
					local l = 3
					while l < 130 and i + l <= n and s:byte(j + l) == s:byte(i + l) do l = l + 1 end
					if l > len then len, off = l, i - j end
					if l >= 130 then break end
				end
			end
		end
		if len >= 4 or (len == 3 and off < 256) then
			Flush(i - 1)
			out[#out + 1] = string.char(128 + len - 3, off % 256, floor(off / 256))
			for k = i, math.min(i + len - 1, n - 2) do Add(k) end
			i = i + len
			litStart = i
		else
			if i + 2 <= n then Add(i) end
			i = i + 1
		end
	end
	Flush(n)
	return table.concat(out)
end

local function LZUnpack(z)
	local buf, nb, i, n = {}, 0, 1, #z
	while i <= n do
		local c = z:byte(i)
		i = i + 1
		if c < 128 then
			if c == 0 or i + c - 1 > n then return nil end
			for k = 0, c - 1 do nb = nb + 1; buf[nb] = z:byte(i + k) end
			i = i + c
		else
			if i + 1 > n then return nil end
			local off = z:byte(i) + z:byte(i + 1) * 256
			i = i + 2
			if off == 0 or off > nb then return nil end
			for _ = 1, c - 128 + 3 do nb = nb + 1; buf[nb] = buf[nb - off] end
		end
		if nb > MAX_INPUT then return nil end
	end
	local parts = {}
	for p = 1, nb, 2000 do parts[#parts + 1] = string.char(unpackFn(buf, p, math.min(nb, p + 1999))) end
	return table.concat(parts)
end

-- text -> list of pages (a short export stays one readable page)
function ns:BackupPages(text)
	if #text <= PAGE then return { text } end
	local b = B64Enc(LZPack(text))
	local n = math.ceil(#b / PAGE)
	local pages = {}
	for i = 1, n do pages[i] = ("CP1|%d/%d|"):format(i, n) .. b:sub((i - 1) * PAGE + 1, i * PAGE) end
	return pages
end

-- "CP1|2/6|..." -> 2, 6, chunk
function ns:BackupPageInfo(text)
	if type(text) ~= "string" then return nil end
	local i, n, rest = text:match("^%s*CP1|(%d+)/(%d+)|(.*)$")
	i, n = tonumber(i), tonumber(n)
	if not i or i < 1 or i > n or n > 600 then return nil end
	return i, n, rest
end

-- all chunks together -> the plain export text
function ns:BackupJoin(parts, n)
	local t = {}
	for i = 1, n do
		if not parts[i] then return nil end
		t[i] = parts[i]
	end
	local z = B64Dec(table.concat(t))
	if not z or z == "" then return nil end
	local plain = LZUnpack(z)
	return plain ~= "" and plain or nil
end

-- checking what goes into the saved data ---------------------------------------
local SKIP_SETTINGS = { seenVersion = true, tutorialSeen = true, tutorialVersion = true, tutorialDone = true }

local function ImportSettings(db, data)
	local src = CleanTable(data.settings)
	if src then
		for k, v in pairs(src) do
			if type(k) == "string" and not SKIP_SETTINGS[k] then
				local def = ns.defaults[k]
				if def == nil or type(def) == type(v) then db.settings[k] = v end
			end
		end
	end
	local snip = CleanTable(data.snippets)
	if snip then db.snippets = snip end
end

local function ImportNotes(db, data)
	local src = CleanTable(data.notes)
	if not src then return end
	local list = {}
	for i = 1, math.min(#src, 100) do
		local n = src[i]
		if type(n) == "table" and type(n.text) == "string" then
			list[#list + 1] = {
				text = n.text,
				x = Clamp(n.x, -5000, 20000, 300), y = Clamp(n.y, -5000, 20000, 500),
				w = Clamp(n.w, 120, 2000, 220), h = Clamp(n.h, 80, 2000, 160),
				min = n.min == true,
			}
		end
	end
	db.notes = list
	db.notesShown = #list > 0
end

local function ImportChats(db, data)
	local ch = type(data.chats) == "table" and data.chats or nil
	if not ch then return end
	local cw = CleanTable(ch.windows)
	if cw then
		local windows, groups, maxId = {}, {}, 0
		for _, wd in ipairs(type(cw.windows) == "table" and cw.windows or {}) do
			if type(wd) == "table" and type(wd.id) == "number" then
				wd.cats = type(wd.cats) == "table" and wd.cats or {}
				local lines = {}
				for _, l in ipairs(type(wd.lines) == "table" and wd.lines or {}) do
					if type(l) == "table" and type(l[1]) == "string" and #lines < 400 then lines[#lines + 1] = l end
				end
				wd.lines = lines
				windows[#windows + 1] = wd
				if wd.id > maxId then maxId = wd.id end
			end
		end
		for _, g in ipairs(type(cw.groups) == "table" and cw.groups or {}) do
			if type(g) == "table" and type(g.order) == "table" then
				g.w, g.h = Clamp(g.w, 100, 4000, 380), Clamp(g.h, 60, 4000, 200)
				g.x, g.y = Clamp(g.x, -5000, 20000, 300), Clamp(g.y, -5000, 20000, 500)
				groups[#groups + 1] = g
			end
		end
		cw.windows, cw.groups = windows, groups
		cw.nextId = math.max(tonumber(cw.nextId) or 0, maxId + 1)
		db.cwin = cw
	end
	for _, key in ipairs({ "history", "whispers", "mentions" }) do
		local t = CleanTable(ch[key])
		if t then db[key] = t end
	end
end

-- parts: { settings = bool, notes = bool, chats = bool }
function ns:BackupApply(data, parts)
	local db = self.db
	if InCombatLockdown() then return false, L.BK_COMBAT end
	if parts.settings then ImportSettings(db, data) end
	if parts.notes then ImportNotes(db, data) end
	if parts.chats then ImportChats(db, data) end
	-- the live windows would write their own state over it at logout
	self.noLogoutSave = true
	return true
end

-- every bit of data, gone: the save file is rewritten empty at the reload
function ns:WipeAllData()
	if InCombatLockdown() then ns.Print(L.BK_COMBAT) return false end
	local keep = ns.db
	_G.ChatPilotBackup = nil
	for k in pairs(keep) do keep[k] = nil end
	ns.noLogoutSave = true
	ns.reloading = true
	if ReloadUI then ReloadUI() end
	return true
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local win

local function CountText(info)
	local parts = {}
	if info.settings then parts[#parts + 1] = L.BK_SETTINGS end
	if info.notes then parts[#parts + 1] = L.BK_SUM_NOTES:format(info.notes) end
	if info.chats then parts[#parts + 1] = L.BK_SUM_CHATS:format(info.chats) end
	return table.concat(parts, "  ·  ")
end

local function CreateWin()
	local f = UI.Window("ChatPilotBackup", L.BK_TITLE_EXPORT, 640, 570)
	f.sel = { settings = true, notes = true, chats = true }

	-- what to include
	f.rows = {}
	for i, key in ipairs(PARTS) do
		local r = CreateFrame("Frame", nil, f.content)
		r:SetSize(600, 24)
		r:SetPoint("TOPLEFT", 16, -14 - (i - 1) * 28)
		r.toggle = UI.Toggle(r, function(v) f.sel[key] = v; if f.OnSelect then f:OnSelect() end end)
		r.toggle:SetPoint("LEFT", 0, 0)
		r.toggle:SetValue(true)
		r.label = UI.Text(r, "GameFontHighlight")
		r.label:SetPoint("LEFT", 52, 0)
		r.label:SetText(L["BK_" .. key:upper()])
		f.rows[key] = r
	end

	local box = CreateFrame("Frame", nil, f.content)
	box:SetPoint("TOPLEFT", 14, -104)
	box:SetPoint("BOTTOMRIGHT", -14, 146)
	UI.Fill(box, C.panel)
	UI.Border(box)
	local scroll = UI.ScrollArea(box)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	local eb = CreateFrame("EditBox", nil, scroll.child)
	eb:SetPoint("TOPLEFT")
	eb:SetPoint("RIGHT", scroll.child, "RIGHT")
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(0)
	if eb.SetMaxBytes then eb:SetMaxBytes(0) end
	eb:SetFontObject(UI.MessageFont())
	eb:SetScript("OnEscapePressed", function() f:Hide() end)
	eb:SetScript("OnTextChanged", function(self, userInput)
		if f.mode == "export" and userInput and f.exportText then
			self:SetText(f.exportText)
			self:HighlightText()
		elseif f.mode == "import" and userInput and f.OnPaste then
			f:OnPaste()
		end
		scroll.child:SetHeight(math.max(self:GetHeight(), 10))
	end)
	scroll:SetScript("OnSizeChanged", function(_, width)
		scroll.child:SetWidth(width)
		eb:SetWidth(width)
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() eb:SetFocus() end)
	f.eb, f.scroll = eb, scroll

	f.hint = UI.Text(f.content, "GameFontHighlightSmall", C.muted)
	f.hint:SetPoint("BOTTOMLEFT", 16, 48)
	f.hint:SetPoint("RIGHT", f.content, "RIGHT", -16, 0)
	f.hint:SetJustifyH("LEFT")
	f.hint:SetSpacing(2)
	f.status = UI.Text(f.content, "GameFontHighlight", C.accent)
	f.status:SetPoint("BOTTOMLEFT", 16, 24)
	f.status:SetPoint("RIGHT", f.content, "RIGHT", -300, 0)
	f.status:SetJustifyH("LEFT")

	-- file route (the save file of the game) and page buttons
	f.fileBtn = UI.Button(f.content, L.BK_FILE_SAVE, 220, 28)
	f.fileBtn:SetPoint("BOTTOMLEFT", 14, 108)
	f.nextBtn = UI.Button(f.content, ">", 44, 28)
	f.nextBtn:SetPoint("BOTTOMRIGHT", -14, 108)
	f.prevBtn = UI.Button(f.content, "<", 44, 28)
	f.prevBtn:SetPoint("RIGHT", f.nextBtn, "LEFT", -6, 0)
	f.prevBtn:SetScript("OnClick", function() f:SetPage((f.page or 1) - 1) end)
	f.nextBtn:SetScript("OnClick", function() f:SetPage((f.page or 1) + 1) end)

	f.close = UI.Button(f.content, CLOSE or "Close", 100, 28)
	f.close:SetPoint("BOTTOMRIGHT", -14, 12)
	f.close:SetScript("OnClick", function() f:Hide() end)
	f.doImport = UI.ConfirmButton(f.content, L.BK_DO, 190, 28, function() f:RunImport() end)
	f.doImport:SetPoint("RIGHT", f.close, "LEFT", -8, 0)

	function f:RunImport()
		if not self.data then return end
		local ok, err = ns:BackupApply(self.data, self.sel)
		if not ok then self.status:SetText(err or "") return end
		ns.Print(L.BK_DONE)
		if ReloadUI then ReloadUI() end
	end

	function f:SetPage(p)
		local n = self.pages and #self.pages or 0
		if n == 0 then return end
		self.page = math.max(1, math.min(n, p))
		self.exportText = self.pages[self.page]
		eb:SetText(self.exportText)
		self.status:SetText(n > 1 and L.BK_PAGE:format(self.page, n, #self.fullText) or L.BK_SIZE:format(#self.fullText))
		self.prevBtn:SetShown(n > 1)
		self.nextBtn:SetShown(n > 1)
		eb:SetFocus()
		eb:HighlightText()
		C_Timer.After(0, function() scroll.child:SetHeight(math.max(eb:GetHeight(), 10)) end)
	end

	function f:Refresh()
		if self.mode == "export" then
			local any = self.sel.settings or self.sel.notes or self.sel.chats
			local okB, built = pcall(ns.BackupBuild, ns, self.sel)
			if not okB then self.status:SetText(tostring(built)) return end
			self.fullText = any and built or ""
			if not any then
				self.pages, self.exportText = nil, ""
				eb:SetText("")
				self.status:SetText(L.BK_EMPTY)
				self.prevBtn:Hide()
				self.nextBtn:Hide()
				return
			end
			local okP, pages = pcall(ns.BackupPages, ns, self.fullText)
			if not okP then self.status:SetText(tostring(pages)) return end
			self.pages = pages
			self:SetPage(1)
		end
	end

	-- the file route: the game writes the text into its own save file at reload/logout
	function f:FileAction()
		if self.mode == "export" then
			if not self.fullText or self.fullText == "" then return end
			_G.ChatPilotBackup = { text = self.fullText, created = time(), version = ns.version }
			self.status:SetText(L.BK_FILE_SAVED)
		else
			local fb = _G.ChatPilotBackup
			if type(fb) ~= "table" or type(fb.text) ~= "string" or fb.text == "" then
				self.status:SetText(L.BK_FILE_NONE)
				return
			end
			self:Analyze(fb.text)
		end
	end
	f.fileBtn:SetScript("OnClick", function() f:FileAction() end)
	f.OnSelect = f.Refresh

	function f:Analyze(text)
		text = text or eb:GetText()
		local data, info = ns:BackupParse(text)
		self.data = data
		if not data then
			self.status:SetText(text == "" and "" or L.BK_BAD)
			self.doImport:Hide()
			for _, key in ipairs(PARTS) do self.rows[key]:Hide() end
			return
		end
		self.status:SetText(L.BK_FOUND:format(info.version, CountText(info)))
		for _, key in ipairs(PARTS) do
			local present = (key == "settings" and info.settings) or (key == "notes" and info.notes ~= nil) or (key == "chats" and info.chats ~= nil)
			self.rows[key]:SetShown(present and true or false)
			self.sel[key] = present and true or false
			self.rows[key].toggle:SetValue(present and true or false)
		end
		self.doImport:Show()
	end
	function f:OnPaste()
		C_Timer.After(0.25, function()
			if not (self:IsShown() and self.mode == "import") then return end
			local text = eb:GetText()
			local i, n, chunk = ns:BackupPageInfo(text)
			if not i then self.parts = nil; self:Analyze(text) return end
			if not self.parts or self.partsN ~= n then self.parts, self.partsN = {}, n end
			self.parts[i] = chunk
			eb:SetText("")
			local got = 0
			for k = 1, n do if self.parts[k] then got = got + 1 end end
			if got < n then
				self.data = nil
				self.doImport:Hide()
				self.status:SetText(L.BK_PART:format(got, n))
				return
			end
			local full = ns:BackupJoin(self.parts, n)
			self.parts = nil
			if not full then self.status:SetText(L.BK_BAD) return end
			self:Analyze(full)
		end)
	end
	return f
end

function ns:ShowBackup(mode)
	win = win or CreateWin()
	win.mode = mode
	win.data = nil
	win.title:SetText(mode == "export" and L.BK_TITLE_EXPORT or L.BK_TITLE_IMPORT)
	win.hint:SetText(mode == "export" and L.BK_HINT_EXPORT or L.BK_HINT_IMPORT)
	win.status:SetText("")
	win.sel = { settings = true, notes = true, chats = true }
	for _, key in ipairs(PARTS) do
		win.rows[key].toggle:SetValue(true)
		win.rows[key]:SetShown(mode == "export")
	end
	win.doImport:SetShown(false)
	win.exportText, win.pages, win.fullText, win.parts = nil, nil, nil, nil
	win.fileBtn.label:SetText(mode == "export" and L.BK_FILE_SAVE or L.BK_FILE_LOAD)
	win.prevBtn:Hide()
	win.nextBtn:Hide()
	win.hint:SetText((mode == "export" and L.BK_HINT_EXPORT or L.BK_HINT_IMPORT) .. "\n" .. (mode == "export" and L.BK_HINT_FILE_EXPORT or L.BK_HINT_FILE_IMPORT))
	win.eb:SetText("")
	win:Show()
	win:Raise()
	if mode == "export" then
		win:Refresh()
	else
		win.eb:SetFocus()
	end
end
