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

-- #3018 (Laptop-Tester: the Golem's box-shaped body poked through the carrier's arms): a cat whose model carries a
-- HeldScale attribute (Model-Agent's, cats.py held_scale) rides in the arms at that share of its size, once.
local function fitHeld(model: Model)
	local k = model:GetAttribute("HeldScale")
	if typeof(k) == "number" and k > 0 and k ~= 1 and model:GetAttribute("HeldScaled") == nil then
		model:ScaleTo(model:GetScale() * k)
		model:SetAttribute("HeldScaled", true)
	end
end

--- Where the held cat's pivot would be in the world right now, for a hop into the arms (the intro).
function HeldCat.target(model: Model, character: Model, root: BasePart): CFrame
	HeldCat.sleep(model)
	fitHeld(model)
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
	fitHeld(model)
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

-- #2719 (Derek2 2026-11-09: "make players wear a backpack when bought and the first cat they grab goes in it with
-- just their head sticking out"): the Backpack's owner wears Model-Agent's CatCafe_Item_Backpack behind the torso,
-- and the packed cat rides in it with only its head out of the top. Numbers are in the pack's own space at scale 1
-- (mysteryitems.py: the pivot is the middle of the strap side, the cat face -Z).
HeldCat.PACK = "WornBackpack" -- the worn pack's name in the character
HeldCat.PACK_ASSET = "CatCafe_Item_Backpack"
local FLAP_HINGE = "FlapHinge" -- the Weld that holds the flap, open or shut
-- Model-Agent's FLAP_OPEN is 125; worn, that swings the flap's top into the wearer's head, so it stands straight up
local FLAP_OPEN = 90
local PACK_RIM = 0.66 -- the top of the pack's opening
local PACK_MOUTH_Z = -0.33 -- the middle of the opening, front to back
-- the packed cat's size, so its head fits the opening. #2888 (Derek2: the cat's head "like 60% smaller"): 0.4 in
-- the 1.4x pack is about 0.56x the cat, was 0.7 in the 2x pack (1.4x)
local PACKED_SCALE = 0.4
local HEAD_OUT = 0.75 -- how much of the head's height shows over the rim
local PACK_PART = "PackPart" -- the Weld that holds each part of the bag (not the flap) to its body
-- #2733: how much wider (x) and deeper (z) the bag gets with a cat in it; its back stays against the wearer
local BULGE = Vector3.new(1.12, 1, 1.1)
-- #2849 (Derek2: the worn Backpack and its cat "at least 2x bigger"): the pack's size over the torso-fit one; the
-- packed cat follows through the pack's scale. PACK_DROP (per unit of scale) lowers it so the taller bag does not
-- ride up past the shoulders. #2888 (Derek2: "about 30% smaller"): 1.4, was 2.
local PACK_GROW = 1.4
local PACK_DROP = 0.15

-- The worn pack on `character`, nil without one.
function HeldCat.pack(character: Model): Model?
	local pack = character:FindFirstChild(HeldCat.PACK)
	return if pack ~= nil and pack:IsA("Model") then pack :: Model else nil
end

-- #2856: whether `character` wears its pack and the pack is still welded to the character's current torso. False
-- when the pack is gone, or when the avatar's appearance rebuilt the torso after it went on (the weld went with it).
function HeldCat.packHeld(character: Model): boolean
	local pack = HeldCat.pack(character)
	local torso = HeldCat.torso(character)
	if pack == nil or torso == nil then
		return false
	end
	local weld = pack:FindFirstChild("PackWeld", true)
	return weld ~= nil
		and weld:IsA("Weld")
		and (weld :: Weld).Part0 == torso
		and (weld :: Weld).Part1 ~= nil
end

-- Puts `pack` (a clone of CatCafe_Item_Backpack, not yet parented) on `character`'s back: behind the torso, turned so
-- the cat face looks backward, scaled to the torso, every part welded (massless, colliding with nothing), the flap
-- on a Weld that HeldCat.openPack turns. The caller parents it to the character. False without a torso.
function HeldCat.wearPack(pack: Model, character: Model): boolean
	local torso = HeldCat.torso(character)
	local body = bodyOf(pack)
	if torso == nil or body == nil then
		return false
	end
	pack.Name = HeldCat.PACK
	local scale = math.clamp(torso.Size.X / 2, 0.6, 1.6) * PACK_GROW
	if math.abs(scale - 1) > 1e-3 then
		pack:ScaleTo(pack:GetScale() * scale)
	end
	pack:PivotTo(
		torso.CFrame
			* CFrame.new(0, -PACK_DROP * scale, torso.Size.Z / 2)
			* CFrame.Angles(0, math.pi, 0)
	)
	local flap: Model? = nil
	for _, child in pack:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-5) == "_Flap" then
			flap = child :: Model
		end
	end
	local flapBody = if flap ~= nil then bodyOf(flap) else nil
	for _, descendant in pack:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local onFlap = flap ~= nil and flapBody ~= nil and part:IsDescendantOf(flap)
			if part == body then
				part:SetAttribute("RestSize", part.Size)
			elseif onFlap and flapBody ~= nil and part ~= flapBody then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = flapBody
				weld.Part1 = part
				weld.Parent = part
			elseif not onFlap then
				-- a Weld rather than a WeldConstraint, so the bulge can move it out
				local rest = body.CFrame:ToObjectSpace(part.CFrame)
				local weld = Instance.new("Weld")
				weld.Name = PACK_PART
				weld.Part0 = body
				weld.Part1 = part
				weld.C0 = rest
				weld:SetAttribute("Rest", rest)
				weld:SetAttribute("RestSize", part.Size)
				weld.Parent = part
			end
		end
	end
	if flap ~= nil and flapBody ~= nil then
		local hinge = flap:GetPivot()
		local shut = body.CFrame:ToObjectSpace(flapBody.CFrame)
		local open = body.CFrame:ToObjectSpace(
			hinge * CFrame.Angles(math.rad(FLAP_OPEN), 0, 0) * hinge:ToObjectSpace(flapBody.CFrame)
		)
		local weld = Instance.new("Weld")
		weld.Name = FLAP_HINGE
		weld.Part0 = body
		weld.Part1 = flapBody
		weld.C0 = shut
		weld:SetAttribute("Shut", shut)
		weld:SetAttribute("Open", open)
		weld.Parent = flapBody
	end
	local hold = Instance.new("Weld")
	hold.Name = "PackWeld"
	hold.Part0 = torso
	hold.Part1 = body
	hold.C0 = torso.CFrame:ToObjectSpace(body.CFrame)
	hold:SetAttribute("Rest", hold.C0)
	hold.Parent = body
	return true
end

-- How much a part turned by `rotation` (in the bag body's space) grows along each of its own axes when the bag
-- grows by `factor` along the body's axes.
local function grownSize(rotation: CFrame, factor: Vector3): Vector3
	local function along(axis: Vector3): number
		return (axis * factor).Magnitude
	end
	return Vector3.new(
		along(rotation.RightVector),
		along(rotation.UpVector),
		along(rotation.LookVector)
	)
end

-- #2733: the bag full (BULGE) or empty. The body moves away from the wearer by its own growth, so its back stays on
-- the torso; every other bag part moves out with it and grows along its own axes. The flap keeps its size.
local function bulge(pack: Model, full: boolean)
	local body = bodyOf(pack)
	local restSize = if body ~= nil then body:GetAttribute("RestSize") else nil
	if body == nil or typeof(restSize) ~= "Vector3" then
		return
	end
	local factor = if full then BULGE else Vector3.one
	body.Size = restSize * factor
	local hold = body:FindFirstChild("PackWeld")
	local holdRest = if hold ~= nil then hold:GetAttribute("Rest") else nil
	if hold ~= nil and hold:IsA("Weld") and typeof(holdRest) == "CFrame" then
		-- the body's back face, against the wearer, is at +Z/2 in its own space
		(hold :: Weld).C0 = holdRest * CFrame.new(0, 0, -(factor.Z - 1) * restSize.Z / 2)
	end
	for _, descendant in pack:GetDescendants() do
		if descendant.Name == PACK_PART and descendant:IsA("Weld") then
			local weld = descendant :: Weld
			local rest = weld:GetAttribute("Rest")
			local size = weld:GetAttribute("RestSize")
			local part = weld.Part1
			if typeof(rest) == "CFrame" and typeof(size) == "Vector3" and part ~= nil then
				weld.C0 = CFrame.new(rest.Position * factor) * rest.Rotation
				part.Size = size * grownSize(rest.Rotation, factor)
			end
		end
	end
end

-- Opens or shuts the worn pack's flap and fills or empties the bag: open and a little wider while a cat rides in it
-- (#2733). Nothing without a worn pack.
function HeldCat.openPack(character: Model, open: boolean)
	local pack = HeldCat.pack(character)
	if pack == nil then
		return
	end
	bulge(pack, open)
	local hinge = pack:FindFirstChild(FLAP_HINGE, true)
	if hinge == nil or not hinge:IsA("Weld") then
		return
	end
	local frame = hinge:GetAttribute(if open then "Open" else "Shut")
	if typeof(frame) == "CFrame" then
		(hinge :: Weld).C0 = frame
	end
end

-- Welds every part of `model` to its body and the body to `part0` where it is now (massless, colliding with nothing).
local function weldOn(model: Model, body: BasePart, part0: BasePart): Weld
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
	hold.Part0 = part0
	hold.Part1 = body
	hold.C0 = part0.CFrame:ToObjectSpace(body.CFrame)
	hold.Parent = body
	return hold
end

--- #2565 (mystery-market.md section 3a): a Backpack's packed cat, welded like the held cat (massless, so the walk
--- doesn't change). #2719: in the worn pack (HeldCat.wearPack) it sits at PACKED_SCALE facing backward with only its
--- head out of the top, the rest of it hidden inside, and the flap opens; with no pack it stands upright behind the
--- torso as before. Nil when the character has no torso.
function HeldCat.attachBack(model: Model, character: Model): Weld?
	local body = bodyOf(model)
	local torso = HeldCat.torso(character)
	if body == nil or torso == nil then
		return nil
	end
	local pack = HeldCat.pack(character)
	local head = pieceOf(model, "Head")
	if pack ~= nil and head ~= nil then
		local packScale = pack:GetScale()
		model:ScaleTo(model:GetScale() * PACKED_SCALE * packScale)
		local box, size = head:GetBoundingBox()
		local headAt = model:GetPivot():PointToObjectSpace(box.Position)
		local rim = PACK_RIM * packScale
		local mouth = CFrame.new(0, rim + size.Y * (HEAD_OUT - 0.5), PACK_MOUTH_Z * packScale)
		model:PivotTo(pack:GetPivot() * mouth * CFrame.new(-headAt))
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant:IsDescendantOf(head) then
				(descendant :: BasePart).Transparency = 1 -- inside the pack
			end
		end
		HeldCat.openPack(character, true)
		return weldOn(model, body, torso)
	end
	local _, size = model:GetBoundingBox()
	-- behind the back (+Z in the torso's space), a little above its middle, facing the way the player faces
	local at = CFrame.new(0, torso.Size.Y * 0.15, torso.Size.Z / 2 + size.Z * 0.3)
	model:PivotTo(torso.CFrame * at)
	return weldOn(model, body, torso)
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
