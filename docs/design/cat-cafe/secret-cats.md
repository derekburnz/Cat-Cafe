# Secret cats: a hidden tier above Mythical (#3470)

Proposed 2026-11-12 by Design-Agent. Owner: game-designer. Readers: Gameplay-Engineer, Model-Agent, Motion-FX-Agent, Review-QA-Agent. Built 2026-11-12 with the numbers below (#3486, #3487, #3489, effects #3480 and #3492), behind `secretCats`, which is off.

Derek, 2026-11-12 03:07 UTC, from a player's "add secret tier pet": "add a secret tier of pet that is out of index can spawn on any area and its super rare like 100x rarer then mythic but its better then all current mythics in the game (also let it have a gold chance/rainbow chance)".

Derek was away when this was written. Points marked **(assumed)** were decided without him and are listed in section 9.

## 1. In one paragraph

A sixth rarity, **Secret**. It turns up anywhere a Mythical can, 100 times less often. It earns 4 times a Mythical in the owner's best area. It is not in the Index until you own one. It can be gold or rainbow like any cat.

## 2. Odds

One rule: **a source's Secret chance is its Mythical chance divided by 100**, taken out of the Mythical share so no other rarity moves. The one number is `Catalog.secretPerMythical = 0.01`.

| Source | Mythical | Secret |
|---|---|---|
| Wild stray, every area | 1.2% | 0.012% (1 in 8,333) |
| Bait bowls, Kibble to Star Treat | 0.085% to 12.75% | 0.00085% to 0.1275% |
| Rescue traps | the trap's Mythical chance | divided by 100 |

- Luck, Lucky days and potions move it exactly as they move Mythical. There is no Secret-only boost and none is sold.
- No pity timer. **(assumed)**
- At 57 strays a game day per server, one server sees a wild Secret about once in 146 game days. Across all servers one is seen most days.

## 3. Value

- `incomePerSecond` 300 (Mythical 75). **(assumed)**
- Secret is a keep-up rarity (`Config.KeepUpRarities`): it earns with the multiplier of the owner's best open area, wherever it was caught. This is what makes "any area" and "better than every Mythical" both true without giving a new player end game money. **(assumed)**
- Sell value 60,000, first catch reward 150,000.
- Wherever a rule asks for a rarity, Secret counts as Mythical or better. No rank up asks for a Secret.
- Traits, levels, the spa, names and accessories work as on any cat.

## 4. Coats

The same gold and rainbow rolls and multipliers as every cat. A wild rainbow Secret is about 1 in 555,000 strays.

## 5. Catching

The same game, harder than Mythical: 8 circles, `shrinkSeconds` 0.50, `catchWindow` 0.64, `trustNeed` 26, Mythical moods, double and paw rings, `fleeStuds` 72, `rescueHits` 8. Tries stay unlimited.

## 6. How it shows

- **In the world:** its own look (section 8), a soft dark aura and a thin beam of light to the sky. The rarity colour `#16161D` is for tags and cards only; the beam, sparkles and rings use a pale starlight, RGB (226, 214, 255). The beam stays up while someone is catching it. The tag reads "SECRET" with "???" for the name until it is caught.
- **On spawn:** one banner and one chat line for the server, naming the area and not the spot: "A Secret cat is somewhere in the Park!" Bait and rescue Secrets get none. **(assumed)**
- **On catch:** the rare catch line one step up, inside the server only. **(assumed)**
- It stays until the next night like any wave stray. No timer shows and nothing says it will leave.
- Normal tackle rules apply on the way home.

## 7. Out of the Index

- No row, silhouette or "???" slot, and no count toward any Index total, track or reward.
- After you own one, a Secret page appears at the end of your Index with only the ones you found and no total. **(assumed)**
- The Collector and the Relic Museum never ask for one.
- **Bait cards stay as they are.** A bait card's Mythical line keeps its number and now means "Mythical or better": the Secret share is inside it, so the card stays true and gives nothing away. This is allowed because bait is bought with coins and coins are never in any Robux item (store-skus.md), so no Robux buys a random roll. If bait or coins ever enter a Robux item, each card must list Secret on its own line with its real chance (`monetization-policy`).

## 8. The first three **(assumed)**

| Name | Look | Favourite role |
|---|---|---|
| Nebula | deep space coat, slow drifting stars, faint purple glow | Entertainer |
| Glitch | teal and magenta coat that shimmers in little squares | Barista |
| Cafe Ghost | pale see-through cat with a tiny chef hat, floats a little | Greeter |

Any area can spawn any of the three, picked evenly. Original designs only.

**Looks reworked (Derek 2026-11-12).** Cafe Ghost is as first built. Derek asked for more that makes Nebula and Glitch unique, Model-Agent redid both (#3534) and he OK'd the new looks at 12:23 UTC. `secretCats` goes on with the Friday 2026-11-13 update ([update-2026-11-13.md](update-2026-11-13.md)).

**Art outside the game (Derek 2026-11-12).** In ads, thumbnails, the event picture and any store picture, a Secret cat is shown only as a dark shape, never with its real look. The looks are for players to find.

## 9. Assumed without Derek

1. Three cats to start, with these names.
2. 4 times a Mythical, paid at the owner's best area.
3. A server notice on a wild spawn, naming the area only.
4. A Secret page in the Index only after you own one.
5. No pity timer, and the catch notice stays inside the server.

## 10. Rollout

- A new rarity is new data for every server that reads a profile, so it is built behind LiveFlag `secretCats`, off. With it off nothing rolls Secret.
- The flag goes on only when every live server runs a build that knows Secret, which means after a restart. No restart is made for this alone.
- The build confirms whether cats are saved by catalog id only (then no save version change) and that a build with the flag off keeps a Secret cat it loads.

## 11. QA checks

The test plan is on #3470 (odds within tolerance of Mythical / 100, income at Tier 1 and Tier 7, coats, Index before and after, bait card odds line, a profile with a Secret loading on a flag-off build, phone readability).
