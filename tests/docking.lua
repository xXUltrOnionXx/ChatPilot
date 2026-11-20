-- Run from the repository root: lua tests/docking.lua
-- Loads the real module; only WoW frames and unrelated rendering are mocked.
local function up(fn, key, value, replace)
    for i = 1, 100 do
        local name, current = debug.getupvalue(fn, i)
        if not name then break end
        if name == key then
            if replace then debug.setupvalue(fn, i, value) end
            return current
        end
    end
    error("Missing upvalue: " .. key)
end

local function frame(left, bottom, width, height, scale)
    local f = { left = left or 0, bottom = bottom or 0, width = width or 400,
        height = height or 180, scale = scale or 1, shown = true, scripts = {}, points = {} }
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetShown(v) self.shown = not not v end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.left + self.width end
    function f:GetBottom() return self.bottom end
    function f:GetTop() return self.bottom + self.height end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return self.scale end
    function f:GetName() return "TestChat" end
    function f:GetFrameStrata() return "LOW" end
    function f:GetFrameLevel() return 1 end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:ClearAllPoints() self.points = {} end
    function f:SetAllPoints(p) self.allPoints = p end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetHeight(h) self.height = h end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:RegisterEvent() end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:SetToplevel() end
    function f:Raise() end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    return f
end

local function setup()
    local s = { x = 200, y = 200, down = true }
    UIParent = frame(0, 0, 1920, 1080)
    ChatFrame1 = frame(100, 100, 400, 180)
    DEFAULT_CHAT_FRAME = ChatFrame1
    GENERAL_CHAT_DOCK = {}
    FCFDock_GetSelectedWindow = function() return s.selected end
    CreateFrame = function() return frame() end
    GetCursorPosition = function() return s.x, s.y end
    IsMouseButtonDown = function() return s.down end
    MouseIsOver = function(f, top, bottom, left, right)
        local z = f:GetEffectiveScale()
        return s.x >= (f:GetLeft() + (left or 0)) * z
            and s.x <= (f:GetRight() + (right or 0)) * z
            and s.y >= (f:GetBottom() + (bottom or 0)) * z
            and s.y <= (f:GetTop() + (top or 0)) * z
    end
    local ns = { L = {}, UI = { C = {}, OnTheme = function() end },
        OnChatFrame = function() end, Print = function() end }
    assert(loadfile("ChatWindows.lua"))("ChatPilot", ns)
    local cw = ns._cw
    local data = { groups = {}, windows = {} }
    up(cw.StartDrag, "Data", data, true)
    up(cw.FinishDrag, "LayoutTabs", function() end, true)
    up(cw.FinishDrag, "Select", function(g, w) g.data.active = w.data.id end, true)
    up(cw.StartDrag, "UpdateLaunchers", function() end, true)
    ns.ShowMainDrop = function(_, on) s.highlight = on end
    local function group(id, left, bottom)
        local g = { data = { order = {id}, active = id, w = 400, h = 180 },
            frame = frame(left or 700, bottom or 500), header = frame(700, 650, 400, 24),
            body = frame(), dropHl = frame() }
        local w = { data = { id = id, title = "Window " .. id, cats = {} },
            msg = frame(), tab = frame(), group = g }
        cw.wins[id] = w
        table.insert(cw.groups, g)
        table.insert(data.groups, g.data)
        return g, w
    end
    s.ns, s.cw, s.data, s.group = ns, cw, data, group
    return s
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = {name, fn} end
test("main chat drop", function(s)
    local g = s.group(1)
    s.cw.FinishDrag(g)
    assert(g.data.main and g.mainOpen and g.frame.parent == ChatFrame1)
end)
test("selected dock tab while default chat is hidden", function(s)
    ChatFrame1:Hide()
    s.selected = frame(100, 100, 400, 180)
    local g = s.group(1)
    assert(s.ns:OverMainChat(), "visible selected tab must be a drop target")
    s.cw.FinishDrag(g)
    assert(g.data.main and g.frame.parent == s.selected)
end)
test("hidden chat is not a target", function(s)
    ChatFrame1:Hide()
    assert(not s.ns:OverMainChat())
end)
test("no dock API falls back to default chat", function(s)
    FCFDock_GetSelectedWindow = nil
    assert(s.ns:OverMainChat())
end)
test("pixel fallback handles a scaled chat and tab row", function(s)
    MouseIsOver = nil
    ChatFrame1.scale = 0.75
    s.x, s.y = 200 * 0.75, 300 * 0.75
    assert(s.ns:OverMainChat())
    s.y = 400
    assert(not s.ns:OverMainChat())
end)
test("own-window title bar docking", function(s)
    local g, w = s.group(1)
    local target = s.group(2)
    s.x, s.y = 800, 660
    s.cw.FinishDrag(g)
    assert(w.group == target and #target.data.order == 2 and g.data == nil)
    assert(w.msg.parent == target.body and w.tab.parent == target.header)
end)
test("own title bar wins over underlying main chat", function(s)
    local g, w = s.group(1)
    local target = s.group(2)
    target.header = frame(100, 190, 300, 24)
    s.cw.FinishDrag(g)
    assert(w.group == target, "underlying main chat swallowed title-bar drop")
end)
test("preview matches overlapping title-bar drop", function(s)
    local g = s.group(1)
    local target = s.group(2)
    target.header = frame(100, 190, 300, 24)
    s.cw.StartDrag(g)
    local drag = up(s.cw.FinishDrag, "dragFrame")
    drag.scripts.OnUpdate()
    assert(target.dropHl.shown and not s.highlight)
end)
test("hidden parent excludes own-window target", function(s)
    local g, w = s.group(1)
    local target = s.group(2)
    target.frame.parent = frame()
    target.frame.parent:Hide()
    s.x, s.y = 800, 660
    s.cw.FinishDrag(g)
    assert(w.group == g, "invisible window captured the drop")
end)
test("snap above main chat", function(s)
    local g = s.group(1, 100, 314)
    s.x, s.y = 600, 500
    s.cw.FinishDrag(g)
    assert(g.data.snap and not g.data.main)
end)
test("snap above selected tab with default hidden", function(s)
    ChatFrame1:Hide()
    s.selected = frame(100, 100, 400, 180)
    local g = s.group(1, 100, 314)
    s.x, s.y = 600, 500
    s.cw.FinishDrag(g)
    assert(g.data.snap and g.frame.points[1][2] == s.selected)
end)
test("free drop saves position", function(s)
    local g = s.group(1, 700, 500)
    s.x, s.y = 800, 800
    s.cw.FinishDrag(g)
    assert(not g.data.snap and not g.data.main and g.data.x == 700 and g.data.y == 680)
end)
test("undock from main chat and redock", function(s)
    local g, w = s.group(1)
    s.cw.FinishDrag(g)
    s.x, s.y = 800, 600
    s.cw.StartDrag(g, w)
    assert(not g.data.main and not g.mainOpen and g.frame.parent == UIParent and g.frame.moving)
    s.x, s.y = 200, 200
    s.down = false
    local drag = up(s.cw.FinishDrag, "dragFrame")
    drag.scripts.OnUpdate()
    assert(g.data.main and g.mainOpen and not g.frame.moving and not drag.shown)
end)
test("multi-tab group docks intact into main chat", function(s)
    local g = s.group(1)
    g.data.order[2] = 2
    s.cw.FinishDrag(g)
    assert(g.data.main and #g.data.order == 2)
end)

local failures = 0
for _, entry in ipairs(tests) do
    local ok, err = pcall(function() entry[2](setup()) end)
    print((ok and "PASS " or "FAIL ") .. entry[1] .. (ok and "" or (": " .. tostring(err))))
    if not ok then failures = failures + 1 end
end
assert(failures == 0, failures .. " docking tests failed")
print(#tests .. " docking tests passed")
