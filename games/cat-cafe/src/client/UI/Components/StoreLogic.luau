--!strict
-- The Store window's rows (Monetization-Agent's shop-and-pass-plan, 2026-11-01): which passes show, what each says
-- and its button. Pure, so the spec runner loads it; Components/PassShop asks Roblox for prices and ownership and
-- Screens/Store draws the rows.
--
-- Only passes that exist show (a Config id of 0 is a pass not made yet). The money ladder shows one card: the next
-- rung above the highest owned (2x, then 3x, then 4x), or the top rung marked Owned. Long Nap shows once made. Every
-- price comes from Roblox at runtime, never from here (plan section 1), so a card reads "..." until it is known and
-- "Soon" while the pass is off sale.

local StoreLogic = {}

export type Row = {
	key: string, -- "money", "longNap" or a PASSES key
	passId: number,
	name: string,
	icon: string,
	effect: string,
	owned: boolean,
}

-- What Roblox said about a pass: its price in Robux and whether it is on sale. Missing until the lookup returns.
export type Price = {
	robux: number?,
	forSale: boolean,
}

export type Button = {
	text: string,
	style: string, -- a Button style
	enabled: boolean,
}

local MONEY_ICON = "💰"
local NAP_ICON = "😴"

-- The rest of the shop's passes (#1182, docs/growth/store-skus.md section 1), in the Store's order after the ladder
-- and Long Nap: VIP, then by price. Each reads its id from Config[configKey] (a number, or a list whose first made id
-- counts, as ExtraSlotPassIds); 0 or missing means the pass is not made yet (#1197) and its card stays hidden.
export type PassCard = {
	key: string,
	configKey: string,
	name: string,
	icon: string,
	effect: string,
	note: string?,
}
local PASSES: { PassCard } = {
	{
		key = "vip",
		configKey = "VipPassId",
		name = "VIP",
		icon = "⭐",
		effect = "+10% money, a VIP chat tag and a gold VIP plate on your cafe sign.",
	},
	{
		key = "accessories",
		configKey = "CatAccessoriesPassId",
		name = "Cat Accessories",
		icon = "🎀",
		effect = "Dress your cats: a dressed cat earns +15%.",
	},
	{
		key = "uniforms",
		configKey = "UniformStylesPassId",
		name = "Uniform Styles",
		icon = "👕",
		effect = "New uniform styles for every job: +15% money.",
	},
	{
		key = "extraSlot",
		configKey = "ExtraSlotPassIds",
		name = "Extra Slot",
		icon = "➕",
		effect = "+1 job slot, so one more cat can work.",
	},
	{
		key = "cafeStyle",
		configKey = "CafeStylePassId",
		name = "Cafe Style",
		icon = "🏪",
		effect = "A new cafe theme and tag, +50% money, and rich visitors come 25% more often.",
	},
	{
		key = "royalCat",
		configKey = "RoyalCatPassId",
		name = "Royal Cat",
		icon = "👑",
		effect = "A cat that always earns like a Legendary from your newest area.",
		note = "Yours to keep. Can't be traded.",
	},
	{
		key = "grandTheme",
		configKey = "GrandThemePassId",
		name = "Grand Cafe Theme",
		icon = "🏰",
		effect = "The grand look: +150% money, twice the rich visitors, +1 job slot every tier.",
	},
	{
		key = "kingPack",
		configKey = "KingPackPassId",
		name = "King Cat Pack",
		icon = "🤴",
		effect = "The King Cat, who always earns like a Mythical from your newest area, plus a crown sign style.",
		note = "Yours to keep. Can't be traded.",
	},
}
StoreLogic.PASSES = PASSES

-- A pass card's id from the Config, or nil while it is not made (0, missing, or an empty list).
local function passId(config: any, card: PassCard): number?
	local value = config[card.configKey]
	if type(value) == "table" then
		for _, id in value do
			if type(id) == "number" and id ~= 0 then
				return id
			end
		end
		return nil
	end
	return if type(value) == "number" and value ~= 0 then value else nil
end

-- Every pass id the Config names that is made, money ladder first.
function StoreLogic.passIds(config: any): { number }
	local ids: { number } = {}
	local money = config.MoneyPassIds or {}
	for multiplier = 2, 10 do
		local id = money[multiplier]
		if type(id) == "number" and id ~= 0 then
			table.insert(ids, id)
		end
	end
	local nap = config.LongNapPassId
	if type(nap) == "number" and nap ~= 0 then
		table.insert(ids, nap)
	end
	for _, card in PASSES do
		local id = passId(config, card)
		if id then
			table.insert(ids, id)
		end
	end
	return ids
end

-- The money ladder's rungs that exist, lowest first: { multiplier, id }.
local function rungs(config: any): { { multiplier: number, id: number } }
	local out = {}
	local money = config.MoneyPassIds or {}
	for multiplier = 2, 10 do
		local id = money[multiplier]
		if type(id) == "number" and id ~= 0 then
			table.insert(out, { multiplier = multiplier, id = id })
		end
	end
	return out
end

local function hours(seconds: number): number
	return math.floor(seconds / 3600 + 0.5)
end

-- The rows to show for a player who owns the pass ids in `owned`; `longNap` is ProfileSync's word on Long Nap.
function StoreLogic.rows(config: any, owned: { [number]: boolean }, longNap: boolean?): { Row }
	local rows: { Row } = {}
	local ladder = rungs(config)
	if #ladder > 0 then
		local top = 1
		for _, rung in ladder do
			if owned[rung.id] then
				top = math.max(top, rung.multiplier)
			end
		end
		local nextRung = nil
		for _, rung in ladder do
			if rung.multiplier > top then
				nextRung = rung
				break
			end
		end
		if nextRung ~= nil then
			table.insert(rows, {
				key = "money",
				passId = nextRung.id,
				name = ("%dx Money"):format(nextRung.multiplier),
				icon = MONEY_ICON,
				effect = if top > 1
					then ("All your cafe's money x%d, in place of x%d."):format(
						nextRung.multiplier,
						top
					)
					else ("All your cafe's money x%d."):format(nextRung.multiplier),
				owned = false,
			})
		else
			local last = ladder[#ladder]
			table.insert(rows, {
				key = "money",
				passId = last.id,
				name = ("%dx Money"):format(last.multiplier),
				icon = MONEY_ICON,
				effect = ("All your cafe's money x%d."):format(last.multiplier),
				owned = true,
			})
		end
	end
	local nap = config.LongNapPassId
	if type(nap) == "number" and nap ~= 0 then
		table.insert(rows, {
			key = "longNap",
			passId = nap,
			name = "Long Nap",
			icon = NAP_ICON,
			effect = ("Away money at %d%% for up to %d h.\nWithout it: %d%% for up to %d h."):format(
				math.floor((config.OfflineRatePass or 1) * 100 + 0.5),
				hours(config.OfflineCapPassSeconds or 57600),
				math.floor((config.OfflineRate or 0.5) * 100 + 0.5),
				hours(config.OfflineCapSeconds or 28800)
			),
			owned = owned[nap] == true or longNap == true,
		})
	end
	for _, card in PASSES do
		local id = passId(config, card)
		if id then
			table.insert(rows, {
				key = card.key,
				passId = id,
				name = card.name,
				icon = card.icon,
				effect = if card.note then card.effect .. "\n" .. card.note else card.effect,
				owned = owned[id] == true,
			})
		end
	end
	return rows
end

-- A card's button: Owned, "..." while the price loads, Soon while off sale, else the price in Robux.
function StoreLogic.button(row: Row, price: Price?): Button
	if row.owned then
		return { text = "Owned", style = "ghost", enabled = false }
	end
	if price == nil then
		return { text = "...", style = "ghost", enabled = false }
	end
	if not price.forSale or price.robux == nil then
		return { text = "Soon", style = "ghost", enabled = false }
	end
	-- the gold Store look of the HUD's Store tile (#1020)
	return { text = ("R$%d"):format(price.robux :: number), style = "store", enabled = true }
end

return StoreLogic
