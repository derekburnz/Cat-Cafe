--!strict
-- Equip Best for decor (Derek 2026-10-28: "Equip Best for decor (highest rarity)"), pure. A crate piece's money bonus
-- grows with its rarity (Config.CratePieceBonus), so the best decor is the highest rarity: `plan` says which owned
-- pieces to put out for the most money, and the server's EquipBestDecor applies it.
-- - Furniture and decorations (Crates.takesSpot): the best owned pieces up to the tier's decor spots (`cap`), by
--   bonus, then rarity, then a piece already out, then id, so a tie never moves a piece for nothing.
-- - Wallpaper, floor, paint, door set and cat flap (Crates.isStyle): one each; the owned piece with the highest bonus,
--   but the one in use stays when nothing beats it, so the cafe's look only changes for more money.
-- - The old coin pieces (no kind, their own anchors, no spot): every owned one goes out.
-- Nothing is ever bought or unlocked here; only owned pieces move.
-- #2068 (Auto Equip, Design-Agent 2026-11-07): `swapFor` picks the placed piece a new crate or pass piece replaces
-- when every spot is full: only furniture and decorations, only for a strictly higher bonus, never a piece the player
-- put out by hand in the last HAND_HOLD_SECONDS.

local Catalog = require(script.Parent.Catalog)
local Crates = require(script.Parent.Crates)
local Types = require(script.Parent.Types)

local DecorBest = {}

DecorBest.HAND_HOLD_SECONDS = 600 -- #2068: a piece put out by hand stays at least this long under Auto Equip

export type Plan = {
	placed: { [string]: boolean }, -- the new decorPlaced: every piece to have out
	bonus: number, -- the money bonus of the pieces in `placed`
	pieces: number, -- how many pieces that is
}

local function rank(def: Types.DecorDef): number
	return if def.rarity ~= nil then Catalog.rarityRank[def.rarity] or 0 else 0
end

-- Whether `a` is a better piece to have out than `b` (both owned); `current` names the pieces out now.
local function better(a: Types.DecorDef, b: Types.DecorDef, current: { [string]: boolean }): boolean
	if a.bonus ~= b.bonus then
		return a.bonus > b.bonus
	end
	if rank(a) ~= rank(b) then
		return rank(a) > rank(b)
	end
	local aOut, bOut = current[a.id] == true, current[b.id] == true
	if aOut ~= bOut then
		return aOut
	end
	return a.id < b.id
end

-- What to have out with `cap` decor spots (Crates.spotCap for the player's tier and spot perk).
function DecorBest.plan(profile: Types.PlayerProfile, cap: number): Plan
	local current: { [string]: boolean } = {}
	for decorId, placed in profile.decorPlaced do
		if placed and profile.decorOwned[decorId] then
			current[decorId] = true
		end
	end
	local spotPieces: { Types.DecorDef } = {}
	local bestStyle: { [string]: Types.DecorDef } = {} -- by kind
	local placed: { [string]: boolean } = {}
	for decorId, owned in profile.decorOwned do
		local def = if owned then Catalog.getDecor(decorId) else nil
		if def ~= nil then
			if Crates.takesSpot(def) then
				table.insert(spotPieces, def)
			elseif Crates.isStyle(def.kind) then
				local kind = tostring(def.kind)
				local best = bestStyle[kind]
				if best == nil or better(def, best, current) then
					bestStyle[kind] = def
				end
			elseif def.kind == nil then
				placed[def.id] = true
			end
		end
	end
	table.sort(spotPieces, function(a: Types.DecorDef, b: Types.DecorDef): boolean
		return better(a, b, current)
	end)
	for i = 1, math.min(#spotPieces, math.max(0, math.floor(cap))) do
		placed[spotPieces[i].id] = true
	end
	for _, def in bestStyle do
		placed[def.id] = true
	end
	local bonus, pieces = 0, 0
	for decorId in placed do
		local def = Catalog.getDecor(decorId) :: Types.DecorDef
		bonus += def.bonus
		pieces += 1
	end
	return { placed = placed, bonus = bonus, pieces = pieces }
end

-- #2068: the placed furniture or decoration piece that the new owned piece `newId` should replace, or nil: the weakest
-- placed one (lowest bonus, then rarity, then id) that `held` doesn't name, and only when `newId`'s bonus is strictly
-- higher. Nil too for a style piece, a piece already out or one not owned. The caller checks the spots are full.
function DecorBest.swapFor(
	profile: Types.PlayerProfile,
	newId: string,
	held: { [string]: boolean }
): string?
	local new = Catalog.getDecor(newId)
	if
		new == nil
		or not profile.decorOwned[newId]
		or profile.decorPlaced[newId]
		or not Crates.takesSpot(new)
	then
		return nil
	end
	local weakest: Types.DecorDef? = nil
	for decorId, placed in profile.decorPlaced do
		local def = if placed
				and profile.decorOwned[decorId]
				and not held[decorId]
			then Catalog.getDecor(decorId)
			else nil
		if
			def ~= nil
			and Crates.takesSpot(def)
			and (weakest == nil or better(weakest, def, {}))
		then
			weakest = def
		end
	end
	if weakest ~= nil and new.bonus > weakest.bonus then
		return weakest.id
	end
	return nil
end

-- Whether the plan is what the player already has out.
function DecorBest.isSame(profile: Types.PlayerProfile, plan: Plan): boolean
	for decorId, placed in profile.decorPlaced do
		if placed and profile.decorOwned[decorId] and not plan.placed[decorId] then
			return false
		end
	end
	for decorId in plan.placed do
		if not profile.decorPlaced[decorId] then
			return false
		end
	end
	return true
end

return DecorBest
