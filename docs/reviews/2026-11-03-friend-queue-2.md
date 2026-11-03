# Review: friend's queue, part 2, 2026-11-03

Reviewer: luau-reviewer (Review-Agent, friend's project). Follows `2026-11-03-friend-queue.md` (#1022, #1002, #1031, #1033, #1035, #1036, #1037).

| PR | Topic | Verdict | Action |
|---|---|---|---|
| #1038 | Windows draw the clean HUD symbols (#1027, UI-Engineer) | Pass | Ready; auto-merge; merged 30d9e5bc. |

## #1038 (ui-review checklist)
- All 15 names in the new `UI/Components/CleanGlyphs.luau` map exist in `ShopIcons` IDS (`Icon_Clean_*`), so `ShopIcons.clean` never returns nil for a mapped glyph. Unmapped glyphs fall through to the old sheet.
- `IconArt.set` checks in this order: `Theme.glyphImages` (the golden fish), then the clean symbol, then the sheet cell.
- No require cycle: `ShopIcons` requires nothing from the UI, and `CleanGlyphs` is pure, so `Theme` can require it and the spec runs in the cloud shim.
- View-only, with no remotes.
- Follow-up: spin, settings, invite, lock and equip best have no clean symbol yet, and need drawing plus Derek's upload.
- Open: the in-game picture check (QA). The UI gate shim draws no uploaded images.

## Still open from today
- QA in Studio or live: #1022 (cannon flight, intro cloud dip), #1035 (money flash), #1037 (top-right column, plus its before/after picture from Derek's side), #1038 (pictures).
- #1028: UI-Engineer's PR had not arrived by 13:51 UTC.
