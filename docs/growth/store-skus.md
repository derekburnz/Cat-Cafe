# Store SKUs: card copy, spec and Creator Hub list (#1182)

Owner: growth-analyst. Draft 2026-11-04, refreshed 2026-11-05 for the friend's "start on monetization" (via the Coordinator). Prices come from `shop-and-pass-plan-2026-11-01.md` (library), relayed 2026-11-04. Extra Slot is R$149 (decided). Who does what:
- **UI-Engineer:** builds the cards (pass and product cards are in, hidden while an id is 0; #1240, #1248).
- **Gameplay-Engineer:** developer products (ProcessReceipt is in, #1207) and each effect.
- **The friend:** creates the products in Creator Hub. Passes are made by `game-passes.yml` from `passes.json` once each pass's code merges (decision 2026-11-02).

Rules every card follows (monetization-policy, decisions 2026-11-01 22:42):
- **Prices:** the price comes from Roblox at runtime, never typed into the card. A card shows "Soon" while off sale and "Owned" once bought.
- **Contents:** every card lists exactly what you get. Nothing is random.
- **Banned in any Robux item:** coins, golden fish, crates, spins, Lucky, Gold Rush and Quick Bait.
- **Launch week:** the old price is struck through next to the half price. No countdown, no "last chance", no pop-ups. The Store opens only when the player taps it.
- **Nothing is truly limited:** the shop cats stay on sale for good, and Cafe Pass season items come back later.
- **Store subtitle stays:** "Passes are yours to keep. Prices are in Robux."

## 1. Card copy and spec (UI-Engineer)

Card layout as today: picture, name, one effect line, an optional second line (what you have without it, or the contents), then the price button. Pictures are 512 x 512 PNG in the Cozy Cream style (`docs/art/style-guide.md`). Roblox shows pass and product icons cropped to a circle, so keep the subject inside the middle 80%. The same picture serves the card and the Creator Hub icon.

### Game passes (one-time, kept for good)

| Key | Card name | Effect line | Second line | Price (launch week) | Picture |
|---|---|---|---|---|---|
| money (exists) | 2x / 3x / 4x Money | "All your cafe's money x2." | (as now) | R$5 / 15 / 25 (no discount) | 💰 coin stack (exists) |
| longNap (exists) | Long Nap | "Away money at 100% for up to 16 h." | "Without it: 50% for up to 8 h." | R$199 (R$99) | 😴 cat asleep on a cushion (exists) |
| vip | VIP | "+10% money, a VIP chat tag and a gold VIP plate on your cafe sign." | | R$25 (R$12) | gold VIP plate with a paw |
| accessories | Cat Accessories | "Dress your cats: a dressed cat earns +15%." | | R$149 (R$74) | cat in a bow and little hat |
| uniforms | Uniform Styles | "New uniform styles for every job: +15% money." | | R$149 (R$74) | barista cat in a striped apron |
| cafeStyle | Cafe Style | "A new cafe theme and tag, +50% money, and rich visitors come 25% more often." | | R$249 (R$124) | cafe front in the new theme |
| grandTheme | Grand Cafe Theme | "The grand look: +150% money, twice the rich visitors, +1 job slot every tier." | | R$799 (R$399) | gold and cream grand cafe front |
| extraSlot | Extra Slot | "+1 job slot, so one more cat can work." | | R$149 (R$74) | an empty stool with a "+1" |
| royalCat | Royal Cat | "A cat that always earns like a Legendary from your newest area." | "Yours to keep. Can't be traded." | R$599 (R$299) | the Royal Cat with a small crown |
| kingPack | King Cat Pack | "The King Cat, who always earns like a Mythical from your newest area, plus the Royal Crest sign style." | "Yours to keep. Can't be traded." | R$999 (R$499) | the King Cat in a crown on a velvet cushion (unique model and effect) |

### Developer products (bought each time; ProcessReceipt is in, #1207)

| Key | Card name | Effect line | Contents line | Price (launch week) | Picture |
|---|---|---|---|---|---|
| starter | Starter Bundle | "A head start for a new cafe. Once per player." | "1 Sprinkles (the starter cat), 10 Big Money, 5 Swift, 1 Bakery Stripes sign style" | R$99 (R$49) | gift box with a cat, potions and a sign |
| potionXS | Potion Pack XS | "Big Money Potions: +50% money while they last." | "2 Big Money" | R$10 (no discount) | 2 gold potion bottles |
| potionS | Potion Pack S | "A small potion mix." | "3 Big Money, 1 Swift, 1 Steady Paw" | R$25 (R$12) | 5 bottles in a basket |
| potionM | Potion Pack M | "A potion mix." | "10 potions: 5 Big Money, 3 Swift, 2 Steady Paw" | R$49 (R$24) | crate of 10 bottles |
| potionL | Potion Pack L | "A big potion mix, with 2 bonus." | "22 potions: 10 Big Money, 6 Swift, 6 Steady Paw" | R$99 (R$49) | big crate with a bow |
| cafePass | Cafe Pass | "The paid track for this season: more prizes on every level." | "Season [n], [dates]. Pass XP comes from quests." | R$299 a season (R$149) | season badge |

Notes for UI-Engineer:
- **Money ladder:** keep it as one card.
- **Long Nap:** keep it as one card. Shop cats and themes show "Owned" once bought.
- **Starter Bundle:** hides itself once bought, since it's once per account. That's the only card that disappears.
- **Potion cards:** each shows the player's current potion count, so nobody buys blind.
- **Cafe Pass:** the card shows the season's end date as a plain date, never as a ticking countdown.
- **Order:** ladder, Long Nap, VIP, potion packs, Starter Bundle, then the rest by price. Nothing is pre-selected and nothing auto-opens.

## 2. Creator Hub list (paste-ready for the friend)

Name up to 50 characters. The descriptions avoid the word "game" and don't name the group. Launch prices are set and restored by workflow, so create everything at the regular price, **off sale**.

### Game passes (made off sale by `game-passes.yml` from `passes.json`; Derek OK'd placeholders on 11-04 and all 16 now exist, #1197. Put each on sale only once its code has merged)

```
VIP | R$25 | regional pricing on
+10% cafe money, a VIP chat tag and a gold VIP plate on your cafe sign. Yours to keep.

Cat Accessories | R$149 | regional pricing on
Dress your cats in bows, hats and more. A dressed cat earns +15%. Yours to keep.

Uniform Styles | R$149 | regional pricing on
New uniform styles for every cafe job, and +15% cafe money. Yours to keep.

Cafe Style | R$249 | regional pricing on
A new cafe theme and name tag, +50% cafe money, and rich visitors come 25% more often. Yours to keep.

Grand Cafe Theme | R$799 | regional pricing on
The grand cafe look: +150% cafe money, twice as many rich visitors and +1 job slot at every tier. Yours to keep.

Extra Slot | R$149 | regional pricing on
One more job slot in your cafe, so one more cat can work. Yours to keep.

Royal Cat | R$599 | regional pricing on
The Royal Cat joins your cafe and always earns like a Legendary from your newest area. Yours to keep, can't be traded.

King Cat Pack | R$999 | regional pricing on
The King Cat joins your cafe and always earns like a Mythical from your newest area, plus the Royal Crest sign style. Yours to keep, can't be traded.
```

### Developer products (the friend creates these, then the ids go in `Config`; ProcessReceipt is in, #1207)

```
Starter Bundle | R$99
A head start: 1 Sprinkles, 10 Big Money Potions, 5 Swift Potions and the Bakery Stripes sign style. Once per player.

Potion Pack XS | R$10
2 Big Money Potions (+50% cafe money while active).

Potion Pack S | R$25
3 Big Money Potions, 1 Swift Potion and 1 Steady Paw Potion.

Potion Pack M | R$49
10 potions: 5 Big Money, 3 Swift and 2 Steady Paw.

Potion Pack L | R$99
22 potions (20 + 2 bonus): 10 Big Money, 6 Swift and 6 Steady Paw.

Cafe Pass | R$299
The paid track for the current Cafe Pass season. Level up with quests to unlock its prizes.
```

## 3. Decided and still open

Decided 2026-11-04 (the friend, via the Coordinator, and the library plan):
- **Starter Bundle cat:** Sprinkles, a starter-only cat that earns like an Epic from the newest area (#1191, built in #1244). It is not the Bellhop Cat.
- **King Cat Pack:** the plan's Grand cat becomes the "King" whale item the friend remembers: the King Cat (earns like a Mythical, unique model and effect) plus the Royal Crest sign style, R$999. It's fixed, never random, always on sale, and can't be traded. Names and designs are on #1191: King Croissant and Royal Crest (built, #1289). The "Grand cat" in #1182's body is this pack; this file takes precedence.
- **Royal Cat** stays at R$599 (earns like a Legendary).
- **Pack mixes:** M is 5 Big Money, 3 Swift, 2 Steady Paw. L is 10 Big Money, 6 Swift, 6 Steady Paw.
- **Extra Slot:** R$149.

Still open:
1. **Stacking (economy check before build):** VIP, Accessories, Uniforms, Cafe Style and Grand Cafe all add money on top of the 4x ladder. The economy ladder modelled "about 24x" for a player with every paid bonus (economy-ladder.md). The game-designer should confirm the plan's numbers still match.
2. **PolicyService:** nothing here is random, so no odds screen is needed, and nothing bought can be traded. Gameplay-Engineer still reads `PolicyService:GetPolicyInfoForPlayerAsync` per player, as the monetization-policy skill asks, and confirms in review that no flag needs a card hidden.
3. **Names and models:** done on #1191: Sprinkles (starter cat, Epic), Duchess Marzipan (Royal Cat, Legendary), King Croissant (King Cat, Mythical) and the Royal Crest sign style. The Starter Bundle's sign style is Bakery Stripes (#1289); nothing is left to name.
4. **Derek's calls, 2026-11-05:**
   - **Private servers (#1000):** free for Premium members, R$50 to R$100 for everyone else (price to be picked inside that range).
   - **Second Bait Bowl (#1161):** sold for Robux, overriding growth's earlier advice. Derek's reading (later 2026-11-05): the pass is capacity, not a roll. It lets a player put food in two bowls instead of one; the food is still bought with coins, coins are not for sale, and the odds are the same as bowl 1. So it is not a paid random item and needs no `PolicyService` gate, odds card or off-sale hold. It goes on sale like any other pass. The one rule that keeps it that way: no Robux item may ever sell bait food, coins or anything that speeds or rerolls a bowl.
   - **Golden Pond (#1232):** stays convenience only at R$99 (decision 2026-11-05). `passes.json` still says "2x golden fish" at R$149 and must be corrected by Tools-Agent.
5. **Store FAQ:** "every cat is caught by playing" must change in the publish that first sells a shop cat (`store-page.txt`).
6. **Regional pricing** is off for every pass; turn it on before launch except the money ladder (#1197). All 16 items still use the default icon (pictures in section 1).
