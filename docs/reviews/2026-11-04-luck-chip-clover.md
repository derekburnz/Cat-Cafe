# Review: luck chip clover (#1258), `ui/luck-chip-clover` (PR #1263)

Reviewer: luau-reviewer (fresh subagent, read-only). UI only: no remotes, data or server code, so client trust, rate limits, data safety and policy do not apply. Gate: sourcemap, luau-lsp (no warnings in changed files), stylua pass; selene's API dump fails offline (CI runs it).

## Findings

### Should-fix
1. `Screens/HUD.luau`, the Lucky Day line's circle: `TextBounds` is in screen px after the HUD's UIScale, but went straight into a design px offset, so at the phone's 0.75 scale the circle sat over the first letters. **Fixed:** divided by `Scale.get()`.

### Nits
2. `Screens/TipCard.luau`: the luck tip drew the green clover on the gold disc. **Fixed:** the luck tip's disc is `Theme.luck.circle`; other tips keep gold.
3. `Screens/TipCard.luau`: required LuckLogic (and through it shared Luck and Config) to compare one glyph. **Fixed:** uses `Theme.icons.luck`.
4. `docs/design/cat-cafe/luck-and-rare-moments.md:41, 111` still says the chip glows on a Lucky Day. **Not changed here:** the game-designer owns that doc; noted on the PR for them.
5. `tools/cloudcheck/uigate-scenes.luau` HUDLuck comment said "glowing". **Fixed.**
6. `Screens/FishMarket.luau:650`: the odds note keeps 🍀 inline in rich text (IconArt can't draw inside a text run); matches the contract. **Left as is** (outside Derek's list for #1258).
7. `Theme.luau` comment over 100 columns. **Fixed.**

## Checked and fine
Connections stored and cleaned up; the picture resolves to `Icon_Clean_Clover` (rbxassetid 70755641486261) through CleanGlyphs and IconArt; ZIndex and TextTransparency handling; the card title row width; no ring, stroke or glow left on the circle; Lucky Day still turns the text gold; `--!strict` and types.

## Verdict
Merge after should-fixes (done in the follow-up commit).

QA: with Luck and a Lucky Day running, at 1280 x 720, 844 x 390 and 667 x 375, the chip, card title, Lucky Day line and luck tip show the outlined clover on a dark green circle with no ring, glow or white edge, and the line's circle sits just left of its words for "in 3 days", "tomorrow", "at sunrise" and "now".
