--!strict
-- Snowglobe Village's Snowflake patch (the Christmas Event; Design's snowglobe-village-spec section 2, GE's client
-- half of the event). All on this client, listening only; the server decides every pickup:
--   the bob     each ready patch snowflake (tag SnowglobeFlake, a Model with an invisible `Touch` box) bobs and turns
--               slowly while you are within `bobWithin` studs. Only the flake's own parts move, never its Touch box,
--               so the spot you walk over stays where the server put it. Still with Reduce Motion, none in Low
--               performance.
--   the sparkle a flake whose `Ready` attribute goes false was picked by someone: an icy burst and a ring where it
--               stood. Its regrow (`Ready` back to true) gives a small sprinkle so you see it is back.
--   the pop     "+N Snowflakes" rises over your head when your Snowflake count goes up (PlayerState.snowflakes, a
--               number or nil, from ProfileSync), so a pickup, a catch or the day's first visit all read. The first
--               value seen only sets the mark.
-- Everything waits on the christmasEvent switch (read straight, `== true`). Until the tag is in the world nothing
-- moves, so the module is idle outside the event. Numbers in Presets.snowglobeFlakes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)

local Context = require(script.Parent.Context)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SnowglobeFlakes = {}

type Piece = { part: BasePart, base: CFrame, offset: CFrame }
type Flake = {
	model: Instance,
	pieces: { Piece },
	pivot: CFrame,
	phase: number,
	link: RBXScriptConnection,
	moving: boolean,
}

local started = false
local flakes: { [Instance]: Flake } = {}
local ready: { [Instance]: boolean } = {} -- each flake's Ready as last seen
local count: number? = nil -- the Snowflake count as last seen
local clock = 0

-- What a flake's `Ready` change means: "pick" when it was ready and is not now, "regrow" the other way, nil for the
-- first sight of it (a flake streaming in is not news) and for no change. Pure.
function SnowglobeFlakes.change(was: boolean?, now: boolean): string?
	if was == nil or was == now then
		return nil
	end
	return if now then "regrow" else "pick"
end

-- How many Snowflakes the pop shows: the rise from `was` to `now`, or nil for the first value seen, for no rise and
-- for anything that is not a number (nil while GE's sync is not in yet). Pure.
function SnowglobeFlakes.rise(was: number?, now: unknown): number?
	if type(now) ~= "number" or was == nil or now <= was then
		return nil
	end
	return math.floor(now - was + 0.5)
end

-- The pop's words: "+1 Snowflake", "+N Snowflakes". Pure.
function SnowglobeFlakes.popText(gain: number): string
	return string.format("+%d %s", gain, if gain == 1 then "Snowflake" else "Snowflakes")
end

-- Where a bobbing flake sits at `t` seconds: `lift` studs up (a sine of `height` over `period` seconds, shifted by
-- `phase` so the twelve do not move as one) and turned `turn` radians (one turn every `spin` seconds). Pure.
function SnowglobeFlakes.bob(
	t: number,
	phase: number,
	height: number,
	period: number,
	spin: number
): (number, number)
	local lift = height * math.sin((t + phase) * 2 * math.pi / period)
	local turn = ((t + phase) / spin % 1) * 2 * math.pi
	return lift, turn
end

-- Whether the bob runs: the flake is ready and near, and neither Reduce Motion nor Low performance is on. Pure.
function SnowglobeFlakes.bobs(
	isReady: boolean,
	distance: number,
	within: number,
	still: boolean,
	low: boolean
): boolean
	return isReady and distance <= within and not still and not low
end

local function eventOn(): boolean
	return ReplicatedStorage:GetAttribute(
		LiveFlags.ATTRIBUTE_PREFIX .. Presets.snowglobeFlakes.flag
	) == true
end

local function isReady(model: Instance): boolean
	return model:GetAttribute(Presets.snowglobeFlakes.readyAttribute) ~= false
end

-- Puts a flake's parts back where the server left them.
local function settle(flake: Flake)
	flake.moving = false
	for _, piece in flake.pieces do
		if piece.part.Parent ~= nil then
			piece.part.CFrame = piece.base
		end
	end
end

local function changed(model: Instance)
	local now = isReady(model)
	local what = SnowglobeFlakes.change(ready[model], now)
	ready[model] = now
	local flake = flakes[model]
	if flake ~= nil and not now then
		settle(flake)
	end
	local p = Presets.snowglobeFlakes
	local at = Context.positionOf(model)
	if what == nil or at == nil or not eventOn() or Context.distance(at) > p.within then
		return
	end
	local lifted = at + Vector3.new(0, p.lift, 0)
	if what == "pick" then
		local sparkles = if Context.reducedMotion() then math.ceil(p.pickCount / 2) else p.pickCount
		Particles.burst(p.sparkle, lifted, sparkles, p.colour)
		Particles.ring(at, p.colour, p.pickRing)
	else
		Particles.burst(p.sparkle, lifted, p.regrowCount, p.regrowColour)
	end
end

local function forget(model: Instance)
	local flake = flakes[model]
	if flake ~= nil then
		flake.link:Disconnect()
		settle(flake)
		flakes[model] = nil
	end
	ready[model] = nil
end

local function watch(model: Instance)
	if flakes[model] ~= nil or not model:IsA("Model") then
		return
	end
	local pivot = model:GetPivot()
	local pieces: { Piece } = {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= Presets.snowglobeFlakes.touchName then
			local part = child :: BasePart
			table.insert(
				pieces,
				{ part = part, base = part.CFrame, offset = pivot:ToObjectSpace(part.CFrame) }
			)
		end
	end
	local p = Presets.snowglobeFlakes
	local link = model:GetAttributeChangedSignal(p.readyAttribute):Connect(function()
		if model.Parent ~= nil then
			changed(model)
		end
	end)
	-- spread the twelve over the bob's period by name (SnowglobeFlake01..12) so each client sees the same wave
	local index = tonumber(string.match(model.Name, "(%d+)$")) or 0
	flakes[model] = {
		model = model,
		pieces = pieces,
		pivot = pivot,
		phase = (index * p.phaseStep) % p.period,
		link = link,
		moving = false,
	}
	ready[model] = isReady(model)
end

local function step(dt: number)
	clock += dt
	local p = Presets.snowglobeFlakes
	local on = eventOn()
	local still = Context.reducedMotion()
	for model, flake in flakes do
		local near = Context.distance(flake.pivot.Position)
		if
			on
			and SnowglobeFlakes.bobs(
				ready[model] == true,
				near,
				p.bobWithin,
				still,
				Context.lowPerformance
			)
		then
			local lift, turn = SnowglobeFlakes.bob(clock, flake.phase, p.height, p.period, p.spin)
			local moved = flake.pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, turn, 0)
			for _, piece in flake.pieces do
				if piece.part.Parent ~= nil then
					piece.part.CFrame = moved * piece.offset
				end
			end
			flake.moving = true
		elseif flake.moving then
			settle(flake)
			flake.moving = false
		end
	end
end

local function pop(gain: number)
	local character = Players.LocalPlayer.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local p = Presets.snowglobeFlakes
	Particles.mark(head :: BasePart, SnowglobeFlakes.popText(gain), p.popColour, p.popSeconds)
end

function SnowglobeFlakes.start()
	if started then
		return
	end
	started = true
	local p = Presets.snowglobeFlakes
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local now = (state :: { [string]: unknown }).snowflakes
		local gain = SnowglobeFlakes.rise(count, now)
		if type(now) == "number" then
			count = now
		end
		if gain ~= nil and gain > 0 and eventOn() then
			pop(gain)
		end
	end)
	CollectionService:GetInstanceAddedSignal(p.tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(p.tag):Connect(forget)
	for _, model in CollectionService:GetTagged(p.tag) do
		watch(model)
	end
	local wasStill = false
	RunService.Heartbeat:Connect(function(dt: number)
		if next(flakes) == nil then
			return
		end
		local still = Context.reducedMotion() or Context.lowPerformance or not eventOn()
		if still and not wasStill then
			for _, flake in flakes do
				settle(flake)
			end
		end
		wasStill = still
		if not still then
			step(dt)
		end
	end)
end

return SnowglobeFlakes
