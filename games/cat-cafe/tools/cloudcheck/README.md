# tools/cloudcheck: run Cat Cafe tests without Roblox Studio

Owner: qa-playtester. Node 20+ only, no Rokit tools needed. Works in the cloud (where GitHub release
downloads are blocked, so Lune, luau-lsp and friends cannot be installed) and on any PC.

```
cd games/cat-cafe/tools/cloudcheck
npm install --no-bin-links     # once; --no-bin-links only matters on network drives
npm test                       # tests/specs/*.spec.luau through tests/StudioRunner.luau
npm run test:verbose           # one line per test
npm run analyze                # strict type check + lint of src/, Roblox API types included
npm run analyze:tests          # the same over src/ and tests/ (specs, TestKit, the abuse client)
npm run check                  # analyze:tests, the tests, then the UI gate (what CI runs)
npm run uigate                 # only the UI gate (below)
node run-tests.mjs --filter Economy --json report.json
node run-tests.mjs --shared   # every spec in one Luau state (the old way; see below)
CLOUDCHECK_DUMP_DIR=/tmp/dump node analyze.mjs   # writes each module as the checker sees it, for debugging the rewrites
```

| File | What |
|---|---|
| `run-tests.mjs` | Builds a fake instance tree from `tests.project.json`, loads every ModuleScript with its own `script` and `require`, then calls `StudioRunner` exactly like Studio would, once per spec file in a fresh Luau state. Exit code 1 on any failure. |
| `analyze.mjs` | The Luau type checker (same engine luau-lsp wraps) in strict mode with lint, using the Roblox API definitions luau-lsp uses. Rewrites `require(script.Parent.X)` to module names first because there is no sourcemap here. Exit code 1 on type errors. |
| `rojo-tree.mjs` | Rojo project file to instance tree. Handles `$path`, `init.luau`, `.server`/`.client` suffixes, `.json` modules, optional paths and `globIgnorePaths`. |
| `roblox-shim.luau` | Instance proxies plus `game`, `workspace`, `task`, `warn`, `Enum`, `Color3`, `Vector3`, `UDim2`, `Random`... Enough for pure modules. `Instance.new`, events, DataStores and `RunService:IsServer()` are not there on purpose: a module that needs them is Studio-only and its spec says so. |
| `enum-keep.txt` | Enums kept in the type definitions (the full list is too big for the WebAssembly checker). Add a name here if you see `Unknown type 'Enum.X'`. |

Runtime: `@luau-rs/luau` (Luau 0.739 compiled to WebAssembly). The real gate is still `./check.sh` on a PC
with the Rokit toolchain: it has the sourcemap, the full enum list and selene. Treat a green run here as
"very likely fine" and a red run here as "definitely look".

## One Luau state per spec file

`run-tests.mjs` gives every spec file its own fresh Luau state, module cache and shim, and adds up the results.
On 2026-10-27 the suite in one shared state hit a fault in the WebAssembly Luau build: with 14 spec files and
the check 4 walk grid in `Layout.spec`, 24 `ProfileSchema.migrate` tests failed with "attempt to call a nil
value" at `ProfileSchema.luau:141`. Each of them passed when its spec ran alone, when any other spec file was
left out, or when a debug line was added to `ProfileSchema.luau`. Stopping the Luau garbage collector did not
help, and the cached `Catalog` module still held `getUpgrade`. It looks like a fault in the VM build that depends
on how much code is loaded, not a bug in the game. Real Roblox does not run this build. `--shared` brings back
the single state to reproduce it. If a spec fails here but passes with `--filter` and in Studio, suspect this
first and say so in the PR.

A second fault, also in the VM build, has its own fix: once the tree held 34 spec files the VM's garbage collector
could panic in the middle of a spec ("panicked at crates/luau-vm/src/gc/mark.rs:167:26: unsupported collectable type
5", then "Test run crashed: unreachable"), in two full runs out of three and in every run with a JavaScript GC
forced between specs (UI thread, 2026-10-27). `createState()` now calls `lua.gcStop()`, so no state ever collects.
A state lives for one spec file, and the whole suite peaks at about 190 MB (about 175 MB with the collector on).

## Differences from luau-lsp you may notice
- `Enum.X` for enums not in `enum-keep.txt` type checks as `any`.
- `script.Parent.Foo` outside of `require()` is typed as `Instance` (luau-lsp knows the tree), so those lines
  are reported as info, not errors. Pass `--all-lints` to see them.
- `Instance.new("X")` and `game:GetService("X")` are cast to `X` by text rewrite before checking.

## World scan: floating, gaps and clipping (QA, 2026-11-01)

```
npm run worldscan                               # node worldscan.mjs --assets, report in <system temp>/cat-cafe-worldscan
node worldscan.mjs --out ./scan --tier 3        # cafes dressed at Tier 3 instead of 5; no per-model pass
```

Derek, 2026-10-30: "lots of models are not connected to each other and are floating or have gaps especially around
the cafe", and "models with unfortunate placement clip into each other". This builds the real world and checks it.

| File | What |
|---|---|
| `worldscan.mjs` | Loads all 453 models from `assets/cat-cafe/rbx/` as `ReplicatedStorage.Assets`, runs `WorldBuilder.build()`, dresses every cafe at the chosen tier with its patio open and back door art on (as `CafeService` does), dumps every part and writes the report. About 75 s, 150 s with `--assets`. |
| `world-shim.luau` | A small Roblox with real geometry for the world code: `Vector3`, `CFrame` (all constructors, `*`, `Inverse`, `ToWorldSpace`/`ToObjectSpace`, `Lerp`), `Color3`, instances with parents, attributes, tags, `GetPivot`/`PivotTo`, `GetBoundingBox`, `ScaleTo`, `Clone` and `Workspace:Raycast` against boxes. `dumpParts(root)` writes one line per part. Separate from `roblox-shim.luau` on purpose: the tests' shim stays small. |
| `worldscan-checks.mjs` | Every part as an oriented box (a cylinder or ball as the box round it, a SpecialMesh by its scale) and the separating axis test between neighbours. **Floating**: a drawn group with no chain of parts within 0.1 studs down to the ground. **Seams**: faces 0.05 to 0.6 studs apart, overlapping at least 0.3 studs each way, with at least 3 of 5 sample points in between open, and only where it shows (side by side, or a tall thing over a floor). **Clipping**: a drawn part of one placed model more than 0.12 studs into another model, leaving out props set into the floor and doors and windows set into walls. |

Output, positions in world studs (y up, the Town Square at the origin): `world-scan.md` (folded tables per Cafes,
Town and Areas, then "Inside the model files"), `floating.csv`, `seams.csv`, `clipping.csv`, `models.csv` and
`world-parts.tsv` (every part: path, class, shape, CFrame, size, transparency, collide, mesh, model, material).

Limits: boxes only, so a round or wedge part can show a gap or overlap its real shape does not have (a reported gap
is at least that wide); Terrain, Studio-placed parts and anything built after join at runtime (customers, cats,
effects) are not in it; the area sets are checked in place, not on their own. It reads the code and models on disk,
so run it on the branch you want checked.

## UI gate: tiny buttons, small text, windows off the screen (UI-Engineer, 2026-11-01)

```
npm run uigate                                  # all three screens; report in <system temp>/cat-cafe-uigate
node uigate.mjs --profile phone --scene Quests  # one screen size, one window
node uigate.mjs --out ./ui --verbose            # report next to you, with the UI's own print output
node uigate.mjs --update-baseline               # accept today's findings (after fixing some, to shrink the list)
```

Derek picked "Skills and UI gate" on 2026-11-01: "a cloud check that fails tiny buttons, small text and off-screen
windows". This builds the real UI (`src/client/UI`) as `Controllers/UIController` starts it, with a mid-game player
(a 10-digit money count, a 20-letter cat name, quests half done, crates and potions), at the ui-review skill's three
sizes: desktop 1280 x 720, laptop 1366 x 768 and a phone at 844 x 390 with touch. It looks at the HUD, then opens
every window the way the game does and reads back each piece a player would see, in real screen pixels after the
window's UIScale. About 50 s for all three.

| Check | Fails the run when new |
|---|---|
| `tap` | Something pressable under 44 px on the phone or 36 px with a mouse, either way. |
| `text` | Text that renders under 9 px (the tag size, 12, at the phone's 0.75 scale). |
| `offscreen` | A button, text or scroll list more than 2 px past the screen edge. Something fully off screen is parked (slid out or waiting to tween in) and passes. |
| `topbar` | A button or text under Roblox's menu buttons, the top left 184 x 58. |
| `fonts` | A third font family besides Fredoka One and Nunito (emoji and symbols do not count). |
| `jitter` | Once the scene has settled, a property that changes 6 or more times in a second between only two or three values (Derek 2026-10-28: prize rows "spassing back and forth"). A bob or a countdown takes many values or changes rarely, so it passes. |
| `error` | A script error while the scene was built, with its stack. |

Warnings, in the report only: `fit` (a word clearly wider or taller than its box; text measures from average glyph
widths, so about 10% either way), `overlap` (a pressable covering a quarter of another in the same screen),
`thumbs` (on the phone, a pressable under Roblox's thumbstick or jump button) and `warning` (a `warn()` call).

`uigate-baseline.json` holds the findings accepted when the gate started (203: mostly 29 to 35 px buttons and the
phone's small tiles; 234 once the weekly quests and a code prize became scenes, with their shrunk prize text). One of them does not fail; a new one does. When a fix removes some, the run says so; run with
`--update-baseline` in that pull request so the list only shrinks. A run limited with `--scene` also passes a
finding the baseline holds under another scene of the same size, since one scene alone cannot tell which window
first showed a shared piece. A window added to the game goes in `SCENES` in
`uigate-scenes.luau`; the gate builds it at every size from then on.

| File | What |
|---|---|
| `uigate.mjs` | One fresh Luau state per screen size: world-shim, then ui-shim, then the scenes. Snapshot after each scene, checks, baseline, report. |
| `ui-shim.luau` | Sits on `world-shim.luau` (which exports its internals for this) and adds the client: `Players.LocalPlayer` with a `PlayerGui`, camera `ViewportSize`, `GuiService`, `UserInputService` set for touch or mouse, `TextService`. Signals that fire, property and attribute changed signals, a virtual clock (`task.wait`, `task.delay`, `Heartbeat` and tweens run on it, so a 3 s settle takes milliseconds) and Roblox's 2D layout: scale and offset, `AnchorPoint`, `UIScale`, `UIPadding`, `UIListLayout`, `UIGridLayout`, size and aspect constraints, `AutomaticSize`, `ScrollingFrame` canvases, `ClipsDescendants` and `TextScaled` with `UITextSizeConstraint`. The layout is incremental (only what changed is placed again). |
| `uigate-scenes.luau` | The catalog as `UIController` builds it, the sample player, and the list of windows and how each opens. |
| `uigate-checks.mjs` | The checks, the baseline compare and the report. |

Output in `<out>`: `index.html` (a picture of every scene with each finding boxed: red new, orange in the baseline,
blue a warning; hover a box for its finding), `report.md`, `findings.json`, one SVG per scene and `scenes/*.json`
(every piece with its box, colours, text and rendered text size).

Limits: pictures from asset ids are not downloaded, so an image shows as a tinted box; text sizes come from average
glyph widths per font, not the font files, and snap to whole pixels as Roblox draws them (which is what made the
prize rows shake, and what lets the jitter check see it); `UIFlexItem`, `UIPageLayout` and `UITableLayout` are not laid out; the
phone has no notch. The pictures are for finding a box, not for judging the look: check that in Studio.

