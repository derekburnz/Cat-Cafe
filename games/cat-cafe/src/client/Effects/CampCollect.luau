--!strict
-- The camp extras' collect bursts (F100, camp-extras.md section 2: "Collecting is one press. The prize flies to the
-- HUD with F94's prize toast"). When you collect a camp extra, a small burst in its own colours pops over it and a
-- ring opens on its ground: warm sparkles and gold coin glints over the Picnic Basket, drops off the water and gold
-- glints rising at the Fish Pond with a fish-blue ripple, a grey puff and bright sparkles out of the Lost and Found
-- as its lid lifts, and gold sparkles over the Yard Sale's boxes when you buy a crate. Each one waits for
-- Animation-Engineer's turn (the pond's rod tug, the lid lifting; CampExtras.luau) by its `delay`. The golden fish
-- landing in your wallet sparkle round you as ever (Fish.luau).
--
-- Source: Moments.CampExtraCollect(extraId, position) from Controllers/CampExtrasController on this player's own
-- collect or buy, `position` the extra's PromptAnchor; the `CampExtra`-tagged model in Workspace with that `ExtraId`
-- nearest it, its bounding box, its `FishJump` attachment (the pond's water) and its child Model ending `_Lid`.
-- Listening only. Numbers in Presets.campCollect.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local CampCollect = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG
local started = false

-- The placed model of `extraId` nearest `near`, within `reach` studs.
local function modelOf(extraId: string, near: Vector3, reach: number): Model?
	local best: Model? = nil
	local bestDistance = reach
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == extraId
			and instance:IsDescendantOf(Workspace)
		then
			local model = instance :: Model
			local distance = (model:GetPivot().Position - near).Magnitude
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

-- Where the bursts pop and where the ring opens: the pond's water for both; the lid's top (else the model's) over
-- the model's ground; the prompt itself when the model has not streamed in.
local function spots(model: Model?, fallback: Vector3): (Vector3, Vector3)
	if model == nil then
		return fallback, fallback
	end
	local water = model:FindFirstChild("FishJump", true)
	if water ~= nil and water:IsA("Attachment") then
		local at = (water :: Attachment).WorldPosition
		return at, at
	end
	local box, size = model:GetBoundingBox()
	local ground = (box * CFrame.new(0, -size.Y / 2, 0)).Position
	for _, child in model:GetDescendants() do
		if child:IsA("Model") and string.sub(child.Name, -4) == "_Lid" then
			local lidBox, lidSize = (child :: Model):GetBoundingBox()
			return (lidBox * CFrame.new(0, lidSize.Y / 2, 0)).Position, ground
		end
	end
	return (box * CFrame.new(0, size.Y / 2, 0)).Position, ground
end

local function collected(extraId: unknown, position: unknown)
	if type(extraId) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local c = Presets.campCollect
	local def = c.extras[extraId :: string]
	local near = position :: Vector3
	if def == nil or Context.distance(near) > c.within then
		return
	end
	local top, ground = spots(modelOf(extraId :: string, near, c.reach), near)
	task.delay(def.delay, function()
		local at = top + Vector3.new(0, def.above, 0)
		for _, burst in def.bursts do
			Particles.burst(burst.emitter, at, burst.count, burst.tint)
		end
		Particles.ring(ground + Vector3.new(0, 0.05, 0), def.colour, def.ring, c.ringSeconds)
	end)
end

function CampCollect.start()
	if started then
		return
	end
	started = true
	local onCollect = (Moments :: any).CampExtraCollect -- F100, Gameplay-Engineer's CampExtrasController
	if onCollect ~= nil then
		onCollect:Connect(collected)
	end
end

return CampCollect
