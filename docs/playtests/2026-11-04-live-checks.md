# Live checks for Derek's 2026-11-04 feedback (#1070 to #1083)

For Derek, or anyone on live. Owner: QA-Planner (friend's project). Each issue is fixed in its own PR. Once that PR
merges and a publish carries it, run its row on a phone and on the PC (tablet too where the row says so), then
comment on the issue with pass or fail. A row passes only when **good** holds on every device listed.
Rejoin after a publish so you get a fresh server on the new version.

| Issue | Area | Do | Good |
|---|---|---|---|
| #1070 clean pictures live | ui, tools | Open the food/orders, potions, Decor, daily, weekly, achievements, spin, shop and tips windows, and wait for the 30-minute reward | Every tile shows a clean picture. No blank squares, no old sheet pictures, and the 30-minute reward has a picture. A blank right after an upload can be moderation: recheck an hour later before failing it |
| #1071 crate, money bag, fish | ui | Look at reward cards in daily, weekly, achievements, spin and the offline claim | The crate, money bag and golden fish are the redrawn clean ones. You can tell what each is at a glance, even on the phone |
| #1072 decor gaps | ui, model | Scroll every Decor tab, buy and place a few of the items listed in the PR | Every item has a picture in the menu, and every placed item is a real model, not a grey block or nothing |
| #1073 Claim all | ui, gameplay | Have ready rewards in daily, weekly and achievements (or use the PR's test save), then press Claim all once | It stays visible after one single claim. One press claims all three lists, with one summary toast. It hides only when nothing is left. Pressing it fast many times pays once |
| #1074 red "!" on gifts | ui | Wait until a gift is ready | The gifts/claim tile shows a small red "!", no "1 ready" text. Other claimable tiles use the same badge |
| #1075 button shadow | ui | Look at the bottom edge of HUD and window buttons (old and clean) | No black or dark band along the bottom. Buttons still look pressable |
| #1076 top-right column | ui | Look at Settings, Feedback and Claim top right (phone, tablet, PC; console if possible) | They sit right under Roblox's top bar with no extra gap, not darkened by the bar, not overlapping Roblox's buttons (keeps #1037's fix) |
| #1077 locked Index cats | ui | Open the Index and tap a blacked-out cat | It stays a dark silhouette, and its name shows (its area too if the PR adds it), not "Not found yet" |
| #1078 Use all spins | ui, gameplay | Save 3 or more spins, open the spin window, press Use all | All saved spins are used, one results card lists every prize, the spin count goes to 0. The odds line is still shown. Pressing it twice fast doesn't double-pay |
| #1079 cat speech bubbles | ui, gameplay, design | Walk up to the spin cat and the other cats the PR names, then walk away | A short bubble appears near the cat and fades when you leave. No clicks needed, no menus. Bubbles never stack or cover the HUD (check on the phone) |
| #1080 net outside areas | animation, gameplay | Warp to the cafe, cannon to the cafe and to Town Square, then walk into a catching area | No net in the cafe, in Town Square or right after any warp or landing outside an area. The net comes out on entering a catching area |
| #1081 cannon landing camera | animation | Fire the cannon 2 or 3 times | The landing camera closes in less tightly than v184, the hero landing still reads, and the camera ends in your normal view |
| #1082 Town Square flags, paths | model | Stand in Town Square for 5 minutes, then walk the side paths to their ends | The rope flags stay in place (flutter is fine, drifting away is not). Every path ends inside the map with a finished edge |
| #1083 feedback name line | ui, design | Open Feedback | The line about featuring your name if your idea is used is there, with the opt-in tick (default as the PR says). Nothing asks for anything except the display name |

## Notes

- Rows marked gameplay (#1073, #1078) also need the server checks in their PR's test plan. This list is only what a
  player sees.
- #1076 and #1081 change fixes that the v183 checklist (`2026-11-03-v183-checks.md`, lines 3 and 7) already passed.
  Rerun those two v183 lines along with them.
- A failure goes as a comment on the issue: device, row, what you saw, and a screenshot. QA turns repeats into
  tickets. No fixes from QA.
