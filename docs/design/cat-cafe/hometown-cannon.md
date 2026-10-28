# Hometown and the Cat Cannon (town layout v4, 2026-10-28)

Status: proposed by the game-designer thread at 13:55, waiting on Derek's OK. Revised at 14:00 from QA-Planner's, VFX-Agent's and UI-Engineer's notes: seventeen landing spots, the night sweep during a flight, the camp's edge, drops at its opening, the effect hooks and a picker that lists only open areas. Features F84 (hometown, cannons, camps) and F85 (longer rectangular areas).

Derek, 2026-10-28, in four messages at 13:39 to 13:42:

- "I am thinking about making the hometown with all the cafe's and markets separate from all the areas and have a cannon in the middle you hop into then choose your area and it shoots you to the area showing a quick cannon animation with your character into a brief cloud cutscene while it teleports your chracter into another area in the background (same server)"
- "Have each of the areas after cannon have a little safe area where it starts and cats are considered "caught" if you reach it and either a portal or cannon back to the spawn area/other areas"
- "make sure to still block the teleporting to cat cafe when holding a cat in those wild areas"
- "then each area can be expanded even more make it so most of the rescues are deeper in each area and try and focus on making the areas more rectangular with longer paths so that when running back with cats people might see and tackle you more often rather then maps square shaped and its a quick easy escape"
- "thinking about using cannons for all areas to transport"

Studs, y 0 is the floor top, world X runs across the street (west is -X) and Z along it (south is -Z), as in [town-layout-v3.md](town-layout-v3.md). Where this file differs from town-layout-v3 sections 7 and 8, this file wins once Derek says yes.

## 1. What changes

- **The hometown** is the town as it stands: Cafe Street, the Town Square with its stations, the eight cafes and the Alleyway behind them. It loses its four area gates. The four wild areas (Park, Neighbourhood, Woods, Sewer) move far away in the same place, out of sight of the town and of each other.
- **The Cat Cannon** stands in the middle of the Town Square, where the fountain is. You hop in, pick an open area, and it fires you up into the clouds. The server moves your character to that area while the clouds cover the screen, and you drop onto the area's landing camp. It is the only way into a wild area.
- **Camps.** Every wild area starts with a small safe camp at one end. A carried cat counts as caught the moment you walk into the camp. The camp has its own cannon back to town or on to the other open areas. We use cannons everywhere, as Derek leans; section 9 says where a portal would have been simpler.
- **No teleport with a cat.** Holding a cat in a wild area, the only way to keep it is to carry it into the camp. Home and every other jump are refused while carrying, as Travel already is.
- **Longer, narrower areas** (F85, after F84). Each wild area becomes a long rectangle with the camp at one short end, so the run back with a cat is long and in view, and most rescue traps sit in the far half.

The Alleyway stays behind the cafes as the hometown's own beginner area: no cannon, and cats are checked in at your back door as now. That keeps the Tier 1 start, the intro's first catch and the bait bowl on the back step exactly as they are. It also makes the cannon the Tier 2 reward. Derek can pick the other way (the Alleyway as a fifth cannon area) on the decision card.

## 2. The hometown

| piece | town v3.2 | v4 |
|---|---|---|
| Town Square centre | fountain with a cat statue, radius 6 | the Cat Cannon on a round plinth of the same size; the cat statue rides on the cannon's base so the landmark stays |
| Park gate, street's south end (z -125) | the Park's gate | a "Cat Cafe Town" welcome arch over the street end with a garden backdrop behind it (hedges, a low wall, hills on the skyline), solid |
| Neighbourhood gate, street's north end (z 125) | the Neighbourhood's gate | the same arch with a house-row backdrop |
| Woods and Sewer gates in the back alleys' outer walls (x ±94, z -12 to 12) | 24 wide openings | closed with alley wall and building backs like the rest of the outer walls |
| Signpost by the fountain | four arms at the four gates | stays at the cannon; each arm names an area, its tier lock and "by cannon", pointing the way the cannon fires to it |
| Paw paths along the cross | one per area to its gate | one paw path from the spawn and from each side arch to the cannon |
| Player spawn | (0, -14) facing north | unchanged, facing the cannon 14 studs ahead |
| Ground | 880, centred on the fountain | the hometown's own ground, 260 x 300 around the town, with a backdrop ring past the town's edges |

Everything else stays as in town-layout-v3: the cafe rows, the stations in the square's corners, the side arches, the Alleyway's lanes, nooks, traps and Index Boards, and the safe zone over the street and the square.

## 3. The Cat Cannon

### 3a. The hometown cannon

- **Model** (`CatCafe_Square_Cannon`): a big friendly cannon, cream and teal with gold bands and a paw on the barrel, on a turntable on the plinth. The barrel is about 10 studs long and rests tilted 50 degrees up. Two steps up the plinth on its south side, toward the spawn, lead to a small ladder at the barrel's back. The barrel turns to face the area it fires at: south for the Park, north for the Neighbourhood, west for the Woods and east for the Sewer, so the old compass still holds in the sky.
- **Prompt:** "Hop in", hold E for CatchHoldSeconds (0.5) within CannonRangeStuds (10) of the cannon, shown to anyone not carrying and not in a minigame. It opens the picker.
- **The picker** (UI, section 7) lists the wild areas the player's tier has opened, in tier order, with "More open as you rank up." under them, the same as the Areas panel since #358 (Derek's live notes, 2026-10-27: no buttons for places you cannot go yet). Each card has a picture, the area's name, one short line with its income step and your cats from it ("Coins x1.5 · 7/10 cats") and Launch. At night every card shows a moon and "Closed until sunrise" with the sunrise countdown. In the last DuskWarningSeconds (15) of the day they show "Night is coming" and Launch is off, so nobody lands only to be sent home.
- **Night.** At dusk a moon cover drops over the barrel's mouth, and it lifts at sunrise. The prompt still opens the picker, so players see the countdown.
- **A Tier 1 player** can open the picker; it has no cards and reads "Rank up to Tier 2 to fly." The first time a player reaches Tier 2, a one-time hint says "The cannon is ready! Hop in to fly to the Park." and an arrow points at the cannon.

### 3b. The flight (CannonLaunchSeconds 3.0)

| from | to | the launching player sees | everyone else sees | server |
|---|---|---|---|---|
| 0.0 | 0.5 | the character hops into the barrel; the barrel turns to the destination and wiggles; the fuse fizzes | the same | accepts `LaunchCannon`, anchors the character at the barrel's seat, sets `CannonLaunchAt` and `CannonTo` |
| 0.5 | 1.4 | BOOM: a smoke ring, confetti and a camera shake; the character shoots out curled in a ball, spinning, in a high arc; the camera follows from behind | the character arcs up into the sky and vanishes into a puff of cloud | |
| 1.4 | 2.4 | the cloud cutscene: clouds rush past the camera with the destination's name and icon in the middle ("To the Woods!"), lit in the area's colour toward the end | | at CannonTeleportAtSeconds (1.9) moves the character (still anchored) onto a free spot on the destination's landing pad, and asks the client to stream around it |
| 2.4 | 3.0 | the clouds part above the camp, the character drops onto the pad, lands in a crouch with a dust poof and a bounce, and the camera settles behind them | at the camp: a whistle and a ball dropping from the sky onto the pad | at 3.0 unanchors the character and clears the attributes; control returns |

The flight is the same from every cannon, and it lands at the hometown cannon's foot when the destination is the town. It cannot be skipped; three seconds is short, and the clouds hide the move. The town's landing pad is the same paw print at the hometown cannon's foot, on its south side.

Landing spots: each pad has seventeen, tried in order: its centre, eight points on a 4 stud ring, then eight on a 7 stud ring (inside LandingPadRadius 8). A spot is free when no character is within 3 studs of it. The server places one flight at a time, so two moves in the same frame never share a spot. If all seventeen are taken, the character lands on the nearest point of the camp (in town, of the square) off the pad with no character within 3 studs. Players never land inside each other.

### 3c. Camp cannons

Each camp has a smaller cannon (`CatCafe_Camp_Cannon`, the same look in the area's trim colour) at the camp's back wall, facing out over the area. Its picker lists "Town Square" first, then the other wild areas the player has open, never its own area. The rules and the flight are the same.

## 4. Camps

Every wild area has a camp across its whole width at one short end, CampDepth (30) deep. The rest of the area is the wild part.

- **Inside the camp:** the landing pad (radius LandingPadRadius 8, a big paw print) in the middle, the camp cannon at the back wall, the area's Index Board (moved from the old gate) beside the way out, the area's name on an arch over the way out, and a few props in the area's theme (a tent and lantern in the Woods, a bench and lamp in the Park, a manhole and pipe in the Sewer, a mailbox and picket fence in the Neighbourhood). A low fence with a CampOpeningWidth (24) opening divides the camp from the wild part. It has a red SAFE ZONE stripe on the camp side, like the town's edges.
- **Safe:** no tackles inside the camp, and strays never walk into it (it is outside their roam rects). Nobody can catch, rescue, pick up or tackle in a camp.
- **The edge** is the fence line. The safe zone is exactly the camp rect, which ends there, and the stripe is painted just inside it. One step past the fence a tackle lands again. The check-in uses the same rect, so a carrier is checked in the moment they cross the line and can never be tackled inside.
- **Knocked loose at the opening:** a tackle only lands outside the camp, so the cat drops where the carrier stood, on the wild side, as now. In case lag puts that spot on or over the line, a drop point within 2 studs of the camp rect moves straight out to 3 studs past the fence. A Returning cat's path (F67) never enters a camp. A player standing in the camp steps out to pick it up.
- **Check-in:** a carrier whose character enters the camp checks the cat in at once, the same as at their cafe door. The cat hops into a cat carrier basket by the pad and puffs away, the toast says "Pirate Cat is on its way to your cafe!", `CatCaught` fires and the cat is resting in the cat room. The server checks every carrier against the camp rect ten times a second, as it does for the door path (#415), so running through the opening fast cannot skip it.
- **Respawn:** a character that dies in a wild area respawns on its camp's pad, not in town. A carrier's death drops the cat first, as now (v0.13.3), so a reset is never a free check-in.

## 5. Rules

- **Carrying in a wild area:** Home, Alley, the hometown cannon's HUD button and every cannon refuse while you carry a cat ("Bring your cat to the camp first"). The carry banner reads "Bring it to the camp!" in a wild area and "Take it home!" in the Alleyway. Leaving the game still checks the cat in, as now.
- **Travel and the HUD buttons:**
  - **Home** (your cafe door) and **Alley** (your side's back alley) work from anywhere when you are not carrying. From a wild area they play a cloud hop instead of a cannon: CloudHopSeconds (1.6), clouds over the screen for 0.0 to 0.5 s, the move at CloudHopMoveAtSeconds (0.6), and the clouds parting at the destination by 1.6 s.
  - The **Areas button becomes Cannon.** In the hometown it moves you to the cannon's foot (an instant Travel, as today) and opens the picker. In a wild area it is hidden; walk to the camp.
  - `Travel(areaId)` goes. Area travel is by cannon only.
- **Night:** the dusk warning stays. At night start the sweep moves every character in a wild area home by cloud hop, the same move as Home. A carried cat is checked in for them on arrival and a Dropped stray goes to its last carrier, exactly as F66 does now. Nothing spawns at night and the cannons are covered.
  - **A flight or hop under way at night start** is left alone: the sweep skips a character with `Launching` or `CloudHopAt` set. Only flights to Town Square can be in the air then, because launches into areas stop 15 seconds before night and a flight takes 3, and those land in town anyway. If a flight into an area is somehow still under way, the sweep moves that character the moment it lands. Nobody is moved twice or left anchored.
- **Joining** puts you at the hometown spawn as now (new players at their back door for the intro). Nothing in a save stores a position, so there is no save change.
- **During a flight** the character is anchored and marked `Launching`. Tackles pass through them, Travel and every minigame are refused, and a second `LaunchCannon` is refused. Leaving mid-flight is simply leaving.

## 6. Where the wild areas go, and their shapes

### 6a. F84: the current sets, moved

F84 does not wait for new sets. Each current v3.2 set moves as it is to its new place, turned so its gate side (the set's -Z side) faces the hometown. Its old gate becomes the camp's way out, and the camp is added in front of it, outside the set's old rect. Spawn points, zones and traps move with the set unchanged.

| area | tier | centre of its set | the camp, toward the town | turn |
|---|---|---|---|---|
| Park | 2 | (0, -2000) | on its north side | half turn, as now |
| Neighbourhood | 3 | (0, 2000) | on its south side | none, as now |
| Woods | 4 | (-2000, 0) | on its east side | quarter turn, as now |
| Sewer | 5 | (2000, 0) | on its west side | quarter turn the other way, as now |

WildAreaDistance (2000) keeps every area far out of view of the others. Each area sits on its own ground with a backdrop ring outside its walls (hills, trees, house roofs or brick vaults by theme), so no player ever sees the empty space between places. Lighting and the clock are shared, since it is one server.

### 6b. F85: longer and rectangular

Each wild area becomes a long rectangle with its camp across one short end. The farther the area, the longer the run home, so the best-paying cats have the longest and most exposed carry.

| area | v3.2 floor | F85 floor (width x length, camp included) | floor area | path, camp to far end | on foot (20) | carrying (16) |
|---|---|---|---|---|---|---|
| Park | 160 x 120 | 120 x 340 | 2.1 times | about 425 | about 21 s | about 27 s |
| Neighbourhood | 280 x 280 | 180 x 460 | 1.06 times | about 575 | about 29 s | about 36 s |
| Woods | 240 x 240 | 160 x 520 | 1.4 times | about 650 | about 33 s | about 41 s |
| Sewer | 180 x 180 | 120 x 600 | 2.2 times | about 750 | about 38 s | about 47 s |

- **The way home is long and in view.** The main path runs the length and winds about 1.25 times the straight distance. Blockers run across the width with gaps on alternating sides. Most blockers are low enough to see over (hedges, fences, logs, the water channel, rubble about 4 studs high), so a hunter sees a carrier coming across them but has to go round. A few tall pieces (a house block, the Great Oak, a brick vault) break the view now and then so a careful carrier has places to slip by.
- **Rescues deep.** At least three quarters of each area's rescue traps are in the far half, and none is within 100 studs of the camp. Trap counts stay as in v3.2 (Park 5, Neighbourhood 4, Woods 5 with the tree house branch, Sewer 4).
- **Spawn points** stay at least as many as in v3.2, spread along the whole length, about 60% in the far half. `near` is the camp half and `deep` the far half, and Epic and rarer strays still take only `deep` points; the Great Oak's `rare` nook stays. Wave sizes stay as Derek set them (5, 5, 4 and 4), so the strays are spread farther apart.
- **The far end** gets each area's best landmark, as in town-layout-v3 8f.
- **Bridges, decks and water** keep the 8c rules: steps or ramps at both ends, solid railings, water crossed only on bridges.

The tackle rules do not change. The getaway (CatchRushWalkSpeed 24 for 5 s after a catch) and the grace and cooldowns still protect a carrier, and the camp is safe. Derek wants more tackles on the way home; the longer runs give them without changing the tackle itself.

## 7. Contract for each thread

**Gameplay-Engineer (cannon, flight, camps, rules):**
- `Config.World`: remove ParkGateZ, NeighbourhoodGateZ, WoodsGateX, SewerGateX and the gate openings. Add WildAreaDistance 2000, CampDepth 30, CampOpeningWidth 24, LandingPadRadius 8, CannonRangeStuds 10, and the area centres from 6a (later 6b's sizes).
- `Config`: CannonLaunchSeconds 3.0, CannonTeleportAtSeconds 1.9, CannonCooldownSeconds 3, CloudHopSeconds 1.6, CloudHopMoveAtSeconds 0.6.
- `Layout`: `cannons` (`town` at the square's centre, one per area at its camp's back wall, each with its fire direction), `camps` (each area's camp rect, pad centre and opening) and `landingPads` (`town` at the cannon's foot and one per camp, each with the seventeen spots in 3b). Index Boards move to the camps.
- **Remote `LaunchCannon(cannonId, destination)`, rate-limited to 1 a second.**
  - `cannonId` is `town` or an area id (a camp cannon) and the caller is within CannonRangeStuds of it.
  - `destination` is `town` or an area id other than the cannon's own. For an area, the area is unlocked for the caller's tier, `AreasOpen` is true and it is not the dusk warning.
  - The caller is alive, not carrying, holds no catch or rescue lock, is not launching or tackled down, and is off CannonCooldownSeconds.
  - On accept, the server runs the flight in 3b and sends `CannonLaunch(destination, launchAt)` to the caller for the camera. Refusals answer with a toast reason.
- **Character attributes:** `Launching` (bool), `CannonLaunchAt` (server time), `CannonFrom` and `CannonTo` (ids), so every client plays the flight. The move itself is a server `PivotTo` while anchored; with StreamingEnabled on, call `RequestStreamAroundAsync` on the landing spot as the clouds start. A cloud hop sets `CloudHopAt` (server time) and `CloudHopTo` (`home` or `alley`; the night sweep uses `home`) when it starts and clears them when it ends, so onlookers see a puff where the player leaves and where they land.
- **Client event `CampCheckIn(userId, campId)`** to every client, fired in the check-in frame before the carried cat is removed. A client with that camp streamed in copies the cat as it is (outfit and gold kept) and hops the copy into the basket. The carrier's `Moments.CheckIn` still fires as now.
- **Check-in at camps:** in the carry loop, a carrier inside their area's camp rect is checked in, as at the door. Analytics `camp_checkin` (area, rarity, seconds carried, times knocked loose).
- **Travel:** `home` and `alley` keep working from anywhere when not carrying, with the cloud hop from a wild area. A new `cannon` destination, from the hometown only, lands at the cannon's foot. Area destinations go.
- **Night sweep, respawn and tackles:** the sweep uses the cloud hop and skips characters mid flight or mid hop (section 5). Respawn in a wild area goes to its camp pad. Camps are safe zones in the tackle, catch, rescue and pick-up checks, with the fence line as the edge and drop points near it moved out (section 4).
- Analytics `cannon_launch` (from, to).
- **No save change.**

**Model-Agent (sets and models):**
- **The cannon:** `CatCafe_Square_Cannon` on the plinth with its steps, ladder, turntable and moon cover, and the town's landing pad paw print at its foot.
- **Effect points:** both cannon models carry a `Muzzle` attachment at the barrel's mouth and a `Fuse` attachment at the fuse tip. Each camp's carrier basket is tagged `CampBasket` with a `Drop` attachment at its opening.
- **Camps:** `CatCafe_Camp_Cannon` in each area's trim, and each camp's fence, opening, pad, carrier basket, name arch and theme props.
- **The hometown's ends:** the two welcome arches and backdrops, and the closed alley walls where the Woods and Sewer gates were.
- **Backdrop rings** for the four areas at their new places.
- **F85:** each set rebuilt as the long rectangle in 6b, with its gate side still -Z, to the path, sightline, rescue and spawn rules there.

**VFX-Agent and Animation-Engineer (flight):**
- Animation: the hop into the barrel, the curled spinning ball pose, and the crouch landing with a bounce.
- VFX: the fuse fizz, the muzzle smoke ring and confetti, the sparkle trail, the cloud puff in the sky, the full-screen cloud tunnel tinted by area (the paw path colours from town layout v3: leaf green Park, warm orange Neighbourhood, deep green Woods, slate blue Sewer; cream for Town Square and for Home and Alley hops), the clouds parting, the landing dust poof, and the cat's hop into the carrier basket and its puff at a camp check-in.
- The cloud hop is the cloud tunnel without the cannon.
- Effects play at the `Muzzle`, `Fuse` and `Drop` attachments, falling back to the cannon's pivot and its Layout fire direction. The cloud tunnel sits just under UI's destination name card; VFX and UI agree the DisplayOrder.
- No placeholder Roblox characters in previews; show scale with cats and props.

**UI-Engineer:**
- The cannon picker and its night and dusk states; the camp cannon variant with Town Square first.
- The Cannon HUD button in place of Areas.
- The carry banner text and the "Bring your cat to the camp first" refusal.
- The camp check-in toast.
- The destination name card in the clouds.
- The Tier 2 hint.

**Sound-Agent:**
- Cannon: the fuse fizz, the boom, the whoosh up, the wind in the clouds, the whistle down and the landing thump.
- The camp check-in chime and the cloud hop whoosh.

**Tutorial-Agent:** intro shots 5, 6 and 9 show the gates and the areas next to the town. They need new shots for the cannon and the far areas, for example shot 5 on the cannon firing and shot 6 cutting to the four camps.

## 8. QA checks

1. From the hometown spawn the cannon is the first thing in view, and every station and both side arches are still clear to walk to.
2. The flight takes 3 seconds from Launch to control and lands on the chosen area's pad, never inside another player. Twenty players launching to one camp together all land apart: seventeen on the pad and the rest beside it.
3. A Tier 2 player sees only the Park card in the picker, and a Tier 1 player sees no cards and "Rank up to Tier 2 to fly."
4. In the last 15 seconds of the day no launch into an area is accepted. At night the picker shows the sunrise countdown.
5. Carrying a cat in a wild area, every Home, Alley and cannon attempt is refused. Walking into the camp checks the cat in, and the cat is in the cat room.
6. Tackling is off everywhere in a camp up to the fence line and lands again one step past it, and strays never enter a camp.
7. At night start, everyone in a wild area is clouded home, and carried cats are checked in.
8. A character that dies in a wild area comes back on that area's pad, and a cat it carried is dropped where it died.
9. A player launched from a camp to Town Square 2 seconds before night lands in town once, unanchored, and the sweep does not move them again.
10. A carrier tackled just outside a camp opening drops the cat on the wild side, and a player outside the camp can pick it up at once.
11. F85: in each area the main path from the camp to the far end takes about the time in 6b, the far end cannot be reached in a straight line, and at least three quarters of the traps are in the far half.

## 9. Cannons or portals

Cannons everywhere, as Derek leans. A portal would have been simpler in two places:
- **The camps' way home,** where a walk-in ring needs no picker, model or flight. The camp cannon's picker is still worth it, because it also reaches the other areas.
- **The night sweep,** which is why the sweep and Home use the cloud hop, not a cannon.

Nothing else would be easier with portals, and one flight for everything is less to build than a cannon and a portal.

## 10. Order

1. **F84:** hometown, cannons, camps, check-in, the rules and the moved sets. It plays fully with the current sets.
2. **F85:** the long rectangular sets, one area at a time. Each set swaps in when it lands, like the v3.2 rebuilds.
