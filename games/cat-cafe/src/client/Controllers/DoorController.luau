--!strict
-- The cafe back doors (Model-Agent #509; Derek 2026-10-28 01:28: players walk through the door, cats use the flap).
-- WorldBuilder puts CatCafe_Plot_BackDoor in every plot, tagged CafeBackDoor, with nothing on it solid. On this
-- client, while the areas are open and on an owned cafe, its _Leaf swings out into the yard while any player is
-- within BackDoor.OPEN_RANGE of the doorway and shuts when they have gone, and its _Flap swings as a cat goes through
-- (shared/BackDoor has the rules). While the areas are closed the leaf stays shut, the CLOSED UNTIL SUNRISE sign
-- shows (its bulbs glow with the other night bulbs, WorldController) and an owned cafe's back door panel turns
-- solid, as the closed back door art did.
-- An F80 door set in use (the plot's Door attribute) hides the art, and its own models, which CafeService puts in the
-- plot's Decor, move instead: DoorBack's _Leaf swings and shows its sign as the art's did, and DoorFront's _LeafL and
-- _LeafR stand open into the cafe while the areas are open and shut while they are closed. Decor.CatFlap (the F80 cat
-- flap in use, or the plain one a door set brings) rides the leaf in use from its CatFlap attachment, hides the art's
-- own flap (and its _FlapFrame) and swings its _Flap for cats in that flap's place. Only this client's copy moves.

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

type Leaf = {
	model: Model,
	shut: CFrame, -- its pivot as built: shut
	catFlapRest: CFrame?, -- its CatFlap attachment in its own space, where the server puts Decor.CatFlap
	sign: { BasePart }, -- its sign's plate; the bulbs are WorldController's
}

type Swing = {
	model: Model, -- a flap that swings for cats: the art's _Flap or Decor.CatFlap's
	rest: CFrame, -- its pivot at rest in the space of what carries it: the leaf, or Decor.CatFlap
	axis: Vector3, -- its hinge in its own space: a positive turn about it swings the flap into the cafe
}

type FrontLeaf = {
	model: Model,
	shut: CFrame,
	turn: number, -- BackDoor.frontTurn
}

type Door = {
	art: Model,
	plot: Instance,
	own: Leaf, -- the art's leaf
	ownFlap: Swing?, -- the art's flap
	flapFrame: Model?, -- the art flap's surround and hood, when the art has it apart: hidden with the flap
	leaf: Leaf?, -- the leaf in use: the art's, a door set's back leaf once it is in, or none
	leafFrom: Model?, -- what `leaf` was taken from: the art or the door set's DoorBack
	front: Model?, -- the door set's DoorFront
	frontLeaves: { FrontLeaf },
	frontAngle: number, -- 0 shut to FRONT_OPEN_DEGREES
	shownFront: number,
	decorFlap: Model?, -- Decor.CatFlap riding the leaf in use
	decorSwing: Swing?, -- its _Flap, as first seen from swingFrom
	swingFrom: Model?,
	flapSwings: boolean, -- a flap hangs in the leaf in use: the art's or decorFlap's
	bulbs: Instance?, -- the art sign's _Sign_Bulb model
	dimmed: { [Light]: boolean }, -- bulb lights put out while the art is hidden
	angle: number,
	flapAngle: number,
	flapSpeed: number,
	shownAngle: number, -- the leaf and flap as last put on the art, so a door at rest is left alone
	shownFlap: number,
	push: number?, -- a cat at the flap: BackDoor.pushFrom
	wantsOpen: boolean,
	active: boolean,
	owned: boolean,
	hidden: boolean, -- the art hidden behind a door set
	ownFlapHidden: boolean,
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

local function childModel(parent: Instance?, name: string): Model?
	local found = if parent ~= nil then parent:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found :: Model else nil
end

-- The child model of `parent` whose name ends in `suffix`: the art's and the F80 models' parts carry their name.
local function partNamed(parent: Instance, suffix: string): Model?
	for _, child in parent:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-#suffix) == suffix then
			return child :: Model
		end
	end
	return nil
end

-- A leaf as it stands now, shut: its CatFlap attachment and its _Sign plate's parts.
local function leafOf(model: Model): Leaf
	local shut = model:GetPivot()
	local attachment = model:FindFirstChild("CatFlap", true)
	local sign: { BasePart } = {}
	local plate = partNamed(model, "_Sign")
	if plate ~= nil then
		for _, descendant in plate:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(sign, descendant :: BasePart)
			end
		end
	end
	return {
		model = model,
		shut = shut,
		catFlapRest = if attachment ~= nil and attachment:IsA("Attachment")
			then shut:Inverse() * (attachment :: Attachment).WorldCFrame
			else nil,
		sign = sign,
	}
end

-- A flap at rest, carried by a model now at `carrier`, swinging into the cafe about the world direction `intoCafe`.
local function swingOf(model: Model, carrier: CFrame, intoCafe: Vector3): Swing
	local at = model:GetPivot()
	return { model = model, rest = carrier:Inverse() * at, axis = at:VectorToObjectSpace(intoCafe) }
end

local function setHidden(model: Instance, hidden: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function setSignShown(door: Door, leaf: Leaf, shown: boolean)
	if door.signShown == shown then
		return
	end
	door.signShown = shown
	for _, piece in leaf.sign do
		local look = piece:GetAttribute("NightTransparency")
		piece.Transparency = if shown and type(look) == "number" then look else 1
	end
end

-- Puts the leaf in use, its flap and Decor.CatFlap where the angles say.
local function show(door: Door)
	local leaf = door.leaf
	if leaf == nil or (door.angle == door.shownAngle and door.flapAngle == door.shownFlap) then
		return
	end
	door.shownAngle = door.angle
	door.shownFlap = door.flapAngle
	local leafAt = leaf.shut * CFrame.Angles(0, math.rad(door.angle), 0)
	leaf.model:PivotTo(leafAt)
	local turn = math.rad(door.flapAngle)
	local own = door.ownFlap
	if own ~= nil and leaf == door.own and not door.ownFlapHidden then
		own.model:PivotTo(leafAt * own.rest * CFrame.fromAxisAngle(own.axis, turn))
	end
	local decorFlap, rest, swing = door.decorFlap, leaf.catFlapRest, door.decorSwing
	if decorFlap ~= nil and rest ~= nil then
		local flapAt = leafAt * rest
		decorFlap:PivotTo(flapAt)
		if swing ~= nil then
			swing.model:PivotTo(flapAt * swing.rest * CFrame.fromAxisAngle(swing.axis, turn))
		end
	end
end

-- Puts the door set's front leaves where frontAngle says.
local function showFront(door: Door)
	if door.frontAngle == door.shownFront then
		return
	end
	door.shownFront = door.frontAngle
	for _, leaf in door.frontLeaves do
		leaf.model:PivotTo(leaf.shut * CFrame.Angles(0, math.rad(leaf.turn * door.frontAngle), 0))
	end
end

-- Where the flap in use hangs from with the leaf shut, or nil with none.
local function flapHinge(door: Door): Vector3?
	local leaf = door.leaf
	if leaf == nil then
		return nil
	end
	local rest, swing = leaf.catFlapRest, door.decorSwing
	if door.decorFlap ~= nil then
		return if rest ~= nil and swing ~= nil
			then (leaf.shut * rest * swing.rest).Position
			else nil
	end
	local own = door.ownFlap
	return if own ~= nil and leaf == door.own then (leaf.shut * own.rest).Position else nil
end

-- The leaf in use: the art's, or with a door set in use its DoorBack's _Leaf (`from`) once that is in.
local function bindLeaf(door: Door, from: Model?)
	if door.leafFrom == from then
		return
	end
	local old = door.leaf
	if old ~= nil and old.model.Parent ~= nil then
		old.model:PivotTo(old.shut) -- the art's leaf waits shut behind a door set
	end
	door.leafFrom = from
	local leaf: Leaf? = nil
	if from == door.art then
		leaf = door.own
	elseif from ~= nil then
		local model = partNamed(from, "_Leaf")
		leaf = if model ~= nil then leafOf(model) else nil
	end
	door.leaf = leaf
	door.angle = 0
	door.flapAngle, door.flapSpeed = 0, 0
	door.shownAngle = math.huge
	door.signShown = nil
end

-- The door set's front leaves (`front`, its DoorFront), standing as the clock says when they come in.
local function bindFront(door: Door, front: Model?, open: boolean)
	if door.front == front then
		return
	end
	door.front = front
	local leaves: { FrontLeaf } = {}
	if front ~= nil then
		for _, child in front:GetChildren() do
			local turn = BackDoor.frontTurn(child.Name)
			if turn ~= nil and child:IsA("Model") then
				local model = child :: Model
				table.insert(leaves, { model = model, shut = model:GetPivot(), turn = turn })
			end
		end
	end
	door.frontLeaves = leaves
	door.shownFront = 0 -- built shut
	door.frontAngle = if open then BackDoor.FRONT_OPEN_DEGREES else 0
	showFront(door)
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

-- Owner, clock, door set and cat flap in use: the leaves and flap in use, the sign, the panel's night collision and
-- what is hidden.
local function readState(door: Door, open: boolean)
	local owner = door.plot:GetAttribute("OwnerUserId")
	door.owned = type(owner) == "number" and owner > 0
	local replaced = door.plot:GetAttribute("Door") ~= nil
	if door.hidden ~= replaced then
		door.hidden = replaced
		setHidden(door.art, replaced)
		door.ownFlapHidden = replaced
	end
	local decor = door.plot:FindFirstChild("Decor")
	bindLeaf(door, if replaced then childModel(decor, "DoorBack") else door.art)
	bindFront(door, if replaced then childModel(decor, "DoorFront") else nil, open)
	-- the server put the flap at the shut leaf's attachment (CafeService.refreshDoors)
	local leaf = door.leaf
	local decorFlap = if leaf ~= nil and leaf.catFlapRest ~= nil
		then childModel(decor, "CatFlap")
		else nil
	if door.decorFlap ~= decorFlap then
		door.decorFlap = decorFlap
		if decorFlap ~= nil and decorFlap ~= door.swingFrom then
			-- first seen as the server put it, at rest; a flap that comes and goes with a door set keeps its rest
			local swingModel = partNamed(decorFlap, "_Flap")
			door.swingFrom = decorFlap
			door.decorSwing = if swingModel ~= nil
				then swingOf(swingModel, decorFlap:GetPivot(), door.own.shut.XVector)
				else nil
		end
		door.shownAngle = math.huge -- carry it with the leaf from the next frame
	end
	local flap = door.ownFlap
	local ownFlapHidden = replaced or decorFlap ~= nil
	if flap ~= nil and door.ownFlapHidden ~= ownFlapHidden then
		door.ownFlapHidden = ownFlapHidden
		setHidden(flap.model, ownFlapHidden)
		-- an F80 flap brings its own frame (Model-Agent, F80)
		local frame = door.flapFrame
		if frame ~= nil then
			setHidden(frame, ownFlapHidden)
		end
		door.shownAngle = math.huge
	end
	door.flapSwings = flapHinge(door) ~= nil
	if leaf ~= nil then
		setSignShown(door, leaf, not open)
	end
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

-- Which way a cat at the flap hanging from `hinge` pushes it (BackDoor.pushFrom), or nil with none within
-- FLAP_RANGE: the strays and the plot's own cats.
local function catPush(door: Door, panel: BasePart, hinge: Vector3): number?
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
	door.wantsOpen = BackDoor.wantsOpen(open, door.owned, nearestPlayer(doorway))
	local hinge = if math.abs(door.angle) < FLAP_SHUT_DEGREES then flapHinge(door) else nil
	door.push = if hinge ~= nil then catPush(door, panel, hinge) else nil
end

local function step(door: Door, dt: number, open: boolean)
	if not door.active then
		return
	end
	if door.leaf ~= nil then
		door.angle =
			BackDoor.stepLeaf(door.angle, if door.wantsOpen then BackDoor.OPEN_DEGREES else 0, dt)
		if door.flapSwings then
			door.flapAngle, door.flapSpeed =
				BackDoor.stepFlap(door.flapAngle, door.flapSpeed, door.push, dt)
		else
			door.flapAngle, door.flapSpeed = 0, 0
		end
		show(door)
	end
	if #door.frontLeaves > 0 then
		door.frontAngle =
			BackDoor.stepLeaf(door.frontAngle, if open then BackDoor.FRONT_OPEN_DEGREES else 0, dt)
		showFront(door)
	end
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
	local own = leafOf(leaf :: Model)
	local flap = childModel(own.model, ART .. "_Flap")
	local door: Door = {
		art = art,
		plot = plot,
		own = own,
		-- the art's flap turns about its own X (Model-Agent #509), the leaf's as built: positive into the cafe
		ownFlap = if flap ~= nil then swingOf(flap, own.shut, own.shut.XVector) else nil,
		flapFrame = childModel(own.model, ART .. "_FlapFrame"),
		leaf = nil,
		leafFrom = nil,
		front = nil,
		frontLeaves = {},
		frontAngle = 0,
		shownFront = 0,
		decorFlap = nil,
		decorSwing = nil,
		swingFrom = nil,
		flapSwings = false,
		bulbs = own.model:FindFirstChild(ART .. "_Sign_Bulb"),
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
		hidden = false,
		ownFlapHidden = false,
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
			step(door, dt, open)
		end
	end)
end

return DoorController
