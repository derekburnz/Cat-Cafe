---
name: ui-review
description: Cat Cafe's UI checklist. Use before building, changing or reviewing any screen, HUD piece, card or toast in games/cat-cafe/src/client/UI, and before signing off a UI pull request.
---

# Cat Cafe UI review

The house rules for Cat Cafe screens, in one place. Use it with:

- `roblox-gui` for layout, safe insets, input, gamepad focus and cleanup (the engineering rules).
- `roblox-ui-genre-studs` for the simulator look (outlines, lips, colour meanings, HUD zones, motion numbers). Its numbers are starting values. Where it and Cat Cafe differ, `Theme.luau` and this file win.
- `docs/design/cat-cafe/ui-contract.md` for what each screen does and the API between the UI and the engineer. Read the screen's section before touching it, and update it in the same pull request.

## 1. Boundaries

- The UI is a view. It reads the state it is given (`UI.update`) and reports presses through `UI.events.*`. It never fires a remote and never decides an outcome. A Claim button shows "..." until ProfileSync says the claim happened.
- Logic that can be tested goes in a pure module under `UI/Components/` with a spec in `tests/specs/`. The cloud runner has no `Instance.new`, CFrame or fonts, so a pure module requires no Theme, Format or Roblox services.
- Colours, sizes and fonts come from `Theme.luau`. No hex codes in a screen.

## 2. Derek's standing rules

- **Brief by default.** A screen shows the one thing the player needs; details sit behind a tap (a card, an Odds button, an Expand). Hide rows and pictures that say nothing new.
- **Pictures over writing.** Where a picture says it (a black silhouette for a cat not found, a filled tile for one found), drop the words.
- **HUD status is outlined text with no box.** Only pressable things look like buttons. A number with a plate behind it reads as a button.
- **A red "!" or count means something to claim or new to buy.** Never light it for news the player cannot act on.
- **Fewer pop-ups.** No banner for every small event. Many rewards at once get one Claim all and one summary, not a stack of toasts.
- **One window at a time.** `Components/Modal` owns every window; a new one replaces the old. Only the window's X or its key closes it; the dim backdrop takes taps without closing.
- **Original art only, and no placeholder Roblox characters** in renders, mockups or pose sheets. Show scale with our cats or props.

## 3. Sizes and fit

Check every changed screen at 1280 x 720, 1366 x 768 and a phone at 844 x 390, after the window's UIScale has shrunk it:

- Anything pressable is at least `Theme.sizes.touchMin` (44) real pixels in both directions. The X on a window too.
- Body text stays at `Theme.sizes.textSmall` (14) or more after scaling; `textTiny` (12) only for a tag on a tile. TextScaled labels get a `UITextSizeConstraint` with a sensible minimum.
- Nothing runs off the screen or under Roblox's top bar, the thumbstick (bottom left) or the jump button (bottom right) on touch.
- Two things that can show at once do not overlap (a toast and a card, a window and the HUD's right column). Reflow before you shrink.
- Long names and big numbers fit: try "Neighbourhood", "$1,234,567,890" and a 20-letter cat name.

## 4. Look

- Fonts: Fredoka One for titles and numbers, Nunito for the rest (`Theme.fonts`). No third font.
- Buttons use `Components/Button` styles, and the colour keeps its meaning: green buy or claim, red close, gold rare or featured, grey owned or disabled, ghost for secondary.
- Prize rows show at most two pictures, three on the big prizes (F94, `docs/design/cat-cafe/rewards-and-shops.md`). Permanent bonus chips and name tags do not count.
- Icons come from the icon sheet through `Components/IconArt`; an emoji is only the fallback under it. A new icon goes on the sheet, not as a new emoji.
- Motion: windows pop in from 0.9 and close in 0.16 s (`Components/Tween`). Press feedback is a scale, not a size change. Nothing with text pulses its size forever. Check `GuiService.ReducedMotionEnabled` before shakes, bobs and long tweens.

## 5. Anti-slop check

Adapted from the anti-slop rules in [izzyfrm/roblox-ui-skill](https://github.com/izzyfrm/roblox-ui-skill) (MIT, licence in `LICENSE-anti-slop`) and the list in `roblox-ui-genre-studs` section 7, rewritten for Cat Cafe. Treat each as a defect unless the contract asks for it:

- a card around every group, cards inside cards, or big empty padding;
- an outline on things that are not pressable and not the window itself;
- glow, blur, gradient text or extra shadows added to fill space;
- more accent colours than the screen's header colour plus the button meanings;
- every button the same size whatever its importance;
- pills or badges on everything;
- a permanent upsell button or a timer that nags;
- replacing a working screen with a new one when a fix would do, or dropping a working button or piece of information on the way.

Then ask:

- Does it look like Cat Cafe (latte windows, dark outline, cat ears on the header) and not a generic simulator?
- Did decoration replace good layout?
- Is there anything the player does not need right now?

## 6. Before you open the pull request

- The gate passes: `./check.sh` (sourcemap, luau-lsp, selene, stylua) and the cloud specs.
- The contract section is updated.
- A visible change has a before and after picture or an HTML mockup in `docs/concepts/cat-cafe/ui/` or `/mnt/project-files/UI-Engineer/`, and the pull request says what to look at in Studio.
- The pull request quotes Derek's words for the ask it answers.
