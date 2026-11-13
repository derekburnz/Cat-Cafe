--!strict
-- #3535 (Derek 2026-11-12: "the new featured item speed shoes that give increased speed while carrying cat for 500
-- base price ... you decide how much to boost speed"): the Speed Shoes, a Mystery Market item (Catalog.mysteryItems
-- row ID) bought once with golden fish. They add Config.SpeedShoesCarryBonus walk speed while carrying a cat, and
-- only then: never on the normal walk, the catch rush or a Startled slow. One cat or two in the Backpack, the same
-- bonus. Derek ("dont put a flat cap let it stac", then "limit on carrying speeds"): no flat cap and everything
-- stacks, but the shoes never take a carry to the player's own walk speed with no cat: the carry is
-- max(base carry, min(base carry + bonus, own walk - 1)), counting the player's other boosts on both sides. The
-- limit only trims the shoes' own bonus and never slows anyone.
-- The live switch FLAG starts off (LiveFlags.OFF_BY_DEFAULT): off hides the shelf row, refuses a buy and drops the
-- bonus at the next speed set; an owned pair is kept. It goes on only once no server older than the publish that
-- added the row is running, since an older server's save check drops a Mystery Market id it does not know. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local SpeedShoes = {}

SpeedShoes.ID = "speed_shoes"
SpeedShoes.FLAG = "speedShoes" -- the LiveFlags key

function SpeedShoes.owns(profile: Types.PlayerProfile?): boolean
	return profile ~= nil and profile.mystery[SpeedShoes.ID] == true
end

-- The carry walk speed for `profile`: `baseCarry` is the carry speed without the shoes and `walk` the player's own
-- walk speed with no cat, both with the same boosts counted (Swift Paws; the Swift Potion is added on top of either
-- by the caller, so it cancels out). Without the shoes, or while the switch is off, `baseCarry` as it is.
function SpeedShoes.carry(
	baseCarry: number,
	walk: number,
	profile: Types.PlayerProfile?,
	on: boolean
): number
	if not on or not SpeedShoes.owns(profile) then
		return baseCarry
	end
	return math.max(baseCarry, math.min(baseCarry + Config.SpeedShoesCarryBonus, walk - 1))
end

-- #4050 (Derek 2026-11-13: "shoes on character are not showing"): the owner wears the pair from the shelf model
-- (ASSET's _Left and _Right models), one on each foot, scaled to the foot and welded to it, in a Folder named WORN.
-- The server does it, so every player sees them; the character's SpeedShoes attribute says they are on.
SpeedShoes.ASSET = "CatCafe_Item_SpeedShoes"
SpeedShoes.WORN = "SpeedShoesWorn"
SpeedShoes.FIT = 1.1 -- the shoe's width and length over the foot's
local SIDES = { { "Left", "LeftFoot", "Left Leg" }, { "Right", "RightFoot", "Right Leg" } }

-- Puts the pair from `asset` (a clone of ASSET, used up) on `character`'s feet: R15 feet, else the bottom of R6 legs.
-- Returns the Folder, not parented, or nil when no foot or shoe was found. Each shoe's toe is its model's -Z, as the
-- foot's front.
function SpeedShoes.wear(asset: Model, character: Model): Folder?
	local folder = Instance.new("Folder")
	folder.Name = SpeedShoes.WORN
	local worn = 0
	for _, side in SIDES do
		local shoe = asset:FindFirstChild(asset.Name .. "_" .. side[1])
		local foot = character:FindFirstChild(side[2]) or character:FindFirstChild(side[3])
		if shoe == nil or not shoe:IsA("Model") or foot == nil or not foot:IsA("BasePart") then
			continue
		end
		local model = shoe :: Model
		local part = foot :: BasePart
		local _, size = model:GetBoundingBox()
		if size.X <= 0 or size.Z <= 0 then
			continue
		end
		local scale = math.clamp(
			math.max(part.Size.X * SpeedShoes.FIT / size.X, part.Size.Z * SpeedShoes.FIT / size.Z),
			0.25,
			2
		)
		model:ScaleTo(model:GetScale() * scale)
		local box, grown = model:GetBoundingBox()
		-- the box's bottom centre goes on the foot's sole
		local sole = box * CFrame.new(0, -grown.Y / 2, 0)
		local fromSole = model:GetPivot():ToObjectSpace(sole)
		model:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0) * fromSole:Inverse())
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				local piece = descendant :: BasePart
				piece.Anchored = false
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
				piece.Massless = true
				piece.CastShadow = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = piece
				weld.Parent = piece
			end
		end
		model:SetAttribute("Foot", part.Name)
		model.Parent = folder
		worn += 1
	end
	asset:Destroy()
	if worn == 0 then
		folder:Destroy()
		return nil
	end
	return folder
end

-- Whether `folder` (a WORN Folder in `character`) still sits on the character's own feet: false once the avatar's
-- appearance has rebuilt a foot it was welded to.
function SpeedShoes.onFeet(folder: Instance, character: Model): boolean
	local any = false
	for _, shoe in folder:GetChildren() do
		local footName = shoe:GetAttribute("Foot")
		local foot = if type(footName) == "string" then character:FindFirstChild(footName) else nil
		local piece = if shoe:IsA("Model") then shoe:FindFirstChildWhichIsA("BasePart") else nil
		local weld = if piece ~= nil then piece:FindFirstChildOfClass("WeldConstraint") else nil
		if foot == nil or weld == nil or weld.Part0 ~= foot then
			return false
		end
		any = true
	end
	return any
end

return SpeedShoes
