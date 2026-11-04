# Review: clean glyphs for Settings, Spin and Alley (2026-11-04)

Branch `ui/clean-icons-shadows`, `git diff origin/main...HEAD` (2 files, +15 -3):
`games/cat-cafe/src/client/UI/Components/CleanGlyphs.luau`, `games/cat-cafe/tests/specs/CleanGlyphs.spec.luau`.
Client UI only: no remotes, data, loops or connections touched, so checklist items 1 to 6 do not apply.
Check gate not run (rokit toolchain not installed in this environment).

## What I checked

**(a) Every place the glyphs reach IconArt** (paths relative to `games/cat-cafe/src/client/UI`)

| Glyph | Where | Through IconArt? | New look |
|---|---|---|---|
| ⚙️ | `Screens/HUD.luau:671-674` Menu tile | yes (Button), already sets `image = ShopIcons.clean("Menu")` | unchanged |
| ⚙️ | `Screens/HUD.luau:2434` Settings row in the Menu list | yes (Button) | clean gear, reads as Settings |
| ⚙️ | `Screens/Settings.luau:207` window badge | yes (Panel badge) | clean gear, reads as Settings |
| 🎡 | `Screens/SpinWheel.luau:203, 401, 444` badge and buttons | yes | clean wheel |
| 🎡 | `Components/PrizeChips.luau:265` spins prize glyph | only when there is no picture, and `partImage` (`:237`) always returns `ShopIcons.image("Spin")` | unchanged |
| 🎡 | `Screens/HUD.luau:244` "🎡 Free spin at the Town Square", `Screens/TipJar.luau:455` "+n spin", `Components/TipQueue.luau:84` tip card | no (text in a sentence, or TipCard's plain TextLabel) | unchanged emoji |
| 🐾 | `Screens/HUD.luau:1273` Alley travel button (no `image`) | yes (Button) | clean cat flap door with a paw |
| 🐾 | `Components/DecorPieces.luau:34` cat flap decor kind icon, reached by `init.luau:4212` (BigPull) and `Screens/DecorShop.luau:507` | yes (ItemIcon, glyph fallback when there is no model) | now the Catflap symbol, which is the right picture for a cat flap (better than the old Alley sheet cell) |
| 🐾 | `Components/Panel.luau:108` background paws, `Screens/SpinWheel.luau:275` wheel hub, `Screens/RescueBar.luau:373`, `Screens/TeamRescuePop.luau:95` | no (plain TextLabels, none call IconArt) | unchanged emoji |

No 🎡 is used as a Town Square place icon: Town Square is `Theme.icons.town` (🏡), and no place table in `src/shared` or `src/server` uses 🎡. No generic paw goes through IconArt. I looked at the three PNGs in `assets/cat-cafe/ui/icons-clean-2026-11-03`: Menu is a plain gear (fine for Settings, and the Menu tile already shows it), Spin is a colour wheel with a pointer, Catflap is a brown door with a yellow paw flap (reads as the Alley's paw door).

**(b) Priority.** `IconArt.set` (`Components/IconArt.luau:89-106`) uses `Theme.glyphImages` first and falls back to the clean symbol only when that entry is nil or empty. `Theme.glyphImages` holds only 🐟 (`Theme.luau:379-381`), so none of the three glyphs is in both tables and nothing changes priority. Their sheet cells (`Theme.luau:364, 367, 370`) are now never reached by IconArt.set; they are harmless.

**(c) Spec.** `🔒` is still a `Theme.icons` key with no clean symbol (the new header comment says lock, ✨ and 💌 are the only ones left, and that matches the sheet cells), so the "skips" case still tests something. The new test only re-reads the `CleanGlyphs.icons` table with hand-typed emoji, though (see the nit below). The first spec case (`names an uploaded clean symbol for every entry`) now also covers the three new names.

**(d) Ids.** `Icon_Clean_Menu` (`Components/ShopIcons.luau:86`), `Icon_Clean_Spin` (`:107`) and `Icon_Clean_Catflap` (`:115`) all exist with ids. They match the README table in `assets/cat-cafe/ui/icons-clean-2026-11-03/README.md:26, 38, 52`.

**(e) Style.** `--!strict` is kept, table style and type casts match the file, and the indentation and wrapping look StyLua clean (not run).

## Findings

No blockers and no should-fixes.

- **nit**, `games/cat-cafe/tests/specs/CleanGlyphs.spec.luau:33-38`: the new case passes its own emoji literals, so it would still pass if `Theme.icons.settings` were written differently (for example ⚙ without the U+FE0F selector) and the real gear never matched. It also never checks the table the game uses. Fix: also assert against the built map:
  ```lua
  local Theme = require(Client.UI:WaitForChild("Theme")) :: any
  expect(Theme.cleanGlyphs[Theme.icons.settings]).to.equal("Menu")
  expect(Theme.cleanGlyphs[Theme.icons.spin]).to.equal("Spin")
  expect(Theme.cleanGlyphs[Theme.icons.alley]).to.equal("Catflap")
  ```
- **nit**, `games/cat-cafe/tests/specs/CleanGlyphs.spec.luau:23-32`: the title says the map "skips keys the icon tables lack", but the case only checks one unmapped key and never checks that a `CleanGlyphs.icons` key missing from the input (such as `cats`) is left out. Fix: also assert `map["🐱"] == nil`, or count the map's entries (expect 3).
- **nit**, `games/cat-cafe/src/client/UI/Components/CleanGlyphs.luau:5-6`: "since 2026-11-04 only Equip Best (✨), Invite (💌) and the lock (🔒)" is true today but will go stale when the next symbol lands. Fix: drop the list, or say "see Theme.iconSheet cells without a CleanGlyphs entry".
- **nit**, `games/cat-cafe/src/client/UI/Screens/SpinWheel.luau` vs `Components/PrizeChips.luau:237`: the Spin window now draws `Icon_Clean_Spin`, while the spins prize tiles keep `ShopIcons.image("Spin")` (the older F97 picture). There are now two different wheel pictures. Not part of this change. If Derek wants them to match, use `ShopIcons.clean("Spin")` in `partImage` in a follow-up.

## Verdict

**merge**

QA test plan: on a fresh profile and a v-next build, check that the Settings row in the Menu list, the Settings window badge, the Spin Wheel window badge and spin buttons, the Alley travel button, and a cat flap decor pull with no model show the clean Menu, Spin and Catflap symbols. Check that the wheel hub paw, the rescue paws, the panel background paws and the "🎡 Free spin" line still show the emoji. No new console errors.
