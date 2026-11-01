# The Rainbow coat (F99)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-30 00:24: "I am thinking of adding another tier of cats not just gold but also rainbow or something that is obviously better then gold so that it has more of a late game grinding market and make sure whatever it is rainbow/void/shiny whatever the new tier is make it obvious looking that its good and better then gold". His release rule of 2026-11-01 22:59 puts it before release.

We picked **Rainbow**: every child knows it, and it reads as "more than gold" from across a street.

## 1. How a cat gets it

- A third coat beside base and gold: `variant = "rainbow"`. Every catchable cat has one. Exclusive cats (the Bellhop Cat and the shop cats) never roll gold or rainbow, as now.
- The coat is rolled at the same moments as gold, rainbow first and then gold, so the gold chance stays as it is:

| how the cat was found | rainbow | gold (unchanged) |
|---|---|---|
| Net stray, rolled at spawn and visible from then | RainbowChanceNet 0.005 | 0.05 |
| Bait, rolled when the food goes in | RainbowChanceBait 0.005 | 0.05 |
| Rescue, rolled at night start, hidden until freed | RainbowChanceRescue 0.01 | 0.10 |

- So rainbow is one tenth of gold. A player who secures about 300 cats on the way to Tier 5 meets one or two. It is the late game hunt Derek asked for, and with trading (F102) rainbow cats become the thing people trade for.
- **Rainbow luck.** The new Rainbow track in the Index (section 4) multiplies every rainbow roll by `1 + rainbowLuck`, capped at RainbowLuckMax (1.0). Gold luck, Gold Rush and Lucky Potions do not touch rainbow, so each boost does one clear thing. Whose luck counts follows the gold rule (golden-fish.md section 5): bait uses the player who sets the food; strays and rescue cats use the highest `rainbowLuck` among players in the server with that area open.
- Every food card and the Fish Market's odds card shows "Rainbow 0.5%" (with the player's rainbow luck in it) under the gold line.
- **Earnings.** A rainbow cat earns RainbowMultiplier 3, twice a gold cat's 1.5. A rainbow Alleyway Common earns 3 a second, the same as a Park Common.
- **The Cat Collector** values a rainbow cat at CollectorRainbowMultiplier 10 (gold is 3).

## 2. How it looks

It has to outshine gold at a glance. Gold sparkles; rainbow moves, glows and leaves a trail.

- **The coat.** The cat's own model and parts, coloured in six bright hues (red, orange, yellow, green, sky blue, violet). Each part's colour drifts round the colour wheel with its phase set by its distance from the nose, so bands of colour flow from nose to tail every 3 seconds. Eyes, nose and mouth keep their colours.
- **A soft glow.** A small white light on the cat (range 6, brightness 0.6, no shadows) and a thin outline whose colour follows the bands.
- **A sparkle trail.** While the cat walks or is carried, small star sparkles in the current band colours drop behind it and fade in 0.8 s.
- **When a rainbow stray spawns,** a short rainbow beam rises from it for 3 seconds and the server sees a toast: "A Rainbow Tabby is out in the Woods!" (at most one such toast a minute per server). That gives every player a reason to take the cannon.
- **Cards and the Index.** A rainbow cat's card and Index tile have a slowly turning rainbow border and the word RAINBOW in rainbow letters where gold cards say GOLD. The hover card's buff chips (F97) show a rainbow "x3" chip.
- **Securing one** always plays the big pull (luck-and-rare-moments.md section 3), whatever the rarity: "RAINBOW COMMON!" up to "RAINBOW MYTHICAL!", with rainbow confetti, a rainbow edge and the Mythical sting. The server toast follows F89's rules.
- **Reduce Motion:** the bands stand still, with no trail and no beam; the glow and borders stay.
- **Phones and crowds:** colours animate on at most RainbowAnimateMax (10) rainbow cats within 120 studs of the camera; the rest show still bands.
- Who builds: VFX-Agent (`Effects/Cats` rainbow coat, glow, trail, beam), UI-Engineer (cards, Index tab, odds line, chip), Sound-Agent (a bright shimmer when one spawns near you and a rainbow sting on the big pull), Gameplay-Engineer (rolls, earnings, luck, toast). Model-Agent needs nothing new: the coat is colour on the existing parts.

## 3. Where it counts

- **Index:** a third tab, Rainbow, after Normal and Gold, with the same silhouettes until found (F97 section 6). Each found rainbow coat counts toward the Index leaderboard (F98).
- **Tiers:** "different cats" for rank ups counts a cat kind once, whatever its coat, as now.
- **Locking, selling and trading** work like any cat. Selling asks twice for a rainbow cat ("Sell your Rainbow Tabby? It earns x3").

## 4. The Rainbow track

One track for the whole Index (not per area, since one rainbow Mythical can take weeks), counting different rainbow cats found:

| milestone | rainbow cats | prize |
|---|---|---|
| `rainbow1` | 1 | 25 golden fish and the "Rainbow Finder" tag |
| `rainbow3` | 3 | 50 golden fish and a Golden Classic Crate |
| `rainbow5` | 5 | +20% rainbow luck forever and 75 golden fish |
| `rainbow10` | 10 | +30% rainbow luck forever, 2 Golden Classic Crates and 100 golden fish |
| `rainbow25` | 25 | +50% rainbow luck forever, 3 Golden Classic Crates, 150 golden fish and the "Rainbow Master" tag |

The three luck steps add up to +100%, the RainbowLuckMax cap, so a Rainbow Master rolls rainbow at 1% on strays and bait. Each prize shows at most three pictures (F94).

## 5. Contracts

- Save: `variant` may be `"rainbow"`; the Index entry per cat gains `rainbow` (bool) next to `gold`; `stats.rainbowCatches`; the Rainbow track's claimed milestones sit with the other tracks' claims.
- Config: `RainbowChanceNet` 0.005, `RainbowChanceBait` 0.005, `RainbowChanceRescue` 0.01, `RainbowMultiplier` 3, `RainbowLuckMax` 1.0, `CollectorRainbowMultiplier` 10, `RainbowAnimateMax` 10, `RainbowSpawnToastSeconds` 60.
- Prize shape: `rainbowLuck?` (a fraction) next to `goldLuck?`.
- Remotes: `RainbowSpawned(areaId, catId)` to all clients (the toast and beam); `SecuredRare` gains `variant` so the big pull can say RAINBOW.
- Attributes: `Variant` on cat models reads `"rainbow"` (strays, carried, working, resting) so every client draws the coat.
- Analytics: `rainbow_found` with rarity and source (net, bait, rescue, trade).

## 6. QA checks

1. With the debug hook forcing rainbow on the next stray, the stray spawns with flowing bands, a glow and a beam, and every player in the server sees the toast once.
2. Rolling 100,000 bait placements in the cloud check gives rainbow 0.5% and gold 5% (each within 0.1 percentage points), and the rainbow share is the same for every rarity.
3. A rainbow cat at work earns exactly twice what the same cat in gold earns.
4. Securing a rainbow Common plays the big pull with RAINBOW COMMON!; a gold Common does not.
5. With Reduce Motion on, the bands stand still and there is no trail or beam.
6. Twelve rainbow cats on screen on a phone: only ten animate and the frame rate holds.
7. Claiming `rainbow5`, `rainbow10` and `rainbow25` lifts the food card's rainbow line to 0.6%, 0.75% and 1%.
8. The Collector's offer for a rainbow cat is about ten times the base offer for the same cat.
