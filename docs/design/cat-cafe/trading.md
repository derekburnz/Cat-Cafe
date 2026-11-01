# Trading from Tier 3 (F102)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-30 00:23: "Add trading allowed but for now lock it after Tier 3 (can turn off tier requirement for testing) make sure its secure and not possible to scam people copy other trade menu's from popular roblox games if needed". His release rule of 2026-11-01 22:59 puts it before release, last in the build order because it needs the most safety work.

The layout follows the trade menus players already know from the big pet games: two offer grids side by side, Ready then a countdown, then a confirm screen. On top of that we add the things that stop the usual scams on young players: any change resets both sides, locked cats cannot be offered, every cat shows what it would earn for you, and a lopsided trade gets a warning before the last press.

## 1. What can be traded

- **Cats only, at first.** Any cat the player owns, with its rarity, coat (base, gold or rainbow), charm and level. Up to TradeMaxCats (9) on each side.
- **Never:** coins, golden fish, potions, food, crates, spins or decor, and never exclusive cats (the Bellhop Cat, shop cats and anything bought with Robux). So nothing in a trade can be bought with Robux, and there is no way to turn Robux or coins into another player's cats. Decor can join later, once trades have run clean for a while.
- **Locked cats cannot be offered.** Gold, rainbow, Legendary and Mythical cats arrive locked (F62), so a player has to unlock a good cat on its own card, outside the trade window, before they can trade it. That one step stops most rushed giveaways.
- A traded cat keeps its rarity, coat, charm, level and rescued flag. Its custom name goes back to its kind's name. It arrives locked if it is gold, rainbow, Legendary or Mythical, and it counts as found in the new owner's Index (source "trade").

## 2. Who can trade, and where

- **Both players at Tier 3 or higher** (`Config.TradeMinTier` 3). For testing, `CatCafeDebug:Invoke("tradeMinTier", 0)` lowers it in that server only.
- **Both in a safe zone:** the town or any camp. Not while carrying a cat, in a catch or rescue, in a flight or in the middle of a big pull.
- **Trade requests** setting: Everyone (default), Friends only or Off.
- **One trade at a time** per player, at most TradesPerDay (50), and TradeCooldownSeconds (10) between trades.

## 3. How a trade goes

1. **Ask.** Tap another player's head tag, or open the Trade button in the menu, which lists the players in the server who can trade. They get a card: "Sam wants to trade" with Accept and Decline, for 20 seconds. Declined or timed out, Sam cannot ask that player again for 60 seconds.
2. **Offer.** The trade window opens for both: your offer on the left, theirs on the right, each a 3 x 3 grid. Your cats list sits below, sorted by rarity, with locked cats greyed and marked "Unlock on its card to trade". Every tile shows the cat's picture, rarity colour, coat border, level, buff chips and **what it would earn in your cafe** ("+24/s for you"). Under each grid a total: "Their cats: +240/s in your cafe" and "Your cats: 180/s now".
3. **Any change resets both.** Adding or taking away a cat clears both players' Ready, stops any countdown, flashes the changed tile yellow for 2 seconds and shows "Changed!" over that side. Nobody can swap a cat out at the last moment unseen.
4. **Ready, then a countdown.** When both press Ready, a TradeCountdownSeconds (5) countdown runs on both screens. Any change cancels it.
5. **Confirm screen.** After the countdown both see the summary: "You give" and "You get" in big pictures with names and rarities.
   - **Lopsided warning.** If what you give is worth at least TradeLopsidedRatio (3) times what you get (by the Collector's values: Common 1, Rare 3, Epic 8, Legendary 20, Mythical 50, gold x3, rainbow x10), a red line says "You're giving much more than you get. Are you sure?" and Confirm stays off for 2 seconds.
   - **Gift.** If you get nothing back, it says "You get nothing back" in red, with the same 2 second wait. Gifts to friends are allowed.
6. **Both press Confirm** and the server makes the trade. Both see "Trade done!" with the cats flying into their cat room, and a short chime.

Leaving the server, walking out of the safe zone or either player's Cancel ends the trade with nothing moved.

## 4. Safety on the server

- **The client only asks.** It sends which cat to add or take away, Ready and Confirm. The server holds the trade, its two offers and a version number that goes up on every change.
- **Ready and Confirm carry the version.** A Ready or Confirm for an older version is refused, so a press can never land on an offer the player has not seen.
- **Checked again at the end.** Just before the swap the server checks that both players are still in the server and in safe zones, that every cat is still owned, unlocked, not exclusive and in no other trade, and that both versions match.
- **Nothing doubles and nothing vanishes,** even if the server shuts down mid-trade:
  1. The server writes the trade (both players, both sides' full cat data, state "pending") to the `CatCafe_Trades` DataStore and a pointer to it under each player's id in `CatCafe_TradePending`.
  2. It applies both sides to both profiles in memory and adds the trade id to each profile's `tradeLog`.
  3. It saves both profiles at once, then marks the trade "done" and clears the two pointers.
  4. On every profile load, if a pointer is still there, the server finishes that player's side from the stored trade unless the profile's `tradeLog` already has it, then clears the pointer.
  The reviewer checks this path and QA runs it with a forced shutdown between steps 2 and 3.
- **Rate limits:** 5 trade calls a second per player, one request out at a time.
- **A kill switch.** `CatCafe_Flags.trading`, a DataStore flag every server reads every 60 seconds, turns trading off everywhere without a publish if something goes wrong. With it off, the Trade button says "Trading is resting for now".
- **No player text.** There is no message box in the trade window; players use Roblox chat, which Roblox filters.
- **No logs of who.** Nothing prints user ids, names or trade contents to the output, since the repo and its CI logs are public. Analytics gets counts only.

## 5. The trade log

Settings has a Trades page with the last 20 trades: when, with whom (their display name at the time) and both sides as pictures. It helps a player or a parent see what happened.

## 6. Contracts

- Save: `tradeLog` (up to 20 entries of `{ id, at, partnerName, gave: {CatSummary}, got: {CatSummary} }`), `settings.tradeRequests` (`"everyone"`, `"friends"` or `"off"`), `stats.trades`, `stats.tradesToday = { day, count }`.
- Config: `TradeMinTier` 3, `TradeMaxCats` 9, `TradeCountdownSeconds` 5, `TradeLopsidedRatio` 3, `TradeRequestSeconds` 20, `TradeReaskSeconds` 60, `TradeCooldownSeconds` 10, `TradesPerDay` 50, `TradeFlagCheckSeconds` 60.
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
6. A Mythical for one Common shows the lopsided warning; a gift shows "You get nothing back"; Confirm waits 2 seconds in both.
7. Forcing a server shutdown after step 2 of section 4 and rejoining both accounts leaves each cat with exactly one owner.
8. With the kill switch on, new trades are refused within 60 seconds in a running server.
9. Trade requests set to Friends only refuse a request from a non-friend.
10. The output has no user id, name or cat list from a trade.
