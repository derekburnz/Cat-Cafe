# Leaderboards (F98)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-28 17:14: "Also add a leaderboards for like index completion, playtime, highest money per second". His release rule of 2026-11-01 22:59 ("Finish all updates currently queued before release") puts it before release.

Players come back to check their place, and a board in town shows a new player what the game's top end looks like. Nothing on a board is rewarded beyond a small crown, so there is no grind for prizes and nothing to buy.

## 1. The three boards

| board | what it ranks | shown as | windows |
|---|---|---|---|
| **Index** | Index entries found: every normal cat found plus every gold coat found (and the Rainbow coat when F99 lands). Exclusive cats do not count, as in the Index itself. | "68 cats" | All time |
| **Playtime** | Time played, from the server's session clock (`stats.playtimeSeconds` plus the current session) | "41 h 12 m" | All time and This week |
| **Money** | The highest money per second the cafe has reached (`stats.bestRate`) | "12.4K /s" with the HUD's number format | All time and This week |

- **Which money figure.** The cafe's rate with its cats, decor, tier, passes and pal bonus, but without timed potions, Lucky Days or the night pause. So a potion cannot spike the board, and a rich player who stops playing keeps their best. The server keeps `bestRate` as the highest such rate it has computed and updates it on every cafe sync.
- **This week** starts on Monday at 00:00 UTC, the same week as the weekly quests (`Quests.week`). The weekly Playtime board counts time played this week; the weekly Money board counts the best rate reached this week. A new player can be on a weekly board in their first days, which the all-time boards will never allow.
- **Top 50** on each board and window. Ties keep the store's order.

## 2. Where they show

- **In town.** Three standing boards in a row at the edge of the Town Square, facing the Cat Cannon, clear of the paved cross. Model-Agent places them at a `leaderboards` layout point (`CatCafe_Town_LeaderboardRow`, three boards `CatCafe_Town_Leaderboard_Index`, `_Playtime`, `_Money`). Each board is a framed chalkboard on two legs with a painted header icon (book, clock, coin) and the board's name. Its face shows the top 10 of the all-time window: rank, the player's head picture, display name and value. Ranks 1 to 3 have gold, silver and bronze rows.
  - The face swaps between All time and This week every 15 seconds on Playtime and Money, with a small "This week" ribbon while it shows the weekly list.
  - Under the top 10, each player sees their own line on their own screen: "You: #23" when they are in the top 50, else "You: 41 h 12 m" with no rank.
- **In the Index.** A "Top" tab next to Normal and Gold (one tab, three board buttons along its top, the All time and This week switch on the right). It lists the top 50 with the same rows and pins the player's own line at the bottom.
- **The player list.** `leaderstats` keeps its columns, with "Tips/s" renamed "Money/s" per F94's money wording.

## 3. The crown

A player in the top 10 of any all-time board gets a small gold crown:
- next to their name on the boards and in the Top tab;
- on their cafe's name sign, so the street sees it;
- over their head tag in town.

It lasts while they are in the top 10 at the last refresh. It gives nothing else, and the boards never pay prizes.

## 4. How the server keeps them

- **Stores.** One OrderedDataStore per board and window: `CatCafe_LB_Index`, `CatCafe_LB_Playtime`, `CatCafe_LB_Money` and the weekly `CatCafe_LB_Playtime_W<week>` and `CatCafe_LB_Money_W<week>`. Values are whole numbers: entries, minutes played and money per second rounded down. Keys are the player's user id as a string.
- **Writes.** Each player's values are written when they join (after the profile loads), every LeaderboardWriteSeconds (300), on a rank up and when they leave. A write is skipped when the value has not changed since the last write. That keeps a full server of 8 well under the OrderedDataStore write budget.
- **Reads.** Each server reads the top 50 of every board and window every LeaderboardRefreshSeconds (120), spread across the two minutes, and caches the lists with display names and head pictures (names looked up in a batch with `UserService:GetUserInfosByUserIdsAsync` and cached for the server's life). It sends them to clients with `LeaderboardSync`.
- **Studio and tests.** Writes are off in Studio (`RunService:IsStudio()`) and when `Config.LeaderboardWrites` is false, so playtests never land on the live boards. Reads still work, so testers see the real boards.
- **Hidden players.** A short hidden list (cheaters, Derek's test accounts if he wants) lives in the DataStore key `CatCafe_LB_Hidden`, edited with the debug hook `CatCafeDebug:Invoke("leaderboardHide", userId)`. It is never in the repo. Hidden players are dropped from the lists after the read.
- **No logs of who.** Nothing prints user ids or names to the output, since the repo and its CI logs are public.
- **Exploits.** All three values come from the server's own profile and clock. A client never sends a value. `bestRate` is the rate the server itself computed, and the Money write clamps it to `Config.LeaderboardRateMax` (10,000,000) as a safety net against a bad number.

## 5. Contracts

- Save: `stats.bestRate` (number, 0), `stats.weekPlay` (`{ week: number, seconds: number }`), `stats.weekBestRate` (`{ week: number, rate: number }`).
- Config: `LeaderboardWrites` (true), `LeaderboardWriteSeconds` (300), `LeaderboardRefreshSeconds` (120), `LeaderboardSize` (50), `LeaderboardBoardRows` (10), `LeaderboardRateMax` (10,000,000), `LeaderboardCrownRank` (10), `LeaderboardFaceSwapSeconds` (15).
- Remote: `LeaderboardSync` (server to client): `{ boards: { [board]: { allTime: {Row}, week: {Row}? } }, me: { [board]: { rank: number?, value: number } }, week: number }`, where a Row is `{ rank, userId, name, value, crown }`. Sent on join, after each refresh and to one player after their own write.
- Attributes: `Crown` (bool) on the Player and on the plot's name sign.
- Assets: `CatCafe_Town_LeaderboardRow` with the three boards (Model-Agent), the crown icon and the three header icons (UI-Engineer, IconArt).

## 6. QA checks

1. A fresh account plays 6 minutes in a live server; its playtime shows on the weekly Playtime board after the next refresh, and it is not on it in a Studio session.
2. Drinking a Money Potion does not raise the player's Money value; buying a table that raises the base rate does, within one write.
3. The weekly boards start empty at Monday 00:00 UTC and the all-time ones do not.
4. A player in the all-time top 10 shows a crown on the board, the Top tab, their cafe sign and their head tag; it goes at the first refresh after they drop out.
5. A hidden user id disappears from every list at the next refresh.
6. With 8 players in a server, the output shows no DataStore budget warnings over 30 minutes.
7. No line in the server output contains a user id or player name from the boards.
8. On a phone at 844 x 390 the Top tab's rows and the player's own line fit without clipping.
