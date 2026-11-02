# UI icon sheet

`UI_IconSheet.png` is one 1024 x 1024 picture holding sixteen 256 x 256 icons in a 4 x 4 grid, drawn for the Cat Cafe UI in one chunky style: a thick warm near-black outline (`Theme.colors.outline`, 2A1C15), bright fills with a soft top-to-bottom shade and a white gloss. Derek 2026-10-27: "a lot of the symbols like index upgrades and cats could use a tiny bit more quality also". One upload covers all sixteen; the UI cuts each out with `ImageRectOffset` and `ImageRectSize` (`Components/IconArt.luau`, the cells in `Theme.iconSheet`). Every icon keeps at least 8 px of clear edge, so a scaled cell never picks up its neighbour.

| cell (column, row) | icon | stands in for |
|---|---|---|
| 0, 0 | cats | 🐱 Cats |
| 1, 0 | collection | 📖 Index |
| 2, 0 | upgrades | ⬆️ Upgrades |
| 3, 0 | decor | 🪴 Decor |
| 0, 1 | home | 🏠 My Cafe |
| 1, 1 | travel | 🧭 Areas |
| 2, 1 | alley | 🐾 Alley |
| 3, 1 | equipBest | ✨ Equip Best |
| 0, 2 | gifts | 🎁 Gifts |
| 1, 2 | settings | ⚙️ Settings |
| 2, 2 | invite | 💌 Invite |
| 3, 2 | tutorial | ? Tutorial |
| 0, 3 | spin | 🎡 Spin Wheel |
| 1, 3 | lock | 🔒 Cat lock |
| 2, 3 | crate | 📦 Cafe Crate |
| 3, 3 | potion | 🧪 Potion |

## Remaking it

The icons are hand-written SVG in `make_icons.py` (one copy of each in `src/`). To change one, edit it there, then:

```sh
python3 make_icons.py /some/folder          # writes atlas.html and the SVGs
node render.js /some/folder                 # writes UI_IconSheet.png (transparent) and preview.png
```

`render.js` uses Playwright's Chromium. A changed sheet is a new upload (Actions > upload-image), and its id goes in `Theme.iconSheet.image`.
