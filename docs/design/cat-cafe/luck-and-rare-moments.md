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

- At each sunrise the server rolls LuckyDayChance (0.25). On a hit, that day is a Lucky Day: the sunrise wave and the rescue traps roll with Luck x2 (LuckyDayWaveLuck), and every player in the server gets +0.5 Luck until dusk.
- The sky takes a warm gold tint for the day, a banner says "Lucky Day! Rare cats are twice as likely until night", and the HUD's Luck chip glows.
- 15 seconds before a Lucky Day's sunrise, players still in the server see "Tomorrow is a Lucky Day!", so staying through the night pays.
- A day plus a night is about 6.5 minutes, so a Lucky Day comes about every 26 minutes on average, about once in a normal session. It is random, free and never tied to logging in at a set time.
- A Lucky Day Mythical announce reads "A Mythical cat appeared in the Woods on a Lucky Day!".

### 1d. The Luck chip

A small pill under the coins on the HUD: a four-leaf clover and "Luck x1.3", shown from the first Luck source (before that, hidden). Tapping it opens a card that lists each source with its share and time left, the odds of the food in your bag on your bowl, and the next crate's odds. The first source shows the `luck` context tip from easy-start.md.

### 1e. Not sold

No Luck is sold for Robux in v1. Paid Luck would turn every roll it touches into a paid random item under Roblox's May 2026 rules, and docs/growth/monetization.md keeps those out of the first release. The Lucky Cat is coins only and potions stay earn-only.

### 1f. Contracts

- Config: LuckPerStatueLevel 0.1, LuckMax 3, LuckyDayChance 0.25, LuckyDayWaveLuck 2, LuckyDayPlayerLuck 0.5, LuckyPotionLuck 0.5, LuckyDayWarnSeconds 15.
- `shared/Luck.luau`: `Luck.of(profile, now, luckyDay)` and `Luck.apply(odds, luck)`, both pure, with a spec.
- Clock folder: `LuckyDay` (bool) for the day phase, set at sunrise.
- ProfileSync carries `luck` (the number) and `luckSources` (a list of `{ id, value, endsAt? }`).
- Analytics: `luck_used` (value the Luck number, fields roll kind bait or crate, rarity won, tier) and `lucky_day` (value players in the server, field the area of any Mythical rolled).
- Save change: the `lucky_cat` upgrade level, through the existing `upgradeLevels`.
- Who builds: Gameplay-Engineer (Luck, rolls, Lucky Day, upgrade), UI-Engineer (chip, card, banner, shop row), Model-Agent (the statue at five looks and the plinth), VFX-Agent (the gold sky tint, the statue's level-up sparkle), Animation-Engineer (the waving paw), Sound-Agent (a Lucky Day chime).

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

The reveal keeps its rule that the won piece's rarity shows from the first frame, so nothing looks like a near miss. For a Legendary or Mythical piece only:

- The crate glows in the rarity colour from the moment it appears and shakes for 0.6 seconds before the lid blows open.
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
3. Over many sunrises about one day in four is a Lucky Day, with the banner, the gold sky, the glowing chip and the warning 15 s before.
4. A Lucky Day's wave rolls with Luck x2. A normal day's wave ignores everyone's own Luck.
5. Checking in a Legendary plays the big pull card, the hop and spin and a toast for the whole server; a second Legendary within a minute plays the card but no toast.
6. The first Epic ever gets the small card; the second does not.
7. A Mythical crate piece glows from the first frame, shakes, opens, plays the big pull with "Use it" and toasts the server; a Common piece opens as today.
8. Reduce Motion removes the shake and the turning rays.
9. Gold Leaf in use shows gold trims, gold letters, the glint every 5 s and the night glow, seen from across the street.
