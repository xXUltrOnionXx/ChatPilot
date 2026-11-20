-- Run from the repository root: lua tests/chat_look.lua
-- Exercises the real discovery, skin, message wrapper and lazy-install lifecycle.
local function frame(name)
    local f = { name = name, lines = {}, shown = true, scripts = {}, alpha = 1 }
    function f:GetName() return self.name end
    function f:AddMessage(text) self.lines[#self.lines + 1] = text end
    function f:Clear() self.lines = {} end
    function f:RefreshDisplay() end
    function f:HookScript(e, fn) self.scripts[e] = fn end
    function f:SetScript(e, fn) self.scripts[e] = fn end
    function f:RegisterEvent() end
    function f:SetPoint() end
    function f:SetWidth() end
    function f:SetHeight() end
    function f:SetDrawLayer() end
    function f:SetAlpha(v) self.alpha = v end
    function f:GetAlpha() return self.alpha end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetTexture(v) self.texture = v end
    function f:GetTexture() return self.texture end
    function f:CreateTexture() return frame() end
    return f
end
local function setup(enabled, conflict)
    local filters, hooks = {}, 0
    CreateFrame = function() return frame() end
    GetTime = function() return 123 end
    time = function() return 123 end
    date = os.date
    hooksecurefunc = function(object, method, callback)
        hooks = hooks + 1
        local orig = object[method]
        object[method] = function(self, ...) orig(self, ...); callback(self, ...) end
    end
    ChatFrame_AddMessageEventFilter = function(event, fn)
        filters[event] = filters[event] or {}
        table.insert(filters[event], fn)
    end
    issecretvalue = function(v) return v == "SECRET" end
    CHAT_FRAMES, NUM_CHAT_WINDOWS = {"ChatFrame1"}, 1
    ChatFrame1, ChatFrame2 = frame("ChatFrame1"), nil
    DEFAULT_CHAT_FRAME = ChatFrame1
    ChatFrame1Background = frame()
    ChatFrame1Background.texture = "Blizzard background"
    local ns = { S = { chatSkin = enabled, chatStyle = true },
        L = { CHATSKIN_CONFLICT = "Conflicting addon: %s", WH_YOU = "You", CAT_say = "Say" },
        UI = { C = {}, ApplyTheme = function() end, Paint = function() end,
            OnTheme = function() end, Hex = function() return "|cffaaaaaa" end,
            Glow = function() return frame() end } }
    for _, file in ipairs({"Util.lua", "Levels.lua", "ChatSkin.lua", "ChatLook.lua"}) do
        assert(loadfile(file))("ChatPilot", ns)
    end
    ns.ChatSkinConflict = function() return conflict end
    local original = ChatFrame1.AddMessage
    ns.ScanChatFrames() -- actual Core.lua order: discover BEFORE OnLogin
    ns:OnLogin()
    return ns, filters, original, function() return hooks end
end
local tests = {}
local function test(name, fn) tests[#tests + 1] = {name, fn} end
test("enabled login skins and wraps already-discovered frames", function()
    local ns, filters, original = setup(true)
    assert(ChatFrame1.ChatPilotSkin, "missing frame skin")
    assert(ChatFrame1Background.texture == nil)
    assert(ChatFrame1.AddMessage ~= original, "login skipped message wrapper")
    assert(ChatFrame1.cpDeco, "login skipped message decoration")
    assert(#filters.CHAT_MSG_SAY == 1)
    ChatFrame1:AddMessage("|Hchannel:CHANNEL:2|h[2. Trade - City]|h hello")
    assert(ChatFrame1.lines[1] == "|Hchannel:CHANNEL:2|h[Trade]|h hello")
end)
test("normal login leaves Blizzard messages and textures alone", function()
    local ns, filters, original, hooks = setup(false)
    assert(ChatFrame1.AddMessage == original and not ChatFrame1.cpDeco)
    assert(ChatFrame1Background.texture == "Blizzard background")
    assert(next(filters) == nil and hooks() == 0)
    ns:InstallMainChatHooks()
    assert(not ns.mainHooks, "disabled look must not install hooks")
end)
test("enable after login without reload", function()
    local ns, filters, original = setup(false)
    ns.S.chatSkin = true
    ns:SkinAllChats()
    ns:InstallMainChatHooks()
    ns:RefreshMainChat()
    assert(ChatFrame1.ChatPilotSkin and ChatFrame1.cpDeco)
    assert(ChatFrame1.AddMessage ~= original and #filters.CHAT_MSG_SAY == 1)
end)
test("disable restores messages and background, reenable does not stack hooks", function()
    local ns, filters, _, hooks = setup(true)
    local originalText = "|Hchannel:CHANNEL:2|h[2. Trade - City]|h hello"
    ChatFrame1:AddMessage(originalText)
    local wrapped, hookCount = ChatFrame1.AddMessage, hooks()
    ns.S.chatSkin = false
    ns:UnskinAllChats()
    ns:RefreshMainChat()
    assert(ChatFrame1.lines[1] == originalText)
    assert(ChatFrame1Background.texture == "Blizzard background")
    ns.S.chatSkin = true
    ns:SkinAllChats()
    ns:InstallMainChatHooks()
    ns:RefreshMainChat()
    assert(ChatFrame1.AddMessage == wrapped and hooks() == hookCount)
    assert(#filters.CHAT_MSG_SAY == 1 and ChatFrame1Background.texture == nil)
    assert(ChatFrame1.lines[1] == "|Hchannel:CHANNEL:2|h[Trade]|h hello")
end)
test("new temporary chat gets skin and message hooks once", function()
    local ns = setup(true)
    ChatFrame2 = frame("ChatFrame2")
    CHAT_FRAMES[2] = "ChatFrame2"
    ns.ScanChatFrames()
    assert(ChatFrame2.ChatPilotSkin and ChatFrame2.cpDeco and ChatFrame2.ChatPilotLevels)
    local wrapped = ChatFrame2.AddMessage
    ns.ScanChatFrames()
    assert(ChatFrame2.AddMessage == wrapped)
end)
test("conflicting skin blocks installation", function()
    local ns, filters, original = setup(true, "Other chat addon")
    ns:InstallMainChatHooks()
    assert(not ns.mainHooks and ChatFrame1.AddMessage == original)
    assert(next(filters) == nil and not ChatFrame1.ChatPilotSkin)
end)
test("protected message passes through unchanged", function()
    setup(true)
    ChatFrame1:AddMessage("SECRET")
    assert(ChatFrame1.lines[1] == "SECRET")
end)
test("chat beautification formats real messages and toggles immediately", function()
    local ns, filters = setup(true)
    assert(loadfile("ChatWindows.lua"))("ChatPilot", ns) -- real shared formatters
    local originalText = "|Hplayer:Alice|h[Alice]|h: hello"
    filters.CHAT_MSG_SAY[1](ChatFrame1, "CHAT_MSG_SAY", "hello", "Alice")
    ChatFrame1:AddMessage(originalText, 1, 1, 1)
    assert(#ChatFrame1.lines == 2, "expected separate header and message")
    assert(ChatFrame1.lines[1]:find("|hAlice|h", 1, true))
    assert(ChatFrame1.lines[2] == "|r|rhello")
    ns.S.chatStyle = false
    ns:RefreshMainChat()
    assert(#ChatFrame1.lines == 1 and ChatFrame1.lines[1] == originalText)
    ns.S.chatStyle = true
    ns:RefreshMainChat()
    assert(#ChatFrame1.lines == 2 and ChatFrame1.lines[2] == "|r|rhello")
end)
test("design changes retain the latest 400 history lines", function()
    local ns = setup(true)
    for i = 1, 450 do ChatFrame1:AddMessage("message " .. i) end
    ns:RefreshMainChat()
    assert(#ChatFrame1.lines == 400)
    assert(ChatFrame1.lines[1] == "message 51" and ChatFrame1.lines[400] == "message 450")
end)
local failures = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    print((ok and "PASS " or "FAIL ") .. entry[1] .. (ok and "" or (": " .. tostring(err))))
    if not ok then failures = failures + 1 end
end
assert(failures == 0, failures .. " chat-look tests failed")
print(#tests .. " chat-look tests passed")
