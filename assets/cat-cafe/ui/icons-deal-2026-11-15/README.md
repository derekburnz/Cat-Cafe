# Today's Deal pictures (#4246)

Four 512 square pictures for the Today's Deal cards, transparent, art at about 85% of the square with a dark rim so
they read at 52 px on a phone. No words or numbers: the card says the amount.

| File | Deal | Roblox image |
|---|---|---|
| `CatCafe_Icon_Deal_Fish.png` | 250 Golden Fish | `rbxassetid://77754066053264` |
| `CatCafe_Icon_Deal_Tokens.png` | Trait Tokens | `rbxassetid://120509351245250` |
| `CatCafe_Icon_Deal_Crates.png` | Golden Crates | `rbxassetid://109305006896317` |
| `CatCafe_Icon_Deal_Haul.png` | Golden Haul (crates and fish) | `rbxassetid://127676563860297` |

`src/deal.py` builds them from the cut-outs beside it (`CatCafe_Prop_FishCoin` and `CatCafe_Prop_Crate_Classic_Gold`
rendered from `assets/cat-cafe/rbx`); the tokens are drawn in the token look (violet face, dark edge, cream star).
Run `python3 src/deal.py <out folder>`. Uploaded 2026-11-15 with `upload-image.yml`; the card reads the ids from `ShopIcons.luau` (#4246).

#5120 (2026-11-17): re-uploaded group owned (Creampuff Games); the ids above are the group copies. Derek saw the deal pictures as gray boxes with the Nov 15 copies, which were on his own account.
