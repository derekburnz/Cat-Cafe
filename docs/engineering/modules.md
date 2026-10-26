# Engineering module list (for QA and reviewers)

Updated 2026-10-26. Rojo project: `games/cat-cafe/default.project.json`. Sources under `games/cat-cafe/src/`.
Requires use Roblox instance paths (`script.Parent.X`, `ReplicatedStorage.Shared.X`).

## Pure shared modules (`src/shared` -> `ReplicatedStorage.Shared`)

| Module | Public functions (args -> returns) |
|---|---|
| `Config` | table of constants (data-model section 17) plus `Config.World` layout numbers |
| `Types` | types only: `Rarity`, `CatDef`, `UpgradeDef`, `DecorDef`, `LureDef`, `AreaDef`, `SpotDef`, `CatInstance`, `PlayerProfile`, `PlayerState`, `RingResult`, `ToastKind` |
| `Catalog` | `cats`, `catsById`, `getCat(id) -> CatDef?`, `catModelName(id) -> string`, `rarities`, `rarityOrder`, `rarityRank`, `spots`, `getSpot(id)`, `spotFurniture`, `upgrades`, `getUpgrade(id)`, `decor`, `getDecor(id)`, `lures`, `getLure(id)`, `areas`, `getArea(id)`, `lureSpotsPerArea` |
| `Economy` | `level(profile, id) -> number`, `cafeLevel(profile)`, `cafeMultiplier(profile)`, `catRate(instance)`, `variantMultiplier(variant)`, `incomePerSecond(profile)`, `settle(profile, now) -> earned`, `offlineGain(rate, lastSeen, now) -> amount, seconds`, `canAfford`, `trySpend -> boolean`, `credit`, `nextUpgradeCost -> number?`, `upgradeBlocker -> string?`, `decorBlocker -> string?`, `spotIsOpen`, `catOnSpot -> CatInstance?`, `seats`, `countsByCat` |
| `Catching` | `ringBonus(result)`, `ringResultFromTiming(seconds?)`, `chance(rarity, glovesLevel, lured, ring)`, `succeeds(chance, roll)`, `fleesOnMiss(rarity)`, `pickRarity(odds, roll)`, `candidates(rarity, area)`, `pickCat(rarity, area, roll)`, `rarityAtLeast(rarity, min)`, `percentText(chance)` |
| `ProfileSchema` | `VERSION`, `template(now) -> PlayerProfile`, `migrate(raw, now) -> PlayerProfile`, `catCount`, `collectionCount` |
| `Signal` | `Signal.new<T...>() -> { Connect, Once, Fire, DisconnectAll }` |
| `Remotes` | `ClientToServer`, `ServerToClient` name lists; `folder()`, `event(name)` touch ReplicatedStorage |
| `Mover` | needs RunService: `walkTo(model, target, speed, alive) -> boolean`, `face(model, target)` |

## Server (`src/server` -> `ServerScriptService.Server`)

| Module | Needs Roblox | Public |
|---|---|---|
| `World/Layout` | no (requires Config) | `plotPlacement(index) -> {x, z, side}`, `plot` (door, entry, sign, counter, espresso, spots, spotFurniture, decorAnchors, tables, seatOffsets), `alley`, `park`, `playerSpawn` |
| `World/Placeholders` | yes | `names() -> {string}`, `build(name) -> Model?`, `cat(def)`, `customer(variant)` |
| `World/AssetRegistry` | yes | `folder()`, `ensurePlaceholders() -> count`, `has(name)`, `clone(name) -> Model` |
| `World/WorldBuilder` | yes | `build() -> World { folder, plots, areas, gate }` |
| `Util/Guard` | no | `id(v) -> string?`, `bool(v)`, `int(v, min, max)`, `oneOf(v, list)` |
| `Util/RateLimiter` | no | `new(maxCalls, windowSeconds, clock?) -> { allow(key), forget(key) }` |
| `Services/Net` | yes | `start()`, `on(name, handler)`, `fire(player, name, ...)`, `fireAll(name, ...)`, `toast(player, text, kind?)` |
| `Services/DataService` | yes | `start()`, `get(player) -> PlayerProfile?`, `beforeRelease(fn)`, `takePendingOffline(player)`, `peekPendingOffline(player)`, `policy(player)`, `saves() -> boolean`, `loadedPlayers()`, signals `onLoaded`, `onReleasing` |
| `Services/PlotService` | yes | `start(world)`, `assign(player) -> Plot?`, `release(player)`, `get(player)`, `world()` |
| `Services/CafeService` | yes | `start()`, `buildState(player, profile) -> PlayerState`, `sync(player)`, `refreshPlot(player)`, `addCaughtCat(player, def, notify) -> instance, isNew`, `setCarrying(player, catId?)`, `carrying(player)`, `consumeEquippedLure(player) -> LureDef?, reason?` |
| `Services/CatService` | yes | `start(world)`, `strayCount(area)`, `debugSpawnStray(catId, area)` (Studio only) |
| `Services/Debug` | yes, Studio only | `snapshot(player?)`, `setCoins(player?, n)`, `setLastTick(player?, secondsAgo)`, `resetProfile(player?)`, `giveCat(player?, catId)`, `setUpgrade(player?, id, level)`, `spawnStray(catId, area?)`, `dataSaves()` |

## Client (`src/client` -> `StarterPlayer.StarterPlayerScripts.Client`)

`Net` (`fire`, `on`), `Controllers/UIController` (`start()`, `state`, `ownDoor()`), `Controllers/WorldController` (`start()`), `Controllers/CustomerController` (`start()`). `UI/` belongs to the ui-designer.

## Remotes (server checks in `CafeService` and `CatService`)

As listed in `src/shared/Remotes.luau` and data-model section 15, plus `RequestSync` (client asks for a full sync) and `GrabResult(strayId, ok, reason, retry)` (server -> client, closes or keeps the catch prompt).
Rate limits: 10 calls per second per player per remote; `GrabBegin` 1 per 2 s. Over the limit is dropped and logged.

## Test notes

- `tests/specs/Config.spec.luau` needs `GrabMinHoldSeconds = 0.15` in its expected table (added to data-model section 17 by the engineer).
- `Catalog.spec` "headline rarity" fails on the designer's kibble row (Common 70 vs alley 75): a design question, not code.
