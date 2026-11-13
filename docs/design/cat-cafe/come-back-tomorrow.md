# Come back tomorrow: a reason before the first session ends (#3772)

Spec by Design-Agent, 2026-11-13, for Growth-Agent's ask. Picks made under Derek's standing OK ("go with your recommendations", 2026-11-13 01:31 UTC). Build: Gameplay-Engineer (server, save, switch) and the UI side (card and lines). Test: Review-QA-Agent.

## 1. Why

Day 1 return is 3.55% (46th percentile, genre middle 8.30%) and day 7 is 0% (3rd percentile), while average playtime is at the 97th percentile. Players like the session and do not come back. Home recommendations weigh play days, so the return is the number that matters most now.

What already exists and stays:
- The recap card at 15 minutes in a first session (`RecapFirstSessionSeconds` 900) with one "Tomorrow" line (`ReturnHook`), and at 40 minutes later.
- The welcome back card on a rejoin with offline earnings and one line.
- The Daily Treat, 7 days, which grows from 300 coins on day 1 to a golden crate on day 7.

What is missing: a first-day player has nothing of their own that waits for them tomorrow, and many leave before the 15 minute recap.

## 2. The change

### 2a. A gift for coming back (new)

- **What:** once per account, on the first join on a later UTC day than the account's first day, the player gets **a golden crate of their best open area** (`highest_golden`, as `Prizes.crateFor` resolves it, banked like any crate).
- **When it pays:** at once on that join, with the welcome back card, no claim button. A player who comes back three days later still gets it: it never expires and nothing is lost by waiting.
- **Who:** accounts whose `telemetry.firstDay` is on or after `Config.ReturnGiftFromDay` (the UTC day number the feature ships), so existing players are not all paid at once. An account with `firstDay` 0 (from before save version 19) never gets it.
- **Save:** `returnGift: boolean`, true once paid. A new save version, because an older server would drop it and pay it again during a rollout.
- **Switch:** `returnGift`, off by default (`LiveFlags.OFF_BY_DEFAULT`). Off, nothing pays and no line names it. Turn it on once no older server is running.
- **Earned, not bought.** Nothing here is sold, and the crate's odds are already shown wherever it is opened.

### 2b. The Tomorrow card (new, first session only)

- **When:** once per account, in the first session, after **8 minutes of play** and after the tutorial, at a calm moment (the recap card's rules: not catching, carrying, in a minigame or a menu, idle for 5 seconds). It is the first-session recap moved earlier and made about tomorrow; the 15 minute recap then does not show in that session.
- **The card:** slides up from the bottom, no dark background, a close button, auto-hides after 12 seconds. Up to three lines, each only when true:
  1. A crate picture and "Come back tomorrow for a golden crate" (only while the gift is due and the switch is on).
  2. "Tomorrow: Daily Treat day 2, 10 golden fish and a spin", the next day's prize from `Catalog.dailyTreat`, when today's treat is claimed. If it is not claimed yet: "Today's Daily Treat is waiting for you" (no button, no arrow).
  3. "Your cafe earns up to $N while you're away", with N = income per second x `OfflineRate` x `OfflineCapSeconds` (the pass values when owned), shortened like every money number.
- **Words:** no countdown, no "don't leave", no "you'll lose", no store link. Settings' "Session recap" toggle hides it too.

### 2c. Lines that already exist

- **Recap card, later sessions:** unchanged.
- **ReturnHook order:** "gift" goes first while the gift is due: recap "Tomorrow: a golden crate for coming back"; join "Welcome back gift: a golden crate!". Then bait, treat and quests as today.

## 3. Not doing (and why)

- **A bigger day 2 Daily Treat:** the ladder already grows to day 7, and making day 2 bigger moves value without telling anyone. The card in 2b tells them instead.
- **Notifications or a login streak that resets:** a streak that breaks is loss framing for a young audience.
- **A timer to the next day:** no countdown pressure.

## 4. Funnel and measure

- `tomorrow_card` with the lines shown (`gift`, `treat`, `offline`) and how long it was up; `return_gift_paid` with the days since the first join.
- Read `returned_next_day` (#3695) and Creator Hub day 1 retention by device for 7 days before and after the switch goes on. Read over at least 300 new players.

## 5. QA

- A fresh account sees the Tomorrow card once at about 8 minutes, after the tutorial and only when idle, and not the 15 minute recap that session.
- Each line shows only when true; the offline number matches Config and the pass.
- Next UTC day: the welcome back card says "Welcome back gift: a golden crate!" and the crate is banked once. A second join that day pays nothing. Two servers during a rollout pay once.
- An account from before `ReturnGiftFromDay` gets no gift and no gift line.
- With `returnGift` off nothing pays and no line names the gift; the card still shows lines 2 and 3.

## 6. As built (2026-11-13, Design-Agent)

- **Gift:** `shared/ReturnGift.luau` and `PlaytimeGiftService`. On the first second a returning player is loaded on a later UTC day than `telemetry.firstDay`, with the switch on and `firstDay >= Config.ReturnGiftFromDay` (20770, 2026-11-13), it marks `codesRedeemed.giftreturn` and then pays `{ crates = { highest_golden = 1 } }` through Payout, with the toast "Welcome back gift! ..." (on `ToastRules.KEEP`) and `return_gift_paid` (value: days since the first day).
- **No save version step** (Gameplay-Engineer's advice): the mark lives in `codesRedeemed`, which every server keeps as it is, as the Saturday update gift's does, so hopping servers during a rollout cannot pay it twice and no restart is needed. The key starts with "gift", so the Store's used codes list leaves it out, and it has no digits, so no update gift key can match it. The switch can go on as soon as the build is live; an older server simply does not pay it.
- **Tomorrow card:** built as the first session's recap card moved from 15 to 8 minutes (`RecapFirstSessionSeconds` 480), with the same calm-moment rules, toggle and auto-hide. Its Tomorrow line reads "Come back tomorrow for a golden crate" while the gift pays tomorrow (`ReturnHook.pick(..., "recap", gift)`, the switch checked in SessionRecapService), and the offline share line is already on the card. Not built: the separate "Today's Daily Treat is waiting for you" line and a `tomorrow_card` event (the recap's own close event already logs it).
- **Join line:** the welcome back card keeps its line; the gift's own toast says what was paid.
- **Alt accounts** could each take one golden crate on their second day. Crates trade only from Tier 3 (`TradeMinTier`), so moving them to a main account takes play on each alt, which keeps it small.
- **Recap timing is not behind the switch:** the 8 minute first-session recap applies to every new account from the build's restart, switch or not.

