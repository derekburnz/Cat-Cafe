--!strict
-- The Admin Wheel (#4195, Derek 2026-11-14): an admin event (shared/CafeEvents, ADMIN_KINDS.wheel, the admin effect
-- `wheel = true`) during which every player may spin one wheel once. The rules live here; the server's
-- AdminWheelService rolls with its own Random and pays at once, so leaving mid-animation keeps the prize.
--   PRIZES                          the eight slices in wheel order, their `weight`s summing to 100 (percent)
--   pick(roll) -> Prize             the slice for a roll in [0, 1)
--   key(event) -> string            where a spin of `event` is marked in the save's codesRedeemed
--   spun(redeemed, event) -> bool   this account has spun this event's wheel
--   view(redeemed, event, on) -> View?   PlayerState.adminWheel while a wheel is up, else nil
--   catFor(prize, tier, secretOn, roll) -> CatDef?   the cat a "mythical" or "secret" slice gives
-- No new save field, so no save version step and no restart: a spin is marked in codesRedeemed like the update gift
-- (shared/UpdateGift), under "giftw" and two hashes of the event's id, which the Store's "Codes you've used" list
-- leaves out (UpdateGift.isKey) and no real code can collide with (no code starts with "gift").
-- Spins are free only: nothing sells one, and nothing here is bought (monetization-policy).

local CafeEvents = require(script.Parent.CafeEvents)
local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)
local UpdateGift = require(script.Parent.UpdateGift)

local AdminWheel = {}

AdminWheel.PREFIX = UpdateGift.PREFIX .. "w"
AdminWheel.BOOST = "admin_money_potion" -- the hour of 3x money (Catalog.potions; PotionService.give starts it)

-- `tokens` are Trait Tokens (the Mystic Pool's rerolls), `prize` anything Payout pays, `boost` a potion started at
-- once and `cat` a cat given like a gift cat. `tier` is the slice's colour band and analytics field.
export type Prize = {
	id: string,
	name: string,
	weight: number,
	tier: "good" | "great" | "jackpot",
	tokens: number?,
	prize: Types.IndexPrize?,
	boost: string?,
	cat: ("mythical" | "secret")?,
}
export type View = { eventId: string, spun: boolean, endsAt: number }

AdminWheel.PRIZES = {
	{ id = "rerolls20", name = "20 Trait Rerolls", weight = 22, tier = "good", tokens = 20 },
	{
		id = "fish200",
		name = "200 Golden Fish",
		weight = 22,
		tier = "good",
		prize = { fish = 200 },
	},
	{
		id = "crates5",
		name = "5 Golden Crates",
		weight = 15,
		tier = "good",
		prize = { crates = { highest_golden = 5 } },
	},
	{
		id = "potions",
		name = "Potion Chest",
		weight = 15,
		tier = "good",
		prize = { potions = { big_tip_potion = 10, lucky_potion = 10, swift_potion = 10 } },
	},
	{
		id = "money3x",
		name = "3x Money for 1 Hour",
		weight = 10,
		tier = "great",
		boost = AdminWheel.BOOST,
	},
	{ id = "mythical", name = "Mythical Cat", weight = 8, tier = "great", cat = "mythical" },
	{
		id = "mega",
		name = "50 Rerolls + 500 Golden Fish",
		weight = 6,
		tier = "jackpot",
		tokens = 50,
		prize = { fish = 500 },
	},
	{ id = "secret", name = "Secret Cat", weight = 2, tier = "jackpot", cat = "secret" },
} :: { Prize }

-- The slice a roll in [0, 1) lands on, and its place on the wheel.
function AdminWheel.pick(roll: number): (Prize, number)
	local at = math.clamp(roll, 0, 1) * 100
	local sum = 0
	for index, prize in AdminWheel.PRIZES do
		sum += prize.weight
		if at < sum then
			return prize, index
		end
	end
	return AdminWheel.PRIZES[#AdminWheel.PRIZES], #AdminWheel.PRIZES
end

function AdminWheel.get(id: string): (Prize?, number?)
	for index, prize in AdminWheel.PRIZES do
		if prize.id == id then
			return prize, index
		end
	end
	return nil, nil
end

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function base36(value: number): string
	local out = ""
	repeat
		local digit = value % 36
		out = string.sub(DIGITS, digit + 1, digit + 1) .. out
		value = value // 36
	until value == 0
	return out
end

local function hash(text: string, factor: number, modulus: number): number
	local h = 7
	for i = 1, #text do
		h = (h * factor + string.byte(text, i)) % modulus
	end
	return h
end

-- The codesRedeemed key one event's spin is marked under: letters and digits, at most 19 long (the save keeps keys
-- up to Config.CodeMaxLength). A test event (one server, `/admin wheel` in Studio or a private server) has one id
-- for every run, so its start goes into the key and each run is its own wheel.
function AdminWheel.key(event: CafeEvents.AdminEvent): string
	local text = if event.test then event.id .. "@" .. tostring(event.startsAt) else event.id
	return AdminWheel.PREFIX
		.. base36(hash(text, 31, 4294967296))
		.. base36(hash(text, 131, 4294967291))
end

function AdminWheel.spun(redeemed: { [string]: number }, event: CafeEvents.AdminEvent): boolean
	return redeemed[AdminWheel.key(event)] ~= nil
end

-- PlayerState.adminWheel: the wheel that is up now and whether this account has spun it; nil with the adminEvents
-- switch off (`on`), no admin event, or one without the wheel.
function AdminWheel.view(
	redeemed: { [string]: number },
	event: CafeEvents.AdminEvent?,
	on: boolean
): View?
	if not on or event == nil or not event.effects.wheel then
		return nil
	end
	return { eventId = event.id, spun = AdminWheel.spun(redeemed, event), endsAt = event.endsAt }
end

-- The Mythical cats of the newest area a player at `tier` has opened that has any (an area's own cats only: no
-- shop, spare or Secret cat).
function AdminWheel.mythicals(tier: number): { Types.CatDef }
	local best: { Types.CatDef } = {}
	local bestTier = -math.huge
	for _, area in Catalog.areas do
		if area.tier > tier or area.tier <= bestTier then
			continue
		end
		local found: { Types.CatDef } = {}
		for _, def in Catalog.cats do
			if def.area == area.id and def.rarity == "Mythical" and def.exclusive ~= true then
				table.insert(found, def)
			end
		end
		if #found > 0 then
			best = found
			bestTier = area.tier
		end
	end
	return best
end

-- The cat a cat slice gives a player at `tier`, chosen evenly with `roll` in [0, 1): a Mythical of their newest
-- opened area, or one of the Secret cats. With the `secretCats` switch off (`secretOn`) the Secret slice gives the
-- Mythical instead, so no Secret cat is handed out before they are in the game. Nil for a slice with no cat.
function AdminWheel.catFor(
	prize: Prize,
	tier: number,
	secretOn: boolean,
	roll: number
): Types.CatDef?
	if prize.cat == nil then
		return nil
	end
	local pool = if prize.cat == "secret"
			and secretOn
			and #Catalog.secretCats > 0
		then Catalog.secretCats
		else AdminWheel.mythicals(tier)
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
end

return AdminWheel
