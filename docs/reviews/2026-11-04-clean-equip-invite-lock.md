# Review: clean Equip Best, Invite and Lock symbols (2026-11-04)

PR #1212, branch `ui/clean-equip-invite-lock`, stacked on #1177. Reviewed `git diff origin/ui/clean-icons-shadows...HEAD`
(2 commits, 12 files, +101 -10): three PNGs, `README.md`, `mockup/preview-1136.png`, `source/icons.js`,
`source/iconshot.cjs`, `source/preview-1136.html` in `assets/cat-cafe/ui/icons-clean-2026-11-03`, and
`Components/ShopIcons.luau`, `Components/CleanGlyphs.luau`, `Theme.luau`, `tests/specs/CleanGlyphs.spec.luau`.
Client UI only: no remotes, data, loops or connections touched, so checklist items 1 to 6 do not apply.
`node run-tests.mjs --filter CleanGlyphs`: 6 passed, 0 failed. Full suite, UI gate and `./check.sh` not run (another
process runs them; no rokit toolchain here).

## What I checked

**(a) Mapping and priority.** `CleanGlyphs.icons` gains `equipBest = "EquipBest"`, `invite = "Invite"`, `lock = "Lock"`
(`Components/CleanGlyphs.luau:31-34`). All three keys exist in `Theme.icons` (`Theme.luau:327, 333, 334`), and
`ShopIcons.clean` finds `Icon_Clean_EquipBest/Invite/Lock` (`Components/ShopIcons.luau:116-119`). `IconArt.set`
(`Components/IconArt.luau:89-106`) still tries `Theme.glyphImages` first (only 🐟), then the clean symbol, then the
sheet. None of ✨ 💌 🔒 is in `Theme.glyphImages`, so the clean symbol wins for all three.

**(b) Is anything still reaching the sheet?** With these three, every key of `Theme.iconSheet.cells`
(`Theme.luau:359-376`) has a `CleanGlyphs.icons` entry with an uploaded id, and `IconArt.set:99-105` is the only code
that reads `Theme.iconSheet` or cuts `ImageRectOffset` from it (grep of `src/`). So the new `Theme.luau:354-355` comment
("IconArt never reaches the sheet") is accurate today. A picture that has not loaded yet falls back to the emoji, not
the sheet.

**(c) Where the three glyphs actually reach IconArt** (paths under `games/cat-cafe/src/client/UI`)

| Glyph | Where | Through IconArt? | Result |
|---|---|---|---|
| 💌 | `Screens/HUD.luau:2443` Invite row in the Menu list (`Button.new` with `iconSize`, `:2524-2528`) | yes (`Button.luau:363`) | clean envelope, as intended |
| 💌 | `init.luau:4412` Invite choice on the ask card (`Screens/AskCard.luau:193`, inline icon) | no: an inline icon goes into the text (`Button.luau:226, 277`), and only `Theme.glyphImages` is checked for a picture (`:229`) | unchanged emoji |
| ✨ | `Screens/CatRoom.luau:274`, `Screens/DecorShop.luau:180` Equip Best buttons | no: the glyph is part of `text` | unchanged emoji |
| ✨ | `Screens/CatRoom.luau:409, 810` shiny badges, `Components/TradeTile.luau:229`, `Screens/BaitCard.luau:172` | no (plain TextLabels) | unchanged emoji |
| 🔒 | `Screens/Areas.luau:152`, `CatRoom.luau:828, 1261, 1396`, `DecorShop.luau:858`, `UpgradeShop.luau:644`, `FishMarket.luau:1400`, `GateSigns.luau:356`, `IndexBoards.luau:586`, `LawnEdit.luau:506`, `TradeTile.luau:236` | no (TextLabel text or a sentence) | unchanged emoji |

So only Invite draws its new picture anywhere. Equip Best and the lock never went through IconArt, which means they
never drew the old sheet either.

**(d) Spec.** The new case (`tests/specs/CleanGlyphs.spec.luau:52-80`) checks a hand-typed copy of the sheet's keys,
not `Theme.iconSheet.cells` (see the should-fix). Swapping `lock`/🔒 for `unlock`/🔓 in the "skips keys" case keeps it
testing an unmapped key. Lines look StyLua clean at column width 100 (not run).

**(e) Ids.** README rows (`README.md:53-55`) match `ShopIcons.luau:117-119` exactly (89501318892947, 136442901295833,
133489571923895), same upload run 41889328270.

**(f) Art.** I looked at the three PNGs (256 x 256 RGBA) and `mockup/preview-1136.png`. They match the clean set: the
same thick dark outline, flat fills with one light highlight stroke, the same gold (#ffd23f) as the coins, and they sit
well next to Rewards and Feedback at tile size and at 128 px. The padlock's grey shackle and gold body read clearly on
the grey tile. The envelope's heart seal reads at 58 px.

**(g) #1071's claim.** Untouched: the ShopIcons hunk is only `:116-119` (the `Coins` and `Spin` image pictures at
`:55-56` are not in the diff), and the Theme hunk is only the comment at `:354-355` (`Theme.textures.fishCoin` at
`:137` is not in the diff).

## Findings

No blockers.

- **should-fix**, `assets/cat-cafe/ui/icons-clean-2026-11-03/README.md:65` and `Components/CleanGlyphs.luau:31`: the
  PR says Equip Best and the lock "still drew the old icon sheet" and answers Derek's live v187 "the old images on ui
  buttons" with them, but no code passes ✨ or 🔒 to IconArt (table in (c)). After this merges Derek still sees the ✨
  emoji on both Equip Best buttons and 🔒 on every lock, and the two new pictures show nowhere. Fix: either wire them
  (Equip Best: `icon = Theme.icons.equipBest, iconSize = ..., text = "Equip Best"` at `CatRoom.luau:274` and
  `DecorShop.luau:180`, or teach the inline path to use clean pictures, next point; the lock: `IconArt.set(lock,
  Theme.icons.lock)` on the labels at `Areas.luau:152` and `CatRoom.luau:828`, which are standalone symbol labels),
  or reword the README and the PR body so they say only Invite changes on screen now and the other two are ready for
  a follow-up.
- **should-fix**, `tests/specs/CleanGlyphs.spec.luau:55-73`: the "every Theme.iconSheet cell" case checks a pasted
  copy of the keys. If someone adds a 17th cell to `Theme.iconSheet.cells` without a clean symbol, the spec still
  passes and the new `Theme.luau:354` comment becomes wrong. Fix: move the cell table into the pure module, keyed by
  the `Theme.icons` key (Vector2 is in the cloud shim), and build Theme's table from it, as `cleanGlyphs` already is:
  ```lua
  -- CleanGlyphs.luau
  CleanGlyphs.sheetCells = { cats = Vector2.new(0, 0), collection = Vector2.new(1, 0), ... } :: { [string]: Vector2 }
  -- Theme.luau
  cells = (function() local t = {} for k, v in CleanGlyphs.sheetCells do t[Theme.icons[k]] = v end return t end)(),
  -- spec
  for key in CleanGlyphs.sheetCells do expect(ShopIcons.clean(CleanGlyphs.icons[key])).to.be.ok() end
  ```
  (Or put the same check in the UI gate, whose `ui-shim.luau` has Font and can require Theme.)
- **nit**, `Components/Button.luau:229`: an inline icon only looks up `Theme.glyphImages`, so a glyph with a clean
  symbol passed as `icon` on a plain row button (the ask card's "💌 Invite") stays an emoji. Fix: `local inlinePicture
  = if inlineIcon then Theme.glyphImages[icon] or ShopIcons.clean(Theme.cleanGlyphs[icon] or "") else nil`. This also
  fixes Equip Best once it passes `icon`. Check the gold style: the gold sparkle on the gold CatRoom button needs its
  outline to read.
- **nit**, `README.md:61-65`: the #1024 section (`:61`) notes `asset-permissions.yml` must run for the group-owned game before
  the pictures show live; the #1136 section does not say whether it ran for run 41889328270. Fix: one line saying it
  ran (with the run id), or that it still has to.

## Verdict

**merge after should-fixes** (the second one can be a follow-up issue if Derek wants Invite live now; the first at
least needs the README and PR body reworded so nobody expects Equip Best and the lock to change).

QA test plan: on the v-next build open Menu and check the Invite row shows the clean envelope (emoji until the asset
loads, never the old sheet cell); open the Cat Room and Decor Shop and note whether Equip Best and the lock badges
changed (with this PR as is they should not); no new console errors.
