# Clean icon set (2026-11-03)

Derek's playtest 2026-11-03: "make the buttons more clean looking symbols similar to these attached", "a lot of the ui just feels to plain and outdated", "the buttons need icon re-works". Issues #959 (HUD tiles), #960 (My Cafe and Cannon), #961 (beige buttons), #962 (prompt card text), #963 (potions), #964 (Decor menu), #966 (spin prizes).

- `Icon_Clean_*.png`: 256 x 256, transparent, one bold white (or coloured) symbol with a thick dark outline (#2a1a12). The tile behind each symbol is drawn in Luau (UICorner, a bright two-colour UIGradient, a thick dark UIStroke and a dark depth edge), so the same image works on any tile colour.
- `mockup/hud-mockup.png` and `mockup/parts-mockup.png`: the pictures Derek was asked to OK before building.
- `source/`: `icons.js` draws every symbol as SVG; `iconshot.cjs` renders them (`node iconshot.cjs <abs path>/icons-render.html <out dir>` with Playwright); `mockshot.cjs` renders the two mockups.

Next (after Derek's OK): upload with Tools-Agent's `upload-image.yml`, add the ids to `Components/ShopIcons`, restyle the tiles in `Screens/HUD.luau`.

Tile colours used in the mockup (top to bottom gradient): Cats #6fc0ff to #2f86ef, Index #7ae86f to #2fb043, Quests #ffe46b to #f5ac12, Upgrades #ffb15a to #f06a1d, Decor #62ecd2 to #18ab95, Store #ff8cc2 to #e8378a, Tutorial and Potions #cf96ff to #8a47ea, Rewards and Cannon #ff8a7a to #e4402f, Feedback and Areas #8fe3ff to #2bb3e6, Menu #c9d4e3 to #7f8fa6, My Cafe orange like Upgrades, Bait blue like Cats. Outline 4 px #2a1a12, corner 20 px on a 78 px tile, label 18 px Fredoka bold, white with a 5 px dark outline.
