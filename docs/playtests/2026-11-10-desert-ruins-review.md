# Desert and Ruins model review (2026-11-10)

Issue #2585 (under #2580). QA-Planner, cloud checks only, on main f5dc262d. The Studio rows of the test plan
(`2026-11-09-desert-ruins-test-plan.md`) still need a pass on a dev copy; see "Still to do in Studio".

## Result

No blocking problems. Every Desert and Ruins row the world scan reports follows a pattern that the five older areas
share, except two small gaps in the Desert wagon and trap canopy, filed as a polish ticket.

## Model files (`assets/cat-cafe/rbx/`)

- All 20 Desert and Ruins cats have all six variants (base, `_Sit`, `_Work`, `_Gold`, `_Gold_Sit`, `_Gold_Work`),
  named as `Catalog` builds them (`CatCafe_Cat_<PascalCase id>`).
- No Script, LocalScript or ModuleScript in any cat, camp, set, backdrop, gate, cannon, index board or crate model.
- Mirage has 60 semi-transparent parts. That is its design, not a leak.

## Cloud specs

Type check clean (819 scripts). Passing: Cannon 45, Layout 103, Catalog 84, Crates 54, Pity 34, Rescue 73,
StrayTopUp 6, LateStations 36, CampExtras 53, EffectsAreaFx 2, Waves 3 (Waves loops every area for the deep
Mythicals).

## World scan

`worldscan.mjs` ran out of wasm memory with seven areas; it passes with the collector on (separate tools PR,
`friend/worldscan-gc`). 90,787 parts, 237 s. The Desert and Ruins rows fall in the report's Town section.

| What | Desert / Ruins rows | Verdict |
|---|---|---|
| Camp basket 0.91 into the CampBasket | 1 each | Same in all seven camps. Expected. |
| Backdrop hills 8 to 15 studs into the ground | 3 | Hills are sunk on purpose; the Town backdrop does the same (18.9). |
| Spires and a canyon 1.1 to 1.3 into the brick boundary walls | 4 | Rock merging into the wall; Woods cliffs do the same at 0.57. Fine. |
| Wall ruin 0.73 into the backdrop ground | 1 | Below the floor line. Fine. |
| Ruins wall 0.33 into the backdrop | 1 | Behind the wall. Fine. |
| Seams 0.1 to 0.6 between walls, sets, camps and cannons | about 40 | Same sizes and kinds as every other area. |
| Palm fronds 0.29 off the trunk | 3 | Leaves on a code-built palm; same look as the older camps. |
| Glyph Halls glow 0.15 to 0.16 off the wall | 2 | The glow plate sits off the stone on purpose. |
| Desert Gate, Oasis Spa piece 0.23 to 0.26 off | 2 | Inside the model, above the ground. Minor; left as is. |
| **Wagon pieces 0.32 to 0.34 off, trap canopy 0.1 off** | 3 | **Polish ticket #2990.** The wagon gap is at wheel height where players walk. |

## Still to do in Studio (parked with the coordinator)

These need a dev copy on Derek's PC: B1 cannon visuals, the edge walks, the phone camera in both areas, the carry pose,
outfits, Reduce Motion, and the stress test.
