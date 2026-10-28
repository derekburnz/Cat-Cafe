--!strict
-- Potions and the Mystery Visitor's gift (F64, data-model section 12b). Pure rules, no Roblox services.
-- profile.buffs holds each running potion's seconds of play time left as of profile.lastTick (the last settle), so
-- the time left at `now` is that less the time since; Economy.settle counts the timers down with the time it pays and
-- nothing runs them down while the player is away (Derek 2026-10-27 22:14: "make potion time left pause on exit").

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Potions = {}

Potions.TIP = "tip_potion"
Potions.LUCKY = "lucky_potion"
Potions.SWIFT = "swift_potion"
Potions.STEADY = "steady_potion"

-- Seconds of play time left on a potion at `now`, 0 when it is not running. Nil-safe for fixtures without buffs.
function Potions.left(profile: Types.PlayerProfile, potionId: string, now: number): number
	local buffs = (profile :: any).buffs
	local left = if type(buffs) == "table" then buffs[potionId] else nil
	if type(left) ~= "number" or left ~= left then
		return 0
	end
	return math.max(0, left - math.max(0, now - profile.lastTick))
end

function Potions.running(profile: Types.PlayerProfile, potionId: string, now: number): boolean
	return Potions.left(profile, potionId, now) > 0
end

-- The Tip Potion's share on top of tips at `now` (income, the tip piles and rich visitors): 1 + TipPotionBonus
-- while it runs, else 1.
function Potions.tipMultiplier(profile: Types.PlayerProfile, now: number): number
	return if Potions.running(profile, Potions.TIP, now) then 1 + Config.TipPotionBonus else 1
end

-- Added to walk and carry speed while a Swift Potion runs.
function Potions.speedBonus(profile: Types.PlayerProfile, now: number): number
	return if Potions.running(profile, Potions.SWIFT, now) then Config.SwiftPotionSpeed else 0
end

-- The gold chance of food set in the bowl now: doubled while a Lucky Potion runs.
function Potions.baitGoldChance(profile: Types.PlayerProfile, chance: number, now: number): number
	return if Potions.running(profile, Potions.LUCKY, now)
		then chance * Config.LuckyPotionGoldScale
		else chance
end

-- The net level the circles use: the next one while a Steady Paw Potion runs. Circles clamps the level to the
-- highest in Config.NetWindows, so a Master net stays Master.
function Potions.netLevel(profile: Types.PlayerProfile, netLevel: number, now: number): number
	return if Potions.running(profile, Potions.STEADY, now) then netLevel + 1 else netLevel
end

-- Why UsePotion refuses, or nil: an unknown potion, none in the bag, or (v0.13.8) the potion's minutes on top of the
-- time left would go over PotionMaxMinutes, which is refused whole so nothing is wasted.
function Potions.useBlocker(profile: Types.PlayerProfile, potionId: string, now: number): string?
	local def = Catalog.getPotion(potionId)
	if def == nil then
		return "Unknown"
	end
	if (profile.potions[potionId] or 0) <= 0 then
		return "None"
	end
	if
		Potions.left(profile, potionId, now) + def.minutes * 60
		> Config.PotionMaxMinutes * 60 + 0.5
	then
		return "Full"
	end
	return nil
end

-- Drinks one: the bag loses it and its minutes go on that potion's time left. Settle first, so the time before `now`
-- has been paid at the old multipliers. Returns false when useBlocker refuses.
function Potions.use(profile: Types.PlayerProfile, potionId: string, now: number): boolean
	if Potions.useBlocker(profile, potionId, now) ~= nil then
		return false
	end
	local def = Catalog.getPotion(potionId) :: Types.PotionDef
	local count = (profile.potions[potionId] or 0) - 1
	if count > 0 then
		profile.potions[potionId] = count
	else
		profile.potions[potionId] = nil
	end
	local left = Potions.left(profile, potionId, now) + def.minutes * 60
	-- stored as of lastTick, so Potions.left reads `left` at `now`
	profile.buffs[potionId] = left + math.max(0, now - profile.lastTick)
	profile.stats.potionsUsed = (profile.stats.potionsUsed or 0) + 1
	return true
end

-- Counts every timer down by `elapsed` seconds of play and drops the ones that ran out (Economy.settle).
function Potions.tick(profile: Types.PlayerProfile, elapsed: number)
	local buffs = (profile :: any).buffs
	if type(buffs) ~= "table" or elapsed <= 0 then
		return
	end
	for id, left in buffs do
		local after = (if type(left) == "number" then left else 0) - elapsed
		buffs[id] = if after > 0 then after else nil
	end
end

-- The running potions' ids, least time left first (the order a rejoin shows them in, data-model 13).
function Potions.runningIds(profile: Types.PlayerProfile, now: number): { string }
	local ids: { string } = {}
	for _, def in Catalog.potions do
		if Potions.running(profile, def.id, now) then
			table.insert(ids, def.id)
		end
	end
	table.sort(ids, function(a, b)
		local la, lb = Potions.left(profile, a, now), Potions.left(profile, b, now)
		if la ~= lb then
			return la < lb
		end
		return a < b
	end)
	return ids
end

-- ProfileSync's `buffs`: each running potion's endsAt in server time, `now` being Workspace:GetServerTimeNow().
function Potions.endsAt(profile: Types.PlayerProfile, now: number): { [string]: number }
	local out: { [string]: number } = {}
	for _, def in Catalog.potions do
		local left = Potions.left(profile, def.id, now)
		if left > 0 then
			out[def.id] = now + left
		end
	end
	return out
end

-- A Mystery gift's contents, rolled when it appears. `roll` returns a number in [0, 1) each call.
export type Gift = { kind: Types.MysteryGiftKind, id: string?, count: number }

function Potions.rollGift(roll: () -> number): Gift
	local pick = roll() * 100
	local chosen = Catalog.mysteryGift[#Catalog.mysteryGift]
	for _, row in Catalog.mysteryGift do
		if pick < row.chance then
			chosen = row
			break
		end
		pick -= row.chance
	end
	if chosen.kind == "potion" then
		local index = math.clamp(math.floor(roll() * #Catalog.potions) + 1, 1, #Catalog.potions)
		return { kind = "potion", id = Catalog.potions[index].id, count = chosen.count }
	end
	return { kind = chosen.kind, id = chosen.id, count = chosen.count }
end

-- What an opened gift pays (v0.13.9): a spin opened with the spin bank at SpinBankCap pays the gift table's golden
-- fish instead, so a gift is never empty; every other gift pays as rolled. `banked` is the player's `spin.banked`.
function Potions.giftPaid(gift: Gift, banked: number): Gift
	if gift.kind ~= "spin" or banked < Config.SpinBankCap then
		return gift
	end
	for _, row in Catalog.mysteryGift do
		if row.kind == "fish" then
			return { kind = "fish", count = row.count }
		end
	end
	return gift
end

-- A gift as the prize shape Payout pays.
function Potions.giftPrize(gift: Gift): Types.IndexPrize
	if gift.kind == "potion" and gift.id ~= nil then
		return { potions = { [gift.id :: string] = gift.count } }
	elseif gift.kind == "lure" and gift.id ~= nil then
		return { lures = { [gift.id :: string] = gift.count } }
	elseif gift.kind == "fish" then
		return { fish = gift.count }
	elseif gift.kind == "spin" then
		return { spins = gift.count }
	end
	return {}
end

return Potions
