# Review: friend's queue, part 3, 2026-11-03

Reviewer: luau-reviewer (Review-Agent, friend's project). Follows `2026-11-03-friend-queue-2.md`.

| PR | Topic | Verdict | Action |
|---|---|---|---|
| #1040 | Redrawn My Cafe, Cannon and Potion, new Trade symbol (#1024) | Pass | Merged 28e871dd. |
| #1041 | Dark windows pilot: Quests and Daily Treat (#1028) | Fix, then pass | Merged f5c2e929. |
| #1042 | New icon ids in ShopIcons (#1024) | Pass, held for the grant | Merged 9748efdb, then the grant ran. |
| #1043 | store-media and analytics prefer `OWNER_KEY` | Pass | Merged dc760435. |

## #1040
- One code line: the HUD Trade tile passes `image = ShopIcons.clean("Trade")`, like the other clean tiles. It gives nil, and so the glyph, until an id exists.
- The generator source changes are drawing code only, with no network or shell calls.

## #1041 (pilot only)
- `Theme.dark` tokens and an opt-in Panel `dark` prop. View-only.
- First pass failed contrast: the gold lerps (0.7 to 0.75 toward the card) gave gold 3.9 to 4.1, subtext 3.6 to 3.8 and good 3.5 to 3.6. The fix, `Theme.dark.goldCard` 5C4A33, gives white 8.46, subtext 5.18, good 4.94 and gold 5.52.
- The user later OK'd rolling dark out to the remaining windows ("ok on all asks", 14:13). Each batch gets its own review.

## #1042 and the Roblox actions (user-approved)
- `upload-image.yml` run 41649292093 on the user's OK ("you should have upload perms"): Home 128704819455880, Cannon 134222859642759, Potion 92456971844930, Trade 86243209880722. Moderation was Reviewing at upload.
- The #1042 ids match that log. The merge was held until the grant was OK'd ("yes grant"). `asset-permissions.yml` reads ids from main, so #1042 merged first and grant ran straight after: run 41652928786, "Granted 159, not ours 0, failed 0, of 159".

## #1043 (secrets)
- The key goes into the job env only, so it stays masked. The new step echoes `${{ secrets.X != '' }}`, which the expression engine evaluates to true/false before the shell runs, so no value can leak.
- The triggers are dispatch or schedule only, so fork PRs can't reach `OWNER_KEY`. The daily analytics run now uses `OWNER_KEY`, so keep that key's scopes narrow.
