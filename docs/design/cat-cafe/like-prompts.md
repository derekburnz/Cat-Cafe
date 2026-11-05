# Like and favourite prompts with a playtime gift (#1578)

Status: specced by the game-designer thread (Design-Agent, friend's project), 2026-11-05, from Derek's Set 6 Q5 and Set 7 to 9 answers. Builders: UI-Engineer (cards), Gameplay-Engineer (the gift and its save flag). Monetization-Agent and Review-Agent check it against Roblox's rules before it ships. Derek confirmed the times on 2026-11-05 20:58 ("confirm those times"): the like card at 10 minutes, the favourite card at 30.

## 1. The rule this follows

Roblox can't tell a game whether a player liked or favourited it, and the community reading of Roblox's rules is that a reward for liking or favouriting isn't allowed, because it fakes the like ratio ([DevForum](https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286), [DevForum](https://devforum.roblox.com/t/rewarding-players-for-liking-the-game/2920714)). So **the gift is for playing, never for the like.** Every player who reaches the time gets it, whether they press Like, Favourite or Close, and the card never says the gift needs a like. Monetization-Agent checks this against Roblox's current Community Standards before launch. If the rule turns out stricter, the like and favourite buttons go and the gifts stay as plain playtime gifts.

## 2. The two cards

| when (time played, all sessions) | card | buttons | gift |
|---|---|---|---|
| 10 minutes, never in the first 5 | "Thanks for playing! Here's a gift. If you're enjoying the cafe, a thumbs-up helps other players find it." | **Like the game** (shows Roblox's own rating screen where the client can open it, otherwise "Tap the thumbs-up on the game page"), **Close** | 10 minutes of the player's current cafe income (the HUD rate, no potions) and 10 golden fish |
| 30 minutes | "You've played 30 minutes! Here's another gift. Favourite the game to find it quickly next time." | **Favourite** (`AvatarEditorService:PromptSetFavorite` on the place), **Close** | 1 banked spin and 25 golden fish |

- **The gift is paid when the card shows**, before any button, so pressing Close or leaving still keeps it. The card says "Gift added!" with its pictures (at most two, F94).
- **Once per account.** `likeGift` and `favGift` save flags (booleans) are set when each gift pays. Each card shows once and never comes back.
- **No pressure.** The Close button is the same size as the other button, there's no countdown, timer or guilt line, and nothing else changes after a Close. The card never shows mid-catch, during the intro, a trade or a purchase prompt; it waits until the player is idle in town or at a camp for 3 s.
- **Timing source.** The server's playtime (`stats.playtimeSeconds` plus the session) decides when a card is due and pays the gift. The client only shows the card. Remote `PlaytimeGift(kind)` goes from server to client, and no client remote pays anything.

## 3. Contracts

- Config: `LikeGiftMinutes` 10, `FavGiftMinutes` 30, `LikeGiftIncomeMinutes` 10, `LikeGiftFish` 10, `FavGiftSpins` 1, `FavGiftFish` 25, `GiftIdleSeconds` 3.
- Save: `likeGift`, `favGift` (booleans, default false). Claim `DataService.luau` for the save version bump.
- Analytics: `playtime_gift` (kind, button pressed: like, favourite, close or none). This is the only way to see how many press the button; it's never used to decide a gift.
- QA: (1) A new save gets nothing before 10 minutes and the like card at 10, even with a rejoin at 6. (2) Pressing Close keeps the gift. (3) The favourite card at 30 opens Roblox's favourite prompt and pays the same with or without a favourite. (4) Neither card shows again on any later join.
