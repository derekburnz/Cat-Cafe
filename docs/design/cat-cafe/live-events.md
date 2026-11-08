# Cafe Events: owner-run live events (#2485)

Status: specced by the game-designer thread, 2026-11-08. Parent #2483. Builds: Gameplay-Engineer #2486, UI-Engineer #2487, Tools-Agent and Model-Agent #2488. Research: Research-Agent's live-events-2026-11-08.md in Cat-cafe-library.

Derek2, 2026-11-08: he wants owner-run events like other games' "admin abuse" events, with hourglass countdown icons, built and tested now while the game is small.

## 1. What a Cafe Event is

A Cafe Event is a short, scheduled window when every server gets the same free boosts. Players get the boosts by playing during the window. Nothing in it is sold.

- **A schedule, not a live button.** Each event is one record in the DataStore `CatCafe_Events`. The events workflow (Tools-Agent, #2488) writes it the way `flags.sh` writes LiveFlags, so an event can be scheduled without a publish. Every server reads the store every `EventPollSeconds` (60). Start and end come from `Workspace:GetServerTimeNow()`, the same clock as the day cycle and the pity cat, so every server starts and ends within a second of the others. A server that starts during an event joins it already under way.
- **The record.** `id` (short text, also the analytics key), `title` (at most 24 characters, for example "Cafe Party"), `startsAt` and `endsAt` (UTC seconds), `big` (true for the weekly event), and `effects`, any mix of those in section 2. Each server checks the record against the caps in section 4 when it reads it. A value over its cap is clamped, and the server logs a warning. A record that breaks a hard rule is ignored and logged: it has no end, it lasts longer than `EventMaxSeconds`, it starts in the past by more than its own length, or it overlaps another event.
- **No client remote.** Clients only read. The server puts the current or next event on `ReplicatedStorage` attributes (`EventId`, `EventTitle`, `EventStartsAt`, `EventEndsAt`, `EventEffects` as a short JSON string), and the HUD works out the countdown from the clock. All boosts are applied on the server.
- **Testing in Studio or a private server.** `OwnerTest` gets `event <preset> <minutes>`, which runs an event in that server only, from now for 5 to 120 minutes. Private servers and Studio only. It writes nothing to the DataStore, and its showers claim under `test:` keys (section 2c), so it never touches live servers.

## 2. Effects

### 2a. Stacked days
`days = { lucky, golden, rainbow }`, any of the three. For the window, `Clock.dayKinds` returns the forced kinds in addition to that day's own roll in every server, with the same effects as now (luck-and-rare-moments.md 1g): a Lucky Day's +0.5 Luck and its wave at `LuckyDayWaveLuck`, Golden's gold x3, Rainbow's rainbow x3.

- The day under way at the start gets the kinds from the start. Player Luck and the gold and rainbow multipliers apply at once, and the next sunrise wave rolls with them.
- Every day whose sunrise falls inside the window has them all day.
- The day under way at the end keeps them until its dusk, at most about 5 minutes past the end. The end time shown is still the event's.

### 2b. Money boost
`money = 2` (at most `EventMoneyMax`, 2). It multiplies the cafe's earnings last, after the money pass, the same way the pass multiplies after a rainbow cat's x2 (economy-ladder.md 6a, rainbow-coat.md). The best case is a rainbow cat with the 4x pass during an event, which earns x16 for the window. This was Derek's rule for rainbow: everything multiplies, with no highest-wins rule.

- **It counts:** money from working cats, including customers' tips, rich tips and the tip jar.
- **It doesn't count:** offline income, cat sales, prizes (the Index, quests, the Rally, codes, gifts), golden fish and gold fish. Leaving those out keeps the boost a reason to play during the window and keeps prizes at their tuned values.
- It lasts only as long as the window, at most `EventMoneyMaxSeconds` (7200).
- **Pace.** One 2-hour x2 window a week is worth at most 2 extra hours of income for a player who plays the whole window. Gameplay adds a Pace case with one 2-hour x2 event in the run. That case must still keep a single sitting to Tier 5 within the 9 to 14 hour band (economy-ladder.md §3 v4). If it doesn't, the window gets shorter, not the multiplier smaller.

### 2c. Rare showers
`showers = { count, gapSeconds, firstAfter }`. Shower cats are pity cats on their own slots, `event:<id>:<n>`. Each one spawns in every server at once, and the first player anywhere to catch it gets it, claimed through the same MemoryStore claim and `Pity` topic as the pity cat (luck-and-rare-moments.md 1h). One catch game-wide, so rares stay rare.

- **Which cats.** The odd showers (1st, 3rd, and so on) are a Legendary with a rainbow coat. The even showers are a Mythical whose coat rolls gold and rainbow as a normal stray. The cat is picked from the slot seed, as `Pity.pick` does.
- **Which area.** Equal weights over the five areas (`EventShowerAreaWeights`, 20 each), not the pity cat's tilt toward the high areas. That way a new player in the Alleyway has a fair shot at some of them. The banner adds "(opens at Tier 4)" for areas the player can't reach yet, as the pity banner does.
- **Timing.** The first shower comes `firstAfter` into the window, then one every `gapSeconds`. A shower that falls at night spawns at the next sunrise (nights are 70 s). A shower cat stays until dusk, like a pity cat. Showers due after the end don't spawn.
- **Defaults** for a 2-hour event: 8 showers, the first 10 minutes in and then every 15 minutes (at 10, 25, 40, 55, 70, 85, 100 and 115 minutes). That makes 4 Rainbow Legendaries and 4 Mythicals.
- The normal pity clock runs on as it does now. Shower cats don't restart it (luck-and-rare-moments.md 1i), and a pity cat that falls in the window spawns as usual.
- Announcements reuse the pity banner and sound. The wording is "Event cat! A Mythical appeared in the Woods!", and "Caught by Sam" follows.

### 2d. Luck boost
`luck = 0.5` (at most `EventLuckMax`, 1.0). It is added to every player's Luck in every server for the window and shows on the Luck chip as "Cafe Party +0.5". Total Luck still stops at `LuckMax` (x3). With a stacked Lucky Day the event gives +1.0 in all, so a player's Luck runs from x2.0 with no statue to x3 at the cap. Food cards and the Fish Market odds card show the odds with the event Luck in them, as they do for any Luck.

### 2e. Event reward
`reward = { cosmeticId }`. Any player who secures at least one cat during the window gets two things:
- **The badge** "Cafe Party Guest", once per account. The same badge serves every event, so no new badge is needed each week.
- **The event's free cosmetic**, a decor piece made for that event. The first is the "Party Bunting" (`Decor_PartyBunting`, Model-Agent, #2488).

The reward pops up on the secure, as other prizes do. The piece is free and can't be sold or traded for Robux. Since #2534 (2026-11-08), the Party Bunting is a Rare decoration with the Rare crate bonus (+4% money while in use), the same as the Rare pass pieces. Like every Rare piece, it can't be traded. A test event (`OwnerTest`) pays its reward only in Studio or to an owner.

**Rewards come back (Derek2, 2026-11-08: "free event rewards can come back later but no need to really give limited items").** No event reward is limited. Each event's cosmetic returns at a later event, no sooner than 4 weeks after it was last given, so a player who missed it can still get it. A player who already has it gets the badge only, plus a small coin gift (`EventRepeatGiftIncomeMinutes`, 10 minutes of income). The build stores each reward by `cosmeticId`.

## 3. What players see

- **Countdown, from T-3h** (`EventCountdownSeconds` 10800):
  - A Town Square board, `CatCafe_Square_EventBoard`, with an hourglass frame, beside the pity sign (Model-Agent #2488). It reads "Cafe Party in 2:59:10", then the effects, one line each: "x2 cafe earnings", "8 rare cat showers", "Lucky, Golden and Rainbow Day", "+0.5 Luck", "Free Party Bunting".
  - A small hourglass chip on the HUD by the day clock, "Cafe Party in 2:59". It shows the hours until the last hour, then minutes and seconds.
- **Start.** A banner, "Cafe Party! x2 cafe earnings and rare cat showers until 17:00". The end time shows in the player's local time, from `os.date` on the client. The chip turns gold: "Cafe Party · ends in 1:59:40 · next shower 9:12".
- **The end time always shows**, on the chip, the board and the banner. An event is never extended once it has started. If it has to end early, for a bug, the chip says "Cafe Party ended early". Everyone who already qualified keeps the reward, and the reward is granted to everyone who was in the window when it ended.
- **What's New.** One line from T-24h: "Saturday 15:00 UTC: Cafe Party, x2 cafe earnings and rare cat showers!".
- **After.** "Thanks for coming! See you next Saturday" on the board for an hour, and only if another event is actually scheduled. Otherwise it reads "Thanks for coming!".
- **Reduce Motion** skips the board's sand animation and the chip's glow.

The icon swaps ("3 HOURS", "NOW", "NEW UPDATE!"), the Creator Hub Experience Event page, the group post and the board's code are Tools-Agent's checklist in #2488. The icon variants go up early so moderation is done before the day.

## 4. Numbers and caps (Config)

| Config | Value | What it does |
|---|---|---|
| `EventPollSeconds` | 60 | how often each server reads `CatCafe_Events` |
| `EventMinSeconds` / `EventMaxSeconds` | 300 / 7200 | shortest and longest window |
| `EventMoneyMax` | 2 | the money boost's cap |
| `EventMoneyMaxSeconds` | 7200 | longest money window |
| `EventLuckMax` | 1.0 | the Luck boost's cap (default 0.5); total Luck still at most `LuckMax` 3 |
| `EventShowerMax` | 12 | most showers in one event |
| `EventShowerGapMinSeconds` | 300 | shortest gap between showers |
| `EventShowerDefaults` | count 8, gap 900, firstAfter 600 | the 2-hour preset |
| `EventShowerAreaWeights` | 20 each | the five areas, equal |
| `EventCountdownSeconds` | 10800 | the countdown shows from T-3h |
| `EventRepeatGiftIncomeMinutes` | 10 | the coin gift for a player who already owns the event's cosmetic |
| `EventBigMinGapSeconds` | 518400 | 6 days: the workflow refuses a second `big` event inside this |

Server safety: shower cats are one per slot, at most one new shower every 5 minutes, and each one goes at dusk, so a server never holds more than two at once. The shared strays, traps and waves are unchanged apart from the stacked days. The DataStore read is one call a minute per server.

## 5. Cadence

- **The big event:** once a week, on Saturday from 15:00 to 17:00 UTC. That is 7 am Pacific, 10 am Eastern, 3 pm London and 4 pm Central Europe in winter, before the 19:00 UTC weekend peak. It starts about an hour before the weekly Saturday update goes live, at about 16:00 UTC. The default preset is 2 hours with all five effects.
- **Small events** (`big = false`) fill quiet weeks. One is a stacked day, or a +0.5 Luck hour, with no money boost and at most 3 showers. They have no weekly limit, but never two in one day.
- The Rescue Rally weekend runs alongside. The event doesn't change Rally points or prizes.

## 6. Rules (young audience, studio rules)

- **Free for everyone.** Nothing is sold in the event: no event-only products, no paid skips, no "buy now" pop-ups during the window, and no store prompts tied to the banner or the board. The store and Robux prices are unchanged (Derek's rule that nothing tied to the store or Robux changes without his OK).
- **Countdowns only for real events.** The chip and board show a countdown only for a stored, scheduled event. Nothing counts down to a fake deadline, and no "last chance" wording is used.
- **The end time always shows**, and an event that has started is never extended (section 3).
- **No limited items.** Free rewards come back at later events (2e), and nothing paid is limited.
- **Monetization-Agent's policy check (on #2486, passed with conditions):**
  - **No copy advertises the stack.** Event text always says "x2 cafe earnings". Never "x16", "x8" or a pass named next to the event, on the board, chip, banner, What's New, the icon, the group post or the Experience Event page.
  - **No purchase prompts at all during the window.** That means no store pop-ups or pass prompts from anywhere, not just the event's own UI. The store stays open for a player who walks in or taps it.
  - **Odds cards show the boosted odds.** Food cards and the Fish Market odds card include event Luck and stacked-day effects while they apply.
  - **Tradeable decor is fine** because rewards come back at later events (2e), so a traded piece is never a one-time item.
- Players under 13 get no notification prompts from the event. The Experience Event RSVP is Roblox's own and follows Roblox's rules.

## 7. Analytics

- `event_join` (event id, `GetJoinData` event id if any, join source).
- `event_reward` (event id, first badge or not).
- `event_shower` (event id, slot, area, kind, secured or expired, servers that claimed).
- `event_money` (event id, coins earned from the boost, per player bucket).

Research-Agent's measures: first_hour by join source, and D1 of event joiners against everyone else.

## 8. Test plan

1. **Studio.** `OwnerTest event full 5` runs every effect in a 5-minute window. Check the stacked days, x2 on tips but not on sales or prizes, Luck on the chip and the food cards (capped at x3), 2 or 3 showers at 1-minute gaps (the test preset), the banner, the chip, the board and the reward on a secure.
2. **Live test event.** Use a quiet weekday hour: a 20-minute small event with stacked days and 3 Mythical showers. Check that two servers start within a second of each other, that a shower caught in server A puffs away in server B, and that the board and chip agree in both.
3. **Dress rehearsal.** One weekday before the first Saturday, run the full preset for 30 minutes with the countdown from T-3h, the banner, the icon swap and the What's New line.
4. **Then the first real Saturday.** Watch it in the live console. A check afterwards compares coins earned to the Pace case.

## 9. QA checks

1. With no event stored, no chip, board countdown or banner shows anywhere.
2. A stored event shows the same countdown to the second in two servers from T-3h, and both start within a second of each other.
3. During the window, tips earn x2 and stack with the 4x pass (x8 on a plain cat, x16 on a rainbow cat). Offline income, sales, prizes and golden fish are unchanged.
4. Luck shows "Cafe Party +0.5" and never goes over x3.
5. Showers spawn on schedule, one cat game-wide each, alternating Rainbow Legendary and Mythical. A shower due at night spawns at sunrise. None spawns after the end.
6. Securing any cat in the window gives the badge (once) and the Party Bunting. Securing one after the end gives nothing.
7. A record over its caps is clamped and logged. One with no end, longer than 2 hours, or overlapping another event is ignored and logged.
8. `OwnerTest event` works only in Studio and private servers, and never reaches live servers.
9. Nothing in the store changes, and no purchase prompt opens anywhere during the window. No event text names a stacked multiplier above x2.
