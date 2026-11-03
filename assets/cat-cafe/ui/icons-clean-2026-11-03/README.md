# Clean icon set (2026-11-03)

Derek's playtest 2026-11-03: "make the buttons more clean looking symbols similar to these attached", "a lot of the ui just feels to plain and outdated", "the buttons need icon re-works". Issues #959 (HUD tiles), #960 (My Cafe and Cannon), #961 (beige buttons), #962 (prompt card text), #963 (potions), #964 (Decor menu), #966 (spin prizes).

- `Icon_Clean_*.png`: 256 x 256, transparent, one bold white (or coloured) symbol with a thick dark outline (#2a1a12). The tile behind each symbol is drawn in Luau (UICorner, a bright two-colour UIGradient, a thick dark UIStroke and a dark depth edge), so the same image works on any tile colour.
- `mockup/hud-mockup.png` and `mockup/parts-mockup.png`: the pictures Derek was asked to OK before building.
- `source/`: `icons.js` draws every symbol as SVG; `iconshot.cjs` renders them (`node iconshot.cjs <abs path>/icons-render.html <out dir>` with Playwright); `mockshot.cjs` renders the two mockups.

Derek OK'd the look on 2026-11-03 ("Build it as shown"; the crate was redrawn after his note "The crate img could use some work"). Uploaded the same night with `upload-image.yml` (run 41561146249, from this branch at e47082c). Each upload is a new asset, so a changed icon gets a new id, never a second upload of the same file.

| Icon | rbxassetid |
|---|---|
| Icon_Clean_Areas | 126370922327019 |
| Icon_Clean_Bag | 81699518945581 |
| Icon_Clean_Bowl | 80050724855728 |
| Icon_Clean_Cannon | 112726655919470 (redrawn 11-03 with a banded barrel and wooden carriage for #1024: upload pending) |
| Icon_Clean_Cats | 111022016391627 (redrawn 01:44; first upload 73281357166646 unused) |
| Icon_Clean_Caviar | 94374227160258 |
| Icon_Clean_Coin | 112195289471900 |
| Icon_Clean_Crate | 85523439563968 |
| Icon_Clean_Decor | 130851033023889 (redrawn 01:44; first upload 73990946688611 unused) |
| Icon_Clean_Feedback | 101390180819645 |
| Icon_Clean_Fish | 111395416488950 |
| Icon_Clean_Home | 102266682155402 (redrawn 11-03 as a cafe front for #1024: upload pending) |
| Icon_Clean_Index | 72904412280830 |
| Icon_Clean_Menu | 76526281703913 |
| Icon_Clean_Potion | 74312502748629 (redrawn 11-03 with glass, bubbles, cork and a sparkle for #1024: upload pending) |
| Icon_Clean_Quests | 120388931985566 |
| Icon_Clean_Rewards | 100352240603614 |
| Icon_Clean_Store | 125596282319075 (redrawn 01:44; first upload 133073738193868 unused) |
| Icon_Clean_Tutorial | 109885867788208 |
| Icon_Clean_Upgrades | 90691118878000 |
| Icon_Clean_Trade | new 11-03 for #1024 (two swap arrows, the HUD's Trade tile): upload pending |

Tile colours used in the mockup (top to bottom gradient): Cats #6fc0ff to #2f86ef, Index #7ae86f to #2fb043, Quests #ffe46b to #f5ac12, Upgrades #ffb15a to #f06a1d, Decor #62ecd2 to #18ab95, Store (a wide tile, first in the left column) #fff07a to #ffc61f to #ff8f1f with a white shine, Tutorial and Potions #cf96ff to #8a47ea, Rewards and Cannon #ff8a7a to #e4402f, Feedback and Areas #8fe3ff to #2bb3e6, Menu #c9d4e3 to #7f8fa6, My Cafe orange like Upgrades, Bait blue like Cats. Outline 4 px #2a1a12, corner 20 px on a 78 px tile, label 18 px Fredoka bold, white with a 5 px dark outline.

## #1024 redraw (friend's UI-Engineer, 2026-11-03)

Derek, live v181: "cafe and cannon simple still suck and potions", plus a missing Trade symbol. Home, Cannon and Potion were redrawn with more detail (awning and window, banded barrel on a wooden carriage, glass with bubbles), and Trade is new. Re-render only these with `node iconshot.cjs <abs>/icons-render.html <abs out dir> home,cannon,potion,trade`. They need a new upload (`upload-image.yml`, which only Derek's project runs) and then `asset-permissions.yml`. After that the new ids go in `games/cat-cafe/src/client/UI/Components/ShopIcons.luau`. The HUD Trade tile already asks for `ShopIcons.clean("Trade")` and keeps its glyph until the id is there.
