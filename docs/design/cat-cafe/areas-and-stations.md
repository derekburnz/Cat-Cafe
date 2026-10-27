# Cat Cafe Areas 3 to 5 and World Stations (design v0.6 draft)

Draft v0.6, 2026-10-27. Owner: game-designer thread. Readers: asset thread (3D), engineer, ui-designer, vfx-animator, sound-designer, QA. Contract numbers are in [data-model.md](data-model.md) (section 3c for the cats, 11c for the spin wheel), build rows in [features.md](features.md) (F49 and F50).

Derek, 2026-10-27 14:35: "you draft some ideas for models for those places you can lookup other roblox games and draft similar objects and environments". And 14:36, in the UI thread: "to make the ui less cluttered I see games make things have like drop down arrows to close menus and stuff also things like spins could be an area you walk up to".

Part A gives each locked area a theme, a layout, its landmarks, where strays hide, its two rescue traps, its object kit and its six themed cats. The asset thread turns that into model drafts and renders for Derek to pick from. Part B moves the spin wheel and other once-a-day rewards out of the HUD and into the world as stations you walk up to. Mechanics and layouts are borrowed from other games; every name, model and picture is ours.

## Part A. Neighbourhood, Woods and Sewer

### A1. Rules for all three

- No new mechanics. Each area reuses the Alleyway's systems: 10 strays per night wave, the catch circles, two rescue traps that use the existing kinds (`bar` or `shake_catch`), carry and shove, a gate, a title card. What makes an area different is its look, its sounds, where cats hide and its cats.
- Size: the floor you can walk on is at least as big as the Park and at least 100 x 90 studs, so 10 strays, 2 traps and 8 players never crowd. Today's grayboxes are smaller (about 66 x 64 for the Woods and Sewer, 90 x 56 for the Neighbourhood), so the engineer grows them when the sets arrive.
- One hub per area. As in the Alley Square, Epic, Legendary and Mythical strays spawn only in the area's open hub, so the exciting cats are easy to find. Commons and Rares can spawn anywhere.
- Spawn points sit in the area's hiding spots (the "strays hide" lists below), always reachable on foot and never more than 6 studs up.
- Every area has an Index Board at its entry (Part B), a SAFE ZONE stripe where it meets the street side and its own night lighting.
- Nothing in an area hurts players, and nothing is gross or scary. The Sewer is a hidden canal town, not a dirty drain.
- Kit names follow the asset files on main: `CatCafe_<Area>_<Object>`, pivot at the base centre. The gates already exist (`CatCafe_Neighbourhood_Gate`, `CatCafe_Woods_Gate`, `CatCafe_Sewer_Gate`, `CatCafe_Sewer_Manhole`).

### A2. Neighbourhood (Tier 3): a sunny cul-de-sac

Look: a pastel suburb at the end of a quiet street. Five or six house fronts face a loop road, with front lawns and low picket fences. Gaps in the fences lead to two back gardens, and cats squeeze through those gaps. By day the sprinklers tick and a radio plays somewhere. At night porch lights and windows glow, one window has a cat silhouette and crickets chirp.

Borrowed from: Brookhaven and Welcome to Bloxburg (suburban lots with driveways, mailboxes and lawns), Adopt Me (a friendly neighbourhood of houses), Pet Simulator 99's Backyard and Cozy Village (fenced yards, sheds and garden clutter).

Layout: the gate opens onto the loop road. The circle in the middle of the loop is the hub: a playground with a slide, swings and a sandbox under a big oak with a tyre swing. Houses ring the loop, and the two back gardens sit behind them.

Landmarks: the playground and the tyre swing oak, a parked ice cream van (decor only, no shop), a garage with its door half up, a kiddie pool and a trampoline in one back garden, a BBQ grill and garden gnomes in the other.

Strays hide: on porch steps and under porch benches, in flower beds, on fence tops, under the slide, in the sandbox, on the trampoline, behind recycling bins, under the ice cream van.

Rescue traps:
- `shed`, kind `bar`: a cat is stuck in a garden shed with a jammed door, and the bar wiggles the door loose.
- `gutter`, kind `shake_catch`: a cat is stuck in a roof gutter. Hits shake the drainpipe, the cat drops and one circle catches it, as with the Park tree.

Kit (`CatCafe_Neighbourhood_<Object>`): HouseFrontA, HouseFrontB, HouseFrontC (two storeys, porch, pastel walls, windows that glow at night); PicketFence (straight, corner, gate); Mailbox; Hedge; FlowerBed; GardenGnome; Sprinkler; KiddiePool; Trampoline; Slide; Swings; Sandbox; TyreSwingOak; Garage; BBQGrill; IceCreamVan; RecyclingBins; GardenShed (trap); DrainpipeGutter (trap, on a house corner); StreetSign ("Whisker Lane"); LampPost; Bicycle; LoopRoad tiles; IndexBoard (cork board).

Themed cats (ids and favorite roles unchanged; names, one-line descriptions and props in data-model 3c):

| id | name | rarity | role | prop (slot) | coat idea |
|---|---|---|---|---|---|
| munchkin | Skater Cat | Rare | entertainer | skateboard strapped to its back (Back) | Munchkin, short legs, grey and white |
| fold | Painter Cat | Rare | waiter | beret with a paint splat (Head) | Scottish Fold, folded ears, cream with paint-coloured toe tips |
| chonk | Chef Cat | Epic | barista | tall chef hat (Head) | big orange and white, scale 1.25 |
| postie | Mail Cat | Epic | greeter | mail carrier's cap (Head; a satchel would clip the greeter sash) | blue-grey shorthair |
| marshmallow | Super Cat | Legendary | waiter | red hero cape (Back); effect: the cape flutters and leaves a short whoosh trail | fluffy white long coat |
| comet | Ice Cream Cat | Mythical | entertainer | ice cream cone hat with a cherry (Head); effect: sprinkles float off it | strawberry and vanilla swirl with sprinkle specks, soft glow |

### A3. Woods (Tier 4): a storybook forest

Look: tall pines and big round oaks along a winding dirt path, with a stream crossed by stepping stones and a little wooden bridge. By day it has golden light and birdsong. At night fireflies drift, a fairy ring of mushrooms glows and the campfire crackles.

Borrowed from: Bee Swarm Simulator (the Pine Tree Forest and Mushroom Field), Pet Simulator 99 (Green Forest, Mushroom Field, Enchanted Forest, Firefly Cold Forest), Fisch (Mushgrove Swamp's misty boardwalks and the Lost Jungle's glowing garden).

Layout: the gate opens onto the path, which crosses the stream on the bridge and ends in the hub, a clearing around the Great Oak. The Great Oak is a giant hollow tree whose roots make nooks. A campsite and a treehouse sit off the path.

Landmarks: the Great Oak, the campfire clearing with tents and log benches, a treehouse with a rope ladder, the glowing mushroom ring, a ranger lookout tower, a small waterfall pond.

Strays hide: in hollow stumps, under ferns, on mossy rocks, along fallen logs, under the bridge, inside tents, in the Great Oak's root nooks, in leaf piles that rustle when a cat is inside.

Rescue traps:
- `hollow_log`, kind `bar`: a cat is wedged in a fallen hollow log.
- `bramble_bush`, kind `bar`: a cat is tangled in brambles, and the bar parts them.

Kit (`CatCafe_Woods_<Object>`): PineTall; OakRound; GreatOak (hub landmark); Stump; FallenLog; HollowLog (trap); BrambleBush (trap); Fern; MushroomSmall; MushroomGlowing; MushroomRing; MossyRock; Stream; SteppingStones; WoodBridge; Tent; Campfire; LogBench; Treehouse; LookoutTower; BerryBush; LeafPile; Signpost; Lantern; WaterfallPond; IndexBoard (carved wood).

Themed cats:

| id | name | rarity | role | prop (slot) | coat idea |
|---|---|---|---|---|---|
| pinecone | Scout Cat | Rare | barista | little backpack with a bedroll (Back) | brown tabby |
| forest_cat | Lumberjack Cat | Rare | greeter | red plaid cap with ear flaps (Head) | Norwegian Forest Cat, red-brown, scale 1.2 |
| toadstool | Mushroom Cat | Epic | entertainer | red-spotted mushroom cap (Head) | cream with rusty red patches |
| firefly | Firefly Cat | Epic | waiter | jar of fireflies on its back (Back) | dark brown, a tail tip that glows yellow at night |
| old_oak | Antler Cat | Legendary | barista | mossy antlers with tiny flowers (Head); effect: drifting leaves | deep brown with a leafy pattern |
| wisp | Unicorn Cat | Mythical | greeter | glowing horn (Head); effect: a sparkle trail | white with a pastel rainbow mane, glow |

### A4. Sewer (Tier 5): the hidden canal town

Look: brick tunnels under the city where glowing teal water runs in canals. Big pipes pour little waterfalls into the canals, and lost cats have built a town out of junk: bottle caps, tin cans, crates and lost toys. Glowing mushrooms and wall lanterns light it, drips echo and a beam of daylight falls down the manhole shaft. It should feel like a secret base, never dirty or scary.

Borrowed from: DOORS (the flooded Sewage Cells with a waterfall and ladders, made friendly), Fisch (the Mineshaft's minecart rails and levers, the glowing Luminescent Cavern), Pet Simulator 99 (Crystal Caverns and Colorful Mines for the glow). The manhole drop is already built (`CatCafe_Sewer_Manhole` in the Alley Square).

Layout: you drop through the manhole under the daylight beam and climb down a ladder to a landing. A catwalk runs along the main canal to the hub, a round pool under the big pipe waterfall. Side tunnels hold the junk town.

Landmarks: the daylight shaft, the big pipe waterfall pool, the Bottlecap Throne (a junk-built throne on a crate platform), a wall of valve wheels, an old maintenance cart on rails, a heap of lost toys, our own paw-print graffiti.

Strays hide: in big pipe ends, on ledges and catwalks, behind valve wheels, in the lost toy heap, on floating crates, under the throne, in the maintenance cart.

Rescue traps:
- `drain_pipe`, kind `bar`: a cat is stuck in a narrow side pipe.
- `grate`, kind `bar`: a cat is under a floor grate, and the bar lifts it.

Kit (`CatCafe_Sewer_<Object>`): TunnelStraight; TunnelCorner; TunnelArch; CanalWater (glowing); Catwalk; Ladder; PipeLarge; PipeElbow; PipeOutlet (waterfall); ValveWheel; Grate (trap); DrainPipe (trap); MaintenanceCart; Rails; CrateStack (reuse the Alley crates); LostToyPile; BottlecapThrone; GlowMushrooms; WallLantern; PawGraffiti; DripPuddle; DaylightShaft; IndexBoard (tin sheet).

Themed cats:

| id | name | rarity | role | prop (slot) | coat idea |
|---|---|---|---|---|---|
| lantern | Miner Cat | Rare | waiter | hard hat with a lamp (Head) | soot grey |
| bubbles | Bubble Cat | Rare | entertainer | bubble pipe in its mouth (Face) | pale blue-grey |
| gears | Steampunk Cat | Epic | barista | brass goggles (Face) | copper tabby |
| glimmer | Diver Cat | Epic | greeter | snorkel and mask (Face) | teal-grey with a white belly |
| bottlecap | King Cat | Legendary | waiter | crown made of bottle caps (Head); effect: the caps glint | caramel and bronze (not gold, so it never looks like a gold cat) |
| eclipse | Dragon Cat | Mythical | barista | little dragon wings (Back); effect: tiny harmless sparks and smoke puffs | emerald to teal scales, glow |

### A5. For the asset thread

1. Draft the three kits as renders, one sheet per area with the hub vignette, so Derek can pick (Derek picks before anything is wired).
2. Then the six themed cats per area on the new cat body, with their props baked in the way #201 does it (`PropSlot` attribute, `CatCafe_Cat_<Name>_Prop` parts).
3. Each area's Index decor piece is already in data-model section 7: Mailbox Planter, Mushroom Lamp and Pipe Fountain, plus their gold versions.
4. The vfx-animator owns the effects named above (sprinklers, fireflies, the glowing ring, waterfalls, the daylight beam), and the sound-designer owns the area ambience.

## Part B. World stations

### B1. What moves into the world

Derek's rule: things you visit now and then become places you walk to, and the HUD keeps only what you use all the time. Popular simulators do the same. Bee Swarm Simulator has dispensers and the Wealth Clock you walk up to for an hourly reward, and Pet Simulator 99 puts its machines and the Diamond Wheel in the world.

| Feature | Where it lives | Why |
|---|---|---|
| Spin wheel (F49) | The Spin Wheel station in the street plaza | Derek's ask; a spin is a little event worth walking to |
| Daily Treat calendar (later, common-features 11) | A treat stand next to the wheel | Once a day, like the wheel |
| Night food dealer | Already a world cart; it parks in the same plaza at night | Every reward and shop stop is in one spot |
| Mail (later) | A mailbox on each cafe's front path; the flag goes up when mail waits | Your mail comes to your cafe |
| Codes | Stay in Settings, where players look for them; the prize goes to the mailbox | |
| Index | Stays a HUD button, because players check it everywhere, even mid-chase. Each area also gets an Index Board at its entry (F50) | |
| Tip Jar | Stays on the HUD, because the countdown is the point | |
| Bait bowl | Already in the world on the back step | |
| Cats, Upgrades and Staff, Decor | Stay HUD screens; the UI thread's collapsible menus answer the clutter | |

### B2. The street plaza

- All the stations stand together in the safe zone on Cafe Street, so one place marker ("Plaza") covers them and nobody can be shoved while spinning.
- Preferred spot: the street's north end in front of the Alley Square arch, where every player passes on the way to the Square. The engineer picks the exact spot from the layout, under 10 seconds on foot from any cafe door at NormalWalkSpeed 20.
- Dressing: bunting across the street, two benches, a lamp post, a big hanging "Cat Cafe" street sign. The dealer cart parks here at night.
- The place marker shows a red dot while a free spin is waiting (UI).

### B3. Spin Wheel station (F49)

Model `CatCafe_Street_SpinWheel`, about 12 studs tall: an upright wheel with six slices in the Cozy Cream pastels, a cat-ear frame, a paw-shaped pointer at the top and blinking rim lights, standing on a small striped booth. Parts the code uses:
- `Wheel`: the turning part or model, pivot at the hub, turning about its own front axis.
- `Face`: on the wheel, with a SurfaceGui per slice so prizes and chances come from data.
- `Pointer`: the paw at the top. At rest slice 1 sits under it, and slices 2 to 6 follow clockwise in `Catalog.spinWheel` order, so the art matches the code (reviewer S64).
- `PromptAnchor`: an Attachment at the front, 3 studs up, for the prompt.
- `RimLight` parts: for the blink.
- The station root is tagged `SpinWheel`.

How it plays:
1. Walk up and hold E on the "Spin" prompt (0.5 s, like a catch). The Spin window opens (UI). It shows the six slices, each with its prize and its chance, your spins ("Spins: 2"), the time to the next free spin and a big Spin button.
2. Press Spin. The server picks the slice and pays straight away, so leaving mid-spin never loses a prize. Your window spins for about 4 seconds and lands in the middle of the prize's slice with a burst. It never creeps past a bigger prize or stops on a slice edge to look like a near miss (reviewer N127). The world wheel turns for everyone at the same time and stops on the slice you won (`LastSlice`), so the plaza looks busy and never shows a different prize.
3. Spins come free: one free spin every day (it resets at 00:00 UTC, and missed days do not stack), plus one banked spin from each of Tip Jar steps 11 and 12. The Daily Treat's day 7 adds one later. You can bank up to 20.
4. Spins are never sold for Robux, no pass gives spins, no Robux item adds a spin or speeds up a spin source and no Robux button appears in the window (monetization-policy, reviewer N126). A spin never gives a cat: cats only come from catching, rescuing and bait (round 3 Q17).

Slices, prizes and server checks are in data-model section 11c.

### B4. Index Boards (F50)

- Model `CatCafe_<Area>_IndexBoard` for every area: a noticeboard at the area's entry, inside the gate, styled to the area (brick for the Alleyway, wood for the Park and the Woods, cork for the Neighbourhood, tin for the Sewer).
- Its `Screen` part, 8 x 5 studs, shows a SurfaceGui. Because the board differs for every player, the SurfaceGui lives in PlayerGui with its Adornee set to `Screen`, and it is re-adorned when the board streams back in (reviewer N129). It shows the area's ten cats: silhouettes for the ones you have not found and portraits for the ones you have, with "6 / 10", the gold count and a red dot when an Index reward is ready.
- The prompt "Index" (hold E 0.5 s) opens the Index on that area's page, where the Claim buttons already are (F48), so the board needs no new remote.
- A locked area's board still shows from outside the gate, with the silhouettes and "Opens at Tier 3", as a teaser.

### B5. Acceptance checks for QA

- From any cafe door the plaza is under 10 seconds away on foot, and its marker shows a red dot while a free spin waits.
- A new day's first spin is free. A second spin that day with nothing banked is refused, and the window says when the next free one comes.
- Leaving the game during the spin animation keeps the prize.
- Every slice shows its chance, and the chances add up to 100%.
- Nothing in the Spin window mentions Robux.
- Two players spinning at once each get their own result, and the world wheel turns for both.
- Each area's Index Board shows the right count and opens the Index on that area's page.
