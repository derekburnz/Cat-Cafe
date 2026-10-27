---
name: concept-visuals
description: The rough-visual process for Cat Cafe: style options in words, a Studio graybox of the cafe and alley, one Blender hero asset, an HTML or SVG HUD mockup, saved to docs/concepts/cat-cafe/ with captions. Use for mood, graybox, hero asset and mockup tasks, and when assembling a comparison page for Derek and friends to vote on.
---

# Concept visuals (Cat Cafe)

Claude does not paint. Rough visuals come from the real tools: Roblox Studio generation tools for grayboxes, Blender for one hero asset, HTML or SVG for UI mockups. This doubles as a test of the pipeline.

## 1. Style options (already drafted; pick one)
The Three Game Sketches page (https://claude.ai/artifact/LEGHFzKQrACa125S45VCqX) lists three named styles for the cafe. Keep them as the vote options unless Gavin or Derek asks for new ones:
- **Cozy Cream**: warm creams and wood browns, soft rounded shapes, afternoon window light.
- **Pastel Pop**: mint, peach and lavender, chunky toy-like shapes, flat bright lighting.
- **Alley Night**: cafe glows warm against a blue dusk alley, string lights, higher contrast.
Each option in words: palette with 5 hex codes, shape language (rounded / chunky / angular), camera (third person over the shoulder vs raised isometric-ish), lighting mood, one reference word. Record the winner in `docs/decisions.md` and `docs/art/style-guide.md`.

## 2. Studio graybox (style neutral until a style is picked)
One hero area: the cafe interior (counter, 4 tables, cat shelf, window) plus the alley outside the back door (bins, crates, fence, lamp, one catchable cat spot).
- Build with `generate_procedural_model`, `generate_mesh`, `generate_material` and plain Parts via `execute_luau`. Name everything `PH_<Thing>` so the engineer can hook gameplay to it and the artist can swap it later.
- Scale check: counter 3 studs high, tables 3, door 7, cat 1.5 to 2 at the shoulder.
- Lighting: one `Lighting` preset per style option (ClockTime, Ambient, OutdoorAmbient, a warm PointLight over the counter) saved as a snippet in `docs/concepts/cat-cafe/lighting.md` so the three looks can be compared on the same graybox.
- Capture 3 or 4 angles with `screen_capture`: from the door, behind the counter, from the alley looking in, top-down. Save as `docs/concepts/cat-cafe/<date>-graybox-<n>.png`.

## 3. One Blender hero asset
The signature cat (`Cat_Tabby_Base`) if Blender MCP is connected, otherwise the counter. Follow asset-pipeline for scale, pivot and naming; bring it into the graybox and screenshot it next to a PH_ cat so the size reads.

## 4. HUD mockup (ui-designer)
An HTML or SVG page at `assets/cat-cafe/ui/hud.html` showing: coins, current order with a cat portrait, cats owned count, a shop button, a cat book button, and the "new cat spotted in the alley" toast. Phone portrait and landscape at minimum. Real copy, style palette, 44 px touch targets. Screenshot to `docs/concepts/cat-cafe/<date>-hud-<device>.png`.

## 5. Comparison page for the vote
`docs/concepts/cat-cafe/comparison.html`: the three style options side by side, each with its palette, the graybox under its lighting preset, the hero asset and the HUD recoloured. One sentence per option on what it would cost to maintain (textures vs flat colours). Derek shares it with friends; the vote result goes in `docs/decisions.md`.

## 6. Captions
Every image gets one line in `docs/concepts/cat-cafe/README.md`: filename, what it shows, which style option, date. Captions are what the devlog and the portfolio page reuse.
