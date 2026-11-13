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
	-- #1822: the ids of what the bundle holds that is also sold alone (passes and products), for its "Worth" line
	worthIds: { number }?,
	perk: string?, -- #2147: a gold chip over the words, "+15% money" (the two outfit passes)
	closed: boolean?, -- #2129: not offered right now (the Cafe Pass in the last minutes of a season)
}

-- The Store's left rail, top to bottom (#1425). Featured and Codes (#1428, the code box) always show; another tab
-- only while it has a card.
export type Tab = { id: string, name: string, icon: string, always: boolean? }
StoreLogic.TABS = {
	{ id = "featured", name = "Featured", icon = "⭐", always = true },
	{ id = "passes", name = "Passes", icon = "🎟️" },
	{ id = "cats", name = "Cats", icon = "🐱" },
	{ id = "potions", name = "Potions", icon = "🧪" },
	{ id = "cafePass", name = "Cafe Pass", icon = "🏅" }, -- the medal, as its picture (#1982)
	{ id = "codes", name = "Codes", icon = "🔑", always = true },
} :: { Tab }

-- #3572 (Derek's OK of Model-Agent's mock, 2026-11-12 13:10 UTC): the reworked Store, behind the `storeRework`
-- switch, puts Cats above Passes on the rail.
StoreLogic.REWORK_FLAG = "storeRework"
StoreLogic.REWORK_RAIL = { "featured", "cats", "passes", "potions", "cafePass", "codes" }

-- The rail's tabs in their order: TABS, or with the rework on REWORK_RAIL's order.
function StoreLogic.railTabs(rework: boolean): { Tab }
	if not rework then
		return StoreLogic.TABS
	end
	local out: { Tab } = {}
	for _, id in StoreLogic.REWORK_RAIL do
		for _, tab in StoreLogic.TABS do
			if tab.id == id then
				table.insert(out, tab)
			end
		end
	end
	return out
end

-- #3572: the reworked Store's header line under its title, by tab (the mock's words): what a tab's items are and
-- that prices are in Robux. The Codes tab keeps the window's own line.
StoreLogic.SUBTITLE_DEFAULT = "Help your cafe grow"
local SUBTITLES: { [string]: string } = {
	featured = "Prices are in Robux.", -- Featured can show potion packs, which are used up
	cats = "Passes are yours to keep. Prices are in Robux.",
	passes = "Passes are yours to keep. Prices are in Robux.",
	potions = "Potions are used from your Bag. Prices are in Robux.",
	cafePass = "Prices are in Robux.",
}

function StoreLogic.subtitle(tab: string): string
	return SUBTITLES[tab] or StoreLogic.SUBTITLE_DEFAULT
end

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

-- "1,450"
local function commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local grouped, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		text = grouped
		if count == 0 then
			return text
		end
	end
end

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
	perk: string?, -- #2147 (store-pass-looks.md 7): the card's gold chip
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
		-- #2147: the words Derek2 approved 2026-11-07 (store-pass-looks.md 7)
		effect = "Dress your cats in bows, glasses and more. A dressed cat earns +15%. Yours to keep.",
		perk = "+15% money",
	},
	{
		key = "uniforms",
		configKey = "UniformStylesPassId",
		name = "Uniform Styles",
		icon = "👕",
		effect = "New uniform styles for every job: +15% money.",
		perk = "+15% money",
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
	-- #2010 (Derek2: "extra food bowl is missing from live game store"): the Second Bait Bowl (#1161) under Cats, as
	-- baiting brings cats; the Bait bowl window's locked tab sells it too. Hidden while SecondBowlPassId is 0
	{
		key = "secondBowl",
		configKey = "SecondBowlPassId",
		name = "Second Bait Bowl",
		icon = "🥣",
		effect = "A second bait bowl, so two baits run at once. Same upgrades as the first.",
		note = "Yours to keep.",
		tab = "cats",
	},
	{
		key = "grandTheme",
		configKey = "GrandThemePassId",
		name = "Grand Cafe Theme",
		icon = "🏰",
		effect = "The grand look: +150% money, twice the rich visitors, +1 job slot every tier.",
	},
	-- #1168 row 3: the six pieces of Catalog.passDecor with pack "Garden Decor Pack", by name and rarity (#2006: each
	-- adds money while in use, Rare +4% and Epic +8%); hidden while GardenDecorPackPassId is 0
	{
		key = "gardenDecor",
		configKey = "GardenDecorPackPassId",
		name = "Garden Decor Pack",
		icon = "🌻",
		effect = "More money while in use. Rare +4%: Hanging Fern Basket, Sunflower Pot, Watering Can Planter. "
			.. "Epic +8%: Potted Lemon Tree, Ivy Trellis, Garden Swing Seat.",
	},
	-- #1168 row 1: the three sign styles of shared/SignStyles with passKey SignStylePackPassId, by name; hidden while
	-- the id is 0. Owned, they show on the Style tab with the rest.
	{
		key = "signStylePack",
		configKey = "SignStylePackPassId",
		name = "Sign Style Pack",
		icon = "🏷️", -- #2015: not 🪧 (Unicode 13), drawn blank
		effect = "Three cafe sign looks: Flower Box, Starry Night and Paw Chalkboard. Looks only.",
	},
	-- #1822 (Monetization's store doc §3C): the King Cat alone sits just before its bundle under Cats, so the bundle
	-- reads as the better deal; hidden while KingCatPassId is 0
	{
		key = "kingCat",
		configKey = "KingCatPassId",
		name = "King Cat",
		icon = "🤴",
		effect = "A cat that always earns like a Mythical from your newest area.", -- fits a phone's card
		note = "Yours to keep. Can't be traded.", -- as the Royal Cat's; a longer note shrank the card's text on a small phone
		tab = "cats",
	},
	-- #1822: the bundle lists what it holds (shared/KingPack.contents, in its order)
	{
		key = "kingPack",
		configKey = "KingPackPassId",
		name = "King Cat Pack",
		icon = "🤴",
		-- short enough to stay readable on a phone's small card (the King Cat's own card says how he earns)
		effect = "King Croissant, Royal Crest sign, Grand look, Royal Velvet Booth, Potion Pack M.",
		note = "Yours to keep. Can't be traded.",
		tab = "cats",
	},
}
StoreLogic.PASSES = PASSES
-- #2147 (store-pass-looks.md 7.3): the toast right after an outfit pass is bought, with its pass's symbol
StoreLogic.OUTFIT_THANKS = "Your working cats now earn +15%!"
function StoreLogic.outfitThanks(which: string): string
	return (if which == "uniforms" then "👕 " else "🎀 ") .. StoreLogic.OUTFIT_THANKS
end

-- The potion packs (#1182, store-skus.md section 1; Gameplay-Engineer's #1207): developer products, bought each time.
-- Each reads its id from Config.ProductIds[productKey] (0 while not made: hidden) and its exact contents from
-- Catalog.products, and the card says how many of those potions the player already has, so nobody buys blind.
export type ProductCard = { key: string, productKey: string, effect: string }
local PRODUCTS: { ProductCard } = {
	{
		key = "potionXS",
		productKey = "potion_pack_xs",
		effect = "More money while they last.", -- #1715: one short line
	},
	-- #1715: the mixes need no line of their own (the name says the size, the rows say what is in it), so a phone card
	-- keeps its text readable; "with 2 bonus" said nothing
	{ key = "potionS", productKey = "potion_pack_s", effect = "" },
	{ key = "potionM", productKey = "potion_pack_m", effect = "" },
	{ key = "potionL", productKey = "potion_pack_l", effect = "" },
	-- #1168 row 8: 10 Steady Paw potions, bought each time like the packs above; its rows say what is in it
	{ key = "steadyPaw", productKey = "steady_paw_pack", effect = "" },
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
	effect = "Season %d paid track:", -- short so a phone card keeps 9 px text
}
StoreLogic.CAFE_PASS = CAFE_PASS

-- #1168 row 4: the Thank You Badge, a developer product sold once per account with no gameplay in it. It shows only
-- while the player is not a supporter (ShopView.supporter, the Player attribute), so it isn't bought twice.
local THANK_YOU: ProductCard = {
	key = "thankYou",
	productKey = "thank_you_badge",
	effect = "A [Thank You] chat tag and a gold heart by your name on the ideas board.",
}
StoreLogic.THANK_YOU = THANK_YOU

-- What the Store needs to draw the product cards: Catalog.products, potion id to its name, and the player's bag.
export type ProductPrize = {
	potions: { [string]: number },
	cats: { string }?, -- #1625: the Starter Bundle's Sprinkles
	signStyles: { string }?, -- #1625: the Starter Bundle's Bakery Stripes
	moneyMultiplier: number?, -- #2850: the Starter Bundle's 2x Money for good
}
-- The running Cafe Pass season for its card: its number, its name, whether its paid track is bought, and the paid
-- track's contents in words (PassLogic.paidContents).
-- #2129: `saleOpen` false in the last minutes of a season (CafePass.saleOpen); the card then waits for the next one.
export type PassOffer = {
	season: number,
	name: string,
	paid: boolean,
	contents: string,
	saleOpen: boolean?,
}
export type ShopView = {
	products: { { id: string, name: string, prize: ProductPrize } }?,
	potionNames: { [string]: string }?,
	catNames: { [string]: string }?, -- cat id to its name, for a prize's cats
	have: { [string]: number }?,
	starterBought: boolean?, -- the server's word on the Starter Bundle (nil: unknown, so it stays hidden)
	cafePass: PassOffer?, -- #1646: nil while no season runs (or before CafePassState), so the card stays hidden
	supporter: boolean?, -- #1168: the Player's Supporter attribute; the Thank You Badge hides while true
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
	local thanks = productId(config, THANK_YOU)
	if thanks then
		table.insert(out, thanks)
	end
	return out
end

-- The sign styles' names (shared/SignStyles' ids, #1625): Bakery Stripes from the Starter Bundle, Royal Crest from
-- the King Cat Pack.
StoreLogic.SIGN_STYLE_NAMES = {
	bakery_stripes = "Bakery Stripes",
	royal_crest = "Royal Crest",
} :: { [string]: string }

-- "2x Money for good, Sprinkles the cat, Bakery Stripes sign style": a prize's money multiplier (#2850), cats and sign
-- styles in words, or nil when it has none.
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
	local multiplier = prize.moneyMultiplier
	if type(multiplier) == "number" and multiplier > 1 then
		table.insert(parts, ("%dx Money for good"):format(multiplier))
	end
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

-- #1715 (Derek2: "make the potion packs description better organized"): the exact contents, one row per potion,
-- biggest first, then how many of them are already in the bag on a line of its own:
--   "3x Money Potion\n1x Swift Potion\nIn your bag: 4"
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
		table.insert(parts, ("%dx %s"):format(entry.count, (names or {})[entry.id] or entry.id))
		local mine: number = (have or {})[entry.id] or 0
		owned += mine
	end
	table.insert(parts, ("In your bag: %d"):format(owned))
	return table.concat(parts, "\n")
end

-- #2850: the same contents on one line, biggest first, without the bag count and with "Potion" said once at the end:
-- "10x Big Money, 5x Swift potions" (the Starter Bundle's card, whose bigger prize no longer fits a row per potion on
-- the Featured hero of a small phone)
function StoreLogic.contentsLine(
	potions: { [string]: number },
	names: { [string]: string }?
): string
	local rows = StoreLogic.contents(potions, names, nil):split("\n")
	table.remove(rows) -- the "In your bag" line
	for index, row in rows do
		rows[index] = row:gsub(" Potion$", "")
	end
	return table.concat(rows, ", ") .. " potions"
end

-- #3572 (the OK'd mock's Potions tab): the "In your bag now" strip over the potion packs, one entry per potion any pack
-- holds, with how many the bag has (0 included), by name. A wide card shows only its first line, so the strip carries
-- the bag counts the old "In your bag: N" line gave.
export type BagEntry = { id: string, name: string, count: number }
function StoreLogic.bag(view: ShopView?): { BagEntry }
	local out: { BagEntry } = {}
	if view == nil then
		return out
	end
	local names: { [string]: string } = view.potionNames or {}
	local have: { [string]: number } = view.have or {}
	local seen: { [string]: boolean } = {}
	local defs: { any } = view.products or {}
	for _, def in defs do
		local potions = if type(def.prize) == "table" then def.prize.potions else nil
		if type(potions) ~= "table" then
			continue
		end
		for id in potions do
			if type(id) == "string" and not seen[id] then
				seen[id] = true
				local count = have[id]
				table.insert(out, {
					id = id,
					name = names[id] or id,
					count = if type(count) == "number" then math.max(0, math.floor(count)) else 0,
				})
			end
		end
	end
	table.sort(out, function(a: BagEntry, b: BagEntry): boolean
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.id < b.id
	end)
	return out
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
				effect = (if card.effect ~= "" then card.effect .. "\n" else "")
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
	-- #2850: the potions on one line, so the bigger bundle still fits the Featured hero on a phone
	local potions = def.prize.potions
	if potions and next(potions) ~= nil then
		effect ..= "\n" .. StoreLogic.contentsLine(potions, view.potionNames)
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
		-- "Season 1 paid track:" and the track's exact contents
		effect = CAFE_PASS.effect:format(offer.season) .. "\n" .. offer.contents,
		owned = offer.paid,
		product = true,
		tab = "cafePass",
		closed = offer.saleOpen == false,
	}
end

-- #1168: the Thank You Badge's row. Once the player is a supporter it stays and reads "Yours" (#2073), so it is not
-- bought twice and the card does not just vanish.
local function thankYouRow(config: any, view: ShopView?): Row?
	local id = productId(config, THANK_YOU)
	if id == nil or view == nil then
		return nil
	end
	return {
		key = THANK_YOU.key,
		passId = id,
		name = "Thank You Badge",
		icon = "💛",
		effect = THANK_YOU.effect,
		owned = view.supporter == true,
		product = true,
		tab = "passes",
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

-- #1822: what the King Cat Pack's worth adds up, as shared/KingPack.worthRefs: the King Cat alone pass and the Potion
-- Pack M product, both only once made (the looks-only pieces are never priced). nil while either is 0.
local function kingWorth(config: any): { number }?
	local cat = config.KingCatPassId
	local ids = config.ProductIds
	local potions = if type(ids) == "table" then ids.potion_pack_m else nil
	if type(cat) == "number" and cat ~= 0 and type(potions) == "number" and potions ~= 0 then
		return { cat, potions }
	end
	return nil
end

-- #1822/#1823 (store-layout-v2.md §2, §4): what a bundle's parts the player doesn't own yet cost bought apart, the
-- real sum of Roblox's prices, rounded down to R$5. nil while a part's price hasn't loaded or is off sale (never
-- guessed), for an owned bundle, or for a row that isn't a bundle. `owned` is the passes the player owns.
function StoreLogic.worth(
	row: Row,
	prices: { [number]: Price },
	owned: { [number]: boolean }?
): number?
	local ids = row.worthIds
	if ids == nil or #ids == 0 or row.owned then
		return nil
	end
	local sum = 0
	for _, id in ids do
		if owned and owned[id] then
			continue
		end
		local price = prices[id]
		if price == nil or not price.forSale or price.robux == nil then
			return nil
		end
		sum += price.robux :: number
	end
	return math.floor(sum / 5) * 5
end

-- The bundle's "Worth R$X" line (§2: muted, no strike-through, no "% off"); only when the parts left are worth more
-- than the bundle's own price, so it never reads as a loss.
function StoreLogic.worthLine(
	row: Row,
	prices: { [number]: Price },
	owned: { [number]: boolean }?
): string?
	local worth = StoreLogic.worth(row, prices, owned)
	local own = prices[row.passId]
	if worth == nil or own == nil or own.robux == nil or worth <= (own.robux :: number) then
		return nil
	end
	return ("Worth R$%s"):format(commas(worth))
end

-- §2: one badge at most. "Best Value" only when the parts left are worth at least 1.25 x the bundle's price; nothing
-- else ("Most Popular" waits for real sales data).
StoreLogic.BEST_VALUE = 1.25
function StoreLogic.badge(
	row: Row,
	prices: { [number]: Price },
	owned: { [number]: boolean }?
): string?
	local worth = StoreLogic.worth(row, prices, owned)
	local own = prices[row.passId]
	if worth == nil or own == nil or own.robux == nil or (own.robux :: number) <= 0 then
		return nil
	end
	return if worth >= StoreLogic.BEST_VALUE * (own.robux :: number) then "Best Value" else nil
end

-- #3572: the Sale badge. The old price to strike through on this card, or nil for no badge: only a card in
-- Config.StoreWasPrice that is not owned, on sale at exactly its half price, before Config.StoreSaleEnds. It has to
-- be true, so any other live price (a regional one, a later change) shows no badge. No countdown, no end date shown.
StoreLogic.SALE = "SALE"
function StoreLogic.saleWas(row: Row, price: Price?, config: any, now: number): number?
	local entry = if type(config.StoreWasPrice) == "table"
		then config.StoreWasPrice[row.key]
		else nil
	local ends = config.StoreSaleEnds
	if
		type(entry) ~= "table"
		or type(ends) ~= "number"
		or now >= ends
		or row.owned
		or row.closed == true
		or price == nil
		or not price.forSale
		or price.robux ~= entry.now
		or type(entry.was) ~= "number"
		or entry.was <= entry.now
	then
		return nil
	end
	return entry.was
end

-- The Sale badge's words (rich text): SALE and the old price struck through. The button beside it has the new price.
function StoreLogic.saleBadge(was: number): string
	-- "was" in words, so it reads right even where the strike line does not draw
	return ("%s  was <s>R$%s</s>"):format(StoreLogic.SALE, commas(was))
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

-- #1606 (Derek2 11-05: "shows 2x money on your screen somewhere near your money always and replaces itself with
-- 3x/4x if bought"): the badge beside the HUD's money. The highest money pass owned (Roblox's answer in `owned`, or
-- the server's PlayerState.passBoosts.money as `serverMultiplier`) reads "2x", "3x" or "4x"; with none, "Get 2x"
-- while the 2x pass is on sale (a tap opens the Store), else no badge.
-- price: #1759, the not-owned badge's line under its pill, "Only R$5" (nil once owned or with no price yet)
-- quiet: #1936 (release.md section 3), the first 30 minutes of play: a plain "x2" with no price that holds still, and
-- a tap still opens the Store
-- id: #2353 (Derek2 11-07: "just prompt them to buy it for robux not open shop"), the 2x pass a tap on the X2 Cash
-- pill buys straight away; nil while owned or quiet, so those taps work as before
export type MoneyBadge = {
	text: string,
	owned: boolean,
	price: string?,
	quiet: boolean?,
	id: number?,
}
function StoreLogic.moneyBadge(
	config: any,
	owned: { [number]: boolean },
	prices: { [number]: Price },
	serverMultiplier: number?,
	quiet: boolean?
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
	if price ~= nil and price.forSale and quiet then
		return { text = ("x%d"):format(first.multiplier), owned = false, quiet = true }
	end
	if price ~= nil and price.forSale then
		-- #1759 (Derek2 11-06: "more in your face then that slight 2x"): the HUD's rainbow buy button
		return {
			text = ("X%d Cash"):format(first.multiplier),
			owned = false,
			price = if price.robux ~= nil then ("Only R$%d"):format(price.robux :: number) else nil,
			id = first.id,
		}
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
			local thanks = thankYouRow(config, view)
			if thanks then
				table.insert(rows, thanks)
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
				perk = card.perk,
				worthIds = if card.key == "kingPack" then kingWorth(config) else nil,
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

-- #3572: the rows cheapest first, the rework's order inside each tab. A row whose price is not in yet (or is off
-- sale) goes after the priced ones; equal prices keep the Store's order. Rows are not changed, only reordered.
function StoreLogic.cheapestFirst(rows: { Row }, prices: { [number]: Price }?): { Row }
	local index: { [Row]: number } = {}
	for i, row in rows do
		index[row] = i
	end
	local function cost(row: Row): number
		local price = if prices then prices[row.passId] else nil
		return if price and price.forSale and price.robux then price.robux else math.huge
	end
	local out = table.clone(rows)
	table.sort(out, function(a: Row, b: Row): boolean
		local ca, cb = cost(a), cost(b)
		if ca ~= cb then
			return ca < cb
		end
		return index[a] < index[b]
	end)
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

-- #1823 §4 (store-layout-v2.md): the tabs whose New dot shows, from shared/StoreTabs.unseen. Only a tab the rail
-- shows gets one, so a tab with no cards (the Cafe Pass between seasons) never keeps the HUD's Store dot lit.
function StoreLogic.newTabs(unseen: { [string]: true }, rows: { Row }): { [string]: true }
	local out: { [string]: true } = {}
	for _, tab in StoreLogic.tabs(rows) do
		if unseen[tab.id] then
			out[tab.id] = true
		end
	end
	return out
end

export type Featured = { hero: Row?, picks: { Row } }

StoreLogic.PICKS = 3
-- #3562 (Derek: "should focus on cats bundles 2x money being cheap", "never show potion bundles unless they are only
-- thing left"). The hero, first one that can be bought: the Starter Bundle (the cat bundle for a new cafe), the
-- Royal Cat, the King Cat Pack, the running season's Cafe Pass, the Grand Cafe Theme. Earlier orders: #1425, #1823.
local HERO_ORDER = { "starterBundle", "royalCat", "kingPack", "cafePass", "grandTheme" }
-- The three picks, left to right, first three that can be bought and are not the hero: the money ladder's next rung
-- (2x Money is the cheapest thing in the Store), the cat bundles, then what brings more cats
-- (Second Bait Bowl, Extra Slot), VIP, Long Nap and the Cafe Pass. Earlier orders: #1823 §1, #2850.
local PICK_ORDER =
	{ "money", "royalCat", "kingPack", "secondBowl", "extraSlot", "vip", "longNap", "cafePass" }
-- Then the passes the player keeps that are mostly looks (#2303, Monetization-Agent's order). Any other pass comes
-- next, then any other product; the potion packs fill a pick only once nothing else can be bought.
local PASS_PICKS = {
	"accessories",
	"cafeStyle",
	"signStylePack",
	"gardenDecor",
	"grandTheme",
	"kingCat",
}

-- #3562: the potion packs (every card of PRODUCTS), last on Featured. They keep their place on the Potions tab.
local function potionPack(key: string): boolean
	for _, card in PRODUCTS do
		if card.key == key then
			return true
		end
	end
	return false
end

-- The Featured tab's cards: one hero and up to three picks, never the same row twice. Owned rows give way to ones
-- that can still be bought, and an empty spot is filled from PASS_PICKS, then the rest of the Store's passes, then
-- its other products, then the potion packs, each in order. #3562: with `prices`, a card Roblox says is off sale or
-- has no price is passed over too, so the tab never leads with "Soon" (a price still loading does not count: the
-- card shows "..." for a moment as before). Cards passed over only come back when nothing else fills the tab.
function StoreLogic.featured(rows: { Row }, prices: { [number]: Price }?): Featured
	local byKey: { [string]: Row } = {}
	for _, row in rows do
		byKey[row.key] = row
	end
	local function buyable(row: Row): boolean
		if row.owned or row.closed == true then
			return false
		end
		local price: Price? = if prices then prices[row.passId] else nil
		return price == nil or (price.forSale and price.robux ~= nil)
	end
	local hero: Row? = nil
	for _, key in HERO_ORDER do
		local row = byKey[key]
		if row and buyable(row) then
			hero = row
			break
		end
	end
	if hero == nil then
		-- #2072: everything is bought, so the hero still shows the first card of the order, marked Yours
		for _, key in HERO_ORDER do
			if byKey[key] then
				hero = byKey[key]
				break
			end
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
		if row and buyable(row) then
			take(row)
		end
	end
	for _, key in PASS_PICKS do
		local row = byKey[key]
		if row and buyable(row) then
			take(row)
		end
	end
	for _, row in rows do
		if buyable(row) and not row.product then
			take(row)
		end
	end
	for _, row in rows do
		if buyable(row) and not potionPack(row.key) then
			take(row)
		end
	end
	for _, row in rows do
		if buyable(row) then
			take(row) -- only the potion packs are left to buy
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
		return { text = "Yours", style = "ghost", enabled = false } -- #1823 §4
	end
	if row.closed == true then
		return { text = "Next season", style = "ghost", enabled = false } -- #2129
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

-- #1823: what each card showed at the last render, by row key: its pass id and whether it was owned.
export type Seen = { [string]: { passId: number, owned: boolean } }

-- #1823: the row keys whose pass the player has just bought since `seen`, for the store's thank-you burst. A card
-- that turned Owned counts, and so does the money card moving up a rung (its bought rung is gone from the rows, the
-- next one shows). Products are never owned, and a key not seen before (the first render) never counts. Returns the
-- keys and the new Seen.
function StoreLogic.justBought(seen: Seen, rows: { Row }): ({ string }, Seen)
	local bought: { string } = {}
	local now: Seen = {}
	for _, row in rows do
		if row.product == true then
			continue
		end
		now[row.key] = { passId = row.passId, owned = row.owned }
		local before = seen[row.key]
		if before and not before.owned then
			if (row.owned and before.passId == row.passId) or before.passId ~= row.passId then
				table.insert(bought, row.key)
			end
		end
	end
	return bought, now
end

return StoreLogic
