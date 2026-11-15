# Today's Deal pictures (#4246)

Four 512 square pictures for the Today's Deal cards, transparent, art at about 85% of the square with a dark rim so
they read at 52 px on a phone. No words or numbers: the card says the amount.

| File | Deal |
|---|---|
| `CatCafe_Icon_Deal_Fish.png` | 250 Golden Fish |
| `CatCafe_Icon_Deal_Tokens.png` | Trait Tokens |
| `CatCafe_Icon_Deal_Crates.png` | Golden Crates |
| `CatCafe_Icon_Deal_Haul.png` | Golden Haul (crates and fish) |

`src/deal.py` builds them from the cut-outs beside it (`CatCafe_Prop_FishCoin` and `CatCafe_Prop_Crate_Classic_Gold`
rendered from `assets/cat-cafe/rbx`); the tokens are drawn in the token look (violet face, dark edge, cream star).
Run `python3 src/deal.py <out folder>`. The Roblox image ids are in `ShopIcons.luau`.
