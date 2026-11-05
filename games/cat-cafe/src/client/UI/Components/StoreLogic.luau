--!strict
-- The Store window's rows (Monetization-Agent's shop-and-pass-plan, 2026-11-01): which passes show, what each says
-- and its button. Pure, so the spec runner loads it; Components/PassShop asks Roblox for prices and ownership and
-- Screens/Store draws the rows.
--
-- Only passes that exist show (a Config id of 0 is a pass not made yet). The money ladder shows one card: the next
-- rung above the highest owned (2x, then 3x, then 4x), or the top rung marked Owned. Long Nap shows once made. Every
-- price comes from Roblox at runtime, never from here (plan section 1), so a card reads "..." until it is known and
-- "Soon" while the pass is off sale.
--
-- #1425 (Derek2 11-05: "if people have to scroll down for the best packs they will never be bought"): every row
-- names its tab on the Store's left rail (TABS), and StoreLogic.featured picks the Featured tab's hero card and its
-- three top picks. Featured means shown first, never louder: no badges, no timers, nothing pre-selected.

local StoreLogic = {}

export type Row = {
	key: string, -- "money", "longNap" or a PASSES key
	passId: number,
	name: string,
	icon: string,
	effect: string,
	owned: boolean,
	product: boolean?, -- a developer product (bought each time; passId holds its product id, never Owned)
	tab: string, -- the rail tab it shows under: "passes", "cats", "potions" or "cafePass"
	multiplier: number?, -- the money card's rung (2, 3, 4), for its picture (ShopIcons.store)
}

-- The Store's left rail, top to bottom (#1425). Featured and Codes (#1428, the code box) always show; another tab
-- only while it has a card.
export type Tab = { id: string, name: string, icon: string, always: boolean? }
StoreLogic.TABS = {
	{ id = "featured", name = "Featured", icon = "⭐", always = true },
	{ id = "passes", name = "Passes", icon = "🎟️" },
	{ id = "cats", name = "Cats", icon = "🐱" },
	{ id = "potions", name = "Potions", icon = "🧪" },
	{ id = "cafePass", name = "Cafe Pass", icon = "🎫" },
	{ id = "codes", name = "Codes", icon = "🔑", always = true },
} :: { Tab }

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
	tab: string?, -- default "passes"
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
		tab = "cats",
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
		tab = "cats",
	},
}
StoreLogic.PASSES = PASSES

-- The potion packs (#1182, store-skus.md section 1; Gameplay-Engineer's #1207): developer products, bought each time.
-- Each reads its id from Config.ProductIds[productKey] (0 while not made: hidden) and its exact contents from
-- Catalog.products, and the card says how many of those potions the player already has, so nobody buys blind.
export type ProductCard = { key: string, productKey: string, effect: string }
local PRODUCTS: { ProductCard } = {
	{
		key = "potionXS",
		productKey = "potion_pack_xs",
		effect = "Money Potions: more money while they last.",
	},
	{ key = "potionS", productKey = "potion_pack_s", effect = "A small potion mix." },
	{ key = "potionM", productKey = "potion_pack_m", effect = "A potion mix." },
	{ key = "potionL", productKey = "potion_pack_l", effect = "A big potion mix, with 2 bonus." },
}
StoreLogic.PRODUCTS = PRODUCTS

-- The Starter Bundle (store-skus.md section 1): a developer product sold once per account, under Cats and as the
-- Featured hero. It shows only while the server says it has not been bought (ShopView.starterBought false), so it can
-- never be bought twice; with no word from the server (nil) or no product id yet it stays hidden.
local STARTER: ProductCard = {
	key = "starterBundle",
	productKey = "starter_bundle",
	effect = "A head start for a new cafe. Once per player.",
}
StoreLogic.STARTER = STARTER

-- The Cafe Pass's paid track (#1646, cafe-pass.md section 5): a developer product bought once a season, under the
-- Cafe Pass tab. It shows only while a season runs (ShopView.cafePass), with the track's exact contents, and reads
-- Owned once this season's track is bought; the price is Roblox's, read at runtime.
local CAFE_PASS: ProductCard = {
	key = "cafePass",
	productKey = "cafe_pass",
	effect = "Season %d paid track, a reward every level:",
}
StoreLogic.CAFE_PASS = CAFE_PASS

-- What the Store needs to draw the product cards: Catalog.products, potion id to its name, and the player's bag.
export type ProductPrize = {
	potions: { [string]: number },
	cats: { string }?, -- #1625: the Starter Bundle's Sprinkles
	signStyles: { string }?, -- #1625: the Starter Bundle's Bakery Stripes
}
-- The running Cafe Pass season for its card: its number, its name, whether its paid track is bought, and the paid
-- track's contents in words (PassLogic.paidContents).
export type PassOffer = { season: number, name: string, paid: boolean, contents: string }
export type ShopView = {
	products: { { id: string, name: string, prize: ProductPrize } }?,
	potionNames: { [string]: string }?,
	catNames: { [string]: string }?, -- cat id to its name, for a prize's cats
	have: { [string]: number }?,
	starterBought: boolean?, -- the server's word on the Starter Bundle (nil: unknown, so it stays hidden)
	cafePass: PassOffer?, -- #1646: nil while no season runs (or before CafePassState), so the card stays hidden
}

local function productId(config: any, card: ProductCard): number?
	local ids = config.ProductIds
	local id = if type(ids) == "table" then ids[card.productKey] else nil
	return if type(id) == "number" and id ~= 0 then id else nil
end

-- The made products' ids, to look their prices up.
function StoreLogic.productIds(config: any): { number }
	local out: { number } = {}
	for _, card in PRODUCTS do
		local id = productId(config, card)
		if id then
			table.insert(out, id)
		end
	end
	local starter = productId(config, STARTER)
	if starter then
		table.insert(out, starter)
	end
	local cafePass = productId(config, CAFE_PASS)
	if cafePass then
		table.insert(out, cafePass)
	end
	return out
end

-- The sign styles' names (shared/SignStyles' ids, #1625): Bakery Stripes from the Starter Bundle, Royal Crest from
-- the King Cat Pack.
StoreLogic.SIGN_STYLE_NAMES = {
	bakery_stripes = "Bakery Stripes",
	royal_crest = "Royal Crest",
} :: { [string]: string }

-- "Sprinkles the cat, Bakery Stripes sign style": a prize's cats and sign styles in words, or nil when it has none.
-- An id with no name yet reads as its words ("new_cat" is "New Cat").
local function titled(id: string): string
	local words: { string } = {}
	for _, word in id:split("_") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(words, " ")
end
function StoreLogic.extras(prize: ProductPrize, catNames: { [string]: string }?): string?
	local parts: { string } = {}
	local names: { [string]: string } = catNames or {}
	local cats: { string } = prize.cats or {}
	for _, id in cats do
		table.insert(parts, (names[id] or titled(id)) .. " the cat")
	end
	local styles: { string } = prize.signStyles or {}
	for _, id in styles do
		table.insert(parts, (StoreLogic.SIGN_STYLE_NAMES[id] or titled(id)) .. " sign style")
	end
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

-- "3 Money Potion, 1 Swift Potion · You have 4": the exact contents, biggest first, and how many of them are owned.
function StoreLogic.contents(
	potions: { [string]: number },
	names: { [string]: string }?,
	have: { [string]: number }?
): string
	type Entry = { id: string, count: number }
	local list: { Entry } = {}
	for id, count in potions do
		table.insert(list, { id = id, count = count })
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.id < b.id
	end)
	local parts: { string } = {}
	local owned = 0
	for _, entry in list do
		table.insert(parts, ("%d %s"):format(entry.count, (names or {})[entry.id] or entry.id))
		local mine: number = (have or {})[entry.id] or 0
		owned += mine
	end
	return table.concat(parts, ", ") .. (" · You have %d"):format(owned)
end

local function productRows(config: any, view: ShopView?): { Row }
	local rows: { Row } = {}
	if view == nil then
		return rows
	end
	local byId: { [string]: any } = {}
	local defs: { any } = view.products or {}
	for _, def in defs do
		byId[def.id] = def
	end
	for _, card in PRODUCTS do
		local id = productId(config, card)
		local def = byId[card.productKey]
		if id and def then
			table.insert(rows, {
				key = card.key,
				passId = id,
				name = def.name,
				icon = "🧪",
				effect = card.effect
					.. "\n"
					.. StoreLogic.contents(def.prize.potions, view.potionNames, view.have),
				owned = false,
				product = true,
				tab = "potions",
			})
		end
	end
	return rows
end

-- The Starter Bundle's row while it can be bought, else nil.
local function starterRow(config: any, view: ShopView?): Row?
	local id = productId(config, STARTER)
	if id == nil or view == nil or view.starterBought ~= false then
		return nil
	end
	local def = nil
	local defs: { any } = view.products or {}
	for _, product in defs do
		if product.id == STARTER.productKey then
			def = product
		end
	end
	if def == nil then
		return nil
	end
	-- #1625: the exact contents on the card (monetization policy): the cat and sign style, then the potions
	local effect = STARTER.effect
	local extras = StoreLogic.extras(def.prize, view.catNames)
	if extras then
		effect ..= "\n" .. extras
	end
	local potions = def.prize.potions
	if potions and next(potions) ~= nil then
		effect ..= "\n" .. StoreLogic.contents(potions, view.potionNames, view.have)
	end
	local row: Row = {
		key = STARTER.key,
		passId = id,
		name = def.name,
		icon = "🎁",
		effect = effect,
		owned = false,
		product = true,
		tab = "cats",
	}
	return row
end

-- The Cafe Pass's row while a season runs, else nil (#1646).
local function cafePassRow(config: any, view: ShopView?): Row?
	local id = productId(config, CAFE_PASS)
	local offer = if view then view.cafePass else nil
	if id == nil or offer == nil or offer.season <= 0 then
		return nil
	end
	return {
		key = CAFE_PASS.key,
		passId = id,
		name = "Cafe Pass",
		icon = "🍁",
		-- "Season 1 paid track, a reward every level:" and the track's exact contents
		effect = CAFE_PASS.effect:format(offer.season) .. "\n" .. offer.contents,
		owned = offer.paid,
		product = true,
		tab = "cafePass",
	}
end

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
	-- #1161: the Second Bait Bowl, priced for the Bait bowl window's locked tab (no Store card yet)
	local second = config.SecondBowlPassId
	if type(second) == "number" and second ~= 0 then
		table.insert(ids, second)
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

-- #1606 (Derek2 11-05: "shows 2x money on your screen somewhere near your money always and replaces itself with
-- 3x/4x if bought"): the badge beside the HUD's money. The highest money pass owned (Roblox's answer in `owned`, or
-- the server's PlayerState.passBoosts.money as `serverMultiplier`) reads "2x", "3x" or "4x"; with none, "Get 2x"
-- while the 2x pass is on sale (a tap opens the Store), else no badge.
export type MoneyBadge = { text: string, owned: boolean }
function StoreLogic.moneyBadge(
	config: any,
	owned: { [number]: boolean },
	prices: { [number]: Price },
	serverMultiplier: number?
): MoneyBadge?
	local ladder = rungs(config)
	local top = if type(serverMultiplier) == "number"
			and serverMultiplier == serverMultiplier
		then math.max(1, math.floor(serverMultiplier))
		else 1
	for _, rung in ladder do
		if owned[rung.id] then
			top = math.max(top, rung.multiplier)
		end
	end
	if top > 1 then
		return { text = ("%dx"):format(top), owned = true }
	end
	local first = ladder[1]
	local price = if first ~= nil then prices[first.id] else nil
	if price ~= nil and price.forSale then
		return { text = ("Get %dx"):format(first.multiplier), owned = false }
	end
	return nil
end

local function hours(seconds: number): number
	return math.floor(seconds / 3600 + 0.5)
end

-- The rows to show for a player who owns the pass ids in `owned`; `longNap` is ProfileSync's word on Long Nap.
function StoreLogic.rows(
	config: any,
	owned: { [number]: boolean },
	longNap: boolean?,
	view: ShopView?
): { Row }
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
				multiplier = nextRung.multiplier,
				effect = if top > 1
					then ("All your cafe's money x%d, in place of x%d."):format(
						nextRung.multiplier,
						top
					)
					else ("All your cafe's money x%d."):format(nextRung.multiplier),
				owned = false,
				tab = "passes",
			})
		else
			local last = ladder[#ladder]
			table.insert(rows, {
				key = "money",
				passId = last.id,
				name = ("%dx Money"):format(last.multiplier),
				icon = MONEY_ICON,
				multiplier = last.multiplier,
				effect = ("All your cafe's money x%d."):format(last.multiplier),
				owned = true,
				tab = "passes",
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
			tab = "passes",
		})
	end
	-- the order of store-skus.md: the ladder, Long Nap, VIP, the potion packs, then the rest by price
	for index, card in PASSES do
		if index == 2 then
			for _, row in productRows(config, view) do
				table.insert(rows, row)
			end
			local starter = starterRow(config, view)
			if starter then
				table.insert(rows, starter)
			end
			local cafePass = cafePassRow(config, view)
			if cafePass then
				table.insert(rows, cafePass)
			end
		end
		local id = passId(config, card)
		if id then
			table.insert(rows, {
				key = card.key,
				passId = id,
				name = card.name,
				icon = card.icon,
				effect = if card.note then card.effect .. "\n" .. card.note else card.effect,
				owned = owned[id] == true,
				tab = card.tab or "passes",
			})
		end
	end
	return rows
end

-- The rows under one rail tab, in the Store's order.
function StoreLogic.tabRows(rows: { Row }, tab: string): { Row }
	local out: { Row } = {}
	for _, row in rows do
		if row.tab == tab then
			table.insert(out, row)
		end
	end
	return out
end

-- The rail's tabs for these rows: Featured, each tab that has a card, then Codes.
function StoreLogic.tabs(rows: { Row }): { Tab }
	local out: { Tab } = {}
	for _, tab in StoreLogic.TABS do
		if tab.always or #StoreLogic.tabRows(rows, tab.id) > 0 then
			table.insert(out, tab)
		end
	end
	return out
end

export type Featured = { hero: Row?, picks: { Row } }

StoreLogic.PICKS = 3
-- The hero, in order of preference (#1425): the Starter Bundle while it can be bought (the best first buy for a new
-- cafe), then the running season's Cafe Pass until it is bought (#1646), then the King Cat Pack. An owned King Cat Pack gives way to the Royal Cat, then the Grand Cafe Theme.
local HERO_ORDER = { "starterBundle", "cafePass", "kingPack", "royalCat", "grandTheme" }
-- The top picks, left to right: the money ladder's next rung, Long Nap and the King Cat Pack (the Royal Cat when the
-- King Cat Pack is the hero).
local PICK_ORDER = { "money", "longNap", "kingPack", "royalCat" }

-- The Featured tab's cards: one hero and up to three picks, never the same row twice. Owned rows give way to ones
-- that can still be bought, and an empty spot is filled from the rest of the Store in its order.
function StoreLogic.featured(rows: { Row }): Featured
	local byKey: { [string]: Row } = {}
	for _, row in rows do
		byKey[row.key] = row
	end
	local hero: Row? = nil
	for _, key in HERO_ORDER do
		local row = byKey[key]
		if row and not row.owned then
			hero = row
			break
		end
	end
	local used: { [string]: boolean } = {}
	if hero then
		used[hero.key] = true
	end
	local picks: { Row } = {}
	local function take(row: Row?)
		if row and not used[row.key] and #picks < StoreLogic.PICKS then
			used[row.key] = true
			table.insert(picks, row)
		end
	end
	for _, key in PICK_ORDER do
		local row = byKey[key]
		if row and not row.owned then
			take(row)
		end
	end
	for _, row in rows do
		if not row.owned then
			take(row)
		end
	end
	for _, key in PICK_ORDER do
		take(byKey[key]) -- everything bought: the picks still show, marked Owned
	end
	return { hero = hero, picks = picks }
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
