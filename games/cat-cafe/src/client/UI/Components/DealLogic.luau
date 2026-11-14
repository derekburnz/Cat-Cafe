--!strict
-- #3996 (Design-Agent's todays-deal-3996.md section 4): the words on the Store's Today's Deal card, from
-- PlayerState.dailyDeal (shared/DailyDeal.view) and the deal's Catalog product. The card says what is in the deal and
-- its price before the prompt; the value line compares counts only where that is true; the change line is a plain
-- local time that never ticks; the Tomorrow line names the next deal so nobody needs to fear missing today's. The
-- token deal carries the Mystic Pool's roll odds, as every Trait Token offer does (#3864). No countdown, no "only
-- today", no streaks (monetization-policy).
--   DealLogic.card(view, now, oddsLine)   the card's words, or nil when there is no deal to show
--   DealLogic.contents(prize)             "5 Big Money · 2 Swift", the count and "potion" or "token"
--   DealLogic.value(prize)                "7 potions for R$25, more than Potion Pack S"
--   DealLogic.changeText(now)             "A new deal each day at 7:00 PM" (UTC midnight in the device's time)
-- Pure but for os.date's local time in changeText.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local DailyDeal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyDeal"))

local DealLogic = {}

DealLogic.TITLE = "Today's Deal"
DealLogic.PRICE = 25 -- tools/opencloud/products.json: deal_1 to deal_4 are R$25 each, regional pricing off
DealLogic.BOUGHT = "Bought today"
DealLogic.BOUGHT_LINE = "Bought today. A new deal comes tomorrow."
DealLogic.TOKEN_LINE = "One Trait Token is one Mystic Pool roll."

-- the potions in the order the pack cards name them, with their short names
local POTIONS: { { id: string, short: string } } = {
	{ id = "big_tip_potion", short = "Big Money" },
	{ id = "swift_potion", short = "Swift" },
	{ id = "steady_potion", short = "Steady Paw" },
}

-- the normal packs a deal is compared with (count only)
local SMALL_PACK = "potion_pack_s"
local STEADY_PACK = "steady_paw_pack"
local TOKEN_PACK = "trait_tokens_20"
local TOKEN_PACK_PRICE = 99

export type Card = {
	n: number,
	product: string, -- the Catalog.products id, for PromptDeal
	bought: boolean,
	kind: string, -- "potion" or "token": the picture
	potion: string?, -- the first potion's id, for its picture
	title: string,
	contents: string,
	value: string,
	tomorrow: string,
	change: string,
	odds: string?, -- the token deal's roll odds
	price: string, -- "R$25"
	full: string, -- every line, as the card shows them with room
	short: string, -- the lines kept on a small card (the value line goes first; the odds never)
}

local function potionCount(prize: any): number
	local count = 0
	for _, amount in
		(if type(prize) == "table" and type(prize.potions) == "table" then prize.potions else {})
	do
		if type(amount) == "number" then
			count += amount
		end
	end
	return count
end

local function productPrize(id: string): any
	local def = Catalog.getProduct(id)
	return if def ~= nil then def.prize else nil
end

-- What the deal holds, as the pack cards name it: the words, the count, and "potion" or "token".
function DealLogic.contents(prize: any): (string, number, string)
	if type(prize) ~= "table" then
		return "", 0, "potion"
	end
	local tokens = if type(prize.traitTokens) == "number" then prize.traitTokens else 0
	if tokens > 0 then
		return string.format("%d Trait Tokens", tokens), tokens, "token"
	end
	local parts: { string } = {}
	local potions: { [string]: any } = if type(prize.potions) == "table" then prize.potions else {}
	for _, potion in POTIONS do
		local amount = potions[potion.id]
		if type(amount) == "number" and amount > 0 then
			local count: number = amount
			local short: string = potion.short
			table.insert(parts, string.format("%d %s", count, short))
		end
	end
	return table.concat(parts, " · "), potionCount(prize), "potion"
end

-- The honest value line: more than a normal pack only where the count says so.
function DealLogic.value(prize: any): string
	local _, count, kind = DealLogic.contents(prize)
	local price = DealLogic.PRICE
	if kind == "token" then
		local pack = productPrize(TOKEN_PACK)
		local packTokens: number = if type(pack) == "table"
				and type(pack.traitTokens) == "number"
			then pack.traitTokens
			else 0
		local perPrice = math.floor(packTokens * price / TOKEN_PACK_PRICE)
		if packTokens > 0 and count > perPrice then
			return string.format(
				"%d Trait Tokens, more than the %d pack gives for R$%d",
				count,
				packTokens,
				price
			)
		end
		return string.format("%d Trait Tokens for R$%d", count, price)
	end
	local steady = productPrize(STEADY_PACK)
	local steadyCount = potionCount(steady)
	local mine = if type(prize) == "table" and type(prize.potions) == "table"
		then prize.potions
		else {}
	local steadyHere = if type(mine.steady_potion) == "number" then mine.steady_potion else 0
	if steadyCount > 0 and steadyHere >= steadyCount and count > steadyCount then
		return string.format(
			"%d potions, %d more than the Steady Paw Pack",
			count,
			count - steadyCount
		)
	end
	local small = potionCount(productPrize(SMALL_PACK))
	if small > 0 and count > small then
		return string.format("%d potions for R$%d, more than Potion Pack S", count, price)
	end
	return string.format("%d potions for R$%d", count, price)
end

-- "A new deal each day at 7:00 PM": the next UTC midnight in the device's own time, plain words that never tick.
function DealLogic.changeText(now: number): string
	local midnight = (now // DailyDeal.DAY_SECONDS + 1) * DailyDeal.DAY_SECONDS
	local at = os.date("*t", midnight) :: any
	local hour: number = if type(at) == "table" and type(at.hour) == "number" then at.hour else 0
	local minute: number = if type(at) == "table" and type(at.min) == "number" then at.min else 0
	local twelve: number = if hour % 12 == 0 then 12 else hour % 12
	local half: string = if hour < 12 then "AM" else "PM"
	return string.format("A new deal each day at %d:%02d %s", twelve, minute, half)
end

-- The card's words for PlayerState.dailyDeal, or nil (false, nil, or a deal number it doesn't know). `oddsLine` is
-- the Mystic Pool's "Roll odds: ..." line, shown on the token deal.
function DealLogic.card(view: any, now: number, oddsLine: string?): Card?
	if type(view) ~= "table" or type(view.deal) ~= "number" then
		return nil
	end
	local deal = DailyDeal.LIST[view.deal]
	if deal == nil then
		return nil
	end
	local prize = productPrize(deal.product)
	local contents, _, kind = DealLogic.contents(prize)
	local potion: string? = nil
	local potions: { [string]: any } = if type(prize) == "table"
			and type(prize.potions) == "table"
		then prize.potions
		else {}
	for _, entry in POTIONS do
		if potion == nil and type(potions[entry.id]) == "number" and potions[entry.id] > 0 then
			potion = entry.id
		end
	end
	local next = DailyDeal.LIST[if type(view.tomorrow) == "number" then view.tomorrow else 0]
	local tomorrow = if next ~= nil then string.format("Tomorrow: %s deal", next.name) else ""
	local value = DealLogic.value(prize)
	local change = DealLogic.changeText(now)
	local bought = view.bought == true
	-- commas between the rarities, so a narrow card wraps the odds between them
	local odds: string? = if kind == "token" and oddsLine ~= nil
		then table.concat(string.split(oddsLine, " · "), ", ")
		else nil
	local lines: { string } = { contents }
	local short: { string } = { contents }
	if bought then
		table.insert(lines, DealLogic.BOUGHT_LINE)
		table.insert(short, DealLogic.BOUGHT_LINE)
	elseif odds ~= nil then
		-- a bought token is a paid random item: the roll and its odds are on the card itself (#3864)
		table.insert(lines, value)
		table.insert(lines, DealLogic.TOKEN_LINE)
		table.insert(lines, odds)
		table.insert(short, odds)
	else
		table.insert(lines, value)
	end
	if tomorrow ~= "" then
		table.insert(lines, tomorrow)
		table.insert(short, tomorrow)
	end
	if not bought then
		table.insert(lines, change)
	end
	return {
		n = view.deal,
		product = deal.product,
		bought = bought,
		kind = kind,
		potion = potion,
		title = DealLogic.TITLE,
		contents = contents,
		value = value,
		tomorrow = tomorrow,
		change = change,
		odds = odds,
		price = string.format("R$%d", DealLogic.PRICE),
		full = table.concat(lines, "\n"),
		short = table.concat(short, "\n"),
	}
end

return DealLogic
