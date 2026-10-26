# Review: five areas and the 5 minute clock (PR #47, F23) and rank up (PR #48, F24)

Reviewer: luau-reviewer thread, 2026-10-26 about 23:20 UTC. #47 on head 8f4a723 (engineer commits d72d02e and 1f13120); #48 on head f53b433, engineer commit 997b084 only (the rest is #47 merged in). Read only; no game files changed. Checked against data-model v0.3.1 sections 5b, 9 and 15.

## Verdict

Both are sound on the server side, and CI is green on both heads. No blocker. One should-fix on #47 (S35): five areas of ten strays quadruple the server's per-frame stray movement, and on placeholders every step moves ten parts. One nit on #48 for the designer (N44). #47 is behind main (8665ac5), so merge main in first.

## PR #47: checked and fine

- **Gates are cosmetic, as designed.** Each gate carries `RequiresTier`, and `WorldController` opens only this player's copy when `state.tier` reaches it. The server already refuses `GrabBegin`, `RescueBegin` and `UseLure` below an area's tier (`Economy.tier(profile) >= area.tier`), and that check reads the Catalog, so the three new areas are covered without new code.
- **Catalog and Config** match data-model section 9: day 300 s, night 300 s, waves of 10, odds per area that sum to 100, and tiers 3 to 5 for Neighbourhood, Woods and Sewer. `WorldBuilder` asserts that each area's Layout has as many spawn points as the Catalog says, so the two cannot drift apart silently.
- **`Debug.teleport`** goes through `guard()`, which errors outside Studio, and no remote reaches it.
- **Layout.** The new areas sit at z 103 to 147 and z -158 to -102, clear of the plots (z -84 to 84), and inside the 400 stud ground.

## PR #48: checked and fine

- **`RankUp` takes no arguments** and is rate-limited to 1 per 2 s (section 15). `onRankUp` (`CafeService.luau:541`) runs `Economy.rankUpBlocker` again on the server, then `trySpend` (`:553`), and only then raises `profile.tier` (`:557`). A client cannot skip a requirement or rank up twice for one payment, and nothing resets.
- **Requirements** follow the 5b table: `distinctCats` counts `collection` entries, so a shiny does not count twice, and the rarity rule matches what the UI's rank up card ticks (`RankUp.luau:175`), so the button and the server agree.
- **Expansions and the back door** are per plot. `PlotService.release` closes them when the owner leaves, so the next owner of the plot starts at Tier 1's layout. A closed expansion floor sits flush with the ground, so closing it under a visitor drops nobody, and every expansion stays inside the ground and clear of the areas.
- **Announce** uses `DisplayName` and the Catalog tier name, so there is no player text to filter.

## Findings

**S35 (should-fix, engineer, #47) 50 wandering strays.** Every night now spawns 10 strays in each of five areas, whether or not anyone can enter them (data-model 9, by design). Each stray rests 3 to 7 s, then walks for about 2 s (`CatService.luau:189` to `:209`), and `Mover.walkTo` moves it with `PivotTo` every Heartbeat (`Mover.luau:24`). That puts about 17 strays in motion at any moment instead of about 4. The placeholder cat is ten separate anchored parts (`Placeholders.cat`), so each step sets ten CFrames, and the server replicates every one to every client: roughly 10,000 part moves a second. StreamingEnabled will not help, because its default radius (1024 studs) covers the whole 400 stud map. On a phone that is steady bandwidth and CPU for cats nobody is near. Two cheap fixes, either of which removes most of it:
1. Skip a wander step when no player is within about 80 studs of the stray. Idle strays stay where they are, so nothing looks different to a player who walks up.
2. Weld the placeholder's parts to its body, as `attachHeldCat` already does for the carried cat, and keep only the body anchored. Then a step moves one part.

Measure it in the next Studio run: the Developer Console (F9) shows the network data the client receives, so compare day (strays standing still) against night after a wave.

**N44 (nit, designer, #48) "One Epic" means exactly Epic.** `Economy.distinctCatsOfRarity` (`Economy.luau:199`) and the UI card both count only cats of that exact rarity. A player with a Legendary or a Mythical but no Epic cannot reach Tier 3, and at Tier 5 a Legendary plus a Mythical does not meet "two different Legendaries". If the intent is "Epic or rarer", change both places together (there is `Catching.rarityAtLeast` for it); if it is exact, say so in section 5b and on the card.

## Build checklist status

Not touched by these PRs: S25, S26, S32 and N29 (bump), S27 and N32 (dealer), S28 (rescue), S29 (rich tip), S30 and N35 (rename), N30 (bait reveal). S32 (a dropped stray skips a wave within 120 s) lands with the bump build, in the same night-start code #47 now runs for five areas. Open here: S35, N44.
