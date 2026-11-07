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

## 6. Cat Accessories (#1624, agreed with Gameplay-Engineer 2026-11-05)
- **One pick for the whole cafe**, like the uniform style, on the Style panel. Every working cat wears it. There are no per-cat picks; they'd be a chore with 12 slots.
- **The pass gives two pieces:** Tail Bow (`CatCafe_Accessory_TailBow`, Tail) and Round Glasses (`CatCafe_Accessory_Glasses`, Face). The Tail Bow replaced the Tiny Hat on 2026-11-07 (#2109, see 6a). Cafe Pass pieces (cafe-pass.md §3) join the picker once earned, as looks only.
- **Slot rule** (data-model.md props): a Head piece replaces the role hat, a Back piece replaces the Cape, and a Face piece clashes with nothing. A cat whose own themed prop already fills that slot keeps its prop and skips the accessory.
- **Money:** the +15% comes with the pass and applies to every working cat, whatever is picked, even "none" (economy-ladder.md §6a). The picker never changes income.

### 6a. Tail Bow replaces the Tiny Hat (#2109, 2026-11-07)
Derek2 asked for a piece that shows on every cat. A cat's own themed prop takes the Head slot on 65 of the 125 working cat models, so the Tiny Hat was skipped on about half the cafe. No existing slot is free on every cat. Derek2 also turned down letting accessories win over a cat's own prop.
- **The piece:** a **Tail Bow**, a small satin ribbon tied near the tip of the tail. It's cafe rose pink with a cream edge (style guide palette), and it's sized so it reads at cafe camera distance without hiding the tail. Id `CatCafe_Accessory_TailBow`, slot **Tail**, a new slot that no themed prop uses, so it shows on every working cat. It isn't a collar, so it fits Derek's no-collars rule.
- **Model-Agent:** builds the bow and adds an `Outfit_TailBow` attachment near the tail tip on every cat model, the same way as the existing `Outfit_<Slot>` attachments. The bow follows the tail's pose, so it has no animation of its own and no Reduce Motion case.
- **Slot rule:** the Tail slot clashes with nothing, like Face. If a future themed prop ever uses the Tail slot, the usual rule applies and the cat keeps its prop.
- **Saved picks:** a saved pick of `hat` (the Tiny Hat) is read as `tail_bow` on load, so nobody is left with an empty or broken pick, and nothing is refunded or removed. The Tiny Hat leaves the picker. `CatCafe_Accessory_Hat` can stay in the asset folder unused.
- **Store text:** any mention of "Tiny Hat" in the pass's store description becomes "Tail Bow" (Tools-Agent, `passes.json`). The pass's price, the +15% and Round Glasses don't change.
- **Builders:** Gameplay-Engineer (Looks: the slot, the id and the `hat` to `tail_bow` read, with tests), Model-Agent (the bow and the attachments), Tools-Agent (store text), UI-Engineer (picker label and icon).
- **QA:** with Tail Bow picked, every working cat in the cafe wears it, including cats with a Head or Back prop. An account that saved the Tiny Hat sees Tail Bow picked after rejoining. "None" removes it.
