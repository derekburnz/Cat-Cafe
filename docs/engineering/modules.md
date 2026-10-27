# Engineering module list (for QA and reviewers)

Updated 2026-10-26 (design v0.3 data, F22). Rojo project: `games/cat-cafe/default.project.json`. Sources under `games/cat-cafe/src/`.
Requires use Roblox instance paths (`script.Parent.X`, `ReplicatedStorage.Shared.X`).

## Pure shared modules (`src/shared` -> `ReplicatedStorage.Shared`)

| Module | Public functions (args -> returns) |
|---|---|
| `Config` | table of constants (data-model section 17) plus `Config.World` layout numbers |
| `Types` | types only: `Rarity` (Common to Mythical), `Area`, `Role` (`SpotType` is an alias), `CatchMethod`, `LureSource`, `RarityDef`, `CatDef` (`area`, `favoriteRole`), `UpgradeDef` (`requiresTier?`, `requiresTierAtLevel?`), `DecorDef` (`requiresTier?`), `LureDef` (`source`), `LureOdds` (five rarities), `AreaDef` (`tier`, `waveSize`, `rescueSpots`), `SpotDef` (`tier`), `TierDef`, `CatInstance` (`rescued?`, `name?`, `method?`), `CatView`, `BaitState`, `DealerState`, `Stats`, `PlayerProfile` (version 3), `PlayerState` (`tier`, `shinyCollection`), `CatchCircle`, `NetWindows`, `CatchWindows`, `CircleGrade` (`RingResult` is an alias while the UI uses it), `ClockPhase`, `ToastKind` |
| `Catalog` | `cats` (all 50; 3c provisional), `catsById`, `getCat(id) -> CatDef?`, `catModelName(id) -> string` (`maine_coon` -> `CatCafe_Cat_MaineCoon`), `catsByModelName`, `rarities`, `rarityOrder`, `rarityRank`, `spots` (ten role slots), `getSpot(id)`, `spotFurniture` (by role), `tiers`, `maxTier`, `getTier(n)`, `tierForLevel(upgradeId, level) -> tier?`, `upgrades` (`requiresTierAtLevel` filled from the tier caps), `getUpgrade(id)`, `decor`, `getDecor(id)`, `lures` (shop and dealer foods), `getLure(id)`, `dealerSlotWeights[tier]`, `areas`, `getArea(id)`, `lureSpotsPerArea`, `renamedUpgrades` (old id -> new id, gloves -> net) |
| `Economy` | `level(profile, id) -> number`, `tier(profile)`, `tierMultiplier(profile)`, `cafeMultiplier(profile)`, `catRate(instance)`, `variantMultiplier(variant)`, `incomePerSecond(profile)`, `settle(profile, now) -> earned`, `offlineGain(rate, lastSeen, now) -> amount, seconds`, `canAfford`, `trySpend -> boolean`, `credit`, `nextUpgradeCost -> number?`, `upgradeBlocker -> string?`, `decorBlocker -> string?`, `spotIsOpen`, `catOnSpot -> CatInstance?`, `seats`, `countsByCat` |
| `Circles` | `windows(netLevel) -> NetWindows`, `publicWindows(windows) -> CatchWindows`, `schedule(rarity, netLevel, now, roll) -> { CatchCircle }`, `target(circle)`, `deadline(circle, windows)`, `endsAt(circles, windows)`, `lockUntil(circles, windows)`, `latency(pingSeconds)` (half the ping, capped), `grade(errorSeconds, windows) -> CircleGrade, score`, `newAttempt(circles, windows) -> Attempt`, `expire(attempt, now) -> count`, `press(attempt, index, pressTime, now) -> CircleGrade?` (nil = ignored), `isDone(attempt)`, `chance(scores)` (mean), `perfectCount(attempt)`, `pushHistory(history, perfect)`, `looksScripted(history)` (over 95% Perfect in the last 50) |
| `Catching` | `succeeds(chance, roll)`, `fleesOnFail(rarity)`, `pickRarity(odds, roll)` (scaled by the odds total), `rescueOdds(odds) -> odds` (every non-Common weight doubled, back to 100), `candidates(rarity, area)`, `pickCat(rarity, area, roll)`, `rarityAtLeast(rarity, min)`, `percentText(chance)` |
| `CatStats` | `level`, `xp`, `charm`, `rollCharm(roll1, roll2)`, `charmMultiplier`, `levelMultiplier`, `rescuedMultiplier(rescued?)`, `variantMultiplier`, `stars`, `starsText`, `xpToNext`, `xpForLevel`, `addXp(instance, amount)`, `rating(instance)` (shiny 1.5x; the rescued multiplier is 1.0 since v0.3), `maxRating(catId)`, `isBetter(a, b)`, `newInstance(uid, catId, now, charm?)`, `view(instance) -> CatView`, `shortText` |
| `EquipBest` | `value(instance, spot)`, `openSpots(profile)`, `plan(profile) -> Plan`, `apply(profile, plan) -> moved`, `isOptimal(profile, plan)` |
| `Clock` | `phaseAt(secondsSinceServerStart) -> ClockPhase, secondsLeft`, `startOf(phase) -> seconds` |
| `ProfileSchema` | `VERSION` (3), `template(now) -> PlayerProfile`, `versionOf(raw) -> number`, `isNewerThanCode(raw) -> boolean`, `migrate(raw, now) -> PlayerProfile` (2 to 3: Tier 1, refunds at the frozen v2 prices, roles refilled by Equip Best, `method` set; carries a saved gloves level to net), `catCount`, `collectionCount` |
| `Signal` | `Signal.new<T...>() -> { Connect, Once, Fire, DisconnectAll }` |
| `Remotes` | `ClientToServer`, `ServerToClient` name lists; `folder()`, `event(name)` touch ReplicatedStorage |
| `Mover` | needs RunService: `walkTo(model, target, speed, alive) -> boolean`, `face(model, target)` |

## Server (`src/server` -> `ServerScriptService.Server`)

| Module | Needs Roblox | Public |
|---|---|---|
| `World/Layout` | no (requires Config) | `plotPlacement(index) -> {x, z, side}`, `plot` (door, entry, sign, counter, espresso, spots, spotFurniture, decorAnchors, tables, seatOffsets), `alley` and `park` (spawnPoints, lureSpots, rescueSpots, props with an optional `y` for wall props), `stuckPoses` (prop name to the stuck cat's pose in prop space as the manifest's 12 CFrame numbers), `playerSpawn` |
| `World/Placeholders` | yes | `names() -> {string}`, `build(name) -> Model?`, `cat(def)`, `customer(variant)` |
| `World/AssetRegistry` | yes | `folder()`, `ensurePlaceholders() -> count`, `has(name)`, `clone(name) -> Model` |
| `World/WorldBuilder` | yes | `build() -> World { folder, plots, areas, gate }`; each area has `spawnPoints`, `lureSpots` and `rescueSpots` (anchors tagged `RescueSpot` with `Area`, `RescueSpotId`, `Occupied`, `LockedBy`) |
| `Util/Guard` | no | `id(v) -> string?`, `bool(v)`, `int(v, min, max)`, `oneOf(v, list)` |
| `Util/RateLimiter` | no | `new(maxCalls, windowSeconds, clock?) -> { allow(key), forget(key) }` |
| `Services/Net` | yes | `start()`, `on(name, handler)`, `fire(player, name, ...)`, `fireAll(name, ...)`, `toast(player, text, kind?)` |
| `Services/DataService` | yes | `start()`, `get(player) -> PlayerProfile?`, `beforeRelease(fn)`, `takePendingOffline(player)`, `peekPendingOffline(player)`, `policy(player)`, `saves() -> boolean`, `loadedPlayers()`, `debugSetAway(player, seconds) -> amount`, signals `onLoaded`, `onReleasing`. Refuses (kicks, saves nothing new) a profile whose version is newer than `ProfileSchema.VERSION` |
| `Services/ClockService` | yes | `start()`, `phase() -> ClockPhase`, `isNight()`, `phaseEndsAt() -> server time`, signal `changed(phase, endsAt)`, `debugSetPhase(phase)` (Studio only). Publishes `ReplicatedStorage.Clock` attributes `Phase`, `PhaseEndsAt` |
| `Services/PlotService` | yes | `start(world)`, `assign(player) -> Plot?`, `release(player)`, `get(player)`, `world()` |
| `Services/CafeService` | yes | `start()`, `buildState(player, profile) -> PlayerState`, `sync(player)`, `refreshPlot(player)`, `addCaughtCat(player, def, notify, profile?, charm?, method?, variant?) -> instance, isNew` (method "net", "rescue" or "bait"), `setCarrying(player, catId?)`, `carrying(player)`, `consumeEquippedLure(player) -> LureDef?, reason?` |
| `Services/CatService` | yes | `start(world)`, `strayCount(area)`, `inCatch(player)`, `isCarrying(player)`, `startCarry(player, def, method, charm, variant)`, `busyReason(player) -> string?`, `strayFolder()`, `setRescueCheck(fn)` (RescueService installs it; avoids a require cycle), `debugSpawnStray(catId, area)` (Studio only) |
| `Services/RescueService` | yes | `start(world)`: stuck cats on the traps at night and the rescue minigames (F27). `stuckCount()`, `debugSpawnStuck(catId, rescueSpotId?, shiny?)` (Studio only). Rules in `shared/Rescue`, marker maths in `shared/RescueMarker` |
| `Services/Debug` | yes, Studio only | `snapshot(player?)`, `setCoins(player?, n)`, `setLastTick(player?, secondsAgo)`, `resetProfile(player?)`, `giveCat(player?, catId, rescued?)`, `setUpgrade(player?, id, level)`, `setTier(player?, tier)`, `giveLure(player?, lureId, count?)`, `setLastSeen(player?, secondsAgo) -> amount`, `setSaveVersion(player?, version)`, `spawnStray(catId, area?)`, `setPhase("day" or "night")`, `clock() -> { phase, endsAt, secondsLeft }`, `spawnStuckCat(catId, rescueSpotId?, shiny?)`, `counts(area?) -> { strays, stuck }`, `dataSaves()` |

## Client (`src/client` -> `StarterPlayer.StarterPlayerScripts.Client`)

`Net` (`fire`, `on`), `Controllers/UIController` (`start()`, `state`, `ownDoor()`), `Controllers/WorldController` (`start()`), `Controllers/CustomerController` (`start()`). `UI/` belongs to the ui-designer.

## Remotes (server checks in `CafeService` and `CatService`)

As listed in `src/shared/Remotes.luau` and data-model section 15, plus `RequestSync` (client asks for a full sync) and `GrabResult(id, ok, reason, retry)` (server -> client, closes or keeps the catch or rescue prompt; `id` is a strayId or a rescueSpotId). `RescueBegin(rescueSpotId)` locks a stuck cat to one player and answers `RescueChallenge(rescueSpotId, challenge)` (kind `bar` or `shake_catch`; a tree sends a second one of kind `circle` after its shakes). `RescuePress(rescueSpotId)` carries no time: the server stamps it on arrival less half the ping and answers `RescueResult(rescueSpotId, hits, pawsLeft, done, success)`. `RescueCancel(rescueSpotId)` gives up. After a failed attempt others wait RescueRetrySeconds (3) and the player who failed RescueSelfRetrySeconds (6).
Rate limits: 10 calls per second per player per remote, 30 per second across all remotes; `GrabBegin` 1 per 2 s, `RescueBegin` 1 per s, `RescueCancel` 1 per s, `EquipBest`, `RequestSync`, `ClaimOffline` 1 per 2 s, `TutorialAdvance` 1 per s. Over the limit is dropped and logged.

## Test notes

- Design v0.2 specs (clock, net, waves, rescue) come from the QA thread on the same branch as the code.
- `Catalog.spec` "headline rarity" fails on the designer's kibble row (Common 70 vs alley 75): a design question, not code.
