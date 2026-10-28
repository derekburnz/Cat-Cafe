--!strict
-- The cafe back doors (Model-Agent #509; Derek 2026-10-28 01:28: players walk through the door, cats use the flap).
-- WorldBuilder puts CatCafe_Plot_BackDoor in every plot, tagged CafeBackDoor, with nothing on it solid. On this
-- client, while the areas are open and on an owned cafe, its _Leaf swings out into the yard while any player is
-- within BackDoor.OPEN_RANGE of the doorway and shuts when they have gone, and its _Flap swings as a cat goes through
-- (shared/BackDoor has the rules). While the areas are closed the leaf stays shut, the CLOSED UNTIL SUNRISE sign
-- shows (its bulbs glow with the other night bulbs, WorldController) and an owned cafe's back door panel turns
-- solid, as the closed back door art did. An F80 door set in use (the plot's Door attribute) stands in the doorway
-- instead, so the art hides; an F80 cat flap in use (CatFlap) hides the default flap (and its _FlapFrame) and rides
-- the leaf. Only this client's copy moves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BackDoor = require(ReplicatedStorage.Shared.BackDoor)

local DoorController = {}

local ART = "CatCafe_Plot_BackDoor"
local ACTIVE_RANGE = 160 -- studs from the camera within which a door moves
local SENSE_SECONDS = 0.1 -- how often the players near a doorway and the cats near a flap are looked for
local STATE_SECONDS = 0.25 -- how often the owner, the clock, the door set and the cat flap in use are read
local NEAR_HEIGHT = 10 -- a player more than this above or below the doorway (on a roof) does not open it
local FLAP_SHUT_DEGREES = 5 -- the flap only meets cats while the leaf is about shut

type Door = {
	art: Model,
	plot: Instance,
	leaf: Model,
	leafShut: CFrame, -- the leaf's pivot as built: shut
	flap: Model?,
	flapFrame: Model?, -- the default flap's surround and hood, when the art has it apart: hidden with the flap
	flapRest: CFrame, -- the flap's pivot in the leaf's space, at rest
	catFlapRest: CFrame?, -- the leaf's CatFlap attachment in the leaf's space, where the server puts an F80 flap
	decorFlap: Model?, -- the F80 cat flap riding the leaf
	sign: { BasePart }, -- the sign's plate; its bulbs are WorldController's
	bulbs: Instance?, -- the sign's _Sign_Bulb model
	dimmed: { [Light]: boolean }, -- bulb lights put out while the door is hidden
	angle: number,
	flapAngle: number,
	flapSpeed: number,
	shownAngle: number, -- the leaf and flap as last put on the art, so a door at rest is left alone
	shownFlap: number,
	push: number?, -- a cat at the flap: BackDoor.pushFrom
	wantsOpen: boolean,
	active: boolean,
	owned: boolean,
	replaced: boolean,
	hidden: boolean,
	flapHidden: boolean,
	signShown: boolean?,
}

local doors: { [Model]: Door } = {}

local function areasOpen(): boolean
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	return clock == nil or clock:GetAttribute("AreasOpen") ~= false
end

-- The plot's back door panel (WorldBuilder: Walls/BackDoor), the doorway and the collider.
local function panelOf(door: Door): BasePart?
	local walls = door.plot:FindFirstChild("Walls")
	local panel = if walls ~= nil then walls:FindFirstChild("BackDoor") else nil
	return if panel ~= nil and panel:IsA("BasePart") then panel :: BasePart else nil
end

-- The F80 cat flap model in use on the plot, if any.
local function decorFlapOf(door: Door): Model?
	if door.plot:GetAttribute("CatFlap") == nil then
		return nil
	end
	local decor = door.plot:FindFirstChild("Decor")
	local flap = if decor ~= nil then decor:FindFirstChild("CatFlap") else nil
	return if flap ~= nil and flap:IsA("Model") then flap :: Model else nil
end

local function setHidden(model: Instance, hidden: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function setSignShown(door: Door, shown: boolean)
	if door.signShown == shown then
		return
	end
	door.signShown = shown
	for _, piece in door.sign do
		local look = piece:GetAttribute("NightTransparency")
		piece.Transparency = if shown and type(look) == "number" then look else 1
	end
end

-- Puts the leaf, the flap and an F80 flap where the angles say.
local function show(door: Door)
	if door.angle == door.shownAngle and door.flapAngle == door.shownFlap then
		return
	end
	door.shownAngle = door.angle
	door.shownFlap = door.flapAngle
	local leafAt = door.leafShut * CFrame.Angles(0, math.rad(door.angle), 0)
	door.leaf:PivotTo(leafAt)
	local flap = door.flap
	if flap ~= nil then
		flap:PivotTo(leafAt * door.flapRest * CFrame.Angles(math.rad(door.flapAngle), 0, 0))
	end
	local decorFlap, rest = door.decorFlap, door.catFlapRest
	if decorFlap ~= nil and rest ~= nil then
		decorFlap:PivotTo(leafAt * rest)
	end
end

-- A hidden door's bulbs still turn Neon and get their light at night (WorldController). The Neon hides with the
-- rest, so only the light is put out here, and lit again when the door shows at night (review N251).
local function keepLightsOut(door: Door)
	local bulbs = door.bulbs
	if bulbs == nil then
		return
	end
	if door.hidden then
		for _, descendant in bulbs:GetDescendants() do
			if descendant:IsA("Light") and (descendant :: Light).Enabled then
				(descendant :: Light).Enabled = false
				door.dimmed[descendant :: Light] = true
			end
		end
	elseif next(door.dimmed) ~= nil then
		local clock = ReplicatedStorage:FindFirstChild("Clock")
		local night = clock ~= nil and clock:GetAttribute("Phase") == "night"
		for light in door.dimmed do
			light.Enabled = night
		end
		table.clear(door.dimmed)
	end
end

-- Owner, clock, door set and cat flap in use: the sign, the panel's night collision and what is hidden.
local function readState(door: Door, open: boolean)
	local owner = door.plot:GetAttribute("OwnerUserId")
	door.owned = type(owner) == "number" and owner > 0
	door.replaced = door.plot:GetAttribute("Door") ~= nil
	if door.hidden ~= door.replaced then
		door.hidden = door.replaced
		setHidden(door.art, door.replaced)
		door.flapHidden = door.replaced
	end
	-- the server put the flap at the shut leaf's attachment (CafeService.refreshDoors); with a door set it is on that
	local decorFlap = if door.replaced then nil else decorFlapOf(door)
	if door.decorFlap ~= decorFlap then
		door.decorFlap = decorFlap
		door.shownAngle = math.huge -- carry it with the leaf from the next frame
	end
	local flap = door.flap
	local flapHidden = door.replaced or decorFlap ~= nil
	if flap ~= nil and door.flapHidden ~= flapHidden then
		door.flapHidden = flapHidden
		setHidden(flap, flapHidden)
		-- an F80 flap brings its own frame (Model-Agent, F80)
		local frame = door.flapFrame
		if frame ~= nil then
			setHidden(frame, flapHidden)
		end
	end
	setSignShown(door, not open)
	keepLightsOut(door)
	-- the closed back door art used to block an owned cafe's back door at night; an empty plot's panel is shut anyway
	local panel = panelOf(door)
	if panel ~= nil and door.owned and panel.CanCollide == open then
		panel.CanCollide = not open
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- The nearest player's character to the doorway, in studs across the ground, or nil with none close in height.
local function nearestPlayer(doorway: Vector3): number?
	local best: number? = nil
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root ~= nil then
			local offset = root.Position - doorway
			if math.abs(offset.Y) <= NEAR_HEIGHT then
				local across = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if best == nil or across < best then
					best = across
				end
			end
		end
	end
	return best
end

-- Which way a cat at the flap pushes it (BackDoor.pushFrom), or nil with none within FLAP_RANGE: the strays and the
-- plot's own cats.
local function catPush(door: Door, panel: BasePart): number?
	local flap = door.flap
	if flap == nil then
		return nil
	end
	local hinge = (door.leafShut * door.flapRest).Position
	local function near(model: Instance): number?
		if not model:IsA("Model") then
			return nil
		end
		local at = (model :: Model):GetPivot().Position
		if Vector3.new(at.X - hinge.X, 0, at.Z - hinge.Z).Magnitude > BackDoor.FLAP_RANGE then
			return nil
		end
		return BackDoor.pushFrom(panel.CFrame:PointToObjectSpace(at).Z)
	end
	for _, stray in CollectionService:GetTagged("Stray") do
		local push = near(stray)
		if push ~= nil then
			return push
		end
	end
	local cats = door.plot:FindFirstChild("Cats")
	if cats ~= nil then
		for _, cat in cats:GetChildren() do
			local push = near(cat)
			if push ~= nil then
				return push
			end
		end
	end
	return nil
end

local function sense(door: Door, open: boolean, camera: Vector3?)
	local panel = panelOf(door)
	if panel == nil then
		door.active = false
		return
	end
	local doorway = panel.Position
	door.active = camera == nil or (doorway - camera).Magnitude <= ACTIVE_RANGE
	if not door.active then
		door.wantsOpen = false
		door.push = nil
		return
	end
	door.wantsOpen = BackDoor.wantsOpen(open, door.owned, door.replaced, nearestPlayer(doorway))
	door.push = if not door.flapHidden and math.abs(door.angle) < FLAP_SHUT_DEGREES
		then catPush(door, panel)
		else nil
end

local function step(door: Door, dt: number)
	if not door.active or door.hidden then
		return
	end
	door.angle =
		BackDoor.stepLeaf(door.angle, if door.wantsOpen then BackDoor.OPEN_DEGREES else 0, dt)
	if door.flap ~= nil and not door.flapHidden then
		door.flapAngle, door.flapSpeed =
			BackDoor.stepFlap(door.flapAngle, door.flapSpeed, door.push, dt)
	else
		door.flapAngle, door.flapSpeed = 0, 0
	end
	show(door)
end

local function register(instance: Instance)
	if not instance:IsA("Model") or doors[instance :: Model] ~= nil then
		return
	end
	local art = instance :: Model
	local plot = art.Parent
	local leaf = art:FindFirstChild(ART .. "_Leaf")
	if plot == nil or leaf == nil or not leaf:IsA("Model") then
		-- not all in yet: try again as the rest arrives
		local connection: RBXScriptConnection? = nil
		connection = art.ChildAdded:Connect(function()
			if art:FindFirstChild(ART .. "_Leaf") ~= nil and connection ~= nil then
				connection:Disconnect()
				register(art)
			end
		end)
		return
	end
	local leafModel = leaf :: Model
	local leafShut = leafModel:GetPivot()
	local attachment = leafModel:FindFirstChild("CatFlap", true)
	local flapFound = leafModel:FindFirstChild(ART .. "_Flap")
	local flap = if flapFound ~= nil and flapFound:IsA("Model") then flapFound :: Model else nil
	local frameFound = leafModel:FindFirstChild(ART .. "_FlapFrame")
	local sign: { BasePart } = {}
	local signModel = leafModel:FindFirstChild(ART .. "_Sign")
	if signModel ~= nil then
		for _, descendant in signModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(sign, descendant :: BasePart)
			end
		end
	end
	local door: Door = {
		art = art,
		plot = plot,
		leaf = leafModel,
		leafShut = leafShut,
		flap = flap,
		flapFrame = if frameFound ~= nil and frameFound:IsA("Model")
			then frameFound :: Model
			else nil,
		flapRest = if flap ~= nil then leafShut:Inverse() * flap:GetPivot() else CFrame.identity,
		catFlapRest = if attachment ~= nil and attachment:IsA("Attachment")
			then leafShut:Inverse() * (attachment :: Attachment).WorldCFrame
			else nil,
		decorFlap = nil,
		sign = sign,
		bulbs = leafModel:FindFirstChild(ART .. "_Sign_Bulb"),
		dimmed = {},
		angle = 0,
		flapAngle = 0,
		flapSpeed = 0,
		shownAngle = 0,
		shownFlap = 0,
		push = nil,
		wantsOpen = false,
		active = false,
		owned = false,
		replaced = false,
		hidden = false,
		flapHidden = false,
		signShown = nil,
	}
	doors[art] = door
	readState(door, areasOpen())
end

function DoorController.start()
	for _, art in CollectionService:GetTagged("CafeBackDoor") do
		register(art)
	end
	CollectionService:GetInstanceAddedSignal("CafeBackDoor"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("CafeBackDoor"):Connect(function(instance)
		if instance:IsA("Model") then
			doors[instance :: Model] = nil
		end
	end)

	local senseIn, stateIn = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		senseIn -= dt
		stateIn -= dt
		local readNow, senseNow = stateIn <= 0, senseIn <= 0
		if readNow then
			stateIn = STATE_SECONDS
		end
		if senseNow then
			senseIn = SENSE_SECONDS
		end
		local open = areasOpen()
		local camera = Workspace.CurrentCamera
		local cameraAt = if camera ~= nil then camera.CFrame.Position else nil
		for _, door in doors do
			if readNow then
				readState(door, open)
			end
			if senseNow then
				sense(door, open, cameraAt)
			end
			step(door, dt)
		end
	end)
end

return DoorController
