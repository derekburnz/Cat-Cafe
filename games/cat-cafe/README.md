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

Check gate: `./check.ps1` (Windows) or `./check.sh`. Cloud stand-in without Rokit: `cd tools/cloudcheck && npm test && npm run analyze`.

## What is in the draft

| Area | Done | Where |
|---|---|---|
| World | street, 8 plots (floor, walls, door zone, sign, counter, espresso by level, spot furniture, decor anchors, table anchors, customer waypoints), alley with 8 spawn points and 2 lure spots, park with 10 and 3 plus a gate | `src/server/World/` |
| Assets | a Part placeholder for every name in features.md section 5, created only when `ReplicatedStorage.Assets` lacks that name | `World/Placeholders.luau`, `World/AssetRegistry.luau` |
| Data | ProfileStore sessions, version 1 schema with forward migration, settle on leave, offline gain (25% up to 1 h), BindToClose | `Services/DataService.luau`, `shared/ProfileSchema.luau` |
| Income | lazy accounting (`Economy.settle`), cafe multiplier, favorite spots, ProfileSync every 10 s and on change, client prediction between | `shared/Economy.luau`, `Services/CafeService.luau` |
| Strays | spawn loops per area with odds, max 6, despawn, wander, tutorial Common at alley point 1 | `Services/CatService.luau` |
| Grab | GrabBegin lock (3 s), GrabEnd roll with gloves, lure and a ring bonus the server scores from the hold time (a full hold resolves as a miss at 1.75 s), flee or retry rules | `Services/CatService.luau`, `shared/Catching.luau` |
| Carry | held cat welded to the torso, walk speed 13, auto check-in at the own door, saved on leave mid-carry | `CatService.luau`, `client/Controllers/WorldController.luau` |
| Shop | PlaceCat, UnplaceCat, SellCat, BuyUpgrade, BuyDecor, ToggleDecor, BuyLure, EquipLure, ClaimOffline, TutorialAdvance, all validated and rate limited | `Services/CafeService.luau`, `Services/Net.luau` |
| Lures | UseLure at a lure spot: bowl and food appear, a stray of the lure's odds comes after 45 s, reserved to the placer, never flees from them, refund on despawn | `Services/CatService.luau` |
| Client | UI module wired (catalog, state, intents, catch prompt, carry marker, tutorial hints), park gate, cosmetic customers | `src/client/Controllers/` |
| QA hooks | Studio-only `Services/Debug.luau`: snapshot, setCoins, setLastTick, resetProfile, giveCat, setUpgrade, spawnStray | |

## Known gaps (not in the draft)

- Analytics (F16), leaderboards (F17), fast travel (F19), TelemetryReport remote: not started.
- Tutorial beats are server-advanced (1 near the alley, 2 catch, 3 place, 4 table) and shown as text hints; no arrows beyond the alley marker.
- Spot sit offsets are the placeholder numbers in `World/Layout.luau`; real furniture from the asset thread may need the `sit_point` values from its manifest.
- Customers are client-only and use the placeholder blocky models, one per chair.
- Selene could not run in the cloud (its Roblox API dump download is blocked there); run `./check.ps1` on the PC for the full gate.
