-- Run from repository root: lua tests/history.lua
local function setup(keep)
    local frames, callbacks, timers = {}, {}, {}
    local function frame(capacity)
        local f = { lines = {}, capacity = capacity or 128, scripts = {} }
        function f:GetMaxLines() return self.capacity end
        function f:SetMaxLines(n) self.capacity = n end
        function f:GetNumMessages() return #self.lines end
        function f:GetMessageInfo(i) return self.lines[i], 1, 1, 1 end
        function f:AddMessage(text)
            table.insert(self.lines, text)
            while #self.lines > self.capacity do table.remove(self.lines, 1) end
        end
        function f:RegisterEvent() end
        function f:SetScript(e, fn) self.scripts[e] = fn end
        return f
    end
    CreateFrame = function() local f = frame(); frames[#frames+1] = f; return f end
    time = function() return 1000000 end
    date = os.date
    C_Timer = { After = function(_, fn) timers[#timers+1] = fn end }
    NUM_CHAT_WINDOWS = 3
    ChatFrame1, ChatFrame2, ChatFrame3 = frame(), frame(300), frame(500)
    local ns = { S = { keepHistory = keep, chatSkin = false }, playerKey = 'player',
        db = { history = {} }, L = { HISTORY_RESTORED = 'Restored %s' },
        IsSecret = function(v) return v == 'SECRET' end,
        OnChatFrame = function(fn) callbacks[#callbacks+1] = fn end }
    assert(loadfile('History.lua'))('ChatPilot', ns)
    for _, fn in ipairs(callbacks) do
        for _, f in ipairs({ChatFrame1, ChatFrame2, ChatFrame3}) do fn(f) end
    end
    return ns, frames[1].scripts.OnEvent, callbacks[1], timers, frame
end
local tests = {}
local function test(name, fn) tests[#tests+1] = {name, fn} end
test('live capacities double for all Blizzard frames even with persistence disabled', function()
    setup(false)
    assert(ChatFrame1.capacity == 256 and ChatFrame2.capacity == 600 and ChatFrame3.capacity == 1000)
    for i = 1, 300 do ChatFrame1:AddMessage(tostring(i)) end
    assert(#ChatFrame1.lines == 256 and ChatFrame1.lines[1] == '45')
end)
test('revisiting frames cannot repeatedly multiply capacity', function()
    local _, event, callback = setup(true)
    callback(ChatFrame1); event(nil, 'PLAYER_LOGIN'); callback(ChatFrame1)
    assert(ChatFrame1.capacity == 256)
end)
test('new temporary windows receive double capacity', function()
    local _, _, callback, _, frame = setup(true)
    local temporary = frame(150)
    callback(temporary)
    assert(temporary.capacity == 300)
end)
test('logout saves latest 240 lines per regular tab, excluding combat log', function()
    local ns, event = setup(true)
    for i = 1, 300 do
        ChatFrame1:AddMessage('a' .. i); ChatFrame2:AddMessage('b' .. i); ChatFrame3:AddMessage('c' .. i)
    end
    event(nil, 'PLAYER_LOGOUT')
    local saved = ns.db.history.player.frames
    assert(#saved[1] == 240 and saved[1][1][1] == 'a61' and saved[1][240][1] == 'a300')
    assert(#saved[3] == 240 and not saved[2])
end)
test('saved history restores without losing its earliest retained message', function()
    local ns, event, _, timers = setup(true)
    for i = 1, 250 do ChatFrame1:AddMessage(tostring(i)) end
    event(nil, 'PLAYER_LOGOUT')
    ChatFrame1.lines = {}
    event(nil, 'PLAYER_LOGIN'); timers[1]()
    assert(#ChatFrame1.lines == 241 and ChatFrame1.lines[1] == '11' and ChatFrame1.lines[240] == '250')
end)
test('disabled persistence does not save messages', function()
    local ns, event = setup(false)
    ChatFrame1:AddMessage('hello'); event(nil, 'PLAYER_LOGOUT')
    assert(next(ns.db.history) == nil)
end)
test('protected messages are still excluded from saved history', function()
    local ns, event = setup(true)
    ChatFrame1:AddMessage('hello'); ChatFrame1:AddMessage('SECRET')
    event(nil, 'PLAYER_LOGOUT')
    assert(#ns.db.history.player.frames[1] == 1)
end)
local failed = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    print((ok and 'PASS ' or 'FAIL ') .. entry[1] .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failed = failed + 1 end
end
assert(failed == 0, failed .. ' history tests failed')
print(#tests .. ' history tests passed')
