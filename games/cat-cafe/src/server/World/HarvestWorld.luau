--!strict
-- #4251 Harvest Hollow, the world (harvest-hollow-spec sections 1 and 2). Model-Agent's set and pieces (#4381), placed
-- from the set's manifest points (assets/cat-cafe/exports/manifest.json, CatCafe_Harvest_Set points_roblox), far from
-- every other area. The area is fenced all round, so the only way in is the Travel "harvest" trip (TravelService):
-- walking through the arch in the Town Square or the HUD's Harvest button.
--   buildArch(parent)   the arch in the Town Square, tagged HarvestArch, with an invisible HarvestArchTouch part in its
--                       opening. It stays after the area closes, as decor (spec section 7).
--   buildArea(parent)   the set, the Harvest Stall (tagged HarvestStall, with the ProximityPrompt HarvestStallPrompt
--                       the client opens the Stall window from), the Thankful Board (HarvestBoard, with
--                       HarvestBoardPrompt for the note picker), the 12
--                       patch pumpkins (HarvestPumpkin, each with an invisible Touch part) and the arrival pad
--                       (HarvestArrival) at the player spawn. HarvestService watches those tags.
--   landing()           where a trip in lands: the player spawn, facing the patch.
--   spawns / nook       the 14 stray spots and the maze's middle, in world space, for the harvest cats (part 3).
-- Built once a server: HarvestService builds the area at start when it is due within AREA_EARLY_SECONDS, else on a
-- timer, and never after the area has closed.

local CollectionService = game:GetService("CollectionService")

local AssetRegistry = require(script.Parent.AssetRegistry)

local HarvestWorld = {}

HarvestWorld.SET = "CatCafe_Harvest_Set"
HarvestWorld.ARCH = "CatCafe_Harvest_Arch"
HarvestWorld.STALL = "CatCafe_Harvest_Stall"
HarvestWorld.BOARD = "CatCafe_Harvest_Board"
HarvestWorld.PUMPKIN = "CatCafe_Harvest_Pumpkin"

HarvestWorld.ARCH_TAG = "HarvestArch"
HarvestWorld.ARCH_TOUCH_TAG = "HarvestArchTouch"
HarvestWorld.STALL_TAG = "HarvestStall"
HarvestWorld.BOARD_TAG = "HarvestBoard"
HarvestWorld.PUMPKIN_TAG = "HarvestPumpkin"
HarvestWorld.ARRIVAL_TAG = "HarvestArrival"

-- The set's centre on its floor: south-west of the Alley, clear of every area (the Water Park mirrors it at +2400).
HarvestWorld.CENTER = Vector3.new(-2400, 0, -2400)
-- The arch in the Town Square's north-west quarter, facing the cannon (Model-Agent's world scan on #4397): 2 studs or
-- more clear all round, with a 12 wide path from the opening to the cannon between the Arcade Cabinet's ring and the
-- Spin Wheel's. (-46, 30) had the Arcade Cabinet 6.5 studs in front of the opening.
HarvestWorld.ARCH_AT = Vector3.new(-42, 0.1, 38)
HarvestWorld.AREA_EARLY_SECONDS = 3600 -- built this long before it opens, so the first trip never waits on it
HarvestWorld.ARCH_EARLY_SECONDS = 86400 -- the arch and its countdown from a day before (the update countdown's 24 hours)

-- CatCafe_Harvest_Set points_roblox (set space, front -Z, no turn): x, y, z. player_spawn, stall and board carry a
-- fourth value, their turn, and it is 0 for all three, so the Stall and Board stand unturned (front -Z, toward the
-- spawn).
local POINTS = {
	playerSpawn = Vector3.new(0, 0, -55.2),
	stall = Vector3.new(24, 0, 14),
	board = Vector3.new(0, 0, 16),
	nook = Vector3.new(-47.75, 0, 30),
	spawns = {
		Vector3.new(56, 0, -35),
		Vector3.new(44, 0, -29),
		Vector3.new(36, 0, -17),
		Vector3.new(-36, 0, -27),
		Vector3.new(-56, 0, -27),
		Vector3.new(-66, 0, -13),
		Vector3.new(54, 0, 28),
		Vector3.new(40, 0, 32),
		Vector3.new(-30.25, 0, 44),
		Vector3.new(-33.75, 0, 16),
		Vector3.new(-61.75, 0, 44),
		Vector3.new(20, 0, -36),
		Vector3.new(22, 0, 40),
		Vector3.new(-16, 0, 30),
	},
	pumpkins = {
		Vector3.new(61, 0.29, -32),
		Vector3.new(51, 0.29, -32),
		Vector3.new(41, 0.29, -32),
		Vector3.new(31, 0.29, -32),
		Vector3.new(61, 0.29, -26),
		Vector3.new(51, 0.29, -26),
		Vector3.new(41, 0.29, -26),
		Vector3.new(31, 0.29, -26),
		Vector3.new(61, 0.29, -20),
		Vector3.new(51, 0.29, -20),
		Vector3.new(41, 0.29, -20),
		Vector3.new(31, 0.29, -20),
	},
}

local function world(point: Vector3): Vector3
	return HarvestWorld.CENTER + point
end

HarvestWorld.spawns = table.freeze((function()
	local out = {}
	for _, point in POINTS.spawns do
		table.insert(out, world(point))
	end
	return out
end)() :: { Vector3 })
HarvestWorld.nook = world(POINTS.nook)
HarvestWorld.pumpkinCount = #POINTS.pumpkins

-- Where a trip in lands: just over the player spawn (landingPoint, pure for the specs), facing the patch (+Z, into
-- the area).
function HarvestWorld.landingPoint(): Vector3
	return world(POINTS.playerSpawn) + Vector3.new(0, 3, 0)
end

function HarvestWorld.landing(): CFrame
	return CFrame.new(HarvestWorld.landingPoint()) * CFrame.Angles(0, math.pi, 0) -- LookVector (0, 0, 1)
end

-- Whether a point is inside the set's fence (150 x 120, a stud of slack).
function HarvestWorld.inArea(position: Vector3): boolean
	local offset = position - HarvestWorld.CENTER
	return math.abs(offset.X) <= 76
		and math.abs(offset.Z) <= 61
		and offset.Y > -10
		and offset.Y < 60
end

local function invisible(name: string, size: Vector3, cframe: CFrame, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = true
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- A ProximityPrompt (the "press E" / tap button Roblox shows near an object) the client listens to.
-- It shows on a part, so it goes on the model's PrimaryPart (or its first part).
local function prompt(name: string, action: string, object: string, model: Model)
	local parent: Instance = model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
		or model
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 10
	p.Parent = parent
end

local function place(asset: string, cframe: CFrame, parent: Instance): Model?
	if not AssetRegistry.known(asset) then
		warn(string.format("[HarvestWorld] %s is not in the assets", asset))
		return nil
	end
	local model = AssetRegistry.clone(asset)
	model:PivotTo(cframe)
	model.Parent = parent
	return model
end

-- The arch in the Town Square, facing the cannon at the origin, with its touch part across the opening.
function HarvestWorld.buildArch(parent: Instance): Model?
	local at = HarvestWorld.ARCH_AT
	-- turned so its front (-Z, LookVector (-sin r, 0, -cos r)) faces the origin
	local cframe = CFrame.new(at) * CFrame.Angles(0, math.atan2(at.X, at.Z), 0)
	local arch = place(HarvestWorld.ARCH, cframe, parent)
	if arch == nil then
		return nil
	end
	local touch =
		invisible("HarvestArchTouch", Vector3.new(10, 9, 2), cframe * CFrame.new(0, 4.5, 0), arch)
	CollectionService:AddTag(touch, HarvestWorld.ARCH_TOUCH_TAG)
	CollectionService:AddTag(arch, HarvestWorld.ARCH_TAG)
	return arch
end

-- The area: the set, its Stall, Board and pumpkins, and the arrival pad. Returns the folder it built into.
function HarvestWorld.buildArea(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "HarvestHollow"
	place(HarvestWorld.SET, CFrame.new(HarvestWorld.CENTER), folder)
	local stall = place(HarvestWorld.STALL, CFrame.new(world(POINTS.stall)), folder)
	if stall ~= nil then
		prompt("HarvestStallPrompt", "Shop", "Harvest Stall", stall)
		CollectionService:AddTag(stall, HarvestWorld.STALL_TAG)
	end
	local board = place(HarvestWorld.BOARD, CFrame.new(world(POINTS.board)), folder)
	if board ~= nil then
		prompt("HarvestBoardPrompt", "Pin a note", "Thankful Board", board)
		CollectionService:AddTag(board, HarvestWorld.BOARD_TAG)
	end
	for index, point in POINTS.pumpkins do
		local pumpkin = place(HarvestWorld.PUMPKIN, CFrame.new(world(point)), folder)
		if pumpkin ~= nil then
			pumpkin.Name = string.format("HarvestPumpkin%02d", index)
			-- the pumpkin's own parts take no touches, so a touch box over it does
			invisible(
				"Touch",
				Vector3.new(4, 4, 4),
				CFrame.new(world(point) + Vector3.new(0, 1.5, 0)),
				pumpkin
			)
			CollectionService:AddTag(pumpkin, HarvestWorld.PUMPKIN_TAG)
		end
	end
	local arrival = invisible(
		"HarvestArrival",
		Vector3.new(14, 6, 10),
		CFrame.new(world(POINTS.playerSpawn) + Vector3.new(0, 3, 0)),
		folder
	)
	CollectionService:AddTag(arrival, HarvestWorld.ARRIVAL_TAG)
	folder.Parent = parent
	return folder
end

return HarvestWorld
