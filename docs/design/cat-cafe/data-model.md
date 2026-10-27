# Cat Cafe Data Model and Balance Tables

Draft v0.10.1, 2026-10-27 (v0.10.1 adds the vfx-animator's display hooks for the Mystery Visitor and potions, sections 12b, 13 and 15; v0.10 folds in the round 4 answers, [feedback/answers-2026-10-27-round4.md](feedback/answers-2026-10-27-round4.md), and Derek's 20:10 Codes Cat stand: a dropped cat walks back to where it was caught, a themed cat may wear two props, every working cat shows its job, foods get rarity badges, the Tip Jar's 60 and 120 minute steps and the Daily Treat's days 2, 4 and 7 get bigger, each Index track gets its own kind of permanent bonus and the Codes Cat gets a stand with a walk-in circle plus the `launch` and `group` codes, sections 3, 5, 8, 10c, 11b to 11e and 13 to 17; v0.9 makes night a short reset from Derek's 19:40 and 19:41 asks: a 90 second night, the catching areas close at dusk and send everyone home, and a fresh wave of strays spawns at sunrise, sections 8b, 9, 10c, 13 and 17; v0.8 folds in Gavin's round 3 answers 1 to 6, [feedback/gavin-2026-10-27-round3.md](feedback/gavin-2026-10-27-round3.md): a catch pushes nearby players back and gives the catcher a short rush, a shove always drops a carried cat for anyone to pick up, the chase runs twice as far with a growing wait and a slow for the player who missed, a Mythical in a new wave is announced, dealer foods come in rolled amounts every 5 minutes, night pays 100% and bait set at night is ready in half the time, day tips pile up on the tables, rich visitors pay more, the Cat Collector and the Mystery Visitor come by day and cats can be locked (sections 2, 4, 8, 8b, 9, 10, 10c, 11, 12, 12b and 13 to 17), plus Derek's 19:33 Codes Cat (section 11d); v0.7 adopts [golden-fish.md](golden-fish.md), which Derek okayed on 2026-10-27 at 19:27 ("looks good"): golden fish, Cafe Crates, the Decor Index, the Golden Fish Market and the Index rewards rebalance, with the contract in sections 11b, 11c and 14 to 17; v0.6 adds the Spin Wheel station, section 11c, and themes the Neighbourhood, Woods and Sewer cats, section 3c, from Derek's 14:35 and 14:36 asks, with looks and kits in [areas-and-stations.md](areas-and-stations.md); v0.5.4 renames the Book to the Index, section 11b, and matches the Tip Jar's claimed list to the engineer's build; v0.5.3 adds the Tip Jar and Index rewards, section 11b, and follows the engineer's gold identifiers; v0.5.2 names the gold cats and makes every Rare and up a themed cat with a prop, section 3 and 4, from Derek's 13:18 and 13:22 asks; v0.5.1 adds the reviewer's S44, S45 and N84 to N86 from docs/reviews/2026-10-27-design-v0.5.md: the self-retry wait after a miss, target-side shove immunity, reachable sprint end points, no shoving from a minigame and a still dropped stray during its owner window; v0.5 folds in Gavin's round 2 answers, [feedback/gavin-2026-10-27.md](feedback/gavin-2026-10-27.md): a missed cat sprints away with unlimited tries, Shove replaces Bump, the bowl moves outside, shinies get their own colour at 5%, one shared dealer stock, the cafe closes at night; v0.2 earlier the same day; v0.3.1 adds the reviewer's findings S23 to S31 from docs/reviews/2026-10-26-design-v0.3.md; v0.4 makes a missed circle end the catch, adds patience paws and the Perfect charm bonus, the back alley layout and walk speeds from Derek's playtest, and syncs the engineer's F22 choices; reasoning in [world-and-feel.md](world-and-feel.md)). Owner: game-designer thread. v0.3 folds in Gavin's answers ([feedback/gavin-2026-10-26.md](feedback/gavin-2026-10-26.md)); the "v0.3 change" notes say what moved so the engineer can diff against what is built. Every number is a first guess. Catalog tables go in `src/shared/Catalog.luau`, tuning numbers in `src/shared/Config.luau`, so QA can tune without touching logic. Field names match [ui-contract.md](ui-contract.md) where they exist; new fields are listed for the UI thread in [features.md](features.md) section 6. Context and reasoning are in [gdd.md](gdd.md).

## 1. Conventions

- Ids are lower snake_case strings and never change once saved: `tabby`, `tables`, `neon_sign`, `tuna`, `barista_1`. Display names can change freely.
- Model names derive from ids per the style guide: cat `tabby` is `CatCafe_Cat_Tabby`, `maine_coon` is `CatCafe_Cat_MaineCoon`.
- Currency is coins, stored as an integer, shown as `$`. Rates are coins per second.
- Rarity strings are exactly `Common`, `Rare`, `Epic`, `Legendary`, `Mythical`. v0.3 change: `Mythical` replaces `Secret` (no cat ever used Secret, so no save holds it).
- Time is server time. Never trust a client clock. Durations that must survive a rejoin (bait) use `os.time()`; sub-second timing (circles, rescue bars) uses `workspace:GetServerTimeNow()` on both sides.
- Chances are stored as 0 to 1 and shown as whole percentages, or one decimal under 1%.
- In code a role slot is still called a spot (`SpotDef`, `spotId`, `spotType`) so the save field and the UI intents keep their names; only the values change (section 5).

## 2. Rarity

| rarity | incomePerSecond | circles | shrinkSeconds | fleeStuds | rescueHits | sellValue | firstCatchReward | color |
|---|---|---|---|---|---|---|---|---|
| Common | 1 | 1 | 1.40 | 24 | 2 | 25 | 50 | #8E97B2 |
| Rare | 3 | 2 | 1.15 | 32 | 3 | 150 | 300 | #5FA8FF |
| Epic | 8 | 3 | 0.95 | 40 | 4 | 600 | 1,500 | #C07CFF |
| Legendary | 25 | 4 | 0.80 | 52 | 5 | 3,000 | 8,000 | #FFC94D |
| Mythical | 75 | 5 | 0.65 | 64 | 6 | 12,000 | 30,000 | #FF5E7E |

`circles` and `shrinkSeconds` drive the net (section 10), `rescueHits` the rescue bar (section 10b). v0.5 change (Gavin, round 2 Q2): `fleeStuds` replaces the v0.4 `patience`; it is how far a stray sprints after a missed catch before anyone can try again (section 10). Tries are unlimited for every rarity. v0.8 change (Gavin, round 3 Q3: "double those amounts for both"): `fleeStuds` doubles for every rarity, from 12 / 16 / 20 / 26 / 32 to 24 / 32 / 40 / 52 / 64. v0.3 change: `baseCatchChance` is gone; the circles decide the catch. The Mythical color is a proposal for the UI thread.

## 3. Cat catalog (50 cats, 10 per area)

Each area has four Common, two Rare, two Epic, one Legendary and one Mythical, and each cat lives in exactly one area (Gavin, Q5; area-unique is a round 2 question). `favoriteRole` is one of `barista`, `waiter`, `greeter`, `entertainer`; a cat working its favorite role earns 1.5 times its rating. `incomePerSecond` repeats the rarity rate for the UI's `CatDef`.

v0.3 change: `area` is a single area id (no more `both`), `favoriteSpot` becomes `favoriteRole`, eight new cats fill out the Alleyway and the Park, and three areas get provisional rosters.

Themed cats (Derek, 2026-10-27 13:22: "make the cats more unique like a little hat or glasses and call it nerd cat etc"; themes and props from the asset thread, borrowing the one-hook-per-type idea from Bee Swarm and the costume pets from Pet Simulator, all our own art): Commons stay plain breeds and coats, so a prop means a rarer cat. Every Rare, Epic, Legendary and Mythical is a character named "<Theme> Cat" with one signature prop, a role that fits the theme and a one-line description. Ids do not change (`siamese` is Nerd Cat), so saves, the Index and the `CatCafe_Cat_<Id>` models keep working; only `name`, `favoriteRole` and `description` move. Gavin may still rename them (round 3).

Props: each is its own `CatCafe_Accessory_<Prop>`, attached to the cat model at an Attachment, and the model carries a `PropSlot` attribute: `Head`, `Face` or `Back`. The prop is always worn: on strays, carried, at work, napping, in the Index and on gold cats (a gold cat keeps its prop as modelled; only the coat turns gold). A working cat leaves off the piece of its role outfit that sits in the prop's slot: a Head prop drops the role hat (BaristaCap, Boater, PartyHat), a Back prop drops the Entertainer Cape, and a Face prop clashes with nothing, so the other outfit piece still marks the cat as staff. No neck props: scarves, bandanas and bells read as collars, which Derek ruled out. Neighbourhood, Woods and Sewer get themed Rares and up when their cats are modelled. v0.10 (round 4 Q6: "one or two props is fine"): a themed cat may wear a second prop in a different slot. The root model then also carries `PropSlot2`, and the second prop's parts are named `..._Prop2` with the same `Follows` attribute; ideas for the 18 later area cats are in [area-ideas.md](area-ideas.md), and none is built until picked. Q7 ("Make sure all cats can at least where one tell tale sign of role"): see section 5. Q8 ("Yes thats a great idea make them special because of rarity"): a gold Legendary or Mythical keeps its effect (Ninja Cat's glowing eyes, Wizard Cat's stars, Fairy Cat's petals, Astro Cat's glow and the later areas' effects), recoloured gold, so the rarest gold cats look the most special (vfx-animator).

### 3a. Alleyway (`alley`), in the slice

| id | name | rarity | favoriteRole | description | art notes |
|---|---|---|---|---|---|
| tabby | Tabby | Common | barista | The starter. Stripes, snacks, naps. | stripes; fur_orange, fur_orange_dark, eye_amber |
| tuxedo | Tuxedo | Common | waiter | Dressed for dinner, waiting for it. | patches; fur_black, fur_white chest, eye_green |
| ginger | Ginger | Common | greeter | Warm, round, always in the sun. | solid; fur_orange, eye_green |
| smoke | Smoke | Common | entertainer | Grey as a rainy morning. | solid; fur_grey, eye_green |
| calico | Pirate Cat | Rare | waiter | Carries every tray like buried treasure. | Calico coat (patches; fur_white, fur_orange, fur_black); prop eye patch (Face) |
| tortie | Rocker Cat | Rare | entertainer | Knows one chord and plays it very loudly. | Tortie coat (black with ginger); prop mini guitar (Back) |
| sphynx | DJ Cat | Epic | greeter | Drops a beat every time the door opens. | Sphynx (peach skin, violet eyes; the one shape exception); prop headphones (Head) |
| maine_coon | Bandit Cat | Epic | barista | Sneaks extra foam onto every latte. | Maine Coon (silver tabby, white ruff; scale 1.2); prop black eye mask (Face) |
| void | Ninja Cat | Legendary | waiter | Silent, fast and never spills a drop. | Void coat (pure black, glowing eyes, sparkle); prop headband with trailing tails (Head) |
| midnight | Wizard Cat | Mythical | barista | Stirs a little starlight into every cup. | Midnight coat (night sky, star speckles, glow); prop starry wizard hat (Head) |

### 3b. Park (`park`), in the slice

| id | name | rarity | favoriteRole | description | art notes |
|---|---|---|---|---|---|
| snow | Snow | Common | waiter | All white, hates the muddy paths. | solid; fur_white, eye_blue |
| cream | Cream | Common | barista | The color of a latte, and smells faintly of one. | solid; fur_cream, eye_amber (new) |
| brownie | Brownie | Common | entertainer | Chocolate stripes, chases every leaf. | stripes; fur_brown, fur_brown_dark (new) |
| blue | Blue | Common | greeter | Silver-blue and very polite. | solid; fur_grey blue tint, eye_green (new) |
| siamese | Nerd Cat | Rare | barista | Measures every latte to the last drop. | Siamese (cream, seal points, eye_blue); prop big round glasses (Face) |
| bengal | Explorer Cat | Rare | entertainer | Tells tall tales about the wild side of the Park. | Bengal (sand with dark spots); prop safari hat (Head) |
| ragdoll | Sleepy Cat | Epic | greeter | Says hello with an enormous yawn. | Ragdoll (white, blue points; scale 1.2); prop nightcap with a pom (Head) |
| persian | Fancy Cat | Epic | waiter | Serves every cup on a silver tray. | Persian (lavender long coat); prop top hat and monocle (Head) |
| blossom | Fairy Cat | Legendary | barista | Leaves a petal on every saucer. | Blossom (rose and white, petal particles); prop fairy wings (Back) |
| aurora | Astro Cat | Mythical | entertainer | Moonwalks between the tables. | Aurora (galaxy gradient, glow); prop glass bubble helmet (Head) |

### 3c. Neighbourhood, Woods and Sewer (after the slice)

v0.6 (Derek, 2026-10-27 14:35: "you draft some ideas for models for those places"): the Rares and up are themed cats like 3a and 3b. Ids and favorite roles are unchanged; names, descriptions and props are drafts Gavin can rename (round 3 Q22). Each area's look, kit and coat ideas are in [areas-and-stations.md](areas-and-stations.md) Part A. Effects (Legendary and Mythical) belong to the vfx-animator. The Commons keep their placeholder names in the table after this one.

| id | area | name | rarity | favoriteRole | description | prop (slot) |
|---|---|---|---|---|---|---|
| munchkin | neighbourhood | Skater Cat | Rare | entertainer | Lands every trick, eventually. | skateboard on its back (Back) |
| fold | neighbourhood | Painter Cat | Rare | waiter | Carries every plate like a masterpiece. | beret with a paint splat (Head) |
| chonk | neighbourhood | Chef Cat | Epic | barista | Taste-tests every pastry, twice. | tall chef hat (Head) |
| postie | neighbourhood | Mail Cat | Epic | greeter | Knows every customer by name and address. | mail carrier's cap (Head; a satchel would clip the greeter sash, N130) |
| marshmallow | neighbourhood | Super Cat | Legendary | waiter | Catches every falling cup before it lands. | red hero cape (Back); cape flutter and whoosh trail |
| comet | neighbourhood | Ice Cream Cat | Mythical | entertainer | Hands out a sprinkle with every smile. | ice cream cone hat with a cherry (Head); floating sprinkles |
| pinecone | woods | Scout Cat | Rare | barista | Always prepared, especially with snacks. | backpack with a bedroll (Back) |
| forest_cat | woods | Lumberjack Cat | Rare | greeter | Waves every customer in with a mighty paw. | red plaid cap with ear flaps (Head) |
| toadstool | woods | Mushroom Cat | Epic | entertainer | Bounces between the tables like a little spring. | red-spotted mushroom cap (Head) |
| firefly | woods | Firefly Cat | Epic | waiter | Lights up every table it visits. | jar of fireflies on its back (Back) |
| old_oak | woods | Antler Cat | Legendary | barista | Brews tea from leaves only it can find. | mossy antlers with tiny flowers (Head); drifting leaves |
| wisp | woods | Unicorn Cat | Mythical | greeter | Every customer leaves a little more sparkly. | glowing horn (Head); sparkle trail |
| lantern | sewer | Miner Cat | Rare | waiter | Lights the way to every table. | hard hat with a lamp (Head) |
| bubbles | sewer | Bubble Cat | Rare | entertainer | Blows a bubble for every customer. | bubble pipe in its mouth (Face) |
| gears | sewer | Steampunk Cat | Epic | barista | Fixes the espresso machine with one paw. | brass goggles (Face) |
| glimmer | sewer | Diver Cat | Epic | greeter | Swims all the way from the canal to say hello. | snorkel and mask (Face) |
| bottlecap | sewer | King Cat | Legendary | waiter | Rules the canal town and still clears every table. | crown made of bottle caps (Head); glinting caps |
| eclipse | sewer | Dragon Cat | Mythical | barista | Warms every cup with one tiny puff. | little dragon wings (Back); tiny harmless sparks and smoke puffs |

The full roster for these areas, Commons included:

| area | Common | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|
| `neighbourhood` | biscuit Biscuit (barista), pepper Pepper (waiter), socks Socks (greeter), butter Butter (entertainer) | munchkin Skater Cat (entertainer), fold Painter Cat (waiter) | chonk Chef Cat (barista), postie Mail Cat (greeter) | marshmallow Super Cat (waiter) | comet Ice Cream Cat (entertainer) |
| `woods` | moss Moss (greeter), acorn Acorn (barista), bramble Bramble (waiter), fern Fern (entertainer) | pinecone Scout Cat (barista), forest_cat Lumberjack Cat (greeter) | toadstool Mushroom Cat (entertainer), firefly Firefly Cat (waiter) | old_oak Antler Cat (barista) | wisp Unicorn Cat (greeter) |
| `sewer` | rusty Rusty (waiter), soot Soot (barista), pipes Pipes (entertainer), puddle Puddle (greeter) | lantern Miner Cat (waiter), bubbles Bubble Cat (entertainer) | gears Steampunk Cat (barista), glimmer Diver Cat (greeter) | bottlecap King Cat (waiter) | eclipse Dragon Cat (barista) |

Which cat within a rarity: a uniform pick among that area's cats of that rarity (four Commons, two Rares, two Epics, one each above). Bait picks across all unlocked areas (section 8).

## 4. Cat instances, gold cats and names

A cat the player owns is an instance: `{ uid, catId, variant, caughtAt, spotId, level, xp, charm, rescued, name, method, locked }`.

- `uid`: unique string from the server.
- `variant`: `base` or `gold` (`shiny` in version 3 saves). v0.3 change: Golden and Galaxy are dropped; there is no merging. A gold cat earns GoldMultiplier 1.5 and shows a sparkle on its model, its card and its Index entry. v0.5 (Gavin, round 2 Q5: "A shiny also has a different color variation"): every cat also gets its own gold coat, an alternate set of palette swatches on the same mesh, made by the asset thread. Derek picked gold for all of them on 2026-10-27 (round 3 Q4, option B: "change shiny to gold and make it gold modeled"), so each gold cat is the same cat modelled in gold. Gold chance by how the cat was found: net stray GoldChanceNet 0.05 (v0.5, was 0.02; rolled at spawn and visible as the gold coat and sparkle on the stray), bait GoldChanceBait 0.05 (v0.5, was 0.02; rolled when the food goes in, revealed when the cat arrives), rescue GoldChanceRescue 0.10 (rolled at night start, revealed when the cat comes out). A knocked-loose cat keeps its variant and charm.
- Name (Derek, 2026-10-27 13:18: "change “shiny” to be called gold also"): players only ever see the word Gold, never Shiny: "Gold Tabby" on cards, the Gold badge and filter chip, "Gold 5%" on food cards, the Index's Gold page, "Sam caught a gold Rare Tabby!" in announcements. The engineer renamed the code to match (save version 4): variant `"gold"`, `goldCollection`, the `Gold` attribute, the `Gold*` Config constants and the `gold_found` event; loading a version 3 save reads its `"shiny"` variant and `shinyCollection` as gold, so no saved cat loses its coat. The sparkle sprite keeps its file name `CatCafe_VFX_ShinySparkle`. Gold the colour (buttons, Perfect grades, coin piles) stays as it is.
- `spotId`: the role slot the cat works, or nil in the cat room (section 5).
- `level`, `xp`, `charm`: the per-cat stats in section 4b, unchanged.
- `rescued`: true for a rescued cat. v0.3 change: it no longer pays more (RescuedTipsMultiplier is 1.0); the rescue reward is the gold chance. The flag stays for the Index and analytics.
- `name`: the player's name for this cat, or nil to show the catalog name. Validation (S30): trim, then 1 to CatNameMaxLength (20) characters counted with `utf8.len` (not `#`); reject invalid UTF-8, control characters, newlines, `<` and `>`. RenameCat filters it once with `TextService:FilterStringAsync` and refuses with a toast if filtering errors or the filtered text is all hashes, so the old name stays. The save keeps the raw name; whenever the name is shown (the cat starts working, or the profile loads with the cat working; at most 10 cats) the server filters it again for broadcast (`GetNonChatStringForBroadcastAsync`) and sets `DisplayName`, because the filter changes over time. If that display filter fails, `DisplayName` falls back to the catalog name.
- `locked` (v0.8, Gavin, round 3 Q6: the Cat Collector asks only for cats "that are not equipped or locked"): a locked cat cannot be sold or traded to the Cat Collector (section 12b). `LockCat(uid, locked)` sets it from the lock icon on the cat card. Gold, Legendary and Mythical cats arrive locked and the save 8 migration locks the ones already owned, so one quick tap never sells or trades away a player's best cat. A missing field loads as false.
- `method`: `net`, `rescue`, `bait` or `starter`, for the Index and analytics. A v2 cat saved as rescued migrates with method `rescue` (engineer's F22, PR #38).

## 4b. Cat stats: charm, level, XP and rating (`src/shared/CatStats.luau`)

Built 2026-10-26 by the cat stats thread and unchanged in v0.3 except the multipliers named below. Everything is deterministic given the saved fields; the server sends it in `CatView`.

- `charm` 0 to 100, rolled once (now at spawn for strays and rescues, at food placement for bait) and never changed after the cat is owned. v0.4 change: a net catch adds the Perfect bonus to the stray's charm at the moment of the catch (section 10, step 5). The average of two uniform rolls times 101, floored and clamped. Most cats sit near 50; about 8% are 80 or above.
- `stars` 1 to 5 from charm in bands of 20.
- `charmMultiplier = 1 + (charm - 50) / 50 x CharmSpread` (0.20): 0.8x to 1.2x. The starter Tabby has charm 50.
- `level` 1 to CatMaxLevel (10), `levelMultiplier = 1 + CatLevelBonus x (level - 1)` (0.05), so level 10 is 1.45x.
- `xp` counts seconds working a role slot; XP from level n to n + 1 is `CatXpBase x n` (60 x n). Only online time counts.
- `rating = rarity rate x charmMultiplier x levelMultiplier x variantMultiplier`. `variantMultiplier` is GoldMultiplier for a gold cat, else 1. A perfect max-level gold Wizard Cat rates 75 x 1.2 x 1.45 x 1.5 = 195.75.
- `maxRating(catId)` is the rating at charm 100 and max level, base variant, for the Index's potential line; the Index also shows the gold figure.
- Sort order (`CatStats.isBetter`): rating, then rarity, then catId, then uid.
- Equip Best (`src/shared/EquipBest.luau`, remote `EquipBest`): unchanged algorithm, now over at most 10 role slots with `favoriteRole` in place of `favoriteSpot`.

## 5. Roles (replaces spot types)

v0.3 change (Gavin, Q12): the six spot types become four roles. Each role slot is a station in the plot model where the assigned cat sits on the seated body (`CatCafe_Cat_<Name>_Sit`) in that role's outfit (v0.6, Derek's body picks on 2026-10-27; it stood upright before). All roles pay the same in v0.3: `rating x favoriteMultiplier` where favoriteMultiplier is 1.5 when the slot's role equals the cat's `favoriteRole`. Role-specific boosts for certain cats are later content.

| role (`spotType`) | station | uniform | slot ids in opening order |
|---|---|---|---|
| barista | counter with the espresso machine | apron | barista_1 (T1), barista_2 (T3), barista_3 (T5) |
| waiter | between the tables | bow tie | waiter_1 (T1), waiter_2 (T2), waiter_3 (T4) |
| greeter | inside the door | sash | greeter_1 (T2), greeter_2 (T4) |
| entertainer | cat tree stage | party hat | entertainer_1 (T3), entertainer_2 (T5) |

v0.10 (round 4 Q7: "Make sure all cats can at least where one tell tale sign of role", and Derek's 18:39 rule that every cat can do every job without the outfit or prop getting in the way): every working cat shows at least one piece of its role outfit. The Barista's apron, the Waiter's bow tie and vest and the Greeter's sash sit on the body, and no prop ever uses the body, so those roles always show. Only the Entertainer's two pieces (party hat on the Head, cape on the Back) can both clash: an Entertainer whose props fill both its Head and its Back wears the party hat in place of its head prop while it sits at the station (`CatPose.dress` hides that prop's parts and shows them again when the cat leaves). With one prop nothing changes.

`SpotDef` becomes `{ id, spotType, tier }`; `tier` replaces `cafeLevel` as the tier that opens the slot. Slots per tier: 2, 4, 6, 8, 10.

## 5b. Tiers (replaces cafe level and Renovate)

v0.3 change (Gavin, Q18): no rebirth and nothing resets. `tier` is a profile field from 1 to 5, raised only by the `RankUp` remote when every requirement is met. Coins are spent on rank up (Gavin confirmed, round 2 Q6). "Different cats" counts entries in `collection` (distinct catIds, gold cats not counted twice).

| tier | name | cost | different cats | also needs | role slots | tierMultiplier | opens area | shop caps (tables, espresso, net) | decor and other unlocks |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Corner Cafe | start | | | 2 | 1.00 | alley | 2, 2, 1 | bait bowl |
| 2 | Cozy Cafe | 1,500 | 5 | | 4 | 1.25 | park | 4, 3, 2 | plants, rug; cafe expansion 1 |
| 3 | Busy Cafe | 8,000 | 12 | one Epic or rarer | 6 | 1.50 | neighbourhood | 6, 4, 3 | neon sign; expansion 2 |
| 4 | Famous Cafe | 30,000 | 20 | one Legendary or rarer | 8 | 1.75 | woods | 6, 5, 3 | fish tank, patio; expansion 3 |
| 5 | Grand Cafe | 120,000 | 30 | two different Legendary or rarer cats | 10 | 2.00 | sewer | 6, 5, 3 | "Grand Cafe" leaderboard tag; expansion 4 |

Each column is reachable from the areas already open: Tier 2 needs 5 of the Alleyway's 10, Tier 3 needs 12 of 20, Tier 4 20 of 30, Tier 5 30 of 40. "Cafe expansion n" is a plot model variant the world builder swaps in (more floor, the patio at T4); in the graybox it is extra floor Parts. The UI shows a rank up card with each requirement ticked or not. Rarity requirements mean that rarity or rarer (reviewer N44): the check counts distinct catIds in `collection` whose rarity rank is at least `needsRarity`, so a Mythical meets "one Epic" and a Legendary plus a Mythical meets Tier 5. The card reads "1 Epic or better" and "2 Legendary or better".

`TierDef = { tier, name, cost, distinctCats, needsRarity?, needsRarityCount?, slots, multiplier, area, caps = { tables, espresso, net } }`.

## 6. Upgrade catalog

UI `UpgradeDef` fields. `costs[n]` is the cost of level n. `startLevel` is 1 for espresso, 0 otherwise. v0.3 change: `cafe_level` and `park_access` are removed (tiers do both), `requiresCafeLevel` becomes `requiresTier`, and `requiresTierAtLevel` caps levels by tier (the caps column in section 5b).

| id | name | description | maxLevel | costs | requiresTierAtLevel | effect per level |
|---|---|---|---|---|---|---|
| tables | Tables | Each table seats two more customers and adds tips | 6 | 100, 250, 600, 1500, 3500, 8000 | 3 to 4 need T2, 5 to 6 need T3 | +0.10 cafe multiplier, +2 seats |
| espresso | Espresso machine | Better coffee, bigger tips from every cat | 5 | 0, 300, 1200, 4000, 12000 | 3 needs T2, 4 needs T3, 5 needs T4 | +0.15 cafe multiplier per level above 1 |
| net | Net | Wider timing windows and steadier circles | 3 | 500, 3000, 15000 | 2 needs T2, 3 needs T3 | section 10 net table |
| lure_bowl | Bait bowl | A bowl by your door; put food in and a cat comes by | 1 | 400 | | enables bait (section 8) |

Net level names for the UI: 0 Basic Net, 1 Sturdy Net, 2 Pro Net, 3 Master Net.

## 7. Decor catalog

UI `DecorDef` fields; `requiresCafeLevel` becomes `requiresTier`. Bonuses apply only while placed. Decor a v2 save placed above its new tier stays placed with no refund (engineer's F22).

| id | name | cost | category | effect | requiresTier | bonus |
|---|---|---|---|---|---|---|
| plants | Window plants | 150 | Plants | +5% tips | 2 | +0.05 |
| rug | Cozy rug | 400 | Floor | +5% tips | 2 | +0.05 |
| neon_sign | Neon cat sign | 1,500 | Wall | +10% tips | 3 | +0.10 |
| fish_tank | Fish tank | 5,000 | Furniture | +10% tips, cats stare at it | 4 | +0.10 |
| index_alley | Alley Mural Print | Index | Wall | +5% tips | | +0.05 |
| index_park | Park Bench | Index | Furniture | +5% tips | | +0.05 |
| index_neighbourhood | Mailbox Planter | Index | Plants | +5% tips | | +0.05 |
| index_woods | Mushroom Lamp | Index | Furniture | +5% tips | | +0.05 |
| index_sewer | Pipe Fountain | Index | Furniture | +5% tips | | +0.05 |
| index_alley_gold, index_park_gold, ... | the same five in gold | Index | as above | +10% tips | | +0.10 |

Index decor (F48, section 11b) is never sold: `cost` 0 with `source = "index"`, BuyDecor refuses it, and only ClaimIndexReward grants it. The Decor screen shows it as "Index reward" with no Buy button and the milestone that unlocks it ("All 10 Alleyway cats"), locked until claimed, then Place or Remove like any owned decor (reviewer N113). An area's normal and gold pieces do not stack (N114): each gold row carries `replaces = "book_<area>"`, and while both are placed only the gold +0.10 counts, so the five areas top out at +25% tips, or +50% with every gold set. The Alleyway and Park pieces are needed for the slice; the asset thread can make the print from the existing Alley mural and the gold pieces with the metal gold swatches.

## 8. Bait (lure catalog and the bowl)

v0.3 change (Gavin, Q7): bait moves from shared lure spots in the areas to one bait bowl at your own cafe, the wait is 10 minutes, and the cat that arrives is offered as Tame or Let go. Lure spots, reservations, the calm bonus and refunds are gone.

Rules:

- The bowl is the `lure_bowl` upgrade, one per player. v0.5 (Gavin, round 2 Q4: "The bowl sits out side of your cafe"): the plot's `BaitBowl` anchor moves outside, to the back step facing the Alleyway, where the strays would come from. Other players can see the bait cat eating, but only the owner can Tame or Let go.
- `UseLure(lureId)` near the bowl (12 studs) with the bowl empty and food in stock consumes one food at once. The server rolls everything then and saves it in `profile.bait`: rarity from the food's odds, the cat uniformly among that rarity's cats in every area the player has unlocked, charm, and gold (GoldChanceBait). Rolling at placement means rejoining cannot reroll.
- The cat is ready at `placedAt + LureWaitSeconds` (600, server `os.time()`), and the timer runs while the player is offline. v0.8 (Gavin, round 3 Q6: "some sort of night event or bonus speeding up of the cat food that's set outside cafe as bait"): food that goes in while the player's server is in night is ready after LureWaitSecondsNight (300) instead. `UseLure` reads `Phase` at placement and saves `bait.readyAt`, so the wait never changes later and a rejoin or a server hop cannot move it (a save without `readyAt` uses `placedAt + 600`). The bowl countdown shows a moon and "Night bait: half the wait", and at dusk the HUD reminds players with an empty bowl. The HUD shows the countdown. Until ready, ProfileSync sends only `lureId` and `readyAt`, never the rolled `catId`, `variant` or `charm`, so the reveal is not spoiled (N30).
- When ready and the owner is in the server, the cat model sits eating at the bowl and the bait card shows its name, rarity, stars and sparkle with two buttons: Tame and Let go. `ResolveBait("tame")` adds the instance (method `bait`) straight to the cat room, fires `CatCaught` and empties the bowl; no net and no carry. `ResolveBait("letgo")` empties the bowl. The food is used either way.
- Odds are on every food card before purchase, with the per-cat line ("Legendary 2.6%, split equally across the 2 Legendary cats in your areas, 1.3% each"). A tier up that opens a new area changes the per-cat split, and the card says so. Every food card (shop and dealer) also shows the gold chance (5% from v0.5) and the charm star odds, because both change income: 1 star 7.8%, 2 stars 23.5%, 3 stars 35.7%, 4 stars 24.3%, 5 stars 8.7% (growth thread; required if coins are ever sold, shown from day one).
- Catnip (common-features item 14, launch) shifts only the wave spawn rolls in the areas. It never changes bait or dealer rolls, so food card odds stay fixed.

Shop foods (`LureDef`, `source = "shop"`):

| id | name | cost | attracts | odds Common / Rare / Epic / Legendary / Mythical | description |
|---|---|---|---|---|---|
| kibble | Kibble | 25 | Common | 70 / 25 / 4 / 0.9 / 0.1 | Cheap and crunchy. Brings the regulars. |
| tuna | Tuna | 100 | Rare | 40 / 45 / 12 / 2.6 / 0.4 | The good stuff. Rare cats come running. |
| salmon | Salmon | 500 | Epic | 15 / 45 / 30 / 8.5 / 1.5 | Nobody can resist it, not even the Ninja Cat. |

v0.10 (round 4 Q11: "make the food for bait noticable rarities so people know whats good"): every food gets a `rarity` on its `LureDef`, a grade of how good the food is, shown as a badge and border in the cat rarity colours wherever the food appears (shop, bag, bowl, dealer, prize pictures): Kibble Common, Tuna Rare, Moonlit Sardines Rare, Salmon Epic, Caviar Epic, Moon Milk Legendary, Star Treat Mythical. The odds and the `attracts` chip stay on every card, so the badge never replaces the real numbers.

## 8b. The night food dealer

v0.3 addition (Gavin, Q10). A cart with the dealer NPC parks on the street at night start and leaves at day start. Proximity prompt (12 studs) opens the dealer screen.

- v0.8 (Gavin, round 3 Q5: "stock is per player and same items are rolled globally across all servers might role 0 of an item or a couple rarer the item the less odds and more expensive, resets every 5 min"): the three slots go, and the slot rules below are replaced where they differ. Every window the dealer stocks each of the four dealer foods with an amount rolled from `DealerAmountWeights` (table below), still seeded only by the window as `Random.new(hash(dealerWindow))` and rolled in the order sardines, caviar, moon_milk, star_treat, so every server shows the same amounts. The amount is per player: each player can buy up to that many of each food in the window, and one player's buys never lower another's. A food with an amount of 0 shows greyed with "None this time". DealerWindowSeconds drops from 600 to 300. `profile.dealer` becomes `{ window, bought = { [lureId] = count } }`; a saved `bought` keyed "1" to "3" is dropped on load, and since `floor(os.time() / 300)` is always above the old 600 second window number, the first new window starts fresh anyway. `BuyDealerFood(lureId, window)` replaces `(slot, lureId)`: night, the cart within 12 studs, `lureId` a dealer food, `window` equal to the server's current window (a buy sent across a roll is refused and answered with DealerStock, which keeps S42: nobody buys stock they never saw), `bought[lureId]` below that food's amount, affordable. DealerStock becomes `{ window, restocksAt, stock = { { lureId, cost, amount, bought } } }` in the same food order. Prices stay as they are, so the rarer foods stay the dearest.
- v0.5 (Gavin, round 2 Q9: "Every server shares one stock"): one stock for everyone. Three slots, each one food from the dealer table, rolled from `DealerSlotWeights` (one row now; tiers no longer change it) and seeded only by the global time window, `dealerWindow = floor(os.time() / DealerWindowSeconds)` (600), as `Random.new(hash(dealerWindow))`, so every player on every server sees the same three foods and a rejoin or a server hop cannot reroll (S27). Each player can still buy each slot once per window (round 3 question: once each, or a limited amount everyone races for); bought slots are saved in `profile.dealer = { window, bought }` (`bought` keyed by the strings "1" to "3" so the save stays JSON-shaped, engineer's F22), cleared only when the current window is greater than the saved one (N32: server clocks differ by a second or two, so a hop at a boundary can go from W + 1 back to W), so a rejoin or a server hop cannot buy twice. Server nights are not aligned with windows, so a window can roll over mid-night: the stock refreshes then and the dealer screen shows "Fresh stock in m:ss".
- Stock and prices are shown before buying. Bought dealer food goes into `lures` and is used in the bowl like shop food, with its odds on its card.
- `BuyDealerFood(slot, lureId)`: night, cart within 12 studs, slot 1 to 3, not bought this window, affordable. The server recomputes the stock from the seed at purchase time rather than trusting a cached or client value, and refuses the buy when the recomputed slot holds a different food than `lureId` (reviewer S42: a Buy that lands just after a window roll must not buy the new item the player never saw). After every BuyDealerFood, bought or refused, the server sends `DealerStock` so the Buy button gets a definite answer.
- Later: an upgrade that improves the dealer's weights (Gavin's "upgrade or someway"), not in v0.5. With one shared stock an upgrade could only add a personal fourth slot.

Dealer foods (`LureDef`, `source = "dealer"`):

| id | name | cost | odds Common / Rare / Epic / Legendary / Mythical | description |
|---|---|---|---|---|
| sardines | Moonlit Sardines | 800 | 30 / 45 / 20 / 4.5 / 0.5 | Silvery and still glowing a little. |
| caviar | Caviar | 3,000 | 10 / 35 / 38 / 14 / 3 | Tiny, shiny and very fancy. |
| moon_milk | Moon Milk | 10,000 | 0 / 20 / 45 / 28 / 7 | Nobody knows where he gets it. |
| star_treat | Star Treat | 40,000 | 0 / 0 / 40 / 45 / 15 | It twinkles. Mythical cats can smell it from the next area. |

Each dealer food's `attracts` chip is its likeliest rarity: sardines Rare, caviar Epic, moon_milk Epic, star_treat Legendary (engineer's F22).

`DealerSlotWeights` (chance per slot of sardines / caviar / moon_milk / star_treat), v0.5 one row for everyone (the old Tier 3 row): 50 / 33 / 14 / 3. The v0.3 per-tier rows (Tier 1 70 / 25 / 5 / 0 up to Tier 5 30 / 36 / 24 / 10) are retired. v0.8 retires `DealerSlotWeights` too.

`DealerAmountWeights` (v0.8), the chance in percent that a window stocks 0, 1, 2, 3 or 4 of each food:

| food | 0 | 1 | 2 | 3 | 4 | average |
|---|---|---|---|---|---|---|
| Moonlit Sardines | 15 | 25 | 30 | 20 | 10 | 1.85 |
| Caviar | 35 | 40 | 20 | 5 | 0 | 0.95 |
| Moon Milk | 60 | 35 | 5 | 0 | 0 | 0.45 |
| Star Treat | 90 | 10 | 0 | 0 | 0 | 0.10 |

A Star Treat turns up about one window in ten. Since v0.9 a night lasts 90 seconds, so most nights see one window and about one in four sees a restock part way through; coins still limit what a player buys because the prices are unchanged. The dealer is the main reason to be out at night, and the plaza is under 10 seconds from every cafe door. The dealer screen shows these chances per food, as it showed the slot weights.

## 9. Areas, the clock and spawning

Clock (Gavin, Q1): DayLengthSeconds 300 then NightLengthSeconds 300, exposed as `Phase` and `PhaseEndsAt` on the `Clock` folder in ReplicatedStorage. A new server starts in day with ServerStartDaySeconds 120 left. v0.9 (Derek, 2026-10-27: "I think changing night to be shorter since there is less content overnight currently is a good idea and its mostly just to reset cat spawns" (19:40), "cat spawns should be in waves on every night reset and you should be sent to spawn/cafe area if you were in a zone when night hits" (19:40) and "and not allowed into zones at night" (19:41)): NightLengthSeconds becomes 90 and ServerStartDaySeconds 300, so the loop is 5 minutes of day and a 90 second night, 6.5 minutes in all, and a new server opens at sunrise with a fresh wave (below). Night is now the reset between hunts, spent at the cafe and the plaza: the dealer, the Spin Wheel, the Golden Fish Market and the Codes Cat stay open, the cafe is closed with the cats napping and still earning the full rate, and food set in the bowl is ready in half the time.

v0.9 night closing (F66). These rules replace the night start wave below where they differ:

- Dusk warning: DuskWarningSeconds (15) before night, every player in a catching area gets the banner "Night falls in 15 s! The areas close until sunrise." and the HUD clock chip counts down.
- At night start the catching areas close. Each area's gate and SAFE ZONE stripe turns into a closed fence with a moon sign (solid on the client, like a locked area's gate), the back doors onto the Alleyway show "Closed until sunrise", and the bait bowl on the back step stays reachable because it is on the cafe side of the stripe. `Travel` to an area answers "The areas are closed at night. They open at sunrise." and the travel buttons grey out with a moon.
- Sent home: at night start, and then every NightSweepSeconds (2) during night, the server moves any character standing inside a catching area home, the same move as `Travel("home")`: to their own cafe door, or to the street spawn if they have no plot. Toast: "Night fell, so you headed home." A player in the middle of a catch or rescue finishes it first (an attempt lasts a few seconds at most) and is moved when it ends. The server also refuses GrabBegin, RescueBegin, PickUpCat and Bump in a catching area at night, so walking through the fence on a modified client gains nothing.
- Nothing is lost at dusk. A player carrying a cat goes home with it and it is checked in for them on arrival (`CatCaught` as usual). A Dropped stray goes to its last carrier and is checked in for them if they are still in the server; otherwise it leaves with the rest. This replaces the DroppedMinStaySeconds rule (S32), whose job was to keep a knocked-loose cat alive across a wave.
- Clearing: at night start every area despawns its strays and empties its rescue traps (a stray or trap held by an attempt in progress goes when that attempt ends). Nothing spawns during night.
- Sunrise wave: at day start each area spawns WaveSize (10) strays at once from its odds and fills its rescue traps (RescueSpawnChance and RescueMinStuck as before), then the fences open with the banner "Sunrise! Fresh cats in every area." The Mythical announcement (v0.8 below) fires at this moment, which is the "day reset" Gavin asked about. Strays stay catchable all day until the next dusk.
- We read "in waves on every night reset" as one fresh wave per reset, as now, not several small waves in a day.
- Pace: the day is now about 77% of the loop (was 50%), so a player meets about 1.5 times as many strays an hour and the day-only tip piles and visitors come more often. QA's loop script re-times Tier 2 (10 to 20 minutes) with F66 in. Lighting, the cafe sign (sun or moon), customers, the dealer cart and the HUD chip follow `Phase`.

Night waves (Q2, Q3): at every night start each area despawns its uncaught strays and spawns WaveSize (10) strays at once from its odds; a dropped (knocked-loose) stray counts as uncaught only if it was dropped more than DroppedMinStaySeconds (120) before the wave starts; a younger one skips that wave (S32). Leftovers stay catchable by day until the next night. Rescue traps roll at night start too. Areas spawn whether or not anyone has them unlocked, so a player who ranks up mid-night finds a wave waiting. v0.8 (Gavin, round 3 Q3: "Possibly announce if a mythical has spawned in an area on the day reset and wipe all cats during night to refresh which can be found"): the wipe and refresh already happen at every night start, which we read as the reset he means. New: when a wave spawns a Mythical stray, the server fires `Announce` to everyone in that server, "A Mythical cat appeared in the Woods!" ("A gold Mythical cat..." when it is gold), once per Mythical and also for players who have not unlocked the area, as a reason to rank up. It names the area and not the cat, so finding it is still a surprise. A Mythical that the tutorial rule or bait brings is not announced.

| id | name | unlock | spawnPoints | waveSize | rescue traps | odds Common / Rare / Epic / Legendary / Mythical |
|---|---|---|---|---|---|---|
| alley | Alleyway | Tier 1 | 24 | 10 | trash_bin x2, garbage_bag x1 | 72 / 22 / 5 / 0.9 / 0.1 |
| park | Park | Tier 2 | 14 | 10 | tree x2, trashcan x1 | 60 / 28 / 9 / 2.5 / 0.5 |
| neighbourhood | Neighbourhood | Tier 3 | 18 (was 14; the area grows to about 140 x 140 studs, Derek 2026-10-27 15:26) | 10 | shed, gutter (provisional) | 50 / 32 / 13 / 4 / 1 |
| woods | Woods | Tier 4 | 16 | 10 | hollow_log, bramble_bush (provisional) | 42 / 34 / 17 / 5.5 / 1.5 |
| sewer | Sewer | Tier 5 | 16 | 10 | drain_pipe, grate (provisional) | 35 / 35 / 20 / 7.5 / 2.5 |

v0.4 layout (engineer, 2026-10-26, after Derek found the old alley too far and too small; design in [world-and-feel.md](world-and-feel.md) section 2): the Alleyway is two back alleys behind the cafe rows that meet in an Alley Square at the north end, at least 8 times the old 60 x 44 box. Every cafe's back door opens onto it from Tier 1, and check-in works at either door. Its 24 spawn points carry `Zone`: `lane` (two behind every cafe, 16) or `square` (8). Epic, Legendary and Mythical strays take only free `square` points (any free point if none is free); Commons and Rares take any. One trash bin per back alley, the garbage bags in the Square. The Park gate stays at the street's south end; the Neighbourhood, Woods and Sewer gates go where world-and-feel.md suggests unless the engineer finds better spots.

Locked areas: a gate model at the entrance is solid on the client for players below the tier, and the server refuses GrabBegin, RescueBegin and Bump in an area the player has not unlocked, so walking past the gate gains nothing.

Area cats (Gavin confirmed, round 2 Q10): a cat spawns only in its own area and never in another; several copies of the same cat can be in its area at once. Bait is not an area spawn, so a bait cat can be any cat from the player's unlocked areas.

Tutorial rule: a player with `tutorialStep` below 2 always finds a Common stray waiting, v0.4 at the `lane` spawn point behind their own cafe so it is right outside the back door. Strays are workspace models with attributes (section 13).

## 10. Net: closing circles

v0.3 change (Gavin, Q6): the hold-and-release ring and the flat catch chance are replaced by a sequence of closing circles judged on the server. v0.4 change (Derek, 2026-10-26: "making the game actually matter if you miss the catch windows"): the first Miss ends the catch with no roll and all Good or Perfect is a sure catch. v0.5 change (Gavin, round 2 Q2): the patience paws are gone; a missed cat sprints away and anyone can chase it and try again, with no limit on tries.

Flow:

1. The stray's Catch prompt is held for CatchHoldSeconds (0.5, hold E; Derek 2026-10-27 12:07, so walking past a stray with a tap of E never starts a catch) and then fires `GrabBegin(strayId)`. Server checks as before (exists, unlocked area, LockedBy 0 or self, 10 studs, not carrying, cooldown), plus v0.5: the stray is not sprinting or catching its breath, and the caller is not inside their own StraySelfRetrySeconds after missing it (step 5, S44). It locks the stray and builds the schedule: `n = circles[rarity]`; circle 1 starts CircleLeadInSeconds (0.6) from now; each circle's shrink time is `shrinkSeconds[rarity] x (1 + u)` with `u` uniform in `[-jitter, +jitter]` for the player's net level; a gap of CircleGapMin to CircleGapMax (0.40 to 0.75 s) separates circles. The target moment of circle i is its start plus its shrink time. The lock lasts until the last target plus GoodWindow plus 1 s, or v0.4 until a Miss ends the attempt, whichever comes first.
2. The server fires `CatchSchedule(strayId, circles, windows)` to that player (v0.5 drops `pawsLeft`): `circles = { { startsAt, shrinkSeconds, x, y } }` in server time (x and y are screen positions 0 to 1 so circles do not sit in one spot), `windows = { perfect, good }` in seconds for drawing the bands.
3. The client draws each circle shrinking onto its ring and fires `CatchPress(strayId, index)` on each press (Space on a keyboard, a tap on touch; UI #168). The client sends no time: the server stamps each press with `GetServerTimeNow()` on arrival and subtracts half the player's round-trip ping (`Player:GetNetworkPing() / 2`, capped at CatchLatencyCapSeconds 0.15).
4. Judging each circle: `error = abs(press - target)`. Within `perfect` is Perfect, within `good` is Good, else Miss (v0.4: grades only, no scores). Only the first press per index counts, presses must come in index order, and a press before a circle's start is ignored. A circle with no press by its target plus `good` plus CatchLatencyCapSeconds is a Miss. Invariant (S24, a Config spec): `CircleGapMin > max(good over net levels) + CatchLatencyCapSeconds`, so a late press for one circle can never land on the next; today 0.40 > 0.18 + 0.15. Raise CircleGapMin whenever `good` is widened.
5. v0.4: the attempt ends at the first Miss or after the last circle, with no roll.
   - Fail (a Miss): the server stops judging and cancels the circles left. v0.5 (Gavin, round 2 Q2: "Any miss ends the catch and the cat sprints away for a bit making the player catch up to it again to retry. unlimited tries for all cats regardless of rarity but the rarer the cat the harder it is to catch"): the stray sprints `fleeStuds[rarity]` (section 2, 24 for a Common up to 64 for a Mythical since v0.8) straight away from the player at StrayFleeSpeed (26, faster than walking), then catches its breath for StrayRestSeconds (1.5) and goes back to wandering. The end point is clamped to the area's `roam` rects and the run stops short at the first prop on its path, so the cat always lands where players can reach it (reviewer N84). Until it stops, GrabBegin from anyone refuses with "It's running!". Once it stops, everyone else can try at once and the player who missed can try again StraySelfRetrySeconds (1) later (reviewer S44: without the wait, one player could miss on purpose and win every race back to the stray, keeping a Legendary from the whole area). The wait lives in the stray's server entry (`selfRetryAt[userId]`). There is no limit on tries for any rarity, so there are no paws. Exception (reviewer N86): a Dropped stray does not sprint while its old carrier's owner window runs (DropOwnerPrioritySeconds, section 10c); it stays put and the old carrier can retry after StraySelfRetrySeconds. After the window it sprints like any stray. The stray mirrors `FleeingUntil` for the client (section 13). Toast: "It got away! Chase it!". Rarer cats are harder through more and faster circles (section 2) and a longer chase. v0.8 (Gavin, round 3 Q3: "Think of some failure repercussions for the player that failed the catching workout fking over the players that have not tried catching the pet yet"): the player who missed pays for it and nobody else does. (a) Their own wait on that stray grows with each miss in a row: StraySelfRetrySeconds becomes the list {3, 6, 10}, so the first miss means 3 s after the stop, the second 6 s and the third and later 10 s, kept in the stray's server entry as `missStreak[userId]` and cleared when anyone catches the stray, when it despawns or after StrayMissStreakResetSeconds (60) without a miss by that player. (b) They are Startled: StartledWalkSpeed (12) for StartledSeconds (2), with "Your paws are shaking!" and the dizzy stars. Everyone else can still try the moment the stray stops, so a player who never tried loses nothing.
   - Walking out of range or finishing a rescue mid-catch (S21, S33) is a Miss.
   - Success (every circle Good or Perfect): the player enters carry (section 10c). Charm bonus: `gain = PerfectCharmBonus (4) x perfectCount`, times PurrfectCharmMultiplier (2) when every circle is Perfect, and 0 for a profile with `flags.autoPress` or when the stray is Dropped (reviewer S36: a dropped cat already carries its bonus, and unlimited tries would let two friends shove and re-catch it up to charm 100); the caught cat's `charm = min(100, strayCharm + gain)` and its stars follow (section 4b).
   - The server fires `CatchResult(strayId, grades, success, charmGain)` (v0.5 drops `pawsLeft`): `grades` lists the judged circles up to and including any Miss, `charmGain` is 0 on a fail. The UI shows each grade as it lands and the charm line; there is no percentage.

Net levels (windows are half-widths in seconds either side of the target; jitter is the spread on each circle's shrink time):

| net | name | perfect | good | jitter |
|---|---|---|---|---|
| 0 | Basic Net | 0.045 | 0.11 | 0.30 |
| 1 | Sturdy Net | 0.055 | 0.13 | 0.20 |
| 2 | Pro Net | 0.065 | 0.155 | 0.10 |
| 3 | Master Net | 0.08 | 0.18 | 0 |

Feel targets for QA (v0.5): a new player with a Basic Net should catch a Common in one or two tries (one slow circle, Good is enough), and a missed Common is a short hop away. A Rare or Epic should feel tense but fair. A Mythical with a Basic Net should take several tries and real chases, and a Master Net should make it fair. Test on a phone on mobile data as well as Wi-Fi: phone ping wanders by 30 to 50 ms against a 45 ms Basic Perfect window (N28). If the Basic Net feels mean on touch, widen `good` before touching anything else, and raise CircleGapMin with it (S24).

Exploit note (reviewer signed off 2026-10-26): the server owns the schedule and the clock, so a client cannot forge a Perfect, but a script that watches the circles and presses on time will score well. That is accepted for the slice (Gavin wants all-Perfect to be 100%). v0.4 raises the stakes: all Good or Perfect is now a sure catch, so a script that presses on time catches every cat it reaches; supply (ten strays per area per night, shared) is still the limit. The exploit check uses the server's own stamped errors, never TelemetryReport (S23): CatService keeps a 50-circle ring buffer per player and sets `profile.flags.autoPress` when the Perfect rate over the last 50 circles is above AutoPressFlagRate (0.95). v0.4, what the flag does (reviewer, 2026-10-26): while set, the profile gets no Perfect charm bonus, and the server sends an `autopress_flag` analytics event when it sets and when it clears. It clears itself when the buffer holds a full 50 circles and their rate is AutoPressClearRate (0.85) or below; the buffer is in memory and empty after a rejoin, so a short buffer never clears a saved flag (reviewer N46). Nothing else is taken away automatically, because a false positive on a child costs more than a script catching cats; Derek reviews flagged accounts from analytics. A script that mixes in Goods stays under the flag, which is also accepted. AnalyticsService has no per-player view, so the check cannot live there. No error-spread test, because network jitter alone spreads a script's arrivals by about 10 ms.

## 10b. Rescue minigames

v0.3 change (Gavin, Q8): the 4 s hold becomes a short minigame on an area-specific trap. A failed attempt never loses the cat.

- At night start each rescue trap holds a stuck cat with RescueSpawnChance 0.6, and every area gets at least RescueMinStuck (1): if no trap rolled a cat, one random trap is filled anyway, so a new player always meets a rescue on the first night (QA, 0.4 cubed is one server in 16 otherwise). Rescue odds are the area odds with every non-Common weight doubled and renormalised (Alleyway 56.3 / 34.4 / 7.8 / 1.4 / 0.16, Park 42.9 / 40.0 / 12.9 / 3.6 / 0.7). Charm and gold (GoldChanceRescue 0.10) are rolled then and kept server-side until the rescue succeeds: not on the stuck cat's model, prompt or attributes (N30). Stuck until rescued or the next night.
- The stuck cat's Rescue prompt is held for CatchHoldSeconds (0.5), like a stray's (Derek 2026-10-27).
- `RescueBegin(rescueSpotId)` checks as before (occupied, unlocked area, lock free or own, 10 studs, not carrying), locks the trap to the player for the attempt and fires `RescueChallenge(rescueSpotId, challenge)`.
- Kind `bar` (trash_bin, garbage_bag, trashcan and the provisional traps except `gutter`): a marker slides back and forth along a bar at RescueBarSpeed[rarity] bar lengths per second, starting at a server-set time and phase, with a target zone RescueZoneWidth[rarity] wide at a server-set position. `RescuePress(rescueSpotId)` is stamped and latency-corrected like a circle press; the server computes where the marker was and allows RescueTolerance 0.03 of the bar. A hit moves the zone to the next server-set position; `rescueHits[rarity]` hits frees the cat. Each miss costs one of RescuePatience (3) paws; out of paws ends the attempt.
- Kind `shake_catch` (tree, and the Neighbourhood's `gutter` from F51, where the hits shake the drainpipe): `rescueHits[rarity] - 1` bar hits shake the branch, then the cat drops and one catch circle (Common shrink time, the Pro Net windows whatever net you own) must score Good or Perfect to catch it. A miss means the cat lands, climbs back up and the attempt ends.
- Every attempt has a deadline (S28): it ends as a fail at RescueAttemptMaxSeconds (15) after RescueBegin, when the player moves more than 14 studs from the trap, dies or leaves, or on RescueCancel. The server keeps the lock and the deadline in its own table.
- Ending without success: the trap unlocks and the cat stays stuck. Other players can try after RescueRetrySeconds (3); the same player waits RescueSelfRetrySeconds (6), so one player or script cannot re-lock the trap at the instant it opens and hold it all night.
- Success: the cat is revealed (sparkle if gold), the player enters carry with `rescued = true`.

| rarity | RescueBarSpeed | RescueZoneWidth |
|---|---|---|
| Common | 0.8 | 0.30 |
| Rare | 1.0 | 0.24 |
| Epic | 1.2 | 0.19 |
| Legendary | 1.4 | 0.15 |
| Mythical | 1.6 | 0.12 |

## 10c. Carry and shove

v0.3 change (Gavin, Q9): one cat at a time on the way home, and other players can knock it loose. This replaces the v0.2 no-stealing rule.

v0.5 change (Gavin, round 2 Q3: "Instead of Bump, make it a shove mechanic. Players are able to shove other players in areas where they can catch cats"): Bump becomes Shove. Any player can shove any other player, carrying or not, but only while both stand inside a catching area the shover has unlocked; the street, the cafes and the yards are safe. The edges are painted (engineer, PR #171, Derek 2026-10-27): red stripes where the cafe district meets the back alleys, at the Alley Square arch and at the Park gate, with SAFE ZONE written on the cafe side; the rule itself is unchanged. A shove pushes the target ShoveKnockbackStuds (10) away from the shover. Characters are client-owned, so the server sends the impulse to the target's client and the engineer picks how to apply it. Shoving a carrier also rolls the knock-loose below, with every protection kept. Our plan, both round 3 questions: a player inside a catch or rescue minigame cannot be shoved, and a shove knocks a carried cat loose half the time. In code the remote, the attributes and the constants may keep their `Bump` names; the player-facing word is Shove. The server sends the target's client only a direction and ShoveKnockbackStuds, never a strength taken from the shover. v0.5.1 (reviewer S45): after a shove lands, nobody can shove that player again for ShoveTargetImmuneSeconds (4), so a group cannot chain-shove one player against a wall; the carry protections below are unchanged. Reviewer N85: a player holding a catch or rescue lock cannot shove either, the Shove key is never E, Space or any key the circles or the rescue bar use, and the Shove button hides while either minigame is up.

v0.8 change (Gavin, round 3 Q1: "No, maybe make it so players are knocked away from the person who caught it or give them a temporary speed boost when captured so whoever catches has a good chance of getting home." Q2: "if you manage to shove a player the cat drops they get knocked a bit back then anyone can hold e to pickup no timer needed and then the original catcher can get push them back to get it."). The answer to Q1 says "or"; we do both because they are small and work together. Where these rules differ from the bullets below, these win.

- Nobody can be shoved during a catch or a rescue (unchanged).
- Getaway: when a net catch or a rescue succeeds, every other player within CatchBurstRadiusStuds (10) of the catcher is pushed CatchBurstStuds (8) straight away from them, with the same client impulse as a shove, and the catcher walks at CatchRushWalkSpeed (24) for CatchRushSeconds (5) before dropping to CarryWalkSpeed. The burst is not a shove: it never knocks a cat loose, starts no cooldown and leaves the shove tables alone, and it skips players holding a catch or rescue lock so nobody is pushed into a miss. Picking up a dropped cat gives neither.
- A shove always drops a carried cat: BumpChance becomes 1.0, so every shove that lands on a carrier past BumpGraceSeconds (3) knocks it loose and "It held on tight!" goes away. The carrier is pushed ShoveKnockbackStuds like any shove target, and the cat lands where they stood, without the 6 to 10 stud scurry.
- Pick up: a Dropped stray has no circles. Its prompt reads Pick up and uses the same hold E (CatchHoldSeconds 0.5), then fires `PickUpCat(strayId)`. Anyone can pick it up, the shover and the old carrier included, with no owner window: DropOwnerPrioritySeconds, the bar on the shover and the BumpImmune carry for whoever takes a dropped stray are removed. The new carry starts with BumpGraceSeconds like any carry, so the old carrier can shove back once those 3 seconds pass, and the existing cooldowns end the tug of war, because a shover cannot shove the same target again for BumpSameTargetSeconds (20).
- `PickUpCat(strayId)`: the stray exists and is Dropped, its area is unlocked for the caller, the caller is within GrabRangeStuds (10), not carrying, holds no lock and is off GrabCooldownSeconds; the first valid call wins and starts the carry. The cat keeps its catId, variant, charm and rescued flag and gains no charm (S36 still holds). GrabBegin on a Dropped stray is refused.
- The Drop button works the same way: inside a catching area the cat lands at the player's feet as a Dropped stray that anyone can pick up; anywhere else it still runs back to its own area. A Dropped stray never despawns by day, and since v0.9 a Dropped stray still lying in an area at dusk is checked in for its last carrier (section 9), so a shove can delay a cat but never lose it.
- Telemetry: `stats.bumpsLanded` now counts drops, and `stats.pickups` counts pick ups.

v0.10 change, the Drop button (round 4 Q4: "Dropping it makes it start walking back to its original spot but still able to be picked up until it makes it back if it makes it back then need to be caught again"). This replaces the Drop rules in the v0.8 bullet above and the 12:07 bullet below. A cat knocked loose by a shove still stays where it fell, as Gavin decided in round 3 Q2.
- Home spot: when a catch or rescue starts, the server saves where the stray stood as `homePos` in its carry record (for a rescue, the trap's foot). A pick up keeps the same `homePos`, so a cat dropped twice still walks to its first spot.
- `DropCat()` puts the cat down at the carrier's feet as a Dropped stray with `Returning` true (no hop and no run), and it walks back to `homePos` at DropReturnWalkSpeed (8, well under a player's walk) along a server path (PathfindingService, or the stray roam mover). This works from anywhere: a cat dropped in the street or the cafe yard walks back into its area.
- While it walks, anyone can pick it up with the hold E and `PickUpCat(strayId)`, the dropper included, with no charm, rush or burst, exactly like a shoved-loose cat.
- When it gets within DropHomeRadiusStuds (2) of `homePos` it stops being Dropped and Returning and is a normal stray again with its catId, variant and charm: the circles are back and a catch is needed. That catch adds no charm (S36), so drop and re-catch is no charm loop. If a blocked path keeps it from arriving within DropReturnMaxSeconds (60), it appears at `homePos`.
- Night: at dusk a walking cat is checked in for its last carrier like any Dropped stray (section 9), and `DropCat` is refused while `AreasOpen` is false ("Keep hold of it, the areas are closed"), so no cat walks into a closed area.
- The engineer's N99 still holds: with no reachable `homePos` (the area has no roam rects), the player keeps the cat. Analytics `drop_outcome` gains `returned` (it got home) next to the pick up outcomes.

- Carry is as built: success sets carry state, walk speed CarryWalkSpeed (16 since v0.4), the held cat model, `CheckIn` at the own door (8 studs) adds the instance. Leaving mid-carry still saves the cat. A carrying player cannot start a catch, a rescue or a bump.
- The carrier's character gets attributes `CarryingCatId`, `CarryStartedAt`, `BumpImmune`.
- Drop (Derek 2026-10-27 12:07, engineer PR #162): `DropCat()` lets the carrier let go, from a Drop button on the carry banner or the G key. Inside a catching area the cat hops down in front of the player; anywhere else (street, cafe, yard) it runs back to a free spawn point in its own area. Either way it becomes a Dropped stray with the player as its old carrier and no shover (droppedBy 0): only that player can catch it for DropOwnerPrioritySeconds (8), nobody is barred after that, a re-catch adds no charm (S36, so drop and re-catch is no charm loop) and it counts for no shove outcome in telemetry (reviewer N100). If its area has no spawn points the player keeps the cat (N99).
- `Bump(targetUserId)`: server checks `targetUserId` is an integer (`Guard.int`) naming a player in the server (`Players:GetPlayerByUserId`) other than the bumper (N29), the bumper is not carrying, both players are inside one catching area the bumper has unlocked (v0.5), the bumper is within BumpRangeStuds (6), the target holds no catch or rescue lock (v0.5) and is outside its own safe zone (its plot plus BumpSafeRadiusStuds 15 around both of its doors); the bumper is off BumpCooldownSeconds (8, v0.5, was 12) and has not shoved this target in the last BumpSameTargetSeconds (20, v0.5, was 60); the bumper holds no catch or rescue lock (N85); nobody has shoved the target in the last ShoveTargetImmuneSeconds (4, S45), kept in the server's shove table. Every valid shove pushes the target (v0.5). The knock-loose roll below runs only when the target is carrying, not BumpImmune and at least BumpGraceSeconds (3) into the carry. BumpEnabled false in Config turns the remote off and hides the prompt.
- Then roll BumpChance (0.5). Success: the cat drops at the carrier's feet as a stray with `Dropped` true, its catId, variant, charm and rescued flag kept, and scurries 6 to 10 studs. The server records `droppedBy` (the bumper) and `dropOwner` (the old carrier) in its own table (S25). For DropOwnerPrioritySeconds (8) only the old carrier can start a catch on it; after that anyone can, except the bumper, who can never catch a stray they knocked loose. A Dropped stray never despawns or leaves its area and stays until caught (S26); after a missed catch it sprints like any stray once the owner window is over (N86, section 10), and tries are unlimited for everyone (v0.5). It also survives any night wave that starts within DroppedMinStaySeconds (120) of the drop (S32), so a bump timed just before nightfall cannot delete the cat before the owner window is used. A bump can delay a kid's Legendary but never lose it outright. Whoever catches a dropped stray is BumpImmune for that carry. Fail: both players get "It held on tight!" and the carrier is BumpImmune for 3 s.
- Grace, immunity, cooldowns and drop claims live in server tables; the character and stray attributes are display only (N29). The 6-stud range check uses client-owned character positions, so it only bounds honest play; the cooldowns are what limit a teleporting exploiter, which is accepted.
- The bumper never receives the cat. Nothing is taken from a cafe, only from arms on the way home.
- v0.5: Shove is a button on mobile and a key on desktop, shown only inside catching areas and aimed at the nearest other player within 6 studs (UI thread's choice of key and look); the server validates regardless.

## 11. Income and offline

- `incomePerSecond = sum over working cats of (rating x favoriteMultiplier) x cafeMultiplier x tierMultiplier x phaseMultiplier`.
- `tierMultiplier` from section 5b. v0.3 change: it replaces `prestigeMultiplier` and `renovations`, in the same place in `Economy.incomePerSecond`.
- `phaseMultiplier` is 1.0 by day and NightIncomeMultiplier (0.6) by night (Gavin, Q10). v0.8 (Gavin, round 3 Q6: "lets do earn the same but no customers"): NightIncomeMultiplier becomes 1.0. The cafe still closes at night with no customers and napping cats. Keep the phase split in `Economy.settle` so the number can be tuned again. Day stays the better time to be home because of the tip piles and visitors in sections 12 and 12b. Settling must split the window at phase boundaries: `Economy.settle` integrates the multiplier over `[lastTick, now]` using `Clock.phaseAt`, and ProfileSync sends the current rate, which drops at nightfall.
- `favoriteMultiplier` is 1.5 when the slot's role is the cat's `favoriteRole`.
- `cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + sum of placed decor bonuses` (unchanged).
- Accounting unchanged: `coins` and `lastTick`, settle on every read or spend, the client predicts between syncs.
- Offline unchanged: `offlineGain = dayRateAtLogout x OfflineRate (0.25) x min(now - lastSeen, OfflineCapSeconds 3600)`. `rateAtLogout` stores the day rate.

## 11b. Rewards: the Tip Jar and Index rewards (F47, F48)

Derek asked on 2026-10-27 for the reward screens from his reference games (playtime gifts, index rewards, a daily calendar). The Tip Jar and Index rewards are in the slice; the daily calendar (Daily Treat, common-features 11) and the spin wheel come later (v0.10: the Daily Treat's prizes are in section 11e; the wheel shipped as F49). Every prize is free and paid by the server, and nothing can be bought with Robux to skip a timer or a milestone (monetization-policy). Claiming is always a button press, so a milestone reached mid-chase never interrupts anything. Gavin can still change the prizes (round 3 Q16 and Q18).

Name (Derek, 2026-10-27 14:34: "switch book to index"): the collection screen is the Index, as in the simulator games in Derek's references, and players never see the word Book. The F48 names follow before save version 5 ships: `indexRewards`, `ClaimIndexReward`, `Catalog.indexMilestones` and `Catalog.indexPrizes` (the prize table never shares a name with the claimed map, reviewer S61), decor `source = "index"` and ids `index_<area>`, analytics `index_reward`. Milestone ids are unchanged.

**Tip Jar (playtime gifts, F47).** A jar on the HUD fills as you play. Twelve steps unlock at set minutes of the current session, and each has its own Claim button. Session time is server time since the profile loaded: `sessionStartedAt = workspace:GetServerTimeNow()` when the profile loads. The claimed steps live in server memory only, so leaving the game resets the jar. Rejoining every 10 minutes to farm the first three steps about breaks even on coins (reviewer N112: roughly 990 s of day rate and 22 Kibble over two hours, against 780 s for staying) and misses the Tuna, Salmon, Moonlit Sardines and Caviar, so staying pays more; Roblox's 20 minute idle kick limits idle play.

`Catalog.tipJar`, one row per step in order:

| step | minutes | prize |
|---|---|---|
| 1 | 2 | coins: 30 s of day rate, at least 50 |
| 2 | 5 | 2 Kibble |
| 3 | 10 | coins: 60 s of day rate, at least 100 |
| 4 | 15 | 1 Tuna |
| 5 | 20 | coins: 90 s of day rate, at least 150 |
| 6 | 30 | 2 Tuna |
| 7 | 40 | coins: 120 s of day rate, at least 250 |
| 8 | 50 | 1 Salmon |
| 9 | 60 | v0.10: coins: 600 s of day rate, at least 1,000, plus 10 golden fish and 1 spin (was 180 s, at least 400) |
| 10 | 75 | 1 Moonlit Sardines |
| 11 | 90 | coins: 300 s of day rate, at least 600 |
| 12 | 120 | v0.10: 1 Caviar, 1 Classic Crate, 25 golden fish, 2 spins and a Tip Potion (was 1 Caviar, then 5 fish and a spin in v0.7) |

Row shape: `{ step, minutes, kind = "coins" | "lure", seconds?, minCoins?, lureId?, count? }`. A coins row pays `max(minCoins, floor(dayRate x seconds))`, where `dayRate` is the player's day income per second at claim time (the rich tip uses the same shape), so a bigger cafe gets bigger gifts. Foods go into `lures` like a shop food; the dealer's Moonlit Sardines and Caviar are fine here because they are free. With the Spin Wheel (F49, section 11c), steps 11 and 12 also bank one spin each.

v0.10 (round 4 Q10: "add a pretty good reward also earlier on like 1 hour so people are inticed to stay on and 2h really good so the regulars will play 2h a day"): step 9 at 60 minutes becomes a pretty good gift and step 12 at 120 minutes a really good one, as in the table. Step 11 keeps its banked spin. Rows move to the prize shape of the Index (below) plus potions, so one step can pay several things: `{ step, minutes, prize = { coins?, coinSeconds?, lures? = { [lureId] = n }, fish?, spins?, crates? = { [crateId] = n }, potions? = { [potionId] = n } } }`, with `coins` the minimum and `coinSeconds` the day rate seconds as before; `kind`, `lureId`, `count` and TipJarStep12Fish go. Until F53 ships the crate pays 60 golden fish instead, and until F64 ships the potion is left out. The jar still resets when you leave, so step 12 needs two hours in one session. Roblox's idle kick keeps it to players who are playing.

- `ClaimTipJar(step)`: profile loaded, `step` an integer from 1 to 12, not claimed this session, `GetServerTimeNow() - sessionStartedAt >= minutes x 60`; 1 per second. Pays, marks the step claimed, fires `TipJarState` and ProfileSync. Coins count toward `lifetimeCoins`.
- `TipJarState` (server to client): `{ sessionStartedAt, claimed }`, where `claimed` is a list of 12 booleans in step order (a dense array, because a sparse table loses entries over a remote; engineer #206, UI N116), sent when the profile loads and after every claim. The UI works out each countdown from `sessionStartedAt`, `Catalog.tipJar` and `GetServerTimeNow()`, and estimates a coin prize from the synced day rate; the server's figure at claim time is final.
- `stats.tipJarClaims` counts claims. Analytics: custom event `tip_jar` (step) and economy source `tip_jar`.

**Index rewards (F48).** v0.7 (F54, decided: Derek okayed [golden-fish.md](golden-fish.md) on 2026-10-27 at 19:27): Derek asked for rewards worth chasing and no decor handed out directly, so golden-fish.md sections 5 and 5b replace the table below and are the contract: a normal track (`cats3`, `cats6`, `cats10`) and a separate gold track (`gold1`, `gold2`, `gold4`, `gold6`, `gold8`, `gold10`) per area plus the all-areas All Cats track (area id `all`, `total5` to `total50`), paying coins scaled to the day rate, food, golden fish, banked spins, Cafe Crates and small permanent tip bonuses. The prize shape is `{ coins?, coinSeconds?, lures? = { [lureId] = n }, fish?, spins?, crates? = { [crateId] = n }, bonus?, tag? }` and milestone rows are `{ id, track, needs }`. The Decor Index pages (`decor_alley` up to `decor_sewer` and `decor_classic`, milestones `decor5` and `decor10`) claim through the same remote. The F48 table below stays only as the record of what earlier claims paid: those prizes are not paid again, and an F48 claim of `cats6`, `cats10` or `gold10` gets its permanent bonus on the next load. Each area page in the Index has a reward bar with four milestones. Progress is counted from `collection` (distinct catIds whose `area` is that area) and, for the gold milestone, `goldCollection`. The client already has both, so it computes progress itself.

v0.10 (round 4 Q12: "Thats good do different permanent bonuses and big reward bonuses at milestones depending on track also"): each track has its own kind of permanent bonus, in [golden-fish.md](golden-fish.md) sections 5 and 5b: the normal area track keeps tips forever (`bonus`), the gold track gives gold luck forever (`goldLuck`, a lift to every gold roll) and the All Cats track makes bait faster forever (`baitSpeed`, a cut to every bait wait). The milestones that finish a track (`cats10`, `gold10`, `total25` and `total50`) get bigger prizes. The prize shape gains `goldLuck?` and `baitSpeed?` as fractions next to `bonus?`.

| milestone id | needs | Alleyway | Park | Neighbourhood | Woods | Sewer |
|---|---|---|---|---|---|---|
| `cats3` | 3 of the area's 10 cats | 300 coins | 1,000 coins | 3,000 coins | 10,000 coins | 30,000 coins |
| `cats6` | 6 of 10 | 2 Tuna | 2 Salmon | 2 Caviar | 2 Moon Milk | 2 Star Treat |
| `cats10` | all 10 | Salmon and the area's Index decor | Caviar and decor | Moon Milk and decor | Star Treat and decor | 2 Star Treat and decor |
| `gold10` | all 10 as gold cats | the area's Index decor in gold | same | same | same | same |

- `ClaimIndexReward(areaId, milestoneId)`: profile loaded, `areaId` a string in `Catalog.areas`, `milestoneId` one of `cats3`, `cats6`, `cats10`, `gold10`, the count met, not already in `indexRewards[areaId]`; 1 per second. Pays coins and foods, adds the decor to `decorOwned` and places it (like BuyDecor), marks the milestone and sends ProfileSync with `indexRewards`.
- `indexRewards` is saved in the profile (section 14) and F48 raises the save version to 5 (reviewer S60): an older server rebuilds a profile from the fields it knows and would drop `indexRewards`, letting a player who hops servers during a rollout claim every milestone again, while the newer-save guard (S31) stops a version 5 save from loading on an old server at all. Saves made before F48 migrate with it empty and can claim every milestone they already passed.
- The Index tab and the HUD Index button show a red badge while any milestone is claimable (UI).
- Analytics: custom event `index_reward` (area, milestone) and economy source `index_reward`.
- Later (Alpha, common-features 4): rarity sets across all areas (all Commons, all Rares and so on) and the all-50 reward.

## 11c. The Spin Wheel station (F49)

Derek, 2026-10-27 14:36: "things like spins could be an area you walk up to". The wheel is a station in the street plaza ([areas-and-stations.md](areas-and-stations.md) Part B), not a HUD button. Spins are free and never sold: no Robux button, no pass and no product gives spins (monetization-policy), and every slice shows its chance. A spin never gives a cat (round 3 Q17, kept in round 4 Q11: "sounds good for now"). v0.10 (round 4 Q11: "have the odds be a button you can click for the spin so you can see whats likely to hit"): the Spin window gets an Odds button that opens a list of the six slices, likeliest first, each with its prize picture and its chance in percent, the same numbers as on the wheel (UI).

`Catalog.spinWheel`, six slices in wheel order, clockwise from slice 1, which sits under the pointer when the wheel is at rest:

| slice | prize | weight (chance) |
|---|---|---|
| 1 | coins: 120 s of day rate, at least 200 | 30 |
| 2 | 3 Tuna | 22 |
| 3 | coins: 600 s of day rate, at least 1,000 | 18 |
| 4 | 2 Salmon | 15 |
| 5 | 2 Moonlit Sardines | 10 |
| 6 | 1 Caviar | 5 |

v0.7 (F54, decided 19:27, [golden-fish.md](golden-fish.md) section 6): slice 5 becomes 4 golden fish (`{ kind = "fish", count = 4 }`, weight 10) and slice 6 one crate of the highest zone the player has unlocked (`{ kind = "crate", crate = "highest" }`, weight 5). Slices 1 to 4 are unchanged, and the Moonlit Sardines and Caviar stay in the Tip Jar and with the dealer.

Row shape: `{ slice, kind = "coins" | "lure" | "fish" | "crate", seconds?, minCoins?, lureId?, count?, crate?, weight }`, the Tip Jar's shape plus `weight` (and from v0.7 the fish and crate kinds). The weights add up to 100, so each is the slice's chance in percent, shown on the slice and in the window. Coins pay `max(minCoins, floor(dayRate x seconds))` and count toward `lifetimeCoins`; foods go into `lures`.

Spins:
- One free spin a day: due when `floor(os.time() / 86400)` (the UTC day) is above `spin.lastFreeDay`. Missed days do not stack.
- Banked spins in `spin.banked`, up to SpinBankCap (20): one each from Tip Jar steps 11 and 12 (v0.10: one from step 9, one from step 11 and two from step 12), and later the Daily Treat (section 11e). A claim that would pass the cap still pays the step's other prize and drops the extra spin, and the Tip Jar row says "Spins full".
- A spin uses the free spin first, then a banked one.

- `SpinWheel()`: profile loaded; the character within SpinStationRange (14) studs of a station tagged `SpinWheel`; a free spin due or `spin.banked` of 1 or more; at least SpinCooldownSeconds (4, the spin animation) since the caller's last spin; 1 call per second, since a refusal also answers with a remote (N125). The server picks the slice with its own `Random`, weighted by `weight`, pays at once (so leaving mid-animation keeps the prize), updates `spin`, adds to `stats.spins`, fires `SpinResult(slice, amount)` to the caller and ProfileSync with `spin`, and sets the station's `LastSlice` and then `LastSpinAt`, so every client turns the world wheel for show and stops it on the won slice (S64). A refused spin fires `SpinResult(0, 0)` and the window says why ("Next free spin in 5h 12m").
- No Robux item may add a spin or speed up a spin source (no product that resets the free spin, no pass that shortens the Tip Jar) (N126).
- On load a version 6 `spin` is sanitised: `banked` clamped to 0 to SpinBankCap and `lastFreeDay` to 0 to today, so a bad value cannot bank spins or block the free one (N128).
- The UI works out when the next free spin is due from `spin.lastFreeDay` and `GetServerTimeNow()`; the server's check at spin time is final.
- `spin` is saved and F49 raises the save version to 6, for the same reason as S60: an older server would drop `spin` during a rollout, giving a second free spin and losing banked ones. Migration 5 to 6 sets `spin = { lastFreeDay = 0, banked = 0 }`.
- Analytics: custom event `spin` (slice, free or banked) and economy source `spin_wheel`.

## 11d. Codes and the Codes Cat (F65)

Derek, 2026-10-27 19:33: "After all the currency is good and sorted add codes can go up to the codes cat in the cafe area and it will pop up a box to enter codes we will start with just playtest(make codes non case sensitive) giving some decent starting items for now that would be good to help with testing things like spins and crates and potions if in the game yet". This replaces the round 3 Q19 plan of a code box in Settings with prizes in Mail.

- The Codes Cat is a station in the street plaza with the Spin Wheel and the Golden Fish Market ([areas-and-stations.md](areas-and-stations.md) B2): a cat in a postman's cap behind a little desk with a "Codes" sign, model `CatCafe_Street_CodesCat`, tag `CodesCat`. v0.10 (Derek, 2026-10-27 20:10: "make code cat have a stand and a clear area circle to walk into to open code entering menu"): the Codes Cat sits up on a stand, a little booth with the "Codes" sign, and in front of it a clearly marked circle lies on the ground (`CodesCircle`, part of the model: a flat glowing ring with a ticket icon in the middle, radius CodesCircleRadius 4 studs, CanCollide off). Walking into the circle opens the code box, with no key press and no prompt; walking out closes it and clears the field. The client checks its own character's flat distance to the circle's centre: it opens at CodesCircleRadius or less and closes past CodesCircleRadius + 1, so standing on the edge never flickers. The box has one text field, a Redeem button and a line for the answer. The server's check stays the range check below (CodesCatRange 12 from the station). The plaza is in the safe zone, so nobody gets shoved while typing.
- Codes are not case sensitive: the server trims spaces and lowercases the text before it looks it up, so "PlayTest", "playtest" and " PLAYTEST " are the same code. Codes are letters and digits only, 1 to CodeMaxLength (20) characters.
- `Catalog.codes`, keyed by the lowercased code: `{ id, prize, active, endsAt? }`. The prize uses the Index prize shape (section 11b) plus potions: `{ coins?, coinSeconds?, lures? = { [lureId] = n }, fish?, spins?, crates? = { [crateId] = n }, potions? = { [potionId] = n } }`. `endsAt` is an optional `os.time()`; an inactive or ended code answers "That code has expired".
- Each player can redeem each code once: `codesRedeemed` (map code id to the `os.time()` it was redeemed) is saved in the profile (section 14). Spins over the bank cap are dropped with "Spins full", as for Index prizes, and the rest still pays.
- Launch code, for the friends alpha:

| code | prize |
|---|---|
| `playtest` | 5,000 coins, 300 golden fish, 10 spins, 3 Classic Crates, 1 Alley Crate, 1 Golden Classic Crate, 3 Tuna, 2 Salmon, 1 Caviar and one of each potion if F64 has shipped |
| `launch` | v0.10 (round 4 Q13: "launch for release"): 600 s of day rate (at least 1,000 coins), 25 golden fish, 2 spins and 3 Tuna; added with `active = false` and switched on the day the experience goes public (it stays private for the friends alpha) |
| `group` | v0.10 (round 4 Q13: "group! can be a code that gives really good rewards but requires people to join the community group"): 1,800 s of day rate (at least 2,500 coins), 100 golden fish, 5 spins, 1 Classic Crate, 2 Caviar and a Tip Potion, for members of Derek's Roblox group only (`requiresGroup`); inactive until the game belongs to the group |

  If F64 is not in the game when F65 ships, `playtest` leaves the potions out and F64 adds a second code, `playtest2`, with two of each potion, so testers still get them. Both codes get an `endsAt` or are set inactive before the experience goes public, because they hand out far more than normal play.
- `RedeemCode(text)`: profile loaded, the caller within CodesCatRange of a `CodesCat` station, `text` a string of at most 40 bytes, then trimmed, lowercased and checked against `^%w+$` and CodeMaxLength. A known, active code not in `codesRedeemed` pays its prize at once, saves the code id and answers `CodeResult(true, "Code redeemed!", prize)`. A wrong code answers `CodeResult(false, "That code doesn't exist", nil)`, an old one "You already used that code". 1 call per 2 seconds, and after CodeWrongLimit (5) wrong codes in a minute the box locks for CodeLockSeconds (60) with "Too many tries, wait a minute", so nobody can guess codes by brute force. The typed text is never shown to other players and never saved (only the code id is), so it needs no text filter.
- v0.10 `requiresGroup` (optional on a code row): `RedeemCode` checks `player:IsInGroup(Config.GroupId)` on the server (in a pcall, cached per player for 60 s). A player who is not a member gets `CodeResult(false, "Join the Cat Cafe group to use this code", nil)` and the code is not marked used, so they can come back after joining. While `Config.GroupId` is 0 (the game is still on Derek's own account) every `requiresGroup` code answers "That code has expired". Codes are letters and digits, so the answer's "group!" is the code `group` (Set 4 checks).
- Later codes (round 4 Q13: "then we will do ones for milestones hit of concurrent players and likes"): when the game first reaches a concurrent player or like milestone, the growth thread adds a code named for it (for example `likes1000`), with an `endsAt` and a prize that grows with the milestone. Rows can be added without new code, because the catalog is data.
- Analytics: custom event `code_redeemed` (code id) and economy source `code` for coins and golden fish.
- Nothing about codes is sold or tied to Robux.

## 11e. Daily Treat (F70, launch)

Round 4 Q9: "Thats good I think the day 2/4 rewards should be pretty good also so people come back and 7 be really good like a random legendary or mythical+ cat crate or cosmetic crate up to you". The seven-stamp card from common-features 11, with the prizes moved into the Index prize shape plus potions. Days 2 and 4 are pretty good and day 7 is really good. Of the two day 7 ideas we picked the cosmetic crate, and added a Star Treat: the night dealer's best bait brings a Legendary 45% or Mythical 15% of the time, so day 7 gives a real shot at a top cat while cats still come only from catching, rescue and bait (round 4 Q11 kept that rule).

`Catalog.dailyTreat`, one row per day:

| day | prize |
|---|---|
| 1 | coins: 300 s of day rate, at least 300 |
| 2 | 2 Salmon, 15 golden fish and 1 spin |
| 3 | coins: 600 s of day rate, at least 600 |
| 4 | 1 Caviar, 1 Classic Crate and 1 spin |
| 5 | coins: 900 s of day rate, at least 1,000 |
| 6 | 3 Tuna and a Lucky Potion |
| 7 | 1 Golden Classic Crate, 1 Star Treat, 50 golden fish and 3 spins |

- One stamp per UTC day you play: a stamp is due when `floor(os.time() / 86400)` is above `dailyTreat.lastDay`. A missed day loses nothing; the card waits for the next stamp. After day 7 the next stamp starts a fresh card at day 1.
- The Daily Treat window opens by itself once on the first join of a day with a stamp due, and from a HUD button with a red dot while one is due. Claiming is a button press.
- `ClaimDailyTreat()`: profile loaded, a stamp due; 1 per second. Pays day `dailyTreat.stamp + 1` (or day 1 after a full card), sets `lastDay` to today and `stamp` to the day paid and sends ProfileSync with `dailyTreat`. Spins over SpinBankCap are dropped with "Spins full", until F53 a crate pays 60 golden fish (200 for the golden one) and until F64 the potion is left out.
- `dailyTreat = { stamp = 0 to 7, lastDay = 0 }` is saved (section 14) and takes the next save version when F70 ships. On load `stamp` is clamped to 0 to 7 and `lastDay` to 0 to today.
- Nothing here is sold, sped up or restored for Robux, and there is no streak to lose (monetization-policy, no dark patterns).
- Analytics: custom event `daily_treat` (day) and economy source `daily_treat`.

## 12. Customers and rich customers

- Customers are client-simulated as before. By day: a customer every CustomerSpawnSeconds (6) while a seat is free. v0.5 (Gavin, round 2 Q8: "Cats earn 60% at night because they aren't working and 100% when Cafe is running"): the cafe closes at night. No customers come and the door sign flips to Closed with a moon; working cats curl up and nap at their stations while the 60% keeps coming in. The v0.3 night owls and CustomerSpawnSecondsNight are gone.
- Rich customer (Gavin, Q10), server-driven because it pays: by day, every RichCheckSeconds (60), each occupied plot with income above 0 and at least one table (tables level 1 or more, because the rich customer, coin pile and RichTipAnchor sit on table 1; N81) rolls RichChance (0.15). On a hit the server records `{ ownerUserId, serial, amount = max(50, floor(dayRate x RichTipSeconds 45)), expiresAt = now + RichTipStaySeconds (90) }` in its own table keyed by plot, and mirrors amount and expiry to the plot attributes `RichTipAmount` and `RichTipExpiresAt` for display only. Each client shows a rich customer (top hat, gold coin pile on a table). `ClaimRichTip()` by the owner within 12 studs of the plot's tip anchor before expiry adds the amount. If unclaimed, the server adds it when it expires, so it is never lost; claiming is just sooner and more fun. One rich tip at a time per plot. Owner safety (S29): the expiry credit checks the owner UserId and serial still match; pay exactly once by zeroing the record before crediting on both the claim and the expiry path; if the owner leaves before expiry, the save-on-leave path credits it; releasing a plot clears the record and both attributes.
- v0.8 tip piles (Gavin, round 3 Q6: "During day customers that leave tips (base it on money per min for scaling) can leave a good chunk of your revenue"): by day, every TipPileSeconds (30) each occupied plot with income above 0 and at least one table adds a tip pile worth `max(5, floor(dayRate x TipPileRateSeconds))` (6), so a player who keeps collecting earns about 20% more by day. Piles wait on the tables, up to TipPilesMax (6), and no new pile comes while six wait, so a player who stays out in the areas all day misses some. The server keeps the piles in its own table keyed by plot and mirrors the count and total to the plot attributes `TipPiles` and `TipPilesAmount`, display only. `CollectTips()` by the owner standing inside their own plot pays every waiting pile at once; the client fires it when the owner walks within 8 studs of a pile or presses Collect on the till. Piles still waiting are paid when the owner leaves (the save-on-leave path, as for the rich tip), and night adds no piles. The client puts each pile on a table a customer just left, so the coins match what players see. Coins count toward `lifetimeCoins`.
- v0.8 rich visitors (Gavin, round 3 Q6: "rich visitors that give bonus cash a good chunk of it"): RichTipSeconds rises from 45 to 120 and RichChance falls from 0.15 to 0.10, so a rich visitor pays 2 minutes of income and adds about 20% to the day where it added about 11%.
- Pace check (v0.8): night at 100%, tip piles and bigger rich visitors give about 1.4 times the coins per hour of v0.7 (about 1.4 of the day rate by day and 1.0 by night, against about 1.1 and 0.6). QA's loop script re-times Tier 2 (target 10 to 20 minutes); if it comes in under 10, the tier costs go up rather than these rewards down.

## 12b. Visitors: the Cat Collector and the Mystery Visitor (v0.8)

Gavin, round 3 Q6: "rarer customers like cat collector might offer items for a certain one  of your cats that are not equipped or locked in return for rare items like cosmetic crates (the rarer the cat the better the item and gold rarities even better have some sort of value calculated based on rarity and gold version calculation that can roll better rewards he might offer the better it is) ... and mysterious visitors that might give potions or other things". Both visitors are server-driven because they pay, and both come only by day to an occupied plot with at least one table, like the rich visitor, one of each kind at a time per plot. Neither is ever sold, sped up or called with Robux.

**Cat Collector (F63).** Every CollectorCheckSeconds (120) by day, each such plot whose owner has at least one resting, unlocked cat rolls CollectorChance (0.12), about one visit every 35 minutes of play. On a hit the server picks the cat he wants: a catId chosen evenly among the distinct catIds the owner has as resting, unlocked cats (so a pile of Tabbies does not crowd out the rest), then that catId's instance with the lowest rating. Then it works out his offer:

- value = CollectorValue by rarity (Common 1, Rare 3, Epic 8, Legendary 20, Mythical 50), times CollectorGoldMultiplier (3) for a gold cat, times a roll from 0.8 to 1.5, so the same cat can get a better offer another time.
- The offer is the best row of `Catalog.collectorOffers` whose `value` is at most that number. The zone crate is the crate of the cat's own area and the golden crate its golden version (golden-fish.md section 4).

| value | offer |
|---|---|
| 1 | 5 golden fish |
| 2 | 3 Tuna and 1 spin |
| 4 | 15 golden fish |
| 7 | 1 zone crate |
| 12 | 1 zone crate and 20 golden fish |
| 20 | 2 zone crates |
| 35 | 1 golden crate |
| 60 | 1 golden crate and 50 golden fish |
| 120 | 2 golden crates and 100 golden fish |

So a Common always gets 5 fish, a Rare 3 Tuna and a spin or 15 fish, an Epic a crate or more, a Legendary a crate and fish or two crates, a Mythical a golden crate, a gold Legendary a golden crate and maybe 50 fish and a gold Mythical two golden crates and 100 fish. Row shape: `{ value, fish?, lures? = { [lureId] = n }, spins?, crates? = { zone = n, golden = n } }`.

He waits at the counter for CollectorStaySeconds (180). The HUD says "The Cat Collector is at your cafe! He wants your Pirate Cat." and his card opens when the owner walks within 12 studs: the cat's card, the offer's pictures and amounts, "Your Index keeps this cat" and the buttons Trade and No thanks. `AnswerCollector(accept)`: the visit is live and is the caller's, the caller is within 12 studs, and on accept the cat is still owned, resting and unlocked (otherwise a toast says why and the visit stays). Accept removes the instance (`collection` and `goldCollection` keep it, so the Index never goes back), pays the offer (crates into `crates`, spins into `spin.banked` with the usual cap), adds to `stats.collectorTrades` and he leaves happy. No thanks, the timeout, locking the cat or putting it to work ends the visit and nothing is lost. A cat being carried is not in the room yet, so he never asks for one. His crate offers need F53; until then those rows pay golden fish at 60 per crate and 200 per golden crate.

**Mystery Visitor and potions (F64).** Every MysteryCheckSeconds (120) by day, each such plot rolls MysteryChance (0.08). A hooded visitor sits at a table for MysteryStaySeconds (120) and leaves a wrapped gift on it. v0.10.1: the gift goes on the table as the visitor sits down, so the server sets the plot attributes `MysteryVisitorUntil` (now + MysteryStaySeconds) and `MysteryGiftAt` (now) together, and each client builds the visitor and the gift from them, as it does the rich customer (section 13). Dusk or a plot release sends the visitor home early (`MysteryVisitorUntil` back to 0); the gift stays until it is opened or its keep time ends. The gift is rolled when it appears, and the owner opens it with a hold E prompt within 12 studs (`OpenMysteryGift()`); an unopened gift waits up to MysteryGiftKeepSeconds (600) and is opened for the owner when they leave. The gift's card shows what it can hold before it is opened:

| gift | chance |
|---|---|
| a potion, one of the four below at even odds | 60% |
| 2 Salmon | 20% |
| 10 golden fish | 10% |
| 1 spin | 10% |

Potions go into `potions` (map potionId to count) and are drunk from the bag with `UsePotion(potionId)`. A potion's timer runs in real time from when it is drunk, saved as `buffs[potionId] = endsAt` in `os.time()`, and keeps running offline. Drinking another of the same kind adds its time, up to PotionMaxMinutes (60).

| id | name | lasts | effect |
|---|---|---|---|
| tip_potion | Tip Potion | 10 min | +25% tips: a multiplier on `incomePerSecond`, the tip piles and rich visitors; `Economy.settle` splits the window where the buff ends, like a phase change |
| lucky_potion | Lucky Potion | 10 min | food set in the bowl while it runs rolls gold at double the chance (10%) |
| swift_potion | Swift Potion | 5 min | +4 walk and carry speed |
| steady_potion | Steady Paw Potion | 10 min | the circles use the windows and jitter of the next net level (a Master net stays Master) |

Potions are earn-only. Selling one for Robux would change income or catch odds, so it needs the monetization review first.

## 13. Instance attributes (world data, no remote needed)

Stray cat model (tag `Stray`): `StrayId`, `CatId`, `CatName`, `Rarity`, `Area`, `LockedBy` (UserId or 0), `SpawnedAt`, `Charm`, `Stars`, `Gold` (bool, never set on a stuck cat before its rescue), `Dropped` (bool), `DropOwner` (the old carrier's UserId), `DropOwnerUntil` (display of the old carrier's priority window), `FleeingUntil` (v0.5, server time the sprint and rest end), `HissAt` (server time of the latest Miss, for the hiss everyone nearby sees), `Returning` (v0.10, a dropped cat walking back to where it was caught, section 10c). All display only; the drop records live in the server's table (S25). v0.3 change: `ReservedFor` is gone (no lured strays in areas).

Rescue trap (tag `RescueSpot`): `RescueSpotId`, `Area`, `TrapType` (`trash_bin`, `garbage_bag`, `tree`, `trashcan`, ...), `Occupied`, `LockedBy`, `RetryAt`. The stuck cat model shows `CatId`, `CatName`, `Rarity` (shown before the attempt so players can choose) but not `Gold`.

Carrier character: `CarryingCatId`, `CarryStartedAt`, `BumpImmune`. Display only; the carry grace and immunity checks read the server's carry table. v0.8: `RushUntil` (server time the Catch Rush ends, for the speed lines) and `StartledUntil` (the slow after a miss). A Dropped stray's `DropOwner` and `DropOwnerUntil` go away with the owner window; its prompt reads Pick up.

Shoved character (v0.5, asked by the vfx-animator for the shove puff and dizzy stars): `ShovedAt` (server time of the latest shove that landed on this player) and `ShovedBy` (the shover's UserId). Display only; the cooldowns and ShoveTargetImmuneSeconds read the server's shove table.

Potion drinker (v0.10.1, F64, asked by the vfx-animator for a glow everyone nearby sees, since ProfileSync `buffs` reach only the owner): `ActivePotions`, the ids of the potions running now, comma-separated, oldest drink first and "" when none. The server sets it on `UsePotion` (a kind already running moves to the end, as the newest), when a buff's `endsAt` passes (a check once a second is enough) and on every CharacterAdded, so a respawn or a rejoin with offline time left shows it again. The drink order is not saved, so on a rejoin the ids are ordered by `endsAt`, soonest first. Each client shows one glow per player, for the last id. Display only; every effect reads the profile `buffs`.

Mystery Visitor and gift (v0.10.1, F64, asked by the vfx-animator for the arrive and leave puffs and the gift sparkle): the client that builds them tags the hooded visitor's model `MysteryVisitor` and the wrapped gift's model `MysteryGift`, both under their plot, while `MysteryVisitorUntil` and `MysteryGiftAt` say they are there. The tags are on each client's own models, which is all the effects need. The ribbon pop plays on the owner's `MysteryGiftResult`.

Clock folder in ReplicatedStorage: `Phase`, `PhaseEndsAt`. v0.9: `AreasOpen` (bool, false from dusk to sunrise) for the fences, the travel buttons and the back door signs.

Stray naps (engineer #290, Derek's ask in the animation thread): strays carry `Napping` (bool) and `StretchAt` (server time of the next stretch) for the nap and stretch animation. Display only.

Attributes are for display. Server decisions (locks, deadlines, bump grace and claims, rich tips, the bait roll, the hidden gold roll) read the server's own tables.

Dealer cart (tag `DealerCart`): `Open` (bool).

Spin Wheel station (tag `SpinWheel`, F49): `LastSlice` (1 to 6, the slice the latest spinner won) and `LastSpinAt` (server time of the latest spin by anyone). The server sets `LastSlice` just before `LastSpinAt`, so every client's world wheel stops on the slice that was really won (reviewer S64). Show only.

Index Board (tag `IndexBoard`, F50): `Area` (the area id). The board is drawn on each client from that client's own `collection` and `goldCollection`; the prompt opens the Index on that area's page.

Plot model (tag `Plot`): `OwnerUserId`, `PlotIndex`, `Tier`, `RichTipAmount`, `RichTipExpiresAt`, `BaitReadyAt` (0 when empty). v0.8 adds `TipPiles` and `TipPilesAmount` (section 12), `CollectorUntil` and `CollectorCatId` (the Cat Collector's visit, 0 and "" when none) and `MysteryGiftAt` (0 when no gift waits); v0.10.1 adds `MysteryVisitorUntil` (server time the hooded visitor leaves, 0 when none, section 12b); all display only. Children: `Spots/<slotId>` station parts with attribute `SpotType` (the role), `DecorAnchors/<decorId>`, `BaitBowl`, `RichTipAnchor`, `Door`, `CustomerWaypoints`, `Expansions/<n>`.

Working cat model (under `Plot/Cats`): `Uid`, `CatId`, `OwnerUserId`, `Role`, `DisplayName` (the filtered name or the catalog name), `Gold`, `Napping` (bool, naps any cat), and the CollectionService tag `WorkingCat` while it works a station. v0.5 night nap (F44): each client naps every `WorkingCat` while the Clock `Phase` is night, so the server writes nothing at dusk and dawn; income stays the server's 60%.

## 14. Player profile (save data, version 5 from F48, 6 from F49, 7 from F52, 8 from v0.8)

| field | type | default | notes |
|---|---|---|---|
| version | integer | 8 | 7 (F52, design v0.7: adds `goldenFish`, `lifetimeGoldenFish`, `crates`, `crateLuck`, `fishPerks`, `stats.cratesOpened` and `stats.fishEarned`; migration 6 to 7 sets them to 0 or empty); 8 (v0.8, Gavin's round 3: adds `potions`, `buffs`, `bait.readyAt`, the cats' `locked`, `stats.pickups`, `stats.collectorTrades`, `stats.mysteryGifts` and `stats.potionsUsed`, and changes `dealer.bought` to counts per food; migration 7 to 8 sets the new fields to 0 or empty, locks every gold, Legendary and Mythical cat, sets `bait.readyAt = placedAt + 600` on a filling bowl and clears `dealer.bought`). Whichever of these ships first takes 7 and the other 8, for the S60 reason: an older server would drop the new fields. As built: F54 took version 8 (#325), so F65's `codesRedeemed` takes 9, and the remaining v0.8 fields, `dailyTreat` and `introSeen` take the next numbers in the order they ship. Earlier: 3 (2026-10-26, design v0.3); 4 (2026-10-27, the engineer's gold rename: `shiny` becomes `gold`, `shinyCollection` becomes `goldCollection`); 5 (F48: adds `indexRewards` and `stats.tipJarClaims`; migration 4 to 5 sets `indexRewards = {}` and the counter to 0); 6 (F49: adds `spin` and `stats.spins`; migration 5 to 6 sets `spin = { lastFreeDay = 0, banked = 0 }`) |
| coins | integer | 50 | |
| lifetimeCoins | integer | 0 | |
| lastTick, lastSeen | integer | join time | |
| rateAtLogout | number | 0 | day rate |
| tier | integer | 1 | new, section 5b |
| upgradeLevels | map id to level | espresso 1, tables 0, net 0, lure_bowl 0 | `cafe_level` and `park_access` removed |
| decorOwned, decorPlaced | map id to true | empty | |
| lures | map id to count | empty | shop and dealer foods |
| bait | `{ lureId, placedAt, readyAt, catId, variant, charm }` or nil | nil | section 8; v0.8 adds `readyAt` (night bait is ready sooner) |
| dealer | `{ window, bought = { [lureId] = count } }` | `{ window = 0, bought = {} }` | section 8b; `window` is the global dealer window; v0.8 counts per food (was `{ [slot] = true }`) |
| cats | map uid to cat instance | one `tabby` on `barista_1`, charm 50, level 1, method `starter` | section 4 adds `name`, `method`; `variant` can be `gold`; v0.8 adds `locked` |
| collection | map catId to firstCaughtAt | tabby | drives the Index and "different cats" |
| goldCollection | map catId to firstCaughtAt | empty | new, the gold page |
| indexRewards | map area id to `{ [milestoneId] = true }` | empty | F48, section 11b; a missing field loads as empty |
| goldenFish, lifetimeGoldenFish | integer | 0 | v0.7, F52 ([golden-fish.md](golden-fish.md) sections 1 and 2) |
| crates | map crateId to count | empty | v0.7, F53: unopened crates from the Index, the wheel and the Cat Collector |
| crateLuck | map crate pool (the zone or `classic`) to 0..19 | empty | v0.7, F53: opens since the last Epic or better, for the lucky twentieth |
| fishPerks | map perkId to level | empty | v0.7, F53: the Golden Fish Market perks |
| potions | map potionId to count | empty | v0.8, section 12b |
| codesRedeemed | map code id to `os.time()` | empty | F65, section 11d; takes the next save version when it ships |
| introSeen | boolean | false | F72 ([intro-cutscene.md](intro-cutscene.md)): set by the first non-replay `IntroDone`; every save starts false, existing ones included, so the friends testing see the intro once. While it is false the player spawns just inside their own cafe's back door, facing it (plot-local about x -8, z 11). Takes the next save version |
| dailyTreat | `{ stamp, lastDay }` | `{ stamp = 0, lastDay = 0 }` | v0.10, F70, section 11e; takes the next save version when it ships |
| buffs | map potionId to endsAt (`os.time()`) | empty | v0.8, section 12b; expired entries are dropped on load |
| spin | `{ lastFreeDay, banked }` | `{ lastFreeDay = 0, banked = 0 }` | F49, section 11c; `lastFreeDay` is the UTC day number of the last free spin, `banked` 0 to SpinBankCap |
| stats | catsCaught, catsSold, grabsAttempted, grabsSucceeded, perfectCircles, circlesTotal, rescues, rescueAttempts, baitsTamed, baitsLetGo, bumpsGiven, bumpsLanded, bumpsTaken, luresUsed, playtimeSeconds, sessions, tipJarClaims (F47), spins (F49), cratesOpened and fishEarned (v0.7), pickups, collectorTrades, mysteryGifts and potionsUsed (v0.8) | 0 | new counters added |
| tutorialStep | 0 to 5 | 0 | 0 new, 1 saw the alley, 2 caught, 3 assigned a role, 4 bought a table, 5 set bait (done) |
| settings | music, sfx, musicVolume, sfxVolume, screenShake, lowPerformance, showOtherCats, markers, tutorialButton | music, sfx, screenShake, showOtherCats and markers true; volumes 1; lowPerformance false | engineer #215: volumes are 0 to 1 rounded to 0.01; `markers` shows the place icons; a missing key loads as its default, so no version bump; F72 adds `tutorialButton` (boolean, default true) for the HUD's Tutorial tile |
| telemetry | `{ onboardingStep, achieved = { [step] = true } }` | `{ onboardingStep = 0, achieved = {} }` | new; the funnel logs each onboarding step once and only in order, because Roblox marks every earlier step complete when a later one is logged, so a rank up before bait would otherwise fake the bait steps (growth, analytics-plan) |
| flags | `{ autoPress }` | `{ autoPress = false }` | new; set by the circle ring buffer (section 10), review only |

Removed: `equippedLure` (UseLure takes the food id), `renovations`.

Migration 2 to 3: `tier = 1`; refund the coins spent on `cafe_level` levels above 1 and on `park_access` so test saves keep their value; drop both from `upgradeLevels`; cap `tables`, `espresso` and `net` at the Tier 1 caps and refund levels above the cap; clear every cat's `spotId`, then run Equip Best once on load to fill `barista_1` and `waiter_1`; set `method = "net"` on caught cats and `"starter"` on the first tabby; drop `equippedLure` and `renovations`. Forward only. The v2 cost tables for `cafe_level` (0, 250, 800, 2500, 8000) and `park_access` (1000) are frozen inside `ProfileSchema` for the refund, because the live Catalog no longer has them (S31).

Newer-save guard (S31): if a saved `version` is above the code's version, do not load and do not save that profile; kick with "The game just updated, please rejoin". This stops an old server from rebuilding a v3 save as v2 and dropping `tier`, `bait`, `dealer` and names. When v3 is published, restart all servers.

## 15. Remotes (`src/shared/Remotes.luau`)

Every client to server call is validated on the server. Default rate limit 10 calls per second per player per remote. Reject silently on a limit and log the UserId.

| name | kind | args | server checks | result |
|---|---|---|---|---|
| GrabBegin | event | strayId | stray exists, area unlocked, LockedBy 0 or self, not sprinting (v0.5), not the caller's StraySelfRetrySeconds after their miss (S44), for a Dropped stray not the bumper and within the old carrier's priority window only the old carrier (v0.8: a Dropped stray refuses GrabBegin and is picked up with PickUpCat), 10 studs, not carrying, GrabCooldownSeconds | locks, fires CatchSchedule (section 10) |
| CatchPress | event | strayId, index | LockedBy self, attempt open, index is the next unjudged circle, not before its start; 10 per second | judges the circle; a Miss or the last circle ends the attempt and fires CatchResult, no roll (v0.4) |
| RescueBegin | event | rescueSpotId | occupied, area unlocked, unlocked or own, past RetryAt (RescueSelfRetrySeconds for the player who just failed), 10 studs, not carrying | locks with a deadline, fires RescueChallenge (section 10b) |
| RescuePress | event | rescueSpotId | LockedBy self, attempt open; 10 per second | scores the press; on success to carry, on out of paws ends; fires RescueResult |
| RescueCancel | event | rescueSpotId | LockedBy self | ends the attempt, sets RetryAt |
| CheckIn | event | none | carrying, 8 studs of own Door | adds instance, CatCaught, first-catch reward |
| DropCat | event | none | carrying; 1 per second; v0.10: refused while `AreasOpen` is false | v0.10 (section 10c): the cat is put down as a Dropped, Returning stray that walks back to its `homePos`; anyone can pick it up on the way; at home it is a normal stray again |
| Bump | event | targetUserId | integer UserId of another player in the server, then section 10c (caller holds no lock, target not shoved by anyone within ShoveTargetImmuneSeconds); 1 per BumpCooldownSeconds | v0.5 Shove: pushes the target; if it is carrying, rolls and drops the cat as a stray on success; Toast both ways |
| PickUpCat | event | strayId | v0.8 (section 10c): stray exists and is Dropped, area unlocked, 10 studs, not carrying, no lock held, GrabCooldownSeconds; first valid call wins | starts the carry, no charm, no rush or burst |
| PlaceCat | event | uid, spotId | owns uid, slot exists in own plot, slot open at the player's tier, slot empty, cat not already working | sets spotId, rate, seated model with outfit |
| UnplaceCat | event | uid | owns uid, working | clears spotId, cat to the cat room |
| EquipBest | event | none | profile loaded; 1 per 2 s | best placement over open slots |
| SellCat | event | uid | owns uid, not the last working cat, v0.8 not locked | removes, adds sellValue |
| LockCat | event | uid, locked | v0.8 (section 4): owns uid, `locked` a boolean; 4 per second | sets `locked`, ProfileSync |
| RenameCat | event | uid, name | owns uid, string, valid UTF-8, 1 to 20 `utf8.len` after trim, no control characters, newlines, `<` or `>`, 1 per 5 s; filter succeeds | saves the raw name, sets DisplayName from a broadcast filter (section 4) |
| RankUp | event | none | tier below 5, cost affordable, distinct cats, rarity requirement; 1 per 2 s | spends, tier + 1, unlocks, Announce, ProfileSync |
| BuyUpgrade | event | upgradeId | in catalog, below maxLevel, tier cap for the next level, affordable | level + 1, spends |
| BuyDecor | event | decorId | in catalog, not owned, requiresTier met, affordable | owned and placed |
| ToggleDecor | event | decorId, placed | owned | sets placed |
| BuyLure | event | lureId | shop food (source shop), affordable | count + 1. No PolicyService gate (section 8 and the monetization notes) |
| UseLure | event | lureId | lure_bowl owned, bowl empty, count above 0, 12 studs of own BaitBowl | consumes, rolls and saves `bait`, sets BaitReadyAt |
| ResolveBait | event | choice (`tame` or `letgo`) | bait exists, ready, owner within 20 studs of own BaitBowl | tame adds the cat; both empty the bowl |
| BuyDealerFood | event | lureId, window | v0.8 (section 8b): night, 12 studs of the cart, a dealer food, `window` is the current window, `bought[lureId]` below its rolled amount, affordable; the amount recomputed from the seed (S42) | count + 1, `bought[lureId]` + 1; sends DealerStock either way |
| ClaimRichTip | event | none | own plot has an unexpired tip, 12 studs of RichTipAnchor | adds the tip, clears it |
| CollectTips | event | none | v0.8 (section 12): the caller stands inside their own plot, at least one pile waits; 2 per second | pays every waiting pile, clears them |
| AnswerCollector | event | accept | v0.8 (section 12b): a live Collector visit on the caller's plot, 12 studs of him; on accept the cat is owned, resting and unlocked; 1 per second | trade: removes the cat, pays the offer; either way ends the visit |
| OpenMysteryGift | event | none | v0.8 (section 12b): a gift waits on the caller's plot, 12 studs of it; 1 per second | pays the rolled gift, fires MysteryGiftResult |
| RedeemCode | event | text | F65 (section 11d): within 12 studs of a `CodesCat`, a string of at most 40 bytes, trimmed and lowercased, letters and digits, a known active code not yet redeemed; 1 per 2 s, locked 60 s after 5 wrong in a minute | pays the prize, saves the code id, fires CodeResult either way; v0.10: a `requiresGroup` code also needs `IsInGroup(Config.GroupId)`, and the code box opens from the walk-in circle |
| UsePotion | event | potionId | v0.8 (section 12b): a known potion, count above 0, the buff below PotionMaxMinutes; 2 per second | count - 1, extends `buffs[potionId]`, ProfileSync, the character's `ActivePotions` (section 13) |
| OpenCrate | event | crateId | v0.7 (golden-fish.md section 8): 14 studs of a `FishMarket` station, a known crate whose area is unlocked, a banked crate (used first) or `price` affordable in fish, CrateOpenCooldownSeconds 2; 1 per second | rolls, adds the piece or its refund, updates `crateLuck`, fires CrateResult |
| BuyFishItem | event | itemId | v0.7: 14 studs of the Market, a known `Catalog.fishShop` row, affordable, below its max level; 2 per second | spends fish, adds the item or level |
| TelemetryReport | event | name, value | allowlist, 10 per minute | analytics only |
| ClaimOffline | event | none | pending above 0 | adds coins |
| ClaimTipJar | event | step | F47 (section 11b): integer 1 to 12, unclaimed this session, session minutes reached; 1 per second | pays the step, fires TipJarState and ProfileSync |
| IntroDone | event | shot, replay | F72: `shot` an integer 0 to 9 (0 = played to the end), `replay` a boolean; 1 per second | the first non-replay call sets `introSeen`; every call logs `intro_cutscene` (finished or skipped, shot, replay) |
| ClaimDailyTreat | event | none | v0.10, F70 (section 11e): a stamp due; 1 per second | pays the day, sets `dailyTreat`, ProfileSync |
| ClaimIndexReward | event | areaId, milestoneId | F48 (section 11b): known area and milestone, count met from `collection` or `goldCollection`, not claimed; 1 per second | pays, marks `indexRewards`, ProfileSync |
| SpinWheel | event | none | F49 (section 11c): within 14 studs of a `SpinWheel` station, a free or banked spin, SpinCooldownSeconds since the last spin; 1 per second | pays the slice, fires SpinResult and ProfileSync, sets `LastSlice` then `LastSpinAt` |
| TutorialAdvance | event | step | step is tutorialStep + 1 | saves step |
| SetSetting | event | key, value | engineer #202 and #215: `key` one of the nine `settings` keys (F72 adds `tutorialButton`); `value` a number from 0 to 1 for `musicVolume` and `sfxVolume` (rounded to 0.01), a boolean for the rest; 4 per second | saves to `profile.settings`, answered by ProfileSync |
| CatchSchedule | server to client | strayId, circles, windows | | UI draws the circles |
| CatchResult | server to client | strayId, grades, success, charmGain | | UI grades, charm line and toast (v0.5) |
| RescueChallenge | server to client | rescueSpotId, challenge | | UI draws the bar or the shake |
| RescueResult | server to client | rescueSpotId, hits, pawsLeft, done, success | | UI |
| DealerStock | server to client | v0.8: `{ window, restocksAt, stock = { { lureId, cost, amount, bought } } }` (was slots) | | sent at night start, at each window change during night, when the screen opens and after every BuyDealerFood, bought or refused |
| BaitReady | server to client | catView | | UI bait card |
| TipJarState | server to client | `{ sessionStartedAt, claimed }` | | on profile load and after each ClaimTipJar (F47) |
| SpinResult | server to client | slice, amount | | the window lands on `slice` (0 means refused) and shows `amount` (F49) |
| CrateResult | server to client | crateId, decorId, duplicate, refund | | v0.7: the reveal; a refusal is (crateId, "", false, 0) |
| CollectorOffer | server to client | catUid, offer, endsAt | | v0.8: the owner's Cat Collector card (offer in the `Catalog.collectorOffers` row shape); `catUid` "" ends the visit |
| CodeResult | server to client | ok, message, prize | | F65: the code box's answer line and the prize pictures |
| MysteryGiftResult | server to client | kind, id, count | | v0.8: what the gift held (`kind` potion, lure, fish or spin) |
| ProfileSync | server to client | partial `PlayerState` | | adds `tier`, `bait`, `goldCollection`, `rankUp` progress; F48 adds `indexRewards`, F49 adds `spin`; v0.7 adds `goldenFish`, `crates`, `crateLuck` and `fishPerks`; v0.8 adds `potions`, `buffs` and each cat's `locked` |
| CatCaught | server to client | catId, isNew, gold, isNewGold | | cat found popup |
| OfflineEarnings, Toast | server to client | as before | | |
| Announce | server to all | text | | Epic and up, every gold cat, every rank up to Tier 3 and up; v0.8 every Mythical a night wave spawns (section 9) |

Removed: GrabEnd (replaced by CatchPress), RescueEnd (replaced by RescuePress), EquipLure.

v0.4 addition, `Travel(destination)` (engineer's F19, the shape is theirs): `home` or an area id; the area is unlocked, the player is not carrying, holds no catch or rescue lock (reviewer N47) and TravelCooldownSeconds (3) has passed; moves the character to that destination's entry point.

## 16. Analytics events (AnalyticsService)

The plan is the growth thread's [analytics-plan.md](../../growth/analytics-plan.md). v0.3 asks it to add: onboarding steps `first_role`, `first_bait`, `first_bait_resolved`, `tier_2`; custom events `catch_circles` (rarity, net level, perfect count; per-circle error goes to the exploit check), `rescue_attempt` (trap type, rarity, success), `bait_resolved` (food, rarity, tame or letgo), `bump` (success, rarity, area), `rank_up` (tier, minutes played), `dealer_buy` (food, tier), `rich_tip` (claimed or auto), `cat_renamed`, `gold_found` (method, rarity); progression `tier` 1 to 5 in place of `cafe_level`. Sinks add `rank_up` and `dealer`. The growth thread also added `bump`, `drop_outcome` and `left_after_bump` to judge griefing in the alpha (analytics-plan.md, PR #33). v0.4 asks for `catch_circles` to add `missed`, `purrfect` and `charmGain` (v0.5 drops `pawsLeft` and adds `tryNumber`, the player's tries on that stray), `shove` (knocked loose or not, area) in place of `bump`, a custom event `autopress_flag` (set or cleared), and `travel` (destination) to see whether players still walk. F72 adds the custom event `intro_cutscene` (finished or skipped, the shot, replay) so the growth thread can see where new players skip the intro.

## 17. Tuning constants (`src/shared/Config.luau`)

Changed or new in v0.3 (everything not listed keeps its v0.2 value):

| constant | value | was | used by |
|---|---|---|---|
| DayLengthSeconds | 300 | 180 | ClockService |
| NightLengthSeconds | 300 | 120 | ClockService |
| WaveSize | 10 | 6 | CatService |
| NightIncomeMultiplier | 0.6 | new | Economy |
| GoldMultiplier | 1.5 | new | CatStats |
| GoldChanceNet, GoldChanceBait, GoldChanceRescue | 0.02, 0.02, 0.10 | new | CatService |
| CircleLeadInSeconds | 0.6 | new | CatService |
| CircleGapMin, CircleGapMax | 0.40, 0.75 | new | CatService; spec: CircleGapMin > max(good) + CatchLatencyCapSeconds |
| CircleScorePerfect, CircleScoreGood | 1.0, 0.5 | new | CatService |
| NetWindows | per section 10 table | new | CatService, UI |
| CatchLatencyCapSeconds | 0.15 | new | CatService |
| RescueSpawnChance | 0.6 | 0.5 | CatService |
| RescueMinStuck | 1 | new | CatService, stuck cats guaranteed per area per night |
| RescueBarSpeed, RescueZoneWidth | per section 10b table | new | CatService, UI |
| RescueTolerance | 0.03 | new | CatService |
| RescuePatience | 3 | new | CatService, UI |
| RescueRetrySeconds | 3 | new | CatService, for other players |
| RescueSelfRetrySeconds | 6 | new | CatService, for the player who just failed |
| RescueAttemptMaxSeconds | 15 | new | CatService |
| RescuedTipsMultiplier | 1.0 | 1.10 | CatStats |
| LureWaitSeconds | 600 | 45 | CafeService |
| BaitBowlRangeStuds | 12 | new | CafeService |
| BumpEnabled | true | new | CatService |
| BumpRangeStuds | 6 | new | CatService |
| BumpChance | 0.5 | new | CatService |
| BumpGraceSeconds | 3 | new | CatService |
| BumpSafeRadiusStuds | 15 | new | CatService |
| BumpCooldownSeconds | 12 | new | CatService |
| BumpSameTargetSeconds | 60 | new | CatService |
| DropOwnerPrioritySeconds | 8 | new | CatService, only the old carrier can catch a dropped stray |
| DroppedMinStaySeconds | 120 | new | CatService, a dropped stray skips a wave that starts sooner than this after the drop |
| CustomerSpawnSecondsNight | 12 | new | client customers |
| RichCheckSeconds | 60 | new | CafeService |
| RichChance | 0.15 | new | CafeService |
| RichTipSeconds | 45 | new | CafeService |
| RichTipStaySeconds | 90 | new | CafeService |
| DealerRangeStuds | 12 | new | DealerService |
| DealerWindowSeconds | 600 | new | DealerService, global stock window |
| CatNameMaxLength | 20 | new | CafeService |
| RenameCooldownSeconds | 5 | new | CafeService |
| AnnounceMinRarity | Epic (plus every gold cat) | Epic | CatService |

Changed or new in v0.4:

| constant | value | was | used by |
|---|---|---|---|
| patience (Catalog rarity field) | 3, 2, 2, 1, 1 | fleesOnFail | CatService, UI paw row |
| StrayWarySeconds | 5 | new | CatService, the player who just missed |
| StrayJumpBackStuds | 6 to 10 | new | CatService |
| PerfectCharmBonus | 4 | new | CatService |
| PurrfectCharmMultiplier | 2 | new | CatService |
| AutoPressFlagRate | 0.95 | `Circles.AUTO_PRESS_RATE` | CatService |
| AutoPressClearRate | 0.85 | new | CatService |
| NormalWalkSpeed | 20 | 16 | CatService, PlotService |
| CarryWalkSpeed | 16 | 13 | CatService |
| TravelCooldownSeconds | 3 | new | Travel (F19) |
| alley spawnPoints | 24 | 14 | Catalog areas |

Changed or new in v0.5 (Gavin's round 2):

| constant | value | was | used by |
|---|---|---|---|
| fleeStuds (Catalog rarity field) | 12, 16, 20, 26, 32 | patience | CatService |
| StrayFleeSpeed | 26 | new | CatService |
| StrayRestSeconds | 1.5 | new | CatService |
| CatchHoldSeconds | 0.5 | new (Derek 2026-10-27, was a single press) | CatService and RescueService prompts |
| StraySelfRetrySeconds | 1 | new (v0.5.1, S44) | CatService |
| GoldChanceNet, GoldChanceBait | 0.05, 0.05 | 0.02, 0.02 | CatService, food cards |
| ShoveKnockbackStuds | 10 | new | CatService, target client |
| BumpCooldownSeconds | 8 | 12 | CatService (Shove) |
| BumpSameTargetSeconds | 20 | 60 | CatService (Shove) |
| ShoveTargetImmuneSeconds | 4 | new (v0.5.1, S45) | CatService (Shove) |
| DealerSlotWeights | 50 / 33 / 14 / 3, one row | per tier | DealerService |

Removed in v0.5: patience, StrayWarySeconds, StrayJumpBackStuds, CustomerSpawnSecondsNight.

New in v0.6 (F49, the Spin Wheel station):

| constant | value | was | used by |
|---|---|---|---|
| SpinStationRange | 14 | new | SpinService |
| SpinCooldownSeconds | 4 | new | SpinService, Spin window animation |
| SpinBankCap | 20 | new | SpinService, TipJarService |

New in v0.7 (decided 2026-10-27 19:27, [golden-fish.md](golden-fish.md) section 8): CratePrice 60, CrateDuplicateRefund {Common 10, Rare 20, Epic 40, Legendary 80, Mythical 150}, CrateLuckyEvery 20, FishMarketRange 14, CrateOpenCooldownSeconds 2, DecorSpots {2, 3, 4, 5, 6} by tier, DecorIndexBonus 0.05, DecorIndexHalfFish 25, the crate piece bonuses {0.02, 0.04, 0.08, 0.15, 0.25}, FishFirstCatch { Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 40 } and FishRepeatCatch { Epic = 1, Legendary = 3, Mythical = 8 } (maps by rarity, as built in PR #295), FishRankUp { 10, 25, 50, 100 } for Tiers 2 to 5, TipJarStep12Fish 5. A first catch that is also gold pays both the first catch and the first gold catch rows (an Epic: 8 + 16 = 24), because it fills both Index pages.

Changed or new in v0.8 (Gavin's round 3 answers 1 to 6):

| constant | value | was | used by |
|---|---|---|---|
| fleeStuds (Catalog rarity field) | 24, 32, 40, 52, 64 | 12, 16, 20, 26, 32 | CatService |
| StraySelfRetrySeconds | {3, 6, 10} by misses in a row | 1 | CatService, the player who missed |
| StrayMissStreakResetSeconds | 60 | new | CatService |
| StartledWalkSpeed, StartledSeconds | 12, 2 | new | CatService, the player who missed |
| CatchBurstRadiusStuds, CatchBurstStuds | 10, 8 | new | CatService, other players' clients |
| CatchRushWalkSpeed, CatchRushSeconds | 24, 5 | new | CatService |
| BumpChance | 1.0 | 0.5 | CatService (Shove) |
| DropOwnerPrioritySeconds | removed | 8 | anyone picks up a dropped cat |
| DealerWindowSeconds | 300 | 600 | DealerService |
| DealerAmountWeights | per section 8b table | DealerSlotWeights | DealerService |
| LureWaitSecondsNight | 300 | new | CafeService |
| NightIncomeMultiplier | 1.0 | 0.6 | Economy |
| TipPileSeconds, TipPileRateSeconds, TipPilesMax | 30, 6, 6 | new | CafeService |
| RichChance | 0.10 | 0.15 | RichTipService |
| RichTipSeconds | 120 | 45 | RichTipService |
| CollectorCheckSeconds, CollectorChance, CollectorStaySeconds | 120, 0.12, 180 | new | VisitorService |
| CollectorValue | 1, 3, 8, 20, 50 by rarity | new | VisitorService |
| CollectorGoldMultiplier | 3 | new | VisitorService |
| CollectorRollMin, CollectorRollMax | 0.8, 1.5 | new | VisitorService |
| MysteryCheckSeconds, MysteryChance, MysteryStaySeconds, MysteryGiftKeepSeconds | 120, 0.08, 120, 600 | new | VisitorService |
| PotionMaxMinutes | 60 | new | PotionService |
| CodesCatRange, CodeMaxLength, CodeWrongLimit, CodeLockSeconds | 12, 20, 5, 60 | new (F65, Derek 19:33) | CodeService |

Changed or new in v0.9 (Derek's short night, F66):

| constant | value | was | used by |
|---|---|---|---|
| NightLengthSeconds | 90 | 300 | ClockService, Clock, Audio |
| ServerStartDaySeconds | 300 | 120 | ClockService |
| DuskWarningSeconds | 15 | new | ClockService, UI |
| NightSweepSeconds | 2 | new | CatService (sends players home) |
| DroppedMinStaySeconds | removed | 120 | a dropped cat at dusk is checked in for its last carrier |

Changed or new in v0.10 (the round 4 answers and Derek's Codes Cat stand):

| constant | value | was | used by |
|---|---|---|---|
| DropReturnWalkSpeed | 8 | new | CatService, a dropped cat walking home |
| DropHomeRadiusStuds | 2 | new | CatService |
| DropReturnMaxSeconds | 60 | new | CatService, appears at home if the path is blocked |
| CodesCircleRadius | 4 | new | the Codes Cat circle (client opens the box; closes past radius + 1) |
| GroupId | 0 | new | CodeService, `requiresGroup` codes; set when the game moves to Derek's group |
| GoldLuckMax | 1.5 | new | gold rolls, the cap on summed Index `goldLuck` |
| BaitSpeedMax | 0.5 | new | CafeService, the cap on summed Index `baitSpeed` |
| TipJarStep12Fish | removed | 5 | Tip Jar rows carry their own fish |

CircleScorePerfect and CircleScoreGood no longer decide anything in v0.4; keep them only if a test or analytics wants a number.

Removed: GrabHoldSeconds, GrabMinHoldSeconds, NetBonus, LureBonus, RingBonusPerfect, RingBonusGood, RingPerfectWindow, RingGoodWindow, RingLatencyGraceSeconds, CatchChanceMin, CatchChanceMax, LureDespawnSeconds, LureReserveSeconds, RescueHoldSeconds, RescueLockSeconds (the attempt holds the lock), RenovateBonus. GrabLockSeconds becomes "schedule length plus 1 s".

Unchanged and still used: ServerPlayers 8, StartCoins 50, FavoriteMultiplier 1.5, TableBonus 0.10, EspressoBonus 0.15, OfflineRate 0.25, OfflineCapSeconds 3600, AutosaveSeconds 60, ServerStartDaySeconds 120, GrabRangeStuds 10, GrabRetrySeconds 2, GrabCooldownSeconds 2, CheckInRangeStuds 8, the cat stats constants, the customer constants, RemoteRateLimitPerSecond 10, MaxIdLength 40, TutorialGuaranteedStrayStep 2. World layout numbers stay the engineer's in `Config.World`, now with three more area centers and gates.
