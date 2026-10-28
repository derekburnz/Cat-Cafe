--!strict
-- The Cat Cannon and the camps (F84, hometown-cannon.md sections 3b, 4 and 5). A flight: the fuse fizzes while the
-- barrel turns, then BOOM, a smoke ring round the muzzle with confetti and a camera shake, a sparkle trail on the
-- flying player, and a cloud puff where they vanish in the sky. The launching player's screen fills with clouds
-- tinted toward where they are going (Clouds.luau) with their own character gliding through them, the clouds part
-- over the camp, and a dust poof goes off as their feet touch the pad. A cloud hop (Home from a wild area, the night
-- sweep) is the clouds without the cannon, with a puff where onlookers see the player go and arrive. At a camp
-- check-in the carried cat hops out of its carrier's arms into the carrier basket and puffs away. The intro plays
-- the same flight and check-in on its copy of the player (Cannon.playStaged, Cannon.checkInStaged). The hop into the
-- barrel, the curled ball, the glide in the clouds and the crouch landing are Animation-Engineer's
-- (Effects/CannonGlide); the move itself is the server's.
--
-- Source: the character attributes `CannonLaunchAt` (server time), `CannonTo` and `Launching`, and `CloudHopAt` and
-- `CloudHopTo`; the cannon models' `Muzzle` and `Fuse` attachments (else the cannon's bounding box); the
-- `CampBasket` tag and its `Drop` attachment; CannonGlide through Cannon.setGlide once that module is in;
-- `Moments.CampCheckIn(userId, campId)` and the carrier's `HeldCat`, once the engineer has them. Listening only.
-- Numbers in Presets.cannon, Presets.clouds and Presets.campCheckIn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Moments = require(script.Parent.Parent.Moments)

local Clouds = require(script.Parent.Clouds)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Cannon = {}

-- A flight's beats in seconds from its start: Presets.cannon for a real one, Presets.cannon.introStage for the
-- intro's squeezed one (Cannon.playStaged).
export type Stage = {
	boomAt: number,
	puffAt: number,
	dropAt: number,
	landAt: number,
	endAt: number,
	clouds: Logic.CloudPlan,
	glideFrom: number,
	glideTo: number,
}

type Flight = {
	at: number, -- server time of the launch
	stage: Stage,
	beats: { [string]: number },
	staged: boolean, -- the intro's local copy: no attributes, effects on its pivot, always this screen's
	mine: boolean,
	fired: { [string]: boolean },
	muzzle: Vector3,
	fuse: Vector3,
	aim: Vector3, -- the way the barrel fires
	nextFizz: number, -- seconds into the flight
	flying: boolean, -- `Launching` has been seen on, so its going off early means the flight stopped
	last: Vector3, -- where the flying body was last seen, for the cloud puff where it vanishes
	trail: Attachment?,
}

export type Glide = {
	body: (character: Model) -> CFrame?,
	mount: (parent: GuiObject, zIndex: number, character: Model, launchAt: number) -> (),
	-- the intro's copy gliding from `from` (server time) for `seconds`, once Animation-Engineer has it
	mountStaged: ((
		parent: GuiObject,
		zIndex: number,
		model: Model,
		from: number,
		seconds: number
	) -> ())?,
}

type Hop = {
	at: number,
	mine: boolean,
	fired: { [string]: boolean },
	from: Vector3,
	last: Vector3,
	arrived: boolean,
}

local CANNONS = { "CatCafe_Square_Cannon", "CatCafe_Camp_Cannon" }
local REAL: Stage = {
	boomAt = Presets.cannon.boomAt,
	puffAt = Presets.cannon.puffAt,
	dropAt = Presets.cannon.dropAt,
	landAt = Presets.cannon.landAt,
	endAt = Presets.cannon.endAt,
	clouds = Presets.clouds.cannon,
	glideFrom = Presets.cannon.puffAt,
	glideTo = Presets.cannon.dropAt,
}

local flights: { [Model]: Flight } = {}
-- Animation-Engineer's CannonGlide (the flying body and the launching player's character in the clouds), handed in
-- by init.luau once it is in the build.
local glide: Glide? = nil
local hops: { [Model]: Hop } = {}
local loop: RBXScriptConnection? = nil
local started = false
local below = RaycastParams.new()
below.FilterType = Enum.RaycastFilterType.Exclude
local nearby = OverlapParams.new()
nearby.FilterType = Enum.RaycastFilterType.Exclude

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return character.PrimaryPart
end

-- Where the flying body is: Animation-Engineer moves it through the Root joint while the root part waits in the
-- barrel, so its own CFrame when it has one (nil while it is hidden in the sky), else the root part.
local function bodyAt(character: Model, root: BasePart): Vector3?
	local g = glide
	if g ~= nil then
		local frame = g.body(character)
		return if frame ~= nil then frame.Position else nil
	end
	return root.Position
end

local function tintOf(destination: unknown): Color3
	local tints = Presets.cannon.tints
	local found: Color3? = if type(destination) == "string" then tints[destination] else nil
	return found or tints.town
end

local function near(position: Vector3, within: number, mine: boolean): boolean
	return mine or Context.distance(position) <= within
end

-- The cannon a launching player sits in: the nearest cannon model with a part round them.
local function findCannon(character: Model, at: Vector3): Model?
	nearby.FilterDescendantsInstances = { character, Context.folder() }
	for _, part in Workspace:GetPartBoundsInRadius(at, Presets.cannon.findCannon, nearby) do
		for _, name in CANNONS do
			local model = part:FindFirstAncestor(name)
			if model ~= nil and model:IsA("Model") then
				return model :: Model
			end
		end
	end
	return nil
end

-- Where the muzzle and the fuse are and the way it fires: the model's attachments, else the top of its bounding box
-- firing straight up, else the player's own spot.
local function aimOf(cannon: Model?, spot: Vector3): (Vector3, Vector3, Vector3)
	local up = Vector3.new(0, 1, 0)
	if cannon == nil then
		return spot + up * 3, spot, up
	end
	local frame, size = cannon:GetBoundingBox()
	local muzzle = frame.Position + up * Logic.halfExtents(frame, size).Y
	local fuse = frame.Position
	local muzzleAt = cannon:FindFirstChild("Muzzle", true)
	local fuseAt = cannon:FindFirstChild("Fuse", true)
	if fuseAt ~= nil and fuseAt:IsA("Attachment") then
		fuse = (fuseAt :: Attachment).WorldPosition
	end
	if muzzleAt ~= nil and muzzleAt:IsA("Attachment") then
		local mouth = muzzleAt :: Attachment
		muzzle = mouth.WorldPosition
		local barrel = muzzle - fuse
		local aim = if barrel.Magnitude > 0.5 then barrel.Unit else mouth.WorldCFrame.LookVector
		return muzzle, fuse, aim
	end
	return muzzle, fuse, up
end

local function boom(flight: Flight)
	local c = Presets.cannon
	local aim = flight.aim
	local side = aim:Cross(Vector3.new(0, 1, 0))
	if side.Magnitude < 0.01 then
		side = Vector3.new(1, 0, 0)
	end
	side = side.Unit
	local up = side:Cross(aim).Unit
	for i = 1, c.ring do
		local angle = 2 * math.pi * i / c.ring
		local at = flight.muzzle + (side * math.cos(angle) + up * math.sin(angle)) * c.ringRadius
		Particles.burst("smokePuff", at, c.ringPuffs)
	end
	Particles.burst("smokePuff", flight.muzzle + aim, Presets.bursts.smokePuff)
	Particles.confetti(flight.muzzle, math.max(1, math.floor(Context.budget.confetti * c.confetti)))
	if flight.mine then
		Context.shake(c.shake, c.shakeStuds)
	elseif Context.distance(flight.muzzle) <= c.shakeWithin then
		Context.shake(c.shake, c.shakeNear)
	end
end

local function land(character: Model, at: Vector3)
	local c = Presets.cannon
	below.FilterDescendantsInstances = { character, Context.folder() }
	local hit = Workspace:Raycast(at, Vector3.new(0, -12, 0), below)
	local ground = if hit ~= nil then hit.Position else at - Vector3.new(0, 3, 0)
	for i = 1, c.landRing do
		local angle = 2 * math.pi * i / c.landRing
		Particles.burst(
			"dust",
			ground + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * c.landRadius,
			c.landDust
		)
	end
	Particles.ring(ground + Vector3.new(0, 0.1, 0), Presets.palette.cream, 7, 0.4)
end

local function trails(): number
	local n = 0
	for _, flight in flights do
		if flight.trail ~= nil then
			n += 1
		end
	end
	return n
end

-- The sparkle trail follows the flying body on an Attachment in the Terrain moved each step.
local function setTrail(flight: Flight, at: Vector3?, on: boolean)
	local holder = flight.trail
	if on and at ~= nil then
		if holder == nil and (flight.mine or trails() < Presets.cannon.most) then
			local made = Particles.anchor("EffectsCannonTrail", at)
			Particles.attach("cannonTrail", made)
			flight.trail = made
		elseif holder ~= nil then
			holder.Position = at
		end
	elseif holder ~= nil then
		holder:Destroy()
		flight.trail = nil
	end
end

local function endFlight(character: Model)
	local flight = flights[character]
	if flight == nil then
		return
	end
	flights[character] = nil
	local holder = flight.trail
	if holder ~= nil then
		holder:Destroy()
	end
end

local function stepFlight(character: Model, flight: Flight, now: number)
	local c = Presets.cannon
	local s = flight.stage
	local t = now - flight.at
	local root = rootOf(character)
	if t > s.endAt + c.stale or character.Parent == nil or (root == nil and not flight.staged) then
		endFlight(character)
		return
	end
	-- the intro's copy is flown by its pivot; a real character's root part waits in the barrel while its body flies
	local spot = if flight.staged
		then character:GetPivot().Position
		else (root :: BasePart).Position
	local at = if flight.staged then spot else bodyAt(character, root :: BasePart)
	if at ~= nil and t < s.puffAt then
		flight.last = at
	end
	-- stopped before the drop (the server clears `Launching` only as it lands): no more of the flight
	local launching = character:GetAttribute("Launching") == true
	flight.flying = flight.flying or launching
	if not flight.staged and flight.flying and not launching and t < s.dropAt then
		if flight.mine then
			Clouds.stop()
		end
		endFlight(character)
		return
	end
	local seen = near(spot, c.within, flight.mine)
	if t < s.boomAt and t >= flight.nextFizz then
		flight.nextFizz = t + c.fuseEvery
		if seen or Context.distance(flight.fuse) <= c.within then
			Particles.burst("fuseSpark", flight.fuse, Presets.bursts.fuseSpark)
		end
	end
	for _, beat in Logic.beatsDue(t, flight.beats, flight.fired) do
		if beat == "boom" and (seen or Context.distance(flight.muzzle) <= c.within) then
			boom(flight)
		elseif beat == "puff" and (seen or Context.distance(flight.last) <= c.within) then
			Particles.burst("smokePuff", flight.last, c.skyPuff, Presets.clouds.white)
		elseif beat == "land" and near(spot, c.within, flight.mine) then
			land(character, spot)
		end
	end
	setTrail(flight, at, seen and Logic.cannonTrail(t, s))
end

local function stepHop(character: Model, hop: Hop, now: number)
	local h = Presets.clouds
	local t = now - hop.at
	local root = rootOf(character)
	if t > h.hop.partTo + Presets.cannon.stale or character.Parent == nil or root == nil then
		hops[character] = nil
		return
	end
	local at = (root :: BasePart).Position
	for _ in Logic.beatsDue(t, { gone = h.hop.coverTo }, hop.fired) do
		if not hop.mine and near(hop.from, Presets.cannon.within, false) then
			Particles.burst("smokePuff", hop.from, h.hopPuff, h.white)
		end
	end
	if not hop.arrived and (at - hop.last).Magnitude > h.moved then
		hop.arrived = true
		if not hop.mine and near(at, Presets.cannon.within, false) then
			Particles.burst("smokePuff", at, h.hopPuff, h.white)
		end
	end
	hop.last = at
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for character, flight in flights do
		stepFlight(character, flight, now)
	end
	for character, hop in hops do
		stepHop(character, hop, now)
	end
	local current = loop
	if next(flights) == nil and next(hops) == nil and current ~= nil then
		current:Disconnect()
		loop = nil
	end
end

local function running()
	if loop == nil then
		loop = RunService.Heartbeat:Connect(step)
	end
end

-- A flight starting at `at` (server time) on `character`'s beats in `stage`.
local function fly(
	character: Model,
	at: number,
	stage: Stage,
	staged: boolean,
	cannon: Model?,
	spot: Vector3
)
	local c = Presets.cannon
	local t = Workspace:GetServerTimeNow() - at
	local muzzle, fuse, aim = aimOf(cannon, spot)
	local beats: { [string]: number } =
		{ boom = stage.boomAt, puff = stage.puffAt, land = stage.landAt }
	local fired: { [string]: boolean } = {}
	-- beats long gone when this client heard of the flight are skipped, not played late
	for name, beat in beats do
		if t > beat + 0.3 then
			fired[name] = true
		end
	end
	flights[character] = {
		at = at,
		stage = stage,
		beats = beats,
		staged = staged,
		mine = staged or character == Players.LocalPlayer.Character,
		fired = fired,
		muzzle = muzzle,
		fuse = fuse,
		aim = aim,
		nextFizz = stage.boomAt - c.fuseSeconds,
		flying = false,
		last = spot,
		trail = nil,
	}
	running()
end

local function launched(character: Model)
	local at = character:GetAttribute("CannonLaunchAt")
	local root = rootOf(character)
	if type(at) ~= "number" or root == nil then
		return
	end
	local existing = flights[character]
	if existing ~= nil and existing.at == at then
		return
	end
	endFlight(character)
	local c = Presets.cannon
	local t = Workspace:GetServerTimeNow() - at
	if t > c.endAt + c.stale then
		return -- joined or streamed in after it was over
	end
	local spot = (root :: BasePart).Position
	fly(character, at, REAL, false, findCannon(character, spot), spot)
	if character == Players.LocalPlayer.Character then
		Clouds.play(at, Presets.clouds.cannon, tintOf(character:GetAttribute("CannonTo")))
		-- your own character glides through the clouds (Animation-Engineer), between the clouds behind and in front
		local g, rider = glide, Clouds.rider()
		if g ~= nil and rider ~= nil then
			g.mount(rider, Presets.clouds.riderZ, character, at)
		end
	end
end

local function hopped(character: Model)
	local at = character:GetAttribute("CloudHopAt")
	local root = rootOf(character)
	if type(at) ~= "number" or root == nil then
		return
	end
	local existing = hops[character]
	if existing ~= nil and existing.at == at then
		return
	end
	local t = Workspace:GetServerTimeNow() - at
	if t > Presets.clouds.hop.partTo then
		return
	end
	local mine = character == Players.LocalPlayer.Character
	local from = (root :: BasePart).Position
	hops[character] =
		{ at = at, mine = mine, fired = {}, from = from, last = from, arrived = false }
	if mine then
		Clouds.play(at, Presets.clouds.hop, tintOf(character:GetAttribute("CloudHopTo")))
	end
	running()
end

-- Where a cat drops into a carrier basket: its `Drop` attachment, else its pivot.
local function dropPoint(basket: Instance): Vector3
	local drop = basket:FindFirstChild("Drop", true)
	if drop ~= nil and drop:IsA("Attachment") then
		return (drop :: Attachment).WorldPosition
	end
	return if basket:IsA("Model") then (basket :: Model):GetPivot().Position else Vector3.zero
end

-- A cat's hop from its carrier's arms into a camp's carrier basket: a copy of the cat, so it keeps its outfit and
-- gold coat while the real one is removed. Into `basket`, else the nearest CampBasket.
local function hopIn(cat: Model, basket: Model?)
	local k = Presets.campCheckIn
	local from = cat:GetPivot()
	local to = from.Position + Vector3.new(0, -1, 0)
	if basket ~= nil then
		to = dropPoint(basket)
	else
		local best = k.findBasket
		for _, tagged in CollectionService:GetTagged("CampBasket") do
			if tagged:IsA("Model") and tagged:IsDescendantOf(Workspace) then
				local point = dropPoint(tagged)
				local distance = (point - from.Position).Magnitude
				if distance < best then
					best, to = distance, point
				end
			end
		end
	end
	Particles.burst("gateSparkle", from.Position, k.sparkle)
	if Context.reducedMotion() then
		Particles.burst("smokePuff", to, k.puff, Presets.clouds.white)
		return
	end
	cat.Archivable = true
	local copy = cat:Clone()
	local hold = copy:FindFirstChild("HoldWeld", true)
	if hold ~= nil then
		hold:Destroy()
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- the real one goes in a moment; only the copy shows
			(descendant :: BasePart).LocalTransparencyModifier = 1
		end
	end
	copy.Name = "EffectsCheckInCat"
	copy.Parent = Context.folder()
	local turn = from.Rotation
	local began = os.clock()
	local hopping: RBXScriptConnection? = nil
	hopping = RunService.Heartbeat:Connect(function()
		local s = math.min(1, (os.clock() - began) / k.hopSeconds)
		copy:PivotTo(CFrame.new(Logic.hopPoint(from.Position, to, k.hopHeight, s)) * turn)
		copy:ScaleTo(1 - (1 - k.shrink) * s)
		if s >= 1 then
			if hopping ~= nil then
				hopping:Disconnect()
			end
			Particles.burst("smokePuff", to, k.puff, Presets.clouds.white)
			Particles.burst("gateSparkle", to, k.sparkle)
			copy:Destroy()
		end
	end)
end

-- The checked-in cat of a carrier at a camp (Moments.CampCheckIn), within sight.
local function checkedIn(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local held = if character ~= nil then character:FindFirstChild("HeldCat") else nil
	if character == nil or held == nil or not held:IsA("Model") then
		return
	end
	local cat = held :: Model
	if near(cat:GetPivot().Position, Presets.campCheckIn.within, player == Players.LocalPlayer) then
		hopIn(cat, nil)
	end
end

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("CannonLaunchAt"):Connect(function()
		launched(character)
	end)
	character:GetAttributeChangedSignal("CloudHopAt"):Connect(function()
		hopped(character)
	end)
	launched(character)
	hopped(character)
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

-- The intro's cannon shot (F84 intro, intro-cutscene.md shot 2): the same flight on a local copy of the player's
-- character, which the intro flies itself, on `stage`'s squeezed beats (Presets.cannon.introStage by default) from
-- `startedAt` (Workspace:GetServerTimeNow() terms; call it stage.boomAt - fuseSeconds early for the fuse fizz). The
-- muzzle and fuse come from `cannon`'s attachments. This screen only: the clouds tinted toward `destination` and,
-- once Animation-Engineer has it, the copy gliding in them.
function Cannon.playStaged(
	model: Model,
	cannon: Model?,
	destination: string,
	startedAt: number,
	stage: Stage?
)
	local plan = stage or Presets.cannon.introStage
	endFlight(model)
	fly(model, startedAt, plan, true, cannon, model:GetPivot().Position)
	Clouds.play(startedAt, plan.clouds, tintOf(destination))
	local g, rider = glide, Clouds.rider()
	local staged = if g ~= nil then g.mountStaged else nil
	if staged ~= nil and rider ~= nil then
		staged(
			rider,
			Presets.clouds.riderZ,
			model,
			startedAt + plan.glideFrom,
			plan.glideTo - plan.glideFrom
		)
	end
end

-- The intro's camp check-in: `cat` (the copy's carried cat) hops into `basket`'s Drop point, else the nearest
-- CampBasket, and puffs away. It hides `cat` on this client, so the intro removes it after.
function Cannon.checkInStaged(cat: Model, basket: Model?)
	hopIn(cat, basket)
end

-- Ends the intro's flight on `model` at once (Skip, or the intro over): no more beats or trail, and the clouds go
-- unless this player is on a real flight.
function Cannon.stopStaged(model: Model)
	endFlight(model)
	local own = Players.LocalPlayer.Character
	local real = if own ~= nil then flights[own] else nil
	if real == nil or real.staged then
		Clouds.stop()
	end
end

-- Hands in Animation-Engineer's CannonGlide (init.luau calls it once that module is in the build).
function Cannon.setGlide(api: Glide)
	glide = api
end

function Cannon.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		Clouds.stop() -- respawned mid-flight: never leave the screen covered
	end)
	-- the engineer's camp check-in, once Moments has it (F84); until then a check-in shows only the toast
	local moments = Moments :: any
	if moments.CampCheckIn ~= nil then
		moments.CampCheckIn:Connect(function(userId: unknown)
			if type(userId) == "number" then
				checkedIn(userId)
			end
		end)
	end
end

return Cannon
