# Cat Cafe UI contract

Owner: UI thread ("Design cat cafe UI"). Last updated 2026-10-25.
Readers: engineer thread (client controller), designer thread (catalog fields), reviewer, QA.

## Ownership and file boundaries

- The UI thread owns everything under `games/cat-cafe/src/client/UI/`. Nobody else edits there; ask the UI thread instead.
- The UI never requires anything outside its own folder. It does not touch RemoteEvents, DataStores, workspace cats or player data.
- The engineer owns the client controller that requires `UI`, feeds it state, and forwards UI intents to the server over remotes.
- Catalog data (cats, upgrades, decor, lures) is passed in by the engineer at `UI.init`. The UI hardcodes nothing about the game's content.

## Where it lives in Rojo

```
games/cat-cafe/src/client/UI/        -> StarterPlayer.StarterPlayerScripts.<Client>.UI  (ModuleScript via init.luau)
  init.luau            public API (everything below)
  Types.luau           exported Luau types for catalog, state, events
  Theme.luau           colors, fonts, sizes, rarity colors ("Cozy Cream" default)
  Scale.luau           viewport-driven UIScale, touch detection, safe insets
  Components/          Create, Button, Panel, Modal, Tween, Format, Signal
  Screens/             HUD, UpgradeShop, DecorShop, CatCollection, CatchPrompt, Toasts, CatFoundPopup, OfflineEarnings
  Demo.luau            fake catalog + ticking state so the UI can be seen in Studio with no server code
```

Pure Luau, no UI framework, no Wally packages. Instances are built in code (no .rbxm), so Rojo syncs the whole UI from files.

## How the engineer uses it

```lua
local UI = require(script.Parent.UI)   -- adjust to where the controller sits

UI.init({
    catalog = {
        cats = CATS,          -- {CatDef}   see Types
        upgrades = UPGRADES,  -- {UpgradeDef}
        decor = DECOR,        -- {DecorDef}
        lures = LURES,        -- {LureDef}
    },
    keybinds = true,          -- U upgrades, B decor, C collection, Esc close (optional, default true)
})

-- push state whenever the server replicates a change (partial tables are fine, they merge)
UI.update({ money = 8420, incomePerSecond = 12 })
UI.update({ catsOwned = { tabby_waffles = { count = 1 } } })

-- listen for intents; the controller validates nothing here, the server does
UI.events.buyUpgrade:Connect(function(upgradeId: string) BuyUpgradeRemote:FireServer(upgradeId) end)
UI.events.buyDecor:Connect(function(decorId) ... end)
UI.events.toggleDecor:Connect(function(decorId, placed: boolean) ... end)
UI.events.buyLure:Connect(function(lureId) ... end)
UI.events.equipLure:Connect(function(lureId) ... end)
UI.events.claimOffline:Connect(function() ... end)
UI.events.screenOpened:Connect(function(name) ... end)   -- "Upgrades" | "Decor" | "Collection" | nil (closed)
```

The UI is a view. It renders what `UI.update` gives it and raises events for what the player tapped. It never changes money or ownership on its own. If the server rejects a purchase, call `UI.toast("Not enough coins", "warn")` and push the real state.

## Public API (game -> UI)

| Function | Purpose |
|---|---|
| `UI.init(config)` | Build all ScreenGuis under PlayerGui. Call once. Returns `UI`. |
| `UI.update(partialState)` | Merge into current state and re-render affected screens. Safe to call every frame for money, but prefer on change. |
| `UI.getState()` | Read-only copy of current UI state. |
| `UI.open(screenName)` / `UI.close()` / `UI.isOpen()` | Modal screens: `"Upgrades"`, `"Decor"`, `"Collection"`. Only one open at a time. |
| `UI.toast(text, kind?)` | Small message top-centre. kind: `"info"` (default), `"good"`, `"warn"`. |
| `UI.showCatFound(catId)` | Celebration popup with rarity colour and name. Pauses nothing. |
| `UI.showOfflineEarnings(amount, seconds)` | "While you were away" popup with a Claim button, fires `events.claimOffline`. |
| `UI.floatText(worldPosition: Vector3, text, color?)` | Rising "+$8" text at a world point (BillboardGui, auto-destroys). |
| `UI.setVisible(bool)` | Hide the whole UI for cutscenes or screenshots. |
| `UI.catch.show(info)` | Show grab prompt. `info = { catName, rarity, holdDuration, actionText?, keyCode? }`. |
| `UI.catch.setProgress(alpha)` | 0..1 fill of the timing ring while holding. |
| `UI.catch.hide()` / `UI.catch.fail(reason)` / `UI.catch.success(catId)` | Close the prompt. `fail` shows a short "bolted" flash, `success` calls `showCatFound`. |
| `UI.catch.bindProximityPrompts()` | Optional. Drives the prompt UI from any `ProximityPrompt` with `Style = Custom` and attribute `CatId` (plus optional `CatName`, `Rarity`). Handles hold begin/end, progress, and the mobile GRAB button. |
| `UI.demo()` | Runs `Demo.luau`: fake catalog, money ticking, random cat found. For looking at the UI in Studio before the server exists. Remove from production. |

## Events (UI -> game), all `Signal` with `:Connect(fn)` returning a connection with `:Disconnect()`

| Event | Args | Fired when |
|---|---|---|
| `buyUpgrade` | `upgradeId` | Buy button pressed in Upgrades (only when affordable and not maxed, per UI state) |
| `buyDecor` | `decorId` | Buy pressed in Decor |
| `toggleDecor` | `decorId, placed` | Place / Remove pressed on an owned decor item |
| `buyLure` | `lureId` | Buy pressed in the lure strip of the catch prompt or HUD |
| `equipLure` | `lureId` | Player selects which lure to use next |
| `claimOffline` | none | Claim pressed on the offline earnings popup |
| `screenOpened` | `name or nil` | Modal opened or closed |
| `catchHoldBegan` / `catchHoldEnded` | none | Only when using the UI's own mobile GRAB button without `bindProximityPrompts` |

## State shape (`Types.PlayerState`)

```lua
{
    money: number,                 -- coins
    incomePerSecond: number,
    cafeLevel: number,
    cafeProgress: number?,         -- 0..1 toward next level (hidden if nil)
    cafeProgressText: string?,     -- e.g. "3 / 6 upgrades"  (hidden if nil)
    tables: number?, customers: number?,
    catsOwned: { [catId]: { count: number } },
    upgradeLevels: { [upgradeId]: number },   -- 0 or missing = not bought
    decorOwned: { [decorId]: boolean },
    decorPlaced: { [decorId]: boolean },
    lures: { [lureId]: number },               -- count held
    equippedLure: string?,
}
```

## Catalog shapes (`Types.*Def`)

```lua
CatDef     = { id, name, rarity: "Common"|"Rare"|"Epic"|"Legendary"|"Secret", incomePerSecond: number,
               area: string?, favoriteSpot: string?, description: string?, imageId: string? }
UpgradeDef = { id, name, description, maxLevel: number, costs: {number},     -- costs[level+1] = cost of next level
               requiresCafeLevel: number?, icon: string? }
DecorDef   = { id, name, cost: number, category: string, effect: string?, description: string?,
               requiresCafeLevel: number?, imageId: string? }
LureDef    = { id, name, cost: number, attracts: Rarity, description: string? }
```

Ids are snake_case strings and double as sort keys only when the catalog array order is not given; the UI shows arrays in the order received.

## Mobile and scaling rules the UI follows

- One `UIScale` per ScreenGui, driven by viewport: design size 1280x720, `scale = clamp(min(w/1280, h/720), 0.6, 1.3)`, with a floor of 0.75 on touch devices.
- All sizes are Scale-based or Offset-under-UIScale. No raw Offset layouts that ignore the scale.
- Touch targets at least 44x44 design px. Hover effects skipped on touch.
- `ScreenInsets = CoreUISafeInsets`, HUD keeps clear of the Roblox top bar and the chat button.
- Modals are max 92% of viewport width and 86% height with a UISizeConstraint, lists scroll with `AutomaticCanvasSize`.
- Money text uses `Format.money` ("$8,420", "$1.2M") so it never overflows its panel.

## Names to agree on (engineer, designer)

- Screen names: `Upgrades`, `Decor`, `Collection`.
- Rarity strings exactly: `Common`, `Rare`, `Epic`, `Legendary`, `Secret`.
- ProximityPrompt attributes on catchable cats: `CatId` (string, required), `CatName`, `Rarity` (strings, optional; the UI falls back to the catalog by `CatId`).
- Currency is "coins" shown with a `$`. If the designer renames it, change `Theme.currencySymbol` only.

## Not in scope for the UI thread

Remotes, validation, rate limits, data saving, cat AI, placement of decor in the world, sounds (hooks exist: `Theme.sounds.click` etc. are nil by default), localization (strings sit in one table per screen, ready for it).
