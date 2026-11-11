# Rich customers leave a money bag (#3360)

Draft v1, 2026-11-11, Design-Agent. Builder: Gameplay-Engineer (`RichTipService`, `CustomerController`, `Screens/RichTip.luau`). Replaces the "the rich customer is the timer" rule in [data-model.md](data-model.md) section 12. Bags never save, so there is no save version step and no restart is needed.

## 1. Why
Derek2 (2026-11-11): "sometimes rich people don't have their timer start at the full time make it so rich customers leave money bags that sit there for a while instead of they themselves being the timer".

The short timer has a clear cause on main. `RichTipService.open` sets `expiresAt = min(now + RichTipStaySeconds, dusk)`, and a rich customer may still arrive until `DuskWarningSeconds` (15) before dusk. With a 345 s day and a 90 s stay, every rich customer that arrives in the last 90 s of the day gets a shorter timer, down to 15 s. That is about a quarter of all rich customers (75 of the 330 s in which one can arrive). The client's walk to the table also runs on that same clock, so the seated customer shows even less time.

## 2. The change
- When a rich customer comes, the server puts a **money bag** on table 1 at once, at the plot's `RichTipAnchor` (where the gold coin pile sits today). The bag holds the whole rich payout: `Economy.richTipAmount(dayRate)` with the Tip Potion and a running Cafe Event counted at the moment it drops, as now.
- The customer still walks in and sits for show for `RichCustomerSitSeconds` (20), then leaves as a normal customer does. The customer no longer stands for the timer and nothing waits on it.
- The bag's countdown starts at full time when the bag drops: `RichBagSeconds` (180). **No dusk clamp.** A bag dropped by day waits through nightfall, as a Mystery gift does (data-model 12b). Rich customers themselves still come only by day before the dusk warning, so none is seen arriving at night (Derek's 2026-10-28 rule).
- An account's first rich customer (#2792) keeps `FirstVisitStaySeconds` (300) for its bag.

## 3. The three questions from the issue
1. **How long a bag lasts:** 180 s, twice today's 90 s. A flight out to an area and back plus a catch fits in about 3 minutes, so a player who hears about the bag can get home for it. Longer would make the bag meaningless as a reason to check the cafe.
2. **More than one at once:** yes, up to `RichBagsMax` (3) per plot. The rich timer keeps counting while a bag waits (today it pauses while a tip is open). With the 240 to 720 s timer and no rate boosts two bags rarely overlap; with Cafe Style and Grand Cafe (x2.25) the shortest gap is about 107 s, so two can wait together. At the cap the timer holds at 0 until a bag goes, and the next customer comes then. Bags 2 and 3 sit on the anchor with small side offsets (engineer's choice of spots, on table 1, never overlapping the tip pile ring).
3. **Is an uncollected bag lost:** yes. It fades out over its last 5 s and pays nothing, which keeps Derek's 2026-10-28 rule "if you miss it you miss it". A bag also goes, unpaid, when its owner leaves the game or releases the plot. No UI text ever says anything is lost by leaving.

## 4. Collecting
- The owner walks into the bag (touch, within `RichTipRangeStuds` 12 of the bag) or taps it (a ProximityPrompt-style tap on phone, E on desktop). Both send `ClaimRichTip(bagId)`.
- The server checks: the caller owns the plot, the bag id is in its own table and not expired, and the caller's root is within `RichTipRangeStuds` + 2 of that bag's position. It takes the record out of the table before it credits (S29, pays exactly once). Rate limit as today's ClaimRichTip.
- Only the owner can collect. Other players see the bag but it does nothing for them. The F90 Waiter does not sweep money bags to the till; the bag is the reason to come home.
- On collect: the existing gold "+$X" pop and coin sound, then the bag is gone.

## 5. Display (client, display only)
- The server makes each bag as a folder child `RichBags/<bagId>` on the plot with attributes `Amount`, `ExpiresAt` (server `os.time()`) and `Outcome` ("claimed" or "missed", set just before it goes). The client builds the bag model and a small ring countdown over it from those. Decisions read the server's table only.
- `RichTipAmount` and `RichTipExpiresAt` on the plot go away once the client reads bags; the engineer can keep them one release for older clients.
- The gold marker on the HUD (`Screens/RichTip.luau`) points at the nearest waiting bag and shows the total waiting, for example "$1,240 waiting". Calm, one line, no flashing.
- Model: a small gold-tied sack with a coin symbol, Cozy Cream style, under 500 triangles. Until the Model lane makes one, the current coin pile stands in.

## 6. Numbers (new Config values)
| Name | Value | Note |
|---|---|---|
| RichBagSeconds | 180 | replaces RichTipStaySeconds (90) for the payout |
| RichBagsMax | 3 | bags waiting at once per plot |
| RichCustomerSitSeconds | 20 | how long the customer sits for show |
| RichBagFadeSeconds | 5 | fade at the end of the wait |

Unchanged: RichEveryMin 240, RichEveryMax 720, RichTipSeconds 120, RichTipRangeStuds 12.

## 7. Pace and analytics
- The payout per customer is the same. Fewer bags are missed (longer wait, no dusk clamp), so a player who stays home sees about the same as today and a player out catching gets somewhat more. Rich tips are about 5% of day income, so Tier 2 and Tier 5 pace barely move. If QA's Pace run shows a tier too fast, raise its cost (economy rule v0.8), never cut the bag.
- `rich_tip` keeps "claimed" and "missed" and adds the seconds the bag waited, so Growth can see how many bags players reach.

## 8. Test plan for the build
- A rich customer arriving 20 s before dusk shows a bag with the full 180 s, and the bag still waits after nightfall.
- Two bags with a boosted rate: both show, both can be collected, each pays once.
- A non-owner touching the bag gets nothing. A claim from 30 studs away is refused. A claim for an expired or unknown bag id does nothing.
- Leaving the game with a bag waiting: it is gone on rejoin, no error.
- Phone, tablet, desktop and console: the tap works and the HUD line fits.
