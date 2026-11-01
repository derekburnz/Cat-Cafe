# Cats make the orders (F90)

Status: proposed by the game-designer thread, 2026-11-01. From Derek's ask of 2026-10-30 23:27: "Consider making it so the cats make whatever items the people are asking for and bring it to them / collect tips from table, Also add more bubble pop-ops for customers not just always milk and cake and draft models for that with some sort of baking animation for the cats in the back making the food consider making the animation or bubble showing them baking to be quite simple so that it doesn't require a lot of attention to detail to make it look good".

In the decision memo's plan this is the first weekly update after launch. It changes how the cafe looks, not what it earns: everything here runs on each client, like today's customers, and the server, the economy and the save stay as they are.

## 1. The menu grows with the cafe

Customers order from a menu that grows by tier, so a higher tier cafe visibly serves more. Each item has a chunky, toy-like model on a plate and an icon from the same render for the order bubble.

| Tier | Item | Made at | Look |
|---|---|---|---|
| 1 | Coffee | espresso machine | a round mug with a heart in the foam |
| 1 | Milk | counter | a glass of milk with a striped straw |
| 1 | Cake slice | oven | a pink slice with a cherry on top |
| 1 | Paw cookie | oven | a round cookie with a chocolate paw print |
| 2 | Tea | espresso machine | a teacup and saucer with a tea bag tag |
| 2 | Fish biscuit | oven | a golden fish-shaped biscuit |
| 3 | Kitty cupcake | oven | a cupcake with two little icing ears |
| 3 | Hot cocoa | espresso machine | a mug with a cat-shaped marshmallow |
| 4 | Pancake stack | oven | three pancakes, a butter pat and syrup |
| 4 | Ice cream sundae | counter | a sundae with two wafer ears |
| 5 | Strawberry roll | oven | a sliced roll cake with cream and a strawberry |
| 5 | Rainbow cake | oven | a tall slice in rainbow layers |

A customer picks evenly among the items its cafe's tier has opened. The rich customer always orders the newest item open, on a gold-rimmed plate.

## 2. How an order plays

1. **Order.** At the counter the customer's bubble shows the item's icon, as today's bubble does.
2. **Make.** The Barista cat at the counter makes it, kept deliberately simple:
   - The cat stays seated at its station and does a little working bob: two small hops and a head tilt, on a loop.
   - A bubble over the cat shows the item's icon with a ring that fills over MakeSeconds: 2 s for a drink, 3 s for a bake.
   - A puff at the station while it works: steam for a drink, a flour puff and a warm glow from the oven door for a bake.
   - At the end a "ding!" sparkle and sound, and the item appears on the counter.
   - With two or three Baristas the orders split between them. At most three orders wait per cafe; a customer beyond that gets its item on the table when it sits, so nobody stands waiting.
3. **Carry.** The cafe's free Waiter cat gets up, trots to the counter, takes the item on a little tray balanced on its head, trots to the customer's table along the same aisle customers use and sets it down. A heart pops over the customer, as today's Served heart does. The Waiter trots back and sits. With no Waiter working, the Barista hands it over the counter and the customer carries it to the seat.
4. **Leave.** When the customer leaves, the plate stays empty for 5 s and fades, and the customer's tip pile appears where they sat, as today.
5. **Tips.** An idle Waiter (or Greeter) walks to a table with a tip pile, sweeps it into a little coin bag and carries it to the till, where the piles stack up beside the till button. The player still collects at the till, by walking within 8 studs of it or pressing Collect. The server's tip piles are unchanged: same count, same amounts, and still lost if the player leaves the game. Only where they sit on screen changes.

At night the cafe is closed as now, so no orders are made.

## 3. Keeping it simple to make

Derek asked for this to look good without fine detail, so the pieces are chosen to read at a glance:

- **No paw animation.** Making is a bob, a bubble with a filling ring, a puff and a ding. Nothing has to line up with a cat's paws.
- **One carry pose.** The tray rides on the head attachment, so every cat body carries the same way and props on the Head move aside the way the Entertainer's party hat does.
- **Chunky food.** Each item is 40 to 150 triangles in bright flat colours with a soft outline, so it reads from across the cafe and its icon is just a render.
- **One new station.** A small oven behind the counter (`CatCafe_Cafe_Oven`). Drinks use today's espresso machine; Milk and the sundae come straight off the counter.

## 4. Budget

- Your own cafe plays everything.
- Other cafes in range (CafeLifeRangeStuds) play the making bubble, puff and ding, but the item appears on the table without a Waiter walk, and tips stay on the tables.
- On a phone or in Low performance, other cafes show only the order bubbles and the item on the table.

## 5. Contracts (all client side)

- `Catalog.menu`: `{ id, name, tier, station, makeSeconds, model, icon }` for the twelve items; `station` is `espresso`, `oven` or `counter`.
- `CustomerController`: picks the order from the menu by the plot's `Tier`, runs the make, carry, leave and tip steps above, and keeps one queue per cafe. The `Order` attribute takes the menu ids in place of `coffee`, `cake` and `milk`.
- `Layout.cafe`: the oven's anchor behind the counter and a `TillStack` point beside the till.
- No server, remote, save or analytics change.

## 6. Who builds what

- Model-Agent: the twelve items on plates, the gold-rimmed plate, the head tray, the coin bag and the oven, drafted on one sheet for Derek first, then their icon renders.
- Animation-Engineer: the working bob, get up and sit down at a station, the trot with a tray and the tip sweep.
- VFX-Agent: the steam, flour puff, oven glow and ding sparkle.
- UI-Engineer: the making bubble with its ring and the order bubble icons.
- Gameplay-Engineer: the CustomerController flow and the Catalog and Layout rows.
- Sound-Agent: pour, oven ding, tray clink and coin sweep.
- QA-Planner: section 7.

## 7. QA checks

1. A Tier 1 cafe's customers order only coffee, milk, cake slices and paw cookies; a Tier 5 cafe's order all twelve.
2. Each order shows its icon, the Barista bobs under a filling ring, the right puff plays and the ding sounds when it is done.
3. The Waiter carries the item on its head tray to the right table, the heart pops and the Waiter returns to its spot. With no Waiter the Barista hands it over.
4. More than three orders at once: the extra customers find their item on the table.
5. Tip piles move to the till; the till's count and the coins paid by Collect match the server's `TipPiles` and `TipPilesAmount` exactly.
6. A second player watching from the street sees bubbles and items but no Waiter walks in a cafe that is not theirs.
7. On a phone with eight cafes in view the frame rate holds.
