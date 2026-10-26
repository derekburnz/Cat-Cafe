# Cat Cafe World, Look and Feel (design v0.4)

Draft v0.4, 2026-10-26. Owner: game-designer thread. Readers: engineer, asset-artist (3D), ui-designer, vfx-animator, sound-designer, QA, reviewer. Numbers for catching are in [data-model.md](data-model.md) section 10, build rows F34 to F39 in [features.md](features.md) section 2b.

Derek, after playing the rough draft (2026-10-26 23:03): "mainly focus on making the game clean looking and playable the sketch of how the cafes should look was much better looking also don't make the empty tycoons look so dull and boxy maybe have the peoples cafes more lively and also figure out how the actual alleyway should be accessible it takes too long to run towards it and also is wayyy to small focus on copying ui's and design of other roblox games for a lot of these features" and "fix the catching features and making the game actually matter if you miss the catch windows etc..."

So v0.4 changes five things: missing a circle costs you the catch, the Alleyway moves behind the cafes and gets much bigger, cafes look like the concept sketch and feel busy, empty plots look like closed shops instead of grey boxes and the UI copies patterns players already know from the biggest Roblox games. Mechanics can be borrowed; names, characters, art and audio stay ours.

## 1. Catching: a miss costs you

Today a Miss only lowers the averaged chance, and a Common stays put with a 2 second retry, so missing costs nothing. v0.4 borrows from Fisch, where letting the fish slip means it is gone:

- Any Miss ends the catch on the spot. A press outside the Good band, no press by the circle's deadline or walking out of range all count. The cat hisses, jumps back 6 to 10 studs and the circles left over vanish. There is no roll.
- No Miss means caught. Every circle Good or Perfect is a sure catch. Pressing well always works, so a near miss never turns into a coin-flip loss.
- Patience paws. Each stray has a row of paws per player: Common 3, Rare 2, Epic 2, Legendary 1, Mythical 1. A failed catch costs you one paw on that cat. At zero the cat stops trusting you for the rest of its stay: your prompt disappears and a small hiss icon sits over it for you. Other players still have their own paws, so nobody can burn a Legendary for everyone by missing on purpose (reviewer, 2026-10-26).
- After a miss you wait StrayWarySeconds (5) before trying that cat again; everyone else waits GrabRetrySeconds (2) while it lands from its jump.
- Perfects pay. Every Perfect circle adds 4 charm to the cat you catch, and an all-Perfect "Purrfect" catch doubles it, capped at 100. A Purrfect Mythical (five circles) gains 40 charm, which is up to two stars and about 16% more income for that cat. The card shows "Charm +8" and the stars ticking up. Re-catching a cat knocked loose by a bump gives no bonus, since it already has its charm (reviewer S36).
- Never lost to bad luck: on a Dropped stray the player who was carrying it has unlimited paws (the S26 rule that a bump never loses a kid's cat), and so does a new player (tutorialStep below 2) on the tutorial Common.

Why this shape: the server already judges every press on its own clock, so the change is in what happens after a judged Miss, not in timing. Paws make a Legendary tense (one chance) without letting a griefer delete it for others. Charm from Perfects keeps a reason to aim for the centre now that Good also catches. Net durability was considered and dropped: repairing nets is a chore, punishes the youngest players and drifts toward pay-to-repair.

Readability, copied from rhythm games and Fisch: each circle pops PERFECT (gold), GOOD (green) or MISS (red) at the ring; a Miss gives a small camera shake, the hiss sound and the cat leaping back; the paw row sits under the ring and over the stray's head, losing a paw with a little pop. "It slipped away! 2 paws left" and, at zero, "It won't trust you tonight". A Purrfect plays a gold burst and a chime.

## 2. The world: Alleyway out back

The engineer moved the Alleyway behind the cafes (2026-10-26), matching the concept sketch's back door to the alley. The design follows it:

- Every cafe has a back door that opens from Tier 1 onto a back alley running behind its row. The two back alleys meet in a big Alley Square at the north end. Check-in works at either door.
- Distance targets for the engineer to tune against: under 2 seconds from a back door to the nearest stray spawn, under 8 seconds from any cafe to the far side of the Alley Square, under 10 seconds from any cafe to any unlocked area gate. Anything farther gets a travel button.
- Size target: at least 8 times the old 60 x 44 stud box, so 10 strays, 3 traps and 8 players never crowd. The back alleys are the narrow, cosy part; the Square is the open hub.
- Spawn points: 24 in the Alleyway, two behind every cafe (16) and 8 in the Square. Commons and Rares can spawn anywhere; Epic, Legendary and Mythical spawn only in the Square, so the exciting cats are a short run from everyone and nobody's cafe is the lucky one.
- Traps: one trash bin in each back alley and the garbage bags in the Square.
- Square landmarks so it is not a flat box: a dumpster corner, stacked crates you can hop on, a fire escape with a ledge (one spawn point up there), a laundry line, puddles that shine at night, string lights across the gap, a big wall mural of our own cats, a bench under a street lamp.
- The other areas open off the hubs: the Park gate at the south end of the street, the Woods beyond the far side of the Park, the Neighbourhood through a fence gate on the Square's east side, the Sewer down a manhole in the middle of the Square (it opens at Tier 5). Final spots are the engineer's.
- Walk speed rises to NormalWalkSpeed 20 and CarryWalkSpeed 16 (still 80%), the Roblox default of 16 felt slow for this map. Bump range and safe radius are unchanged.

Gates, copied from Pet Simulator 99 and Bee Swarm Simulator: an arch with a glowing barrier you can see through, a sign with a lock icon and "Park, needs Cozy Cafe (Tier 2)", and under it your progress ("3 / 5 cats, $900 / $1,500"). The first time a gate opens for you the barrier dissolves with confetti. Walking into an area shows its name as a big title card for two seconds ("THE ALLEYWAY"), the way Pet Simulator and Fisch name zones.

Fast travel (F19, now P0), copied from Grow a Garden's buttons along the top of the screen: three buttons top centre, Cafe, Alley and Areas. Areas opens a small panel of five area cards, locked ones greyed with the tier they need. Travel lands you at the area's entry, not in the middle. All of them are greyed while you carry a cat ("Walk your cat home first"), so carrying and bumps still matter. A 3 second cooldown.

## 3. Cafes that look like the sketch

The target is the Three Game Sketches cafe (Cozy Cream): warm, cluttered, readable from the street. Rules against "dull and boxy":

- Shape. A pitched or rounded roof with an overhang and a chimney, never a flat lid. The front breaks up the wall: two big arched windows, a recessed door with a step, corner trim, a striped awning sticking out 3 studs, a trim band under the roof.
- See inside. The street side is mostly glass, so people walking past see the cats at work, the way Steal a Brainrot's open bases show off what is inside. When you are inside your own cafe the roof fades out on your screen only, giving the sketch's cutaway view.
- Color. Each plot's facade gets a different pastel from the Cozy Cream palette by plot number, with cream trim, so the street reads as a row of shops. One owner accent (the awning stripe and door) can be picked later.
- Interior from the sketch: plank floor, wainscoting with wallpaper above, pendant lamps, a menu board over the counter, a pastry case, framed pictures of our cats, a rug, cushions and the cat tree.
- Out front: a chalkboard stand, flower boxes, a bench, a lamp post and a short path, so every plot has a little garden strip.
- Name sign. Over the door: the owner's Roblox avatar headshot, "Derek's Cafe", the tier name and the cafe's tips per second ("$42/s"), like the base signs in Steal a Brainrot. Readable from the street.
- Tiers you can see from the street, the tycoon habit of making progress visible: Tier 1 awning and chalkboard; Tier 2 flower boxes and one bistro table outside; Tier 3 neon OPEN sign, string lights and a second bistro table; Tier 4 the backyard patio between the cafe and the back alley (the F24 expansions) and a fish tank in the window; Tier 5 gold trim, a rooftop sign and a red carpet at the door. Each rank up plays a puff of smoke and confetti as the new pieces appear.

## 4. Cafes that feel alive

- Customers walk in from the street, queue at the counter, sit and get served. A small order bubble (coffee, cake, milk) pops over each one and turns into a heart when the waiter brings it. A coin pops "+$12" over the table for the owner; other players see a small sparkle. At night a few night owls in pyjamas and with lanterns.
- Working cats animate at their stations: the barista taps the espresso machine, the waiter carries a tray between tables, the greeter waves at the door, the entertainer bats a yarn ball on the cat tree. Over each one a small tag in its rarity color shows its rate ("+$3/s"), visible within 40 studs (Steal a Brainrot).
- Cats without a job do not vanish into a menu. Up to four of them wander the cafe and nap on cushions, the window sill and the cat tree, so your collection is on show. Highest rating first; the rest stay in the cat room.
- Ambient life: espresso steam, chimney smoke, swinging string lights, butterflies by the flower boxes by day, fireflies and glowing windows at night, a sparkle on every shiny. Sound: soft chatter and cup clinks near the door, a purr when you walk past a working cat.
- Budget: each cafe's extra life is culled beyond 80 studs and roaming cats pause when no player is within 60 studs, so eight busy cafes still run on a phone. The vfx-animator measures it in docs/vfx/cat-cafe/.

## 5. Empty plots: closed for rent, never grey boxes

A server has 8 plots and often fewer players. An empty plot uses the same cafe shell and pastel facade as a running one, so the street stays complete, dressed as a shop between owners:

- Shutters half down over the windows, dust sheets over the furniture inside, warm light behind the shutters at night.
- A hanging "For Rent" sign with a little cat silhouette, a stack of boxes and a broom by the door, a potted plant, the lamp post on at night.
- A sleeping cat on the doorstep with floating "z"s. It is decoration only and cannot be caught.
- Later (P2): an "Invite a friend" prompt on the sign that opens the Roblox invite window.

When a player joins, their plot does the reverse with a quick transition: shutters roll up, the sign flips to OPEN, lights come on and the Tabby walks in.

## 6. UI patterns to copy

Players already know these from the top Roblox games, so they need no teaching. The UI thread owns the layout and ui-contract.md; this is the list of patterns the design wants.

| Pattern | Where it comes from | What we copy | P |
|---|---|---|---|
| Travel buttons | Grow a Garden | Cafe, Alley and Areas buttons top centre, greyed while carrying | P0 |
| Catch circles | rhythm games, Fisch | Approach circle onto a ring, PERFECT, GOOD and MISS pops, paw row, shake and hiss on a miss | P0 |
| Gate signs | Pet Simulator 99, Bee Swarm Simulator | Lock, requirement and your progress on a billboard at the gate; barrier dissolves when you qualify | P0 |
| Money and rate | Steal a Brainrot, most tycoons | Coins top left with "+$42/s" under them, as in the sketch | P0 |
| Next goal tracker | Pet Simulator 99 quests | One card on the right: "Next: Cozy Cafe" with a bar per requirement; tap opens the rank up card | P1 |
| New cat reveal | Pet Simulator egg hatch | Rays in the rarity color, the cat pops in, rarity banner, NEW sticker, stars filling one by one, Purrfect charm bonus | P1 |
| Side menu | Pet Simulator 99, Grow a Garden | A vertical stack of big icon buttons on the left with short labels and red dots when something is new (Cats, Shop, Book, Bait) | P1 |
| Rate tags | Steal a Brainrot | "+$3/s" over each working cat and the cafe total on the name sign | P1 |
| Area title card | Pet Simulator 99, Fisch | Big area name for two seconds on entry | P1 |
| Dealer restock list | Grow a Garden seed shop | A list of the three foods with stock left and "Restock in 4:12" at the top | P1 |
| Server shout-outs | Pet Simulator 99 | "Derek caught a Mythical Midnight!" in the rarity color, with a small sound | P1 |
| Tutorial path | Pet Simulator 99, many simulators | A glowing trail on the ground from you to the next goal | P1 |
| Collection book | Pet Simulator index | Grid per area with silhouettes for cats not found yet and a completion percent | P1 |

Style rules, from the sketch: one chunky rounded font (FredokaOne) with a dark UIStroke outline, rounded panels, rarity colors on borders, green 3D buttons with a darker bottom edge, big tap targets for phones. Fewer floating labels: world labels only within 30 studs, and never more than one per cat.

## 7. Who builds what

- Engineer: F34 catching stakes, F35 world layout v2 with back doors and the Square, F19 Travel remote, plot state (For Rent or owned) and the tier dressing swap, the roaming cats and customer life in F37.
- Asset-artist: the cafe shell (roof, windows, awning, trim, back door) with tier dressing sets, the For Rent dressing, Alley Square landmarks, back alley dressing, gates with see-through barriers, a sleeping doorstep cat pose, customer order bubbles as world props if they are not UI.
- UI-designer: the table in section 6, starting with the P0 rows, and the paw row and miss feedback on the catch HUD.
- VFX-animator: miss hiss and jump-back, Purrfect burst, gate dissolve, rank up confetti, shutter roll-up, station idles for the four roles, napping loops, steam, smoke, butterflies and fireflies within the budget.
- Sound-designer: hiss, paw lost, Purrfect chime, gate open, shutters, cafe ambience bed, purr near working cats, shout-out sting.
- QA: the checks in section 8.

## 8. Acceptance checks for QA

1. A Miss on circle 1 of a Rare ends the catch at once with no roll; the cat jumps back and the paw row shows 1 left. A second Miss and the prompt is gone for you but still there for a second player.
2. Any mix of Good and Perfect catches every time over 20 tries. An all-Perfect Common arrives with 8 more charm than the stray showed.
3. A bumped carrier can miss their own dropped cat five times and still try again.
4. From the farthest cafe's back door, a stray spawn is under 2 seconds away; the far side of the Square is under 8 seconds at walk speed 20.
5. With one player on the server, the other seven plots show For Rent shops with no grey boxes; joining a second player rolls their shutters up.
6. From the street, you can see cats working inside a running cafe, and its sign shows the owner's name, tier and rate.
7. Travel buttons are greyed while carrying and work from anywhere otherwise.
8. A phone-sized viewport keeps 30 or more frames per second standing in the street with eight running cafes.
