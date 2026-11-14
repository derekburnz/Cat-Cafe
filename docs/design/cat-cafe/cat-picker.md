# The shared "pick a cat" list (#3700)

Status 2026-11-12: built at the Mystic Pool the same evening by Design-Agent (`Components/CatPickLogic`, `Screens/MysticPool`); the other menus take it as they are redone. Asked by Derek at 22:06 UTC: "make the picking the cat menu better and make sure to add rarity/level sorting". One picker component, used first at the Mystic Pool, then by the other station menus as they are redone under #3558. Client only, no new remote. Layout draft in the Library: `Design-Agent/for-derek-2026-11-12/pick-a-cat-menu.png`.

## 1. Sort (Derek's ask)

A "Sort" row of chips: **Rarity** (default), **Level**, **Money**, **Name**.

- Rarity: best first (Secret, Mythical, Legendary, Epic, Rare, Common), then rainbow before gold before plain, then level high to low, then name.
- Level: high to low, then rarity. Money: the cat's own pay a second, high to low. Name: A to Z.
- Tapping the active chip flips the order and its small arrow. The choice is remembered for the session, per menu.
- Sorting is on the client from data it already has. No new remote.

## 2. Show (filters)

A "Show" row: **All**, **Resting**, **Working** (as today), plus **No trait** and **Has trait** at the Mystic Pool. Search stays. A count on the right: "42 cats", or "0 cats match" with a "Clear" chip when nothing fits.

## 3. Rows

- A coloured left edge and portrait ring in the cat's rarity colour, and a rarity tag with the word (colour is never the only sign).
- "GOLD" and "RAINBOW" tags beside the name where they apply.
- A level badge on the portrait.
- Second line: rarity tag, "Lv 37 · Working · $410M/s".
- Third line at the Mystic Pool: "Trait: Quick Paws", or "No trait yet".
- The button keeps its job; where the menu's action differs for a cat that already has a trait, the label says so (for example "Reroll") instead of "Pick". A cat that cannot be picked shows a greyed button with the reason in a few words.

## 4. Size and phone

- The list area grows so about six rows show on desktop and tablet (about two and a half today): a smaller header, the title and "Back" on one line with the search.
- Phone: rows full width, the Sort and Show rows scroll sideways, every chip and button at least thumb size, text never under the UI gate's smallest size, nothing under the safe area.
- Long lists stay smooth: rows are recycled, not all built at once.

## 5. One picker for every menu

Build it as one component and use it first at the Mystic Pool. Then the other "pick a cat" lists take it as their menus are redone under #3558 (Oasis Spa, Cat Collector, trades, the cafe's work and rest list), each with its own third line and filters.

## As built at the Mystic Pool (2026-11-12)

- `Components/CatPickLogic` holds the order, the filters and the row words, with no screen code, so any menu can use it.
- The search and Back share the first row. Sort and Show share one row that scrolls sideways and ends with the count.
- Rows have three lines: name; the rarity tag, a GOLD or RAINBOW tag and "Lv 37 · Working · +$410/s"; then the trait.
- While the list shows, the card grows to the room the screen has (at most 680 px), which gives about six rows on a desktop. On the smallest phone it stays at its short height and the list scrolls.
- Left for the next pass: the level badge on the portrait (the level is on the second line), a "Clear" chip when nothing matches, recycled rows, and a "Re-roll" label for cats that already have a trait.

## One small row on top and a Filter pop-up (#3874, 2026-11-13)

Derek: "make that just one small row on the top so I can see more cats at the same time on mobile", then "make it a search bar and a filter menu that they can pop up and close with an X. Make the default sort by money". This replaces the layout of sections 1 and 2 at the Mystic Pool:

- One row: a small search box (its hint holds the count, "Search 14 cats"), **Filter** and **Back**.
- Filter pops up over the list: Sort **Money** (the default now), **Level**, **Rarity**, with the X at the right; Show **All**, **Working**, **Resting**, **No trait**, **Has trait**. A chip works at once and the pop-up stays until the X or Filter. Filter is gold while open, and reads "Filter •" while a Show chip other than All is on. A press on the sort in use turns it round. A Name sort remembered from before falls back to Money.
- On a short screen each row has two lines: the name with the trait at the right, then the rarity, level, job and pay. The Pick button is drawn slimmer (its touch pad still reaches 44 px). The UI gate wants at least three whole rows on a short screen: the A06 goes from 2 rows to about 3.3, the small phone to 4.

## The cat's detail card (#3717)

Derek, 2026-11-12 22:32 UTC: "in the cat menu rework show the trait of cat in this little menu here". The Cats menu's detail card gets a TRAIT row under the chips: the trait's name in its rarity colour with the rarity word, its effects one per line, or a dashed "No trait yet. Roll one at the Mystic Pool." row. Hidden while `traits` is off. Built with the Cats menu rework (#3647). Layout draft: `Design-Agent/for-derek-2026-11-12/cat-card-trait.png`.
