# EasyFind: Pawn Extension

The boss drops Pawn rates as upgrades for your character, in EasyFind's search bar. Type `upgrades` and each row names the item, how much better Pawn says it is and for which scale, and the boss and instance it drops from. A click goes where EasyFind's own loot row goes: the Adventure Guide on retail, directions to the instance on WoW Forever.

Requires Pawn and EasyFind.

## What it adds

- Upgrade rows in EasyFind's search results, and an `@upgrades` scope that lists them all, biggest upgrade first.
- Click to open the drop in the Adventure Guide (or get directions to the instance), Ctrl-click to try it on, Shift-click to link it in chat.
- Right-click to compare it in Pawn against what you wear.
- An Upgrades row in the filter menu with two toggles: Dungeons, Raids.
- A Pawn tile in the extensions menu, its badge counting the upgrades, with the same toggles in Options > Extensions.

## Dependencies

- EasyFind, with its extension API (EasyFind.API version 1) and its loot actions.
- Pawn, whose upgrade verdicts this addon reads at runtime through the functions of Pawn's own API section. Nothing of Pawn's is copied into this addon: no code, no scales, no stat weights.

## How it reads Pawn

Once the character is in the world and Pawn reports it is ready, the addon asks EasyFind for its boss loot and rates each drop with Pawn's upgrade check, a few items per frame so nothing stalls. It rates again when your gear or specialization changes, and when Pawn's scales change. Pawn's settings and scales are never written. If a function it needs is missing in the installed Pawn version, upgrade search turns itself off with one line in chat and nothing else changes.
