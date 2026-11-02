# Review: night close to the Spin Wheel (PRs #144 to #242)

Reviewer: luau-reviewer thread, 2026-10-27, about 08:45 to 15:40 UTC. This review is read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. It follows `2026-10-27-v05-builds.md`. Everything was checked against the design as it stood at each PR: v0.5.1, Derek's 12:07 round (#174), the gold rename (#180), the rewards design (#198), the Index rename (#213) and design v0.6 (#220).

Status is as of main at fe7772c (#242 merged). Findings are numbered on from the last doc: S47 to S65 and N89 to N142.

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #144 cafes close at night, bowl on the back step (F44) | engineer | e83c2a7 | Sound. Nit N91, since fixed |
| #146 name your cats, filtered (F33) | engineer | 95032f7, then 20559f2 | S47 fixed as an allow list. N92 fixed, N95 since fixed |
| #147 tutorial beat for the bait bowl (F13) | engineer | d16d553, then 3d6eab6 | S48, N93 and N94 fixed before the merge |
| #149 player list leaderboard (F17) | engineer | 5d0488a | Sound. No findings |
| #150 shiny coats, owner's turn card | ui-designer | 1f23032 | Sound. Closes N89 and N90 |
| #151 tutorial strip wraps | ui-designer | d932b7c | Sound. Closes the HUD half of N94 |
| #152 Rename box, names on rate tags | ui-designer | aa4b824 | Sound. Nit N96, since fixed |
| #155 onboarding funnel, coin sources and sinks (F16) | engineer | b0ae49a | Sound. No findings |
| #156 catch, bait and area funnels, device report | engineer | c608313, then 0cdb5ce | S49 and N97 fixed before the merge |
| #159 working cats stand upright in outfits (F25) | engineer | d4156a5 | Sound. S50 (UI) still open. S51 (assets) and N98 since fixed |
| #162 hold E to catch, DropCat | engineer | 375eff3 | Sound. S52 fixed in UI #168. N99 and N100 since fixed |
| #164 upright cats doze standing | vfx-animator | 32711be | Sound. No findings |
| #166 no floating "opens at Tier" labels | engineer | c21bf11 | Sound. N101 fixed in UI #177 |
| #168 HUD v3: My Cafe, Drop, hold fill | ui-designer | 32ec51b | Sound. Closes S52. S53 (DropCat forward) since fixed |
| #169 caught cats can be placed again (uid guard) | engineer | 72e9b7a | Sound. No findings |
| #171 SAFE ZONE markings | engineer | 8de3380 | S54 (Park stripe placement), since fixed |
| #173 Staff tab | ui-designer | 5791150 | S55 and N102, since fixed |
| #175 UnequipAll | engineer | d24363e | Sound. No findings |
| #176 cat room inventory | ui-designer | f9fd1e0 | Sound. N103 fixed in #197 |
| #177 retired UI pieces dropped | ui-designer | fdcc976 | Sound. Closes N101 |
| #178 My Cafe after a drop | ui-designer | 9ae89b6 | Sound. No findings |
| #179 gold cats in Effects | vfx-animator | 335456e | S56 (double reveal), since fixed |
| #181 shiny renamed gold, save version 4 | engineer | b0ddbdf | Sound save path. S57 closed by UI #186, S58 by assets #189. N104 and N105 since fixed |
| #182 zone chip | engineer | ef957ef | Sound. No findings |
| #183 location markers, Safe zone chip | ui-designer | 478bd5d | Sound. N106 fixed in #188 |
| #185 themed cats design | game-designer | 59ed039 | S59 fixed in #198 |
| #186 gold names in the UI | ui-designer | c328e78 | Sound. Closes S57 |
| #188 cat-eared windows | ui-designer | 89cc178 | Sound. Closes N106 |
| #190 placement audit | engineer | 2892838 | Sound. No findings |
| #193 gold names only | ui-designer | 8357d68 | Sound. Closes N107 |
| #195 cat ears on HUD pills | ui-designer | 2890f8a | Sound. No findings |
| #197 sell prices from Catalog | ui-designer | 61c30bc | Sound. Closes N103 |
| #198 Tip Jar and Book rewards design (F47, F48) | game-designer | 3070eaf | Sound. S60 built in #211. N112 and N113 taken, N114 built |
| #200 tree cat across its branch | engineer | 7a6de9e | Sound. N108 (assets), since fixed |
| #201 themed cats build | engineer | a9dc3d4 | Sound. N109, since fixed |
| #202 SetSetting remote | engineer | d8b4219 | Sound. N110 closed in #198 and QA #205 |
| #203 Settings screen | ui-designer | 11d10d6 | Sound. N111 closed in #207 |
| #206 Tip Jar (F47) | engineer | d176385, then 2d866d8 | Sound. No findings |
| #207 Settings wiring | engineer | dd05a37 | Sound. Closes N111. N115 fixed in #208 and #209 |
| #209 Tip Jar UI | ui-designer | 48ed5de | Sound. N116, since fixed |
| #210 Index rewards UI (F48) | ui-designer | 63505ef, 5c0a289, 6615b7f | S61 and N117 fixed. S62 raised for #211 |
| #211 Index rewards server, save version 5 (F48) | engineer | 5c92468 to 24728ec | Closes S60 and N114. S62, S63 and N124 fixed before the merge |
| #215 every setting saved | engineer | a3f1e89, then ebc0d62 | Sound. N118 accepted. N119 to N121 since fixed |
| #216 Effects follow screen shake and low performance | vfx-animator | 7fc6687 | Sound. N121 and N122 since fixed |
| #218 volume sliders scale the channels | sound-designer | f2449df | Sound. N123 fixed by QA #221 |
| #219 SettingsList edges | qa-playtester | 04d4adf | Sound. No findings |
| #220 design v0.6: Spin Wheel, Index Boards, three areas | game-designer | 745a0b8 | Sound. N125 to N130 all taken |
| #222 cafe cats loaf | vfx-animator | 44b87cd | Sound. N131 taken in #227 |
| #223 Spin Wheel server, save version 6 (F49) | engineer | fc0b1e4, then 8dbdb02 | Sound. N125 and N128 built. S64 closed on the server side |
| #224 sound hooks | engineer | 25778b7 | Sound. N133, since fixed |
| #226 world Spin Wheel turns for everyone | vfx-animator | caa9659, then 035a6ab | S64 and N134 fixed before the merge |
| #227 sounds for the 2026-10-27 features | sound-designer | 1eb130c, then 3a26b1e | Sound. N135 withdrawn |
| #230 Low performance and Show other cats in the world | engineer | 1ec58e9, then 7b9890f | N136 and N137 fixed before the merge |
| #231 Settings v2 | ui-designer | 9879102, then 027755d | Sound. N138 fixed before the merge. N139 fixed in #241 |
| #233 bigger HUD pictures, fold tabs | ui-designer | 2f77e64 | Sound. N141 optional, open |
| #234 Effects skip hidden cats | vfx-animator | e337fcc | Sound. N140 fixed at 9e15e9b. Not merged yet |
| #235 Spin window (F49) | ui-designer | 5dd88c8 | Sound. Closes N127 and N132 |
| #236 Spin window cues, no purr from hidden cats | sound-designer | f24020c | Sound. No findings |
| #238 wrong dealer food gets its own refusal | engineer | 11ea6c3 | Sound. No findings |
| #239 night lights stop washing the cafe out | engineer | 533a248 | Sound. S65 (style guide) and N142 open |
| #241 every setting as the screen shows it | engineer | ac5a7bc | Sound. Closes N139 |
| #242 Spin station prompt wired to the window | engineer | bc4455f | Sound. No findings |

QA, tooling and docs-only PRs in the range (#145, #148, #153, #154, #158, #160, #161, #165, #167, #170, #172, #174, #180, #184, #187, #189, #191, #192, #194, #196, #199, #204, #205, #208, #212 to #214, #217, #221, #225, #228, #229, #232, #237 and #240) were merged on their owners' checks. Where they closed one of these findings, the table names them.

## What was checked

**Names and the save (#146, #152, #169, #181, #193).**
- **Cat names.** `CatName.allowed` is an allow list: plain ASCII words, Latin-1 and Latin Extended letters, kana, CJK and Hangul. Invisible, joining and line-break characters are refused (S47).
- **Filtering.** Names on show are filtered through `NameService.request` on join. The rest are filtered from a snapshot after a delay (N95). Other players see only filtered text.
- **Gold rename.** Save version 4 maps the old `shiny` variant to `gold` and `shinyCollection` to `goldCollection`. An older server kicks a newer save rather than dropping fields (S31). The UI reads only the gold names since #193, and every `_Shiny` model became `_Gold` in #189.
- **uid guard.** `Guard.id` takes hyphens, so a caught cat's uid passes placement, selling and renaming (#169).

**Catching and carrying (#162, #168, #171, #175).**
- **Hold E.** The prompt's `HoldDuration` is 0.5 s and the card fills over the hold (S52).
- **Drop.** `DropCat` is forwarded from the UI (S53). A self-drop is kept out of the shove outcomes (N100). A drop outside an area with no home area keeps the cat in the player's arms (N99).
- **Safe zones.** Each stripe sits on the area side of its gate (S54).

**Working cats and placement (#159, #164, #190, #200, #201).**
- `CatPose.upright` runs once per clone (N98), and `dress` skips the role piece in the model's prop slot.
- A rate tag over an upright cat is still placed from the old axes (S50, open).
- Models stand on their floors and clear of each other. Rescue poses match `poses.py` (N108).

**Analytics (#155, #156, #224).**
- The device report goes on the first ProfileSync, when the Telemetry session exists (S49).
- `ui_opened` is sent once per screen per session (N97).
- The progression funnel is `area_index` (N124).
- Circle sounds stop when the stray despawns mid-catch (N133).

**Rewards: Tip Jar and Index (#198, #206, #209, #210, #211).**
- **Tip Jar.** `ClaimTipJar(step)` passes `Guard.int` and the server checks session time on its own clock. `claimed` is a dense array of 12 booleans, because a sparse number-keyed table can lose entries over a remote (N116).
- **Index rewards.** `ClaimIndexReward(areaId, milestoneId)` is limited to 1 per second. Counts come from the server's collection, and the prizes table is frozen. The saved fields `indexRewards` and `stats.tipJarClaims` came with save version 5 (S60), because `ProfileSchema.migrate` rebuilds from the template and an older server would drop them. The Book is the Index in code and player text alike (S62). The claim path is wired in UIController (S63). A gold Index piece replaces the normal one in the bonus (N114, N117).

**Settings (#202, #203, #207, #215, #216, #218, #230, #231, #241).**
- **Keys.** `shared/Settings` holds eight keys: six switches and two volumes from 0 to 1 at 0.01. `Settings.clean` validates each `SetSetting`, which is limited to 4 per second, and `sanitize` runs on load.
- **No version bump (N118, accepted).** An older server keeps only `music` and `sfx`, so only preferences could be lost.
- **The tap hold.** Every key reads as the screen shows it. A tap or drag shows at once and holds until the server agrees or 5 s pass (N111, N139).
- **Sliders.** A slider sends once on release, and the minus and plus buttons send once after a pause, so the limiter never drops the final value (N120). A drag follows only the touch that started it (N138).
- **Defaults.** Low performance starts off (N122).
- **Show other cats.** Other players' cats get `LocalTransparencyModifier` 1, their billboards are disabled and the model gets the local `HiddenLocal` mark. Parts added later under a hidden cat are hidden too (N137). Audio skips hidden cats (#236). Effects will once #234 merges.

**Spin Wheel (#220, #223, #226, #235, #242).**
- **The remote.** `SpinWheel()` takes no arguments and is limited to 2 per second. The server checks range from the tagged station's pivot (14 studs), a 4 s cooldown and `Spin.take`, rolls with its own `Random` and pays before `SpinResult(slice, amount)`. A refused spin gets `(0, 0)`.
- **The save.** Save version 6 adds `spin` and `stats.spins`, and `Spin.sanitize` clamps both fields on load (N128).
- **Landing.** The world wheel and the window both land on the paid slice: the server sets `LastSlice` before `LastSpinAt` (S64), and the window eases with no near-miss crawl (N127).
- **Range.** The window closes past range plus 2 studs (N132). The prompt's reach sits inside the server's range.
- **No Robux.** Nothing sells or speeds up a spin (N126).

**Night look and the dealer (#238, #239).**
- A wrong food says "That food isn't on the cart." "Fresh stock just arrived" is kept for the food that was in that slot in the window before.
- Night exposure is 0. Window, string light and tube lights are 0.8 brightness and 10 range, and panes stay 0.3 transparent.

## Open findings

| Id | Owner | Finding |
|---|---|---|
| S65 | asset-artist | `docs/art/style-guide.md` section 9 (lines 279 and 283) and `assets/cat-cafe/blender/build_all.py:126` and `:128` still give night exposure 0.25, PointLight 1.5 / 16 and solid Neon panes. #239 changed the code to 0, 0.8 / 10 and panes at 0.3 transparency after the laptop playtest. Sent to the model thread |
| S50 | ui-designer | `WorldTags.anchorOf` measures an upright cat along its old axes, so the rate tag sits too low on a standing working cat |
| N140 | vfx-animator | Fixed on #234 at 9e15e9b, but #234 is not merged: automerge was refused at 15:22 and the label came off. Until it lands, hidden cats still get sparkles and z's |
| N141 | ui-designer | Optional: the fold tabs are 44 x 34 design px and shrink on small phones. Give them a minimum touch size if QA finds them hard to hit |
| N142 | engineer | Optional: an `isPane` helper next to `isTube` in WorldController, coming with the next WorldController push |
| QA S32, S33 | qa-playtester | The S33 row still describes three Settings rows and says the screen has no rows for volumes, shake, low performance or other cats; Settings v2 (#231) has all eight |

Carried over from earlier docs: N73, N62, N63, N51, N53, N55, N56 and N13 (game-designer), S11 (Derek), and README:41 EquipLure (lead).

## Notes for the next reviewer

- Any new saved field needs a `ProfileSchema.VERSION` bump. `migrate` rebuilds from the template on every load, so an older server would drop the field mid-rollout.
- Check names across PRs in one pass: remote payloads, attributes (`Gold`, `LastSlice`, `HiddenLocal`), catalog keys and `UI.update` fields. Most should-fixes in this range came from two halves of one feature landing under different names (S57, S61, S62, S63, S64).
- `UI.update` partials cannot set a field to nil. The shared `Signal` spawns handlers from a dictionary, so handler order is not fixed.
- The StyLua gate checks `src` only.
