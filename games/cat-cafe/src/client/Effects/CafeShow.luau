--!strict
-- The Corner Shop's shows (corner-shop.md sections 2 and 5, #1052), bought for coins and seen by everyone nearby:
-- the Bubble Machine blows soft pastel bubbles from the cafe's door for 10 minutes, and Cafe Fireworks fire a 20 s
-- show of shells over the cafe. Each cafe runs one show at a time; the server queues the next, so a queued show
-- waits here until its own start. A client that joins during a show starts partway. Bubbles are one steady emitter
-- per cafe on the nearest budget.cafeBubbles cafes; fireworks are one burst a shell on the nearest
-- budget.cafeFireworks cafes, fewer shells on the low budget (a phone or Low performance). With Reduce Motion
-- neither moves: the door, or the sky over the cafe, glows once in the show's colour.
--
-- Source: the server's `CafeShow(userId, showId, endsAt)` (showId "bubbles" or "fireworks", endsAt in server time)
-- to every client, hooked when the remote appears; the Plot whose `OwnerUserId` is userId, its `Door` part and its
-- bounding box. Listening only. Numbers in Presets.cafeShow.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local CafeShow = {}

type Show = {
	owner: number,
	kind: "bubbles" | "fireworks",
	startsAt: number,
	endsAt: number,
	at: Vector3?, -- the door (bubbles) or the sky over the cafe (fireworks), found each step
	emitter: ParticleEmitter?,
	nextShell: number,
	glowed: boolean,
}

local shows: { Show } = {}
local rng = Random.new()
local started = false

local function plotOf(owner: number): Model?
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == owner then
			return plot :: Model
		end
	end
	return nil
end

local function doorAt(plot: Model): Vector3
	local door = plot:FindFirstChild("Door")
	local base = if door ~= nil and door:IsA("BasePart")
		then (door :: BasePart).Position
		else plot:GetPivot().Position
	return base + Vector3.new(0, Presets.cafeShow.bubbles.lift, 0)
end

local function skyAt(plot: Model): Vector3
	local frame, size = plot:GetBoundingBox()
	return frame.Position + Vector3.new(0, size.Y / 2 + Presets.cafeShow.fireworks.lift, 0)
end

local function stopBubbles(show: Show)
	local emitter = show.emitter
	if emitter ~= nil then
		show.emitter = nil
		local holder = emitter.Parent
		emitter.Enabled = false
		-- the bubbles already in the air drift on and fade
		local fade = Presets.emitters.cafeBubble.lifetime[2] + 0.5
		Debris:AddItem(if holder ~= nil then holder else emitter, fade)
	end
end

-- Reduce Motion's stand-in: a light that fades in and out once, no particles and nothing moving.
type Glow = { seconds: number, range: number, brightness: number, colour: Color3 }

local function glow(at: Vector3, g: Glow)
	local part = Context.effectPart("CafeShowGlow", Vector3.new(0.2, 0.2, 0.2), g.colour)
	part.Transparency = 1
	part.Position = at
	local light = Instance.new("PointLight")
	light.Color = g.colour
	light.Range = g.range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = part
	part.Parent = Context.folder()
	local half = g.seconds / 2
	local info = TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true)
	TweenService:Create(light, info, { Brightness = g.brightness }):Play()
	Debris:AddItem(part, g.seconds + 0.2)
end

local function shell(sky: Vector3)
	local f = Presets.cafeShow.fireworks
	local x, z = rng:NextNumber(-f.spread, f.spread), rng:NextNumber(-f.spread, f.spread)
	local offset = Vector3.new(x, 0, z)
	local from = sky + offset
	local burstAt = from + Vector3.new(0, rng:NextNumber(f.height[1], f.height[2]), 0)
	local colour = f.colours[rng:NextInteger(1, #f.colours)]
	local rocket = Context.effectPart("FireworkShell", Vector3.new(0.35, 0.35, 0.35), colour)
	rocket.Shape = Enum.PartType.Ball
	rocket.Material = Enum.Material.Neon
	rocket.Position = from
	rocket.Parent = Context.folder()
	local info = TweenInfo.new(f.rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(rocket, info, { Position = burstAt }):Play()
	Debris:AddItem(rocket, f.rise + 0.05)
	task.delay(f.rise, function()
		Particles.burst("fireworkStar", burstAt, f.stars, colour)
		Particles.burst("dingSparkle", burstAt, f.glitter, Presets.palette.golden)
	end)
end

local function playBubbles(show: Show, at: Vector3)
	if Context.reducedMotion() then
		stopBubbles(show)
		if not show.glowed then
			show.glowed = true
			glow(at, Presets.cafeShow.bubbles.glow)
		end
		return
	end
	local emitter = show.emitter
	if emitter == nil or emitter.Parent == nil then
		local holder = Particles.anchor("CafeBubbles", at)
		emitter = Particles.make(Presets.emitters.cafeBubble)
		local made = emitter :: ParticleEmitter
		made.Name = "cafeBubble"
		made.Parent = holder
		show.emitter = made
	end
	local holder = (emitter :: ParticleEmitter).Parent
	if holder ~= nil and holder:IsA("Attachment") then
		(holder :: Attachment).Position = at
	end
	-- at the budget's rateScale, every step, so the Low performance setting reaches it
	Particles.switchOn(emitter :: ParticleEmitter, "cafeBubble")
end

local function playFireworks(show: Show, at: Vector3, now: number)
	local f = Presets.cafeShow.fireworks
	if Context.reducedMotion() then
		if not show.glowed then
			show.glowed = true
			glow(at, f.glow)
		end
		return
	end
	if now >= show.nextShell then
		local every = f.every[Context.tier] or f.every.low
		show.nextShell = Logic.nextShell(show.startsAt, now, every)
		if now < show.endsAt - f.rise then
			shell(at)
		end
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local bubbles: { Logic.Candidate<Show> } = {}
	local fireworks: { Logic.Candidate<Show> } = {}
	for i = #shows, 1, -1 do
		local show = shows[i]
		local phase = Logic.showPhase(now, show.startsAt, show.endsAt)
		local plot = if phase == "on" then plotOf(show.owner) else nil
		if phase == "over" then
			stopBubbles(show)
			table.remove(shows, i)
		elseif plot ~= nil then
			local at = if show.kind == "bubbles" then doorAt(plot) else skyAt(plot)
			show.at = at
			local candidate = { key = show, distance = Context.distance(at) }
			table.insert(if show.kind == "bubbles" then bubbles else fireworks, candidate)
		else
			show.at = nil
		end
	end
	local chosen: { [Show]: boolean } = {}
	local budget, c = Context.budget, Presets.cafeShow
	for _, show in Logic.nearest(bubbles, c.bubbles.within, budget.cafeBubbles) do
		chosen[show] = true
		playBubbles(show, show.at :: Vector3)
	end
	for _, show in Logic.nearest(fireworks, c.fireworks.within, budget.cafeFireworks) do
		chosen[show] = true
		playFireworks(show, show.at :: Vector3, now)
	end
	for _, show in shows do
		if not chosen[show] then
			stopBubbles(show)
		end
	end
end

local function add(userId: unknown, showId: unknown, endsAt: unknown)
	if type(userId) ~= "number" or type(endsAt) ~= "number" or endsAt ~= endsAt then
		return
	end
	if showId ~= "bubbles" and showId ~= "fireworks" then
		return
	end
	local kind: "bubbles" | "fireworks" = if showId == "bubbles" then "bubbles" else "fireworks"
	for _, show in shows do
		if show.owner == userId and show.kind == kind and show.endsAt == endsAt then
			return -- the same show sent again
		end
	end
	if #shows >= Presets.cafeShow.most then
		return
	end
	local seconds = if kind == "bubbles"
		then Presets.cafeShow.bubbles.seconds
		else Presets.cafeShow.fireworks.seconds
	local startsAt = endsAt - seconds
	table.insert(shows, {
		owner = userId,
		kind = kind,
		startsAt = startsAt,
		endsAt = endsAt,
		at = nil,
		emitter = nil,
		nextShell = startsAt,
		glowed = false,
	})
end

function CafeShow.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("CafeShow", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(add)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for i = #shows, 1, -1 do
			if shows[i].owner == player.UserId then
				stopBubbles(shows[i])
				table.remove(shows, i)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Presets.cafeShow.pick)
			step()
		end
	end)
end

return CafeShow
