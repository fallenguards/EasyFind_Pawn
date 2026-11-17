-- The addon loaded offline: what it registers with EasyFind's API, that it
-- stays silent without Pawn, and that any gear on a row is rated, a boss
-- drop or not (2026-11-17: only EasyFind's boss loot was).
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

function T.toc_requires_only_easyfind_pawn_optional()
    local fields = Harness.Toc()
    Eq(fields.Dependencies, "EasyFind", "Dependencies")
    Eq(fields.OptionalDeps, "Pawn", "OptionalDeps")
    Eq(fields.LoadWith, nil, "LoadWith")
    True(fields["X-Curse-Project-ID"] ~= nil, "the CurseForge project")
end

function T.toc_lists_retail_and_forever()
    local fields = Harness.Toc()
    local listed = {}
    for n in fields.Interface:gmatch("%d+") do listed[tonumber(n)] = true end
    for _, n in ipairs({ 120105, 16001 }) do True(listed[n], "Interface lists " .. n) end
end

function T.toc_files_all_exist()
    local _, files = Harness.Toc()
    True(#files >= 2, "the toc lists its files")
    for _, file in ipairs(files) do True(io.open(Harness.ROOT .. "/" .. file) ~= nil, file .. " exists") end
end

function T.registers_its_tile_opening_upgrades()
    local ext = Harness.Load().extension
    True(ext ~= nil, "the extension is registered")
    Eq(ext.id, "pawn", "id")
    Eq(ext.scope, "upgrades", "the tile opens @upgrades")
    True(type(ext.icon) == "string" and ext.icon:find("EasyFind_Pawn", 1, true) ~= nil, "its own glyph")
end

function T.without_pawn_registers_nothing()
    local ctx = Harness.Load({ pawn = false })
    Eq(ctx.extension, nil, "extension")
    Eq(ctx.decorator, nil, "decorator")
end

function T.any_gear_on_a_row_is_rated_not_only_boss_loot()
    local ctx = Harness.Load()
    ctx.Fire("PLAYER_ENTERING_WORLD")
    local d = ctx.decorator
    True(d ~= nil, "the row decorator is registered")
    d.applies({ itemID = 1001 })
    d.applies({ itemID = 1002 })
    ctx.Settle()
    True(d.applies({ itemID = 1001 }), "a robe no boss drops, rated an upgrade")
    True(not d.applies({ itemID = 1002 }), "cloth is no gear: no verdict")
    True(not d.applies({ itemID = 1003 }), "a hood Pawn rates no upgrade: no mark")
    True(ctx.judge ~= nil, "@upgrades is judged by Pawn")
end

return T
