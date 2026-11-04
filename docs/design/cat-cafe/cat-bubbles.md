# Speech bubbles on the town's key cats (#1079)

Proposed 2026-11-04 by Design-Agent (friend's project), from Derek's live check the same day: when the player walks near the spin cat and a few other key cats, a small bubble over the cat says one short line, and it fades when they walk away. Derek: "don't make tedious menus that are annoying to get through." Owner: game-designer. Readers: UI-Engineer, Gameplay-Engineer, Model-Agent, sound-designer, QA.

## 1. Which cats, and their lines

Seven cats, one line each. Each line says what the station does in a few words, never asks for anything and never hurries the player.

| cat (station tag) | where | line | shows when |
|---|---|---|---|
| The Spin Wheel's cat (`SpinWheel`) | Town Square | "Got a spin? Give the wheel a whirl!" | always |
| The Fish Market's shopkeeper (`FishMarket`) | Town Square | "Crates, treats and fresh potions!" | always |
| The Codes Cat (`CodesCat`) | Town Square | "Got a code? Tell me here!" | always |
| The Bellhop Cat at its stand (`BellhopStand`) | Town Square | "A free cat for your cafe!" | only until the player has claimed it |
| The night dealer (`DealerCart`) | the street, at night | "Rare foods here every night!" | only while the cart is in town |
| The Cat Collector (`CatCafe_NPC_Collector`) | at the player's cafe, on a visit | "Got a cat I'm looking for?" | only while he is visiting |
| The Corner Shop's cat (`CornerShop`) | Town Square, once built (#1052) | "Snacks, bubbles and fireworks!" | always |

- If the Spin Wheel model has no cat yet, Model-Agent adds a small cat sitting on its base (`CatCafe_Street_SpinWheel`, a child model `WheelCat`), because the bubble needs someone to say it.
- No bubble on customers, strays, the player's own cats or the Mystery Visitor. Keeping the list short keeps the bubbles special and the square calm.
- A new station gets a line here first (one row, under 36 characters), so the voice stays the same.

## 2. How a bubble behaves

- **Proximity only.** A bubble fades in (0.2 s) when the player's character comes within `CatBubbleShowStuds` (12) of the cat, and fades out (0.3 s) beyond `CatBubbleHideStuds` (16). The gap between the two stops it flickering at the edge. No tap, no prompt and no window: it is only text.
- **One at a time.** Only the nearest cat in range shows its bubble. Walking from the wheel to the Market swaps one for the other, so bubbles never stack.
- **Not every time.** Once a bubble has faded out, that cat stays quiet for `CatBubbleRepeatSeconds` (60) even if the player comes back, so walking around the square does not chatter.
- **Out of the way.** It is a `BillboardGui` on an attachment `BubbleAnchor` above the cat's head (Model-Agent adds it; without one, 1.5 studs above the model's top). It is sized in studs, not pixels, so it never grows to cover the screen up close, it is never `AlwaysOnTop` (walls hide it), and it never sits in HUD space. It hides while any window is open, during a catch, while carrying a cat and in the intro.
- **Look.** The Cozy Cream bubble: a cream rounded box with a 2 px cocoa outline and a little tail pointing at the cat, cocoa text in the HUD font at one size, one line, at most 36 characters. Reduce Motion drops the pop and keeps a plain fade.
- **Sound.** One soft "mrrp" from the cat when its bubble shows, quiet and in the SFX group, and never more often than the 60 s rule. The sound-designer picks it, or leaves it silent if nothing fits the mix.
- **Text.** The lines are ours and fixed, so no filtering is needed. Nothing a player types ever shows in a bubble.

## 3. Contracts

- **Config:** `CatBubbleShowStuds` 12, `CatBubbleHideStuds` 16, `CatBubbleRepeatSeconds` 60.
- **Catalog:** `Catalog.catBubbles` rows `{ tag, text, when = "always" | "unclaimedBellhop" | "dealerHere" | "collectorVisiting" }`, the seven in section 1.
- **Client only.** No remote and no save. `Screens/CatBubbles.luau` (UI-Engineer) finds the tagged stations with `CollectionService`, checks the distance on a 0.25 s step (not every frame), and reads the `when` states from what the client already has: the Bellhop claim from ProfileSync, the dealer's cart from the night clock, the Collector from his visit.
- **Models (Model-Agent):** a `BubbleAnchor` attachment on each of the seven cats, and the `WheelCat` if the wheel has none.
- **Who builds:** UI-Engineer (the screen and the look), Model-Agent (anchors and the wheel cat), sound-designer (the "mrrp", optional), QA (section 4).

## 4. QA checks

1. Walking up to the Spin Wheel shows its line within 12 studs, and walking away hides it past 16; standing at 14 does not flicker.
2. Between the wheel and the Market, only the nearer cat's bubble shows.
3. Coming back to the wheel within 60 s of leaving shows no bubble; after 60 s it shows again.
4. A player who has claimed the Bellhop Cat never sees its bubble; the dealer's bubble shows only at night while the cart is in town.
5. With a window open, during a catch or while carrying a cat, no bubble shows. Up close the bubble stays small and never covers the HUD, and a wall between the player and the cat hides it.
6. On a phone (roblox-mobile-playtest) the line is readable at 12 studs and fits on one line.
