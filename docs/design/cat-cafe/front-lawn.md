# Front lawn decorations (F91)

Status: proposed by the game-designer thread, 2026-11-01. From Derek's ask of 2026-10-30 23:30: "Consider also adding decorations for the front lawn /infront of the cafe for more unique looking cafe's also". It also answers his 2026-10-31 point that the cafe has "not as much customization for the cafe as restaurant tycoon". In the decision memo's plan this is the second weekly update after launch.

## 1. What the player gets

The front garden strip (`Layout.cafe.frontGarden`, 5 studs deep across the 38 stud plot front, with the 5 stud path to the door in the middle) becomes a lawn the player dresses. Everything in it shows from the street, so it is how a cafe looks different from its neighbours.

- **Lawn spots.** Six fixed spots, three on each side of the path. Each side has one big spot (about 4 by 4 studs, nearest the street) and two small spots (about 2 by 2, one by the front wall and one beside the path). Tier 1 opens the two small spots beside the path, Tier 2 the two big spots and Tier 3 the two by the front wall.
- **Path style.** One at a time, from Tier 1: Grey Slabs (the default), Red Brick, Stepping Stones and the Paw Print Path.
- **Fence style.** One at a time along the sidewalk edge, with a gap at the path, from Tier 1: no fence (the default), White Picket, Low Hedge, Iron Railing and the Flower Box Fence.
- **The Lucky Cat** (F88) keeps its own place by the front door and never takes a lawn spot.

## 2. Bought with coins, chosen freely

Lawn pieces are bought with coins in the Decor screen's new Front lawn tab, so the player picks exactly what they want. That is the Restaurant Tycoon kind of customization the crates cannot give, and a steady coin sink. They give no tip bonus, like today's coin-shop decor, so the lawn is about looks and never about balance. Rare lawn pieces from crates can come later; v1 keeps the crates' odds as they are.

| Piece | Spot | Tier | Price | Note |
|---|---|---|---|---|
| Tulip Bed | small | 1 | 500 | red and yellow tulips |
| Sandwich Board | small | 1 | 500 | chalk menu; shows the newest menu item from F90 when it ships |
| Potted Cat Topiary | small | 1 | 1,000 | a hedge trimmed into a sitting cat |
| Mailbox | small | 1 | 1,000 | its flag pops up when a bait cat is ready |
| Lamp Post | small | 2 | 3,000 | glows at night |
| Bird Bath | small | 2 | 3,000 | a bird hops on and off by day |
| Garden Gnome Cat | small | 2 | 5,000 | a nod to the Gnome Cat |
| Bicycle with Basket | big | 2 | 8,000 | flowers in the basket |
| Garden Bench | big | 2 | 8,000 | a roaming cat naps on it sometimes |
| Umbrella Table | big | 3 | 25,000 | one customer may sit outside with their order |
| Little Fountain | big | 3 | 40,000 | water that moves |
| Fairy Light Arch | big | 4 | 150,000 | an arch of lights, glowing at night |
| Flower Cart | big | 4 | 200,000 | a cart of potted flowers |
| Balloon Bunch | small | 4 | 100,000 | balloons that bob in the wind |
| Cat Tree Sign | big | 5 | 1,000,000 | a tall sign shaped like a cat tree with the cafe's name |
| Golden Paw Statue | big | 5 | 3,000,000 | a big gold paw on a plinth that glints |

| Style | Kind | Tier | Price |
|---|---|---|---|
| Grey Slabs | path | 1 | free |
| Red Brick | path | 1 | 2,000 |
| Stepping Stones | path | 2 | 10,000 |
| Paw Print Path | path | 3 | 50,000 |
| White Picket | fence | 1 | 2,000 |
| Low Hedge | fence | 2 | 10,000 |
| Iron Railing | fence | 3 | 50,000 |
| Flower Box Fence | fence | 4 | 200,000 |

Prices follow the tier's wallet: a Tier 1 piece is about a minute or two of income, a Tier 5 piece a few minutes of a late cafe's. QA's pace model can check them against data-model section 11.

## 3. How it is placed

- The Decor screen gets a Front lawn tab with Shop and Mine rows. "Edit lawn" swings the camera to a view of the cafe front (the edit view) and shows a ring on each open spot.
- Tapping a ring opens a picker of owned pieces that fit that spot, with the shop's pieces below; buying one places it there. "Clear" empties the spot and keeps the piece. A piece can stand in one spot at a time and moves by placing it in another.
- Path and fence styles are chips at the top of the tab, like the wallpaper chips.
- Leaving the edit view or walking off puts the camera back.
- Each piece and style appears with the purchase sparkle that buying already plays.

## 4. Look and budget

- Every piece meets the decor quality bar in luck-and-rare-moments.md section 2c at the Rare row or better, since the whole street sees them. The Tier 4 and 5 pieces meet the Legendary row.
- The moving touches are cheap and few: the lamp and lights glow only at night, the bird, balloons and fountain run only within 40 studs of the camera, and Low performance mode shows them still.
- A full lawn is about 1,500 triangles at most, so eight full lawns on a street stay inside the street's budget.

## 5. Contracts

- Catalog: `Catalog.lawn` (`{ id, name, spot = "small" | "big", tier, price, model }`) and `Catalog.lawnStyles` (`{ id, kind = "path" | "fence", tier, price, model }`).
- Layout: `Layout.cafe.lawnSpots`, six `{ id, size, tier, x, z, rotY }` in plot space; `Layout.cafe.fenceLine` along the sidewalk edge with the path's gap.
- Profile (next save version): `lawnOwned` (map piece or style id to true), `lawn` (map spot id to piece id), `lawnStyles` (`{ path, fence }`).
- Remotes: `BuyLawn(id)` 2 per second, at the player's own plot, checks tier and coins and logs a coin sink `lawn`; `SetLawnSpot(spotId, pieceId?)` 4 per second, the spot open at the player's tier, the piece owned and the right size; `SetLawnStyle(kind, id)` 2 per second.
- Plot attributes, display only, so every client builds the lawn: `Lawn_<spotId>` (piece id), `LawnPath`, `LawnFence`.
- Analytics: the `lawn` sink in the economy events; `lawn_placed` (value 1, fields piece id, tier) to see which pieces people pick.
- Who builds: Model-Agent (16 pieces, 4 paths, 4 fences, drafted on one sheet for Derek first), Gameplay-Engineer (catalog, remotes, save, attributes, building the lawn), UI-Engineer (the tab, edit view, rings and picker), VFX-Agent (night glows and the small moving touches), QA-Planner (section 6).

## 6. QA checks

1. A Tier 1 player sees two open rings, buys a Tulip Bed and places it; a second player on the street sees it.
2. A big piece will not go in a small spot; a piece moved to another spot leaves the first one empty.
3. Path and fence styles change for everyone; the fence leaves the path open.
4. A Tier 2 piece cannot be bought at Tier 1, and the server refuses a forged `BuyLawn` with too few coins.
5. At night the Lamp Post and the Fairy Light Arch glow; in Low performance mode nothing on the lawn moves.
6. Eight full lawns on one street keep the frame rate on a phone.
