# Playing together: pals, Team Rescue and invites (F92)

Status: proposed by the game-designer thread, 2026-11-01, at Monetization-Agent's ask. Its key stats plan (`Monetization-Agent/key-stats-plan-2026-11-01.md` in the project files, section 4) notes that Roblox now ranks games partly on intentional co-play days, counted through joins, invites and private servers. It builds on common-features.md item 7 (friend bonus) and Derek's standing rule that the game is friendly: nothing here takes anything from anyone.

## 1. Pals

A **pal** is someone on your server who is any of these:

- a Roblox friend (`Player:IsFriendsWith`, checked on join and cached for the session);
- someone who joined through your invite, or whose invite you joined (the invite's launch data carries the inviter's user id);
- anyone in the same private server, since a private server is invite-only;
- someone who followed you into the server from your profile, or whom you followed (`Player.FollowUserId`).

How a pal joined never matters: a friend already on the server, one who joined through an invite and one in a private server all count the same.

## 2. Pal bonus

- While at least one pal is on your server, your tips earn PalTipBonus (+10%), and with two or more pals +PalTipBonusMax (+15%). It is a multiplier on `incomePerSecond` like the Tip Potion, split in `Economy.settle` where it starts and ends.
- A HUD chip shows the pals' headshots and "+10% with pals". It shows nothing when you have none, so a solo player never sees a missing bonus.
- The bonus does not touch offline earnings.

## 3. Team Rescue

- Any rescue in progress can take one helper. While a trap is locked to a rescuer, another player within 10 studs who is not carrying sees its prompt read "Help" (hold, like Rescue).
- The helper gets the same challenge, drawn from the same server times, on their own screen. A hit from either player counts toward `rescueHits`. A helper's miss costs no paw, so a helper can never make a rescue fail. A helped attempt gets TeamRescueExtraSeconds (+5) on its deadline.
- The cat goes to the rescuer, always. The helper gets a helper's tip of HelperTipSeconds (60) of their own day rate, and pals helping each other get it doubled. Only one helper per attempt and one helper's tip per player per TeamRescueTipCooldown (120 s), so two players cannot farm tips by taking turns.
- It works on every rarity, and it matters most on Legendary and Mythical traps, where Derek's harder bars (data-model 10b, 37% for a Mythical at 50 ms) make a second pair of hands worth asking for.
- Both players see a small "Team Rescue!" pop when the cat comes free.

## 4. Helping a pal's cafe

- A pal can collect tip piles from your cafe while you are away from it. The piles still pay you in full, at once, even though you are not there: a pal's collect is the one exception to "if you miss it you miss it" (data-model section 12).
- The pal earns a helping-hand share of PalCollectShare (25%) of what they collected, made new and never taken from you, up to PalCollectCapSeconds (600 s of the pal's own day rate) an hour.
- Strangers cannot collect your piles, so nobody can tour the street farming other cafes.
- You get a toast, "Sam collected your tips! +1,240", the next time you are on the server, or at once if you are.

## 5. Invites and joining a pal

- The HUD's invite button sends Roblox's invite with launch data naming the inviter (`SocialService:PromptGameInvite` with `ExperienceInviteOptions.LaunchData`).
- A player who joins through an invite or by following a pal spawns at that pal's cafe front door, facing the street, with a little wave from both characters. A player whose tutorial has not started yet spawns there too, and the hint trail leads them to their own cafe's back door from there.
- If the pal is out in an area, the joiner gets a marker "Sam is in the Park" on the HUD, and the travel button for that area glows if it is open to them.
- One soft nudge, once per account, after the first rank up: "Playing with a friend gives you both +10% tips. Invite one?" with the invite button. No reward for inviting.

## 6. Contracts

- Server: `PalService` keeps each player's pal set (friends, invite and follow links, private server members) and fires `PalsChanged(userIds)` to the player; `Economy` reads the pal bonus; RescueService takes `RescueHelp(rescueSpotId)` (1 per second, 10 studs, not carrying, the trap locked to someone else with no helper yet) and judges the helper's `RescuePress` against the same challenge; CafeService's `CollectTips` accepts a pal on the owner's plot while the owner is not on it and pays both as in section 4; spawning reads the join data for the invite or follow.
- Remotes: `RescueHelp(rescueSpotId)` new; `PalsChanged` new; `CollectTips` keeps its name and gains the pal case on the server only.
- Constants: PalTipBonus 0.10, PalTipBonusMax 0.15, TeamRescueExtraSeconds 5, HelperTipSeconds 60, TeamRescueTipCooldown 120, PalCollectShare 0.25, PalCollectCapSeconds 600.
- Analytics: `pal_time` (value minutes with at least one pal, fields how the first pal is linked: friend, invite, follow or private, and tier), `team_rescue` (value 1, fields rarity, success, pals yes or no), `pal_collect` (value coins to the owner, field tier). The economy events get the sources `pal_bonus`, `helper_tip` and `pal_share`.
- No save change: pals are worked out each session.
- Who builds: Gameplay-Engineer (PalService, the rescue helper, the pal collect, spawning), UI-Engineer (the pal chip, Help prompt, the helper's bar, toasts and the invite nudge), VFX-Agent (the Team Rescue pop, the wave), Sound-Agent (a short two-note chime for Team Rescue), QA-Planner (section 7).

## 7. QA checks

1. Two Roblox friends on one server both see "+10% with pals" and earn 10% more; a third friend makes it 15%; a stranger changes nothing.
2. A player who joins through an invite from a non-friend counts as a pal for both, and so does everyone in a private server.
3. A helper joins a Mythical rescue: either player's hits count, the helper's misses cost no paw, the deadline is 5 s longer, the cat goes to the rescuer and the helper gets the helper's tip once in 120 s.
4. A stranger cannot collect your tip piles; a pal can while you are away, you are paid in full and they get 25% on top, up to their cap.
5. An invited new player spawns at the inviter's front door and the trail leads to their own cafe.
6. Nothing in this feature ever takes coins, cats or tips from anyone.
