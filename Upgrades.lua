-- Pawn's verdicts on EasyFind's rows: a drop EasyFind lists (its loot
-- rows, @upgrades, a bag item) says how much better Pawn rates it and for
-- which scale, with Pawn's compare on its menu; @upgrades is judged by
-- Pawn. Pawn is only read: its functions are called at runtime, its
-- scales and settings never written or copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
local KEY = "pawn"
-- EasyFind's own loot glyph, so the marks read as one feature.
local ICON = "Interface\\AddOns\\EasyFind\\textures\\art\\loot"
local ICON_COORDS = { 0, 0.75, 0, 0.67188 }
local RATE_BUDGET_MS = 4     -- rating time per frame
local REFRESH_DELAY = 1      -- seconds after a gear or scale change
local FIRST_LOAD_DELAY = 10  -- seconds after entering the world
local BIG_UPGRADE = 100      -- Pawn's "no number" percent (an empty slot)

local C_Item = C_Item
local sformat, floor, debugprofilestop = string.format, math.floor, debugprofilestop

-- Module state in one table (upvalue limit).
local S = {
    ready = false,
    byItem = {},    -- itemID -> loot entry from EasyFind
    verdict = {},   -- itemID -> upgrade table, false when rated no upgrade
    queue = {}, head = 1,
    pending = {},   -- itemID -> true, item data requested from the server
    waitGear = false,
    inPawn = false, -- inside a Pawn call: its hooks are not our signal
}

local function Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

-- ==== Pawn ==================================================================

-- The functions of Pawn's own API section that the rating needs.
local function BindPawn()
    local need = { "PawnIsReady", "PawnGetItemData", "PawnIsItemAnUpgrade" }
    for i = 1, #need do
        if type(_G[need[i]]) ~= "function" then return false end
    end
    return true
end

local function BindLoot()
    return API.HasAction("loot", "ensure") and API.HasAction("loot", "entries") and API.HasAction("loot", "link")
end

-- Pawn's upgrade list, sorted by scale name; the mark shows the biggest.
local function Verdict(info, link)
    if type(info) ~= "table" or not info[1] then return false end
    local best = info[1]
    for i = 2, #info do
        if (info[i].PercentUpgrade or 0) > (best.PercentUpgrade or 0) then best = info[i] end
    end
    local others = {}
    for i = 1, #info do
        if info[i] ~= best then others[#others + 1] = info[i] end
    end
    return { pct = best.PercentUpgrade or 0, scaleName = best.LocalizedScaleName or best.ScaleName,
             existing = best.ExistingItemLink, others = others, link = link }
end

local function AskPawn(link)
    S.inPawn = true
    local item = PawnGetItemData(link)
    local info = item and PawnIsItemAnUpgrade(item)
    S.inPawn = false
    return info
end

-- ==== rating ================================================================

local loader = CreateFrame("Frame")
local rater = CreateFrame("Frame")
rater:Hide()
local Publish, Begin

local function Cached(itemID)
    return not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(itemID)
end

local function RequestItem(itemID)
    S.pending[itemID] = true
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    loader:RegisterEvent("ITEM_DATA_LOAD_RESULT")
end

-- Pawn compares against the worn gear, so that must be known first.
local function GearCached()
    local ok = true
    for slot = 1, 17 do
        local id = GetInventoryItemID("player", slot)
        if id and not Cached(id) then
            RequestItem(id)
            ok = false
        end
    end
    return ok
end

local function Rate(itemID)
    local link = API.CallAction("loot", "link", itemID)
    if not link then
        S.verdict[itemID] = false
        return
    end
    if not Cached(itemID) then return RequestItem(itemID) end
    S.verdict[itemID] = Verdict(AskPawn(link), link)
end

rater:SetScript("OnUpdate", function(self)
    local stop = debugprofilestop() + RATE_BUDGET_MS
    while S.head <= #S.queue do
        Rate(S.queue[S.head])
        S.head = S.head + 1
        if debugprofilestop() > stop then return end
    end
    self:Hide()
    S.queue, S.head = {}, 1
    Publish()
end)

local function Enqueue(itemID)
    S.queue[#S.queue + 1] = itemID
    rater:Show()
end

-- Items the server sent: rated now; worn gear complete: the run starts.
loader:SetScript("OnEvent", function(self, _, itemID, ok)
    if not S.pending[itemID] then return end
    S.pending[itemID] = nil
    if next(S.pending) == nil then self:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end
    if S.waitGear then
        if next(S.pending) == nil then Begin() end
        return
    end
    if ok and S.byItem[itemID] then Enqueue(itemID) else S.verdict[itemID] = false end
end)

-- Rates every known drop again; verdicts stay until replaced.
function Begin()
    if not (S.ready and PawnIsReady()) then return end
    if not GearCached() then
        S.waitGear = true
        return
    end
    S.waitGear = false
    S.queue, S.head = {}, 1
    for itemID in pairs(S.byItem) do S.queue[#S.queue + 1] = itemID end
    if #S.queue > 0 then rater:Show() end
end

-- EasyFind's loot changed: new entry list, rated from scratch.
local function Reload()
    if not S.ready then return end
    local list = API.CallAction("loot", "entries")
    if type(list) ~= "table" then return end
    S.byItem = {}
    for i = 1, #list do
        local e = list[i]
        if e.itemID then S.byItem[e.itemID] = e end
    end
    for itemID in pairs(S.verdict) do
        if not S.byItem[itemID] then S.verdict[itemID] = nil end
    end
    Begin()
end

local refreshPending = false
local function Refresh()
    if refreshPending or not S.ready or S.inPawn then return end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, function()
        refreshPending = false
        Begin()
    end)
end

-- ==== EasyFind's rows =======================================================

local function Percent(pct)
    return floor(pct * 100 + 0.5)
end

local publishPending = false
function Publish()
    if publishPending then return end
    publishPending = true
    C_Timer.After(0.2, function()
        publishPending = false
        if API.RefreshUpgrades then API.RefreshUpgrades() end
        if API.RefreshRowDecorations then API.RefreshRowDecorations() end
    end)
end

-- After the row's subtext: the percent and the scale; on @upgrades, whose
-- rows show the percent already, the scale alone.
local function Mark(row)
    local v = S.verdict[row.itemID]
    if v.pct >= BIG_UPGRADE then return sformat(L["MARK_BIG_FMT"], v.scaleName) end
    if row.upgradeSlot then return v.scaleName end
    return sformat(L["MARK_FMT"], Percent(v.pct), v.scaleName)
end

-- Under the row's tooltip: what the drop replaces, the other scales it helps.
local function Lines(row, _, tt)
    local v = S.verdict[row.itemID]
    if v.existing then tt:AddLine(sformat(L["REPLACES_FMT"], v.existing), 1, 1, 1) end
    for i = 1, #v.others do
        local o = v.others[i]
        if (o.PercentUpgrade or 0) < BIG_UPGRADE then
            tt:AddLine(sformat(L["ALSO_FMT"], Percent(o.PercentUpgrade or 0), o.LocalizedScaleName or o.ScaleName or ""),
                0.8, 0.8, 0.8)
        end
    end
end

local function Menu(row)
    local v = S.verdict[row.itemID]
    local link = v and v.link
    if not link then return nil end
    local rows = {}
    if type(PawnUI_SetCompareItemAndShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_COMPARE"],
                            onClick = function() PawnUI_SetCompareItemAndShow(2, link) end }
    end
    if type(PawnUIShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_PAWN"], onClick = PawnUIShow }
    end
    return rows
end

local function Rated()
    local ids = {}
    for itemID, v in pairs(S.verdict) do
        if v then ids[itemID] = true end
    end
    return { itemID = ids }
end

-- Pawn's word for @upgrades: the percent, true with no number, false for
-- no upgrade, nil while unrated (EasyFind's own comparison stands).
local function Judge(itemID)
    local v = S.verdict[itemID]
    if v == nil then return nil end
    if v == false then return false end
    if v.pct >= BIG_UPGRADE then return true end
    return Percent(v.pct)
end

-- ==== registration ==========================================================

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    iconCoords = ICON_COORDS,
})

if API.RegisterRowDecorator then
    API.RegisterRowDecorator({
        id = KEY, label = L["EXT_NAME"],
        candidates = Rated,
        applies = function(row) return S.ready and S.verdict[row.itemID] and true or false end,
        subtext = Mark,
        tooltip = Lines,
        menu = Menu,
    })
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if not BindPawn() then return Print(L["NOT_READY"]) end
        if not BindLoot() then return Print(L["NEED_EASYFIND"]) end
        S.ready = true
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        -- Pawn has no change event: a scale edited, shown or hidden ends in
        -- one of these two calls, as does its own spec switch.
        hooksecurefunc("PawnInvalidateBestItems", Refresh)
        hooksecurefunc("PawnResetTooltips", Refresh)
        if API.RegisterUpgradeJudge then API.RegisterUpgradeJudge({ extension = KEY, rate = Judge }) end
        API.On("loot", "changed", Reload)
        -- The loot list loads after the login settles, not during it.
        C_Timer.After(FIRST_LOAD_DELAY, function() API.CallAction("loot", "ensure", Reload) end)
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    Refresh()
end)
