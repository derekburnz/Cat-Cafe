--!strict
-- Snowglobe Village's Gift Stall buy sparkle (the Christmas Event; Design's snowglobe-village-spec section 5, issue
-- #5641). All on this client, listening only; the server decides every buy:
--   the sparkle when your Snowflake count (PlayerState.snowflakes from ProfileSync) goes down while you stand within
--               `within` studs of the stall (tag SnowglobeStall), the stall bursts with gold and icy sparkles, a ring
--               opens on the ground and "Gift wrapped!" rises over your head. Spending Snowflakes is what a buy
--               does, so it plays for whatever buy remote the event row wires, with no hook of its own. A drop
--               away from the stall (nothing else spends them today) plays nothing. The first value seen only sets
--               the mark. Reduce Motion halves the sparkles and skips the ring (Particles.ring does that itself).
-- Everything waits on the christmasEvent switch (read straight, `== true`). Numbers in Presets.giftStallFx.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)

local Context = require(script.Parent.Context)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local GiftStallFx = {}

local started = false
local count: number? = nil -- the Snowflake count as last seen

-- How many Snowflakes were spent: the fall from `was` to `now`, or nil for the first value seen, for no fall and
-- for anything that is not a number. Pure.
function GiftStallFx.spent(was: number?, now: unknown): number?
	if type(now) ~= "number" or was == nil or now >= was then
		return nil
	end
	return math.floor(was - now + 0.5)
end

-- Whether a spend plays the sparkle: the switch is on, something was spent and the nearest stall is within reach
-- (`nearest` is nil when no stall is in the world). Pure.
function GiftStallFx.plays(on: boolean, spentBy: number?, nearest: number?, within: number): boolean
	return on and spentBy ~= nil and spentBy > 0 and nearest ~= nil and nearest <= within
end

-- How many sparkles a buy gets: `count`, halved (rounded up) with Reduce Motion. Pure.
function GiftStallFx.sparkles(base: number, still: boolean): number
	return if still then math.ceil(base / 2) else base
end

local function eventOn(): boolean
	return ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. Presets.giftStallFx.flag)
		== true
end

-- The nearest tagged stall's position and distance, or nil when none is streamed in.
local function nearestStall(): (Vector3?, number?)
	local best: Vector3? = nil
	local bestDistance: number? = nil
	for _, stall in CollectionService:GetTagged(Presets.giftStallFx.tag) do
		local at = Context.positionOf(stall)
		if at ~= nil then
			local d = Context.distance(at)
			if bestDistance == nil or d < bestDistance then
				best, bestDistance = at, d
			end
		end
	end
	return best, bestDistance
end

local function play(at: Vector3)
	local p = Presets.giftStallFx
	local still = Context.reducedMotion()
	local lifted = at + Vector3.new(0, p.lift, 0)
	local n = GiftStallFx.sparkles(p.count, still)
	Particles.burst(p.sparkle, lifted, n, p.gold)
	Particles.burst(p.sparkle, lifted, n, p.icy)
	Particles.ring(at, p.icy, p.ring)
	local character = Players.LocalPlayer.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head ~= nil and head:IsA("BasePart") then
		Particles.mark(head :: BasePart, p.text, p.gold, p.popSeconds)
	end
end

function GiftStallFx.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local now = (state :: { [string]: unknown }).snowflakes
		local spentBy = GiftStallFx.spent(count, now)
		if type(now) == "number" then
			count = now
		end
		if spentBy == nil then
			return
		end
		local at, distance = nearestStall()
		if
			at ~= nil
			and GiftStallFx.plays(eventOn(), spentBy, distance, Presets.giftStallFx.within)
		then
			play(at)
		end
	end)
end

return GiftStallFx
