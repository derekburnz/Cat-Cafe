# Cat Cafe UI contract

Owner: UI thread ("Design cat cafe UI"). v3, updated 2026-10-26 (v1 2026-10-25, v2 earlier on 2026-10-26).
v3 changes: ring bands come from shared Config and a full hold sends no GrabEnd (designer, data-model section 10); catalog types are re-exported from shared Types so the controller passes the catalog with no cast (reviewer S9); `equipBest` event and per-cat stats (cat stats thread); mockup page built.
Readers: engineer (client controller), designer (catalog fields), reviewer, QA.
Code: `games/cat-cafe/src/client/UI/` (20 Luau files, StyLua-formatted to the repo's stylua.toml).
Mockups: `docs/concepts/cat-cafe/ui/index.html`.

## Ownership and file boundaries

- The UI thread owns everything under `games/cat-cafe/src/client/UI/`. Nobody else edits there; ask the UI thread instead.
- Outside its own folder the UI requires only `ReplicatedStorage.Shared.Types` (type re-exports), `Shared.Config` (ring timing) and, in Demo only, `Shared.Catalog`. It does not touch RemoteEvents, DataStores, workspace cats or player data.
- The engineer owns the client controller that requires `UI`, feeds it state, and forwards UI intents to the server over remotes.
- Catalog data (cats, upgrades, decor, lures, spots) is passed in at `UI.init`. The UI hardcodes nothing about the game's content.
- Field names match `src/shared/Types.luau` (engineer) and `data-model.md` (designer). Where the engineer's `PlayerState` has extras (`cats`, `collection`, `carrying`, `tutorialStep`), the UI reads them when present.

## Where it lives in Rojo

```
games/cat-cafe/src/client/UI/      -> StarterPlayer.StarterPlayerScripts.Client.UI  (ModuleScript via init.luau)
  init.luau          public API (everything below)
  Types.luau         Luau types for state and events; catalog types re-exported from src/shared/Types.luau
  Theme.luau         Cozy Cream tokens (final, Derek's pick), fonts, sizes, rarity colors
  Scale.luau         viewport-driven UIScale, touch detection
  Demo.luau          the shared Catalog plus a pretend server: UI.demo() shows the whole UI in Studio with no backend
  Components/        Create, Button, Panel, Modal, Tween, Format, Signal, WorldMarker
  Screens/           HUD, UpgradeShop, DecorShop, CatCollection (Book + Cat room tabs), CatchPrompt (timing ring), Toasts, Popups
```

Pure Luau, no UI framework, no Wally packages. Instances are built in code (no .rbxm), so Rojo syncs the whole UI from files.

## How the engineer uses it

```lua
local UI = require(script.Parent.UI)

UI.init({
    catalog = {                     -- the shared Catalog's own tables, no cast: UI.Types re-exports the shared types
        cats = Catalog.cats,          -- {CatDef}
        upgrades = Catalog.upgrades,  -- {UpgradeDef}
        decor = Catalog.decor,        -- {DecorDef}
        lures = Catalog.lures,        -- {LureDef} with odds
        spots = Catalog.spots,        -- {SpotDef}, needed by the cat room's Place picker
    },
    keybinds = true,  -- U upgrades, B decor, C collection, F lure picker, gamepad B closes (default true)
})

-- push state whenever ProfileSync arrives (partial tables are fine, they merge at the top level)
UI.update({ money = 8420, incomePerSecond = 12 })
UI.update({ cats = profile.cats, collection = profile.collection })   -- catsOwned is derived from cats

-- intents: the controller forwards, the server validates
UI.events.buyUpgrade:Connect(function(upgradeId) Remotes.BuyUpgrade:FireServer(upgradeId) end)
UI.events.placeCat:Connect(function(uid, spotId) Remotes.PlaceCat:FireServer(uid, spotId) end)
UI.events.grabBegan:Connect(function(strayId) Remotes.GrabBegin:FireServer(strayId) end)
UI.events.grabEnded:Connect(function(strayId) Remotes.GrabEnd:FireServer(strayId) end)  -- the server scores the hold time itself

-- catch flow: one call and every stray's custom ProximityPrompt is drawn by the UI
UI.catch.bindProximityPrompts()
```

The UI is a view. It renders what `UI.update` gives it and raises events for what the player tapped. It never changes money or ownership. If the server rejects a purchase, call `UI.toast("Not enough coins", "warn")` and push the real state.

## Public API (game -> UI)

| Function | Purpose |
|---|---|
| `UI.init(config)` | Build all ScreenGuis under PlayerGui. Call once. Returns `UI`. |
| `UI.update(partialState)` | Merge into current state and re-render. Derives `cafeLevel` from `upgradeLevels.cafe_level`, `tables` from `upgradeLevels.tables`, `catsOwned` from `cats` when those are absent. |
| `UI.getState()` | Shallow copy of the current UI state. |
| `UI.setCatalog(catalog)` | Swap the catalog at runtime (hot reload, tests). |
| `UI.open(name)` / `UI.close()` / `UI.isOpen()` | Modal screens: `"Upgrades"`, `"Decor"`, `"Collection"`. One open at a time. |
| `UI.openCatRoom()` | Opens Collection on the Cat room tab (tutorial step 3). |
| `UI.toast(text, kind?)` | Top-centre message. kind: `"info"` (default), `"good"`, `"warn"`, `"announce"` (gold). |
| `UI.announce(text)` | Server-wide catch announcement (gold toast). |
| `UI.showCatFound(catId, isNew?)` | Celebration popup with rarity banner, sparkles, name, rate. Auto-closes in 5 s. |
| `UI.showOfflineEarnings(amount, seconds)` | "While you were away" popup with Claim, fires `events.claimOffline`. |
| `UI.floatText(worldPosition, text, color?)` | Rising "+$8" at a world point (customers' coin pops). |
| `UI.setCarrying(info?)` | `info = { catId, catName?, rarity?, door: BasePart? }`. Bottom-centre banner "Carrying Void" plus a world marker with distance over the door. `nil` clears. |
| `UI.tutorial.show(text, target?, markerLabel?)` / `UI.tutorial.hide()` | One-line gold strip at the bottom and, with a target (BasePart, Attachment or Vector3), a marker in the world. |
| `UI.setVisible(bool)` | Hide the whole UI for cutscenes or screenshots. |
| `UI.destroy()` | Tear everything down and disconnect every connection. |
| `UI.demo()` | Runs Demo.luau. Returns a stop function. Not for production. |

### Catch prompt and timing ring (`UI.catch`)

| Function | Purpose |
|---|---|
| `bindProximityPrompts()` | Recommended. Watches `ProximityPromptService`. Any prompt with `Style = Custom` and a `CatId` attribute (on the prompt, its Model or its parent) gets the UI. Reads `StrayId`, `CatName`, `Rarity`, `Stars`, `Charm` the same way, falling back to the catalog by `CatId`. Hold begin starts the ring with the prompt's `HoldDuration` and fires `events.grabBegan`. A release fires `events.grabEnded(strayId, ringHint, catId)` once. A hold that runs its full length fires nothing: the ring shows "Missed" and the UI waits for the controller's `catch.fail` or `showCatFound` (the server resolves the attempt itself about 0.25 s later). On touch, the big GRAB button calls `prompt:InputHoldBegin/End`, so the server sees an ordinary hold. |
| `unbindProximityPrompts()` | Stop watching. |
| `show(info)` | Manual use. `info = { catId?, strayId?, catName?, rarity?, holdDuration?, actionText?, keyCode?, stars?, charm? }`. |
| `startRing(config?)` | `config = { duration?, goodBand?, perfectBand? }`. The outer ring shrinks from 1 to 0 over `duration` (default `Config.GrabHoldSeconds`, 1.5 s). The band is the end of the shrink: good is the last `Config.RingGoodWindow` s (0.80, ring scale 0 to 0.533), perfect the last `Config.RingPerfectWindow` s (0.30, scale 0 to 0.2). Pass bands only to experiment. |
| `stopRing()` | Call on release. Shows "Perfect!", "Good" or "Too early" from where the ring was and returns `"perfect"`, `"good"` or `"miss"` as a hint. The server scores the real time between GrabBegin and GrabEnd (release 1.20 to 1.50 s perfect, 0.70 to 1.50 s good), so the hint decides nothing. |
| `expire()` | Call when a manual hold runs its full length with no release. Miss flash, nothing sent. `bindProximityPrompts` does this itself on `PromptTriggered`. |
| `fail(reason?, retry?)` | `retry = true` keeps the prompt open with "Missed, try again" (Commons, lured strays). Otherwise it flashes "It got away" and hides. |
| `success(catId)` is not needed: call `UI.showCatFound` when CatCaught arrives. | |
| `hide()` / `setProgress(alpha)` / `getActivePrompt()` | Utilities. |

Set each stray prompt's `HoldDuration` to `Config.GrabHoldSeconds` (1.5). Holding the whole duration triggers the prompt: the UI shows "Missed", sends no GrabEnd (a GrabEnd then would score as a 1.5 s release) and waits for the server's result. The ring is a bonus, never a gate: a ring miss still rolls the catch chance.

## Events (UI -> game), all `Signal` with `:Connect(fn)` returning a connection with `:Disconnect()`

| Event | Args | Fired when |
|---|---|---|
| `buyUpgrade` | `upgradeId` | Buy pressed (UI only enables it when affordable, not maxed, cafe gate met) |
| `buyDecor` | `decorId` | Buy pressed in Decor |
| `toggleDecor` | `decorId, placed` | Place / Remove pressed on an owned decor item |
| `buyLure` | `lureId` | Buy pressed in the lure picker (odds are on screen before the button) |
| `equipLure` | `lureId` | Equip pressed |
| `placeCat` | `uid, spotId` | A free, open spot picked for a cat in the Cat room |
| `unplaceCat` | `uid` | Rest pressed on a placed cat |
| `sellCat` | `uid` | Sell confirmed. Rare and above ask twice: Sell turns into "Sell $150", Rest turns into an equal-sized Cancel. |
| `equipBest` | none | "Equip best" pressed at the top of the Cat room: the server places the highest-rated cats on the open spots |
| `claimOffline` | none | Claim pressed on the offline popup |
| `grabBegan` | `strayId, catId` | Hold began on a bound stray prompt |
| `grabEnded` | `strayId, ringHint, catId` | The player released during the hold. `ringHint` is the client's `perfect`, `good` or `miss` for feedback only; the server scores timing. Not fired when the hold runs out. |
| `screenOpened` | `name or nil` | Modal opened or closed |

## State shape (`Types.PlayerState`)

```lua
{
    money: number,
    incomePerSecond: number,
    cafeLevel: number,                       -- or send upgradeLevels.cafe_level and the UI derives it
    cafeProgress: number?, cafeProgressText: string?,   -- unused in the slice (cafe level is bought)
    tables: number?, customers: number?,
    catsOwned: { [catId]: { count } },       -- derived from cats when cats is sent
    upgradeLevels: { [upgradeId]: number },
    decorOwned: { [decorId]: boolean }, decorPlaced: { [decorId]: boolean },
    lures: { [lureId]: number }, equippedLure: string?,
    -- engineer extras the UI uses when present
    cats: { [uid]: { uid, catId, variant?, caughtAt?, spotId?,       -- enables the Cat room tab
                     level?, xp?, xpToNext?, charm?, stars?, rating? } }, -- cat stats thread; shown when present
    collection: { [catId]: firstCaughtAt },                        -- drives "?" silhouettes and the 7 / 12 count
    carrying: string?, tutorialStep: number?,
}
```

## Catalog shapes (re-exported from `src/shared/Types.luau`)

`UI.Types.CatDef`, `UpgradeDef`, `DecorDef`, `LureDef`, `SpotDef`, `LureOdds`, `Rarity`, `Area`, `SpotType` and `RingResult` are the shared types, so `Catalog.cats` and friends pass straight into `UI.init`. Fields the UI reads:

```lua
CatDef     : id, name, rarity, incomePerSecond, area, favoriteSpot, description, color {r,g,b}  (placeholder body colour until renders exist)
UpgradeDef : id, name, description, maxLevel, costs {n}, startLevel, requiresCafeLevel?, requiresCafeLevelAtLevel? { [level] = cafe }
DecorDef   : id, name, cost, category, effect, description, requiresCafeLevel?   (asset is the 3D model; the card draws a lettered tile)
LureDef    : id, name, cost, attracts, description, odds { Common, Rare, Epic, Legendary }  -- percentages, sum 100
SpotDef    : id, spotType, cafeLevel
```

`CatInstance`, `PlayerState` and `PartialState` stay the UI's own (optional fields for the cat stats extras); the controller passes `cats` with a cast because Luau table fields are invariant.

`costs[n]` is the price of level n. Starting levels (`cafe_level` 1, `espresso` 1) mean `costs[1]` is never offered. Odds are printed on every lure row as "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.5% Legendary" and a labelled Details button expands the per-cat split per area, computed from the catalog (every cat of a rarity in an area has the same chance).

## Mobile and scaling rules the UI follows

- One `UIScale` per ScreenGui root, driven by viewport: design size 1280x720, `scale = clamp(min(w/1280, h/720), 0.6, 1.3)`, floor 0.75 on touch. The root's Size is `1/scale` so edge-anchored panels stay on the edges.
- Everything is laid out in design pixels under that scale; no raw Offset layouts that ignore it.
- Touch targets at least 44x44 design px. Hover effects only with a mouse. Keyboard hints hidden on touch.
- `ScreenInsets = CoreUISafeInsets`: the HUD keeps clear of the Roblox top bar.
- Modals are 92% x 86% of the viewport with a UISizeConstraint cap; lists scroll with `AutomaticCanvasSize`.
- Money uses `Format.money` ("$8,420", "$1.2M") so it never overflows.
- DisplayOrder: HUD 10, catch prompt 15, modals 20, toasts 30, popups 40.

## Shop rules followed (growth thread, docs/growth/monetization.md section 6)

Odds visible before any purchase and the detail control is labelled "Details", not an icon. Buy and Equip (and Sell and Cancel) are the same size and contrast. No timers anywhere in the shop.

## Names agreed

- Screens: `Upgrades`, `Decor`, `Collection`. Rarities exactly: `Common`, `Rare`, `Epic`, `Legendary`, `Secret`.
- Stray prompt attributes (on the model, data-model section 13): `StrayId`, `CatId`, `CatName`, `Rarity`, plus `Stars` and `Charm` from the cat stats thread; prompt `Style = Custom`.
- Ring timing constants live only in `Shared.Config`: `GrabHoldSeconds`, `RingGoodWindow`, `RingPerfectWindow`. The UI derives its bands from them.
- Currency is coins shown as `$` (`Theme.currencySymbol`).

## Not in scope for the UI thread, and space left for later

Remotes, validation, rate limits, data saving, cat AI, decor placement in the world, sounds (`Theme.sounds.*` hooks are nil), localization (strings sit in the screens, ready to pull out). Planned screens with room reserved: fast travel buttons (F19, HUD left stack under the menu, greyed while carrying), leaderboards and settings (P2, modal screens), day and night chip and event banner (HUD top corners, post-slice).

## Check gate status

StyLua: formatted and parse-clean (20 files). QA's cloud checker (`tools/cloudcheck/analyze.mjs`, strict Luau with the Roblox definitions) reports 0 type errors under `src/client/UI`. `luau-lsp analyze` and `selene` with the real sourcemap have not run yet; first person to run `check.sh` or `check.ps1` on a PC, please send the UI thread the output.

## Mockups

`docs/concepts/cat-cafe/ui/index.html`: HUD at 1280x720, phone at 812x375 with the catch ring and GRAB button, carry banner, Upgrades, Decor, Collection (Book and Cat room tabs), lure picker with odds and Details, popups and toasts, tokens and rules. Built from the asset thread's cat renders.
