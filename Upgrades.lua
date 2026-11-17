-- Pawn's verdicts on EasyFind's boss loot: the drops Pawn rates above what
-- this character wears, each with its boss and instance, a click going
-- where EasyFind's own loot row goes. Pawn is only read: its functions are
-- called at runtime, its scales and settings never written or copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
local KEY = "pawn"
-- EasyFind's own loot glyph, so the rows read as one feature.
local ICON = "Interface\\AddOns\\EasyFind\\textures\\art\\loot"
local ICON_COORDS = { 0, 0.75, 0, 0.67188 }
local RATE_BUDGET_MS = 4     -- rating time per frame
local REFRESH_DELAY = 1      -- seconds after a gear or scale change
local FIRST_LOAD_DELAY = 10  -- seconds after entering the world
local BIG_UPGRADE = 100      -- Pawn's "no number" percent (an empty slot)

local C_Item = C_Item
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
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

local function DB()
    EasyFindPawnDB = EasyFindPawnDB or {}
    return EasyFindPawnDB
end

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
    return API.HasAction("loot", "ensure") and API.HasAction("loot", "entries")
        and API.HasAction("loot", "link") and API.HasAction("loot", "open")
end

-- Pawn's upgrade list, sorted by scale name; the row shows the biggest.
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

-- ==== rows ==================================================================

local function Percent(pct)
    return floor(pct * 100 + 0.5)
end

local function Subtext(e, v)
    if v.pct >= BIG_UPGRADE then
        return sformat(L["SUBTEXT_BIG_FMT"], v.scaleName, e.bossName or "", e.instanceName or "")
    end
    return sformat(L["SUBTEXT_FMT"], Percent(v.pct), v.scaleName, e.bossName or "", e.instanceName or "")
end

local function Wanted(e, db)
    if e.isRaid then return db.raids ~= false end
    return db.dungeons ~= false
end

-- Outside @upgrades only these words find a row: EasyFind's own loot row,
-- which the decorator below marks, is the one a name or a boss finds.
local function Rows()
    if not S.ready then return {} end
    local db = DB()
    local scoped = (API.MINOR or 0) >= 7 or nil
    local out = {}
    for itemID, v in pairs(S.verdict) do
        local e = v and S.byItem[itemID]
        if e and Wanted(e, db) then
            out[#out + 1] = { name = e.name, icon = e.icon, itemID = itemID, pct = v.pct,
                              searchCommandDesc = Subtext(e, v), scopedName = scoped,
                              keywords = { "upgrade", "upgrades", v.scaleName } }
        end
    end
    -- The biggest upgrade leads; ties by name.
    table.sort(out, function(a, b)
        if a.pct ~= b.pct then return a.pct > b.pct end
        return a.name < b.name
    end)
    return out
end

local publishPending = false
function Publish()
    if publishPending then return end
    publishPending = true
    C_Timer.After(0.2, function()
        publishPending = false
        local n = 0
        for itemID, v in pairs(S.verdict) do
            if v and S.byItem[itemID] and Wanted(S.byItem[itemID], DB()) then n = n + 1 end
        end
        API.SetBadge(KEY, n)
        API.RefreshSearchProvider(KEY)
        if API.RefreshRowDecorations then API.RefreshRowDecorations() end
    end)
end

local function HasJournal()
    return type(EJ_GetNumTiers) == "function" and (EJ_GetNumTiers() or 0) > 0
end

local function Hint()
    if not S.ready then return nil end
    return { click = HasJournal() and L["HINT_JOURNAL"] or L["HINT_DIRECTIONS"],
             ctrl = L["HINT_DRESS"], shift = L["HINT_LINK"] }
end

local function Link(row)
    local v = S.verdict[row.itemID]
    return v and v.link or nil
end

-- Shift links the item in chat, Ctrl tries it on; a plain click goes
-- where EasyFind's own loot row goes.
local function Select(row)
    if not S.ready then return end
    local link = Link(row)
    if IsShiftKeyDown() and link then return ChatEdit_InsertLink(link) end
    if IsControlKeyDown() and link then return DressUpItemLink(link) end
    API.CallAction("loot", "open", row.itemID)
end

local function Tooltip(row, tt)
    local v = S.ready and S.verdict[row.itemID]
    local e = v and S.byItem[row.itemID]
    if not e then return false end
    tt:SetHyperlink(v.link)
    tt:AddLine(" ")
    tt:AddLine(sformat(L["FROM_FMT"], e.bossName or "", e.instanceName or ""), 1, 1, 1)
    if v.existing then tt:AddLine(sformat(L["REPLACES_FMT"], v.existing), 1, 1, 1) end
    for i = 1, #v.others do
        local o = v.others[i]
        if (o.PercentUpgrade or 0) < BIG_UPGRADE then
            tt:AddLine(sformat(L["ALSO_FMT"], Percent(o.PercentUpgrade or 0), o.LocalizedScaleName or o.ScaleName or ""), 0.8, 0.8, 0.8)
        end
    end
    return true
end

local function Menu(row)
    local link = S.ready and Link(row)
    if not link then return nil end
    local rows = {}
    if type(PawnUI_SetCompareItemAndShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_COMPARE"], onClick = function() PawnUI_SetCompareItemAndShow(2, link) end }
    end
    if type(PawnUIShow) == "function" then
        rows[#rows + 1] = { kind = "action", label = L["MENU_PAWN"], onClick = PawnUIShow }
    end
    return rows
end

-- ==== registration ==========================================================

local function Option(key, label, tip)
    return {
        label = label, tooltip = tip,
        get = function() return DB()[key] ~= false end,
        set = function(on)
            if on then DB()[key] = nil else DB()[key] = false end
            Publish()
        end,
    }
end

local function FilterOptions()
    return { Option("dungeons", L["OPT_DUNGEONS"], L["OPT_DUNGEONS_TIP"]),
             Option("raids", L["OPT_RAIDS"], L["OPT_RAIDS_TIP"]) }
end

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    iconCoords = ICON_COORDS,
    keywords = { "upgrade", "upgrades", "pawn", "gear" },
    scope = KEY,
    settings = function(page, kit)
        local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
        local opts = FilterOptions()
        for i = 1, #opts do
            local box = kit.Checkbox(page, opts[i].label, opts[i].get, opts[i].set, opts[i].tooltip)
            box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, i == 1 and -8 or -4)
            below = box
        end
    end,
})

API.RegisterSearchProvider({
    key = KEY,
    label = L["PROVIDER_LABEL"],
    category = L["CATEGORY"],
    extension = KEY,
    words = { "upgrade", "upgrades", "pawn" },
    aliases = { "upgrades", "upgrade", "pawn" },
    lazy = true,
    options = FilterOptions(),
    rows = Rows,
    select = Select,
    tooltip = Tooltip,
    hint = Hint,
    menu = Menu,
})

-- EasyFind's own rows for a rated drop (its loot row, the item in a bag)
-- carry the verdict: the subtext's percent and scale, Pawn's menu entries.
local function Mark(row)
    local v = S.verdict[row.itemID]
    if v.pct >= BIG_UPGRADE then return sformat(L["MARK_BIG_FMT"], v.scaleName) end
    return sformat(L["MARK_FMT"], Percent(v.pct), v.scaleName)
end

local function Rated()
    local ids = {}
    for itemID, v in pairs(S.verdict) do
        if v then ids[itemID] = true end
    end
    return { itemID = ids }
end

if API.RegisterRowDecorator then
    API.RegisterRowDecorator({
        id = KEY .. "-mark", extension = KEY, label = L["EXT_NAME"],
        candidates = Rated,
        -- Never the extension's own rows (they carry pct).
        applies = function(row)
            if not S.ready or row.pct ~= nil or not S.verdict[row.itemID] then return false end
            local e = S.byItem[row.itemID]
            return e ~= nil and Wanted(e, DB())
        end,
        subtext = Mark,
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
        API.On("loot", "changed", Reload)
        -- The loot list loads after the login settles, not during it.
        C_Timer.After(FIRST_LOAD_DELAY, function() API.CallAction("loot", "ensure", Reload) end)
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    Refresh()
end)
