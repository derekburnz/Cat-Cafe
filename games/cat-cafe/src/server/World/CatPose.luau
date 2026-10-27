--!strict
-- A working cat stands upright at its station in its role's outfit (features.md F25, data-model section 5; Derek
-- 2026-10-27: outfits by role). Cats in the cat room stay on all fours with nothing on.
--
-- The pose is assets/cat-cafe/exports/manifest.json `poses.upright` in Roblox axes: a CFrame for the body relative
-- to the station point, then a turn for the Head and the Tail about their joints (the exporter's Head and Tail are
-- Models pivoted at the joint), with every position times the cat's Scale. Outfit pieces go on the cat's
-- Outfit_<Piece> Attachments, which ride the Body or the Head, so the asset thread can move a slot without a code
-- change. Each piece's parts get Follows = "Body" or "Head", which the client's idles (Effects/Pose) read.
--
-- Roblox terms: an Attachment is a named point and rotation inside a part; its WorldCFrame follows the part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.AssetRegistry)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local CatPose = {}

-- manifest poses.upright, for a cat of Scale 1
local BODY = CFrame.new(0, 0.8, -0.72, 1, 0, 0, 0, 0, -1, 0, 1, 0) -- body_cframe_roblox
local HEAD_OFFSET = Vector3.new(0, 0, -0.32) -- head_offset_roblox, in the body's own frame
local HEAD_TURN = CFrame.Angles(math.rad(-90), 0, 0) -- head_angles_roblox_deg
local TAIL_TURN = CFrame.Angles(math.rad(-80), 0, 0) -- tail_angles_roblox_deg

local function scaled(frame: CFrame, scale: number): CFrame
	return frame.Rotation + frame.Position * scale
end

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

-- Stands the cat up with its pivot on `station`. A cat with no Head or Tail object is only placed.
function CatPose.upright(model: Model, station: CFrame)
	local scale = CatPose.scaleOf(model)
	local rest = model:GetPivot()
	local head = objectModel(model, "Head")
	if head ~= nil then
		local joint = rest:ToObjectSpace(head:GetPivot())
		head:PivotTo(rest * CFrame.new(HEAD_OFFSET * scale) * joint * HEAD_TURN)
	end
	local tail = objectModel(model, "Tail")
	if tail ~= nil then
		tail:PivotTo(tail:GetPivot() * TAIL_TURN)
	end
	model:PivotTo(station * scaled(BODY, scale))
	model:SetAttribute("Pose", "upright")
end

-- Puts `role`'s outfit on a posed cat. A piece is skipped while its asset or the cat's Outfit_<Piece> slot is
-- missing, so new pieces and new cats can land in either order. Returns how many pieces went on.
function CatPose.dress(model: Model, role: string): number
	local pieces = Catalog.roleOutfits[role]
	if pieces == nil then
		return 0
	end
	local scale = CatPose.scaleOf(model)
	local head = objectModel(model, "Head")
	local worn = 0
	for _, piece in pieces do
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
