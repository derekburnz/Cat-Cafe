--!strict
-- The crate reel's numbers (F103, crate-reel.md), pure so the cloud spec runner checks them:
--   timing(config)                the reel's shape from shared Config's CrateReel* numbers, or nil while Config has
--                                 none (the Market keeps the old reveal until then). The stop time is the same every
--                                 time and matches Effects/Logic.crateReelStop, which the counter crate's lid uses.
--   position(t, timing)           which tile sits under the marker `t` seconds in, as a number: 1 at the start, the
--                                 landing tile's centre (34) at the stop and after. It speeds up evenly to the top
--                                 speed, runs flat out, then an ease-out cubic slows it to a dead stop.
--   strip(pieces, won, rng, timing)  the tiles, display only: the won piece on the landing tile, the rest drawn from
--                                 the crate's real chances, and on the protected tiles (26 to 37: the last second and
--                                 everything in view at the stop) nothing rarer than the prize.
--   crossed(from, to)             how many tile lines passed the marker between two positions (the ticks)
-- The server has already rolled and paid before the reel starts; nothing here changes what was won.

local CrateReelLogic = {}

export type Timing = {
	tiles: number,
	landing: number,
	protectFrom: number,
	protectTo: number,
	topSpeed: number, -- tiles a second
	ramp: number, -- seconds to reach the top speed
	slowFrom: number, -- seconds in when the slow down starts
	slowSeconds: number,
	slowTiles: number, -- tiles covered while slowing
	stop: number, -- seconds in when it stops dead on the landing tile
	hold: number, -- seconds the marker pulses before the prize card
}

export type Piece = { id: string, rarity: string, percent: number }
export type Tile = { id: string, rarity: string }

local RANK: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }

local function number(value: unknown): number?
	return if type(value) == "number" then value else nil
end

function CrateReelLogic.timing(config: { [string]: any }): Timing?
	local tiles = number(config.CrateReelTiles)
	local landing = number(config.CrateReelLandingTile)
	local top = number(config.CrateReelTopSpeed)
	local ramp = number(config.CrateReelRampSeconds)
	local slow = number(config.CrateReelStopSeconds)
	if tiles == nil or landing == nil or top == nil or ramp == nil or slow == nil or top <= 0 then
		return nil
	end
	ramp = math.max(ramp, 0)
	slow = math.max(slow, 0)
	-- the cubic sets off at three times its average pace, so meeting the top speed it covers top * slow / 3 tiles
	local slowTiles = top * slow / 3
	local cruise = math.max(landing - 1 - top * ramp / 2 - slowTiles, 0) / top
	local slowFrom = ramp + cruise
	return {
		tiles = math.max(tiles, landing),
		landing = landing,
		protectFrom = number(config.CrateReelProtectFrom) or landing - 8,
		protectTo = number(config.CrateReelProtectTo) or landing + 3,
		topSpeed = top,
		ramp = ramp,
		slowFrom = slowFrom,
		slowSeconds = slow,
		slowTiles = slowTiles,
		stop = slowFrom + slow,
		hold = number(config.CrateReelHoldSeconds) or 0.25,
	}
end

function CrateReelLogic.position(t: number, timing: Timing): number
	if t <= 0 then
		return 1
	end
	if t >= timing.stop then
		return timing.landing
	end
	local top = timing.topSpeed
	local ramp = timing.ramp
	local travelled: number
	if t < ramp then
		travelled = 0.5 * (top / ramp) * t * t
	elseif t < timing.slowFrom then
		travelled = top * ramp / 2 + top * (t - ramp)
	else
		local before = timing.landing - 1 - timing.slowTiles
		local u = math.clamp((t - timing.slowFrom) / math.max(timing.slowSeconds, 1e-6), 0, 1)
		local left = 1 - u
		travelled = before + timing.slowTiles * (1 - left * left * left)
	end
	return math.min(1 + travelled, timing.landing)
end

-- How many tile lines (the halfway points between tile centres) passed the marker going from `from` to `to`.
function CrateReelLogic.crossed(from: number, to: number): number
	if to <= from then
		return 0
	end
	return math.floor(to - 0.5) - math.floor(from - 0.5)
end

local function draw(pool: { Piece }, rng: Random): Piece?
	local total = 0
	for _, piece in pool do
		total += math.max(piece.percent, 0)
	end
	if total <= 0 then
		return pool[1]
	end
	local roll = rng:NextNumber() * total
	for _, piece in pool do
		roll -= math.max(piece.percent, 0)
		if roll < 0 then
			return piece
		end
	end
	return pool[#pool]
end

function CrateReelLogic.strip(pieces: { Piece }, won: Tile, rng: Random, timing: Timing): { Tile }
	local wonRank = RANK[won.rarity] or 1
	local safe: { Piece } = {}
	for _, piece in pieces do
		if (RANK[piece.rarity] or 1) <= wonRank then
			table.insert(safe, piece)
		end
	end
	local tiles: { Tile } = {}
	for index = 1, timing.tiles do
		if index == timing.landing then
			table.insert(tiles, { id = won.id, rarity = won.rarity })
		else
			local protected = index >= timing.protectFrom and index <= timing.protectTo
			local piece = draw(if protected then safe else pieces, rng)
			if piece == nil then
				table.insert(tiles, { id = won.id, rarity = won.rarity })
			else
				table.insert(tiles, { id = piece.id, rarity = piece.rarity })
			end
		end
	end
	return tiles
end

return CrateReelLogic
