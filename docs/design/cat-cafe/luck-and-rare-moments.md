# Luck, Lucky Days and rare moments (F88, F89)

Status: proposed by the game-designer thread, 2026-11-01. Two pieces of the ship-and-learn plan in the decision memo (`Design-Agent/rework-or-ship-2026-11-01.md` in the project files).

- F88 answers Derek's 2026-10-31 19:47 note that "the game is also missing some form of "Luck" most popular games have but no real way it fits in".
- F89 answers his 2026-10-30 23:31 ask: "Some of the rare decor doesn't even look that good like the gold leaf paint consider taker more time making the rarer ones so not only it feels rewarding but also looks good. Also when securing something good leg/mythic decor or cats possibly consider a bigger VFX or Animation to make it feel more rewarding for the player".

## 1. Luck (F88)

### 1a. Where luck fits: the Lucky Cat

Shops in Japan and around the world keep a beckoning cat statue by the door for luck and customers. A cat cafe is the one game where that belongs. Every cafe gets a **Lucky Cat** statue beside its front door, waving one paw. Upgrading it raises your Luck, and other players see it from the street. That is the "way it fits in".

- `lucky_cat` joins the upgrade catalog (data-model section 6): five levels, level n needs Tier n. Prices 2,000, 20,000, 150,000, 1,000,000 and 5,000,000 coins. Each level adds 0.1 Luck.
- The statue changes look by level: clay, bronze, silver, gold and jade with a rainbow shimmer. Its paw waves a little faster at each level. Level 0 is an empty plinth with a "Lucky Cat" sign, so new players see that it is there to buy.
- It is a coin sink in the middle and late tiers, where the wallet piles up.

### 1b. The Luck number

Luck is one number, shown as a multiplier: "Luck x1.3". It starts at x1.0 and adds up every source the player has right now. LuckMax is x3.

| Source | Luck | How long |
|---|---|---|
| Lucky Cat statue | +0.1 a level, +0.5 at level 5 | always |
| Lucky Potion | +0.5 (it still doubles the gold chance on bait, as now) | 10 minutes |
| Lucky Day | +0.5 for everyone in the server | that day phase |

What Luck does: on a roll it multiplies the chance of Epic, Legendary and Mythical by Luck. Rare keeps its chance and Common takes the difference, so the odds still add to 100. If Common would fall below zero, the rest comes off Rare. One pure function, `Luck.apply(odds, luck)`, does it. Example: Kibble on a level 1 bowl is 70 / 25 / 4 / 0.9 / 0.1. With Luck x1.5 it becomes 67.5 / 25 / 6 / 1.35 / 0.15.

Which rolls it touches:

- **Your bait.** The food's odds, then the bowl's shift (BowlLuck, unchanged), then Luck. Saved with the roll at placement as now, so it cannot be rerolled.
- **Your crates.** A crate's rarity roll uses Luck the same way, and the Fish Market's odds card shows the odds with your Luck in them. The lucky twentieth and the golden crates are unchanged.
- **Not the shared strays and traps.** Those are rolled once for the whole server at sunrise, so only a Lucky Day changes them (1c). The dealer's stock is unchanged too.

The bowl's own luck is renamed on its card to "Comfy bowl: rarer visitors" so players see one thing called Luck.

### 1c. Lucky Days

- Every LuckyDayEvery (4th) day on a server, counted from the server's start, is a Lucky Day, so players can see one coming and stay for it (Monetization-Agent's key stats plan: a scheduled event with its start on the HUD clock keeps players for one and brings them back for one). It takes the place of the Cat Parade in common-features.md, which was the same idea. On a Lucky Day the sunrise wave and the rescue traps roll with Luck x2 (LuckyDayWaveLuck), and every player in the server gets +0.5 Luck until dusk.
- The sky takes a warm gold tint for the day, a banner says "Lucky Day! Rare cats are twice as likely until night", and the HUD's Luck chip glows.
- The HUD's day clock shows how far away the next one is ("Lucky Day in 2 days", about 13 minutes), and 15 seconds before a Lucky Day's sunrise players still in the server see "A Lucky Day starts at sunrise!", so staying through the night pays.
- A day plus a night is about 6.5 minutes, so a Lucky Day comes every 26 minutes, at least once in a 30 minute session. It is free and runs on each server's own clock, never at a set time of day, so nobody has to log in at a certain hour.
- A Lucky Day Mythical announce reads "A Mythical cat appeared in the Woods on a Lucky Day!".

### 1d. The Luck chip

A small pill under the coins on the HUD: a four-leaf clover and "Luck x1.3", shown from the first Luck source (before that, hidden). Tapping it opens a card that lists each source with its share and time left, the odds of the food in your bag on your bowl, and the next crate's odds. The first source shows the `luck` context tip from easy-start.md.

**The card, v2 (#1776, Derek2 2026-11-06: "those odds are not helpful just say overall 5% increase to this rarity 10% increase to this").** The two odds blocks ("Your next cat from ..." and "Your next ... Crate") go. In their place is one row of rarity pills, which say what Luck does to every roll at once, whatever the bait or crate:
- **The maths.** `Luck.apply` multiplies the Epic, Legendary and Mythical chances by the Luck number and leaves Rare as it was, and Common gives up the difference. So the boost to each of the three is the same: `boost = round((luck - 1) * 100)` percent. At x1.3 that's +30%, and at x3 (LuckMax) it's +200%. It's relative to the chance at x1.0, so "+30%" on a 4% Epic means about 5.2%. This is the honest number for every table. A point gain ("+1.2 points") would differ per bait and crate, and that's the kind of detail Derek2 asked to drop. Add `Luck.boostPercent(luck): number` to `shared/Luck` so the card and the server can never disagree, and it returns 0 at or below x1.
- **The row.** Three pills in their rarity colours, "Epic +30%", "Legendary +30%" and "Mythical +30%", using the rarity pill from the Index (#1711 look), in one line under the source list. Rare and Common get no pill. Text stays at that and nothing more: no "relative to", no table and no footnote. The hue carries which rarity is which.
- **Nothing to show.** At Luck x1.0 the chip is hidden (above), so the card never shows "+0%".
- **The cap.** In the rare case where the three boosted chances fill a whole table (the scaled branch of `Luck.apply`), the real gain is smaller than the pill says. Only a near-empty Common/Rare table at x3 gets there, so the pill keeps the simple number.
- **QA.** (1) With a statue level 3 (x1.3), the card shows Epic, Legendary and Mythical +30% in their colours, and no odds blocks. (2) A Lucky Potion on top (x1.8) changes all three to +80% within a second. (3) The card fits on phone, tablet and desktop in the UI gate.

### 1e. Not sold

No Luck is sold for Robux in v1. Paid Luck would turn every roll it touches into a paid random item under Roblox's May 2026 rules, and docs/growth/monetization.md keeps those out of the first release. The Lucky Cat is coins only and potions stay earn-only.

### 1f. Contracts

- Config: LuckPerStatueLevel 0.1, LuckMax 3, LuckyDayEvery 4, LuckyDayWaveLuck 2, LuckyDayPlayerLuck 0.5, LuckyPotionLuck 0.5, LuckyDayWarnSeconds 15.
- `shared/Luck.luau`: `Luck.of(profile, now, luckyDay)` and `Luck.apply(odds, luck)`, both pure, with a spec.
- Clock folder: `LuckyDay` (bool) for the day phase, set at sunrise.
- ProfileSync carries `luck` (the number) and `luckSources` (a list of `{ id, value, endsAt? }`).
- Analytics: `luck_used` (value the Luck number, fields roll kind bait or crate, rarity won, tier) and `lucky_day` (value players in the server, field the area of any Mythical rolled).
- Save change: the `lucky_cat` upgrade level, through the existing `upgradeLevels`.
- Who builds: Gameplay-Engineer (Luck, rolls, Lucky Day, upgrade), UI-Engineer (chip, card, banner, shop row), Model-Agent (the statue at five looks and the plinth), VFX-Agent (the gold sky tint, the statue's level-up sparkle), Animation-Engineer (the waving paw), Sound-Agent (a Lucky Day chime).

### 1g. Day rolls v2: Lucky, Golden and Rainbow Days (#1572)

Derek, 2026-11-05 (Set 6 Q9 and Sets 7 to 9): days are rolled at the start of each day, stackable, "Lucky 33%, Golden 20%, Rainbow 10%", per server or global both fine. This replaces 1c's "every 4th day" (`LuckyDayEvery`). The Lucky Cat statue (1a) is already built and stays as it is.

- **One global roll.** Each kind is rolled on its own from the global day number (`Clock` day since `Config.ClockEpoch`, #1555) with a fixed seed per kind, so every server has the same day at the same moment and nobody gains by hopping servers. All three can land on the same day.

  | day | chance | what it does, from that sunrise to night |
  |---|---|---|
  | Lucky Day | 33% (`LuckyDayChance`) | as 1c: the sunrise wave and traps roll at Luck x2, every player gets +0.5 Luck |
  | Golden Day | 20% (`GoldenDayChance`) | every gold roll (net, bait, rescue) x2 (`GoldenDayGoldMultiplier`), so 5% becomes 10% |
  | Rainbow Day | 10% (`RainbowDayChance`) | every rainbow roll x3 (`RainbowDayMultiplier`), on top of rainbow luck |

- **What players see.** The sunrise banner names every kind of the day at once ("Lucky Day! Golden Day!"), the sky takes the gold tint for any of them, and the HUD's day clock shows today's kinds as small chips. Each chip's card gives its effect and its chance. Because the roll is random, the old "Lucky Day in 2 days" countdown goes; the warning 15 s before sunrise stays, naming tomorrow's kinds, since the server can already roll them. The food cards and the Fish Market's odds card show the boosted gold and rainbow chances on those days.
- **Not sold, no urgency.** Days are free, frequent (about 1 day in 3 is lucky) and the same for everyone. No Robux or coin offer appears on or about a special day.
- Contracts: Config `LuckyDayChance` 0.33, `GoldenDayChance` 0.2, `RainbowDayChance` 0.1, `GoldenDayGoldMultiplier` 2, `RainbowDayMultiplier` 3; `LuckyDayEvery` goes. `Clock.dayKinds(day)` returns `{ lucky, golden, rainbow }`, pure, with a spec that checks the rates over 100,000 days within 0.5 points. The Clock folder gains `GoldenDay` and `RainbowDay` next to `LuckyDay`. Analytics: `lucky_day` gains a `kinds` field.

### 1h. The pity cat (#1572)

Derek, 2026-11-05: a sign on the cat square shows the time until a Legendary (30 min) and a Mythical (2 h). The timer is global. When it ends, one pity cat spawns for the whole game, first come first served, in one random area that prefers the higher areas (the Alleyway still possible). Everyone gets a banner and a sound naming the area, and the cat stays until night.

- **The clock.** Slots run every 30 min (`PityLegendarySeconds` 1800) from `Config.ClockEpoch`, on `Workspace:GetServerTimeNow()`, so every server counts the same slots with no shared store. Every 4th slot (each 2 h, `PityMythicalSeconds` 7200) is a Mythical slot instead of a Legendary one. A slot that falls at night spawns at the next sunrise.
- **Which area and cat.** Seeded from the slot number, so every server picks the same: area weights Alleyway 10, Park 15, Neighbourhood 20, Woods 25, Sewer 30 (`PityAreaWeights`), then a random Legendary or Mythical of that area. Its coat rolls gold and rainbow as a normal stray. It spawns at one of the area's hiding spots with a gold beam, and it is a normal stray in every way: nettable, tackle and shove rules as usual, secured by carrying it into the camp.
- **One for the whole game: whoever catches it.** The cat spawns in every server at once, and the first player anywhere to catch it (net catch or bait) gets it. Derek on #1581: "you have to catch it so its only who catches it gets it". On the catch, the server claims `pity:<slot>` in a MemoryStore HashMap with `UpdateAsync` (set only if empty, expiry 1 day). The winner's catch goes on as normal, and every other server is told through MessagingService topic `Pity`, so its copy puffs away with "Sam caught the pity cat!". A catch that loses the claim (two servers within the same second) puffs out of the net with the same banner. There's no consolation prize. If MemoryStore fails 3 times, that server's catcher keeps the cat (we never take a cat away on our own error) and the event logs it. At night every server's uncaught copy goes.
- **The sign.** A board on the Town Square, `CatCafe_Square_PitySign` (Model-Agent, #1592: a cat-ear frame with a 5.6 x 2.8 Screen at (13.5, -23) facing the spawn, across the street from the Day Cart; the signpost was removed on 11-03) reads "Legendary cat in 12:30" and "Mythical cat in 1:42:10", worked out on each client from the clock, plus "Now in the Woods!" while a pity cat is out and "Caught by Sam" after. The same two lines show on the day clock's card.
- **Announcements.** At spawn, every server gets a game-wide banner and the rare-cat sound: "A Legendary pity cat appeared in the Woods!". A player whose tier hasn't opened that area sees "(opens at Tier 4)" after it, so the banner never points at a door they can't use.
- **Security.** No new client remote: the client only reads the clock and the server-set `PityCat` attribute. The server validates the catch as for any stray, and the MemoryStore claim is server-only. Review-Agent gives it the first security review.
- Contracts: Config `PityLegendarySeconds` 1800, `PityMythicalEvery` 4, `PityAreaWeights`, `PityClaimRetries` 3. `shared/Pity.luau` with `Pity.slot(now)`, `Pity.nextAt(now, kind)` and `Pity.pick(slot)` (area, cat id), all pure with a spec. The server's `PityService` spawns, claims and announces. Remote `PityAnnounce(kind, areaId, state, winnerName?)` to all clients. Analytics `pity_cat` (slot, area, kind, secured or expired, servers that claimed).
- QA: (1) Two servers show the same countdown to the second and spawn the same cat in the same area. (2) Catching it in server A puffs server B's copy within a few seconds and shows the banner, and only A's player owns the cat. (3) Over 10,000 slots the areas land within 1 point of the weights. (4) A slot at night spawns at sunrise. (5) With MemoryStore blocked in Studio, the catcher keeps the cat and the log says so. (6) No golden fish are paid to anyone who missed it.

## 2. Rare moments (F89)

### 2a. When a rare cat is secured

"Securing" is the moment a cat becomes yours and safe: a carried cat checked in, a bait cat tamed or a stuck cat freed into your arms and then checked in. For a Legendary, a Mythical or any gold Epic or better, the check-in plays a **big pull**, about 2.4 seconds:

- **On your screen:** the edges warm to the rarity colour, light rays turn slowly behind a big card with the cat's portrait, the rarity word ("LEGENDARY!", "MYTHICAL!", "GOLD MYTHICAL!") slams in from 1.6 times size with a small shake, the cat's kind below it, and confetti in the rarity colour bursts in from both sides. A Mythical adds a second wave of sparkles and a longer sting. The card closes on a tap after 1 second or by itself at 2.4 seconds. Controls stay on.
- **In the world:** the cat does a happy hop with a full spin at the door (Animation-Engineer) inside the existing catch beam; a Mythical adds a ground shockwave ring 20 studs across.
- **For the server:** everyone in the server gets a small toast, "Sam secured a Mythical Jazz Cat!", using the player's display name and the cat's kind, never its nickname. Legendary and Mythical only, at most one toast a minute per player.
- **First of a rarity:** the first Epic a player ever secures gets a smaller card (no server toast), so the first step up feels like something too.
- Reduce Motion: no shake, no turning rays, half the confetti. Phones get half the particles and Low performance a third, as the other bursts do.
- Sound-Agent: one sting per rarity from Epic up.

### 2b. When a rare decor piece comes out of a crate

Since F103 (2026-11-01) the crate reel shows the result, with its own near miss rules in [crate-reel.md](crate-reel.md); nothing hints at the rarity before the reel stops. For a Legendary or Mythical piece only, at the stop:

- The landing tile and the counter crate glow in the rarity colour and the crate shakes for 0.6 seconds before the lid blows open.
- The same big pull card shows the piece's icon and name, with the "Use it" button on the card.
- Mythical pieces get a server toast, "Sam found the Mythical Midnight Sky!", on the same once-a-minute rule.

### 2c. Rarer pieces must look rarer

Derek's bar for the models is the Fish Market stall. Each rarity of decor needs at least the following:

| Rarity | A wallpaper, floor or paint | A furniture or decoration model |
|---|---|---|
| Common | one clean colour or simple pattern | a simple model, one or two materials |
| Rare | a detailed pattern with a trim or border | more detail, three or more materials |
| Epic | a pattern plus one surface that catches the light (gloss, metal, glass) | a hero model with one moving part or light |
| Legendary | changes two or more surfaces with matching trims | the most detailed model in its crate, a moving part and a light, a small sound when used |
| Mythical | changes the whole look of the cafe (walls, trims and its signature effect) | as Legendary, plus its signature effect |

**Gold Leaf, redone first.** Today it reads as flat yellow paint. As a Mythical it should look like a fancy old cafe: the walls a deep cream, every trim real metallic gold (window and door frames, the awning edge, the roof edge, the sign frame and the corner posts), the sign's letters gold, a slow glint that sweeps across the trims every 5 seconds and a soft glow on them at night. Other players see it from the street, so it should be the cafe front people walk over to look at.

**The other eleven Legendary and Mythical pieces** get the same check, with a before and after sheet for each: Midnight Sky, Retro Jukebox, Duck Fountain, Blossom Tree, Rainbow Shimmer, Ice Cream Counter, Aurora Sky, Hollow Log Booth, Glimmer Canal, Bathtub Sofa and Cat Tree Tower. Model-Agent and VFX-Agent do them worst first and show Derek the sheets before they merge.

### 2d. Contracts

- Server: `SecuredRare(userId, catId, rarity, gold)` to all clients after a check-in, tame or rescue check-in of a Legendary, a Mythical or a gold Epic or better (rate rule: one per player per 60 s for the toast; the owner's own card always plays). `CrateResult` already carries the rarity, so the crate's big pull needs no new remote; a Mythical crate piece fires `FoundRareDecor(userId, pieceId)` for the toast.
- Analytics: `rare_secured` (value 1, fields rarity, gold yes or no, how: catch, bait or rescue).
- Who builds: UI-Engineer (the card, rays, banner word and toasts), VFX-Agent (confetti, shockwave, crate glow and shake, the Gold Leaf glint), Animation-Engineer (the hop and spin), Sound-Agent (the stings), Model-Agent (the decor rework in 2c), Gameplay-Engineer (the two remotes), QA-Planner (section 3).

## 3. QA checks

1. A fresh player has no Luck chip. Buying the Lucky Cat's first level shows "Luck x1.1", the `luck` tip and the clay statue by the door, which other players see.
2. With Luck x1.5, the food card and the crate card show the Epic, Legendary and Mythical chances at 1.5 times and the odds still add to 100.
3. Every fourth day on a server is a Lucky Day, the HUD clock counts down to it, and it comes with the banner, the gold sky, the glowing chip and the warning 15 s before.
4. A Lucky Day's wave rolls with Luck x2. A normal day's wave ignores everyone's own Luck.
5. Checking in a Legendary plays the big pull card, the hop and spin and a toast for the whole server; a second Legendary within a minute plays the card but no toast.
6. The first Epic ever gets the small card; the second does not.
7. A Mythical crate piece glows from the first frame, shakes, opens, plays the big pull with "Use it" and toasts the server; a Common piece opens as today.
8. Reduce Motion removes the shake and the turning rays.
9. Gold Leaf in use shows gold trims, gold letters, the glint every 5 s and the night glow, seen from across the street.
