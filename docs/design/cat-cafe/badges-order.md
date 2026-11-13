# Badges in order (#3618)

Asked by Derek, 2026-11-12 15:12 UTC: tutorial steps first, then one badge per tier from Tier 1 to Tier 7, then the rest in groups. Standing rule (15:15 UTC): badges are made only inside Roblox's free allowance of 5 a day, never with Robux.

28 badges: the 22 that exist keep their ids and what earns them, 6 are new. Every badge is earned by playing only. None can be lost.

## 1. The list

"Key" is the field in `shared/Badges.luau`. "New" badges need an icon and a badge id before they can be given.

### First steps (the tutorial)

| # | Key | Name | Line on the Roblox page | Earned when | State |
|---|---|---|---|---|---|
| 1 | firstCatch | First Catch | Catch your first stray cat. | 1 cat caught | exists |
| 2 | firstHome | Home Sweet Home | Carry your first cat home to your cafe. | the carry home step of the tutorial is passed | new |
| 3 | firstUpgrade | Fixing Up | Buy your first upgrade for your cafe. | 1 upgrade or piece bought with coins | new |
| 4 | firstFlight | Liftoff | Fly from the cannon for the first time. | 1 cannon flight | new |
| 5 | welcome | Welcome to the Cafe | Finish the first day at your cafe. | the tutorial is finished | exists |
| 6 | grandOpening | Grand Opening | Finish every step of the Grand Opening. | Grand Opening finished | exists |

### Cafe tiers

| # | Key | Name | Line | Earned when | State |
|---|---|---|---|---|---|
| 7 | cornerCafe | Corner Cafe | Open your Tier 1 cafe. | the cafe is Tier 1 or higher and the tutorial is finished | new |
| 8 | cozyCafe | Cozy Cafe | Rank your cafe up to Tier 2. | Tier 2 | exists |
| 9 | busyCafe | Busy Cafe | Rank your cafe up to Tier 3. | Tier 3 | exists |
| 10 | famousCafe | Famous Cafe | Rank your cafe up to Tier 4. | Tier 4 | exists |
| 11 | grandCafe | Grand Cafe | Rank your cafe up to Tier 5. | Tier 5 | exists |
| 12 | sunstoneCafe | Sunstone Cafe | Rank your cafe up to Tier 6. | Tier 6 | new |
| 13 | wonderCafe | Wonder Cafe | Rank your cafe up to Tier 7. | Tier 7 | new |

The badge names are the tier names in the game, so the page reads as the same ladder the player climbs.

### Catching

| # | Key | Name | State |
|---|---|---|---|
| 14 | purrfect | Purrfect! | exists |
| 15 | purrfectStreak | Purrfect Streak | exists |
| 16 | baitCat | Bait Cat | exists |
| 17 | rareFind | Rare Find (an Epic cat) | exists |
| 18 | legendaryFind | Legendary Find | exists |
| 19 | mythicalFind | Mythical Find | exists |

### Collecting

| # | Key | Name | State |
|---|---|---|---|
| 20 | catCollector | Cat Collector (25 cats) | exists |
| 21 | catExpert | Cat Expert (50 cats) | exists |
| 22 | goldenCoat | Golden Coat | exists |
| 23 | rainbowCoat | Rainbow Coat | exists |
| 24 | pageComplete | Page Complete | exists |

### With other players

| # | Key | Name | State |
|---|---|---|---|
| 25 | helpingPaw | Helping Paw | exists |
| 26 | firstTrade | First Trade | exists |
| 27 | partyGuest | Cafe Party Guest | exists |
| 28 | metOwner | Met the Owner | exists |

## 2. Rules for the new six

- **Catch up.** A player who already passed the step or tier gets the badge on the next join, through the same path the other badges use (`Badges.due`). So each rule reads only from the save: the tutorial step for Home Sweet Home, anything bought for Fixing Up, an area visited or the tutorial step past the cannon for Liftoff, the tier for the three tier badges.
- **Corner Cafe waits for the tutorial.** Every save starts at Tier 1, so without the wait it would pop on the first second of the first join and sit on top of the tutorial. It arrives with Welcome to the Cafe, as the first rung of the ladder.
- **No new toasts.** The badge is Roblox's own pop up. Nothing in the game points at an unearned badge.
- **A badge with no id yet is skipped**, as today (`Config.Badges` field 0).

## 3. Making them, free only

Six new badges at 5 free a day take two days.

- Day 1: Home Sweet Home, Fixing Up, Liftoff, Corner Cafe, Sunstone Cafe.
- Day 2: Wonder Cafe.

Each needs a 512 x 512 icon first (Model-Agent, in the style of the present set; the three tier icons show the cafe front of that tier). The Met the Owner badge used one of the free slots on the day it was made, so no other badge is made on a day when the count would pass 5.

## 4. Order on the Roblox page

The page order is set by hand in Creator Hub (Badges, drag to sort) and does not follow the code. Once the six exist, sort to the numbers in section 1. `Badges.LIST` takes the same order so the two never drift.
