# Store layout v2: hero card, bundle cards, New dots and Yours ticks (#1823, #1822)

Status: specced 2026-11-06, decided overnight under Derek2's go-ahead ("go with your recommended"). Design-Agent (friend's project) wrote it from Monetization-Agent's proposal (`/mnt/project-files/monetization/store-ux-and-king-bundle-2026-11-06.md`). Derek2 asked for a store that is "more enticing" and easier to buy from. The layout can be built now behind the owner test mode (#1774). The King Cat bundle's contents are in section 7. Builders: UI-Engineer (cards, tabs), Gameplay-Engineer (product data), Model-Agent (icons). monetization-policy applies throughout: fixed contents, nothing random, no fake countdowns, no guilt text and no pop-up on join.

## 1. The Featured tab

One hero card on top, then a row of three small cards (a 3 x 1 row on desktop and tablet, and a scroll row on phone).

- **Hero card** (full width, about 40% of the panel's height). It shows the bundle that fits the player: the Starter Bundle until it is bought, then the King Cat bundle. When both are owned, it shows the Cafe Pass. The left half is the main item's picture (the cat's portrait or the theme's preview), with the title in FredokaOne under it. The right half holds the contents row, the Worth line and the price button (section 2).
- **Small cards, in order:** the Cafe Pass (with "Season ends in X days", taken from the real season end in cafe-pass.md, never restarted), then the two best sellers from the last 7 days of sales. The growth thread fills that list. Until it has data, use 2x Money and Long Nap.
- Nothing slides or rotates by itself, and there's no auto-play carousel.

## 2. The bundle card

```
[ picture of the main item ]   King Cat Bundle            [Best Value]
                               (cat) (theme) (sign) (+1)
                               Worth R$1,450
                               [  R$999  ]
```

- **Contents row.** One 40 px round icon per item with no text, in the order main item, then theme or look, then extras. Tapping or hovering an icon shows a one-line tip ("Grand theme: a gold cafe look"). If there are more than four items, the row shows four and a "+N" chip that opens the full list.
- **One badge only,** at the top right. Use "Best Value" only when the Worth line is at least 25% above the price. Otherwise use no badge. "Most Popular" can only come from real sales data, and "Recommended" isn't used on bundles.
- **Worth line.** "Worth R$X" in the muted text colour, with no strike-through and no "% off". X is the sum of the parts' current Robux prices, read from MarketplaceService at runtime and never hard-coded. It's rounded down to the nearest R$5. A part that isn't sold alone counts at R$0. If any price fails to load, the line is hidden rather than guessed.
- **Price button = buy button.** One tap opens Roblox's own purchase prompt, with no extra confirm screen.
- An owned bundle shows its "Yours" state (section 4).

## 3. The Cats tab

The cat alone sits directly to the left of its bundle, on the same row, with the same height. Each cat card gets one plain line saying what it earns ("Earns like a Mythical"), taken from its Catalog rarity. Shop-only cats keep their #1490 looks.

## 4. New dots and Yours ticks

- **New dot.** A 10 px pink dot on a tab's top right corner when that tab gained an item since the player last opened it. Save it per player as `storeSeen = { [tab]: catalogVersion }`, with no version bump, as an optional field that defaults to empty. The dot also shows on the HUD Store button when any tab has one. Opening the tab clears it. There's no number on the dot and no pulsing.
- **Yours tick.** An owned pass, bundle or cat keeps its card, greyed to 60%, with a green tick and "Yours" where the price button was. Consumables (potions, spins) never show it. A bundle whose parts are all owned shows "Yours". One with only some parts owned stays buyable, and its Worth line counts only the parts not yet owned. If those parts are worth less than the price, the badge is dropped.

## 5. Icons needed (Model-Agent, one 256 px render each, on the store's icon background)

Theme icons: Garden Cafe and Grand Cafe (a tiny cafe front in each palette). Sign icon: the crown sign. Cat icons: the King Cat and Royal Cat portraits (they already exist from #1490, so reuse them). Extras, once Derek2 picks them: a Money Potion set (three bottles), a decor piece (its own preview), and a cat accessory (the hat or glasses from store-pass-looks.md section 6). Name them `Ui_Store_Icon_<Name>`.

## 6. QA checks

1. A new account sees the Starter Bundle as the hero card. After buying it, the hero becomes the King Cat bundle without a rejoin.
2. The Worth line equals the sum of the live part prices, rounded down to R$5, and is hidden when a price fetch fails.
3. No card has more than one badge, and "Best Value" appears only when the Worth line is at least 1.25 times the price.
4. An owned pass shows "Yours" and greyed out, with no buy prompt. Owning one part of a bundle lowers its Worth line.
5. A New dot shows after a catalog change and clears when the tab is opened. It never comes back for the same change.
6. The phone, tablet and desktop scenes pass the UI gate. Nothing in the store moves by itself or counts down except the real season end.

## 7. The King Cat bundle (#1822, decided overnight 2026-11-06 under Derek2's go-ahead)

- **Same pass, same price.** `KingPackPassId` 2071368679, R$999 (R$499 in launch week). No new product.
- **Contents, in icon order:** the King Cat, the Grand Cafe theme, the Royal Crest crown sign, one decor piece and one allowed potion set. Gameplay-Engineer picks the decor piece and potion set from items that already exist, and they stay fixed. A buyer who already owns the Grand theme pass keeps it, and the bundle's Worth line counts only the parts they don't have (section 4).
- **Badge:** "Best Value" when the live Worth reaches 1.25 x the price, which it should for a new buyer once the King Cat sells alone at R$799, since the Grand theme is a pass of its own.
- **The King Cat alone** in the Cats tab: R$799 (R$399 in launch week), on a new pass that Derek2 creates by hand. Its card stays hidden until `KingCatPassId` is set in Config. Until then the cat counts at R$0 in the Worth line (section 2: a part not sold alone), so the badge may be missing at first. That's honest, and it fixes itself once the pass exists.

## 8. Featured order, half prices and the Sale badge (Derek, 2026-11-12; #3562, #3572)

Derek: "make the featured bundles better as it shows bad packs right now never show potion bundles unless they are only thing left, should focus on cats bundles 2x money being cheap etc", then "make the prizes of anything not being bought yet half'd" and "put a sale badge on it also rework the store with model agent". This section replaces the pick order in section 1. Not built yet.

**Featured order (#3562).**
- Hero, first one not owned: Starter Bundle, Royal Cat, King Cat Pack, Cafe Pass (while a season runs), Grand Cafe Theme.
- Three picks, first three not owned and not the hero: the money ladder's next step (2x Money first, the cheapest item and the best seller), Royal Cat, King Cat Pack, Second Bait Bowl, Extra Slot, VIP, Long Nap, Cafe Pass, then the other passes.
- Potion packs show on Featured only when every pass and every other product is owned. They stay on the Potions tab.
- A card that is off sale or has no price yet is skipped. No badges other than Sale, no timers, nothing pre-selected.

**Half prices (#3572).** Only items that had not sold by 2026-11-12, by Growth-Agent's read. Sales counts are kept in the private Library, not here.

| Robux item | Was | Now |
|---|---|---|
| Golden Pond | 99 | 49 |
| Extra Slot | 149 | 75 |
| Uniform Styles | 149 | 75 |
| Cafe Style | 249 | 125 |
| Royal Cat | 599 | 299 |
| King Cat | 799 | 399 |
| Grand Cafe Theme | 799 | 399 |
| King Cat Pack | 999 | 499 |
| Potion Pack XS | 10 | 5 |
| Potion Pack S | 25 | 13 |
| Potion Pack M | 49 | 25 |
| Potion Pack L | 99 | 49 |
| Steady Paw Pack | 25 | 13 |
| Thank You Badge | 25 | 13 |
| Cafe Pass | 299 | 149 |

Potion Pack L had sold, and Derek halved it too so the bigger pack is never the worse deal. Unchanged because they are selling: 2x, 3x and 4x Money, VIP, Long Nap, Cat Accessories, Second Bait Bowl, Garden Decor Pack, Sign Style Pack and the Starter Bundle. The Jukebox Pass is off sale. Managed pricing stays on in Creator Hub (Derek).

In golden fish only the Fresh Catch shelf halves (rewards-and-shops.md section 3). Crates, perks, the Backpack and the Long Net are being bought and stay. **Crates are never halved without a look at duplicate refunds:** a duplicate piece refunds 10 to 150 golden fish, about 18 a crate on average at normal odds, so a crate at 20 would nearly pay for itself.

**Sale badge.**
- On the halved items only. The card shows a "Sale" tag, the old price struck through and the new price. The button shows the new price.
- It has to be true: the old price is the real price of 2026-11-12, kept in `Config.StoreWasPrice`. If the live price is not the half price, no badge and no old price show.
- It shows for 30 days from the day the prices change, then comes off and the half price is simply the price. No end date is shown.
- A static tag. No countdown, no "ends soon", no flashing.

**Layout rework.** Mock OK'd by Derek: `Model-Agent/store-rework-3572/store-rework-3572.png`. Left rail Featured, Cats, Passes, Potions, Cafe Pass, Codes. Two columns on a phone, a picture on every card, a green "Yours" tick on owned cards, the money ladder as one card with its next step. Same family as the station menus (#3558). A card's line must say what the item really does (the Golden Pond collects from anywhere, it does not make more fish).

