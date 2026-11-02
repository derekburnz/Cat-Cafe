--!strict
-- The secured cat's happy hop with a full spin (F89, luck-and-rare-moments.md 2a: "the cat does a happy hop with a
-- full spin at the door (Animation-Engineer) inside the existing catch beam"). On the server's SecuredRare for a big
-- pull (Logic.bigPull: a Legendary, a Mythical, a gold Epic or a rainbow cat), a copy of the cat on its walking body
-- (gold if it is) appears just in front of the player who secured it, facing them, inside the beam Pull.luau raises
-- there. It crouches, leaps and turns a full turn in the air, lands with a squash, sits up proud and fades out, 1.6 s
-- in all (Logic.pullHop, Logic.pullHopPose, Presets.pullHop). The securing player always sees it; others within
-- Presets.bigPull.within do too, like the pop. With no model for the cat nothing plays. Listening only: the copy is
-- this client's own, anchored and not colliding, in Context.folder().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)
local Pull = require(script.Parent.Pull)

local PullHop = {}

type Hop = {
	copy: Model,
	rig: Pose.Rig,
	parts: { BasePart },
	floor: CFrame, -- where it stands, facing the player
	startedAt: number,
	phase: number,
}

local hops: { [number]: Hop } = {} -- by the securing player's UserId: a new pull replaces theirs
local started = false

local function template(catId: string, gold: boolean): Model?
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	if folder == nil then
		return nil
	end
	local names = { Catalog.catModelName(catId) }
	if gold then
		table.insert(names, 1, Catalog.goldModelName(catId))
	end
	for _, name in names do
		local found = folder:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

local function setFade(parts: { BasePart }, k: number)
	for _, part in parts do
		part.LocalTransparencyModifier = k
	end
end

local function finish(userId: number)
	local hop = hops[userId]
	if hop ~= nil then
		hops[userId] = nil
		Pose.release(hop.rig)
		hop.copy:Destroy()
	end
end

local function secured(
	userId: unknown,
	catId: unknown,
	rarity: unknown,
	gold: unknown,
	variant: unknown
)
	if type(userId) ~= "number" or type(catId) ~= "string" then
		return
	end
	local shiny = gold == true
	if not Logic.bigPull(rarity, shiny, variant == "rainbow") then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local at = (root :: BasePart).Position
	if player ~= Players.LocalPlayer and Context.distance(at) > Presets.bigPull.within then
		return
	end
	local source = template(catId, shiny)
	if source == nil then
		return
	end
	local h = Presets.pullHop
	local look = (root :: BasePart).CFrame.LookVector * Vector3.new(1, 0, 1)
	local ahead = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot = at + ahead * h.ahead
	local ground = Pull.floorBelow(spot, { character }, 10) or (spot - Vector3.new(0, 3, 0))
	local floor = CFrame.lookAt(ground, Vector3.new(at.X, ground.Y, at.Z))
	finish(userId)
	local copy = (source :: Model):Clone() :: Model
	copy.Name = "SecuredHop"
	copy:SetAttribute("CatId", catId)
	copy:SetAttribute("Gold", shiny)
	if type(variant) == "string" then
		copy:SetAttribute("Variant", variant)
	end
	local parts: { BasePart } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.LocalTransparencyModifier = 1
			table.insert(parts, part)
		end
	end
	copy:PivotTo(floor)
	copy.Parent = Context.folder()
	local rig = Pose.bind(copy) -- after the anchoring: Pose binds an unanchored body only to its Motor6Ds
	if rig == nil or rig.usesMotors then
		copy:Destroy()
		return
	end
	hops[userId] = {
		copy = copy,
		rig = rig,
		parts = parts,
		floor = floor,
		startedAt = os.clock(),
		phase = Random.new():NextNumber(0, 20),
	}
end

local function step()
	local now = os.clock()
	local h = Presets.pullHop
	for userId, hop in hops do
		local alpha = (now - hop.startedAt) / h.seconds
		if alpha >= 1 or hop.copy.Parent == nil or not Pose.read(hop.rig) then
			finish(userId)
			continue
		end
		local lift, turn = Logic.pullHop(alpha)
		local o = Logic.idle("stray", now + hop.phase, hop.rig.kind)
		Logic.pullHopPose(o, alpha)
		Pose.hold(hop.rig, hop.floor * CFrame.new(0, lift, 0) * CFrame.Angles(0, turn, 0))
		Pose.draw(hop.rig, o, -1)
		local shown = math.min(alpha / h.fadeIn, (1 - alpha) / h.fadeOut, 1)
		setFade(hop.parts, 1 - math.clamp(shown, 0, 1))
	end
end

function PullHop.start()
	if started then
		return
	end
	started = true
	-- SecuredRare(userId, catId, rarity, gold, variant) to every client (Gameplay-Engineer, F89 and F99)
	Context.whenRemote("SecuredRare", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(secured)
	end)
	RunService.PreRender:Connect(step)
end

return PullHop
