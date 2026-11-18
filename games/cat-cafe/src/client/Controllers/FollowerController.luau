--!strict
-- The cat follower's walk on this client (#5172, switch catFollower; the rules are shared/Follower and the server's
-- FollowerService). Each player's FollowerCat attribute (with FollowerVariant, "gold" for the gold coat) names the
-- cat following them; this client draws that cat's normal model, anchored and with no collision, in
-- Workspace.Followers, and walks it each frame:
--   - its spot is FollowLogic.spot: SIDE studs to the side and BEHIND studs behind the player's root, at their feet;
--   - it moves toward the spot at the player's walk speed (a little faster when it falls behind) and turns the way it
--     walks, facing the player when it stops;
--   - it hops when the player jumps;
--   - more than SNAP studs away (a teleport, a fall, a cannon) it pops to the spot at once, and the model gets a
--     Popped attribute (os.clock) for Motion-FX's puff;
--   - its Moving attribute is false after IDLE seconds standing still, for Motion-FX's sit and groom;
--   - during this player's own net catch (CatchSchedule until CatchResult) it walks out to a spot ASIDE times farther
--     out and sits there (Moving false once it arrives), clear of the rings.
-- On a phone or tablet other players' followers show only within OTHERS_RANGE studs, at most OTHERS_MAX of them.
-- Show only: nothing here reaches the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local FollowLogic = require(Shared:WaitForChild("FollowLogic"))
local GoldTone = require(Shared:WaitForChild("GoldTone"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Net = require(script.Parent.Parent.Net)

local FollowerController = {}

FollowerController.FLAG = "catFollower"
FollowerController.OTHERS_RANGE = 80
FollowerController.OTHERS_MAX = 8

type Walker = {
	model: Model,
	catId: string,
	variant: string?,
	half: number, -- the model's pivot height over its feet
	position: Vector3,
	facing: Vector3,
	hop: number, -- seconds into a hop, or -1
	stillFor: number,
	floorY: number, -- the player's feet the last time they stood on something, held while they are in the air
}

local walkers: { [Player]: Walker } = {}
-- os.clock() when this player's net catch started (CatchSchedule), nil when none runs (CatchResult). Only this
-- player's own catches are known here, so only their own follower steps aside.
local catchingSince: number? = nil

local function catching(): boolean
	local since = catchingSince
	return since ~= nil and os.clock() - since < FollowLogic.CATCH_HOLD
end
local folder: Folder? = nil
local started = false

local function on(): boolean
	return LiveFlags.shown(
		FollowerController.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. FollowerController.FLAG)
	)
end

local function phone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function folderOf(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "Followers"
	made.Parent = Workspace
	folder = made
	return made
end

-- The cat's model with every script gone and every part anchored, not colliding and not hit by rays or touches.
local function cloneCat(catId: string, variant: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	local names, tone = { Catalog.catModelName(catId) }, false
	if variant == "gold" then
		names, tone = GoldTone.names(Catalog.goldModelName(catId), Catalog.catModelName(catId))
	end
	local source: Instance? = nil
	for _, name in names do
		source = assets:FindFirstChild(name)
		if source ~= nil then
			break
		end
	end
	if source == nil or not (source :: Instance):IsA("Model") then
		return nil
	end
	local copy = (source :: Model):Clone() :: Model
	if tone then
		GoldTone.apply(copy)
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	return copy
end

local function drop(owner: Player)
	local walker = walkers[owner]
	if walker ~= nil then
		walker.model:Destroy()
		walkers[owner] = nil
	end
end

local function rootOf(owner: Player): (BasePart?, Humanoid?)
	local character = owner.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil, humanoid
end

-- Whether `owner`'s follower should show here now.
local function wanted(owner: Player, shownOthers: number): boolean
	local catId = owner:GetAttribute("FollowerCat")
	if type(catId) ~= "string" or not on() then
		return false
	end
	if owner == Players.LocalPlayer or not phone() then
		return true
	end
	if shownOthers >= FollowerController.OTHERS_MAX then
		return false
	end
	local mine = rootOf(Players.LocalPlayer)
	local theirs = rootOf(owner)
	return mine ~= nil
		and theirs ~= nil
		and (mine.Position - theirs.Position).Magnitude <= FollowerController.OTHERS_RANGE
end

-- The player's feet height: under the root by half its height and the Humanoid's HipHeight.
local function floorOf(root: BasePart, humanoid: Humanoid?): number
	return FollowLogic.feet(
		root.Position.Y,
		root.Size.Y,
		if humanoid ~= nil then humanoid.HipHeight else 2
	)
end

local function make(owner: Player, root: BasePart, humanoid: Humanoid?): Walker?
	local catId = owner:GetAttribute("FollowerCat") :: string
	local rawVariant = owner:GetAttribute("FollowerVariant")
	local variant = if type(rawVariant) == "string" then rawVariant else nil
	local model = cloneCat(catId, variant)
	if model == nil then
		return nil
	end
	local box, size = model:GetBoundingBox()
	local half = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	model.Name = "Follower_" .. owner.UserId
	model:SetAttribute("Moving", false)
	-- Effects/Rainbow dresses any model with Variant "rainbow" as it is added (review nit: rainbow drew plain)
	if variant == "rainbow" then
		model:SetAttribute("Variant", "rainbow")
	end
	model:SetAttribute("OwnerUserId", owner.UserId)
	model.Parent = folderOf()
	local floorY = floorOf(root, humanoid)
	local spot = FollowLogic.spot(root.Position, root.CFrame.LookVector, floorY)
	return {
		model = model,
		catId = catId,
		variant = variant,
		half = half,
		position = spot,
		facing = root.CFrame.LookVector,
		hop = -1,
		stillFor = 0,
		floorY = floorY,
	}
end

local function step(dt: number)
	if next(walkers) == nil and not on() then
		return -- the switch is off and nothing is drawn: no work a frame
	end
	local shownOthers = 0
	for _, owner in Players:GetPlayers() do
		local want = wanted(owner, shownOthers)
		local walker: Walker? = walkers[owner]
		local root, humanoid = rootOf(owner)
		if not want or root == nil then
			drop(owner)
			continue
		end
		local catId = owner:GetAttribute("FollowerCat")
		local variant = owner:GetAttribute("FollowerVariant")
		if walker ~= nil and (walker.catId ~= catId or walker.variant ~= variant) then
			drop(owner)
			walker = nil
		end
		if walker == nil then
			walker = make(owner, root :: BasePart, humanoid)
			if walker == nil then
				continue
			end
			walkers[owner] = walker :: Walker
		end
		if owner ~= Players.LocalPlayer then
			shownOthers += 1
		end
		local w = walker :: Walker
		local r = root :: BasePart
		-- the floor under the player, kept while they jump or fall so the cat stays on the ground (review nit)
		if humanoid == nil or humanoid.FloorMaterial ~= Enum.Material.Air then
			w.floorY = floorOf(r, humanoid)
		end
		local aside = owner == Players.LocalPlayer and catching()
		local spot = FollowLogic.spot(r.Position, r.CFrame.LookVector, w.floorY, aside)
		local speed = if humanoid ~= nil then humanoid.WalkSpeed else 16
		local move = FollowLogic.move(w.position, spot, speed, dt)
		if move.snapped then
			w.model:SetAttribute("Popped", os.clock())
		end
		if move.moved > 1e-3 then
			w.facing = move.facing
			w.stillFor = 0
		else
			w.stillFor += dt
			local toOwner =
				Vector3.new(r.Position.X - move.position.X, 0, r.Position.Z - move.position.Z)
			if toOwner.Magnitude > 0.1 then
				w.facing = toOwner.Unit
			end
		end
		w.position = move.position
		if humanoid ~= nil and humanoid.Jump and w.hop < 0 then
			w.hop = 0
		end
		local lift = 0
		if w.hop >= 0 then
			w.hop += dt
			lift = FollowLogic.hop(w.hop)
			if w.hop >= FollowLogic.HOP_SECONDS then
				w.hop = -1
			end
		end
		local moving = w.stillFor < FollowLogic.IDLE and not (aside and move.moved <= 1e-3)
		if w.model:GetAttribute("Moving") ~= moving then
			w.model:SetAttribute("Moving", moving)
		end
		local at = w.position + Vector3.new(0, w.half + lift, 0)
		w.model:PivotTo(CFrame.lookAt(at, at + w.facing))
	end
	for owner in walkers do
		if owner.Parent ~= Players then
			drop(owner)
		end
	end
end

function FollowerController.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(drop)
	-- during this player's own net catch the follower sits and watches, out of the rings (cat-follower-spec.md)
	Net.on("CatchSchedule", function()
		catchingSince = os.clock()
	end)
	Net.on("CatchResult", function()
		catchingSince = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return FollowerController
