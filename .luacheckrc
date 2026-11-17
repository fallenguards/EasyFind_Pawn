std = "lua51"
max_line_length = false
-- The dev addon is untracked and never ships.
exclude_files = { "dev" }

-- Standard WoW addon patterns, not real issues.
ignore = {
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument
}

-- WoW API and the addons it reads (read-only)
read_globals = {
    "EasyFind",
    "C_AddOns", "C_Item", "C_Timer", "IsAddOnLoaded",
    "CreateFrame", "GetInventoryItemID", "GetSpecialization",
    "PawnIsReady", "PawnGetItemData", "PawnIsItemAnUpgrade", "PawnUI_SetCompareItemAndShow", "PawnUIShow",
    "debugprofilestop", "hooksecurefunc",
}

-- WoW callbacks have fixed signatures; unused args are normal
unused_args = false
self = false

-- The tests run on the lua in PATH (5.4) and stand in for the game's globals.
files["tests"] = { std = "max", ignore = { "111", "112", "113", "121", "122", "143" } }
