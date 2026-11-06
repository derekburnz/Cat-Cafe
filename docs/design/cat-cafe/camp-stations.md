# Camp stations: Picnic Basket, Yard Sale and Fish Pond as real stations (#1133, #1154, #1232)

Decided by the Coordinator for the friend, overnight 11-05, from Derek's 11-04 asks. Written up by Design-Agent. Owner: game-designer. Readers: Model-Agent, UI-Engineer, VFX, Gameplay-Engineer, QA. This changes [camp-extras.md](camp-extras.md) sections 2 and 3 for these three extras. The Lost and Found (Sewer) gets its rework in section 4b (2026-11-06).

## 1. One shared "!" (all three)

- **Component:** `UI/Components/ReadyBang.luau`. It's the HUD's red "!" (#1074 / #1117) as a world BillboardGui on an attachment called `BangAnchor`, 2 studs above each station's sign.
- **Who sees it:** only the player whose extra is ready. It shows within 150 studs, so it's visible from the camp's cannon landing and from the cafe district for the Picnic Basket.
- **When:** it shows when the extra has something to claim (the same `held > 0` state the cannon picker already uses), and hides the moment it's claimed or while it refills. There's no new remote: `CampExtrasState` already says this.
- **Motion:** a slow 1-stud bob every 2 s. With Reduce Motion it's still. One per station and owner-only, so it stays well inside the phone budget.
- **Prompt cards:** they keep their personal refill time ("Next in 2 h 10 m", "12 fish · full in 2 h 10 m"). #1190's "no restock clocks" rule is about shop stock shared by everyone, not a player's own cooldown, and Derek asked for these.

## 2. Picnic Basket (Park, Tier 2) (#1133)

- **Station:** `CatCafe_Camp_Park_PicnicStation`. A wooden picnic table under a red-and-white checked parasol, with a basket, a thermos and a chalk A-frame sign reading "Picnic". It's about 8 studs wide and 7 tall, so it reads from a distance like the Spin Wheel and Fish Market do. It's solid, climbable and finished on every side. The thermos keeps its steam (`Presets.luau`).
- **Ready glow:** when a potion waits, a soft warm glow sits under the parasol (VFX, a single PointLight, inside the night glow budget). It's off while refilling.
- **Numbers:** unchanged. One Money Potion every 6 hours, holding 2.

## 3. Yard Sale (Neighbourhood, Tier 3) (#1154)

- **Station:** `CatCafe_Camp_Neighbourhood_YardSaleStall`. A folding table under a little striped awning, with cardboard boxes and a hand-painted "Yard Sale" sign on a stake. It's solid, climbable and finished on every side.
- **Timer, in place of the calendar day:** one free zone crate (crate-prices.md section 5) every **4 hours** from the last claim (`YardSaleClaimHours = 4`). It holds **1**, so crates don't stack. A player who drops by morning, afternoon and evening gets about three a day; a once-a-day player still gets one.
  - **Crate choice:** the crate is the next zone crate of the player's open areas in Catalog order, rotating each claim, so it's the same rule in any server.
  - **Balance:** crates are free and their odds don't change, so Mythicals stay about 1 in 190 crates. Two or three extra crates a day mostly speed up Commons and Rares, which is what makes the Decor Index feel alive.
- **Odds:** the card keeps its Odds button (monetization-policy, even though it's free).
- **Save:** `yardSale = { lastClaimAt }` replaces `{ day, bought }`. Migration: a save that took today's crate gets `lastClaimAt` = the start of that UTC day, so nobody gets a second crate right away or loses one. This needs **save version 33** (v32 shipped with Corner Shop v2), with the migration above. Say so in the PR's first line.

## 4. Fish Pond (Woods, Tier 4) (#1232)

- **Station:** `CatCafe_Camp_Woods_FishingHut`. A small fishing hut on a plank jetty over the pond, with a rod rack, a bucket and a "Fish Pond" sign on the roof edge. It's solid, climbable and finished on every side. The fish leap and gold glints stay (`CampCollect.luau`).
- **Faster fish:** **1 golden fish every 10 minutes** (`PondFishPerStep = 1`, `PondStepSeconds = 600`), holding **36** (6 hours, as before). That's 6 an hour, up from 4.
  - Two visits a day land about 72 fish (was about 48). That's about 2 extra crates a day at Tier 4 and 5, where golden fish matter least for pace.
  - The Market's prices don't need to change: crates are 40 fish and the Fresh Catch items 6 to 30.
- **The Golden Pond pass (`GoldenPondPassId`, already made in Creator Hub): convenience, not more fish.**
  - **What it does:** the owner can collect the pond **from anywhere**, with a "Collect" button on the Woods card in the cannon picker. It also gives the hut a gold-trimmed look and golden lily pads. That's all; it never adds fish.
  - **Why not Derek's "2x fish":** golden fish buy crates, which are random. If Robux buys more golden fish, every crate becomes a paid random item. Then crates would need PolicyService gating, which hides them for players where paid random items are restricted (monetization-policy section 2, rules 3 and 5). Our standing rule is that golden fish are never sold for Robux. A 2x pass would break that for one pond.
  - **If Derek still wants 2x fish,** the whole crate system needs the paid-random treatment first: PolicyService checks on every crate open and a restricted-player fallback. That's a separate design.
  - **Price:** R$99, the low end of Derek's R$100 to R$200, since it's convenience only. The store card reads: "Collect your Fish Pond from anywhere, plus a golden pond look. Same fish, less walking."
  - **Server:** `PassService` owner check (cached, granted on `PromptGamePassPurchaseFinished`). `CollectCampExtra("pond")` skips the range check only for an owner.

## 4b. Lost and Found (Sewer, Tier 5): rework and a big buff (Derek2, 2026-11-06)

Derek2: "the lost and found station needs a re-work and a massive buff". Today it's a small box by a pipe with one prize a UTC day, so a Tier 5 player barely notices it. It becomes the best of the four camp extras, because it's the last one a player unlocks.

- **Station:** `CatCafe_Camp_Sewer_LostFoundBooth`. A little lost-property kiosk built into the camp wall: a counter window under a striped awning, a brass bell on the counter, and shelves behind it piled with odd finds (an umbrella, one boot, a teddy bear, a lamp and a cat bed). It has a "Lost & Found" sign on a bulb-lit board, the dripping pipe stays above, and it's about 8 studs wide. It's solid, climbable and finished on every side, with a `PromptAnchor` at the counter and a `BangAnchor` above the sign.
- **Moving touch:** when something waits, the bell gives a little ring-wobble every few seconds and a bulb on the sign blinks. It's still on Reduce Motion.
- **The "!":** uses the shared `ReadyBang` (section 1) like the other three. It was left out when this spec was first written.
- **Timer:** one find every **2 hours** from the last fill, holding **3** (6 hours, like the pond). That's up to 12 a day, where it used to be 1. A player who visits morning and evening gets about 6.
- **Prize table (free, odds on the card):**

  | find | chance |
  |---|---|
  | 40 golden fish | 30% |
  | Lucky Potion + Gold Rush Potion | 22% |
  | 2 spins | 15% |
  | Sewer Crate | 18% |
  | Golden Classic Crate | 10% |
  | Golden Sewer Crate (if the Sewer pool has a golden crate, else a second Golden Classic Crate) | 3% |
  | **A lost cat:** a random Epic from one of the player's open areas, who walks into the cafe like a rescued cat | 2% |

- **Collect all:** the prompt says "Lost & Found: 3 finds, collect". One press opens them one after another in a single prize toast, with at most two pictures each.
- **Balance:** about 6 finds a day give about 72 fish, 1.3 potion pairs, 0.9 spin bundles and 1.9 crates, plus a lost cat about every 8 days. Golden fish and crates don't gate tiers, and Tier 5 is the end, so Pace.spec doesn't move. Nothing here is sold, sped up or refilled for Robux, and luck, gold and rainbow odds aren't touched (the lost cat rolls gold and rainbow like a rescue).
- **Contracts:** `LostFoundEverySeconds` 7200, `LostFoundHold` 3, `LostFoundTable` as above (`{ chance, fish?, potions?, spins?, crate?, lostCat? }`). Save: `lostFound = { at, held }` in place of `{ day, held }`. Migration: `at = now`, and `held` stays as saved. This is a save version bump, so claim `DataService`. `CollectCampExtra("lostFound")` pays every held find. QA: after 7 hours away, 3 are held. 10,000 cloud rolls match the table within one point. A lost cat is an Epic from an open area.

## 5. Contracts

- **Config:**
  - `YardSaleClaimHours` 4.
  - `PondFishPerStep` 1, `PondStepSeconds` 600, `PondHold` 36.
  - `ReadyBangRange` 150.
  - `GoldenPondPassId` stays.
- **Save:** `yardSale.lastClaimAt`, save version 33 (see section 3). The pond and picnic saves are unchanged.
- **Remotes:**
  - `BuyYardSale(crateId)` checks `now >= lastClaimAt + 4 h` and the rotating crate, and refuses with the next time otherwise.
  - `CollectCampExtra("pond")` waives the range check for Golden Pond owners.
- **Models (Model-Agent, Blender toolkit, blender-asset-qa):** the three stations, each with a `PromptAnchor` and a `BangAnchor`, plus the gold variant for the hut.
- **UI-Engineer:** `ReadyBang`, the prompt-card lines, the cannon picker's Collect button for Golden Pond owners, and the Store card.
- **VFX:** the picnic glow.

## 6. QA checks

1. Each station is visible from its camp's cannon landing, and the Picnic Basket from the cafe district. A "!" shows only to the owner while something is ready, and hides on claim.
2. Yard Sale: claim, then try again 3 h 59 m later: refused, showing the time. At 4 h it works. A save from before the change that took today's crate can't claim again until 4 h after that UTC day started.
3. Pond: after 60 minutes away it holds 6. After 7 hours it holds 36, not more.
4. Golden Pond: an owner collects from the cannon picker anywhere and gets the same fish a walker would. A non-owner's `CollectCampExtra("pond")` from outside range is refused.
5. Pace.spec: no tier time changes, since golden fish don't gate tiers.
