--!strict
-- The Cat Whistle's look on the cat it points at (Corner Shop v2, corner-shop-v2.md section 4; #1250). While your
-- Cat Whistle runs, UI-Engineer's marker screen picks the nearest stray or trapped cat in your area every 0.5 s,
-- shows its WorldMarker paw over it and sets `WhistleTarget` = true on that cat's model, on this client only. Here
-- a soft teal ring pulses out at the cat's feet every `every` seconds with a few teal sparkles, one small burst
-- each time. With Reduce Motion a still, faint teal ring lies at its feet instead.
--
-- Source: the local `WhistleTarget` attribute on models tagged Stray or StuckCat (the same cats Cats.luau moves).
-- Listening only. Numbers in Presets.whistle.

local CollectionService = game:GetService("CollectionService")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Whistle = {}

local TAGS = { "Stray", "StuckCat" }

local nextPulse: { [Model]: number } = {}
local still: Part? = nil -- Reduce Motion's ring, on one cat at a time
local started = false

-- Just above the floor under the cat, from its bounding box.
local function feetOf(cat: Model): Vector3
	local frame, size = cat:GetBoundingBox()
	return frame.Position - Vector3.new(0, size.Y / 2 - 0.05, 0)
end

local function hideStill()
	local ring = still
	if ring ~= nil then
		still = nil
		ring:Destroy()
	end
end

local function showStill(at: Vector3)
	local w = Presets.whistle
	local ring = still
	if ring == nil or ring.Parent == nil then
		local made = Context.effectPart("WhistleRing", Vector3.new(0.05, w.ring, w.ring), w.colour)
		made.Shape = Enum.PartType.Cylinder
		made.Material = Enum.Material.Neon
		made.Transparency = w.stillTransparency
		made.Parent = Context.folder()
		ring = made
		still = made
	end
	(ring :: Part).CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
end

local function step()
	local w = Presets.whistle
	local now = os.clock()
	local target: Model? = nil
	for _, tag in TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("Model") and instance:GetAttribute("WhistleTarget") == true then
				target = instance :: Model
				break
			end
		end
		if target ~= nil then
			break
		end
	end
	for cat in nextPulse do
		if cat ~= target then
			nextPulse[cat] = nil
		end
	end
	if target == nil or target.Parent == nil then
		hideStill()
		return
	end
	local cat = target :: Model
	local at = feetOf(cat)
	if Context.distance(at) > w.within then
		hideStill()
		return
	end
	if Context.reducedMotion() then
		showStill(at)
		return
	end
	hideStill()
	local due = nextPulse[cat]
	if due == nil or now >= due then
		nextPulse[cat] = now + w.every
		Particles.ring(at, w.colour, w.ring, w.ringSeconds)
		Particles.burst("dingSparkle", at + Vector3.new(0, w.sparkleLift, 0), w.sparkles, w.colour)
	end
end

function Whistle.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(Presets.whistle.pick)
			step()
		end
	end)
end

return Whistle
