--!strict
-- The Mystery Visitor (F64, data-model 12b): the hooded visitor arrives and leaves in a puff of purple smoke, its
-- gift appears on the table with a little sparkle, a faint twinkle hangs over your own gift while it waits, and
-- opening it pops the ribbon in confetti with sparkles and a ring in the colour of what was inside. The pop plays in
-- that colour from its first frame and never shows anything better first. An unopened gift that runs out, or goes
-- with a plot release, leaves with no pop, so it never looks opened.
--
-- Sources: the `MysteryVisitor` and `MysteryGift` tags on the models each client builds under a Plot from
-- `MysteryVisitorUntil` and `MysteryGiftAt` (data-model 13), the plot's `OwnerUserId`, and this player's own
-- `MysteryGiftResult(kind, id, count)`. Puffs play within animRadius. Listening only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Mystery = {}

type Spot = { top: Vector3, base: Vector3 }

local visitors: { [Instance]: Vector3 } = {} -- where each visitor sat, for the puff when it goes
local mine: Model? = nil -- your own gift while it waits
local mineSpot: Spot? = nil -- where it is or was, for the pop
local twinkle: Attachment? = nil
local started = false

local function spotOf(model: Model): Spot
	local frame, size = model:GetBoundingBox()
	return {
		top = frame.Position + Vector3.new(0, size.Y / 2, 0),
		base = frame.Position - Vector3.new(0, size.Y / 2 - 0.05, 0),
	}
end

local function near(at: Vector3): boolean
	return Context.distance(at) <= Context.budget.animRadius
end

-- The owner of the plot a model sits under, or nil.
local function ownerOf(model: Instance): number?
	local node = model.Parent
	while node ~= nil do
		if node:IsA("Model") and CollectionService:HasTag(node, "Plot") then
			local owner = node:GetAttribute("OwnerUserId")
			return if type(owner) == "number" then owner else nil
		end
		node = node.Parent
	end
	return nil
end

local function puff(at: Vector3)
	if near(at) then
		local m = Presets.mystery
		Particles.burst("smokePuff", at, m.puff, m.puffColour)
	end
end

-- The tagged model once its parts are in (the client tags it as it builds it), or nil if it went already.
local function settled(instance: Instance, after: (Model) -> ())
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return -- a template in ReplicatedStorage.Assets may carry the tag too
	end
	task.defer(function()
		local model = instance :: Model
		if
			model:IsDescendantOf(Workspace)
			and model:FindFirstChildWhichIsA("BasePart", true) ~= nil
		then
			after(model)
		end
	end)
end

local function stopTwinkle()
	local anchor = twinkle
	if anchor ~= nil then
		anchor:Destroy()
		twinkle = nil
	end
end

local function visitorAdded(instance: Instance)
	settled(instance, function(model: Model)
		local frame = model:GetBoundingBox()
		visitors[model] = frame.Position
		puff(frame.Position)
	end)
end

local function visitorRemoved(instance: Instance)
	local at: Vector3? = visitors[instance]
	visitors[instance] = nil
	if at ~= nil then
		puff(at)
	end
end

local function giftAdded(instance: Instance)
	settled(instance, function(model: Model)
		local spot = spotOf(model)
		if near(spot.top) then
			Particles.burst(
				"catchSparkle",
				spot.top,
				Presets.mystery.sparkle,
				Presets.palette.sparkle
			)
		end
		if ownerOf(model) ~= Players.LocalPlayer.UserId then
			return
		end
		mine, mineSpot = model, spot
		stopTwinkle()
		local anchor = Particles.anchor("GiftTwinkle", spot.top)
		Particles.attach("giftTwinkle", anchor)
		twinkle = anchor
	end)
end

local function giftRemoved(instance: Instance)
	if instance == mine then
		mine = nil -- mineSpot stays for a MysteryGiftResult that lands just after the gift goes
		stopTwinkle()
	end
end

-- The ribbon pop at your gift for what it held.
local function opened(kind: unknown, id: unknown)
	local gift = mine
	local spot = if gift ~= nil then spotOf(gift) else mineSpot
	mineSpot = nil
	if spot == nil then
		return
	end
	local m = Presets.mystery
	local colour = Logic.giftColour(kind, id)
	Particles.confetti(spot.top, math.ceil(Context.budget.confetti * m.confetti), m.ribbon)
	Particles.burst("catchSparkle", spot.top, m.pop, colour)
	Particles.ring(spot.base, colour, m.ring, m.ringSeconds)
end

function Mystery.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("MysteryVisitor") do
		settled(instance, function(model: Model)
			visitors[model] = model:GetBoundingBox().Position -- already sitting: no arrival puff
		end)
	end
	CollectionService:GetInstanceAddedSignal("MysteryVisitor"):Connect(visitorAdded)
	CollectionService:GetInstanceRemovedSignal("MysteryVisitor"):Connect(visitorRemoved)
	for _, instance in CollectionService:GetTagged("MysteryGift") do
		giftAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal("MysteryGift"):Connect(giftAdded)
	CollectionService:GetInstanceRemovedSignal("MysteryGift"):Connect(giftRemoved)
	-- MysteryGiftResult(kind, id, count): what your gift held. Net.on waits for the remote with no end, and it only
	-- exists once the server has F64, so this hooks it up whenever it appears instead.
	task.spawn(function()
		local folder = Remotes.folder()
		local function hook(child: Instance): boolean
			if child.Name ~= "MysteryGiftResult" or not child:IsA("RemoteEvent") then
				return false
			end
			(child :: RemoteEvent).OnClientEvent:Connect(function(kind: unknown, id: unknown)
				opened(kind, id)
			end)
			return true
		end
		local existing = folder:FindFirstChild("MysteryGiftResult")
		if existing ~= nil and hook(existing) then
			return
		end
		local waiting: RBXScriptConnection? = nil
		waiting = folder.ChildAdded:Connect(function(child: Instance)
			if hook(child) and waiting ~= nil then
				waiting:Disconnect()
			end
		end)
	end)
end

return Mystery
