local _, ns = ...

-- Small comforts while typing in any chat input box:
--  * quiet keyboard sounds, mechanical or soft (can be switched off under Typing)
--  * the arrow keys move the cursor between the letters (always on): the game
--    normally uses them to walk unless Alt is held down.

local SOUND = "Interface\\AddOns\\ChatPilot\\media\\sounds\\"
local keyN = 0

-- sounds to choose from (files media\sounds\<kind>_<key>.ogg)
ns.TYPE_SOUNDS = { "own", "own2", "metal", "real", "mech", "soft", "creamy", "thocky", "clacky", "poppy", "clicky", "lego", "blue" }
ns.KIND = {}
for _, k in ipairs(ns.TYPE_SOUNDS) do ns.KIND[k] = true end
local function Play(name, force)
	if ns.S and (ns.S.typeSounds or force) and PlaySoundFile then
		local kind = (ns.KIND[ns.S.typeSound] and ns.S.typeSound or "own") .. "_"
		-- volume: 1 quiet, 2 medium, 3 normal, 4 loud (each sound exists in all four)
		local v = tonumber(ns.S.typeVolume) or 3
		local suffix = (v == 3) and "" or ("_v" .. math.max(1, math.min(4, v)))
		PlaySoundFile(SOUND .. kind .. name .. suffix .. ".ogg", "SFX")
	end
end
ns.PlayTypeSound = Play

local function ArrowsMoveCursor(box)
	if box.SetAltArrowKeyMode and box.GetAltArrowKeyMode and box:GetAltArrowKeyMode() then
		box:SetAltArrowKeyMode(false)
	end
end

function ns.HookTyping(box)
	if not box or rawget(box, "ChatPilotTyping") or not box.HookScript then return end
	box.ChatPilotTyping = true

	ArrowsMoveCursor(box)
	box:HookScript("OnShow", ArrowsMoveCursor)
	box:HookScript("OnEditFocusGained", ArrowsMoveCursor)

	box:HookScript("OnChar", function(_, ch)
		if ch == " " then
			Play("space")
		else
			keyN = keyN % 4 + 1 -- four slightly different keys, so it never sounds like a machine
			Play("key" .. keyN)
		end
	end)
	box:HookScript("OnKeyDown", function(self, key)
		local text = self.GetText and self:GetText() or ""
		if type(text) ~= "string" or ns.IsSecret(text) then return end
		if key == "BACKSPACE" or key == "DELETE" then
			if text ~= "" then Play("back") end
		elseif key == "ENTER" or key == "NUMPADENTER" then
			if text ~= "" then Play("send") end
		end
	end)
end
