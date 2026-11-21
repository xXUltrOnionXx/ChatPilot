local _, ns = ...
local L = ns.L

-- Keeps your chat after /reload or logging out: the last lines of every chat
-- window are saved on logout and shown again (greyed marker) after login.

local MAX_LINES = 240
local MARKER = "|cff4ec9ff|r|cff6b7383" -- invisible tag to recognise our separator line

-- Double each Blizzard window's live scrollback once per frame, including
-- combat log and temporary whispers, independently of the modern chat look.
ns.OnChatFrame(function(frame)
	if rawget(frame, "ChatPilotHistoryCapacity") or not frame.GetMaxLines or not frame.SetMaxLines then return end
	local current = frame:GetMaxLines()
	if type(current) ~= "number" or ns.IsSecret(current) or current <= 0 then return end
	frame:SetMaxLines(current * 2)
	frame.ChatPilotHistoryCapacity = true
end)

local function Save()
	if not ns.S or not ns.S.keepHistory or not ns.playerKey then return end
	local frames = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if i ~= 2 and f and f.GetNumMessages and f.GetMessageInfo then -- 2 = combat log
			local n = f:GetNumMessages() or 0
			local lines = {}
			for j = math.max(1, n - MAX_LINES + 1), n do
				local text, r, g, b = f:GetMessageInfo(j)
				if type(text) == "string" and not ns.IsSecret(text) and not text:find(MARKER, 1, true) then
					lines[#lines + 1] = { text, r, g, b }
				end
			end
			if #lines > 0 then frames[i] = lines end
		end
	end
	ns.db.history[ns.playerKey] = { t = time(), frames = frames }
end

local function Restore()
	if not ns.S.keepHistory then return end
	local h = ns.db.history[ns.playerKey]
	if not h or not h.frames or time() - (h.t or 0) > 3 * 86400 then return end
	for i, lines in pairs(h.frames) do
		local f = _G["ChatFrame" .. tonumber(i)]
		if f and f.AddMessage then
			for _, line in ipairs(lines) do
				pcall(f.AddMessage, f, line[1], line[2], line[3], line[4])
			end
			f:AddMessage(MARKER .. L.HISTORY_RESTORED:format(date("%d.%m. %H:%M", h.t)) .. "|r")
		end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then
		-- after an import or a full wipe the data must stay exactly as it is
		if ns.noLogoutSave then return end
		pcall(Save)
		-- after saving: empty what you chose under "Good to know"
		if ns.AutoClearOnLogout then pcall(ns.AutoClearOnLogout, ns) end
	else
		C_Timer.After(0.5, function() pcall(Restore) end)
	end
end)
