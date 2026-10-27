# Cat Cafe UI contract

Owner: UI thread ("Design cat cafe UI"). v5, updated 2026-10-26 (v1 2026-10-25, v2 to v4.1 earlier on 2026-10-26).
v5 (design v0.3, features.md section 6): data v3 (tiers, roles, Mythical, five-rarity odds), closing circles for the net, press prompts, rank up card and tier pill, "Tips 60%" at night. Everything v0.3 is in the section "Design v0.3 (v5)" below, with each row marked built or planned. The v0.2 hold ring is gone with F26; the rescue hold bar stays until the rescue minigames.
v4.1: `catch.fail` closes a hold that is still down and resets the rescue bar, so a server rejection of `GrabBegin` or `RescueBegin` never shows "Missed" or "Rescued!" and sends nothing more.
v4 changes (gdd.md v0.2): day and night clock chip (`UI.clock`, F20), the catch tool is the Net so the prompt copy is a swing, and the 4 s Rescue hold bar with `rescueBegan` / `rescueEnded` (F21). The `gloves` upgrade is now `net`; the UI reads it from the catalog, nothing to change.
v3 changes: ring bands come from shared Config and a full hold sends no GrabEnd (designer, data-model section 10); catalog types are re-exported from shared Types so the controller passes the catalog with no cast (reviewer S9); `equipBest` event and per-cat stats (cat stats thread); mockup page built.
Readers: engineer (client controller), designer (catalog fields), reviewer, QA.
Code: `games/cat-cafe/src/client/UI/` (20 Luau files, StyLua-formatted to the repo's stylua.toml).
Mockups: `docs/concepts/cat-cafe/ui/index.html`.

## Ownership and file boundaries

- The UI thread owns everything under `games/cat-cafe/src/client/UI/`. Nobody else edits there; ask the UI thread instead.
- Outside its own folder the UI requires only `ReplicatedStorage.Shared.Types` (type re-exports), `Shared.Config` (catch and rescue timing) and, in Demo only, `Shared.Catalog`. It does not touch RemoteEvents, DataStores, workspace cats or player data.
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
  Screens/           HUD, UpgradeShop, DecorShop, CatCollection (Book + Cat room tabs), CatchPrompt (prompt card and rescue bar), CatchCircles, RankUp, Toasts, Popups
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
        spots = Catalog.spots,        -- {SpotDef} role slots, needed by the cat room's Assign picker
        tiers = Catalog.tiers,        -- {TierDef}, v0.3: tier names, gates and the rank up card
        areas = Catalog.areas,        -- {AreaDef}, v0.3: the bait odds split pools the areas the tier has opened
    },
    keybinds = true,  -- U upgrades, B decor, C collection, F lure picker, gamepad B closes (default true)
    playSound = Audio.play,  -- optional; the UI plays its own cues through it and stays silent without it
})

-- push state whenever ProfileSync arrives (partial tables are fine, they merge at the top level)
UI.update({ money = 8420, incomePerSecond = 12 })
UI.update({ cats = profile.cats, collection = profile.collection })   -- catsOwned is derived from cats

-- intents: the controller forwards, the server validates
UI.events.buyUpgrade:Connect(function(upgradeId) Remotes.BuyUpgrade:FireServer(upgradeId) end)
UI.events.placeCat:Connect(function(uid, spotId) Remotes.PlaceCat:FireServer(uid, spotId) end)
UI.events.grabBegan:Connect(function(strayId) Remotes.GrabBegin:FireServer(strayId) end)
UI.events.catchPressed:Connect(function(strayId, index) Remotes.CatchPress:FireServer(strayId, index) end)  -- the server stamps the time

-- catch flow: one call and every stray's custom ProximityPrompt is drawn by the UI
UI.catch.bindProximityPrompts()
```

The UI is a view. It renders what `UI.update` gives it and raises events for what the player tapped. It never changes money or ownership. If the server rejects a purchase, call `UI.toast("Not enough coins", "warn")` and push the real state.

## Public API (game -> UI)

| Function | Purpose |
|---|---|
| `UI.init(config)` | Build all ScreenGuis under PlayerGui. Call once. Returns `UI`. |
| `UI.update(partialState)` | Merge into current state and re-render. Derives `tables` from `upgradeLevels.tables` and `catsOwned` from `cats` when those are absent. |
| `UI.getState()` | Shallow copy of the current UI state. |
| `UI.setCatalog(catalog)` | Swap the catalog at runtime (hot reload, tests). |
| `UI.open(name)` / `UI.close()` / `UI.isOpen()` | Modal screens: `"Upgrades"`, `"Decor"`, `"Collection"`. One open at a time. |
| `UI.openCatRoom()` | Opens Collection on the Cat room tab (tutorial step 3). |
| `UI.toast(text, kind?)` | Top-centre message. kind: `"info"` (default), `"good"`, `"warn"`, `"announce"` (gold). |
| `UI.announce(text, rarity?)` | Server-wide catch shout-out, on the rarity's colour for 4 s. Pass the rarity from `Announce` once it carries one; without it the last rarity named as a whole word in the text decides, so a DisplayName like "EpicGamer" does not colour it. Silent, since Audio plays the shout-out sting from the remote. |
| `UI.showCatFound(catId, isNew?, extra?)` | The hatch style reveal (F39 P1): rays in the rarity colour, the cat's own model from `ReplicatedStorage.Assets` popping in and swaying (its initial when the model is missing), a NEW sticker when `isNew`, charm stars filling one by one and "Purrfect catch! Charm +N". `extra = { stars?, shiny?, charmGain? }`; stars and shiny fall back to the newest copy of the cat in `state.cats` from the last 30 s, and the stars row hides without them. Pass `charmGain` from the v0.4 `CatchResult`. Auto-closes in 5 s. |
| `UI.showOfflineEarnings(amount, seconds)` | "While you were away" popup with Claim, fires `events.claimOffline`. |
| `UI.floatText(worldPosition, text, color?)` | Rising "+$8" at a world point (customers' coin pops). |
| `UI.setCarrying(info?)` | `info = { catId, catName?, rarity?, door: BasePart? }`. Bottom-centre banner "Carrying Void" plus a world marker with distance over the door. `nil` clears. |
| `UI.tutorial.show(text, target?, markerLabel?)` / `UI.tutorial.hide()` | One-line gold strip at the bottom and, with a target (BasePart, Attachment or Vector3), a marker in the world. |
| `UI.clock.set(phase, phaseEndsAt)` | Day and night chip under the cats pill: sun or moon and "Day 2:31" counting down. `phase` is `"day"` or `"night"`, `phaseEndsAt` server `os.time()` seconds. The countdown runs on `Workspace:GetServerTimeNow()`, never the device clock. |
| `UI.clock.bind(ReplicatedStorage.Clock)` / `UI.clock.unbind()` | Easiest: reads the folder's `Phase` and `PhaseEndsAt` attributes and follows changes. `UI.clock.clear()` hides the chip. |
| `UI.setVisible(bool)` | Hide the whole UI for cutscenes or screenshots. |
| `UI.destroy()` | Tear everything down and disconnect every connection. |
| `UI.demo()` | Runs Demo.luau. Returns a stop function. Not for production. |

### Catch prompt and rescue bar (`UI.catch`)

A stray's prompt has `HoldDuration = 0` (F26): the card reads "Catch", the mobile button reads CATCH, and one press asks for the closing circles (see Design v0.3 below). A prompt whose model has `Rescue = true` is a stuck cat (F21): with a hold duration it reads "Hold to rescue", a bar fills over the 4 s hold, the button reads HOLD, there is no band and no fail; with `HoldDuration = 0` it reads "Rescue" and waits for the rescue minigame.

| Function | Purpose |
|---|---|
| `bindProximityPrompts()` | Recommended. Watches `ProximityPromptService`. Any prompt with `Style = Custom` and a `CatId` attribute (on the prompt, its Model or its parent) gets the UI. Reads `StrayId`, `CatName`, `Rarity`, `Stars`, `Charm` the same way, falling back to the catalog by `CatId`. A press on a stray's prompt fires `events.grabBegan(strayId, catId)` and the card shows "Get ready..." until `showCircles` or `fail`. A rescue hold fires `events.rescueBegan` on hold begin and `events.rescueEnded` on release or after the full hold. On touch, the big CATCH button calls `prompt:InputHoldBegin/End`, so the server sees an ordinary press or hold. |
| `unbindProximityPrompts()` | Stop watching. |
| `show(info)` | Manual use. `info = { catId?, strayId?, catName?, rarity?, holdDuration?, actionText?, keyCode?, stars?, charm?, kind?, rescueSpotId?, press?, shiny? }`. `kind` is `"swing"` (default, the net) or `"rescue"`. |
| `startRescue(duration?)` / `stopRescue(completed)` | Manual rescue hold. Default duration `Config.RescueHoldSeconds` (4 s). `stopRescue(true)` shows "Rescued!" and leaves the card up for `showCatFound` or `hide`; `stopRescue(false)` resets the bar. |
| `fail(reason?, retry?)` | `retry = true` keeps the prompt open with the reason, or "Missed, try again" ("Hold again to rescue it" on a rescue hold), for strays and rescues turned down for now. Otherwise it flashes the reason or "It got away" and hides. A fail that arrives while a rescue hold is still down (the server turned down `RescueBegin`) closes that hold: its release or full length fires no `rescueEnded`, and the rescue bar resets and hides. The player holds again to retry. |
| `success(catId)` is not needed: call `UI.showCatFound` when CatCaught arrives. | |
| `hide()` / `getActivePrompt()` | Utilities. |

## Design v0.3 (v5)

The UI stays a view: it never fires remotes. Built rows are in the UI now; planned rows are the API the next UI pull requests add, listed so the engineer can wire against them. Times are server time (`Workspace:GetServerTimeNow()`) unless a row says `os.time()`.

### Data v3 (built, F22 and F25)

`state.tier` (1 to 5) replaces `cafeLevel`. Upgrades and Decor gate on `requiresTier` and `requiresTierAtLevel` and say "Tier 3" on a locked button; the Upgrades subtitle and the top pill say "Tier 2 · Cozy Cafe". Mythical (#FF5E7E) replaces Secret. Lure odds list all five rarities, and Details splits each rarity equally across that rarity's cats in every area the player's tier has opened (bait rule, data-model section 8), rebuilt on a tier change.

Cat room (F25): Assign opens a role picker, one row per role, never a slot number. A row says "2 of 3 free", "All 2 taken, more at Tier 3", "Full" or "Opens at Tier 3"; the cat's favorite role shows a star, "1.5x" and a gold button. Assign fires `placeCat(uid, spotId)` with the first free open slot of that role. Each cat row has a "Loves Barista" tag that turns gold while the cat works that role, and its status names the slot ("Barista 2"). Role display names are the role ids capitalised.

### Press prompts (built)

A stray or stuck-cat prompt with `HoldDuration = 0` is a press prompt. The card reads "Catch" or "Rescue" (the prompt's `ActionText` wins when set), the touch button reads CATCH or RESCUE, and one press fires `events.grabBegan(strayId, catId)` or `events.rescueBegan(rescueSpotId, catId)`. The card then shows "Get ready..." until the server answers with `catch.showCircles`, the rescue minigame or `catch.fail(reason, retry)` for a refusal. A rescue prompt with a hold duration keeps the v0.2 rescue bar until the minigames. The `Shiny` attribute on a stray shows on the circles header.

v0.4 paws: when the stray carries a `Patience` attribute the card shows a paw row (pink paws left, grey paws spent) read from `Paws_<UserId>` on the stray (no attribute means full) and the hint "Hit each ring. A miss costs a paw!". Without `Patience` the v0.3 hint stays. At 0 paws the controller hides the prompt, so the card never shows; the hiss icon over the stray is the vfx-animator's.

### Closing circles (`UI.catch`, built, F26)

| Function | Purpose |
|---|---|
| `showCircles(strayId, circles, windows, pawsLeft?)` | From `CatchSchedule`. `pawsLeft` (v0.4) fills the paw row in the header; nil hides it (the player cannot run out on this stray). `circles = { { startsAt, shrinkSeconds, x, y } }`, `windows = { perfect, good }` (half-widths in seconds). The prompt card makes way for a full-screen overlay: a header with the cat, rarity and stars, then each circle at its position. Its ring fades in 0.35 s before `startsAt`, the closer shrinks from three times the ring's size and meets the ring at `startsAt + shrinkSeconds`. The Good band (green) and Perfect band (gold) are drawn from `windows` at the closer's speed, so they show the real timing. `x` and `y` (0 to 1) map into the middle 64% by 50% of the screen. |
| (input) | A tap anywhere, a click, E, Space, or the gamepad's A or R2 is a press. The press goes to the lowest circle still open: a press before that circle's `startsAt` is ignored, and a circle whose window has closed (target + good + `CatchLatencyCapSeconds`, 0.15) counts as a miss so the next press goes to the next circle, the order the server judges in. Each press fires `events.catchPressed(strayId, index)`. The client sends no time. Grades drawn now are hints from the device clock. |
| `showGrades(strayId, grades, success, pawsLeft?, charmGain?)` | From the v0.4 `CatchResult`. `grades` run up to and including the first Miss. Each circle pops PERFECT (gold), GOOD (green) or MISS (red) at its ring. A catch shows the banner "Caught!", or "PURRFECT!" in gold when every circle was Perfect, over "Charm +N" (or "1/3 Perfect" when no charm) for 1.6 s. A miss wobbles the MISS word (not with reduced motion), shrinks away the circles left over, takes a paw off the header with a pop, closes after 1 s and toasts "It slipped away! 2 paws left", "It slipped away! 1 paw left", "It won't trust you tonight" at 0, or "It slipped away! Try again" when `pawsLeft` is nil. The toast is silent; the hiss is the sound-designer's and the camera shake the vfx-animator's. While paws are left the prompt card comes back with the new count. Call nothing else for a CatchResult. |
| `showResult(strayId, scores, chance, success, stayed?)` | The v0.3 `CatchResult`, kept until the controller calls `showGrades`: scores of 1, 0.5 and 0 become Perfect, Good and Miss and it runs the same end with no paw row and no toast, since the server still toasts the miss until the switch (reviewer S39). When the controller moves to `showGrades`, the server drops its three slipped away toasts and keeps only forfeit reasons such as "Too far away". |
| `hideCircles()` / `circlesActive()` | Utilities. The overlay also closes itself 4 s after the last target if no result came. |

### Tiers and rank up (built, F24)

| API | Purpose |
|---|---|
| `catalog.tiers` | `{ TierDef }`, data-model 5b: `{ tier, name, cost, distinctCats, needsRarity?, needsRarityCount?, slots, multiplier, area, caps = { tables, espresso, net } }`. |
| `state.tier` | 1 to 5. With `catalog.tiers` the top pill shows "Tier 2 · Cozy Cafe", what the next tier still needs and a progress bar, and, when every requirement is met, a tilted red "Rank up!" sticker on its corner with "Rank up ready! Tap to see" as the sub line. Tapping it opens the `RankUp` screen. |
| `UI.open("RankUp")` | The card: next tier's name, each requirement ticked or not (coins, different cats from `collection`, the rarity from Tier 3, where a rarer cat also counts: "One cat, Epic or better"), what it opens (area, role slots, tips multiplier, raised upgrade caps, decor with `requiresTier`), and a gold "Rank up · $1,500" button that only lights up when everything is met. A `rankUp` field in ProfileSync is not needed; the card computes progress from the catalog and the state. |
| `events.rankUp()` | Rank up pressed. Forward as `RankUp`; the server checks everything again. |

### Clock chip (built, F31)

At night a small "Tips 60%" chip sits under the clock, from `Config.NightIncomeMultiplier`. The chip stays hidden until that constant exists (F31), because the server pays full tips at night before then. The income line under the money counts only cats in a role slot when `state.cats` is sent, since resting cats earn nothing.

### Sounds (built)

`UI.init` takes `playSound`, a function called with a cue id from the sound list (docs/audio/cat-cafe/sound-list.md section 5.8). Pass `Audio.play`; the UI keeps no asset ids and never requires Audio. A failing call warns once and never breaks a button.

| Cue | When the UI plays it |
|---|---|
| `uiClick` | Any button press, the lure slot, Cafe and Alley travel. Buttons that only open or close a screen (menu tiles, Collection, Areas, the red X) stay silent and let the swish play. |
| `uiError` | A tap on a greyed button (can't afford, carrying, locked area) and every `warn` toast. A drag that starts on a greyed button, such as a phone scroll, stays quiet. |
| `uiOpen` / `uiClose` | A modal screen opens or closes. |
| `uiTab` | The Book and Cat room tabs, the decor category chips and a cat cell in the book. |
| `uiToast` | Every `info` and `good` toast. Shout-outs are silent here because Audio plays their sting. |
| `uiHint` | A new tutorial line. |
| `uiRankReady` | The first time each tier's requirements are all met (the red "Rank up!" sticker appears). |

`purchase` and `jingleCatFound` are not played by the UI: Audio plays them from the `Purchase` and `CatFound` moments, so each plays once and only after the server agrees.

### Gate signs (built, F39)

`UI.init` puts a sign over every gate tagged `AreaGate` (WorldBuilder sets `Area` and `RequiresTier`), including gates that stream in later. Nothing to call: the signs follow `UI.update` and the catalog. Locked: a lock, the area name, "Needs Cozy Cafe (Tier 2)" and, for the next tier only, one bar per rank up requirement from the same progress the rank up card uses ("3 / 5", "$900 / $1.5K", gold with a tick when met; "Ready to rank up!" when all are met). A gate two or more tiers away says "Rank up to <next tier> first". Open: a green name plate with the area icon. The signs are local BillboardGuis sized in studs, shown within 50 studs, and the server's placeholder text label on each gate is removed on this client. Engineer: the label in `WorldBuilder.buildGate` and the BillboardGui toggle in `WorldController.setGateOpen` can go whenever convenient.

### Next goal card and menu dots (built, F39 P1)

The HUD's right column has a next goal card under the clock (Pet Simulator 99 quest style): "NEXT GOAL", the next tier's name and one bar per rank up requirement from `RankUp.progress`, gold when met. All met reads "READY! TAP TO RANK UP" with a gold edge. A tap opens the rank up card; the card hides at the top tier. The tier pill now only says "Next: <tier name>" under the title.

Each menu tile gets a red "!" dot when its screen has something new (`Notices.luau`): an upgrade level or decor item the player can now afford and is allowed to buy, or a cat or shiny added to the collection since the book was last open (cats caught before the session are not news). Opening the screen clears its dot, and anything that appears while it is open counts as seen. No new fields: it reads the state the UI already gets.

### Collection book index (built, F39 P1)

Copied from the Pet Simulator index. The Book tab opens on a row of area tabs in tier order, each in its area colour when open, reading "3 / 10", "Complete!" or "Tier 4" for an area the player has not reached and found nothing in. Under it the open area's name, a progress bar in the area colour (gold when complete) and "3 / 10 · 30%". The grid shows that area's cats, rarest last, as still 3D models from `ReplicatedStorage.Assets` on a disc in the rarity colour; a cat not found yet is a dark silhouette with "???" and its rarity. A Shiny pill marks cats in `state.shinyCollection`. The panel title reads "12 / 50 found · 24%". Tapping a cell fills the detail strip with the same model (or silhouette). A cell's model is cloned the first time its area opens, so the book never holds more than the areas the player has looked at. No new fields: it reads `catalog.areas`, `cat.area`, `state.collection`, `state.catsOwned` and `state.shinyCollection`.

### Area title card and shout-outs (built, F39 P1)

`UI.showAreaTitle(areaId)` shows the area's name in big outlined letters for two seconds with its "Epic or better N%" line in the area's colour (Pet Simulator 99 and Fisch zone names). `"home"` shows the cafe's tier name over "Your cafe". `UI.travel.result(destination, true)` already calls it; the controller also calls it when the player walks into an area (the zone check that picks the ambience). The same area twice within 4 s shows once. `UI.announce(text, rarity?)` shout-outs take the rarity's colour (or the last rarity named in the text) and stay 4 s.

### Cafe name signs, rate tags and order bubbles (built, world-and-feel sections 3 and 4)

Nothing to call: `UI.init` starts all three and they read attributes the server and `CustomerController` already set.

- **Name sign** (Steal a Brainrot base signs, `Screens/CafeSigns.luau`): on every model tagged `Plot`, a local SurfaceGui on the street face of the shell's `SignBoard` part, else the code-built `Sign` part. Owned: the owner's round avatar headshot (`rbxthumb://type=AvatarHeadShot`), "<OwnerName>'s Cafe" and "<TierName>  ·  +$X/s" from the plot's `Rate`; at night (`ReplicatedStorage.Clock` `Phase == "night"`) the rate stays behind a moon ("Cozy Cafe  ·  🌙 +$25/s"), times `NightIncomeMultiplier` once F31 puts it in Config, because cafes keep earning at night (reviewer S41). Empty plots read "FOR RENT" over "A cosy spot for a new cafe". Your own cafe has a gold edge. The server's `SignGui` in the plot is disabled on this client only, so it stays as the fallback if the UI fails to load.
- **Rate tags** (Steal a Brainrot, `Screens/WorldTags.luau`): over every model tagged `WorkingCat`, "+$X/s" from its `Rate` in its `Rarity` colour, shown within 40 studs. Hidden while `Napping` is true or `Rate` is 0.
- **Order bubbles** (`Screens/WorldTags.luau`): over each customer in `Workspace.LocalCustomers` once `Order` is set ("coffee", "cake" or "milk", drawn as emoji). When `Served` turns true it pops into a pink bubble with a red heart for 1.6 s, then pops out. Customers are client-side models, so this costs no network traffic.

All three are BillboardGuis or SurfaceGuis parented under the models, so they leave with the plot, cat or customer.

### Planned in the next UI pull requests

| API | Purpose |
|---|---|
| `UI.rescue.show(rescueSpotId, challenge)` | From `RescueChallenge`. `challenge = { kind = "bar" or "shake_catch", startsAt, phase, speed, zoneWidth, zones = { centre per hit }, hitsNeeded, paws }`. The marker's position at time t is the triangle wave of `phase + speed * (t - startsAt)` with period 2 (0 to 1 and back), the shared `markerAt` helper. Paw lives, a hit count and Cancel. A tree (`shake_catch`) shakes the branch on each hit; the server then sends a second challenge `{ kind = "circle", circle = { startsAt, shrinkSeconds, x, y }, windows }` drawn as one catch circle. Presses fire `events.rescuePressed(rescueSpotId)`, Cancel fires `events.rescueCancelled(rescueSpotId)`. |
| `UI.rescue.update(hits, pawsLeft, done, success)` | From `RescueResult`. A hit moves the zone to `zones[hits + 1]`, a miss greys a paw. |
| `UI.bait.openPicker()` | The bowl's food picker: owned foods with counts, five-rarity odds and the per-cat split. Fires `events.useLure(lureId)`. |
| `state.bait = { lureId, readyAt }` | `readyAt` is server `os.time()`. The HUD shows a countdown chip, then "Cat waiting!". |
| `UI.bait.showReady(catView)` | From `BaitReady`: the cat, rarity, stars and sparkle with Tame and Let go. Fires `events.resolveBait("tame" or "letgo")`. |
| Food cards | Every food card shows the five-rarity odds before Buy and the per-cat split for the player's unlocked areas ("Legendary 2.6%, split equally across the 2 Legendary cats in your areas, 1.3% each"), and says when a rank up will change the split. |
| `UI.dealer.open(slots)` / `UI.dealer.update(slots)` | From `DealerStock`: `slots = { { lureId, cost, bought } }`, three cards with odds, price and a moon timer to dawn. Fires `events.buyDealerFood(slot)`. |
| Action pill | Custom-style prompts without a `CatId` (bait bowl, dealer cart, rich tip, Bump) get a small pill with the key and `ActionText`; on touch the pill is the button. The controller handles `PromptTriggered` as today. |
| `UI.richTip.bind(plot)` | Reads `RichTipAmount`, `RichTipExpiresAt` (server `os.time()`) and the `RichTipAnchor` part: a gold marker with the amount and its time left, and Collect fires `events.claimRichTip()`. |
| Shiny | A sparkle badge on cards, the carry banner and the book; the book gets a Shiny page with its own count from `state.shinyCollection`. `CatInstance.variant = "shiny"`. |
| Rename | A Rename button on each cat in the cat room opens a dialog (20 characters). Fires `events.renameCat(uid, name)`; the shown name is `CatInstance.name` or the catalog name. |
| Fast travel (built, v0.4 F19) | Top centre under the tier pill: Cafe, Alley and Areas buttons (Grow a Garden style). Cafe and Alley fire `events.travel("home")` and `events.travel("alley")`; Areas opens `UI.open("Areas")`, five area cards with "Epic or better N%" and Go, locked ones greyed with "Opens at Tier n". The row hides while the catch circles show (their header takes the top centre). Every button and Go greys while carrying (`state.carrying` or `UI.setCarrying`) and Cafe and Alley grey for `Config.TravelCooldownSeconds` (3 until it exists) after a trip. Forward `events.travel(destination)` as `Travel(destination)`; pass `TravelResult(destination, ok, reason?)` to `UI.travel.result`, which lifts the cooldown and wobbles the button on a refusal (the server toast gives the reason). |

Removed with F26: `grabEnded`, `startRing`, `stopRing`, `expire`, `setProgress`, `RingConfig` and the `RingResult` re-export. Retired once the rescue minigames and the bait bowl land: `rescueEnded`, `startRescue`, `stopRescue` and `equipLure`; they stay until the controller drops them so main keeps compiling.

## Events (UI -> game), all `Signal` with `:Connect(fn)` returning a connection with `:Disconnect()`

| Event | Args | Fired when |
|---|---|---|
| `buyUpgrade` | `upgradeId` | Buy pressed (UI only enables it when affordable, not maxed, tier gate met) |
| `buyDecor` | `decorId` | Buy pressed in Decor |
| `toggleDecor` | `decorId, placed` | Place / Remove pressed on an owned decor item |
| `buyLure` | `lureId` | Buy pressed in the lure picker (odds are on screen before the button) |
| `equipLure` | `lureId` | Equip pressed |
| `placeCat` | `uid, spotId` | Assign pressed on a role in the Cat room; `spotId` is the first free open slot of that role |
| `unplaceCat` | `uid` | Rest pressed on a placed cat |
| `sellCat` | `uid` | Sell confirmed. Rare and above ask twice: Sell turns into "Sell $150", Rest turns into an equal-sized Cancel. |
| `equipBest` | none | "Equip best" pressed at the top of the Cat room: the server places the highest-rated cats on the open role slots |
| `claimOffline` | none | Claim pressed on the offline popup |
| `grabBegan` | `strayId, catId` | Hold began on a bound stray prompt |
| `rescueBegan` | `rescueSpotId, catId` | Hold began on a prompt whose model has `Rescue = true`. Forward as RescueBegin. |
| `rescueEnded` | `rescueSpotId, catId, completed` | `completed = true` after the full 4 s hold: forward as RescueEnd, the server moves the player to carry. `false` is an early release: the bar reset, send what the server needs to unlock the spot (or nothing). |
| `screenOpened` | `name or nil` | Modal opened or closed |
| `catchPressed` | `strayId, index` | v0.3: a press on circle `index` (1-based). Forward as CatchPress. |
| `rankUp` | none | v0.3: Rank up pressed with every requirement met. Forward as RankUp. |

## State shape (`Types.PlayerState`)

```lua
{
    money: number,
    incomePerSecond: number,
    tier: number,                            -- v0.3: 1 to 5, replaces cafeLevel
    cafeProgress: number?, cafeProgressText: string?,   -- unused (the tier pill computes its own progress)
    tables: number?, customers: number?,
    catsOwned: { [catId]: { count } },       -- derived from cats when cats is sent
    upgradeLevels: { [upgradeId]: number },
    decorOwned: { [decorId]: boolean }, decorPlaced: { [decorId]: boolean },
    lures: { [lureId]: number }, equippedLure: string?,
    -- engineer extras the UI uses when present
    cats: { [uid]: { uid, catId, variant?, caughtAt?, spotId?, rescued?, method?,  -- enables the Cat room tab
                     level?, xp?, xpToNext?, charm?, stars?, rating? } }, -- cat stats thread; shown when present
    collection: { [catId]: firstCaughtAt },                        -- drives "?" silhouettes and the 7 / 50 count
    shinyCollection: { [catId]: firstShinyAt }?,                   -- v0.3: the book's Shiny page (planned)
    carrying: string?, tutorialStep: number?,
}
```

## Catalog shapes (re-exported from `src/shared/Types.luau`)

`UI.Types.CatDef`, `UpgradeDef`, `DecorDef`, `LureDef`, `SpotDef`, `TierDef`, `AreaDef`, `LureOdds`, `Rarity`, `Role`, `Area`, `SpotType`, `CatchMethod`, `CatchCircle`, `CatchWindows` and `CircleGrade` are the shared types, so `Catalog.cats` and friends pass straight into `UI.init`. Fields the UI reads:

```lua
CatDef     : id, name, rarity, incomePerSecond, area (one of five), favoriteRole, description, color {r,g,b}  (placeholder body colour until renders exist)
UpgradeDef : id, name, description, maxLevel, costs {n}, startLevel, requiresTier?, requiresTierAtLevel? { [level] = tier }
DecorDef   : id, name, cost, category, effect, description, requiresTier?   (asset is the 3D model; the card draws a lettered tile)
LureDef    : id, name, cost, attracts, source, description, odds { Common, Rare, Epic, Legendary, Mythical }  -- percentages, sum 100
SpotDef    : id ("barista_1"), spotType (the role), tier
TierDef    : tier, name, cost, distinctCats, needsRarity?, needsRarityCount?, slots, multiplier, area, caps { tables, espresso, net }
AreaDef    : id, name, tier, ...   (the UI reads id, name and tier)
```

`CatInstance`, `PlayerState` and `PartialState` stay the UI's own (optional fields for the cat stats extras); the controller passes `cats` with a cast because Luau table fields are invariant.

`costs[n]` is the price of level n. A starting level (`espresso` 1) means `costs[1]` is never offered. Odds are printed on every lure row as "Odds: 70% Common · 22% Rare · 6% Epic · 1.8% Legendary · 0.2% Mythical" and a labelled Details button expands the per-cat split, computed from the catalog: every cat of a rarity in the areas the player's tier has opened has the same chance.

## Mobile and scaling rules the UI follows

- One `UIScale` per ScreenGui root, driven by viewport: design size 1280x720, `scale = clamp(min(w/1280, h/720), 0.6, 1.3)`, floor 0.75 on touch. The root's Size is `1/scale` so edge-anchored panels stay on the edges.
- Everything is laid out in design pixels under that scale; no raw Offset layouts that ignore it.
- Touch targets at least 44x44 design px. Hover effects only with a mouse. Keyboard hints hidden on touch.
- `ScreenInsets = CoreUISafeInsets`: the HUD keeps clear of the Roblox top bar.
- Modals are 92% x 86% of the viewport with a UISizeConstraint cap; lists scroll with `AutomaticCanvasSize`.
- Money uses `Format.money` ("$8,420", "$1.2M") so it never overflows.
- DisplayOrder: HUD 10, catch prompt 15, modals 20, catch circles 25, toasts 30, popups 40.

## Shop rules followed (growth thread, docs/growth/monetization.md section 6)

Odds visible before any purchase and the detail control is labelled "Details", not an icon. Buy and Equip (and Sell and Cancel) are the same size and contrast. No timers anywhere in the shop.

## Names agreed

- Screens: `Upgrades`, `Decor`, `Collection`, `RankUp`. Rarities exactly: `Common`, `Rare`, `Epic`, `Legendary`, `Mythical` (v0.3; Mythical is #FF5E7E with white text).
- Stray prompt attributes (on the model, data-model section 13): `StrayId`, `CatId`, `CatName`, `Rarity`, plus `Stars` and `Charm` from the cat stats thread; prompt `Style = Custom`. A stuck cat adds `Rescue = true` and `RescueSpotId` (the id RescueBegin and RescueEnd take; falls back to `StrayId`).
- Clock folder (`ReplicatedStorage.Clock`, data-model section 9): attributes `Phase` ("day" or "night") and `PhaseEndsAt` (server `os.time()` seconds).
- Catch timing lives in `Shared.Config` and the schedule: the circles' bands come from `CatchSchedule`'s windows, the miss cut-off from `CatchLatencyCapSeconds`, the rescue bar from `RescueHoldSeconds`.
- Currency is coins shown as `$` (`Theme.currencySymbol`).

## Not in scope for the UI thread, and space left for later

Remotes, validation, rate limits, data saving, cat AI, decor placement in the world, localization (strings sit in the screens, ready to pull out). Planned screens with room reserved: leaderboards and settings (P2, modal screens), event banner (HUD top centre under the travel row, post-slice), a "Closed" state on the HUD rate if tips pause at night (questions-for-gavin.md question 10).

## Check gate status

CI runs the full gate (rojo sourcemap, luau-lsp 1.70 analyze, selene, stylua --check) on every pull request. The UI thread also runs luau-lsp 1.70 with the real sourcemap, selene and StyLua before each push.

## Mockups

`docs/concepts/cat-cafe/ui/index.html`: HUD at 1280x720, phone at 812x375 with the catch ring and GRAB button, carry banner, Upgrades, Decor, Collection (Book and Cat room tabs), lure picker with odds and Details, popups and toasts, tokens and rules. Built from the asset thread's cat renders.
