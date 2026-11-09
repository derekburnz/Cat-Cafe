# Late-game stations: Oasis Spa (Desert, Tier 6) and Relic Museum (Ruins, Tier 7)

Status: specced by Design-Agent (friend's project), 2026-11-09, for #2651 part 4 (epic #2580). The picks are from [tier6-7-areas.md](tier6-7-areas.md) §8 and §9.3. Derek2's "make assumptions" rule (2026-11-09 04:00Z) covers the numbers here, and he can tweak any of them.

Builders:
- Gameplay-Engineer: services, saves, remotes and the Pace check.
- Model-Agent: the two stations.
- UI-Engineer: the cards and cannon picker lines.
- VFX-Agent: the steam and the exhibit sparkle.
- Sound-Agent: two cues.
- Review-Agent and QA-Planner.

Both follow the camp-extra rules ([camp-extras.md](camp-extras.md) §1, [camp-stations.md](camp-stations.md) §1):
- Each sits in its area's camp, in the safe zone, at the camp's `Layout.campExtras` point.
- Each uses the shared `ReadyBang` "!".
- Each has one line in the cannon picker.
- Nothing is sold, sped up or refilled for Robux.
- Nothing changes catch, luck, gold or rainbow odds.

The #2687 unlock perks for these areas (Warm Paws, Curator) come from the tier and are separate from what these stations do.

## 1. Oasis Spa (Desert camp, Tier 6)

**What it does.** A cat soaks for an hour and comes back one level higher. Levelling is slowest at the top: level 49 to 50 takes 5,880 XP, about 1.6 hours of work (`CatXpBase` 120 × n). So this is a free, steady push that also works while the player is away.

- **Slots.** 1 slot, free. Two more open for golden fish, bought once and kept: slot 2 for 100 fish, slot 3 for 250 (`SpaSlotPrices = { 0, 100, 250 }`).
  - Fish are never sold for Robux (store-skus.md), so these prices stay outside `monetization-policy`.
- **Put a cat in.** At the spa's card, pick any owned cat below `CatMaxLevel`. Working, resting, locked and unlocked cats are all allowed.
  - **A working cat** leaves its role, and the server runs that player's Equip Best for cats so the slot refills from the cat room.
  - **While soaking** the cat earns nothing and no XP. It shows "At the spa" in the cat room, and it can't be assigned, sold, traded, given to the Collector or donated to the Museum. Each of those refusals reads "This cat is at the spa".
- **Timer.** `SpaSeconds` 3600, real time from when the cat went in. It counts offline too, like every camp extra. When done, the cat waits in its slot for collection. It never auto-returns, so it can't land mid-trade or mid-assign.
- **Collect.** Collect at the card. Each finished cat gains +1 level, capped at `CatMaxLevel`, and keeps its XP toward the next level. It goes back to the cat room, then Equip Best runs, so a better cat steps back into its role.
  - One press collects every finished slot.
  - A toast reads "Mochi relaxed: Lv 37 → 38!".
- **Take out early.** Allowed at any time, with no level gained. The card asks "Take Mochi out now? It won't level up." Nothing is lost.
- **Ceiling.** At most 3 levels per hour, and away time gives at most 3 levels per visit, because a finished cat waits. A player checking in morning, afternoon and evening gets about 9 levels a day. That matters at Tier 6–7 without replacing work XP.
- **The station** is `CatCafe_Camp_Desert_OasisSpa`:
  - A small tiled pool, about 9 studs wide, ringed by two palms.
  - Three striped lounge cushions, a stack of rolled towels and a "Oasis Spa" sign on a carved post.
  - It's solid, climbable and finished on every side, with a `PromptAnchor` at the pool edge and a `BangAnchor` above the sign.
  - **The owner's soaking cats** show in the pool with a little towel on their heads. They're drawn on the owner's client only, from the existing cat models plus one towel accessory. Other players see the steam.
  - **Steam.** Gentle steam rises off the water (VFX, one emitter). It's still on Reduce Motion.
- **Picker line:** "Oasis Spa: 2 relaxing · 1 ready !" or "Oasis Spa: empty".
- **Sound:** a soft splash on putting a cat in, and a happy chime on a level-up collect.

## 2. Relic Museum (Ruins camp, Tier 7)

**What it does.** Duplicate cats get a lasting use. Give one copy of a cat to fill its exhibit. Filling every exhibit in a room gives a permanent tip bonus.

- **Rooms.** One room per area, seven in all (Alleyway, Park, Neighbourhood, Woods, Sewer, Desert, Ruins). Each room has that area's 10 cats as exhibits.
  - Shop cats, the Bellhop Cat, the starter cat and event-only cats have no exhibit.
  - That makes 70 exhibits.
- **Donate.** At the Museum card, each empty exhibit shows its cat's silhouette and "You have 3". "Donate" lists the copies the player can give. A copy can be given when all four hold:
  - **Not the last one:** the player owns at least one other cat of the same `catId`, so the Museum never takes a player's only copy.
  - **Unlocked:** locked cats can't be given, the same F62 rule as selling and trading.
  - **Not busy:** not at the spa and not in an open trade.
  - **Picked lowest-first:** the list is sorted lowest level first, then lowest charm, so the obvious choice is the weakest copy.
  - **Gold and rainbow copies are allowed,** but the card warns "This is a gold cat. Give it anyway?". A gold or rainbow copy also adds a small gold or rainbow frame to the exhibit, which is only a look.
- **A donated cat leaves the save for good,** like a sale but paying no coins. It stays found in the Index, because the Index counts found-ever.
  - If it was working, Equip Best refills the role.
  - Each exhibit takes one cat, once.
- **Room bonus.** A finished room gives **+2% tips forever** (`MuseumRoomTipBonus` 0.02), so all seven give +14%.
  - It adds to the same tips-forever total as the Index milestones (IndexRewardService), so every tip source reads one number.
  - A finished room plays a short banner: "Desert Hall complete! +2% tips forever".
- **Why +2%:** the Museum opens at Tier 7, the last tier, so it can't speed up a rank-up. Pace's tier times don't move, and the bonus only shortens the late upgrade climb a little.
  - Early rooms (Alleyway to Sewer) fill fast from duplicates a Tier 7 player already has, so they give a burst of satisfaction on unlock.
  - The Desert and Ruins rooms need their Legendaries and Mythicals twice, which is the long goal.
- **The station** is `CatCafe_Camp_Ruins_RelicMuseum`:
  - A small museum front in carved sandstone with jade trim, about 10 studs wide.
  - Two columns, three steps, a velvet rope on brass posts, and a glass case by the door holding a little golden cat idol. A "Relic Museum" sign sits over the door.
  - It's solid, climbable and finished on every side, with a `PromptAnchor` at the rope and a `BangAnchor` above the sign.
  - **Exhibits live on the card**, drawn with the existing Index pictures, so there are no 70 statues in the world.
- **The "!"** shows while the player has at least one donatable copy for an empty exhibit. It's the same "something to do here" rule as the other extras, and hides when there is none.
- **Picker line:** "Relic Museum: 23/70 · 4 can be filled !".
- **VFX and Sound:** a gold sparkle on the exhibit tile when filled, and a soft gallery bell. A room finish reuses the Index milestone fanfare.

## 3. Contracts

- **Config:**
  - `SpaSeconds` 3600, `SpaSlotPrices` { 0, 100, 250 }.
  - `MuseumRoomTipBonus` 0.02.
  - `CampExtraRangeStuds` 8 is reused.
- **Save:** both fields are optional, and this is a save version bump, so claim `DataService.luau` and `ProfileSchema.luau`. It can share part 3's bump if that hasn't shipped.
  - `spa = { slots: number (1 to 3), soaking: { [slot]: { uid: string, at: number } } }`.
  - `museum = { [catId]: "base" | "gold" | "rainbow" }`.
  - **Sanitizer:** spa uids must exist in `cats`, and `at` must be a number no later than now. Museum catIds must be known exhibit ids.
- **Remotes** (client asks, server decides, one call a second each, tier and range checked):
  - `SpaPut(slot, catUid)`: checks the tier is at least 6, the player is in range, the slot is open and empty, the cat is owned and below max, and the cat is not at the spa or in a trade.
  - `SpaTakeOut(slot)`: allowed at any time, with no level gained.
  - `SpaCollect()`: collects every finished slot.
  - `SpaBuySlot(slot)`: the next slot only, with the fish balance checked and spent through the single fish-spend helper.
  - `MuseumDonate(catUid)`: checks the tier is at least 7, the player is in range, the cat has an exhibit, the exhibit is empty, the cat is owned and unlocked, it's not at the spa or in a trade, and another copy of that catId remains. All of these are checked again inside the save update.
  - `CampExtrasState` gains `spa = { slots, soaking with doneAt }` and `museum = { filled, canFill }`.
- **Guards elsewhere** (all read one `CatStats.busy(profile, uid)` helper that returns "spa", "trade" or nil):
  - Selling, assigning, trading (`Trade.offerRefusal`), the Collector's pick (`Collector.pickCat` skips spa cats) and Equip Best.
- **Analytics:**
  - `spa_put` and `spa_collect`, with level bands.
  - `museum_donate`, with rarity and variant.
  - `museum_room`, with the area.
  - Counts only, never who.

## 4. QA checks
1. **Spa:**
   1. A working cat put in the spa leaves its role, and Equip Best refills it.
   2. After 60 minutes, including time offline, collecting gives exactly +1 level, and XP toward the next level is kept.
   3. A cat at 50 can't go in.
2. **Spa, early exit:** taking a cat out early gives no level. A spa cat can't be sold, traded, assigned, asked for by the Collector or donated.
3. **Spa slots:** slot 2 costs 100 fish and slot 3 costs 250. Buying slot 3 before slot 2 is refused. A player with 99 fish is refused.
4. **Museum, refusals:** the last copy of a cat, a locked copy, a spa copy and a copy in an open trade can't be donated. A second copy for a filled exhibit is refused.
5. **Museum, bonus:** finishing a room adds exactly +2% to tips forever, once. Rejoining doesn't add it again.
6. **Exploits:** a fired `MuseumDonate` or `SpaPut` with another player's uid, a made-up uid or from out of range is refused.
7. **Pace.spec:** tier times are unchanged. The spa opens at Tier 6, so check that Tier 6 → 7 doesn't drop below the #2683 band. If it does, raise `SpaSeconds`.
