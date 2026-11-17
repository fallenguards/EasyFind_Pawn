-- The extension loaded offline: its toc's files run in a stand-in game
-- against a recording EasyFind.API and a stand-in Pawn.
--   local Harness = require("Harness")
--   local ctx = Harness.Load({ pawn = false })
local Harness = {}

local source = debug.getinfo(1, "S").source:sub(2)
local ROOT = source:gsub("[/\\]?tests[/\\]Harness%.lua$", "")
if ROOT == "" then ROOT = "." end
Harness.ROOT = ROOT
Harness.TOC = "EasyFind_Pawn.toc"

function Harness.Read(path)
    local f = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = f:read("a")
    f:close()
    return text
end

function Harness.Eq(got, want, label)
    if got ~= want then
        error(string.format("%s: got %s, wanted %s", label or "value", tostring(got), tostring(want)), 2)
    end
end

function Harness.True(ok, label)
    if not ok then error((label or "check") .. " failed", 2) end
end

-- The toc's fields and the Lua files it lists, in order.
function Harness.Toc()
    local text = Harness.Read(Harness.TOC)
    local fields, files = {}, {}
    for line in text:gmatch("[^\r\n]+") do
        local key, value = line:match("^## ([%w%-]+):%s*(.-)%s*$")
        if key then
            fields[key] = value
        elseif not line:match("^#") and line:match("%.lua") then
            files[#files + 1] = line:match("^(%S+)"):gsub("\\", "/")
        end
    end
    return fields, files
end

-- Items of the stand-in game: an equip slot makes one gear.
Harness.ITEMS = {
    [1001] = { equipLoc = "INVTYPE_CHEST", link = "|Hitem:1001|h[Robe]|h" },
    [1002] = { equipLoc = "", link = "|Hitem:1002|h[Linen Cloth]|h" },
    [1003] = { equipLoc = "INVTYPE_HEAD", link = "|Hitem:1003|h[Hood]|h" },
}

-- opts.pawn = false: Pawn not loaded. Returns ctx with what the files
-- registered (extension, decorator, judge), the frames they made, and
-- ctx.Fire(event) / ctx.Frame() to drive them.
function Harness.Load(opts)
    opts = opts or {}
    local ctx = { frames = {}, printed = {}, timers = {}, refreshed = 0 }
    local api = {
        VERSION = 1,
        RegisterExtension = function(def) ctx.extension = def end,
        RegisterRowDecorator = function(def) ctx.decorator = def end,
        RegisterUpgradeJudge = function(def) ctx.judge = def end,
        HasAction = function() return true end,
        CallAction = function() return nil end,
        On = function() end,
        RefreshUpgrades = function() end,
        RefreshRowDecorations = function() ctx.refreshed = ctx.refreshed + 1 end,
    }
    local function Frame()
        local f = { events = {}, shown = true, scripts = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown end
        ctx.frames[#ctx.frames + 1] = f
        return f
    end
    local env = setmetatable({
        EasyFind = { API = api },
        C_AddOns = { IsAddOnLoaded = function(name) return name == "Pawn" and opts.pawn ~= false end },
        C_Item = {
            GetItemInfoInstant = function(id)
                local item = Harness.ITEMS[id]
                return id, nil, nil, item and item.equipLoc or nil
            end,
            GetItemInfo = function(id) local item = Harness.ITEMS[id] return item and "name", item and item.link end,
            IsItemDataCachedByID = function() return true end,
            RequestLoadItemDataByID = function() end,
        },
        C_Timer = { After = function(_, fn) ctx.timers[#ctx.timers + 1] = fn end },
        CreateFrame = function() return Frame() end,
        GetInventoryItemID = function() return nil end,
        hooksecurefunc = function() end,
        debugprofilestop = function() return 0 end,
        print = function(...) ctx.printed[#ctx.printed + 1] = table.concat({ ... }, " ") end,
        PawnIsReady = function() return true end,
        PawnGetItemData = function(link) return { link = link } end,
        -- Pawn rates the robe an upgrade, the hood not.
        PawnIsItemAnUpgrade = function(item)
            if item.link:find("Robe", 1, true) then
                return { { PercentUpgrade = 0.12, LocalizedScaleName = "Frost" } }
            end
        end,
    }, { __index = _G })
    env._G = env
    local _, files = Harness.Toc()
    local ns = {}
    for _, file in ipairs(files) do
        local chunk = assert(load(Harness.Read(file), "=" .. file, "t", env))
        chunk("EasyFind_Pawn", ns)
    end
    -- The login, then the rating frame's updates until it rests, then the timers.
    function ctx.Fire(event, ...)
        for _, f in ipairs(ctx.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function ctx.Settle()
        for _ = 1, 10 do
            for _, f in ipairs(ctx.frames) do
                if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.01) end
            end
            local timers = ctx.timers
            ctx.timers = {}
            for _, fn in ipairs(timers) do fn() end
        end
    end
    return ctx
end

return Harness
