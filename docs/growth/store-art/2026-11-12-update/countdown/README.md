# Update countdown game icons (#3453, for the 2026-11-12 update)

Derek asked for an hourglass countdown on the game icon before the update. Roblox has no built-in overlay, so
these are whole icons swapped by hand (Growth-Agent's plan on #3453). Each is 512 x 512: the update icon without
its UPDATE! word (`CatCafe_Icon_H_MysticPool_base.png`), dimmed, with a white hourglass, gold sand that runs down
step by step, and a two word label that reads at the Home tile size.

| File | When |
|---|---|
| `CatCafe_GameIcon_Update_5Hours.png`, `_3Hours`, `_1Hour` | the recommended steps before the push |
| `CatCafe_GameIcon_Update_Now.png` | at the push (brighter, the sand has run out) |
| `_6Hours`, `_4Hours`, `_2Hours`, `_30Min` | spares, if Derek wants hourly steps |

After the countdown the update icon (`../CatCafe_Icon_I_MysticPoolUpdate.png`) goes on for the week.
Each swap is a new upload that Roblox moderates before it shows, so allow time for that at every step.
Nothing is uploaded without Derek's OK.

Rebuild: `python3 -I assets/cat-cafe/blender/event_icons.py <base icon> <fonts dir with LuckiestGuy.ttf> <this folder> update`.
