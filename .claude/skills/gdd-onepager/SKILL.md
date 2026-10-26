---
name: gdd-onepager
description: Template and rules for a one-page game design document for Purr Pot features or whole games: hook, core loop at three scales, session and progression loops, social, monetization, prototype scope with S/M/L, risks, open questions. Use whenever the game-designer writes or updates a GDD or feature spec.
---

# GDD one-pager

A GDD (game design document) is the spec the engineer, artist and QA build from. One page; if it needs more, split a feature out into `docs/design/cat-cafe/features/<feature>.md` using the same template. Write for Derek: plain language, numbers wherever possible, and a reference game named for anything hard to describe.

## Template
```markdown
# <Game or feature name>  (date, author, status: draft | agreed | built)

**Hook (one sentence):** why a 10 year old tells a friend about it.

**Core loop**
- Every 30 seconds: ...
- Every session (10 to 15 min): ...
- Every week: ...

**Session loop:** what the first 10 minutes look like, step by step, for a brand new player.

**Progression:** what unlocks, in what order, and roughly when (minute 5, session 3, week 2).

**Economy:** sources of coins, sinks for coins, the one number that controls pace.

**Social:** what friends see of each other's cafes; what is deliberately not in (stealing, trading) and why.

**Monetization:** game passes, developer products; anything random; PolicyService needs. Reference monetization-policy.

**Prototype scope (vertical slice)**
| System | Smallest version | Size | Owner |
|---|---|---|---|

**Risks:** technical, content volume, policy, fun. One line each with a mitigation.

**Out of scope for now:** list, so nobody builds it by accident.

**Open questions for Derek:** numbered, each with a recommended answer.

**Proposed decision line:** `YYYY-MM-DD: <decision>. Why: <reason>.`
```

## Rules
- The core loop sentence must contain a verb the player does, a reward they get, and what the reward buys.
- Every system in the scope table gets S (under a day of agent work), M (2 to 3 days) or L (a week or more). Anything L must have a smaller version listed beneath it.
- Name the one tuning number that controls pace (for Purr Pot: coins per serve against the price of the next upgrade) and give the engineer a starting value.
- Numbers go in `docs/design/cat-cafe/tuning.md` as a table with columns: key (matches `Config.luau`), value, why, last changed.
- Flag these on sight: paid random items, trading, stealing from other players, PvP, user-generated text, anything that reads differently for players under 13.
- Reference games may be named for mechanics. Never copy their names, characters or art.

## Purr Pot starting skeleton (fill in, do not treat as decided)
- Hook: run a tiny cafe where your cats are the staff, and grow the crew by befriending strays in the alley.
- 30 s loop: customer sits > tap a cat to serve > coins pop > spend on the next upgrade.
- Session loop: 2 to 3 upgrades, 1 to 2 new cats, one "new table unlocked" moment.
- Weekly loop: daily returning customers, rare breed rotation in the alley, cafe decoration goals.
- Pace number: `Config.Cafe.CoinsPerServe` vs `Catalog.Items.upgrade_*.Price`.
- Assumptions from the concept page awaiting Gavin: no stealing cats from others, no trading at launch.
