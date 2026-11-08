# Game icon variants for Cafe Events (#2488)

Model-Agent, 2026-11-08. Each is the live game icon (icon D, Rainbow Pounce), dimmed, with a white hourglass, gold sand and a bold label. All are 512x512 PNGs, and the labels stay readable at 150 px (see `docs/concepts/cat-cafe/event-icons-2488.png`).

| File | Use |
|---|---|
| `CatCafe_GameIcon_Event_3Hours.png` | 3 hours before an event (the sand is all on top) |
| `CatCafe_GameIcon_Event_Now.png` | when the event starts (the sand is running) |
| `CatCafe_GameIcon_Event_NewUpdate.png` | afterwards, when an update ships (the sand is all on the bottom) |
| `CatCafe_GameIcon_Normal.png` | the normal icon to switch back to (a copy of the live icon) |

Only use these for real, scheduled events (#2483). The swap plan is in `docs/growth/launch-ops.md` section 6 (Tools-Agent). Upload them only with Derek's OK. To rebuild them after the game icon changes, run `assets/cat-cafe/blender/event_icons.py`.
