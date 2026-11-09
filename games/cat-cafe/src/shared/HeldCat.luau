--!strict
-- The cat in a carrier's arms (#1964), put there once and then left alone: the server's carry (CatService) and the
-- intro's demo carry (IntroController, on its local copy of you) both call HeldCat.attach. The cat curls up asleep
-- (Catching.HELD_TURNS, eyes shut), every part is welded to its body, and a Weld named HoldWeld holds the body on the torso at
-- Catching.holdPoint. A part welded to a character moves with it on every screen, the arm fold and the walk
-- included, so no client copies, hides or poses the held cat (until 2026-11-07 Effects/Carry drew a copy of it,
-- which on live showed only the body block, #1480).
--
-- Roblox terms: a Weld holds Part1 at `Part0.CFrame * C0 * C1:Inverse()`; a WeldConstraint keeps two parts where
-- they were when it was made. Massless parts add no weight to the character, so its walk speed and jump stay the
-- same. R15 avatars have an UpperTorso, R6 ones a single Torso.

local Catching = require(script.Parent.Catching)

local HeldCat = {}

-- The carrier's torso and its rig type, or nil while the character has none.
function HeldCat.torso(character: Model): (BasePart?, string)
	local upper = character:FindFirstChild("UpperTorso")
	if upper ~= nil and upper:IsA("BasePart") then
		return upper :: BasePart, "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso ~= nil and torso:IsA("BasePart") then
		return torso :: BasePart, "R6"
	end
	return nil, "R15"
end

-- A hinged piece of the walking body by its manifest name ("LegF1" or "CatCafe_Cat_Tabby_LegF1").
local function pieceOf(model: Model, name: string): Model?
	for _, child in model:GetChildren() do
		if
			child:IsA("Model") and (child.Name == name or child.Name:sub(-#name - 1) == "_" .. name)
		then
			return child :: Model
		end
	end
	return nil
end

-- Shuts an eye: every part of the Eye piece squashed to Catching.HELD_EYES of its height about the piece's pivot.
local function shut(piece: Model)
	local pivot = piece:GetPivot()
	for _, descendant in piece:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local at = pivot:ToObjectSpace(part.CFrame)
			part.Size = Vector3.new(part.Size.X, part.Size.Y * Catching.HELD_EYES, part.Size.Z)
			part.CFrame = pivot * CFrame.new(at.X, at.Y * Catching.HELD_EYES, at.Z) * at.Rotation
		end
	end
end

-- Curls the cat up asleep, once: eyes shut, then the pieces turned (the head carries its eyes with it). A cat without
-- hinged pieces keeps its shape.
function HeldCat.sleep(model: Model)
	if model:GetAttribute("HeldAsleep") == true then
		return
	end
	model:SetAttribute("HeldAsleep", true)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and (descendant.Name:match("Eye%d$") ~= nil) then
			shut(descendant :: Model)
		end
	end
	for name, angles in Catching.HELD_TURNS do
		local piece = pieceOf(model, name)
		if piece ~= nil then
			piece:PivotTo(
				piece:GetPivot()
					* CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
			)
		end
	end
end

local function bodyOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
end

-- Where the held cat's body goes, in the frame of the part it is welded to: on the torso at Catching.holdPoint, or
-- on the root at Catching.CARRIED_POSE when the character has no torso yet. The cat must be asleep already.
local function holdFrame(model: Model, character: Model, root: BasePart?): (BasePart?, CFrame)
	local body = bodyOf(model)
	local torso, rig = HeldCat.torso(character)
	if body == nil then
		return nil, CFrame.identity
	end
	local box, size = model:GetBoundingBox()
	local seat = box * CFrame.new(0, -size.Y / 2, 0) -- the bottom middle, in the cat's own axes
	if torso ~= nil then
		local x, y, z =
			Catching.holdPoint(rig, { torso.Size.X, torso.Size.Y, torso.Size.Z }, size.X)
		local hold = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(Catching.HELD.turn), 0)
		return torso, hold * seat:ToObjectSpace(body.CFrame)
	end
	local p = Catching.CARRIED_POSE
	local carried =
		CFrame.new(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], p[12])
	return root, carried * model:GetPivot():ToObjectSpace(body.CFrame)
end

--- Where the held cat's pivot would be in the world right now, for a hop into the arms (the intro).
function HeldCat.target(model: Model, character: Model, root: BasePart): CFrame
	HeldCat.sleep(model)
	local body = bodyOf(model)
	local holder, frame = holdFrame(model, character, root)
	if body == nil or holder == nil then
		return model:GetPivot()
	end
	return holder.CFrame * frame * body.CFrame:ToObjectSpace(model:GetPivot())
end

--- Puts `model` in `character`'s arms: asleep, every part unanchored, massless, not colliding, touching or found by
--- raycasts and welded to the body, and the HoldWeld on the torso (or on `root` while there is no torso). The caller
--- parents it. Returns the HoldWeld, or nil for a model with no parts or no torso and no root.
function HeldCat.attach(model: Model, character: Model, root: BasePart?): Weld?
	HeldCat.sleep(model)
	local body = bodyOf(model)
	local holder, frame = holdFrame(model, character, root)
	if body == nil or holder == nil then
		return nil
	end
	model:PivotTo(holder.CFrame * frame * body.CFrame:ToObjectSpace(model:GetPivot()))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part ~= body and part:FindFirstChild("HeldWeld") == nil then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "HeldWeld"
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local old = body:FindFirstChild("HoldWeld")
	if old ~= nil then
		old:Destroy()
	end
	local hold = Instance.new("Weld")
	hold.Name = "HoldWeld"
	hold.Part0 = holder
	hold.Part1 = body
	hold.C0 = frame
	hold.Parent = body
	return hold
end

--- #2565 (mystery-market.md section 3a): a Backpack's packed cat, upright behind the torso with its head over the
--- pack's top, welded like the held cat (massless, so the walk doesn't change). Nil when the character has no torso.
function HeldCat.attachBack(model: Model, character: Model): Weld?
	local body = bodyOf(model)
	local torso = HeldCat.torso(character)
	if body == nil or torso == nil then
		return nil
	end
	local _, size = model:GetBoundingBox()
	-- behind the back (+Z in the torso's space), a little above its middle, facing the way the player faces
	local at = CFrame.new(0, torso.Size.Y * 0.15, torso.Size.Z / 2 + size.Z * 0.3)
	local frame = at * model:GetPivot():ToObjectSpace(body.CFrame)
	model:PivotTo(torso.CFrame * at)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part ~= body and part:FindFirstChild("HeldWeld") == nil then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "HeldWeld"
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local hold = Instance.new("Weld")
	hold.Name = "HoldWeld"
	hold.Part0 = torso
	hold.Part1 = body
	hold.C0 = frame
	hold.Parent = body
	return hold
end

--- Takes the held cat off its HoldWeld and anchors every part where it is (the intro's check-in hop).
function HeldCat.release(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "HoldWeld" then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
end

return HeldCat
