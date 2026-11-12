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
-- F73 (quests.md section 4): the quest potions
Potions.BIG_TIP = "big_tip_potion"
Potions.GOLD_RUSH = "gold_rush_potion"
Potions.QUICK_BAIT = "quick_bait_potion"
-- #3462: the Day Cart's Tier 6 potions
Potions.BIG_LUCKY = "big_lucky_potion"
Potions.BIG_GOLD_RUSH = "big_gold_rush_potion"
Potions.MEGA_TIP = "mega_tip_potion"

-- The timer a potion runs (corner-shop-v2.md section 4): a Small or Big size's regular potion, else its own id.
function Potions.buffOf(potionId: string): string
	local def = Catalog.getPotion(potionId)
	return if def ~= nil and def.buff ~= nil then def.buff else potionId
end

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

-- The running potions' share on top of tips at `now` (income, the tip piles and rich visitors): 1 plus every running
-- potion's `tips` (the Tip Potion's TipPotionBonus, F73's Big Tip Potion's 0.5), together at most TimedTipsMax.
function Potions.tipMultiplier(profile: Types.PlayerProfile, now: number): number
	local bonus = 0
	for _, def in Catalog.potions do
		if def.tips ~= nil and Potions.running(profile, def.id, now) then
			bonus += def.tips
		end
	end
	return 1 + math.min(bonus, Config.TimedTipsMax)
end

-- F73: the gold luck the running potions add at `now` (a Gold Rush Potion's 0.25), on top of the Index's.
function Potions.goldLuck(profile: Types.PlayerProfile, now: number): number
	local luck = 0
	for _, def in Catalog.potions do
		if def.goldLuck ~= nil and Potions.running(profile, def.id, now) then
			luck += def.goldLuck
		end
	end
	return luck
end

-- F73: the bait speed the running potions add at `now` (a Quick Bait Potion's 0.25); Economy.baitWaitSeconds keeps
-- the sum with the Index's inside BaitSpeedMax.
function Potions.baitSpeed(profile: Types.PlayerProfile, now: number): number
	local speed = 0
	for _, def in Catalog.potions do
		if def.baitSpeed ~= nil and Potions.running(profile, def.id, now) then
			speed += def.baitSpeed
		end
	end
	return speed
end

-- The most gold luck every potion together can add, for IndexRewards.rollChance's cap.
Potions.MAX_GOLD_LUCK = 0
for _, def in Catalog.potions do
	Potions.MAX_GOLD_LUCK += def.goldLuck or 0
end

-- #3462: the Luck the running lucky potions give at `now` and the seconds it lasts at that value: the biggest of a
-- running Lucky Potion's Config.LuckyPotionLuck and every running potion's own `luck` (the Big Lucky Potion's). They
-- never add. 0 and 0 with none running.
function Potions.luck(profile: Types.PlayerProfile, now: number): (number, number)
	local best, left = 0, 0
	local lucky = Potions.left(profile, Potions.LUCKY, now)
	if lucky > 0 then
		best, left = Config.LuckyPotionLuck, lucky
	end
	for _, def in Catalog.potions do
		if def.luck ~= nil and def.luck > best then
			local mine = Potions.left(profile, def.id, now)
			if mine > 0 then
				best, left = def.luck, mine
			end
		end
	end
	return best, left
end

-- Added to walk and carry speed while a Swift Potion runs.
function Potions.speedBonus(profile: Types.PlayerProfile, now: number): number
	return if Potions.running(profile, Potions.SWIFT, now) then Config.SwiftPotionSpeed else 0
end

-- The gold chance of food set in the bowl now: doubled while a Lucky Potion runs, or a Big Lucky Potion (#3462).
function Potions.baitGoldChance(profile: Types.PlayerProfile, chance: number, now: number): number
	return if Potions.luck(profile, now) > 0 then chance * Config.LuckyPotionGoldScale else chance
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
		Potions.left(profile, Potions.buffOf(potionId), now) + def.minutes * 60
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
	local buff = Potions.buffOf(potionId)
	local left = Potions.left(profile, buff, now) + def.minutes * 60
	-- stored as of lastTick, so Potions.left reads `left` at `now`
	profile.buffs[buff] = left + math.max(0, now - profile.lastTick)
	profile.stats.potionsUsed = (profile.stats.potionsUsed or 0) + 1
	return true
end

-- #1600 (the Bag's "Use all"): how many of `potionId` could be drunk now, one after another: the bag's count, cut to
-- what fits under PotionMaxMinutes with the time left (0 for an unknown potion).
function Potions.fitCount(profile: Types.PlayerProfile, potionId: string, now: number): number
	local def = Catalog.getPotion(potionId)
	local have = profile.potions[potionId] or 0
	if def == nil or have <= 0 or def.minutes <= 0 then
		return 0
	end
	local room = Config.PotionMaxMinutes * 60
		+ 0.5
		- Potions.left(profile, Potions.buffOf(potionId), now)
	return math.clamp(math.floor(room / (def.minutes * 60)), 0, have)
end

-- Drinks up to `count` of `potionId` (Potions.use each), stopping at the first one useBlocker refuses. Returns how
-- many were drunk.
function Potions.useMany(
	profile: Types.PlayerProfile,
	potionId: string,
	count: number,
	now: number
): number
	local drunk = 0
	while drunk < count and Potions.use(profile, potionId, now) do
		drunk += 1
	end
	return drunk
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

-- The potions a Common Mystery gift can hold, at even odds: every one but the quest potions (F73), the Corner Shop's
-- own (corner-shop-v2.md: its sizes and the Cat Whistle) and, since #2614, the Swift Potion. A Rare gift's
-- "questPotion" is one of the quest potions.
local GIFT_POTIONS: { string } = {}
local QUEST_POTIONS: { string } = {}
for _, def in Catalog.potions do
	if def.quest == true then
		table.insert(QUEST_POTIONS, def.id)
	elseif def.shopOnly ~= true and def.id ~= "swift_potion" then
		table.insert(GIFT_POTIONS, def.id)
	end
end
Potions.GIFT_POTIONS = GIFT_POTIONS
Potions.QUEST_POTIONS = QUEST_POTIONS

-- A Mystery gift's contents, rolled when it appears. `roll` returns a number in [0, 1) each call.
export type Gift = {
	kind: Types.MysteryGiftKind,
	id: string?,
	count: number,
	tier: Types.MysteryGiftTierName?,
	fish: number?,
}

local function tierNamed(name: Types.MysteryGiftTierName): Types.MysteryGiftTier
	for _, tier in Catalog.mysteryGiftTiers do
		if tier.tier == name then
			return tier
		end
	end
	return Catalog.mysteryGiftTiers[1]
end

-- #2614: the wrap of a gift. `commons` is how many Common gifts in a row came before it this session: from
-- MysteryRareStreak on, the Common share is left out and the rest share the roll.
function Potions.rollGiftTier(roll: () -> number, commons: number?): Types.MysteryGiftTierName
	local skipCommon = (commons or 0) >= Config.MysteryRareStreak
	local total = 0
	for _, tier in Catalog.mysteryGiftTiers do
		if not (skipCommon and tier.tier == "Common") then
			total += tier.chance
		end
	end
	local pick = roll() * total
	local chosen: Types.MysteryGiftTierName = "Common"
	for _, tier in Catalog.mysteryGiftTiers do
		if skipCommon and tier.tier == "Common" then
			continue
		end
		chosen = tier.tier
		if pick < tier.chance then
			break
		end
		pick -= tier.chance
	end
	return chosen
end

-- A gift of wrap `tierName` (rolled with rollGiftTier when nil): a row at its chance, a potion at even odds.
function Potions.rollGift(roll: () -> number, tierName: Types.MysteryGiftTierName?): Gift
	local tier = tierNamed(tierName or Potions.rollGiftTier(roll))
	local pick = roll() * 100
	local chosen = tier.rows[#tier.rows]
	for _, row in tier.rows do
		if pick < row.chance then
			chosen = row
			break
		end
		pick -= row.chance
	end
	if chosen.kind == "potion" or chosen.kind == "questPotion" then
		local pool = if chosen.kind == "questPotion" then QUEST_POTIONS else GIFT_POTIONS
		local index = math.clamp(math.floor(roll() * #pool) + 1, 1, #pool)
		return { kind = "potion", id = pool[index], count = chosen.count, tier = tier.tier }
	end
	return {
		kind = chosen.kind,
		id = chosen.id,
		count = chosen.count,
		tier = tier.tier,
		fish = chosen.fish,
	}
end

-- The average golden fish a gift pays (Pace and the spec check it, #2614: about 3.8).
function Potions.giftFishAverage(): number
	local total = 0
	for _, tier in Catalog.mysteryGiftTiers do
		local fish = 0
		for _, row in tier.rows do
			local count = if row.kind == "fish" then row.count else row.fish or 0
			fish += row.chance / 100 * count
		end
		total += tier.chance / 100 * fish
	end
	return total
end

-- What an opened gift pays (v0.13.9): a spin opened with the spin bank at SpinBankCap pays its wrap's golden fish row
-- instead, so a gift is never empty; every other gift pays as rolled. `banked` is the player's `spin.banked`.
function Potions.giftPaid(gift: Gift, banked: number): Gift
	if gift.kind ~= "spin" or banked < Config.SpinBankCap then
		return gift
	end
	for _, row in tierNamed(gift.tier or "Common").rows do
		if row.kind == "fish" then
			return { kind = "fish", count = row.count, tier = gift.tier }
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
	elseif gift.kind == "coins" then
		return { coins = 0, coinSeconds = gift.count } -- #2614: seconds of the player's income
	elseif gift.kind == "crate" and gift.id ~= nil then
		return { crates = { [gift.id :: string] = gift.count }, fish = gift.fish }
	elseif gift.kind == "food" and gift.id ~= nil then
		return { catFood = { [gift.id :: string] = gift.count } }
	end
	return {}
end

return Potions
