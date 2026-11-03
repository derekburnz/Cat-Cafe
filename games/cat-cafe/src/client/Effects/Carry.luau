--!strict
-- The cat in each player's arms (Derek 2026-10-28: "hold it in your arms crossed arms and it should be either awake
-- loafing or sitting in your arms"). While a character carries a cat (`CarryingCatId`, set by CatService with the
-- HeldCat) Tackle.luau folds its arms across its chest by `Carry.weight` (Avatar.carryArms), and a copy of the cat
-- rests on those arms: awake and loafing (Logic's "held"; Derek 14:16 picked the loaf over sitting up), put on the
-- arms before each frame draws (Avatar.cradle) and posed like any cat.
--
-- The copy is this client's own, anchored and not colliding, in Context.folder(), and the HeldCat itself is only
-- hidden here (LocalTransparencyModifier, every frame, since the camera scripts write it on the whole character).
-- The HeldCat's welds and parts are never touched: until 2026-11-03 this took the HeldCat off its welds and anchored
-- its parts inside the carrier's character, which the game never drew on the arms (Derek 00:55 "carrying still shows
-- nothing", 01:02 "starts for half a second then cat flashes and teleports away"). Past the animation radius, hidden
-- by Show other cats (HiddenLocal), or once the carry ends, the copy goes and the HeldCat shows on its weld again.
-- A staged character (Tackle.luau's StagedCharacter, the intro's copy of you) works the same with its local HeldCat.
-- Nothing here replicates or fires a remote.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local Carry = {}

type Held = {
	rig: Avatar.Rig, -- the carrier's
	weight: number, -- how far the arms are folded, 0 to 1
	carrying: boolean,
	near: boolean, -- within the animation radius (or this player's own)
	cat: Model?, -- the HeldCat shown on the arms by its copy
	copy: Model?, -- this client's copy of it, on the arms
	copyRig: Pose.Rig?,
	phase: number, -- so two carried cats do not look about in step
	refused: Model?, -- the last HeldCat Pose could not move, left showing until retryAt
	retryAt: number,
}

local held: { [Model]: Held } = {}
local started = false
local rng = Random.new()

local function alive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function frameOf(part: BasePart): CFrame
	return part.CFrame
end

-- The HeldCat's parts and decals hidden on this client (or shown again), all of them each time, so a piece that
-- arrives later is hidden too.
local function setHidden(cat: Model, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, item in cat:GetDescendants() do
		if item:IsA("BasePart") then
			(item :: BasePart).LocalTransparencyModifier = value
		elseif item:IsA("Decal") then
			(item :: Decal).LocalTransparencyModifier = value
		end
	end
end

-- Takes the copy off the arms and shows the HeldCat on its weld again (unless Show other cats hides it).
local function release(entry: Held)
	local cat = entry.cat
	if entry.copy ~= nil then
		entry.copy:Destroy()
	end
	if cat ~= nil and cat.Parent ~= nil and cat:GetAttribute("HiddenLocal") ~= true then
		setHidden(cat, false)
	end
	entry.cat, entry.copy, entry.copyRig = nil, nil, nil
end

-- A copy of `cat` for the arms: every part anchored and out of the way, its welds and tags gone (Pose moves each
-- part, and nothing looks for it by tag), named so nothing takes it for the HeldCat. Its colours, outfit and
-- attributes are the HeldCat's as this client has them, so a gold or rainbow coat (Rainbow watches it like any cat
-- model) and a signature cat's glowing eyes come along.
local function copyOf(cat: Model): Model?
	cat.Archivable = true -- on this client only; a model that is not archivable clones to nil
	local copy = cat:Clone() :: Model?
	if copy == nil then
		return nil
	end
	copy.Name = "CarriedCat"
	for _, tag in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, tag)
	end
	for _, descendant in copy:GetDescendants() do
		for _, tag in CollectionService:GetTags(descendant) do
			CollectionService:RemoveTag(descendant, tag)
		end
		-- its welds, and any name tag (one shows on the HeldCat already, if at all)
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.LocalTransparencyModifier = 0
		end
	end
	return copy
end

-- Puts a copy of `cat` on the carrier's arms and hides the HeldCat. A cat Pose cannot move part by part (one with
-- Motor6D joints) is left showing on its weld and tried again after Presets.carryPose.retry seconds.
local function show(entry: Held, cat: Model, now: number)
	local copy = copyOf(cat)
	if copy ~= nil then
		copy.Parent = Context.folder()
	end
	local copyRig = if copy ~= nil then Pose.bind(copy) else nil -- its parts are anchored: Pose moves each one
	if copy == nil or copyRig == nil or copyRig.usesMotors then
		if copy ~= nil then
			copy:Destroy()
		end
		entry.refused, entry.retryAt = cat, now + Presets.carryPose.retry
		return
	end
	entry.cat, entry.copy, entry.copyRig = cat, copy, copyRig
	entry.phase = rng:NextNumber(0, 100)
	setHidden(cat, true)
end

-- How far `character`'s arms are folded for a carried cat this frame, 0 to 1, `dt` seconds after the last call;
-- `near` is false beyond the animation radius, where the arms let go and the HeldCat shows on its weld.
function Carry.weight(character: Model, rig: Avatar.Rig, dt: number, near: boolean): number
	local entry: Held = held[character]
		or {
			rig = rig,
			weight = 0,
			carrying = false,
			near = false,
			cat = nil,
			copy = nil,
			copyRig = nil,
			phase = 0,
			refused = nil,
			retryAt = 0,
		}
	held[character] = entry
	entry.rig = rig
	entry.near = near
	entry.carrying = Avatar.carrying(character:GetAttribute("CarryingCatId"), alive(character))
	entry.weight = Avatar.holdWeight(entry.weight, entry.carrying and near, dt, Presets.carryPose)
	return entry.weight
end

-- Lets go of a character that left or was rebuilt.
function Carry.forget(character: Model)
	local entry = held[character]
	if entry ~= nil then
		release(entry)
		held[character] = nil
	end
end

-- The copy on the arms that stands in for `heldCat` on this client, nil while the HeldCat shows itself: Cats.luau
-- puts a gold cat's sparkle on it and the camp check-in hops it into the basket.
function Carry.copyFor(heldCat: Model): Model?
	for _, entry in held do
		if entry.cat == heldCat then
			return entry.copy
		end
	end
	return nil
end

-- Each frame before it draws, every carried cat in range goes onto its carrier's arms, where this frame's joints
-- have put them, and takes its next breath and look.
local function place()
	local now = os.clock()
	for character, entry in held do
		if not character:IsDescendantOf(game) then
			Carry.forget(character)
			continue
		end
		local found = character:FindFirstChild("HeldCat")
		local cat: Model? = if found ~= nil and found:IsA("Model") then found :: Model else nil
		local wanted = cat ~= nil
			and entry.carrying
			and entry.near
			and cat:GetAttribute("HiddenLocal") ~= true
			and (cat ~= entry.refused or now >= entry.retryAt)
		local copy = entry.copy
		if entry.cat ~= nil and (not wanted or entry.cat ~= cat or copy == nil or copy.Parent == nil) then
			release(entry)
		end
		if wanted and entry.cat == nil and cat ~= nil then
			show(entry, cat, now)
		end
		local copyRig = entry.copyRig
		if copyRig == nil or cat == nil then
			continue
		end
		setHidden(cat, true) -- the camera scripts put the character's parts back every so often
		local floor = Avatar.cradle(entry.rig, "loaf", frameOf)
		if floor == nil or not Pose.read(copyRig) then
			release(entry)
			continue
		end
		Pose.hold(copyRig, floor)
		Pose.draw(copyRig, Logic.idle("held", now + entry.phase, copyRig.kind), -1)
	end
end

function Carry.start()
	if started then
		return
	end
	started = true
	RunService.PreRender:Connect(place)
end

return Carry
