# Console checklist (controller support, #2871)

QA-Planner, 2026-11-09. Console is ticked under Playable Devices (Derek, 2026-11-09). Run this on an Xbox or PlayStation, or in Studio with a gamepad plugged in for a first pass, once #2872, #2873 and #2874 have merged. Use a controller only: no mouse, keyboard or touch at any point. Mark each line pass or fail, and note the screen and button for each fail.

## A. Already expected to work (from QA's code audit)
- [ ] Swing the net with R2 next to a stray; the hint reads "Press R2 next to a cat".
- [ ] Catch circles: A or R2 lands each press.
- [ ] Rescue bar: A or R2.
- [ ] Tackle a carrier with Y.
- [ ] Station and catch prompts open with X, and the key cap shows X, not E (#2874).
- [ ] B closes any open window.
- [ ] The intro plays and can be skipped with the controller.

## B. Menus and windows (#2872)
- [ ] The controller has a way into the menu from anywhere, without using Roblox's selection toggle.
- [ ] Open Upgrades, Decor, Cats, Potions, Quests, Bait and Home. Each window highlights a first button when it opens, and the highlight is easy to see.
- [ ] Move through every button in each window with the DPad or left stick. Nothing can't be reached, and the selection never gets stuck or jumps off screen.
- [ ] Buy an upgrade, equip a cat, use a potion, place a decor piece and claim a quest.
- [ ] Store: the Robux prompt opens and can be cancelled. Do not complete a purchase.
- [ ] Closing a window gives the selection back, or clears it, so the character can walk again.

## C. Carrying, Drop and the Backpack (#2873)
- [ ] Carry a cat and drop it with the new Drop button.
- [ ] Pack a cat in the Backpack and drop it with the same button.
- [ ] The Drop button does nothing during a catch or with a window open.
- [ ] The carry hint shows the controller button.

## D. Other screens (#2874)
- [ ] Settings: change every slider with the DPad or stick, and flip every toggle.
- [ ] Cat Room: feed a cat with one press, and hold A to keep feeding.
- [ ] Spin Wheel, Fish Market, Mystery Market, Day Cart and Night Dealer: buy one item each with the controller.
- [ ] The cannon picker: choose an area and fire.

## E. The TV screen and a session
- [ ] Text is readable from the couch on a 1080p TV. No HUD piece sits in the TV's safe-area edge.
- [ ] The first hour on a fresh account: the tutorial arrows point at what to press on a controller.
- [ ] Ten minutes of normal play with no errors. Check F9 if the console allows it, or the bug reports the next day.

Report results in a dated file in `docs/playtests/`, and gaps as sub-issues under #2871.
