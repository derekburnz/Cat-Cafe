# The free Bellhop Cat and where the asks go (F96)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. His answer of 22:32 to Monetization-Agent's question 5: "Can add liking the game, join the community (after I put game under a group), favourite game, notifications but make sure they are placed wisely don't want to crowd the screen early maybe have a limited decent starting cat with (FREE) then when they go to get it from it's stand in the town square have it make them do something like liking the game before they can claim and check that they have before giving it (Put more effort into this cat)".

What a game can check (Tools-Agent's `like-favorite-check.md` and Monetization-Agent's plan section 5, in the project files):

- **Likes:** no. No engine call tells a game whether a player liked it.
- **Favourites:** only on the player's own device, which an exploiter can fake. Rewarding a number that feeds Roblox's charts is the metric farming `docs/growth/launch-ops.md` keeps us away from.
- **Joining the group:** yes, on the server (`IsInGroupAsync`).
- **Notifications:** may never gate anything, and the prompt shows only to players 13 and up.

So the cat is gated on joining the group. Every other ask is a polite request with no reward.

## 1. The Bellhop Cat

- **Who.** A ginger and white cat in a red bellhop cap with gold braid and a chin strap, a small brass bell on its collar, white socks and a curl at the tip of its tail. Favourite role: Greeter. It rings its bell when a customer comes in and tips its cap as they pass.
- **What it earns.** It is a shop-style exclusive cat (economy-ladder.md section 6) at the Rare rate: it always earns like a Rare from the player's newest area. That is 3 a second at Tier 1, three times the Tabby, and 243 at Tier 5. So it is a real help on day one and stays worth a slot for a long time. It sits below the paid starter cat (Epic rate) on purpose.
- **Not counted.** Like every exclusive cat it does not count toward the tier's "different cats", the Index or Index milestones. It shows on the Exclusive page. It can be locked, but not sold, traded or offered to the Cat Collector. One per account, never gold.
- **More effort, as Derek asked.**
  - Its own sculpt pass: the cap's braid and the bell are modelled, not painted.
  - Five animations: the bell ring, the cap tip, a little bow when it is placed, a sleepy cap-over-eyes pose at night and a happy hop when it is claimed.
  - A before and after sheet goes to Derek before it merges.
  - Model-Agent and Animation-Engineer hold it to the Legendary row of the decor quality bar (luck-and-rare-moments.md section 2c), since every new player sees it.

## 2. Its stand in town

- A round stand in the street plaza (the Town Square once F84 is built), between the Codes Cat and the Spin Wheel. The stand is a red and gold hotel luggage cart with the Bellhop Cat sitting on top, ringing its bell every few seconds.
- A sign on the cart: "Free cat! Take me home".
- Walking within 12 studs opens its card: the cat, "Earns like a Rare from your newest area, always" with today's figure, and what claiming needs.
  - **Before the game is in a group** (`Config.GroupId` is 0): claiming needs the first cafe goals done (`tutorialStep` 5: a cat home, a table bought and food in the bowl). Before that the card says "Finish your first goals to take me home", and the goal card points here once they are done. This is the small task in town Tools-Agent suggested, and it gives a new player a reward right at the end of the first loop.
  - **Once the game is in Derek's group:** claiming needs the player to be in the group. The card has a "Join the group" button (`GroupService:PromptJoinAsync`) and a "Take me home" button that the server checks with `IsInGroupAsync`. A player who is not in yet sees "Join the Cat Cafe group to take me home". Players who claimed before the move keep the cat.
- Claiming plays the happy hop. The cat jumps off the cart into the player's arms and appears in the cafe's free role slot, or resting if none is free, with a small card: "The Bellhop Cat joined your cafe!". The cart stays, with the cat sitting on it for everyone else.
- After claiming, the card shows the cat's portrait with "Already home with you".

## 3. Where the asks go

Derek asked for these to be placed wisely and never crowd the start. Rules for all of them:

- At most one ask a session.
- None before the first loop is done (`tutorialStep` 5).
- Never during a catch, a carry, a minigame or a card.
- Each kind shows once per account, except where noted.
- None gives a reward, and none blocks play.

| ask | when | how |
|---|---|---|
| Join the group | only at the Bellhop Cat's stand and the Regulars Board (launch-ops.md section 2), when the player walks up | the player presses it; there is no pop-up |
| Notifications | after the first bait cat is tamed, players 13 and up only | Roblox's opt-in prompt (`ExperienceNotificationService:PromptOptIn`), once, and again at most once in 30 days if dismissed |
| Favourite | after the first rank up to Tier 2 | Roblox's favourite dialog if Tools-Agent's test in the published place shows it accepts the experience, else a toast: "Favorite Cat Cafe to find it fast next time" |
| Like | after the first Legendary is secured, or the first session on a second day, whichever comes first | the easy-start.md section 4 toast, words only: "Having fun? A thumbs up helps other players find Cat Cafe." |

The like milestone codes in launch-ops.md stay the only reward tied to likes, and they reward everyone, not the person who liked.

## 4. Contracts

- Catalog: `bellhop_cat` with `exclusive = true`, `rarity` "Rare" for its rate, `favoriteRole` "greeter", `source` "free".
- Profile (next save version): `starterCatClaimed` (bool).
- World: the stand model `CatCafe_Street_BellhopStand`, tag `BellhopStand`, in the plaza.
- Remotes: `ClaimStarterCat()`. Checks:
  - the caller is within 12 studs of a `BellhopStand`;
  - `starterCatClaimed` is false;
  - with `Config.GroupId` 0, `tutorialStep` is at least 5; otherwise `IsInGroupAsync(GroupId)`, in a pcall and cached for 60 s (a failed call answers "Try again in a moment").
  - Rate limit 1 per 2 seconds.

  It adds the cat (charm 60, level 1, base coat), places it as section 2 says and answers `StarterCatResult(ok, reason)`.
- Analytics:
  - `starter_cat` (value 1, field gate: task or group);
  - `ask_shown` (value 1, fields kind: notify, favorite or like; the session number);
  - funnel step 25 `starter_cat` after easy-start.md's step 24.
- Who builds:
  - Model-Agent: the cat and the luggage cart, on a sheet for Derek first.
  - Animation-Engineer: the five animations.
  - Gameplay-Engineer: the catalog row, remote, save and asks' timing.
  - UI-Engineer: the stand card, the asks and the claim card.
  - Sound-Agent: a bell.
  - QA-Planner: section 5.

## 5. QA checks

1. Before the group exists, a player who has not finished the first goals cannot claim. After tutorialStep 5 they can, once, and the cat lands in a free role slot.
2. With a group id set, a non-member is refused and sees the join button; after joining, the claim works. A player who claimed earlier keeps the cat.
3. The Bellhop Cat earns 3 a second at Tier 1 and 243 at Tier 5 (charm 50 base), shows on the Exclusive page and does not count toward Tier 2's five different cats.
4. It cannot be sold, offered to the Collector or claimed twice, even after a rejoin or a server hop.
5. No ask shows before tutorialStep 5, none shows twice in a session, and the notification ask never shows to a player under 13.
6. Nothing is paid or unlocked for liking or favouriting.
