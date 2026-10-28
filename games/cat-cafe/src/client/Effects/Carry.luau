--!strict
-- The cat in each player's arms (Derek 2026-10-28: "hold it in your arms crossed arms and it should be either awake
-- loafing or sitting in your arms"). While a character carries a cat (`CarryingCatId`, set by CatService with the
-- HeldCat) Tackle.luau folds its arms across its chest by `Carry.weight` (Avatar.carryArms), and the HeldCat the
-- server welded in front of it rests on those arms instead: awake, loafing on the walking body or sitting up on the
-- sitting one (Logic's "held"), put on the arms before each frame draws (Avatar.cradle) and posed like any cat.
-- To move it, this client lets go of the HeldCat's welds and anchors its parts, here only: the server keeps its weld,
-- so where the server has the cat, and every other client's own copy, are unchanged. Past the animation radius,
-- hidden by Show other cats, or once the carry ends, the parts go back where the server had them and the welds come
-- back on. Nothing here replicates or fires a remote.

local RunService = game:GetService("RunService")

local Avatar = require(script.Parent.Avatar)
local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local Carry = {}

type Held = {
	rig: Avatar.Rig, -- the carrier's
	weight: number, -- how far the arms are folded, 0 to 1
	carrying: boolean,
	near: boolean, -- within the animation radius (or this player's own)
	cat: Model?, -- the HeldCat on the arms, while it is taken over
	catRig: Pose.Rig?,
	welds: { WeldConstraint }, -- its welds this client let go of
	parts: { BasePart }, -- its parts, anchored here while it is taken over
	offsets: { CFrame }, -- each part where the server had it, from the carrier's root
	phase: number, -- so two carried cats do not look about in step
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

-- Gives the HeldCat back to the server's weld, where the server had it.
local function release(entry: Held)
	local cat = entry.cat
	if cat == nil then
		return
	end
	local catRig = entry.catRig
	if catRig ~= nil then
		Pose.release(catRig) -- the eyes and the body back to their own size
	end
	if cat:IsDescendantOf(game) then
		local root = entry.rig.root.CFrame
		for i, part in entry.parts do
			if part.Parent ~= nil then
				part.CFrame = root * entry.offsets[i]
			end
		end
		for _, weld in entry.welds do
			weld.Enabled = true
		end
		for _, part in entry.parts do
			part.Anchored = false
		end
	end
	entry.cat, entry.catRig = nil, nil
	table.clear(entry.welds)
	table.clear(entry.parts)
	table.clear(entry.offsets)
end

-- Takes the HeldCat off the server's weld on this client, so it can rest on the arms. The welds go first: anchoring
-- a part still welded to the character would anchor the character with it.
local function take(entry: Held, cat: Model)
	local fromRoot = entry.rig.root.CFrame:Inverse()
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("WeldConstraint") and (descendant :: WeldConstraint).Enabled then
			local weld = descendant :: WeldConstraint
			weld.Enabled = false
			table.insert(entry.welds, weld)
		end
	end
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			table.insert(entry.parts, part)
			table.insert(entry.offsets, fromRoot * part.CFrame)
			part.Anchored = true
		end
	end
	entry.cat = cat
	entry.phase = rng:NextNumber(0, 100)
	local catRig = Pose.bind(cat)
	if catRig == nil or catRig.usesMotors then
		release(entry) -- a cat Pose cannot move part by part stays on the weld
		return
	end
	entry.catRig = catRig
end

-- How far `character`'s arms are folded for a carried cat this frame, 0 to 1, `dt` seconds after the last call;
-- `near` is false beyond the animation radius, where the arms let go and the cat goes back on its weld.
function Carry.weight(character: Model, rig: Avatar.Rig, dt: number, near: boolean): number
	local entry: Held = held[character]
		or {
			rig = rig,
			weight = 0,
			carrying = false,
			near = false,
			cat = nil,
			catRig = nil,
			welds = {},
			parts = {},
			offsets = {},
			phase = 0,
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
		if entry.cat ~= nil and (not wanted or entry.cat ~= cat) then
			release(entry)
		end
		if wanted and entry.cat == nil and cat ~= nil then
			take(entry, cat)
		end
		local catRig = entry.catRig
		if catRig == nil then
			continue
		end
		local hold = if catRig.kind == "sit" then "sit" else "loaf"
		local floor = Avatar.cradle(entry.rig, hold, frameOf)
		if floor == nil or not Pose.read(catRig) then
			release(entry)
			continue
		end
		Pose.hold(catRig, floor)
		Pose.draw(catRig, Logic.idle("held", now + entry.phase, catRig.kind), -1)
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
