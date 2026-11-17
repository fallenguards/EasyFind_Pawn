# EasyFind: Pawn Extension

Pawn's verdict on the items EasyFind finds. A boss drop, a bag item or an upgrade row that Pawn rates above what you wear says how much better it is and for which scale, right on EasyFind's own row. Hover the row for what the item replaces and the other scales it helps; right-click it to compare the item in Pawn.

With Pawn installed, EasyFind's `@upgrades` is judged by Pawn: under each gear slot, the drops Pawn rates as upgrades for the character you play, biggest first.

Requires Pawn and EasyFind.

## What it adds

- On EasyFind's item rows: the percent and the scale after the row's text, what the item replaces in the tooltip, and Compare in Pawn and Open Pawn on the right-click menu.
- `@upgrades` judged by Pawn's scales for the character you play. Other characters' pages keep EasyFind's own comparison.

## Dependencies

- EasyFind, with its extension API (EasyFind.API version 1) and its loot actions.
- Pawn, whose upgrade verdicts this addon reads at runtime through the functions of Pawn's own API section. Nothing of Pawn's is copied into this addon: no code, no scales, no stat weights.

## How it reads Pawn

Once the character is in the world and Pawn reports it is ready, the addon asks EasyFind for its boss loot and rates each drop with Pawn's upgrade check, a few items per frame so nothing stalls. It rates again when your gear or specialization changes, and when Pawn's scales change. Pawn's settings and scales are never written. If a function it needs is missing in the installed Pawn version, the verdicts turn themselves off with one line in chat and nothing else changes.
