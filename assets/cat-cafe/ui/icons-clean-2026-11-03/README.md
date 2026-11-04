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
| Icon_Clean_Cannon | 134222859642759 (redrawn 11-03 with a banded barrel and wooden carriage for #1024; first upload 112726655919470 replaced) |
| Icon_Clean_Cats | 111022016391627 (redrawn 01:44; first upload 73281357166646 unused) |
| Icon_Clean_Caviar | 94374227160258 |
| Icon_Clean_Coin | 112195289471900 |
| Icon_Clean_Crate | 85523439563968 |
| Icon_Clean_Decor | 130851033023889 (redrawn 01:44; first upload 73990946688611 unused) |
| Icon_Clean_Feedback | 101390180819645 |
| Icon_Clean_Fish | 111395416488950 |
| Icon_Clean_Home | 128704819455880 (redrawn 11-03 as a cafe front for #1024; first upload 102266682155402 replaced) |
| Icon_Clean_Index | 72904412280830 |
| Icon_Clean_Menu | 76526281703913 |
| Icon_Clean_Potion | 92456971844930 (redrawn 11-03 with glass, bubbles, cork and a sparkle for #1024; first upload 74312502748629 replaced) |
| Icon_Clean_Quests | 120388931985566 |
| Icon_Clean_Rewards | 100352240603614 |
| Icon_Clean_Store | 125596282319075 (redrawn 01:44; first upload 133073738193868 unused) |
| Icon_Clean_Tutorial | 109885867788208 |
| Icon_Clean_Upgrades | 90691118878000 |
| Icon_Clean_Wallpaper | 102259047705880 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Floor | 100560850589029 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Paint | 88844625138910 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Spots | 74579562921955 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Door | 82896268186640 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Catflap | 99900172207666 (#964, 11-03 22:13, run 41728803377) |
| Icon_Clean_Trade | 86243209880722 (new 11-03 for #1024: two swap arrows, the HUD's Trade tile) |
| Icon_Clean_PotionTip | 86488148454995 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionLucky | 105359839986454 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionSwift | 123223898814902 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionSteady | 121053101784702 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionBigTip | 89235368935178 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionGoldRush | 117084495995856 (#1070, 11-04, run 41840327151) |
| Icon_Clean_PotionQuickBait | 103272653422076 (#1070, 11-04, run 41840327151) |
| Icon_Clean_Tuna | 128749627858421 (#1070, 11-04, run 41840327151) |
| Icon_Clean_Salmon | 78789450804337 (#1070, 11-04, run 41840327151) |
| Icon_Clean_Sardines | 133035243124941 (#1070, 11-04, run 41840327151) |
| Icon_Clean_MoonMilk | 107176560784324 (#1070, 11-04, run 41840327151) |
| Icon_Clean_StarTreat | 127060767808144 (#1070, 11-04, run 41840327151) |
| Icon_Clean_Spin | 126057350997233 (#1070, 11-04, run 41840327151) |
| Icon_Clean_EquipBest | 89501318892947 (#1136, 11-04, run 41889328270) |
| Icon_Clean_Invite | 136442901295833 (#1136, 11-04, run 41889328270) |
| Icon_Clean_Lock | 133489571923895 (#1136, 11-04, run 41889328270) |

Tile colours used in the mockup (top to bottom gradient): Cats #6fc0ff to #2f86ef, Index #7ae86f to #2fb043, Quests #ffe46b to #f5ac12, Upgrades #ffb15a to #f06a1d, Decor #62ecd2 to #18ab95, Store (a wide tile, first in the left column) #fff07a to #ffc61f to #ff8f1f with a white shine, Tutorial and Potions #cf96ff to #8a47ea, Rewards and Cannon #ff8a7a to #e4402f, Feedback and Areas #8fe3ff to #2bb3e6, Menu #c9d4e3 to #7f8fa6, My Cafe orange like Upgrades, Bait blue like Cats. Outline 4 px #2a1a12, corner 20 px on a 78 px tile, label 18 px Fredoka bold, white with a 5 px dark outline.

## #1024 redraw (friend's UI-Engineer, 2026-11-03)

Derek, live v181: "cafe and cannon simple still suck and potions", plus a missing Trade symbol. Home, Cannon and Potion were redrawn with more detail (awning and window, banded barrel on a wooden carriage, glass with bubbles), and Trade is new. Re-render only these with `node iconshot.cjs <abs>/icons-render.html <abs out dir> home,cannon,potion,trade`. Uploaded 11-03 with `upload-image.yml` (run 41649292093); the ids above are in `games/cat-cafe/src/client/UI/Components/ShopIcons.luau`. `asset-permissions.yml` still has to run for the group-owned game before the pictures show in the live game.

## #1136: Equip Best, Invite and Lock (Derek's UI-Engineer, 2026-11-04)

Derek, live v187: live still shows "the old images on ui buttons". These were the last three glyphs that drew the 2026-10-27 icon sheet (`Theme.iconSheet`): Equip Best is a big gold sparkle with a white and a blue one, Invite a white envelope with a pink heart seal, the lock a gold padlock with a grey shackle. Where they show: the Equip Best buttons (Cats and Decor windows, Button's inline `image`), the Invite row in the Menu list and the Invite ask card, and the lock badges on the Areas cards and locked cat cards. A 🔒 inside a sentence ("🔒 Locked") or on a staff slot square stays the emoji. Group Use permission: `asset-permissions.yml` grant runs on main once this merges. `mockup/preview-1136.png` (from `source/preview-1136.html`) shows them on HUD tiles beside Rewards and Feedback. Re-render with `node iconshot.cjs <abs>/icons-render.html <abs out dir> equipBest,invite,lock`.
