local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["EXT_NAME"] = "Pawn"
L["EXT_DESC"] = "Boss drops Pawn rates as upgrades for you."
L["PROVIDER_LABEL"] = "Upgrades"
L["CATEGORY"] = "Upgrade"
L["SETTINGS_HINT"] = "Which boss drops the list shows. Type upgrades in EasyFind to see them."

L["OPT_DUNGEONS"] = DUNGEONS or "Dungeons"
L["OPT_DUNGEONS_TIP"] = "Drops from dungeon bosses."
L["OPT_RAIDS"] = RAIDS or "Raids"
L["OPT_RAIDS_TIP"] = "Drops from raid bosses."

L["SUBTEXT_FMT"] = "+%d%% %s, from %s in %s"
L["SUBTEXT_BIG_FMT"] = "Upgrade for %s, from %s in %s"
L["MARK_FMT"] = "+%d%% %s"
L["MARK_BIG_FMT"] = "Upgrade for %s"
L["FROM_FMT"] = "From %s in %s"
L["REPLACES_FMT"] = "Replaces %s"
L["ALSO_FMT"] = "Also +%d%% for %s"
L["RATING"] = "Rating boss drops"

L["HINT_JOURNAL"] = ADVENTURE_JOURNAL or "Adventure Guide"
L["HINT_DIRECTIONS"] = "Directions"
L["HINT_DRESS"] = "Dressing room"
L["HINT_LINK"] = "Link in chat"
L["MENU_COMPARE"] = "Compare in Pawn"
L["MENU_PAWN"] = "Open Pawn"

L["NOT_READY"] = "Pawn's upgrade functions are not available in this version, so upgrade search is off."
L["NEED_EASYFIND"] = "This EasyFind has no loot data for extensions, so upgrade search is off."
