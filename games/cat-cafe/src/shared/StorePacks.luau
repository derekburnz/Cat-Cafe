--!strict
-- The Store's four outfit packs (#4026, Derek's OK of store-v2-draft.png 2026-11-13 20:13 UTC), pure: each pack is a
-- game pass that gives a cafe sign style (SignStyles), a decor piece (Catalog.passDecor, given by ShopCatService
-- through PassDecor), a staff uniform colour and a cat wearable (Looks). Every piece adds money while it is in use:
-- the decor its own +25% as any decor does (its Catalog row), the sign +25%, the uniform +15% and the wearable +15%
-- here, and all four of one pack in use add SET more, so a whole pack is +100% (StoreLogic.PACKS has the words).
-- Owned through the pass, looked up each session, so nothing is saved for a pack; the picks are the usual Looks,
-- sign style and decor saves. A pass id of 0 (not made yet) gives nothing and its Store card does not show.
--   bonus(profile, owns) -> number   what the packs add into Economy.cafeMultiplier past their decor
--   inUse(profile, pack) -> count, all   how many of a pack's four pieces are in use, and whether all four are

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local StorePacks = {}

StorePacks.SIGN = 0.25
StorePacks.DECOR = 0.25 -- in the decor piece's Catalog row (`bonus`), counted with the other placed decor
StorePacks.WEAR = 0.15 -- the uniform and the cat wearable, each
StorePacks.SET = 0.2

export type Pack = {
	key: string, -- StoreLogic.PACKS key
	passKey: string, -- the Config field with its pass id
	sign: string, -- SignStyles id
	decor: string, -- Catalog decor id
	uniform: string, -- Looks uniform id
	accessory: string, -- Looks accessory id
}

StorePacks.LIST = table.freeze({
	table.freeze({
		key = "stylish",
		passKey = "StylishPackPassId",
		sign = "pack_club_banner",
		decor = "decor_pack_disco_ball",
		uniform = "uniform_club_suit",
		accessory = "acc_cool_shades",
	}),
	table.freeze({
		key = "winter",
		passKey = "WinterPackPassId",
		sign = "pack_snowy_banner",
		decor = "decor_pack_cocoa_stand",
		uniform = "uniform_winter_coat",
		accessory = "acc_bobble_hat",
	}),
	table.freeze({
		key = "chef",
		passKey = "ChefPackPassId",
		sign = "pack_bakery_banner",
		decor = "decor_pack_pastry_case",
		uniform = "uniform_chef_whites",
		accessory = "acc_chef_hat",
	}),
	table.freeze({
		key = "space",
		passKey = "SpacePackPassId",
		sign = "pack_star_banner",
		decor = "decor_pack_rocket_lamp",
		uniform = "uniform_space_suit",
		accessory = "acc_bubble_helmet",
	}),
}) :: { Pack }

-- The pass id Config holds for `pack`, 0 while it is not made.
function StorePacks.passId(pack: Pack): number
	local id = (Config :: any)[pack.passKey]
	return if type(id) == "number" then id else 0
end

-- How many of `pack`'s four pieces the save has in use (the sign and the looks picked, the decor owned and placed),
-- and whether all four are. Ownership of the pack itself is the caller's (bonus).
function StorePacks.inUse(profile: Types.PlayerProfile, pack: Pack): (number, boolean)
	local looks = (profile :: any).looks
	local count = 0
	if profile.signStyle == pack.sign then
		count += 1
	end
	if profile.decorOwned[pack.decor] == true and profile.decorPlaced[pack.decor] == true then
		count += 1
	end
	if type(looks) == "table" and looks.uniform == pack.uniform then
		count += 1
	end
	if type(looks) == "table" and looks.accessory == pack.accessory then
		count += 1
	end
	return count, count == 4
end

-- What the packs the player owns add into Economy.cafeMultiplier: the sign, uniform and wearable of each owned pack
-- while in use, and SET for a pack with all four in use. The decor's +25% is counted with the other decor, not here.
-- `owns(key)` says whether the player owns the pack with that StorePacks key (Economy.passes().packs).
function StorePacks.bonus(profile: Types.PlayerProfile, owns: (key: string) -> boolean): number
	local looks = (profile :: any).looks
	local uniform = if type(looks) == "table" then looks.uniform else nil
	local accessory = if type(looks) == "table" then looks.accessory else nil
	local total = 0
	for _, pack in StorePacks.LIST do
		if not owns(pack.key) then
			continue
		end
		if profile.signStyle == pack.sign then
			total += StorePacks.SIGN
		end
		if uniform == pack.uniform then
			total += StorePacks.WEAR
		end
		if accessory == pack.accessory then
			total += StorePacks.WEAR
		end
		local _, all = StorePacks.inUse(profile, pack)
		if all then
			total += StorePacks.SET
		end
	end
	return total
end

return StorePacks
