# Trading from Tier 3 (F102)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-30 00:23: "Add trading allowed but for now lock it after Tier 3 (can turn off tier requirement for testing) make sure its secure and not possible to scam people copy other trade menu's from popular roblox games if needed". His release rule of 2026-11-01 22:59 puts it before release, last in the build order because it needs the most safety work.

The layout follows the trade menus players already know from the big pet games: two offer grids side by side, Ready then a countdown, then a confirm screen. On top of that we add the things that stop the usual scams on young players: any change resets both sides, locked cats cannot be offered, every cat shows what it would earn for you, and a lopsided trade gets a warning before the last press.

## 1. What can be traded

- **Cats only, at first.** Any cat the player owns, with its rarity, coat (base, gold or rainbow), charm and level. Up to TradeMaxCats (9) on each side.
- **Never:** coins, potions, food, spins or golden crates (golden fish join in §1d and non-golden crates in §1c, #2745), and never exclusive cats (the Bellhop Cat, shop cats and anything bought with Robux). So nothing in a trade can be bought with Robux, and there is no way to turn Robux or coins into another player's cats. Decor joined on 2026-11-05 (section 1b).
- **Locked cats cannot be offered.** Gold, rainbow, Legendary and Mythical cats arrive locked (F62), so a player has to unlock a good cat on its own card, outside the trade window, before they can trade it. That one step stops most rushed giveaways.
- A traded cat keeps its rarity, coat, charm, level and rescued flag. Its custom name goes back to its kind's name. It arrives locked if it is gold, rainbow, Legendary or Mythical, and it counts as found in the new owner's Index pages (collection, gold and rainbow; source "trade"), so it can fill milestones, but it pays no golden fish, so passing cats back and forth cannot farm fish.
- **Why traded cats count for the Index** (decided 2026-11-02 after the #854 security review): in the big pet games a traded pet fills the index, and that is a large part of why players trade, so we do the same. It does mean a group of friends can lend each other cats to fill their Index pages, Gold and Rainbow tabs and claim those milestones. We accept that: it is playing together, every milestone pays once per player, nothing in it is sold for Robux, the luck rewards are capped (GoldLuckMax, RainbowLuckMax), and TradesPerDay (50) with TradeMaxCats (9) bounds how fast it goes. If the ads week shows Index milestones being claimed far faster by traders than by catchers, the fix is a hold time before a traded cat counts, not taking trades out of the Index.
- **Nothing pays per trade.** `stats.trades` is for the trade log and analytics only. No quest, achievement, milestone or prize may ever count trades, because two friends can swap one cat back and forth.

### 1b. Decor joins (#1574)

Derek, 2026-11-05 (Set 6 Q10): "Trading from Tier 3: cats and decor, with a countdown". So decor joins trades now.

- **Which decor.** Any crate decor or lawn piece the player owns. Saves hold decor as owned or not, with no counts, so each piece is one item. Never exclusive or Robux decor (pass decor, shop exclusives), never Index prize decor, which is tied to its milestone, and never the free Tier 2 and Tier 3 lawn gifts.
- **Placed pieces can be offered.** Since #1544 Equip Best places the lawn and EquipBestDecor places decor, so nobody places a piece by hand. At the swap the piece leaves the giver and their Equip Best fills the spot from what's left. The receiver's piece lands placed by their own Equip Best.
- **Already owned.** A piece the partner already owns can't be added. The grid shows it greyed with "They already have this", so nothing in a trade is ever wasted.
- **Limits.** Up to `TradeMaxDecor` (9) decor on each side, beside the 9 cats. Legendary and up decor arrives locked like cats (F62), and must be unlocked on its own card before it can be offered.
- **What shows.** Each piece shows its rarity and tip bonus. The lopsided warning (section 3) counts decor at its bonus value next to the cats' rates.
- **Index.** A traded piece counts as found on the new owner's Decor Index page (source `trade`), as for cats, and pays no golden fish.
- **Countdown, safety and log** as for cats: any change resets both Ready presses, and the vault (section 4) holds both sides' decor too. Review-Agent re-runs the security review on the decor change before it ships.
- Contracts: Config `TradeMaxDecor` 9. A trade offer gains `decor: { string }` (piece ids), and the server checks that the giver owns each piece, that it's tradeable and that the receiver doesn't own it, again at the swap. The trade log gains a decor list. QA: a placed piece swaps and both sides' Equip Best refills, a piece the partner owns can't be added, an Index prize piece can't be offered, a two-sided cat-and-decor trade arrives complete on both sides, and a disconnect mid-trade returns everything.

### 1c. Unopened crates join (#2745)

Derek2, 2026-11-09: "create an issue to start doing research on implementing golden fish, and unopened crates to trading". The research and recommendation are in #2745. Derek2 gave a standing yes on 2026-11-10 ("you have my yes here for anything needed from now on"). Crates ship first, then golden fish (§1d) behind their own switch.

- **Which crates.** Any banked crate whose Catalog row has `golden = false`: the zone crates, the Classic Crate and the Rally Crate.
  - **Never golden crates.** Golden crates are never sold; they come only from Index prizes, the Lost and Found and similar one-off rewards, so trading them would let spare accounts feed a main.
  - **The rule.** `Trade.crateTradable(id)` returns `Catalog.getCrate(id) ~= nil and not def.golden`.
- **Offers.** An offer gains `crates: { [crateId]: count }`, up to `TradeMaxCrateKinds` (6) crate kinds and `TradeMaxCrates` (20) crates in all on each side.
  - The server checks that each count is a whole number of at least 1 and at most the giver's banked count, on every change and again at the swap.
- **Area gate.** A crate whose area the partner hasn't opened yet (`Crates.openBlocker` for the partner's tier) can't be added. It shows greyed with "They haven't reached the Desert yet", the same way "They already have this" works for decor.
- **Freeze.** While a player is in an open trade, opening a crate that's on offer is refused ("This crate is in a trade").
- **What doesn't travel.** Crate luck (`crateLuck`) and pity stay with each player. A received crate opens with the receiver's luck. Opening a duplicate refunds fish through the normal path.
- **Window.** A Crates tab sits beside Cats and Decor under the grid. A tile shows the crate's art and its count ("x3").
  - Tapping adds one; a long press opens a 1 to max picker.
  - The offer tile shows the count offered.
  - Any change resets both Ready presses, as for cats.
- **Value for the lopsided warning.** A crate counts as its expected piece value, rounded to one decimal: the sum over its odds of chance × `PIECE_VALUE` by rarity. Gameplay computes it once per crate at load.
- **Log and vault.**
  - `RecordSide` gains `crates: { [string]: number }?` (nil in older records means none).
  - Log entries gain `gaveCrates` and `gotCrates`, and `Trade.sanitizeLog` keeps them.
  - Applying a trade subtracts first, then adds, through the same `tradeIds` check.
- **Live switch.** `CatCafe_Flags.tradeCrates` (default true) turns the Crates tab off live without stopping cat trades.

### 1d. Golden fish join, after crates (#2745)

- **The amount.** An offer gains `fish: number`, a whole number from 0 to the giver's balance and at most `TradeMaxFish` (200) a side.
  - The server refuses anything negative, fractional, NaN or infinite, or over the cap or the balance, on every change and again at the swap.
- **Daily cap.** A player can receive at most `TradeFishPerDay` (400) a game day across all trades. The trade window shows the receiver's room left ("They can get 150 more today"), and an offer above it is refused.
- **Freeze.** While a player is in an open trade, every golden fish spend is refused with "Finish your trade first": Market buys, perks, crate buys and spa slots. All spends go through one helper, `GoldenFish.spend`, which checks this.
- **Doesn't count for progress.** Received fish don't count toward `lifetimeGoldenFish`, leaderboards, quests or milestones. Nothing pays per trade (§1).
- **Window.** A fish row sits under each 3 × 3 grid with the 🐟 icon and the amount. Your own row has − and + buttons and 10, 50 and Max (up to the cap and the partner's room left). There's no text box. Any change resets both Ready presses.
- **Value for the lopsided warning.** 40 fish count as 3 (one Rare), so 1 fish counts as 0.075.
- **Log and vault.**
  - `RecordSide` gains `fish: number?`.
  - Log entries gain `gaveFish` and `gotFish`.
  - `stats.tradesToday` gains `fishIn`.
- **Live switch.** `CatCafe_Flags.tradeFish` (default **false**) is turned on only after QA and Review-Agent's security review pass, since fish are the first item traded as an amount rather than a single thing.
- **QA, on top of §7:**
  - Fired offers with −10, 0.5, NaN, inf or balance + 1 fish are refused.
  - A fish spend during an open trade is refused.
  - A forced shutdown mid-swap leaves both fish balances exact.
  - The 400-a-day cap holds across rejoins and servers.
  - Received fish don't change `lifetimeGoldenFish`.

## 2. Who can trade, and where

- **Both players at Tier 3 or higher** (`Config.TradeMinTier` 3). The HUD Trade button shows from that live minimum, so a lowered test server shows it too. For testing, `CatCafeDebug:Invoke("tradeMinTier", 0)` lowers it in that server only.
- **Both in a safe zone:** the town or any camp. Not while carrying a cat, in a catch or rescue, in a flight or in the middle of a big pull.
- **Trade requests** setting: Everyone (default), Friends only or Off.
- **One trade at a time** per player, at most TradesPerDay (50), and TradeCooldownSeconds (10) between trades.

## 3. How a trade goes

1. **Ask.** Press the Trade button in the HUD icon row (with the full HUD, once trading is running in the server; it shows from Tier 3 and stays hidden below it). It opens a list of the other players in the server, each with their name, their tier and a Trade button. For 60 seconds after you press it, however the ask ends, the button reads "Asked" on your screen; it reads "Busy" while that player is trading, and "Tier 3 needed" if they are under the minimum. Tapping a head tag does nothing. They get a card: "Sam wants to trade" with Accept and Decline, for 20 seconds. Declined or timed out, Sam cannot ask that player again for 60 seconds.
2. **Offer.** The trade window opens for both: your offer on the left, theirs on the right, each a 3 x 3 grid. Your cats list sits below, sorted by rarity, with locked cats greyed and marked "Unlock on its card to trade". Every tile shows the cat's picture, rarity colour, coat border, level, buff chips and **what it would earn in your cafe** ("+24/s for you"). Under each grid a total: "Their cats: +240/s in your cafe" and "Your cats: 180/s now".
3. **Any change resets both.** Adding or taking away a cat clears both players' Ready, stops any countdown, flashes the changed tile yellow for 2 seconds and shows "Changed!" over that side. Nobody can swap a cat out at the last moment unseen.
4. **Ready, then a countdown.** When both press Ready, a TradeCountdownSeconds (5) countdown runs on both screens. Any change cancels it.
5. **Confirm screen.** After the countdown both see the summary: "You give" and "You get" in big pictures with names and rarities.
   - **Lopsided warning.** If what you give is worth at least TradeLopsidedRatio (3) times what you get (by the Collector's values: Common 1, Rare 3, Epic 8, Legendary 20, Mythical 50, gold x3, rainbow x10), a red line says "You're giving much more than you get. Are you sure?" and Confirm stays off for TradeConfirmWaitSeconds (2), shown as "Confirm (2)". The server refuses a Confirm sent sooner too.
   - **Gift.** If you get nothing back, it says "You get nothing back" in red, with the same 2 second wait. Gifts to friends are allowed.
6. **Both press Confirm** and the server makes the trade. Both see "Trade done!" with the cats flying into their cat room, and a short chime.

Leaving the server, walking out of the safe zone or either player's Cancel ends the trade with nothing moved.

## 4. Safety on the server

- **The client only asks.** It sends which cat to add or take away, Ready and Confirm. The server holds the trade, its two offers and a version number that goes up on every change.
- **Ready and Confirm carry the version.** A Ready or Confirm for an older version is refused, so a press can never land on an offer the player has not seen.
- **Checked again at the end.** Just before the swap the server checks that both players are still in the server and in safe zones, that every cat is still owned, unlocked, not exclusive and in no other trade, and that both versions match.
- **Nothing doubles and nothing vanishes,** even if the server shuts down mid-trade:
  1. The server writes the trade (both players, both sides' full cat data, state "pending") to the `CatCafe_Trades` DataStore and a pointer to it under each player's id in `CatCafe_TradePending`.
  2. It applies both sides to both profiles in memory and adds the trade id to each profile's `tradeIds` (the last 100 applied trade ids) and its `tradeLog`.
  3. It saves both profiles at once, then marks the trade "done" and clears the two pointers.
  4. On every profile load, if a pointer is still there, the server finishes that player's side from the stored trade unless the profile's `tradeIds` already has it, then clears the pointer. `tradeIds` is the check, not the 20 entry `tradeLog`, so a finished trade never pays twice.
  The reviewer checks this path and QA runs it with a forced shutdown between steps 2 and 3.
- **Rate limits:** 5 trade calls a second per player, one request out at a time.
- **A kill switch.** `CatCafe_Flags.trading`, a DataStore flag every server reads every 60 seconds, turns trading off everywhere without a publish if something goes wrong. With it off, the player list says "Trading is resting for now. Try again later!" and every Trade button in it is off.
- **No player text.** There is no message box in the trade window; players use Roblox chat, which Roblox filters.
- **No logs of who.** Nothing prints user ids, names or trade contents to the output, since the repo and its CI logs are public. Analytics gets counts only.

## 5. The trade log

Settings has a Trades page with the last 20 trades: when, with whom (their display name at the time) and both sides as pictures. It helps a player or a parent see what happened.

## 6. Contracts

- Save: `tradeIds` (the last 100 applied trade ids, the no-double-pay check), `tradeLog` (up to 20 entries of `{ id, at, partnerName, gave: {CatSummary}, got: {CatSummary} }`), `settings.tradeRequests` (`"everyone"`, `"friends"` or `"off"`), `stats.trades`, `stats.tradesToday = { day, count }`.
- Config: `TradeMinTier` 3, `TradeMaxCats` 9, `TradeCountdownSeconds` 5, `TradeLopsidedRatio` 3, `TradeRequestSeconds` 20, `TradeReaskSeconds` 60, `TradeCooldownSeconds` 10, `TradeConfirmWaitSeconds` 2, `TradesPerDay` 50, `TradeFlagCheckSeconds` 60.
- Remotes, client to server: `TradeRequest(userId)`, `TradeRespond(requestId, accept)`, `TradeOffer(tradeId, "add" | "remove", catUid)`, `TradeReady(tradeId, version, ready)`, `TradeConfirm(tradeId, version)`, `TradeCancel(tradeId)`. Server to client: `TradeAsked`, `TradeState` (both offers with tile info, version, Ready and countdown state, the totals and the lopsided flag), `TradeDone`, `TradeEnded(reason)`.
- DataStores: `CatCafe_Trades`, `CatCafe_TradePending`, `CatCafe_Flags`.
- Analytics: `trade_done` with the number of cats each side and the rarities, never who.
- Who builds: Gameplay-Engineer (TradeService, saves, the pending path), UI-Engineer (request card, window, confirm screen, log, setting), Sound-Agent (the countdown ticks and the done chime), VFX-Agent (cats flying to the cat room), Review-Agent (a security review against `remote-security-checklist` before it goes live), QA-Planner (the checks below with two accounts).

## 7. QA checks

1. Two Tier 2 accounts cannot trade; after `tradeMinTier 0` in that server they can.
2. A locked cat, an exclusive cat and a cat already in another trade cannot be added.
3. Adding a cat during the countdown stops it and clears both Ready.
4. A Confirm sent with an old version number is refused and nothing moves.
5. Selling a cat that is in an open trade is refused, or ends the trade before the sale.
6. A Mythical for one Common shows the lopsided warning; a gift shows "You get nothing back"; Confirm waits 2 seconds in both, and a Confirm fired at the server inside those 2 seconds is refused.
7. Forcing a server shutdown after step 2 of section 4 and rejoining both accounts leaves each cat with exactly one owner.
8. With the kill switch on, new trades are refused within 60 seconds in a running server.
9. Trade requests set to Friends only refuse a request from a non-friend.
10. The output has no user id, name or cat list from a trade.
11. A traded cat new to the receiver shows in their Index (and Gold or Rainbow tab) and pays no golden fish.
12. Ten trades of one cat back and forth between two accounts change nothing but `stats.trades` and the trade logs: no fish, no quest progress, no prize.
