# Store pass looks: VIP plate, uniform styles and the two cafe themes (#1624)

Status: game-designer thread (Design-Agent, friend's project), 2026-11-05, for Model-Agent (#1637) and UI-Engineer. The colours come from the Cozy Cream palette in `docs/art/style-guide.md`. A new swatch goes into the style guide first (asset-artist's file), then into the assets. Every look here is cosmetic, and its money effect lives in economy-ladder.md §6a.

## 1. VIP plate
A small gold plate with a paw on it, under the cafe name on the sign. It's a separate part, `CatCafe_Sign_VipPlate`, that shows only for an owner. It doesn't glow or animate.

## 2. Uniform Styles
**Recolours of the existing role pieces** (BaristaCap, Boater, PartyHat, apron, Entertainer Cape), so no new meshes are needed. Three styles that every job can switch between: Striped (cream and caramel stripes, the Store picture), Midnight (navy with gold trim) and Mint (mint with cream trim). The season colours in cafe-pass.md §3 use the same recolour slot. The player picks a style for the whole cafe on the cafe's Style panel.

## 3. Cafe Style theme ("Garden Cafe")
- **Palette:** sage green, warm white, terracotta, with brass touches.
- **Outside:** a sage awning in place of the default one, terracotta planters with small flowers either side of the door, a hanging brass lamp, and a sage sign with the cafe name. The walls and building shape stay the same.
- **Inside:** a light recolour. Wall trim goes sage, tables get terracotta pots with a sprig, and a leafy garland runs over the counter. Placed decor and furniture are untouched.
- **Tag:** "Garden" plate on the sign.

## 4. Grand Cafe Theme
- **Palette:** gold and cream (the Store picture), deep plum accents.
- **Outside:** a tall gold-trimmed cream front with two columns by the door, a plum and gold striped awning, a gold-framed sign, two lantern posts and a short red-plum carpet at the door. It's a bigger change than Garden but keeps the same footprint, so plots and the door don't move.
- **Inside:** gold trim on the walls and counter, a small chandelier over the middle, and plum cushions on the chairs. Placed decor is untouched.
- **Tag:** "Grand" plate on the sign, in gold.

## 5. Rules for both themes
- A player who owns both picks one on the Style panel; default, Garden or Grand. The money bonus stays on whichever theme shows.
- Themes swap parts on the cafe model (`CatCafe_Theme_Garden`, `CatCafe_Theme_Grand` folders under ReplicatedStorage.Assets), and the server sets a `Theme` attribute on the plot. Nothing changes collision, the door, the camera or a station's position.
- Other players see the owner's theme, so it's a status look that never blocks anyone.
