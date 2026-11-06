--!strict
-- #1884 (catch-rework.md 7a): a stray's mood on the approach. Pure: positions are Vector3s and rolls are numbers in
-- [0, 1), so the specs can check every rule without a world.
--   Sleepy: curled up, never wanders, wakes only when a swing lands on it.
--   Curious: walks CuriousWalkStuds toward the first player within CuriousRangeStuds; a swing landing within
--     CuriousBonusSeconds of that walk starting begins with CuriousTrustBonus more trust.
--   Skittish: hops SkittishHopStuds away from a player within SkittishRangeStuds inside its SkittishArcDegrees front
--     arc, at most once every SkittishCooldown seconds. From behind or the side is fine.
-- The tutorial stray is always Sleepy, and a player before tutorialStep 2 never meets a Skittish cat.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Moods = {}

Moods.ORDER = { "Sleepy", "Curious", "Skittish" } :: { Types.CatMood }

-- The tutorialStep from which a player can meet a Skittish cat (7a).
Moods.SKITTISH_FROM_STEP = 2

-- The mood a stray of `rarity` rolls with `u` in [0, 1), by its rarity's weights. `gentle` (a tutorial stray)
-- makes it Sleepy.
function Moods.roll(rarity: Types.Rarity, u: number, gentle: boolean?): Types.CatMood
	if gentle then
		return "Sleepy"
	end
	local weights = Catalog.rarities[rarity].moods
	local list: { { mood: Types.CatMood, weight: number } } = {
		{ mood = "Sleepy", weight = weights.Sleepy },
		{ mood = "Curious", weight = weights.Curious },
		{ mood = "Skittish", weight = weights.Skittish },
	}
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local pick = u * total
	for _, entry in list do
		if entry.weight > 0 and pick < entry.weight then
			return entry.mood
		end
		pick -= entry.weight
	end
	return "Sleepy"
end

-- Whether a Skittish cat startles at a player of `tutorialStep` (7a: never before step 2).
function Moods.canStartle(tutorialStep: number): boolean
	return tutorialStep >= Moods.SKITTISH_FROM_STEP
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Whether `player` is within SkittishRangeStuds of a cat at `at` facing `look`, inside its front arc.
function Moods.inFrontArc(at: Vector3, look: Vector3, player: Vector3): boolean
	local offset = flat(player - at)
	local distance = offset.Magnitude
	if distance > Config.SkittishRangeStuds then
		return false
	end
	if distance < 1e-3 then
		return true
	end
	local facing = flat(look)
	if facing.Magnitude < 1e-3 then
		return false
	end
	local cos = facing.Unit:Dot(offset.Unit)
	return cos >= math.cos(math.rad(Config.SkittishArcDegrees / 2))
end

-- Whether a Skittish cat that last hopped at `lastHop` (nil for never) may hop again at `now`.
function Moods.hopReady(lastHop: number?, now: number): boolean
	return lastHop == nil or now - lastHop >= Config.SkittishCooldown
end

-- Where a Skittish cat at `at` hops to, SkittishHopStuds straight away from `player` (same height).
function Moods.hopTarget(at: Vector3, player: Vector3): Vector3
	local away = flat(at - player)
	if away.Magnitude < 1e-3 then
		away = Vector3.new(1, 0, 0)
	end
	return at + away.Unit * Config.SkittishHopStuds
end

-- Whether a Curious cat at `at` notices a player at `player` (within CuriousRangeStuds).
function Moods.noticed(at: Vector3, player: Vector3): boolean
	return flat(player - at).Magnitude <= Config.CuriousRangeStuds
end

-- Where a Curious cat at `at` walks toward a player at `player`: CuriousWalkStuds closer, stopping 2 studs short.
function Moods.curiousTarget(at: Vector3, player: Vector3): Vector3
	local toward = flat(player - at)
	local step = math.min(Config.CuriousWalkStuds, math.max(0, toward.Magnitude - 2))
	if step <= 0 then
		return at
	end
	return at + toward.Unit * step
end

-- The trust a catch starts with on top of TrustStart: CuriousTrustBonus when the swing lands within
-- CuriousBonusSeconds of a Curious cat's walk starting at `walkAt` (nil when it never walked).
function Moods.trustBonus(walkAt: number?, now: number): number
	if walkAt == nil or now < walkAt or now - walkAt > Config.CuriousBonusSeconds then
		return 0
	end
	return Config.CuriousTrustBonus
end

return Moods
