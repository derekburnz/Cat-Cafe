# Release: badges, the release gate, store timing and the first four weeks (#1934 to #1937)

Status: specced 2026-11-07 by Design-Agent (friend's project), from Derek2's asks the same day: "continue researching and thinking of any changes and additions that might benefit the game to have on release and start implementing them however you suggest", then "go ahead with all and release planning for about 3-5 days from now". Research: Research-Agent's `release-ideas-2026-11-07.md` in the library.

**Release window:** go wide (public, What's New "We're open!") targeted for **Thursday 2026-11-12**, after a short soft launch that needs at least 24 hours of players for the gate in section 2. Set 11 Q4 (Derek2, 2026-11-07): "maybe not tuesday because will do some research on good release days and time but yeah good idea overall". So the soft-launch day and the go-wide day and hour come from Research-Agent's release-timing research (#1956), and the freeze stays Monday 2026-11-09 18:00 UTC. Derek2 decides on the day.

## 1. Roblox badges (#1934)

Badges show on the game page and in a player's inventory. Each one is free to create, up to 5 a day per game (more cost R$100 each), so the 20 below are listed in **creation order**: 5 a day from 2026-11-07 means all 20 exist by 2026-11-10. Builders: Gameplay-Engineer (server awards), Model-Agent (512 x 512 icons, a round cafe-palette badge with one simple picture each), Tools-Agent or Derek (creating them in Creator Hub and putting the ids in Config).

| # | badge (name) | awarded when | day |
|---|---|---|---|
| 1 | Welcome to the Cafe | the tutorial ends (`tutorialStep` 5) | 1 |
| 2 | First Catch | the first stray caught | 1 |
| 3 | Cozy Cafe | Tier 2 | 1 |
| 4 | Grand Opening | roadmap step 8 (first-hour.md §1) | 1 |
| 5 | Purrfect! | the first PURRFECT catch (catch-rework.md §7d) | 1 |
| 6 | Bait Cat | the first bait cat tamed | 2 |
| 7 | Rare Find | the first Epic owned | 2 |
| 8 | Legendary Find | the first Legendary owned | 2 |
| 9 | Mythical Find | the first Mythical owned | 2 |
| 10 | Busy Cafe | Tier 3 | 2 |
| 11 | Famous Cafe | Tier 4 | 3 |
| 12 | Grand Cafe | Tier 5 | 3 |
| 13 | Cat Collector | 25 different cats | 3 |
| 14 | Cat Expert | 50 different cats | 3 |
| 15 | Golden Coat | the first gold cat | 3 |
| 16 | Rainbow Coat | the first rainbow cat | 4 |
| 17 | Page Complete | the first full area page in the Index | 4 |
| 18 | Helping Paw | the first team rescue helped (rescue-rally.md) | 4 |
| 19 | First Trade | the first completed trade | 4 |
| 20 | Purrfect Streak | a Purrfect streak of 5 | 4 |

- **Rules:** awarded by the server only, never for liking, favouriting, buying or inviting, and nothing has a streak that can be lost. Each badge's description is one plain line, for example "Rank your cafe up to Tier 3."
- **Contract:** `Config.Badges = { welcome = 0, firstCatch = 0, ... }`, where 0 means not created yet and is skipped. `BadgeService` awards are wrapped in pcall. A failed award goes into a per-player retry list, tried again at the next qualifying event and on join, and never blocks play. Each player's owned badges are cached once per join with `UserHasBadgeAsync`.
- **Catch-up:** on join, the server checks the profile for every badge the player already qualifies for and awards those quietly, so a badge created after launch still reaches players who earned it. No toast plays for catch-up awards. Live awards get Roblox's own badge notice and nothing extra from us.
- **Funnel:** `badge_awarded` with the badge key and minutes played.
- **QA:** a fresh account gets badges 1 to 5 in its first hour, once each, with no new console errors. An account that already ranked to Tier 3 gets badges 3 and 10 on join. A badge with id 0 is skipped silently.

## 2. The release gate and soft launch (#1935)

Owners: QA-Planner (runs the gate and writes `docs/playtests/2026-11-10-release-gate.md`), Tools-Agent (device and performance captures), Monetization-Agent (reads the funnels). Derek2 makes the go-wide call.

- **Stage 1, private check (2026-11-08 to 11-09):** the full playtest on the device matrix below, on the dev place and then on the live place. Nothing new merges after Monday 2026-11-09 at 18:00 UTC except fixes ("freeze").
- **Stage 2, soft launch (from Tuesday 2026-11-10):** the game goes public with no ads and no outside posts. Only Roblox's own discovery, friends and the group bring players. Read the funnels after 24 to 48 hours.
- **Stage 3, go wide (target Thursday 2026-11-12):** the What's New "We're open!" entry, the launch code, the group post and any outside posts.
- **Pass criteria for going wide** (all from the funnels that already exist):
  1. Tutorial completion (`onboarding_v4` step 5) is **80% or more** of players who load in.
  2. D1 return is **25% or more** on the soft launch's first day of players. The research suggests 30% as a good mark; under 25% means fix first.
  3. The median first session is **10 minutes or more**, and 25% or more of players reach 30 minutes.
  4. Client error rate: no new ClientErrors signature hits more than 1% of sessions, and no server error repeats in more than 1% of servers.
  5. Purchases work: every live pass and product passes its owner test on 2026-11-09.
- **Device matrix** (each passes the first 15 minutes with no new console errors): a low-end Android phone (the lighter phone setting on), an iPhone, an iPad or tablet, a Windows desktop, and console if Derek2 can borrow one (otherwise the console layout in Studio's emulator).
- **Performance marks:** time from load to first move is 20 s or less at the median on phone. Client memory stays under 1.2 GB on the low-end phone over 15 minutes. The server heartbeat stays at 55 Hz or more with 8 players. Tools-Agent records these from Studio and the live developer console.
- If any mark fails, the fix gets an issue labelled `release-blocker`, and the gate re-runs on just that item.

## 3. Store timing guard (#1936)

The research rule is that nothing pushes a paid item at a new player. Today nothing opens the Store or a purchase prompt by itself, and every prompt comes from a tap. This section makes that a tested rule and calms the first 30 minutes. Builders: UI-Engineer (client), Gameplay-Engineer (the play-time value).

- **The rule:** a purchase prompt (`PassShop.prompt` or a product prompt) opens only from a tap on a buy button the player is looking at. A guard in `PassShop.prompt` refuses any call without a tap in the last 2 seconds, and logs `store_guard_blocked` with where the call came from. A unit test covers it.
- **The first 30 minutes of total play** (`stats.playtimeSeconds` plus the session, under 1800):
  - The HUD money pill shows its "x2" icon without a price, and tapping it still opens the Store.
  - No toast, banner, What's New line or goal card mentions a paid item.
  - The Store tile is always there, and the Store itself shows everything as normal when a player opens it.
- **Never, at any play time:** no pop-up Store on join, no "offer ends" countdowns except the real Cafe Pass season end, and no prompt during a catch, a rescue or a cutscene.
- **Free players** can reach every tier, area and cat that isn't shop-only. That's already true, and the guard test lists it as a check, so a future change can't break it quietly.
- **QA:** on a fresh account nothing paid is advertised before 30 minutes, and the money pill gains its price at 30:00. A scripted call to `PassShop.prompt` with no tap is blocked and logged. Every buy button still works.

## 4. The first four weeks (#1937)

Every Saturday from launch gets a small finished drop, built from things that already exist, so no week is a scramble. Monetization-Agent writes each What's New entry (under 60 words) and the codes. Each week's pieces get their own issues and owners by the Wednesday before. The calendar copy for growth goes in `docs/growth/` (Monetization-Agent).

| week | Saturday | the drop | code (coins only, about 10 minutes of income at most) |
|---|---|---|---|
| launch | Thu 11-12 | "We're open!": the Grand Opening roadmap and the new catch | `OPENING` |
| 1 | 11-14 | fixes from the soft launch, plus the first **Rescue Rally weekend** (rescue-rally.md) | `RALLY` |
| 2 | 11-21 | a **Lucky Day** Saturday (luck-and-rare-moments.md) and 3 new decor pieces from the existing crate list | none |
| 3 | 11-28 | the Cafe Pass's Autumn Leaf set reminder (cafe-pass.md §3a), a new camp item, and a **Golden Day** Sunday | `COZY` |
| 4 | 12-05 | a **Rainbow Day** Saturday, 2 more decor pieces and the next fixes from player bug reports | `SNOWY` (kept as the week-4 code name) |

### 4a. No winter event (Set 11 Q6, Derek2 2026-11-07)
Derek2: "this game probably wont live that long its a learning experience so don't worry about next winter or even next month focus on making it good for launch". The Winter Cafe event is dropped. Effort goes into launch polish, and weeks 1 to 4 stay small drops built from what exists.
