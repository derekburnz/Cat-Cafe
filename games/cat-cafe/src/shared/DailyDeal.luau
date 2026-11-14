--!strict
-- #3996 (Design-Agent's todays-deal-3996.md, from Growth-Agent's proposal): Today's Deal, one small fixed R$25 pack
-- on the Store's Featured tab that changes each UTC day, once per player a day, from Tier 2, behind the dailyDeal
-- switch. #4238 (Derek 2026-11-14: "make sure they don't do any potion packs ... make sure they are actually good
-- stuff like 10 of the gold crates from your best area, trait tokens and 250 gold fish"): no potions in any deal.
-- Deal 1's golden fish are not random. Deal 2's Trait Tokens (rolls) and the golden crates of deals 3 and 4 (a decor
-- piece by odds) are paid random items: the token deal shows only where the token bundles may be (traitBundles on,
-- the policy read and not restricting paid random items, the bank has room), a crate deal only where the policy read
-- allows paid random items, and deal 1 shows instead. No countdown, no "only today", no reminder (monetization-policy).
--   DailyDeal.dayOf(now)                                     the UTC day number
--   DailyDeal.dealFor(day, tokensOk, cratesOk)               the deal number (1 to 4) a player sees that day
--   DailyDeal.view(profile, now, tokensOk, tier, cratesOk)   PlayerState.dailyDeal, or false
-- Pure.

local Types = require(script.Parent.Types)

local DailyDeal = {}

DailyDeal.FLAG = "dailyDeal"
DailyDeal.MIN_TIER = 2
DailyDeal.TOKEN_DEAL = 2
DailyDeal.FALLBACK = 1
DailyDeal.DAY_SECONDS = 86400

export type Deal = {
	n: number,
	product: string, -- its Catalog.products id
	name: string, -- for the Tomorrow line ("Tomorrow: Golden Crates deal")
	needs: string?, -- "tokens" or "crates": a paid random deal, shown only where that is allowed
}

DailyDeal.LIST = table.freeze({
	table.freeze({ n = 1, product = "deal_1", name = "Golden Fish" }),
	table.freeze({ n = 2, product = "deal_2", name = "Trait Token", needs = "tokens" }),
	table.freeze({ n = 3, product = "deal_3", name = "Golden Crates", needs = "crates" }),
	table.freeze({ n = 4, product = "deal_4", name = "Golden Haul", needs = "crates" }),
} :: { Deal })

local byProduct: { [string]: Deal } = {}
for _, deal in DailyDeal.LIST do
	byProduct[deal.product] = deal
end

-- The deal a Catalog.products id is, or nil.
function DailyDeal.ofProduct(productId: string): Deal?
	return byProduct[productId]
end

function DailyDeal.dayOf(now: number): number
	return now // DailyDeal.DAY_SECONDS
end

-- The deal number for UTC day `day`: day % 4 + 1, with the token deal falling back to deal 1 where `tokensOk` is not
-- true and a crate deal where `cratesOk` is not true.
function DailyDeal.dealFor(day: number, tokensOk: boolean?, cratesOk: boolean?): number
	local n = day % #DailyDeal.LIST + 1
	local needs = DailyDeal.LIST[n].needs
	if (needs == "tokens" and tokensOk ~= true) or (needs == "crates" and cratesOk ~= true) then
		return DailyDeal.FALLBACK
	end
	return n
end

-- Whether a token bank of `tokens` has room for the token deal's tokens (`max` the bank's cap).
function DailyDeal.roomFor(tokens: number, dealTokens: number, max: number): boolean
	return tokens + dealTokens <= max
end

-- Whether the player bought a deal on UTC day `day`.
function DailyDeal.boughtOn(profile: Types.PlayerProfile, day: number): boolean
	return profile.dealDay == day
end

-- PlayerState.dailyDeal: today's deal, whether it was bought today and tomorrow's, or false below MIN_TIER (the switch
-- is the caller's).
function DailyDeal.view(
	profile: Types.PlayerProfile,
	now: number,
	tokensOk: boolean?,
	tier: number,
	cratesOk: boolean?
): Types.DailyDealView | false
	if tier < DailyDeal.MIN_TIER then
		return false
	end
	local day = DailyDeal.dayOf(now)
	return {
		deal = DailyDeal.dealFor(day, tokensOk, cratesOk),
		bought = DailyDeal.boughtOn(profile, day),
		tomorrow = DailyDeal.dealFor(day + 1, tokensOk, cratesOk),
	}
end

-- Why the prompt for today's deal cannot open, or nil. `productId` the Catalog.products id the client asked for.
function DailyDeal.promptBlocker(
	profile: Types.PlayerProfile,
	now: number,
	tokensOk: boolean?,
	tier: number,
	productId: string,
	cratesOk: boolean?
): string?
	if tier < DailyDeal.MIN_TIER then
		return "Today's Deal opens at Tier 2"
	end
	local day = DailyDeal.dayOf(now)
	if DailyDeal.boughtOn(profile, day) then
		return "Bought today. A new deal comes tomorrow."
	end
	local deal = DailyDeal.LIST[DailyDeal.dealFor(day, tokensOk, cratesOk)]
	if deal.product ~= productId then
		return "That deal is not today's"
	end
	return nil
end

-- The save's dealDay from anything: a whole UTC day number, or nil.
function DailyDeal.sanitizeDay(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1e7 then
		return nil
	end
	return math.floor(value)
end

return DailyDeal
