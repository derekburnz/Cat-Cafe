--!strict
-- The dragon who lives in the Dragon Keep (#4567, Derek 2026-11-15: "I want to see a physical dragon in the keep ...
-- it should change view (only for the player) of what it looks like with the tier matching the players tier").
-- On this client only: the dragon of this player's own stage stands on the Keep's yard, looking out the gate.
-- Nothing at stage 0 or while the Keep is shut; the cushion hides from stage 2 (the Hatchling sleeps on it). Two
-- players at different stages each see their own dragon.
--
-- Sources: the `DragonKeep`-tagged model (WorldBuilder), Model-Agent's dragons (ReplicatedStorage.Assets.Dragon,
-- CatCafe_Dragon_<Stage>: pivot the base centre, front -Z as the Keep's, every part Anchored and CanCollide false)
-- and each ProfileSync's `dragon` view (stage, colour). A stage change swaps him, after the stage-up cutscene when
-- one is playing (Effects/DragonRise). Listening only: no remote is fired and nothing on the server changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)

local KeepDragon = {}

local TAG = "DragonKeep"
local KIT = "Dragon"
local NAME = "KeepDragon"
local STAGES = { "Hatchling", "Whelp", "Drake", "Elder", "Crowned" }
local LIFT = 0.22 -- the yard's paving above the Keep's pivot (its DragonSpot)
-- How far forward of the yard's middle each stage stands, and how big he is shown. The Hatchling is 1.9 tall behind
-- a 3 stud wall: half as big again so he shows through the gate. The Crowned dragon at full size (10.7 across the
-- wings, his tail 6.9 behind his pivot) put a wing over the wall and his tail into the gold pile at the back of the
-- 12.6 wide yard (Studio sweep 2026-11-15), so he is shown at 0.8 and a stud forward: wings 8.5 across, tail 4.5 back.
local FORWARD = { 0, 0, 0, 0, 1 }
local SCALE = { 1.5, 1, 1, 1, 0.8 }
local LOOK_SECONDS = 1
local CUSHION = "_Cushion"
local SCALE_SUFFIX = "_Scale"

local started = false
local stage = 0 -- this player's stage, 0 for none or a shut Keep
local colour: string? = nil
local shown: Model? = nil
local shownStage = 0
local shownColour: string? = nil
local shownKeep: Model? = nil
local cushions: { [BasePart]: number } = {}

-- The stage (1 to 5) a `dragon` view shows, or 0: nil or false while the switch is off or the tier is not reached.
function KeepDragon.stageOf(view: any): number
	if type(view) ~= "table" then
		return 0
	end
	local at = view.stage
	if type(at) ~= "number" or at ~= at or at < 1 then
		return 0
	end
	return math.min(math.floor(at), #STAGES)
end

-- The asset a stage stands as (CatCafe_Dragon_<Stage>), or nil for stage 0.
function KeepDragon.assetOf(at: number): string?
	local name = STAGES[at]
	return if name ~= nil then "CatCafe_Dragon_" .. name else nil
end

-- Where a stage's dragon stands from the Keep's pivot: how far up, and how far forward (toward the gate, the
-- Keep's -Z).
function KeepDragon.spot(at: number): (number, number)
	return LIFT, FORWARD[at] or 0
end

local function findKeep(): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

local function restoreCushion()
	for part, was in cushions do
		if part.Parent ~= nil then
			part.Transparency = was
		end
	end
	table.clear(cushions)
end

local function hideCushion(keep: Model)
	for _, descendant in keep:GetDescendants() do
		local holder = descendant.Parent
		if
			descendant:IsA("BasePart")
			and cushions[descendant :: BasePart] == nil
			and (
				descendant.Name:sub(-#CUSHION) == CUSHION
				or (holder ~= nil and holder:IsA("Model") and holder.Name:sub(-#CUSHION) == CUSHION)
			)
		then
			local part = descendant :: BasePart
			cushions[part] = part.Transparency
			part.Transparency = 1
		end
	end
end

local function drop()
	if shown ~= nil then
		shown:Destroy()
	end
	shown, shownStage, shownColour, shownKeep = nil, 0, nil, nil
	restoreCushion()
end

local function paint(model: Model, tint: Color3)
	for _, descendant in model:GetDescendants() do
		local holder = descendant.Parent
		if
			descendant:IsA("BasePart")
			and (
				descendant.Name:sub(-#SCALE_SUFFIX) == SCALE_SUFFIX
				or (
					holder ~= nil
					and holder:IsA("Model")
					and holder.Name:sub(-#SCALE_SUFFIX) == SCALE_SUFFIX
				)
			)
		then
			(descendant :: BasePart).Color = tint
		end
	end
end

local function build(keep: Model, at: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local kit = if assets ~= nil then assets:FindFirstChild(KIT) else nil
	local name = KeepDragon.assetOf(at)
	local source = if kit ~= nil and name ~= nil then kit:FindFirstChild(name) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local model = (source :: Model):Clone() :: Model
	model.Name = NAME
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	local size = SCALE[at] or 1
	if size ~= 1 then
		model:ScaleTo(size)
	end
	local tint = if colour ~= nil then (Presets.dragonRise.scales :: any)[colour] else nil
	if typeof(tint) == "Color3" then
		paint(model, tint)
	end
	local up, forward = KeepDragon.spot(at)
	model:PivotTo(keep:GetPivot() * CFrame.new(0, up, -forward))
	model.Parent = keep
	return model
end

-- True while the stage-up cutscene plays. Effects/DragonRise is required only here, once a dragon stands, so this
-- module's pure parts load without it.
local function rising(): boolean
	local DragonRise = require(script.Parent.DragonRise) :: any
	return DragonRise.playing() == true
end

local function refresh()
	local keep = findKeep()
	if keep == nil or stage == 0 then
		if shown ~= nil or next(cushions) ~= nil then
			drop()
		end
		return
	end
	local gone = shown == nil or (shown :: Model).Parent == nil
	if not gone and shownStage == stage and shownColour == colour and shownKeep == keep then
		return
	end
	-- the stage-up cutscene shows its own copies and gives the look back when it ends
	if not gone and rising() then
		return
	end
	drop()
	local model = build(keep, stage)
	if model == nil then
		return
	end
	shown, shownStage, shownColour, shownKeep = model, stage, colour, keep
	if stage >= 2 then
		hideCushion(keep)
	end
end

-- Swap him to this player's look now (Effects/DragonStageCut calls it as the stage-up cutscene ends, so the old
-- look does not stand there for up to LOOK_SECONDS before the next check).
function KeepDragon.refresh()
	refresh()
end

-- Studio only: the stage the Workspace attribute KeepDragonTest (0 to 5) asks for, or nil when it is not set.
local function testStage(): number?
	if not RunService:IsStudio() then
		return nil
	end
	local asked = Workspace:GetAttribute("KeepDragonTest")
	if type(asked) ~= "number" then
		return nil
	end
	return if asked >= 1 then KeepDragon.stageOf({ stage = asked }) else 0
end

function KeepDragon.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local view = (state :: { [string]: any }).dragon
		-- Studio only: a stage set by hand (KeepDragonTest) stays until the attribute is cleared
		stage = testStage() or KeepDragon.stageOf(view)
		local picked = if type(view) == "table" then view.colour else nil
		colour = if type(picked) == "string" then picked else nil
		refresh()
	end)
	if RunService:IsStudio() then
		-- Studio only: Workspace attribute KeepDragonTest (0 to 5) shows that stage, switch on or off, until it is
		-- cleared (the next ProfileSync shows the real stage again)
		Workspace:GetAttributeChangedSignal("KeepDragonTest"):Connect(function()
			stage = testStage() or 0
			refresh()
		end)
	end
	-- the Keep streams in and out with the Castle's camp
	local look = 0
	RunService.Heartbeat:Connect(function(dt: number)
		look -= dt
		if look <= 0 then
			look = LOOK_SECONDS
			refresh()
		end
	end)
end

return KeepDragon
