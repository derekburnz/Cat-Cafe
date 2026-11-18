--!strict
-- #5172 (Derek 2026-11-17 23:56 UTC, a player's idea: a cat that follows you around for more money or more luck,
-- picked in a menu): behind the `catFollower` switch (LiveFlags, off by default). From Tier 2 the player picks one of
-- their own cats to follow them and one boost, Money or Luck, by the cat's rarity. The cat keeps its cafe job and
-- income while it follows. Money adds to the tip multiplier (Economy.tipMultiplier, like a Money Potion, online pay
-- only); Luck is a Luck source (Luck.sources, still at most LuckMax). Nothing here is sold for Robux.
-- The save is `profile.follower` ({ uid, boost }); no version bump, so the switch goes on only after a restart.

local Traits = require(script.Parent.Traits)
local Types = require(script.Parent.Types)

local Follower = {}

Follower.FLAG = "catFollower"
Follower.OPEN_TIER = 2 -- after the first Rank Up
Follower.SWITCH_SECONDS = 10 -- between boost switches
Follower.HOME = "" -- the saved uid with no follower

export type Boost = "money" | "luck"
export type Save = { uid: string, boost: Boost }

-- The boost by the following cat's rarity (cat-follower-spec.md): Money is a share of the cafe's pay, Luck adds to
-- the Luck number.
Follower.MONEY = table.freeze({
	Common = 0.03,
	Rare = 0.05,
	Epic = 0.08,
	Legendary = 0.12,
	Mythical = 0.16,
	Secret = 0.20,
}) :: { [string]: number }
Follower.LUCK = table.freeze({
	Common = 0.05,
	Rare = 0.10,
	Epic = 0.15,
	Legendary = 0.20,
	Mythical = 0.30,
	Secret = 0.40,
}) :: { [string]: number }

-- Derek 2026-11-18 (via Design): the coat raises the boost too, the rarity's boost times this; a rainbow Secret gives
-- +30% Money or +0.60 Luck.
Follower.COAT = table.freeze({ gold = 1.25, rainbow = 1.5 }) :: { [string]: number }

function Follower.coat(variant: string?): number
	return if variant ~= nil then Follower.COAT[variant] or 1 else 1
end

-- The switch: set by the specs, else the ReplicatedStorage attribute LiveFlagService copies it to (as DragonKeep).
local onOverride: boolean? = nil
function Follower.setOn(on: boolean?)
	onOverride = on
end
function Follower.on(): boolean
	if onOverride ~= nil then
		return onOverride
	end
	return game:GetService("ReplicatedStorage"):GetAttribute("LiveFlag_" .. Follower.FLAG) == true
end

-- #5296 (Derek 2026-11-18: "don't make it have a switch between stats just have it to an amount for both"), switch
-- BOTH_FLAG (LiveFlags.OFF_BY_DEFAULT): the companion gives its full Money and its full Luck together (Design: no one
-- loses anything, far under LuckMax), and the Cats window picks it from the Companion button (Screens/CatRoom).
Follower.BOTH_FLAG = "companionMenu"
local bothOverride: boolean? = nil
function Follower.setBoth(on: boolean?)
	bothOverride = on
end
function Follower.both(): boolean
	if bothOverride ~= nil then
		return bothOverride
	end
	return game:GetService("ReplicatedStorage"):GetAttribute("LiveFlag_" .. Follower.BOTH_FLAG)
		== true
end

-- "+12% Money · +0.20 Luck", the two boosts a cat of `rarity` and `variant` brings as the companion.
function Follower.bothText(rarity: string?, variant: string?): string
	local money = math.floor(Follower.amount(rarity, "money", variant) * 1000 + 0.5) / 10
	local luck = Follower.amount(rarity, "luck", variant)
	local percent = if money == math.floor(money)
		then string.format("%d", money)
		else string.format("%.1f", money)
	return string.format("+%s%% Money · +%.2f Luck", percent, luck)
end

function Follower.fresh(): Save
	return { uid = Follower.HOME, boost = "money" }
end

-- A save's follower made valid: a short uid string ("" for none) and a known boost.
function Follower.sanitize(raw: unknown): Save
	local save = Follower.fresh()
	if type(raw) == "table" then
		local uid = (raw :: any).uid
		local boost = (raw :: any).boost
		if type(uid) == "string" and #uid <= 64 then
			save.uid = uid
		end
		if boost == "luck" then
			save.boost = "luck"
		end
	end
	return save
end

-- Why `uid` cannot follow now, or nil: the switch, the tier, owning the cat, a running trade.
function Follower.blocker(profile: Types.PlayerProfile, uid: string, trading: boolean): string?
	if not Follower.on() then
		return "Cat Companions are not open yet"
	elseif (profile.tier or 1) < Follower.OPEN_TIER then
		return "Cat Companions open at Tier " .. Follower.OPEN_TIER
	elseif profile.cats[uid] == nil then
		return "That cat is not yours"
	elseif trading then
		return "Finish your trade first"
	end
	return nil
end

local function saveOf(profile: Types.PlayerProfile): Save?
	local save = (profile :: any).follower
	return if type(save) == "table" then save :: Save else nil
end

-- The cat following now: the saved one while the switch is on, the player is at Tier 2 or up and still owns it.
function Follower.cat(profile: Types.PlayerProfile): Types.CatInstance?
	local save = saveOf(profile)
	if save == nil or save.uid == Follower.HOME or not Follower.on() then
		return nil
	end
	if (profile.tier or 1) < Follower.OPEN_TIER then
		return nil
	end
	return profile.cats[save.uid]
end

-- The boost kind picked (Money until the player picks Luck).
function Follower.boost(profile: Types.PlayerProfile): Boost
	local save = saveOf(profile)
	if save ~= nil and save.boost == "luck" then
		return "luck"
	end
	return "money"
end

-- What a cat of `rarity` and coat `variant` ("gold", "rainbow" or nil) gives with `boost`, 0 for an unknown rarity.
-- Rounded to a hundredth of a percent so 0.12 x 1.5 reads 0.18.
function Follower.amount(rarity: string?, boost: Boost, variant: string?): number
	local table_ = if boost == "luck" then Follower.LUCK else Follower.MONEY
	local base = if rarity ~= nil then table_[rarity] or 0 else 0
	return math.floor(base * Follower.coat(variant) * 10000 + 0.5) / 10000
end

-- #5303 (companionTraits): what the cat's trait adds to `boost`, added after the coat (the coat multiplies the base
-- only), 0 while the switch is off or for a trait with no companion effect.
function Follower.traitPart(trait: Types.TraitData?, boost: Boost): number
	if trait == nil or not Traits.companionOn() then
		return 0
	end
	return Traits.amount(
		trait :: any,
		if boost == "luck" then "companionLuck" else "companionMoney"
	)
end

-- Whether the companion traits count (the companionTraits switch, through shared/CompanionTraits).
function Follower.traitsOn(): boolean
	return Traits.companionOn()
end

-- The trait's rarity colour (hex) for its chip, nil for none.
function Follower.traitColor(trait: Types.TraitData?): string?
	local rarity = if trait then Traits.rarity(trait :: any) else nil
	return if rarity then rarity.color else nil
end

-- A cat's whole companion boost: the rarity's times the coat, plus its trait's part.
function Follower.catAmount(cat: Types.CatInstance, rarity: string?, boost: Boost): number
	local sum = Follower.amount(rarity, boost, cat.variant) + Follower.traitPart(cat.trait, boost)
	return math.floor(sum * 10000 + 0.5) / 10000
end

-- "+12% Money · +0.20 Luck" for this cat, its trait included.
function Follower.catBothText(cat: Types.CatInstance, rarity: string?): string
	local money = math.floor(Follower.catAmount(cat, rarity, "money") * 1000 + 0.5) / 10
	local luck = Follower.catAmount(cat, rarity, "luck")
	local percent = if money == math.floor(money)
		then string.format("%d", money)
		else string.format("%.1f", money)
	return string.format("+%s%% Money · +%.2f Luck", percent, luck)
end

-- The trait's chip under a companion's numbers, "Loyal Heart +3%" or "Lucky Shadow +0.08", nil for none.
function Follower.traitChip(trait: Types.TraitData?): string?
	local money = Follower.traitPart(trait, "money")
	local luck = Follower.traitPart(trait, "luck")
	if trait == nil or (money <= 0 and luck <= 0) then
		return nil
	end
	local parts: { string } = { Traits.title(trait :: any) }
	if money > 0 then
		table.insert(parts, string.format("+%d%%", math.floor(money * 100 + 0.5)))
	end
	if luck > 0 then
		table.insert(parts, string.format("+%.2f", luck))
	end
	return table.concat(parts, " ")
end

-- The boost's words for the Cats menu: "+18% money", "+0.60 Luck".
function Follower.text(amount: number, boost: Boost): string
	if boost == "luck" then
		return string.format("+%.2f Luck", amount)
	end
	local percent = math.floor(amount * 1000 + 0.5) / 10
	if percent == math.floor(percent) then
		return string.format("+%d%% money", percent)
	end
	return string.format("+%.1f%% money", percent)
end

-- The coat's chip (Derek 2026-11-18): "Gold x1.25", "Rainbow x1.5", nil for the base coat.
function Follower.coatText(variant: string?): string?
	if variant == "gold" then
		return "Gold x1.25"
	elseif variant == "rainbow" then
		return "Rainbow x1.5"
	end
	return nil
end

-- `rarityOf(catId)` is Catalog's lookup, passed in so this module needs no Catalog (Economy and Luck require it).
local function current(profile: Types.PlayerProfile, rarityOf: (string) -> string?): (Boost, number)
	local cat = Follower.cat(profile)
	local boost: Boost = Follower.boost(profile)
	if cat == nil then
		return boost, 0
	end
	return boost, Follower.catAmount(cat, rarityOf(cat.catId), boost)
end

-- The Money boost added to the tip multiplier now (0.12 is +12%), 0 with Luck picked or nobody following.
function Follower.money(profile: Types.PlayerProfile, rarityOf: (string) -> string?): number
	if Follower.both() then -- #5296
		local cat = Follower.cat(profile)
		return if cat ~= nil then Follower.catAmount(cat, rarityOf(cat.catId), "money") else 0
	end
	local boost, amount = current(profile, rarityOf)
	return if boost == "money" then amount else 0
end

-- The Luck boost added as a Luck source now, 0 with Money picked or nobody following.
function Follower.luck(profile: Types.PlayerProfile, rarityOf: (string) -> string?): number
	if Follower.both() then -- #5296
		local cat = Follower.cat(profile)
		return if cat ~= nil then Follower.catAmount(cat, rarityOf(cat.catId), "luck") else 0
	end
	local boost, amount = current(profile, rarityOf)
	return if boost == "luck" then amount else 0
end

return Follower
