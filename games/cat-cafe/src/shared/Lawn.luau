--!strict
-- The front lawn (F91, front-lawn.md): six lawn spots in the front garden, the pieces bought for them with coins and
-- one path and one fence style at a time. Pure rules for LawnService, CafeService's tier gifts and the save (version
-- 28); the rows are Catalog.lawn and Catalog.lawnStyles, the world side server/World/LawnBuilder.

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

type Profile = Types.PlayerProfile

local Lawn = {}

-- Section 1b with Model-Agent's numbers (#673, style guide section 13), plot space: the base centre of the piece on
-- the grass top, front -Z to the street. Tier 1 opens the two small spots beside the path, Tier 2 the two big ones
-- under the windows, Tier 3 the two small ones by the front wall. Odd numbers are on the plot's -X side.
-- Moved 3 studs out with the bigger cafes' front wall (44 x 34, #917), the big ones 4 further to the sides.
Lawn.SPOTS = {
	{ id = "small1", size = "small", tier = 1, x = -5, y = -0.05, z = -21.3, rotY = 0 },
	{ id = "small2", size = "small", tier = 1, x = 5, y = -0.05, z = -21.3, rotY = 0 },
	{ id = "big1", size = "big", tier = 2, x = -18, y = -0.05, z = -20.8, rotY = 0 },
	{ id = "big2", size = "big", tier = 2, x = 18, y = -0.05, z = -20.8, rotY = 0 },
	{ id = "small3", size = "small", tier = 3, x = -10.5, y = -0.05, z = -20.3, rotY = 0 },
	{ id = "small4", size = "small", tier = 3, x = 10.5, y = -0.05, z = -20.3, rotY = 0 },
} :: { Types.LawnSpot }

Lawn.spotsById = {} :: { [string]: Types.LawnSpot }
for _, spot in Lawn.SPOTS do
	Lawn.spotsById[spot.id] = spot
end

Lawn.DEFAULT_PATH = "grey_slabs" -- every cafe's path until another is laid (section 1)

-- Section 1b: ranking up to Tier 2 gives a Garden Bench and Tier 3 an Umbrella Table, owned and placed in an empty
-- big spot if there is one; a cafe already past the tier gets it on its next load.
Lawn.TIER_GIFTS = { [2] = "garden_bench", [3] = "umbrella_table" } :: { [number]: string }

-- The plot attributes every client reads (display only): the piece on each spot, the path and the fence.
Lawn.PATH_ATTRIBUTE = "LawnPath"
Lawn.FENCE_ATTRIBUTE = "LawnFence"

function Lawn.spotAttribute(spotId: string): string
	return "Lawn_" .. spotId
end

function Lawn.getSpot(id: string): Types.LawnSpot?
	return Lawn.spotsById[id]
end

local function tierOf(profile: Profile): number
	local tier = (profile :: any).tier
	if type(tier) ~= "number" or tier ~= tier then
		return 1
	end
	return math.clamp(math.floor(tier), 1, Catalog.maxTier)
end

local function sizeWord(size: Types.LawnSize): string
	return if size == "big" then "a big" else "a small"
end

function Lawn.freshStyles(): Types.LawnStyles
	return { path = Lawn.DEFAULT_PATH, fence = nil }
end

-- True when the cafe has the piece or style: bought, given, or free (Grey Slabs).
function Lawn.owns(profile: Profile, id: string): boolean
	if profile.lawnOwned[id] == true then
		return true
	end
	local style = Catalog.getLawnStyle(id)
	return style ~= nil and style.price == 0
end

-- The spot a piece stands in, or nil.
function Lawn.spotOf(profile: Profile, pieceId: string): string?
	for _, spot in Lawn.SPOTS do
		if profile.lawn[spot.id] == pieceId then
			return spot.id
		end
	end
	return nil
end

-- Why `id` (a lawn piece or style) cannot be bought now, or nil. Coins are checked when they are spent.
function Lawn.buyBlocker(profile: Profile, id: string): string?
	local piece, style = Catalog.getLawn(id), Catalog.getLawnStyle(id)
	local name, tier
	if piece ~= nil then
		name, tier = piece.name, piece.tier
	elseif style ~= nil then
		name, tier = style.name, style.tier
	else
		return "That is not in the lawn shop."
	end
	if Lawn.owns(profile, id) then
		return string.format("You already have the %s.", name)
	end
	if tierOf(profile) < tier then
		return string.format("The %s opens at Tier %d.", name, tier)
	end
	return nil
end

-- Why `pieceId` cannot go on `spotId` (nil `pieceId` clears the spot), or nil. The spot must be open at the cafe's
-- tier and the piece owned and of the spot's size. A spot with a piece on it can take another: the old one goes back
-- to the player's pieces.
function Lawn.placeBlocker(profile: Profile, spotId: string, pieceId: string?): string?
	local spot = Lawn.getSpot(spotId)
	if spot == nil then
		return "That is not a lawn spot."
	end
	if tierOf(profile) < spot.tier then
		return string.format("That spot opens at Tier %d.", spot.tier)
	end
	if pieceId == nil then
		return nil
	end
	local piece = Catalog.getLawn(pieceId)
	if piece == nil then
		return "That is not a lawn piece."
	end
	if not Lawn.owns(profile, pieceId) then
		return string.format("Buy the %s first.", piece.name)
	end
	if piece.spot ~= spot.size then
		return string.format("The %s needs %s spot.", piece.name, sizeWord(piece.spot))
	end
	return nil
end

-- Puts `pieceId` on `spotId`, taking it off any other spot first, or clears the spot when `pieceId` is nil. Check
-- placeBlocker first.
function Lawn.place(profile: Profile, spotId: string, pieceId: string?)
	if pieceId ~= nil then
		local from = Lawn.spotOf(profile, pieceId)
		if from ~= nil then
			profile.lawn[from] = nil
		end
	end
	if pieceId == nil then
		profile.lawn[spotId] = nil
	else
		profile.lawn[spotId] = pieceId
	end
end

-- The first empty spot of `size` open at the cafe's tier, in Lawn.SPOTS order, or nil.
function Lawn.firstFreeSpot(profile: Profile, size: Types.LawnSize): string?
	local tier = tierOf(profile)
	for _, spot in Lawn.SPOTS do
		if spot.size == size and tier >= spot.tier and profile.lawn[spot.id] == nil then
			return spot.id
		end
	end
	return nil
end

-- Why the style `id` of `kind` cannot go in use (nil: Grey Slabs for a path, no fence for a fence), or nil.
function Lawn.styleBlocker(profile: Profile, kind: Types.LawnStyleKind, id: string?): string?
	if id == nil then
		return nil
	end
	local style = Catalog.getLawnStyle(id)
	if style == nil or style.kind ~= kind then
		return if kind == "path" then "That is not a path." else "That is not a fence."
	end
	if not Lawn.owns(profile, id) then
		return string.format("Buy the %s first.", style.name)
	end
	return nil
end

-- Lays the path or puts up the fence `id` (nil: Grey Slabs, or no fence). Check styleBlocker first.
function Lawn.setStyle(profile: Profile, kind: Types.LawnStyleKind, id: string?)
	if kind == "path" then
		profile.lawnStyles.path = id or Lawn.DEFAULT_PATH
	else
		profile.lawnStyles.fence = id
	end
end

-- Section 1b: gives each tier gift the cafe's tier has reached and it does not own yet, placed in the first empty
-- open big spot when there is one. Returns the piece ids given, in tier order.
function Lawn.grantTierGifts(profile: Profile): { string }
	local given: { string } = {}
	local tier = tierOf(profile)
	for giftTier = 1, Catalog.maxTier do
		local id = Lawn.TIER_GIFTS[giftTier]
		local piece = if id ~= nil then Catalog.getLawn(id) else nil
		if piece ~= nil and tier >= giftTier and profile.lawnOwned[piece.id] ~= true then
			profile.lawnOwned[piece.id] = true
			local spotId = Lawn.firstFreeSpot(profile, piece.spot)
			if spotId ~= nil then
				Lawn.place(profile, spotId, piece.id)
			end
			table.insert(given, piece.id)
		end
	end
	return given
end

-- The lawn of a loaded save (version 28; older saves have none), made valid for `tier`: only known pieces and styles
-- owned; on each spot open at `tier` only an owned piece of its size, each piece on one spot at most (the first in
-- Lawn.SPOTS order keeps it); an owned path, else Grey Slabs, and an owned fence, else none.
function Lawn.sanitize(
	rawOwned: any,
	rawLawn: any,
	rawStyles: any,
	tier: number
): ({ [string]: boolean }, { [string]: string }, Types.LawnStyles)
	local owned: { [string]: boolean } = {}
	if type(rawOwned) == "table" then
		for id, value in rawOwned do
			if
				type(id) == "string"
				and value == true
				and (Catalog.getLawn(id) ~= nil or Catalog.getLawnStyle(id) ~= nil)
			then
				owned[id] = true
			end
		end
	end
	local placed: { [string]: string } = {}
	if type(rawLawn) == "table" then
		local used: { [string]: boolean } = {}
		for _, spot in Lawn.SPOTS do
			local pieceId = rawLawn[spot.id]
			local piece = if type(pieceId) == "string" then Catalog.getLawn(pieceId) else nil
			if
				piece ~= nil
				and owned[piece.id]
				and piece.spot == spot.size
				and tier >= spot.tier
				and not used[piece.id]
			then
				placed[spot.id] = piece.id
				used[piece.id] = true
			end
		end
	end
	local styles = Lawn.freshStyles()
	if type(rawStyles) == "table" then
		for _, kind in { "path", "fence" } :: { Types.LawnStyleKind } do
			local id = rawStyles[kind]
			local style = if type(id) == "string" then Catalog.getLawnStyle(id) else nil
			if style ~= nil and style.kind == kind and (owned[style.id] or style.price == 0) then
				if kind == "path" then
					styles.path = style.id
				else
					styles.fence = style.id
				end
			end
		end
	end
	return owned, placed, styles
end

return Lawn
