# Purchase edge cases: what the code does, what is tested, what is left (2026-11-07, #2118)
Owner: growth-analyst (Monetization-Agent), with Gameplay-Engineer on any code change. Read from `main` at 724daa3:
`ProductService.luau`, `shared/Products.luau`, `PassService.luau`, `DataService.luau`, `ProfileSchema.luau`.
Specs: `tests/specs/PurchaseEdgeCases.spec.luau` (new, pure steps) beside `Products.spec.luau` and `CafePass.spec.luau`.

Two kinds of buy, because they fail differently:
- **Developer products** (potion packs, Steady Paw pack, Starter Bundle, Thank You Badge, Cafe Pass): Roblox calls `ProcessReceipt` on the server and keeps calling it until the answer is `PurchaseGranted`. We grant once per `PurchaseId`, then answer `PurchaseGranted` only after a save that holds the id.
- **Game passes** (Money, Long Nap, slots, King Cat and the rest): nothing is saved. Ownership is read from Roblox at join (`UserOwnsGamePassAsync`) and after a purchase.

## The cases
| # | Case | What the code does | Covered by | Result |
|---|---|---|---|---|
| 1 | Product bought, save fails | The prize is paid in memory the moment the id is recorded. The answer stays `NotProcessedYet` (waits 30 s for a save holding the id), so Roblox delivers it again. | spec "pays a receipt that was never saved"; Studio S1 | Pays once, not zero and not twice |
| 2 | Product bought, player leaves at once | No player in the server: `NotProcessedYet`. At the next join the id is not in the save yet, so it pays then. If the leave save did hold the id, the redelivery finds it and pays nothing. | specs "never saved" and "keeps the receipt"; Studio S2 | OK |
| 3 | Rejoin: ownership | Products: the id, `onceBought` and `signStyles` come back from the save. Passes: re-read from Roblox, nothing from the save. | specs "keeps the receipt", "keeps the once-per-account mark"; Studio S3 | OK |
| 4 | Refund | Roblox does not tell the game about a product refund, so nothing is taken back (Starter Bundle cat and potions stay). A refunded pass is gone at the next join, because it is never saved. | Studio S5 (only a person can refund) | Needs a Studio look; see F3 |
| 5 | Same receipt twice | The id is recorded before the prize, with no yield, so two deliveries (even at the same moment) pay once. | specs "once per PurchaseId", "two different PurchaseIds"; Studio (Laptop-Tester): resent id, two at once, new id | OK, passed in Studio |
| 6 | DataStore down | At join the profile does not load: the player is kicked and nothing can be bought. Mid-session, saves retry; the receipt waits, then Roblox redelivers. | Studio S4; code read | OK, with F1 and F5 below |
| 7 | Free player's save | A player with no purchases has empty `receipts` and `onceBought`; coins and cats survive a save and rejoin. | spec "keeps a free player's earned coins and cats" | OK |
| 8 | Once-per-account bought twice | A second Starter Bundle receipt pays only its potions; the cat and sign never repeat, even when the receipt id has fallen off the 100-id list. | specs "only the potions", "falls off the list"; Studio: first and second Starter Bundle | OK, passed in Studio (Sprinkles and sign once) |
| 9 | Unknown product id | `NotProcessedYet` forever, so Roblox keeps delivering and nothing is given. | `Products.spec` "sells only made ids"; spec "never sells a product id Config does not name"; Studio: unknown product returned `NotProcessedYet` | OK, passed in Studio; see F5 |

## Policy checks (monetization-policy), still passing
- Every product holds a fixed prize of allowed potions only (`Products.spec`, "holds the plan's fixed potions"). No coins, spins, crates, lures or odds potions. Nothing random.
- A repeated purchase never pays a cat or sign twice; the Robux are not taken for nothing (the potions still come).
- Prices come from Roblox at runtime; none of these paths holds a price.
- Nothing tradeable, nothing worded for new players beyond the store text.
- No pass refund or product refund clawback code exists, and none should be added without Derek2's yes: taking items back from a young player is a dark-pattern risk.

## Findings (read from code; each is its own issue so it can be argued with)
- **F1 (#2127). An error halfway through a grant loses the rest of the prize.** `processReceipt` records the id, then `give` pays potions, sign, cat, in that order. If a step throws (the whole call is in a `pcall`), the answer is `NotProcessedYet`, but the id is already recorded, so the redelivery pays nothing. The player has paid and got part. Rare, and only on a bug. Fix idea for Gameplay-Engineer: pay in one protected step and remove the id again if nothing was paid, or put the cat first and log a Telemetry line on any failure.
- **F2 (#2129, fixed in #2135). Cafe Pass with no season running.** A paid receipt then waits until a season runs (`NotProcessedYet`), so the buyer has paid and gets nothing for the gap, and then gets the next season's track. The product is off sale between seasons, so only a prompt opened just before a season ends can do this. Derek2 chose to close the sale 10 minutes before a season ends (#2135); a receipt that still arrives later is granted as before.
- **F3. Refunded pass keeps working until the next join** (ownership is checked once, at join). Harmless. What a refunded pass does to things it already gave (placed Garden Decor, a worn sign style) is not read from code: Studio S5.
- **F4. The receipt list keeps 100 ids.** A repeatable product's receipt that Roblox delivers again after 100 newer purchases would pay twice. Needs an unanswered receipt for 100 purchases, so not a real risk; noted, no issue.
- **F5. Never remove or zero a product id in `Config.ProductIds` once it has sold.** A receipt for an unnamed id is never granted. Add this to the pre-release store rules.
- **F6 (#2130). A failed pass lookup at join is tried again only three times** (5, 15 and 45 seconds). If Roblox's Marketplace is down longer, a paid pass reads as not owned for the whole session (and Long Nap's offline pay at join is worked out without it). The next join fixes it. Fix idea: one more retry every five minutes.

## Studio run, 2026-11-07 (Laptop-Tester, main 724daa36, synthetic receipts through `processReceipt`, no Robux)
Passed: the Potion Pack XS grant, the same PurchaseId resent, the same id delivered twice at once (paid once), a new id, the Starter Bundle first and second purchase (Sprinkles and sign once), an unknown product (`NotProcessedYet`), and a stop and start with everything persisted and nothing doubled.

## Still for Derek2 (nothing else is left)
S1. With "Enable Studio Access to API Services" off, buy a Potion Pack XS in Studio: the potions arrive, a save warning in the output is fine, no error.
S4. With access on, cut your network right after a purchase: the toast shows, the potions are there, and after the network is back the count does not change.
S5. In Roblox, ask for a refund of a game pass you own (Roblox's own page, only you can). Rejoin: the pass is gone. Check the Garden decor you placed and the sign style you wear (F3).
S6. In a real prompt, buy a pack twice quickly: two packs, not one and not three. This also checks the real prompt window.
Write the result next to each line and open an issue for anything that is wrong.
