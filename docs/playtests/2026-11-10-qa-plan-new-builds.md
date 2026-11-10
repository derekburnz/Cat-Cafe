# QA plan: the next Gameplay builds (2026-11-10)

QA-Planner. Covers golden fish and crates in trades (#2745), early upgrades (#2996), the Saturday update gift (#2997),
the "earned while away" notification (#2768), the Codes spot move (#3000) and the bigger Town Square (#3001).
Run each part on its build PR in a dev copy of the place. Steps marked **cloud** run in the cloud test runner
(`tools/cloudcheck`); the rest are Studio rows for Laptop-Tester or Desktop-Tester. Pass means every box is ticked
and a 10-minute session shows no new console errors.

## 1. Trading golden fish and crates (#2745)

Crates ship first, then fish behind the `tradeFish` flag. Fish get a separate security review (Review-Agent, against
`remote-security-checklist`) before the flag goes on.

### Crates
- [ ] **cloud** Adding crates refuses a count of 0, a negative count, 1.5, NaN, inf, a string, or more than owned. The swap checks the count again.
- [ ] **cloud** A crate in an open offer can't be opened ("This crate is in a trade").
- [ ] **cloud** Index prize, code and pass crates (`tradeable = false`) can't be added, even with a forced remote call.
- [ ] **cloud** `Trade.apply` with crates is idempotent: applying the same trade id twice changes counts once.
- [ ] **cloud** A shutdown in the middle of a swap (vault record written, apply not yet run) recovers with both crate counts exact.
- [ ] **cloud** An old vault record or log entry with no crates field loads as none. `sanitizeLog` keeps `gaveCrates` and `gotCrates`.
- [ ] Studio: a Desert or Ruins crate shows greyed out for a partner below that tier, with "They haven't reached the Desert yet".
- [ ] Studio: the received crate opens with the receiver's own luck and pity. The giver's pity doesn't change.
- [ ] Studio: the Crates tab and the "x3" badge work on phone and gamepad, including the long press picker.

### Golden fish
- [ ] **cloud** The amount must be a whole number from 0 up to the balance and `TradeMaxFish` (200). Negative, fraction, NaN, inf, string and over-balance amounts are refused on every change and at the swap.
- [ ] **cloud** Every fish spend is refused during an open trade with "Finish your trade first". There are 6 spend sites and each needs its own test: a fish-paid OpenCrate (no banked crate), BuyCrateBundle, BuyFishItem, the Fresh Catch shelf, the Spa slot buy and the Mystery Market. If any path skips the freeze, it's a blocker.
- [ ] **cloud** With `tradeFish` off, the spend freeze lifts: all 6 sites work during an open cat or decor trade.
- [ ] **cloud** `TradeFishPerDay` (400 received) holds across leave and rejoin and across two servers, and resets on the next game day.
- [ ] **cloud** Received fish never add to `lifetimeGoldenFish`, the leaderboards or milestones.
- [ ] **cloud** With `tradeFish` off, the fish row is hidden and a forced remote is refused. Cat and decor trades still work.
- [ ] Studio: changing an amount resets both Ready presses and shows "Changed!". The confirm screen shows "🐟 120". A fish-only gift shows "You get nothing back" with the 2 s wait.
- [ ] Studio: a two-player trade of fish plus crates plus a cat, then both rejoin. All counts match the trade log.

## 2. Early upgrades (#2996)

- [ ] **cloud** `Pace.spec` new-player case: the gaps between the first three buys are each 60 to 90 s (median of 10 runs). Tier 1 to 7 times stay inside their current bands.
- [ ] **cloud** `StartCoins` and every tier cost are unchanged. Only Tables level 2 and the third buy's first level move.
- [ ] Studio: on a fresh save, each of the three buttons pulses once when it becomes affordable, not again on later visits. With Reduce Motion on, there is no pulse and the highlight still shows.
- [ ] The `upgrade_bought` event carries the seconds since the last buy (check in the Studio output, not the live data).

## 3. Saturday update gift (#2997)

- [ ] **cloud** A join with a new `Config.UpdateGift.id` pays 15 fish and 1 spin once. A second join, a rejoin on another server and a server restart pay nothing.
- [ ] **cloud** An old save with no `updateGiftId` migrates and gets the gift once. `ProfileSchema` version goes up by one.
- [ ] **cloud** Changing the id pays again once. An empty or nil id pays nothing.
- [ ] Studio: one toast, "Update gift! 🐟 15 + 1 spin", with no claim button, timer or countdown wording.
- [ ] Release: the first Saturday publish (2026-11-14 17:00 UTC) carries the new id. Do a look-only live join after it to see the toast once.

## 4. "Earned while away" notification (#2768)

This one is still on the backlog. It needs Derek's OK before anything is sent, because it messages players outside the game.
- [ ] **cloud** The amount in the message is the real offline earning from the save, rounded the same way as the in-game "while you were away" card.
- [ ] **cloud** At most one send per player per day, only to players who opted in through PromptOptIn (#2766), and only after the chosen hours away.
- [ ] The wording has no pressure or fake urgency (young-audience rule). Settings has an opt-out if there is more than one kind.
- [ ] The Open Cloud key is only in repo secrets. Actions logs print no user ids or amounts.
- [ ] First real send: one test account only, with Derek's OK. Tapping the notification opens the game.

## 5. Codes spot move (#3000)

Wait for Derek's pick between A (move the whole stand) and B (move only the circle).
- [ ] **cloud** `Layout.spec` checks the new spot against the lane, the Spin Wheel, the Mystery ring and the Bellhop card: station centres at least 8 studs apart and 6.5 from square props (#2643 guard).
- [ ] Studio: the code box opens only when standing in the circle and closes when leaving it. It never opens from the Mystery ring or the Bellhop card.
- [ ] Studio: from the spawn and the cannon, the Codes Cat or circle is still easy to see. The intro's stations shot still frames it (A only).
- [ ] Studio: the circle works on phone (touch) and gamepad (X prompt).

## 6. Bigger Town Square (#3001)

Run this after Model-Agent's re-fit and Gameplay-Engineer's layout land. It is the "make sure everything still works" list.
- [ ] **cloud** `Layout.spec` with the new sizes (120 by 110): every station, ring and prop spacing guard passes, and cafe plots don't overlap the square or each other.
- [ ] **cloud** `worldscan.mjs` (after #2992): no new floating, seam or clipping rows on the square, the gardens, the streets or the cafes compared with today's scan.
- [ ] Studio: spawn points and the faster walk zone (#2706) cover the new floor.
- [ ] Studio: the Cat Cannon, its pad and ring, and every flight's start look right. No station hides another from the spawn or the cannon.
- [ ] Studio: each station opens from its ring: Spin Wheel, Golden Fish Market, Codes, Mystery Market, Day Cart, night dealer, Bellhop, leaderboards, Thank You board, Rally boards, pity sign.
- [ ] Studio: all 8 cafes. Plot claiming, passages, signs, doors and the safe zone edge work after the cafes move back.
- [ ] Studio: paths to every area and the side arches, street ends, town ground. Nothing floats or sinks at the new edges.
- [ ] Studio: tutorial ring and arrow, bag-cat marker, townsfolk cats, effects and event zones, and the music zone on the square.
- [ ] Studio: the intro's square, stations and cannon shots are still framed.
- [ ] Studio: a full walk on the phone emulator and with a gamepad. Stress check with 8 players on the square: server heartbeat 55 or more.

## Order

Cloud rows run on each PR as it opens. Studio rows go to Laptop-Tester after merge, before the Saturday publish.
Results go in a dated report in `docs/playtests/`, and problems become issues under each parent.
