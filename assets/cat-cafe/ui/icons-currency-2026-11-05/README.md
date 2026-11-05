# Currency icons (2026-11-05, #1253)

Derek, 11-04: the golden fish icon "somehow got worse" in v197, and both currency symbols need a full rework. These replace the flat clean symbols in the same style (256 x 256, transparent, thick #2a1a12 outline), with gold shading, a shine and a tight crop, so they still read at text height:

- `Icon_Clean_CoinGold.png`: the money coin beside the money counter and prices, with an embossed $ and a small sparkle on the rim.
- `Icon_Clean_FishGold.png`: the golden fish currency, a chunky gold fish with an eye, scales and fins.
- `Icon_Clean_BagGold.png`: the money bag on prize tiles and rewards, a green sack with the new gold coin on it.

`compare-sheet.png` shows the v196 fish, the current (v197+) icons and the new ones at the real sizes they're used at: a 30 px HUD counter, an 18 px price row and a 48 px prize chip.

**Status: waiting for Derek's OK on the sheet.** After the OK, Tools-Agent uploads them with `upload-image.yml` and grants them, and UI-Engineer points `Theme.textures.fishCoin`, the money coin (`ShopIcons` Coin) and the money bag (`Icon_Clean_Bag`) at the new ids.

`source/`: the SVGs, `render.cjs` (`node render.cjs <abs svg dir> <abs out dir>`, Playwright), and `sheet.py` plus `shot.cjs` for the sheet.
