# Purr Pot launch operations: codes, group bonus, update board

Owner: growth-analyst. Written 2026-10-25 after the designer scheduled the genre-standard features in docs/design/cat-cafe/common-features.md and handed three launch-phase features to growth: Chalkboard codes (12), Regulars Board (13) and the What's New board (19). This is the operating plan for those three, plus two policy notes on neighbouring features. The store page and the full launch plan are separate docs to write before Phase 4.

## 1. Chalkboard (codes)

Purpose: codes are a free acquisition channel. Code-guide sites (Sportskeeda, Pocket Tactics, Beebom, Pro Game Guides and dozens of smaller ones) publish a page per game that has codes and refresh it monthly; Roll a Fisherman had at least seven such pages within two months of its August 2026 release (comps.md sources). Each page is a search result that points new players at the details page, which is also what the audience expansion share of Creator Rewards credits.

Rules (design): rewards are coins, food and Catnip only, never cats. Growth owns the list and the cadence.

Operating rules:
- Format: one word plus a number or season, all caps, no spaces: `OPENINGDAY`, `REGULARS500`, `AUTUMN26`. Never embed a URL, a social handle or another game's name.
- Value: small enough to be a welcome, not a progression skip. Launch code about 250 coins (the gdd's cafe level 2 price), milestone codes 500 coins or one Tuna, seasonal codes one Salmon or one Catnip. Never more than about ten minutes of mid-game income.
- Cadence: one code at soft launch, one per visits milestone (10k, 100k, 1M), one per seasonal update. Codes expire 60 days after release so guide pages stay accurate; the chalkboard shows "expired" rather than "invalid" for a known old code.
- Redemption is one per account per code, checked on the server from the saved profile, with a rate limit of five attempts per minute so the chalkboard cannot be brute-forced.
- The likes milestone gift (design 13) is released as a code announced on the What's New board, which turns an unverifiable like into a verifiable redemption. A June 2025 DevForum thread (community answer, not Roblox staff) treats a like-milestone code as allowed; what is not done anywhere in Purr Pot is a per-player reward for liking, since the client cannot verify it and Roblox's media-feed ruling shows metric-farming mechanics draw moderation.
- Track every redemption (section 4) and watch the acquisition dashboard the week after each code: a code that moves visits without moving D1 is a code that attracted the wrong players, and the next one gets smaller.

## 2. Regulars Board (group bonus)

Purpose: the Roblox group is the one owned channel that survives algorithm changes; group members see shouts and the group wall, and a group makes Team Create and shared ownership easier (plan.md Phase 1).

Rules (design): +5% tips for group members, verified on the server with GroupService.

Operating rules:
- Verify with GroupService (IsInGroup or GetGroupsAsync) on join and cache; recheck at most once per session. Treat a failed call as "not a member" and retry later, never as an error the player sees.
- Keep the bonus at 5%. It sits below one decor item's bonus, so it is a thank-you rather than a wall. Do not stack it with any future paid multiplier in a way that exceeds the pass's own stated value.
- Say it plainly on the board: "Join the Purr Pot group for +5% tips." No countdown, no "limited".
- Group settings before soft launch: wall posts limited to members with a role above guest, and the group description carries the details-page link so searches for the group name land on the game.
- The group also becomes the place where friends get builder or tester roles for Team Create (plan.md open question on roles).

## 3. What's New board

Purpose: weekly updates are the retention lever in the 2026 comps (Saturday is the update day for the top trending games, comps.md section 4). The board is where that cadence becomes visible to players.

Operating rules:
- One board in the street and a one-time toast on join after each update (design 19). The toast is one line and a "See what's new" button; no reward for reading it, which keeps it clear of the reward-driven media feed rule.
- Content per update: what was added, what was fixed, one teaser for next week, the current code if any. Written by growth from the engineer's handoff notes, under 60 words.
- Cadence: Saturday updates from soft launch, even when small. A fix-only week still gets a board entry. Skipped weeks are announced in advance on the board, not explained after.
- Mirror each entry to the group shout and the devlog so the same text serves players, the group and the portfolio.

## 4. Analytics additions for these features

Added to analytics-plan.md as the 2026-10-25 addendum: `code_redeemed`, `regulars_claimed`, `daily_treat_claimed`, `request_completed`, and a `buff` field on `lure_used` for Catnip.

## 5. Two policy notes on neighbouring launch features

Status 2026-10-25 (late): both accepted by the designer and written into common-features.md and docs/decisions.md. Daily Treat is now a seven-stamp card with one stamp per calendar day played and no reset on a missed day; Catnip states its numeric effect on the shop card before purchase as well as the modified odds on the HUD while active. The two notes below are kept as the reasoning.

- Daily Treat (design 11) resets to day 1 when a day is missed. Streak resets are one of the named parent complaints about Adopt Me (Kinzoo, 2026-05-08) and sit next to "fake timers" in the project's no-pressure rule. Recommendation to the designer: keep the seven rewards but make the streak pause rather than reset, or let the seven gifts be claimed on any seven days. The engagement value of a daily calendar comes from the gift, not from the fear of losing progress.
- Catnip (design 14) is a probability modifier. The design already shows the modified odds while it is active. If coins are ever sold for Robux, the May 2026 clarification also requires the numeric effect ("25% chance to shift the roll one rarity up") to be shown before the purchase of the Catnip itself, and that applies to Catnip granted by codes and the Daily Treat as well as Catnip bought with coins. Cheap to add now: one line on the shop card.

Proposed for docs/decisions.md: 2026-10-25, growth runs codes (small, expiring, one per milestone or season, never cats), the group bonus (5% tips, GroupService-verified) and the Saturday What's New board as the launch acquisition and retention channels; the likes milestone becomes an announced code; growth recommends the Daily Treat streak pause rather than reset.
