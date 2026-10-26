---
name: monetization-policy
description: Roblox monetization rules Purr Pot must follow: paid random items odds disclosure, PolicyService checks per player, game passes vs developer products, Creator Rewards behaviour, no dark patterns for a young audience, and the specific Purr Pot calls (bait, eggs, coin packs). Use when designing, building or reviewing anything that costs Robux or looks like gambling.
---

# Monetization policy (Purr Pot)

Facts below are from Roblox's paid random items guidelines and monetization docs as of 2026-10-25. Verify against the live pages before launch: https://create.roblox.com/docs/production/monetization/paid-random-items and https://create.roblox.com/docs/creator-rewards.

## 1. What Roblox sells and how we get paid (for Derek)
- **Game pass**: one-time purchase that sticks to the player forever (2x coins, extra cafe slot). Easiest, no gambling questions.
- **Developer product**: repeatable purchase (coin pack, instant customer rush). Granted in `MarketplaceService.ProcessReceipt`; must be idempotent and saved before returning `Granted`.
- **Private servers**: optional, fine for friends.
- Roblox takes its marketplace cut; what is left converts through DevEx at about $0.0038 per Robux with a 30,000 Robux minimum. Creator Rewards add roughly 5 Robux per active spender who plays 10+ minutes that day. Retention and session length matter more than the shop.

## 2. Paid random items rules (apply to anything random bought with Robux, directly or via a currency that Robux can buy)
Random here means eggs, spins, chests, gacha, re-roll tokens, random bait, mystery boxes.
1. Show every possible outcome's odds as percentages that sum to 100%, **before** purchase, in the purchase UI itself.
2. Luck boosts, pity systems and rate-ups must state their numeric effect before purchase, and the displayed odds must update while they are active.
3. Call `PolicyService:GetPolicyInfoForPlayerAsync(player)` on the server when the player joins; cache it; respect `ArePaidRandomItemsRestricted` (hide or replace the random feature for that player) and `IsPaidItemTradingAllowed` (no trading of paid items where false).
4. Offer a free, earnable route to the same random items where possible (coins earned in the cafe can buy bait too).
5. If coins can be bought with Robux **and** coins buy random bait or eggs, the bait/egg counts as a paid random item. Either keep coins unbuyable, or show odds on every random purchase. Purr Pot default: **coins are not buyable**; Robux buys passes and cosmetic decoration packs only.

## 3. No dark patterns (young audience)
No fake countdown timers, no "only 2 left", no "your friend just bought", no spending streaks, no nagging popups after a decline, no pay-to-win walls that stop the core loop, no confusing currency stacks. Prices shown in Robux before any confirm. Declines are respected for the session.

## 4. PolicyService snippet (src/server/Services/PolicyService.luau)
```lua
--!strict
-- PolicyService wrapper: fetch once per player, cache, default to the most restrictive values on failure.
local RobloxPolicy = game:GetService("PolicyService")
local Players = game:GetService("Players")

export type Policy = { paidRandomRestricted: boolean, paidTradingAllowed: boolean }

local cache: { [Player]: Policy } = {}
local PolicyService = {}

local function fetch(player: Player): Policy
	local ok, info = pcall(RobloxPolicy.GetPolicyInfoForPlayerAsync, RobloxPolicy, player)
	if not ok then
		warn(`PolicyService failed for {player.Name}; using restrictive defaults`)
		return { paidRandomRestricted = true, paidTradingAllowed = false }
	end
	return {
		paidRandomRestricted = info.ArePaidRandomItemsRestricted == true,
		paidTradingAllowed = info.IsPaidItemTradingAllowed == true,
	}
end

function PolicyService.Get(player: Player): Policy
	local policy = cache[player]
	if not policy then
		policy = fetch(player)
		cache[player] = policy
	end
	return policy
end

function PolicyService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(PolicyService.Get, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return PolicyService
```

## 5. Purr Pot monetization decisions (proposed, growth-analyst confirms)
| Idea | Type | Policy | Verdict |
|---|---|---|---|
| Double Coins | game pass | none | yes, launch |
| Extra cafe room / more tables | game pass | none | yes, launch |
| Cosmetic decoration packs | game pass or dev product (fixed contents) | none | yes |
| Buy coins with Robux | dev product | turns bait and eggs into paid random items | **no** at launch |
| Premium bait with better odds | dev product + random outcome | odds UI, PolicyService, rate-up disclosure | not at launch; if ever, follow section 2 |
| Egg hatch / spin wheel | random | full odds UI | only if free-currency only |
| Trading cats | social | `IsPaidItemTradingAllowed`, scams | no at launch |

## 6. Review checklist
- Does any Robux path end in a random outcome? Then: odds visible before purchase, sum to 100, PolicyService checked, hidden where restricted.
- Is every price read from the server's Catalog and shown before confirm?
- Is `ProcessReceipt` idempotent and saved before Granted?
- Any copy that pressures? Remove it.
