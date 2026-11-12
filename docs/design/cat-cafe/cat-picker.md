# The shared "pick a cat" list (#3700)

Status 2026-11-12: spec, not built yet. Asked by Derek at 22:06 UTC: "make the picking the cat menu better and make sure to add rarity/level sorting". One picker component, used first at the Mystic Pool, then by the other station menus as they are redone under #3558. Client only, no new remote. Layout draft in the Library: `Design-Agent/for-derek-2026-11-12/pick-a-cat-menu.png`.

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
