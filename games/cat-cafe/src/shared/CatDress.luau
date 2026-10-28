--!strict
-- A working cat's outfit (features.md F25, data-model section 5; Derek 2026-10-27: outfits by role), shared so the
-- server's working cats (World/CatPose) and the intro's seated waiter (IntroController, F72) dress the same way.
--
-- Outfit pieces go on the seated cat's Outfit_<Piece> Attachments (manifest sit_slots), which ride the Body or the
-- Head, so the asset thread can move a slot without a code change. Each piece's parts get Follows = "Body" or
-- "Head", which the client's idles (Effects/Pose) read.
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

-- Puts `role`'s outfit on a seated cat, each piece a copy from `clone(assetName)` (nil while that asset is
-- missing). A piece is skipped while its asset or the cat's Outfit_<Piece> slot is missing, so new pieces and new
-- cats can land in either order, and when it sits where the cat's own prop does (the model's PropSlot attribute).
-- Returns how many pieces went on.
function CatDress.dress(model: Model, role: string, clone: (assetName: string) -> Model?): number
	local pieces = Catalog.roleOutfits[role]
	if pieces == nil then
		return 0
	end
	local scale = CatDress.scaleOf(model)
	local head = objectModel(model, "Head")
	local propSlot = model:GetAttribute("PropSlot")
	local worn = 0
	for _, piece in pieces do
		if propSlot ~= nil and Catalog.outfitPieceSlots[piece] == propSlot then
			continue
		end
		local slot = model:FindFirstChild("Outfit_" .. piece, true)
		if slot == nil or not slot:IsA("Attachment") then
			continue
		end
		local accessory = clone(Catalog.accessoryModelName(piece))
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
