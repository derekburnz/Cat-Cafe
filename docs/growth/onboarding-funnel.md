# How to read the onboarding funnel

Owner: growth-analyst. Written 2026-11-04 with #1273. The step list and when each step logs are in `docs/design/cat-cafe/easy-start.md` section 5; this page says what a drop at each step most likely means and what to look at next.

## Where to read it

- **Creator Hub**, Analytics, Funnels: `onboarding_v3` (37 steps) and `onboarding_v3_intro` (13 steps). Each step shows Total users, Step completion, Churn and Total conversion.
- **Without Creator Hub**: the Analytics workflow (`.github/workflows/analytics.yml`, script `games/cat-cafe/tools/opencloud/analytics.sh`) prints every funnel step by step with the share of step 1 left and the players lost since the step before.
- `onboarding_v2` stopped logging on 2026-11-04. A window that starts before that shows both; compare shapes, not counts, since v3's steps are not v2's.

## Reading rules

1. **Look for the biggest "lost since the step before", not the lowest count.** Every funnel falls; the step that loses the most players relative to the step before it is the first thing to fix.
2. **Steps are "reached or passed".** A server step that proves earlier ones logs them too (a catch logs the stray and the catch card), and Roblox counts any step before a logged one as done. So a client step (the tutorial cards, the catch card, the first window) can read a little higher than the number who truly saw it. A drop between two client steps is still real.
3. **Who is in it**: only players whose save had not caught a cat by 2026-11-04, and everyone who joins after. Veterans left the funnel on their next join.
4. **Pair a drop with time.** `session_30s` to `session_10m` carry the furthest step and the screen open at that moment; `new_player_left` and `quit_point` carry the same as a player leaves, with the seconds played as the value. Break them down by the first field to see where people are standing when they go.
5. **Rescue first, catch steps implied.** A player whose first cat is a rescue logs `catch_started` and `first_circle_hit` with it, though they never saw the circles; `first_catch_tries` says "rescue" for them.
6. **Release days are noisy.** While old servers still run after the 2026-11-04 release, a new player who hops to one can drop out of v3 for good (the old server reads the save as an old funnel). Leave the first day or two out when comparing.
7. **The intro funnel counts any play.** Since the intro is played from the tile, a later replay that reaches further moves the player on; `intro_cutscene`'s first or replay field tells the two apart.
8. **Small numbers lie.** Under about 100 players at step 1, a 10 point swing is noise. Wait for a few days of data before acting on one step.

## Step by step: what a big drop likely means

### Loading and the first catch (steps 1 to 15)

| From | To | A big drop most likely means | Check next |
|---|---|---|---|
| joined | loaded | the game did not finish loading on their device, or they left during the load | `loaded` by device field; `new_player_left` in 0 to 60 s; memory and load time on phones |
| loaded | tut_0_shown | the first card did not show, or they left at once on seeing the world | `session_30s` count; a client error on the first sync |
| tut_0_shown | first_move | they did not know how to move, or did not want to | touch controls on phones; first-screen clarity |
| first_move | first_cannon | they could not find or did not try the cannon | `quit_point` where = town; the trail and the cannon hint |
| first_cannon | entered_alley | lost after the flight, or landed somewhere confusing | `cannon_launch` destinations; the landing pad |
| entered_alley | tut_1_shown | the catch card did not appear in the alley | rare; a client bug if large |
| tut_1_shown | first_stray_in_view | they did not find their stray past the camp | the trail; `quit_point` where = alley |
| first_stray_in_view | near_stray | they saw it but did not walk up to it | stray placement; the trail end |
| near_stray | catch_card_opened | the prompt did not show near the cat | prompt range; a stray locked by someone else |
| catch_card_opened | catch_started | they did not know how to start (swing or hold) | the card's picture and words; `net_swing` misses; device |
| catch_started | first_circle_hit | the circles are too hard or unclear | `catch_circles`; `first_catch_tries`; device split |
| first_circle_hit | first_catch | they hit once but could not finish | the tutorial stray's slow circle; `first_catch_tries` |
| first_catch | carrying_first_cat | they dropped the cat or were shoved at once | `left_after_shove`; `drop_outcome` |
| carrying_first_cat | first_checkin | they could not find the basket or the way back | `quit_point` while carrying; the carry marker |

### The first cafe loop (steps 16 to 28)

| From | To | A big drop most likely means | Check next |
|---|---|---|---|
| first_checkin | first_role_assigned | no free role and they did not open Cats | `slots_full`; card 2's line |
| first_role_assigned | tut_3_shown | the table card did not show | rare; a client bug if large |
| tut_3_shown | first_customer_served | the cafe did not earn (cat not working) | the cafe's income in the first minute |
| first_customer_served | second_cat | they did not go back for a second cat | the "catch more" line; `session_2m` and `session_5m` screens |
| second_cat | first_window_opened | they never opened a window (Upgrades) | the HUD button; `stuck_nudge` at tutorialStep 3 |
| first_window_opened | first_table | they opened Upgrades but did not buy, or could not afford it | `first_window` field; coins at `quit_point`; the table's price |
| first_table | first_tip_collected | piles did not come (night, or no earning) | `TipPileSeconds`; time of day at join |
| first_tip_collected | tut_4_shown | the bowl card did not show | rare |
| tut_4_shown | bowl_bought | they did not find or afford the bowl | the bowl's price; `stuck_nudge` at tutorialStep 4 |
| bowl_bought | first_bait | they bought it but did not put food in | the bowl's place on the back step; the prompt |
| first_bait | first_rescue_started | they did not see or try a stuck cat | rescue markers; `quit_point` |
| first_rescue_started | first_rescue_done | the rescue minigame is too hard | `rescue_attempt` outcomes |
| first_rescue_done | first_bait_resolved | they left before the bait timer ended | the timer length against `session_10m` |

### Later (steps 29 to 37)

These span days, so read them as retention: `returned_next_day` against Creator Hub's D1 retention, and `tier_2` against `rank_up` minutes played. A big drop at `rank_up_card_seen` to `rank_up_ready` means Tier 2's needs feel too far; at `rank_up_ready` to `tier_2`, that players do not find or press Rank Up.

### The intro funnel (`onboarding_v3_intro`)

- Few players reach `intro_choice_made` at all: the Tutorial tile is not tempting, or they hide it (`tutorial_closed`).
- A drop at one `intro_shot_n`: that shot is slow or dull; `intro_cutscene` skipped with version:shot names the shot they skipped on.
- `intro_started` well under `intro_choice_made`: the intro failed to start (streaming the camp took too long, or they were carrying a cat).

## Time markers at a glance

Read `session_30s`, `session_60s`, `session_2m`, `session_5m` and `session_10m` by their first field (the furthest step). If most players at `session_2m` are still on `first_cannon` or earlier, the walk to the alley is the problem; if most at `session_5m` sit on `catch_started` or `first_circle_hit`, the catch is. Their second field (the screen open) says whether they were stuck in a window.
