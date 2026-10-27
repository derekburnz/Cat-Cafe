--!strict
-- A working cat sits at its station in its role's outfit (features.md F25, data-model section 5; Derek 2026-10-27:
-- outfits by role, A walks and B sits). CafeService clones the seated body (AssetRegistry.cloneCat with sitting) with
-- its pivot on the station point; resting cats at the odd nap spots sit on it too, with nothing on.
--
-- Outfit pieces go on the seated cat's Outfit_<Piece> Attachments (manifest sit_slots), which ride the Body or the
-- Head, so the asset thread can move a slot without a code change. Each piece's parts get Follows = "Body" or
-- "Head", which the client's idles (Effects/Pose) read.
--
-- Roblox terms: an Attachment is a named point and rotation inside a part; its WorldCFrame follows the part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.AssetRegistry)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local CatPose = {}

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

function CatPose.scaleOf(model: Model): number
	local scale = model:GetAttribute("Scale")
	return if type(scale) == "number" and scale > 0 then scale else 1
end

-- Puts `role`'s outfit on a seated cat. A piece is skipped while its asset or the cat's Outfit_<Piece> slot is
-- missing, so new pieces and new cats can land in either order, and when it sits where the cat's own prop does
-- (the model's PropSlot attribute). Returns how many pieces went on.
function CatPose.dress(model: Model, role: string): number
	local pieces = Catalog.roleOutfits[role]
	if pieces == nil then
		return 0
	end
	local scale = CatPose.scaleOf(model)
	local head = objectModel(model, "Head")
	local propSlot = model:GetAttribute("PropSlot")
	local worn = 0
	for _, piece in pieces do
		if propSlot ~= nil and Catalog.outfitPieceSlots[piece] == propSlot then
			continue
		end
		local slot = model:FindFirstChild("Outfit_" .. piece, true)
		local assetName = Catalog.accessoryModelName(piece)
		if slot ~= nil and slot:IsA("Attachment") and AssetRegistry.has(assetName) then
			local accessory = AssetRegistry.clone(assetName)
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
	end
	return worn
end

return CatPose
