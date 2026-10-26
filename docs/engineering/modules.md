# Engineering module list (for QA and reviewers)

Updated 2026-10-26 (design v0.2). Rojo project: `games/cat-cafe/default.project.json`. Sources under `games/cat-cafe/src/`.
Requires use Roblox instance paths (`script.Parent.X`, `ReplicatedStorage.Shared.X`).

## Pure shared modules (`src/shared` -> `ReplicatedStorage.Shared`)

| Module | Public functions (args -> returns) |
|---|---|
| `Config` | table of constants (data-model section 17) plus `Config.World` layout numbers |
| `Types` | types only: `Rarity`, `CatDef`, `UpgradeDef`, `DecorDef`, `LureDef`, `AreaDef` (`waveSize`, `rescueSpots`), `SpotDef`, `CatInstance` (`rescued?`), `CatView`, `PlayerProfile`, `PlayerState`, `RingResult`, `ClockPhase`, `ToastKind` |
| `Catalog` | `cats`, `catsById`, `getCat(id) -> CatDef?`, `catModelName(id) -> string`, `rarities`, `rarityOrder`, `rarityRank`, `spots`, `getSpot(id)`, `spotFurniture`, `upgrades`, `getUpgrade(id)`, `decor`, `getDecor(id)`, `lures`, `getLure(id)`, `areas`, `getArea(id)`, `lureSpotsPerArea`, `renamedUpgrades` (old id -> new id, gloves -> net) |
| `Economy` | `level(profile, id) -> number`, `cafeLevel(profile)`, `cafeMultiplier(profile)`, `catRate(instance)`, `variantMultiplier(variant)`, `incomePerSecond(profile)`, `settle(profile, now) -> earned`, `offlineGain(rate, lastSeen, now) -> amount, seconds`, `canAfford`, `trySpend -> boolean`, `credit`, `nextUpgradeCost -> number?`, `upgradeBlocker -> string?`, `decorBlocker -> string?`, `spotIsOpen`, `catOnSpot -> CatInstance?`, `seats`, `countsByCat` |
| `Catching` | `ringBonus(result)`, `ringResultFromHold(secondsSinceGrabBegin) -> RingResult?` (nil = dropped, lock continues), `chance(rarity, netLevel, lured, ring)`, `succeeds(chance, roll)`, `fleesOnMiss(rarity)`, `pickRarity(odds, roll)` (scaled by the odds total), `rescueOdds(odds) -> odds` (Rare doubled, back to 100), `candidates(rarity, area)`, `pickCat(rarity, area, roll)`, `rarityAtLeast(rarity, min)`, `percentText(chance)` |
| `CatStats` | `level`, `xp`, `charm`, `rollCharm(roll1, roll2)`, `charmMultiplier`, `levelMultiplier`, `rescuedMultiplier(rescued?)`, `variantMultiplier`, `stars`, `starsText`, `xpToNext`, `xpForLevel`, `addXp(instance, amount)`, `rating(instance)` (includes the rescued bonus), `maxRating(catId)`, `isBetter(a, b)`, `newInstance(uid, catId, now, charm?)`, `view(instance) -> CatView`, `shortText` |
| `EquipBest` | `value(instance, spot)`, `openSpots(profile)`, `plan(profile) -> Plan`, `apply(profile, plan) -> moved`, `isOptimal(profile, plan)` |
| `Clock` | `phaseAt(secondsSinceServerStart) -> ClockPhase, secondsLeft`, `startOf(phase) -> seconds` |
| `ProfileSchema` | `VERSION`, `template(now) -> PlayerProfile`, `migrate(raw, now) -> PlayerProfile` (carries a saved gloves level to net, keeps `rescued`), `catCount`, `collectionCount` |
| `Signal` | `Signal.new<T...>() -> { Connect, Once, Fire, DisconnectAll }` |
| `Remotes` | `ClientToServer`, `ServerToClient` name lists; `folder()`, `event(name)` touch ReplicatedStorage |
| `Mover` | needs RunService: `walkTo(model, target, speed, alive) -> boolean`, `face(model, target)` |

## Server (`src/server` -> `ServerScriptService.Server`)

| Module | Needs Roblox | Public |
|---|---|---|
| `World/Layout` | no (requires Config) | `plotPlacement(index) -> {x, z, side}`, `plot` (door, entry, sign, counter, espresso, spots, spotFurniture, decorAnchors, tables, seatOffsets), `alley` and `park` (spawnPoints, lureSpots, rescueSpots, props), `playerSpawn` |
| `World/Placeholders` | yes | `names() -> {string}`, `build(name) -> Model?`, `cat(def)`, `customer(variant)` |
| `World/AssetRegistry` | yes | `folder()`, `ensurePlaceholders() -> count`, `has(name)`, `clone(name) -> Model` |
| `World/WorldBuilder` | yes | `build() -> World { folder, plots, areas, gate }`; each area has `spawnPoints`, `lureSpots` and `rescueSpots` (anchors tagged `RescueSpot` with `Area`, `RescueSpotId`, `Occupied`, `LockedBy`) |
| `Util/Guard` | no | `id(v) -> string?`, `bool(v)`, `int(v, min, max)`, `oneOf(v, list)` |
| `Util/RateLimiter` | no | `new(maxCalls, windowSeconds, clock?) -> { allow(key), forget(key) }` |
| `Services/Net` | yes | `start()`, `on(name, handler)`, `fire(player, name, ...)`, `fireAll(name, ...)`, `toast(player, text, kind?)` |
| `Services/DataService` | yes | `start()`, `get(player) -> PlayerProfile?`, `beforeRelease(fn)`, `takePendingOffline(player)`, `peekPendingOffline(player)`, `policy(player)`, `saves() -> boolean`, `loadedPlayers()`, signals `onLoaded`, `onReleasing` |
| `Services/ClockService` | yes | `start()`, `phase() -> ClockPhase`, `isNight()`, `phaseEndsAt() -> server time`, signal `changed(phase, endsAt)`, `debugSetPhase(phase)` (Studio only). Publishes `ReplicatedStorage.Clock` attributes `Phase`, `PhaseEndsAt` |
| `Services/PlotService` | yes | `start(world)`, `assign(player) -> Plot?`, `release(player)`, `get(player)`, `world()` |
| `Services/CafeService` | yes | `start()`, `buildState(player, profile) -> PlayerState`, `sync(player)`, `refreshPlot(player)`, `addCaughtCat(player, def, notify, profile?, charm?, rescued?) -> instance, isNew`, `setCarrying(player, catId?)`, `carrying(player)`, `consumeEquippedLure(player) -> LureDef?, reason?` |
| `Services/CatService` | yes | `start(world)`, `strayCount(area)`, `stuckCount()`, `debugSpawnStray(catId, area)` and `debugSpawnStuck(catId, rescueSpotId?)` (Studio only) |
| `Services/Debug` | yes, Studio only | `snapshot(player?)`, `setCoins(player?, n)`, `setLastTick(player?, secondsAgo)`, `resetProfile(player?)`, `giveCat(player?, catId, rescued?)`, `setUpgrade(player?, id, level)`, `spawnStray(catId, area?)`, `setPhase("day" or "night")`, `clock() -> { phase, endsAt, secondsLeft }`, `spawnStuckCat(catId, rescueSpotId?)`, `counts(area?) -> { strays, stuck }`, `dataSaves()` |

## Client (`src/client` -> `StarterPlayer.StarterPlayerScripts.Client`)

`Net` (`fire`, `on`), `Controllers/UIController` (`start()`, `state`, `ownDoor()`), `Controllers/WorldController` (`start()`), `Controllers/CustomerController` (`start()`). `UI/` belongs to the ui-designer.

## Remotes (server checks in `CafeService` and `CatService`)

As listed in `src/shared/Remotes.luau` and data-model section 15, plus `RequestSync` (client asks for a full sync) and `GrabResult(id, ok, reason, retry)` (server -> client, closes or keeps the catch or rescue prompt; `id` is a strayId or a rescueSpotId). `RescueBegin(rescueSpotId)` locks a stuck cat for 6 s; `RescueEnd(rescueSpotId)` is sent only after a full hold and the server checks the 4 s on its own clock (0.25 s latency allowance).
Rate limits: 10 calls per second per player per remote, 30 per second across all remotes; `GrabBegin` 1 per 2 s, `RescueBegin` 1 per s, `EquipBest`, `RequestSync`, `ClaimOffline` 1 per 2 s, `TutorialAdvance` 1 per s. Over the limit is dropped and logged.

## Test notes

- Design v0.2 specs (clock, net, waves, rescue) come from the QA thread on the same branch as the code.
- `Catalog.spec` "headline rarity" fails on the designer's kibble row (Common 70 vs alley 75): a design question, not code.
