# Purr Pot rough draft: how to run it

Rough draft of the whole slice loop with Part placeholders (2026-10-26). Everything is built from code at
server start, so the dev place only needs to be empty (keep or delete the Baseplate, either is fine).

## Run it in Studio

1. In this folder: `rokit install` once (tool versions come from the repo root `rokit.toml`), then `rojo serve`.
2. Open the dev place in Studio, Rojo plugin > Connect. The `Server`, `Client` and `Shared` folders appear.
3. Game Settings > Security > **Enable Studio Access to API Services** so saves persist between play sessions.
   Without it the game still runs: ProfileStore switches to its in-memory mock and you get a "Studio mode" toast.
4. Press Play (F5). Expected: a street with 8 cafes, a brick alley at the far end (+Z), a park behind a gate (-Z),
   you spawn on the street. The output says `[PurrPot] server ready ... 8 plots, N placeholder models`.

The ten-minute loop (features.md section 8): walk to the alley, hold **E** on a stray and release while the ring
is in the band, walk the cat home at carry speed, step into your door to check in, place it from the Collection (**C**),
buy a table in Upgrades (**U**). Coins tick up from placed cats; Decor is **B**.

Day and night (design v0.2): a new server starts in day with 2 minutes left. Strays arrive only with a night wave
(6 in the alley, 6 in the park) plus the tutorial Common at the alley entrance, so the alley is empty until the first
night. To skip the wait in Studio, run this in the command bar while playing:
`require(game.ServerScriptService.Server.Services.Debug).setPhase("night")`.

Check gate: `./check.ps1` (Windows) or `./check.sh`. Cloud stand-in without Rokit: `cd tools/cloudcheck && npm test && npm run analyze`.

## What is in the draft

| Area | Done | Where |
|---|---|---|
| World | street, 8 plots (floor, walls, door zone, sign, counter, espresso by level, spot furniture, decor anchors, table anchors, customer waypoints), alley with 8 spawn points, 2 bait spots and 2 rescue spots (drainpipe, box), park with 10, 3 and 3 (two trees, a box) plus a gate | `src/server/World/` |
| Clock | 3 min day, 2 min night, first night 2 min after the server starts; `ReplicatedStorage.Clock` attributes `Phase` and `PhaseEndsAt` (server time); cafe signs read Closed at night; the client tweens the sky to the style guide's section 9 presets and, at night, turns every World part named `_Bulb`, `_Bulbs`, `_Pane` or `_Tube` Neon with its light on | `Services/ClockService.luau`, `shared/Clock.luau`, `client/Controllers/WorldController.luau` |
| Assets | a Part placeholder for every name in features.md section 5, created only when `ReplicatedStorage.Assets` lacks that name | `World/Placeholders.luau`, `World/AssetRegistry.luau` |
| Data | ProfileStore sessions, version 1 schema with forward migration, settle on leave, offline gain (25% up to 1 h), BindToClose | `Services/DataService.luau`, `shared/ProfileSchema.luau` |
| Income | lazy accounting (`Economy.settle`), cafe multiplier, favorite spots, ProfileSync every 10 s and on change, client prediction between | `shared/Economy.luau`, `Services/CafeService.luau` |
| Strays | night waves: at each night start the area's leftovers leave (a stray mid-swing leaves after the swing) and a wave of `waveSize` arrives from the area odds; wander; tutorial Common at alley point 1 day or night | `Services/CatService.luau` |
| Net | GrabBegin lock (3 s), GrabEnd roll with the net level, bait and a ring bonus the server scores from the hold time (a full hold resolves as a miss at 1.75 s), flee or retry rules | `Services/CatService.luau`, `shared/Catching.luau` |
| Rescue | at each night start every rescue spot drops last night's cat and holds a new one half the time (area odds with Rare doubled); RescueBegin locks it to one player for 6 s, RescueEnd after the 4 s hold always succeeds; the cat is saved with `rescued` and earns 1.10x | `Services/CatService.luau`, `shared/Catching.luau`, `shared/CatStats.luau` |
| Carry | held cat welded to the HumanoidRootPart in the manifest's carried pose (cradled across the chest), walk speed 13, auto check-in at the own door, saved on leave mid-carry | `CatService.luau`, `client/Controllers/WorldController.luau` |
| Shop | PlaceCat, UnplaceCat, SellCat, BuyUpgrade, BuyDecor, ToggleDecor, BuyLure, EquipLure, ClaimOffline, TutorialAdvance, all validated and rate limited | `Services/CafeService.luau`, `Services/Net.luau` |
| Bait | UseLure at a bait spot (ids keep the `lure` name): bowl and food appear, a stray of the food's odds comes after 45 s day or night, reserved to the placer, never flees from them, refund on despawn | `Services/CatService.luau` |
| Client | UI module wired (catalog, state, intents, swing and rescue prompts, clock chip, carry marker, tutorial hints), park gate, day and night lighting, cosmetic customers by day only | `src/client/Controllers/` |
| QA hooks | Studio-only `Services/Debug.luau`: snapshot, setCoins, setLastTick, resetProfile, giveCat (optionally rescued), setUpgrade, spawnStray, setPhase, clock, spawnStuckCat, counts | |

## Known gaps (not in the draft)

- Analytics (F16), leaderboards (F17), fast travel (F19), TelemetryReport remote: not started.
- Tutorial beats are server-advanced (1 near the alley, 2 catch, 3 place, 4 table) and shown as text hints; no arrows beyond the alley marker.
- Wall props (shop windows, string lights) sit at a `y` above the floor in `Layout.alley.props`, front (-Z) turned into the alley.
- Spot sit offsets are the placeholder numbers in `World/Layout.luau`; real furniture from the asset thread may need the `sit_point` values from its manifest.
- Customers are client-only and use the placeholder blocky models, one per chair.
- Selene's Roblox standard library cannot be downloaded in the cloud; CI runs the real selene. Cloud threads lint with a minimal stand-in std (see the engineering notes in project memory).
- Rescue props and the net stay placeholders until their exports are imported into `assets/cat-cafe/rbx/`. The placeholders share the real props' pivots, and the stuck cat sits at `Layout.stuckPoses` (the manifest's `stuck_pose` values), so the import needs no code change. The cat's head and tail angles from the manifest are not applied yet.
