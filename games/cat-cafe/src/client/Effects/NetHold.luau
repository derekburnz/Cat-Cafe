--!strict
-- The net in each player's hand (Derek 2026-10-28: "have your character holding a net while walking around until
-- catching a cat"): in a catching area, alive and with no cat in its arms, a character this client sees holds its
-- player's net, CatCafe_Item_Net_L1 to L3 from ReplicatedStorage.Assets by the player's `NetLevel` (Avatar.netModel),
-- a copy made on this client and pivoted by its `Grip` attachment into the hand before each frame draws. Tackle.luau
-- asks `NetHold.weight` every frame for each character it poses and raises the arm by that much (Avatar.holdNet);
-- the net shows once the arm is past Presets.netHold.showAt, and fades as the hand does (the player's own in first
-- person). The area is the World.Zones box the character stands in, as the WorldController reads it for the player.
-- A server that never sets `NetLevel` shows the Basic net. Nothing here replicates or fires a remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local NetHold = {}

type Held = {
	rig: Avatar.Rig,
	weight: number,
	holding: boolean,
	checkedAt: number, -- os.clock() of the last area check
	model: Model?, -- the net in the hand, while it shows
	level: number, -- the model it is (1 to 3)
	offset: CFrame, -- the model's pivot from its Grip
	parts: { BasePart }, -- the net's parts, to fade with the hand
	missing: number?, -- a level whose net the assets lack: no hold while it stays the level
}

local CHECK_SECONDS = 0.25 -- how often a character's area is read again

local held: { [Model]: Held } = {}
local started = false

-- The World.Zones box `position` stands in ("Cafe", "Alley", "Park" and so on), or nil on the street.
local function zoneAt(position: Vector3): string?
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	if zones == nil then
		return nil
	end
	for _, box in zones:GetChildren() do
		if box:IsA("BasePart") then
			local offset = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if
				math.abs(offset.X) <= half.X
				and math.abs(offset.Y) <= half.Y
				and math.abs(offset.Z) <= half.Z
			then
				return box.Name
			end
		end
	end
	return nil
end

local function alive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function drop(entry: Held)
	if entry.model ~= nil then
		entry.model:Destroy()
		entry.model = nil
	end
end

-- A copy of the level's net that never collides or blocks a click, and its pivot from the Grip (the pivot itself on
-- a net made before the Grip was added). nil when the assets have no such net.
local function make(level: number): (Model?, CFrame, { BasePart })
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = if assets ~= nil
		then assets:FindFirstChild("CatCafe_Item_Net_L" .. level)
		else nil
	if template == nil or not template:IsA("Model") then
		return nil, CFrame.identity, {}
	end
	local model = (template :: Model):Clone() :: Model
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			table.insert(parts, part)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local grip = model:FindFirstChild("Grip", true)
	local offset = if grip ~= nil and grip:IsA("Attachment")
		then (grip :: Attachment).WorldCFrame:Inverse() * model:GetPivot()
		else CFrame.identity
	model.Parent = Context.folder()
	return model, offset, parts
end

-- How far `character`'s arm is raised for its net this frame, 0 to 1, `dt` seconds after the last call; `near` is
-- false beyond the animation radius, where the arm lowers and the net goes. Also makes or drops the net to match.
function NetHold.weight(character: Model, rig: Avatar.Rig, dt: number, near: boolean): number
	local entry: Held = held[character]
		or {
			rig = rig,
			weight = 0,
			holding = false,
			checkedAt = -math.huge,
			model = nil,
			level = 0,
			offset = CFrame.identity,
			parts = {},
			missing = nil,
		}
	held[character] = entry
	entry.rig = rig
	local clock = os.clock()
	if clock - entry.checkedAt >= CHECK_SECONDS then
		entry.checkedAt = clock
		entry.holding = Avatar.holdsNet(
			zoneAt(rig.root.Position),
			character:GetAttribute("CarryingCatId"),
			alive(character)
		)
	end
	local player = Players:GetPlayerFromCharacter(character)
	local level = Avatar.netModel(if player ~= nil then player:GetAttribute("NetLevel") else nil)
	if entry.model ~= nil and entry.level ~= level then
		drop(entry) -- an upgrade bought while holding: the new net comes next
	end
	entry.weight =
		Avatar.holdWeight(entry.weight, entry.holding and near and entry.missing ~= level, dt)
	if entry.weight >= Presets.netHold.showAt then
		if entry.model == nil then
			local model, offset, parts = make(level)
			entry.model, entry.offset, entry.parts, entry.level = model, offset, parts, level
			if model == nil then
				entry.weight, entry.missing = 0, level -- no net to hold, so the arm stays down
			end
		end
	else
		drop(entry)
	end
	return entry.weight
end

-- Lets go of a character that left or was rebuilt.
function NetHold.forget(character: Model)
	local entry = held[character]
	if entry ~= nil then
		drop(entry)
		held[character] = nil
	end
end

-- Each frame before it draws, every shown net goes into its hand, where the frame's joints have put it.
local function place()
	for character, entry in held do
		local model = entry.model
		if model == nil then
			continue
		end
		if not character:IsDescendantOf(game) then
			NetHold.forget(character)
			continue
		end
		local hand, grip = Avatar.netHand(entry.rig)
		if hand ~= nil then
			model:PivotTo(hand.CFrame * grip * entry.offset)
			local fade = hand.LocalTransparencyModifier
			for _, part in entry.parts do
				part.LocalTransparencyModifier = fade
			end
		end
	end
end

function NetHold.start()
	if started then
		return
	end
	started = true
	RunService.PreRender:Connect(place)
end

return NetHold
