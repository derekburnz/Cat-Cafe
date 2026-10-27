# Cat Cafe UI contract

Owner: UI thread ("Design cat cafe UI"). v5, updated 2026-10-26 (v1 2026-10-25, v2 to v4.1 earlier on 2026-10-26).
v5 (design v0.3, features.md section 6): data v3 (tiers, roles, Mythical, five-rarity odds), closing circles for the net, press prompts, rank up card and tier pill, "Tips 60%" at night. Everything v0.3 is in the section "Design v0.3 (v5)" below, with each row marked built or planned. The v0.2 hold ring is gone with F26; the rescue hold bar stays until the rescue minigames.
v4.1: `catch.fail` closes a hold that is still down and resets the rescue bar, so a server rejection of `GrabBegin` or `RescueBegin` never shows "Missed" or "Rescued!" and sends nothing more.
v4 changes (gdd.md v0.2): day and night clock chip (`UI.clock`, F20), the catch tool is the Net so the prompt copy is a swing, and the 4 s Rescue hold bar with `rescueBegan` / `rescueEnded` (F21, retired by the F27 rescue bar). The `gloves` upgrade is now `net`; the UI reads it from the catalog, nothing to change.
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

Windows (`Components/Panel.luau`, cat cafe dress from the UI plan 2026-10-27): every modal screen is a rounded cream window with a thick dark outline, a shaded header, an outlined title and a red X. Two cat ears in the header colour, pink inside, poke up behind the header; a round icon badge, tilted like a sticker, sits over the top-left corner; faint paw prints dot the body behind the content. Each screen has its own header colour and icon so it is known at a glance: Upgrades red ⬆️, Decor gold 🪴, Cats and Book sky 🐱, Bait bowl mint 🥣, Night dealer berry 🌙, Areas green 🧭, Rank up gold 🏆. `Panel.new` takes `color` and `icon` (both optional; caramel and no badge by default). `panel.frame` is a see-through holder that does not clip, so the ears and badge can stick out; the window itself is `panel.body`, and screens keep building inside `panel.content`.

## How the engineer uses it

```lua
local UI = require(script.Parent.UI)

UI.init({
    catalog = {                     -- the shared Catalog's own tables, no cast: UI.Types re-exports the shared types
        cats = Catalog.cats,          -- {CatDef}
        upgrades = Catalog.upgrades,  -- {UpgradeDef}
        decor = Catalog.decor,        -- {DecorDef}
        lures = Catalog.lures,        -- {LureDef} with odds
        spots = Catalog.spots,        -- {SpotDef} role slots, for the cat room's crew strip and Upgrades > Staff
        tiers = Catalog.tiers,        -- {TierDef}, v0.3: tier names, gates and the rank up card
        areas = Catalog.areas,        -- {AreaDef}, v0.3: the bait odds split pools the areas the tier has opened
    },
    keybinds = true,  -- U upgrades, B decor, C collection, F bait bowl, gamepad B closes (default true)
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
| `UI.open(name)` / `UI.close()` / `UI.isOpen()` | Modal screens: `"Upgrades"`, `"Decor"`, `"Collection"`, `"RankUp"`, `"Areas"`, `"Bait"`, `"Dealer"`. One open at a time. |
| `UI.setZone(zone?)` | The `World.Zones` name the player stands in, from the controller's zone check: nil or `"Cafe"` is the safe street and cafes, else the area (`"Alley"`). Drives the Safe zone chip and its toast on coming back, and hides that area's location marker. |
| `UI.openCatRoom()` | Opens Collection on the Cat room tab (tutorial step 3). |
| `UI.toast(text, kind?)` | Top-centre message. kind: `"info"` (default), `"good"`, `"warn"`, `"announce"` (gold). |
| `UI.announce(text, rarity?)` | Server-wide catch shout-out, on the rarity's colour for 4 s. Pass the rarity from `Announce` once it carries one; without it the last rarity named as a whole word in the text decides, so a DisplayName like "EpicGamer" does not colour it. Silent, since Audio plays the shout-out sting from the remote. |
| `UI.showCatFound(catId, isNew?, extra?)` | The hatch style reveal (F39 P1): rays in the rarity colour, the cat's own model from `ReplicatedStorage.Assets` popping in and swaying (its initial when the model is missing), a NEW sticker when `isNew`, charm stars filling one by one and "Purrfect catch! Charm +N". `extra = { stars?, shiny?, charmGain? }`; stars and shiny fall back to the newest copy of the cat in `state.cats` from the last 30 s, and the stars row hides without them. Pass `charmGain` from the v0.4 `CatchResult`. Auto-closes in 5 s. |
| `UI.showOfflineEarnings(amount, seconds)` | "While you were away" popup with Claim, fires `events.claimOffline`. |
| `UI.floatText(worldPosition, text, color?)` | Rising "+$8" at a world point (customers' coin pops). |
| `UI.setCarrying(info?)` | `info = { catId, catName?, rarity?, door: BasePart? }`. Bottom-centre banner "Carrying Void" plus a world marker with distance over the door. `nil` clears the banner, the marker and `state.carrying` (a partial `UI.update` cannot set a field back to nil, so this is the only way to end a carry). |
| `UI.tutorial.show(text, target?, markerLabel?)` / `UI.tutorial.hide()` | Gold strip at the bottom (up to 520 px wide, wrapping onto a second line, so keep hints under about 100 characters; reviewer N94) and, with a target (BasePart, Attachment or Vector3), a marker in the world plus a glowing dotted trail on the ground from the player to it (Pet Simulator 99, F39 P1). The trail follows a PathfindingService route (no dots while none is found, retried every 2 s, so it never cuts through a wall), re-routes after the player moves 5 studs, shows up to about 170 studs ahead and hides within 10 studs of the target. Calling `show` again with the same target keeps the route, so `refreshTutorial` on every state update is fine. The dots are client-only, non-colliding parts in `Workspace.CatCafeTutorialTrail`. |
| `UI.clock.set(phase, phaseEndsAt)` | Day and night chip under the cats pill: sun or moon and "Day 2:31" counting down. `phase` is `"day"` or `"night"`, `phaseEndsAt` server `os.time()` seconds. The countdown runs on `Workspace:GetServerTimeNow()`, never the device clock. |
| `UI.clock.bind(ReplicatedStorage.Clock)` / `UI.clock.unbind()` | Easiest: reads the folder's `Phase` and `PhaseEndsAt` attributes and follows changes. `UI.clock.clear()` hides the chip. |
| `UI.setVisible(bool)` | Hide the whole UI for cutscenes or screenshots. |
| `UI.destroy()` | Tear everything down and disconnect every connection. |
| `UI.demo()` | Runs Demo.luau. Returns a stop function. Not for production. |

### Catch prompt and rescue bar (`UI.catch`)

Since 2026-10-27 (Derek: "hold E to start the minigame") a stray's prompt and a stuck cat's are held for `HoldDuration` (0.5 s): the card reads "Catch" with HOLD under the E key cap, the mobile button reads CATCH, and while the player holds, the key cap fills with gold from the bottom and the CATCH button fills with a gold disc over `HoldDuration`; letting go early drains both (reviewer S52, from `PromptButtonHoldBegan` and `PromptButtonHoldEnded` on the active prompt). The trigger asks for the closing circles (see Design v0.3 below). A prompt whose model has `Rescue = true` is a stuck cat: it reads "Rescue" (the button RESCUE) and its trigger asks for the rescue minigame (`UI.rescue.show`).

| Function | Purpose |
|---|---|
| `bindProximityPrompts()` | Recommended. Watches `ProximityPromptService`. Any prompt with `Style = Custom` and a `CatId` attribute (on the prompt, its Model or its parent) gets the UI. Reads `StrayId`, `CatName`, `Rarity`, `Stars`, `Charm` the same way, falling back to the catalog by `CatId`. A press on a stray's prompt fires `events.grabBegan(strayId, catId)`, on a stuck cat's `events.rescueBegan(rescueSpotId, catId)`, and the card shows "Get ready..." until `showCircles`, `UI.rescue.show` or `fail`. A press while the circles or the rescue bar are up is theirs and asks nothing. On touch, the big CATCH button calls `prompt:InputHoldBegin/End`, so the server sees an ordinary press. |
| `unbindProximityPrompts()` | Stop watching. |
| `show(info)` | Manual use. `info = { catId?, strayId?, catName?, rarity?, holdDuration?, actionText?, keyCode?, stars?, charm?, kind?, rescueSpotId?, press?, shiny? }`. `kind` is `"swing"` (default, the net) or `"rescue"`. |
| `fail(reason?, retry?)` | `retry = true` keeps the prompt open with the reason, or "Missed, try again", for strays and rescues turned down for now. Otherwise it flashes the reason or "It got away" and hides. |
| `success(catId)` is not needed: call `UI.showCatFound` when CatCaught arrives. | |
| `hide()` / `getActivePrompt()` | Utilities. |
| `holdStart()` / `holdStop()` on the card | Called by `bindProximityPrompts` from the prompt's hold signals; manual users with their own hold call them too. |

## Design v0.3 (v5)

The UI stays a view: it never fires remotes. Built rows are in the UI now; planned rows are the API the next UI pull requests add, listed so the engineer can wire against them. Times are server time (`Workspace:GetServerTimeNow()`) unless a row says `os.time()`.

### Data v3 (built, F22 and F25)

`state.tier` (1 to 5) replaces `cafeLevel`. Upgrades and Decor gate on `requiresTier` and `requiresTierAtLevel` and say "Tier 3" on a locked button; the Upgrades subtitle and the top pill say "Tier 2 · Cozy Cafe". Mythical (#FF5E7E) replaces Secret. Lure odds list all five rarities, and Details splits each rarity equally across that rarity's cats in every area the player's tier has opened (bait rule, data-model section 8), rebuilt on a tier change.

Cat room (inventory, UI plan 2026-10-27, `Screens/CatRoom.luau`, order and search in `Components/CatRoomList.luau` with a spec; replaces the F25 list and role picker). Top: the **crew strip**, one group per role ("☕ Barista") with a 44 px square per slot in the order they open (`StaffSlots`): the working cat's own model on its rarity colour, a green "+" for a free slot, a grey lock with "T3". Tap a cat's square to pick that cat; tap a "+" with a cat picked to fire `placeCat(uid, spotId)` for that slot (a move when the cat already works). Under it the **toolbar**: a search box (the player's name for the cat, breed or rarity, plain text, never sent anywhere), All / Working / Resting chips with counts, Unequip All (`events.unequipAll()`, grey while no cat works) and Equip Best (`events.equipBest()`). Then the **grid**, a card per cat: still model, the cat's name (or breed), "Lv 3  $3.4/s" (1.5x on its favourite role), the role icon while it works, ✨ and a gold edge when gold, a sky edge when picked. Working cats come first, then rarer, then the higher rating. On the right the **picked cat**: model, name with the rename pencil, "Gold Rare Tabby", level and stars, rate and slot ("Barista 2") or "Resting", "Loves Barista · 1.5x there", the breed's description where there is room, and Assign (Move while working), Rest and Sell. Assign rings every free "+" in gold and adds "★ 1.5x" to the cat's favourite role; with no free slot it says so instead. Sell asks first from Rare up: Cancel and a wide gold "Sell $150". Models load as cards scroll near view (N71).

### Press prompts (built)

A stray or stuck-cat prompt is a hold prompt (0.5 s, 2026-10-27; it was a press prompt with `HoldDuration = 0` before). The card reads "Catch" or "Rescue" (the prompt's `ActionText` wins when set), the touch button reads CATCH or RESCUE, and one press fires `events.grabBegan(strayId, catId)` or `events.rescueBegan(rescueSpotId, catId)`. The card then shows "Get ready..." until the server answers with `catch.showCircles`, the rescue minigame or `catch.fail(reason, retry)` for a refusal. The `Gold` attribute on a stray adds "Gold" to the circles header.

v0.5 chase (F40, data-model section 10 step 5): tries are unlimited, so the card has no paw row and the hint reads "Hit each ring. Miss and it runs off!". While the stray model's `FleeingUntil` (server time) is ahead the card reads "It's running!" in orange over "Wait till it stops, then try again", the CATCH button greys and a press asks the server nothing; the card turns back to Catch the moment the cat stops, and redraws at once when `FleeingUntil` changes while it is up (someone else missed it). The player who missed reads "Catch your breath..." for `StraySelfRetrySeconds` (1, from Config) after the stop (reviewer S44); the UI notes its own misses from `CatchResult`, so the server sends nothing extra for it. A cat knocked loose by a shove (`Dropped`, F41) reads "Owner's turn" over "Its owner gets the first try" for everyone but its `DropOwner` until `DropOwnerUntil` (reviewer N90), then turns to Catch; the server keeps refusing the shover for good with its own toast.

### Closing circles (`UI.catch`, built, F26)

| Function | Purpose |
|---|---|
| `showCircles(strayId, circles, windows)` | From `CatchSchedule`. `circles = { { startsAt, shrinkSeconds, x, y } }`, `windows = { perfect, good }` (half-widths in seconds). The prompt card makes way for a full-screen overlay: a header with the cat, rarity and stars, then each circle at its position. Its ring fades in 0.35 s before `startsAt`, the closer shrinks from three times the ring's size and meets the ring at `startsAt + shrinkSeconds`. The Good band (green) and Perfect band (gold) are drawn from `windows` at the closer's speed, so they show the real timing. `x` and `y` (0 to 1) map into the middle 64% by 50% of the screen. |
| (input) | A tap anywhere, a click, Space, or the gamepad's A or R2 is a press. E is not: it is the hold-to-start key on the catch prompt (2026-10-27). The press goes to the lowest circle still open: a press before that circle's `startsAt` is ignored, and a circle whose window has closed (target + good + `CatchLatencyCapSeconds`, 0.15) counts as a miss so the next press goes to the next circle, the order the server judges in. Each press fires `events.catchPressed(strayId, index, grade)`, where `grade` is this device's hint ("perfect", "good" or "miss") so the grade sound can play the instant the press lands. Forward only `strayId` and `index`: the client sends no time and no grade, and the server judges. |
| `showGrades(strayId, grades, success, charmGain?)` | From `CatchResult`. `grades` run up to and including the first Miss. Each circle pops PERFECT (gold), GOOD (green) or MISS (red) at its ring. A catch shows the banner "Caught!", or "PURRFECT!" in gold when every circle was Perfect, over "Charm +N" (or "1/3 Perfect" when no charm) for 1.6 s. A miss wobbles the MISS word (not with reduced motion), shrinks away the circles left over, closes after 1 s and toasts "It got away! Chase it!" (the circles header says the same). The toast is silent; the hiss is the sound-designer's and the camera shake the vfx-animator's. The prompt card comes back while its prompt is up, reading "It's running!" (see the v0.5 chase above). Call nothing else for a CatchResult. |
| `hideCircles()` / `circlesActive()` | Utilities. The overlay also closes itself 4 s after the last target if no result came. |

### Tiers and rank up (built, F24)

| API | Purpose |
|---|---|
| `catalog.tiers` | `{ TierDef }`, data-model 5b: `{ tier, name, cost, distinctCats, needsRarity?, needsRarityCount?, slots, multiplier, area, caps = { tables, espresso, net } }`. |
| `state.tier` | 1 to 5. With `catalog.tiers` the top pill shows "Tier 2 · Cozy Cafe", what the next tier still needs and a progress bar, and, when every requirement is met, a tilted red "Rank up!" sticker on its corner with "Rank up ready! Tap to see" as the sub line. Tapping it opens the `RankUp` screen. |
| `UI.open("RankUp")` | The card: next tier's name, each requirement ticked or not (coins, different cats from `collection`, the rarity from Tier 3, where a rarer cat also counts: "One cat, Epic or better"), what it opens (area, role slots, tips multiplier, raised upgrade caps, decor with `requiresTier`), and a gold "Rank up · $1,500" button that only lights up when everything is met. A `rankUp` field in ProfileSync is not needed; the card computes progress from the catalog and the state. |
| `events.rankUp()` | Rank up pressed. Forward as `RankUp`; the server checks everything again. |

### Clock chip (built, F31)

At night a small "Tips 60%" chip sits under the clock, from `Config.NightIncomeMultiplier`. The income line under the money counts only cats in a role slot when `state.cats` is sent, since resting cats earn nothing.

### Sounds (built)

`UI.init` takes `playSound`, a function called with a cue id from the sound list (docs/audio/cat-cafe/sound-list.md section 5.8). Pass `Audio.play`; the UI keeps no asset ids and never requires Audio. A failing call warns once and never breaks a button.

| Cue | When the UI plays it |
|---|---|
| `uiClick` | Any button press, Cafe and Alley travel. Buttons that only open or close a screen (menu tiles, Collection, Areas, the red X) stay silent and let the swish play. |
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

Each menu pill gets a red "!" dot when its screen has something new (`Notices.luau`): an upgrade level or decor item the player can now afford and is allowed to buy, or a cat or gold coat added to the collection since the book was last open (cats caught before the session are not news). Opening the screen clears its dot, and anything that appears while it is open counts as seen. No new fields: it reads the state the UI already gets.

### Collection book index (built, F39 P1)

Copied from the Pet Simulator index. The Book tab opens on a row of area tabs in tier order, each in its area colour when open, reading "3 / 10", "Complete!" or "Tier 4" for an area the player has not reached and found nothing in. Under it the open area's name, a progress bar in the area colour (gold when complete) and "3 / 10 · 30%". The grid shows that area's cats, rarest last, as still 3D models from `ReplicatedStorage.Assets` on a disc in the rarity colour; a cat not found yet is a dark silhouette with "???" and its rarity. A Gold pill marks cats in `state.goldCollection`; the book shows the base coat, while the cat room cards, the catch reveal and the bait card show a gold cat in its own coat (`Catalog.goldModelName`, F42, falling back to the base model). The panel title reads "12 / 50 found · 24%". Tapping a cell fills the detail strip with the same model (or silhouette). A cell's model is cloned the first time its area opens, so the book never holds more than the areas the player has looked at. No new fields: it reads `catalog.areas`, `cat.area`, `state.collection`, `state.catsOwned` and `state.goldCollection`.

### Area title card and shout-outs (built, F39 P1)

`UI.showAreaTitle(areaId)` shows the area's name in big outlined letters for two seconds with its "Epic or better N%" line in the area's colour (Pet Simulator 99 and Fisch zone names). `"home"` shows the cafe's tier name over "Your cafe". `UI.travel.result(destination, true)` already calls it; the controller also calls it when the player walks into an area (the zone check that picks the ambience). The same area twice within 4 s shows once. `UI.announce(text, rarity?)` shout-outs take the rarity's colour (or the last rarity named in the text) and stay 4 s.

### Location markers and the Safe zone chip (built, UI plan 2026-10-27)

Derek: "symbols to locations also that disappear when close enough so its not clutter", and the cafe street counts as safe.

- **Location markers** (`Screens/LocationMarkers.luau`, nothing to call): a round icon with the name and distance ("120 m") over My Cafe (gold 🏠, over the own `Plot`'s pivot), every area (its icon and colour, over the `AreaGate` model's pivot, else the middle of its biggest `World.Zones` box) and the night dealer's cart (🛒, tag `DealerCart` while `Open`). Seen through walls from anywhere; each fades out between 60 and 30 studs (`Components/Wayfinding.luau`, with a spec), so the place in front of the player is never covered. A locked area's icon is grey and reads "🔒 Tier 3 · 120 m". My Cafe hides while carrying (the carry marker leads to the door) and the area the player stands in hides its own. Points come from model pivots and the persistent Zones boxes, so they show before the parts stream in.
- **Safe zone chip** (`Screens/ZoneChip.luau`): a pill under the tier pill, "🛡️ Safe zone" in green on the street and in the cafes, "🐾 Catching area · shoves on" in orange in an area. Walking from an area back to the street pops it and toasts "Safe zone: no shoving here" at most once every 20 s, so walking along an area's open edge does not repeat it. **Engineer:** call `UI.setZone(zone)` with the `World.Zones` name each time the controller's zone check changes (next to `Audio.setZone`); the chip stays hidden until the first call.

### Settings (built, UI plan 2026-10-27, wave 2)

A gear in the HUD's top-right icon row (left of Invite) opens Settings (`Screens/Settings.luau`, rows and logic in `Components/SettingsList.luau` with a spec): a cocoa window with one row per setting, its icon, name, a line on what it does and a chunky green ON or red OFF switch, like the settings lists of Pet Simulator 99 and Grow a Garden. The rows: 🎵 Music, 🔊 Sound effects and 📍 Place icons (the location markers). Every setting is on until the player turns it off. A tap flips the switch at once and fires `events.setSetting(key, value)`; the switch then follows `state.settings` from ProfileSync, keeping the tap for 5 s while the server catches up. A key the server does not save yet keeps the tap for the session, so Place icons works before `markers` is in the profile. Place icons hides every location marker while off.

**Engineer:** pass `settings = s.settings` in `UI.update` (cast `:: any` if the sealed table type complains). Forward `events.setSetting(key, value)` as `SetSetting(key, value)`: the server accepts only `"music"`, `"sfx"` (and `"markers"` once the data model has it) with a boolean, rate-limits it, saves it to `profile.settings` and sends it back in ProfileSync. On the client, apply music and sfx to Audio from `UI.settings.changed(key, on)` instead of from `s.settings` (read `UI.settings.value("music")` and `"sfx"` once after `UI.init` for the start): it fires on the tap (so the music stops at once), on the server's answer and when a tap the server dropped falls back, so a sync sent before the server saw the tap cannot flip the music back during the hold (review N111).

### Cafe name signs, rate tags and order bubbles (built, world-and-feel sections 3 and 4)

Nothing to call: `UI.init` starts all three and they read attributes the server and `CustomerController` already set, plus the player state.

- **Name sign** (Steal a Brainrot base signs, `Screens/CafeSigns.luau`): on every model tagged `Plot`, a local SurfaceGui on the street face of the shell's `SignBoard` part, else the code-built `Sign` part. Owned: the owner's round avatar headshot (`rbxthumb://type=AvatarHeadShot`), "<OwnerName>'s Cafe" and "<TierName>  ·  +$X/s" from the plot's `Rate`; at night (`ReplicatedStorage.Clock` `Phase == "night"`) the cafe is closed (v0.5), so the line reads "🌙 Closed  ·  +$25/s", the `Rate` times `NightIncomeMultiplier` (0.6), because cafes keep earning at night (reviewer S41). Empty plots read "FOR RENT" over "A cosy spot for a new cafe". Your own cafe has a gold edge. The server's `SignGui` in the plot is disabled on this client only, so it stays as the fallback if the UI fails to load.
- **Rate tags** (Steal a Brainrot, `Screens/WorldTags.luau`): over every model tagged `WorkingCat`, its `DisplayName` (the owner's name for it after the server's filter, else the breed; F33) in white over "+$X/s" from its `Rate` in its `Rarity` colour, shown within 40 studs. At night (`Clock` `Phase == "night"`) it reads "🌙 +$X/s", the `Rate` times `NightIncomeMultiplier`, the same number as the name sign, while the cats curl up (reviewer N88). Hidden while `Napping` is true or `Rate` is 0.
- **Order bubbles** (`Screens/WorldTags.luau`): over each customer in `Workspace.LocalCustomers` once `Order` is set ("coffee", "cake" or "milk", drawn as emoji). When `Served` turns true it pops into a pink bubble with a red heart for 1.6 s, then pops out. Customers are client-side models, so this costs no network traffic.
- **Role slot labels: removed** (Derek, 2026-10-27: "remove the place holder texts its ugly. Turn it into a section inside upgrades"). The role slots now live in the Staff tab of Upgrades (below) and the cat room's crew strip. `CafeService` no longer makes `LockLabel` (#166), so `Screens/SlotLabels.luau` and `Components/SlotLabelState.luau` are deleted.

The name signs, rate tags and order bubbles are parented under the models, so they leave with the plot, cat or customer.

### Upgrades tabs: Cafe and Staff (built, UI plan 2026-10-27)

Nothing new to call or forward: `UI.open("Upgrades")` opens it and the tabs read the state the UI already gets.

- **Cafe** (the upgrade list, fishing simulator style): one row per `Catalog.upgrades` entry with an icon box (`Theme.upgradeIcons`), the name, a star per level (gold up to the level owned), the effect line and a gold price button that reads "MAX" when maxed and "Tier 3" while a tier gate holds it. Buying fires `events.buyUpgrade(id)` as before.
- **Staff** (Derek: "slots for each role of the cafe and locked if its locked still"): a rank up card on top ("Tier 2 · Cozy Cafe", "Next: <tier> opens <what>", a "Rank up!" button in gold when every requirement is met, else "See goals"; both open the rank up card; hidden at the top tier). Under it one row per role in catalog order (`Components/StaffSlots.luau`, pure, with a spec): the role icon (`Theme.roleIcons`), the name, a summary ("1 working · 1 free · next at Tier 3", "Opens at Tier 2", "All 2 working") and a 44 px square per slot in the order the slots open. A working slot shows the cat's initial on its rarity colour, a free slot a green "+" (a tap opens the cat room, `UI.openCatRoom`), a locked slot a grey lock with "T3". "Add cat" shows when the role has a free slot and lights when a cat is resting in the cat room. Working and free need `state.cats`; without it every opened slot counts as free.

### Bait bowl (built, F28, data-model section 8)

Always on. The HUD's bottom right chip shows what is in the bowl once the Bait bowl upgrade is owned, and the chip or F opens the Bait bowl screen (or the cat waiting at the bowl). The v0.2 lure slot, its picker, `equipLure` and `equippedLure` are gone (#124 retired them on the server).

| API | Purpose |
|---|---|
| `UI.bait.setBowl(part?)` | The player's own `BaitBowl` part (call when the plot is known, like `ownDoor()`). With it, Use greys out beyond `BaitBowlRangeStuds` (12) and the bait card's buttons beyond `BaitResolveRangeStuds` (20), each with a "walk to your bowl" line. Without it the buttons stay on and the server decides. |
| `UI.bait.set(bait?)` | What is in the bowl: `{ lureId, readyAt }` with `readyAt` in server `os.time()`, nil when empty. Call it from every ProfileSync (a plain `UI.update` cannot clear a field to nil, so the bowl has its own setter). nil also closes the bait card. The rolled cat is never needed here (N30). |
| `UI.bait.openPicker()` | Opens the Bait bowl screen (also `UI.open("Bait")`, the HUD bowl chip and F). Call it from the bowl's ProximityPrompt. |
| `UI.bait.showReady(cat)` | From `BaitReady`. `cat = { catId, variant?, charm?, stars?, name? }` (a `CatView` fits). Shows the cat's 3D model (a gold cat in its own `CatCafe_Cat_<Name>_Gold` coat, F42), name, rarity, stars, charm and a GOLD sticker, with Tame and Let go (Let go asks for a second tap within 3 s, because the food is used either way). The X only hides the card; the chip and the screen's "See the cat" bring it back. After a choice the buttons wait up to 6 s for `UI.bait.set(nil)` or `hideReady`. |
| `UI.bait.hideReady()` | The server resolved the cat: closes the card and forgets it. |

The Bait bowl screen has a status card (no bowl yet with an Upgrades button, empty, "<Food> is in the bowl" with a countdown bar, "A cat is at your bowl!" with See the cat) over one card per food: shop foods by price, then dealer foods ("Sold by the night dealer's cart" until owned). Every card shows the five-rarity odds, the gold chance ("Gold 5%", `GoldChanceBait`, 5% since F42) and the charm star odds (`CharmStarOdds`, else 7.8 / 23.5 / 35.7 / 24.3 / 8.7%) before Use or Buy; Details adds the per-cat split for the player's unlocked areas and which area the next rank up adds. Use (green) and Buy are the same size. The odds text comes from `Components/FoodOdds.luau`.

In bowl mode the HUD's bottom right slot is the bowl chip, shown once `upgradeLevels.lure_bowl >= 1`: "Bait bowl / Empty · add food", "<Food> / Cat in 7m 42s", then "Cat waiting!" in gold.

Each food card has the food's picture on the left (`Components/ItemIcon.luau`): the LureDef's `asset` model from `ReplicatedStorage.Assets`, still, on a tile in its rarity colour, with a glyph from `Theme.foodIcons` until the model exists. Per-cat shares keep up to two decimals so they add back up to the rarity's share (reviewer N69).

### Night dealer (built, F32, data-model section 8b)

The Grow a Garden seed shop, for the dealer's cart: "Fresh stock in 4:12" across the top, then one card per food with its picture, name, rarity, "x2 Stock" in green or "Sold out" in red, "You have N", the odds line, the gold chance and the charm star odds, and one green price button. A food that fills two slots shows once, and Buy sends its first slot not bought yet. Details adds the food's description and the per-cat split. Cards have rarity-coloured borders.

| API | Purpose |
|---|---|
| `UI.dealer.setStock(stock?)` | From `DealerStock`: `stock = { slots = { { lureId, cost, bought } }, restocksAt }`, slots in the server's order (the slot number is the index), `restocksAt` in server `os.time()`. Send it at night start, at each window change and after every `BuyDealerFood`, bought or not: a pressed Buy shows "Buying..." until the next stock or 5 s. nil when the cart leaves at dawn, which also closes the screen. |
| `UI.dealer.open()` | Opens the dealer screen (also `UI.open("Dealer")`). Call it from the cart's ProximityPrompt. It shows "Opening the cart..." until a stock arrives. |
| `UI.dealer.setCart(part?)` | The cart part. With it, Buy greys out beyond `Config.DealerRangeStuds` with "Walk back to the cart to buy". Without it the buttons stay on and the server decides. |

Buy also greys out by day (from `UI.clock`, "Closed until nightfall"), once `restocksAt` has passed until the next stock arrives ("Fresh stock coming..."), and when the player cannot afford it. The odds come from the catalog; the price on the button is the slot's `cost` from the server.

### Rescue minigame (built, F27, data-model section 10b)

A timing bar like the ones in Fisch and other fishing games: a white marker slides back and forth along a dark bar and turns gold while it is inside the green zone; the player presses (tap anywhere, Space, click or the gamepad's A) while it is in the zone (E starts the rescue with a hold). Pips over the bar fill gold per hit and the zone slides to its next spot; a miss shakes the bar and greys a paw in the header (the catch circles' header, with the cat's name and rarity). A thin bar under it drains to the attempt's deadline, and Give up sits under the right end. "Rescued!" or "Still stuck" closes it; on a fail the prompt card comes back while the player is still at the trap.

| API | Purpose |
|---|---|
| `UI.rescue.show(rescueSpotId, challenge)` | From `RescueChallenge`. `challenge = { kind, startsAt, phase?, speed?, zoneWidth?, zones?, hitsNeeded?, paws?, endsAt?, circle?, windows? }`, times in server time. `kind` is `"bar"`, `"shake_catch"` (the same bar; the hint says each hit shakes the branch) or `"circle"` (the tree's falling cat after the shakes: one catch circle from `circle` and `windows`, header "Catch it as it falls!"). The marker is at `Shared.RescueMarker.position(startsAt, phase, speed, t)` (the server judges presses with the same module): the triangle wave of `phase + speed * (t - startsAt)` with period 2, 0 at the left end and 1 at the right, so the server can judge a press with the same three numbers; `RescueMarker.inZone(position, centre, width, RescueTolerance)` is the hit test. `zones` holds the zone centre for each hit in order. `endsAt` defaults to `startsAt + RescueAttemptMaxSeconds` (15). |
| `UI.rescue.update(rescueSpotId, hits, pawsLeft, done, success)` | From `RescueResult`, arguments in the remote's order. The server's hit count and paws replace this device's guesses (a press draws NICE! or MISS at once); `done` ends the attempt. On the circle, `done` shows the circle's result. A success then goes to carry as after a catch. |
| `UI.rescue.hide()` / `UI.rescue.isActive()` | Close without a result (the controller saw the attempt end another way), and whether an attempt is on screen. |

Events: `rescuePressed(rescueSpotId)` on every press, bar or circle (forward as `RescuePress`; the server stamps the time), and `rescueCancelled(rescueSpotId)` on Give up (forward as `RescueCancel`; the bar closes after 0.5 s without waiting). The press prompt's `rescueBegan` stays the way an attempt starts. Optional Config keys read when present: `RescueTolerance` (0.03), `RescueAttemptMaxSeconds` (15).

### Shove (built, F41, data-model section 10c)

A round orange button with a hand at the bottom right, left of the touch CATCH button, and the Q key (gamepad Y), like the push tools in Roblox brawl games. It aims at the nearest other living player within `BumpRangeStuds` (6): a small orange hand floats over their head and a tag above the button reads "Shove Alex", or "No one near" with the button greyed. It passes over players the server would refuse (reviewer S46, `Components/ShoveTarget.luau`): anyone whose UserId is the `LockedBy` of a `Stray` or `RescueSpot` (in the catch circles or the rescue bar), anyone this client shoved in the last `BumpSameTargetSeconds` (20) and, for 3 s after `UI.shove.result(false)`, the player just refused, so the hand moves to the next nearest player. The server stays the judge. A press fires `events.shove(targetUserId)` and starts a `BumpCooldownSeconds` (8) cooldown: a dark layer drains down the button over the seconds left. The three numbers come from Config. The button hides while the player carries a cat or plays the catch circles or the rescue bar (reviewer N85), so Q never meets the keys those use (Space, gamepad A and R2). The server's toasts ("You knocked it loose!", "It held on tight!", "You got shoved!") need no UI call.

| API | Purpose |
|---|---|
| `UI.shove.setEnabled(on)` | The controller's zone check: true while the player stands inside a catching area they have unlocked and `BumpEnabled` is on; false on the street, in the cafes and yards. Off by default. |
| `UI.shove.result(ok)` | Optional. `false` after a refusal lifts the cooldown at once and passes over that target for 3 s; `true` does nothing. |

### Planned in the next UI pull requests

| API | Purpose |
|---|---|
| Action pill (built) | Every `Style = Custom` prompt without a `CatId` (on the prompt, its model or its parent) gets our pill: a dark rounded pill over the prompt's part or attachment (a model's PrimaryPart) with a key cap, `ObjectText` small above and `ActionText` big ("Use" when empty), like the custom prompts in Pet Simulator 99 and Adopt Me. The key cap names the prompt's `KeyboardKeyCode` or `GamepadKeyCode` for the input it was shown for; a hold fills the cap with gold over `HoldDuration`; a trigger squashes the pill. On touch, and with a mouse when `ClickablePrompt` is on, the pill is the button and drives the real prompt (`InputHoldBegin` / `InputHoldEnd`). `UIOffset` moves it in pixels. Nothing to call: `UI.catch.bindProximityPrompts()` already draws them and raises no event, so the game handles `Triggered` as it does today. Engineer: set `Style = Enum.ProximityPromptStyle.Custom` on the bait bowl, dealer cart, manhole and Bump prompts to switch them from the default Roblox prompt to the pill; parent each to a part or an attachment at the height it should float. |
| `UI.richTip.bind(plot)` (built) | Call with your own plot model when you get it (nil to stop). Whenever its `RichTipAmount` and `RichTipExpiresAt` (server `os.time()`) show an unexpired tip, a gold bubble bobs over the plot's `RichTipAnchor` ("RICH TIP · 1:12", "💰 $1.2K", a draining timer bar) with a green Collect button under it, like the cash drops in Steal a Brainrot and Pet Simulator 99. Collect fires `events.claimRichTip()` within `RichTipRangeStuds` (12) and reads "Walk closer" further away; after a press it shows "Collecting..." for 3 s or until the tip clears. When `RichTipAmount` clears (claimed or paid at expiry) "+$X" rises gold from the coin pile and a toast says "Rich tip! +$X", so the server needs no Notify for it; a tip already waiting when you bind is shown, never toasted. The timer reads `RichTipStaySeconds` (90). Sounds stay with Audio (`RichArrive`, `RichTipClaim`). |
| Gold (was Shiny) | Built: the book's Gold pill (from `state.goldCollection`), the catch header and the reveal's sticker, and the cat room's gold cards. Still planned: the carry banner, and a Gold page in the book with its own count. Players see "Gold" everywhere since 2026-10-27; the server sends variant `"gold"`, the `Gold` attribute and `goldCollection` and migrates older saves, so the UI reads only those (`Components/CatVariant.luau`). The UI's own `shiny?` fields (`showCatFound` extra, catch `show(info)`) keep their names. |
| Rename (built, F33) | A pencil next to the picked cat's name in the cat room opens the Rename box (`Screens/RenameDialog.luau`, Pet Simulator's "Rename Pet"): the breed as placeholder, a "7/20" counter, the reason in red for a name the server would refuse (checked live with `Shared.CatName.validate`, so the rules match), and Rename / Cancel. Enter also renames. Rename fires `events.renameCat(uid, name)` with the trimmed name and closes; the server's toast and ProfileSync do the rest (the card shows "Mochi" and the picked cat "Rare Tabby" under it, from the filtered `CatInstance.name`). Rename stays grey until the name differs from the current one. Over working cats the rate tag shows the model's `DisplayName` (filtered, else the breed) in white above "+$X/s". |
| Fast travel (built, v0.4 F19; HUD v3 2026-10-27) | Bottom centre (Grow a Garden style): Equip Best (pink), a big gold My Cafe button (H), Alley and Areas. My Cafe and Alley fire `events.travel("home")` and `events.travel("alley")`; Areas opens `UI.open("Areas")`, five area cards with "Epic or better N%" and Go, locked ones greyed with "Opens at Tier n". The row hides while the catch circles show. Every travel button and Go greys while carrying (`state.carrying` or `UI.setCarrying`), and My Cafe then reads "Walk it home", since the server refuses trips while carrying; My Cafe and Alley grey for `Config.TravelCooldownSeconds` after a trip. Forward `events.travel(destination)` as `Travel(destination)`; pass `TravelResult(destination, ok, reason?)` to `UI.travel.result`, which lifts the cooldown and wobbles the button on a refusal (the server toast gives the reason). |

Removed with F26: `grabEnded`, `startRing`, `stopRing`, `expire`, `setProgress`, `RingConfig` and the `RingResult` re-export. Removed with F27: `rescueEnded`, `catch.startRescue` and `catch.stopRescue` (the v0.2 rescue hold). Removed with the lure spots (#124): `equipLure` and the HUD's lure slot and picker. Removed with F40: the v0.4 paw row on the catch card and circles (`CatchInfo.patience` and `paws`, the `Patience` and `Paws_<UserId>` reads) and `catch.showResult` (the v0.3 `CatchResult`). The rescue bar keeps its paws. Removed once the controller stopped passing them (#162): `InitConfig.baitBowl` and the ignored v0.4 paws argument of `catch.showCircles` and `catch.showGrades`.

## Events (UI -> game), all `Signal` with `:Connect(fn)` returning a connection with `:Disconnect()`

| Event | Args | Fired when |
|---|---|---|
| `buyUpgrade` | `upgradeId` | Buy pressed (UI only enables it when affordable, not maxed, tier gate met) |
| `buyDecor` | `decorId` | Buy pressed in Decor |
| `toggleDecor` | `decorId, placed` | Place / Remove pressed on an owned decor item |
| `buyLure` | `lureId` | Buy pressed on a food card in the Bait bowl screen (odds are on screen before the button) |
| `useLure` | `lureId` | Use pressed on a food in the Bait bowl screen. Forward as `UseLure(lureId)` |
| `resolveBait` | `"tame"` or `"letgo"` | A choice on the bait card. Forward as `ResolveBait(choice)` |
| `buyDealerFood` | `slot` (1 to 3), `lureId` | Buy pressed on the night dealer screen. Forward as `BuyDealerFood(slot, lureId)`; the server refuses it when that slot holds another food after a restock (reviewer S42). Then send `DealerStock` back |
| `placeCat` | `uid, spotId` | A green "+" tapped in the cat room's crew strip while a cat is picked; `spotId` is that slot (a move when the cat already works) |
| `unplaceCat` | `uid` | Rest pressed on a placed cat |
| `sellCat` | `uid` | Sell confirmed. Rare and above ask twice: Sell turns into "Sell $150", Rest turns into an equal-sized Cancel. |
| `renameCat` | `uid, name` | Rename pressed in the Rename box (F33). `name` is trimmed and passed `Shared.CatName.validate`. Forward as `RenameCat(uid, name)` |
| `equipBest` | none | "Equip Best" pressed in the cat room toolbar or on the HUD's bottom row: the server places the highest-rated cats on the open role slots |
| `unequipAll` | none | "Unequip All" pressed in the cat room toolbar: every working cat rests (forward as `UnequipAll`, engineer #175) |
| `dropCat` | none | Drop pressed on the carry banner, or G while carrying (HUD v3). Forward as `DropCat`: the server sets the cat down at the player's feet with their first try |
| `claimOffline` | none | Claim pressed on the offline popup |
| `setSetting` | `key, value` | A switch on the Settings screen: `"music"`, `"sfx"` or `"markers"`, and the new boolean. Forward as `SetSetting`; Audio follows `UI.settings.changed` (see Settings). |
| `grabBegan` | `strayId, catId` | A press on a bound stray prompt. Forward as GrabBegin. |
| `rescueBegan` | `rescueSpotId, catId` | A press on a prompt whose model has `Rescue = true`. Forward as RescueBegin; the server answers with RescueChallenge. |
| `rescuePressed` | `rescueSpotId` | A press on the rescue bar or the tree's catch circle. Forward as `RescuePress(rescueSpotId)` (F27) |
| `rescueCancelled` | `rescueSpotId` | Give up on the rescue bar. Forward as `RescueCancel(rescueSpotId)` (F27) |
| `claimRichTip` | none | Collect on the rich tip marker, within 12 studs of the anchor. Forward as `ClaimRichTip()` (F31); the server checks the owner, range and expiry |
| `shove` | `targetUserId` | The Shove button or Q, aimed at the nearest other player within 6 studs. Forward as `Bump(targetUserId)` (F41); the server checks the area, range, locks, cooldowns and safe zones |
| `screenOpened` | `name or nil` | Modal opened or closed |
| `catchPressed` | `strayId, index, grade` | A press on circle `index` (1-based) with the device's grade hint. Forward `strayId, index` as CatchPress; `grade` is for the instant NetSwing and CircleGrade sounds only. |
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
    lures: { [lureId]: number },
    -- engineer extras the UI uses when present
    cats: { [uid]: { uid, catId, variant?, name?, caughtAt?, spotId?, rescued?, method?,  -- enables the Cat room tab
                     level?, xp?, xpToNext?, charm?, stars?, rating? } }, -- cat stats thread; shown when present
    collection: { [catId]: firstCaughtAt },                        -- drives "?" silhouettes and the 7 / 50 count
    goldCollection: { [catId]: firstGoldAt }?,                     -- the book's Gold pill (was shinyCollection before 2026-10-27)
    carrying: string?, tutorialStep: number?,
    settings: { music: boolean, sfx: boolean, markers: boolean? }?, -- profile.settings; a missing key reads as on
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
- Stray prompt attributes (on the model, data-model section 13): `StrayId`, `CatId`, `CatName`, `Rarity`, plus `Stars` and `Charm` from the cat stats thread; prompt `Style = Custom`. A stuck cat adds `Rescue = true` and `RescueSpotId` (the id RescueBegin, RescuePress and RescueCancel take; falls back to `StrayId`).
- Clock folder (`ReplicatedStorage.Clock`, data-model section 9): attributes `Phase` ("day" or "night") and `PhaseEndsAt` (server `os.time()` seconds).
- Catch timing lives in `Shared.Config` and the schedule: the circles' bands come from `CatchSchedule`'s windows, the miss cut-off from `CatchLatencyCapSeconds`, the rescue bar from `RescueChallenge` with `RescueTolerance` and `RescueAttemptMaxSeconds`.
- Currency is coins shown as `$` (`Theme.currencySymbol`).

## Not in scope for the UI thread, and space left for later

Remotes, validation, rate limits, data saving, cat AI, decor placement in the world, localization (strings sit in the screens, ready to pull out). Planned screens with room reserved: leaderboards and settings (P2, modal screens), event banner (HUD top centre under the travel row, post-slice), a "Closed" state on the HUD rate if tips pause at night (questions-for-gavin.md question 10).

## Check gate status

CI runs the full gate (rojo sourcemap, luau-lsp 1.70 analyze, selene, stylua --check) on every pull request. The UI thread also runs luau-lsp 1.70 with the real sourcemap, selene and StyLua before each push.

## Mockups

`docs/concepts/cat-cafe/ui/index.html`: HUD at 1280x720, phone at 812x375 with the catch ring and GRAB button, carry banner, Upgrades, Decor, Collection (Book and Cat room tabs), lure picker with odds and Details, popups and toasts, tokens and rules. Built from the asset thread's cat renders.
