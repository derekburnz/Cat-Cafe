--!strict
-- A working cat's outfit (features.md F25, data-model section 5; Derek 2026-10-27: outfits by role), shared so the
-- server's working cats (World/CatPose) and the intro's seated waiter (IntroController, F72) dress the same way.
--
-- Outfit pieces go on the seated cat's Outfit_<Piece> Attachments (manifest sit_slots), which ride the Body or the
-- Head, so the asset thread can move a slot without a code change. Each piece's parts get Follows = "Body" or
-- "Head", which the client's idles (Effects/Pose) read. A walking body (F90's walking staff, Effects/CafeWalk) wears
-- a piece's walking cut, CatCafe_Accessory_<Piece>_Walk (Model-Agent #787), where one exists.
--
-- Roblox terms: an Attachment is a named point and rotation inside a part; its WorldCFrame follows the part.

local Catalog = require(script.Parent.Catalog)

local CatDress = {}

-- The exporter's object Model whose name ends in _<suffix> ("Head", "Tail"), or nil (placeholder cats have none).
local function objectModel(model: Model, suffix: string): Model?
	local tail = "_" .. suffix
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-#tail) == tail then
			return child :: Model
		end
	end
	return nil
end

function CatDress.scaleOf(model: Model): number
	local scale = model:GetAttribute("Scale")
	return if type(scale) == "number" and scale > 0 then scale else 1
end

-- Which of `role`'s pieces a cat with props in `propSlot` and `propSlot2` (the model's PropSlot and PropSlot2) wears,
-- and which of its own props comes off for them (features.md F71, data-model section 5): a piece in a slot either
-- prop takes stays off, except that an Entertainer with a Head and a Back prop wears the party hat in place of its
-- head prop at the station, so its "Prop" (or "Prop2") object comes off. Pure, for the specs.
function CatDress.plan(role: string, propSlot: string?, propSlot2: string?): ({ string }, string?)
	local pieces = Catalog.roleOutfits[role]
	if pieces == nil then
		return {}, nil
	end
	local taken: { [string]: boolean } = {}
	if propSlot ~= nil then
		taken[propSlot] = true
	end
	if propSlot2 ~= nil then
		taken[propSlot2] = true
	end
	local offProp: string? = nil
	if role == "entertainer" and taken.Head == true and taken.Back == true then
		taken.Head = false
		offProp = if propSlot == "Head" then "Prop" else "Prop2"
	end
	local wear: { string } = {}
	for _, piece in pieces do
		local slot = Catalog.outfitPieceSlots[piece]
		if slot == nil or not taken[slot] then
			table.insert(wear, piece)
		end
	end
	return wear, offProp
end

-- Whether `model` is a walking body (A) rather than a seated one (B): a seated body carries Pose "sit" (CafeService
-- and the intro set it on the _Sit clones they dress) or still has its asset's _Sit name. A working cat whose seat
-- is not exported yet sits on its walking body, so it gets the walking cut too, which is the one its slots fit.
function CatDress.isWalking(model: Instance): boolean
	return model:GetAttribute("Pose") ~= "sit" and string.find(model.Name, "_Sit", 1, true) == nil
end

-- The assets to try for `piece`, in order: on a walking body its walking cut and then the plain piece (the cut is
-- missing for the pieces whose walking slot sits where the seated one does), on a seated body the plain piece.
function CatDress.assetNames(piece: string, walking: boolean): { string }
	local plain = Catalog.accessoryModelName(piece)
	return if walking then { plain .. "_Walk", plain } else { plain }
end

-- Takes one of the cat's own props off: its object Models (a Head prop's nest in the Head) and their _Glass twins.
local function takeOff(model: Model, prop: string)
	local tails = { "_" .. prop, "_" .. prop .. "_Glass" }
	for _, descendant in model:GetDescendants() do
		if not descendant:IsDescendantOf(model) then
			continue -- inside a prop already taken off
		end
		for _, tail in tails do
			if descendant.Name:sub(-#tail) == tail then
				descendant:Destroy()
				break
			end
		end
	end
end

-- Puts `role`'s outfit on a cat (CatDress.plan), each piece a copy from `clone(assetName)` (nil while that asset is
-- missing), its walking cut on a walking body (CatDress.assetNames). A piece is skipped while its assets or the cat's
-- Outfit_<Piece> slot are missing, so new pieces and new cats can land in either order. Returns how many went on.
function CatDress.dress(model: Model, role: string, clone: (assetName: string) -> Model?): number
	local propSlot = model:GetAttribute("PropSlot")
	local propSlot2 = model:GetAttribute("PropSlot2")
	local pieces, offProp = CatDress.plan(
		role,
		if type(propSlot) == "string" then propSlot else nil,
		if type(propSlot2) == "string" then propSlot2 else nil
	)
	if offProp ~= nil then
		takeOff(model, offProp)
	end
	local scale = CatDress.scaleOf(model)
	local head = objectModel(model, "Head")
	local walking = CatDress.isWalking(model)
	local worn = 0
	for _, piece in pieces do
		local slot = model:FindFirstChild("Outfit_" .. piece, true)
		if slot == nil or not slot:IsA("Attachment") then
			continue
		end
		local accessory: Model? = nil
		for _, name in CatDress.assetNames(piece, walking) do
			accessory = clone(name)
			if accessory ~= nil then
				break
			end
		end
		if accessory == nil then
			continue
		end
		if scale ~= 1 then
			accessory:ScaleTo(scale)
		end
		accessory:PivotTo((slot :: Attachment).WorldCFrame)
		local follows = if head ~= nil and slot:IsDescendantOf(head) then "Head" else "Body"
		for _, descendant in accessory:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part:SetAttribute("Follows", follows)
			end
		end
		accessory.Parent = model
		worn += 1
	end
	return worn
end

return CatDress
