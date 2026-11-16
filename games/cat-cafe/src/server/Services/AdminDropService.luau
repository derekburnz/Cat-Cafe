--!strict
-- #4197 part 2: the two admin events that put things on the ground to grab (shared/CafeEvents, EventService).
-- - Fish Fountain (`fishFountain`): golden fish pickups land in a ring around a golden fountain in the Town Square
--   (#4889; round the cannon plinth before), FOUNTAIN_PER_SECOND a second while fewer than FOUNTAIN_OUT are out. The first
--   player to touch one gets ADMIN.fountainFish golden fish, at most ADMIN.fountainCap in one fountain. One left
--   untouched goes after FISH_LIFE seconds.
-- - Crate Drop (`crateDrop`): by day, every ADMIN.crateGap seconds, a golden crate drops into each area somebody
--   here has open, on one of its stray spawn points. It lands at its `LandsAt` (server time) and the first touch
--   after that opens it: the toucher and every player within ADMIN.crateShareStuds get one golden crate of their
--   best open area (Prizes.HIGHEST_GOLDEN), at most ADMIN.crateCap each in one drop. One left untouched goes after
--   CRATE_LIFE seconds; all of them go when the event ends.
-- #4889 (Derek 2026-11-16: "spawn a gold fish fountain but no ontop of the cannon and make it actual gold fish
-- models that pop out now just gold bars", "make sure that all fish spawning for fountain admin event actually can
-- be picked up"): while the fountain runs, the CatCafe_Square_FishFountain model ("AdminFountain") stands in the
-- square's open quarter at FOUNTAIN_AT, and the fish land in a ring round it, each on open ground found with a ray
-- (a spot on a prop or off the paving is thrown again). A fish is the CatCafe_Prop_GoldenFish model inside the
-- unseen AdminFish part, and it is taken by the nearest player within FISH_GRAB studs, checked CRATE_GRAB_SECONDS
-- apart, as well as on a touch (a Touched event only fires as a touch starts). `From` is the fountain's spout.
-- For the client's effects (Motion-FX): pickups are Parts named "AdminFish" with attribute AdminFish = true and
-- `From` (the plinth's centre, for the spray's arc); crates are Models named "AdminCrate" with attribute
-- AdminCrate = true and `LandsAt` (for the parachute). Both sit in Workspace.AdminDrops. Nothing here is sold.
-- #4888 (Derek 2026-11-16: "make the model soo much better", "make them solid not walkthrough and put exclamation
-- marks above them", "half the time walking into it does nothing"): the crate is the CatCafe_Prop_Crate_Drop model
-- (a plain gold block without the art) round an unseen `Box` that is solid from the landing on, with a "!" over
-- it. It opens for the first player within CRATE_GRAB studs of it, checked CRATE_GRAB_SECONDS apart, as well as on
-- a touch: a Touched event only fires as a touch starts, so a player already against the crate as it landed, or
-- one who stood still beside it, got nothing. A player who already has ADMIN.crateCap crates is told so, again every few seconds while they keep trying.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local Prizes = require(ReplicatedStorage.Shared.Prizes)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local AdminDropService = {}

local ADMIN = CafeEvents.ADMIN
local FOUNTAIN_PER_SECOND = 2
local FOUNTAIN_OUT = 30
local FISH_LIFE = 20
local RING_IN = 6.5 -- #4889: studs from the fountain's centre to the nearest fish (the fountain is 4.8 out)
local RING_OUT = 10.5 -- and how much farther the farthest lands
local FOUNTAIN_ART = "CatCafe_Square_FishFountain"
local FISH_ART = "CatCafe_Prop_GoldenFish"
-- #4889: the middle of the square's quarter between the street's line (x under 8), the east to west lane (z under
-- 6) and the edge stations (x 50): the whole ring of fish stays on open paving, clear of the cannon and its pad
local FOUNTAIN_AT = Vector3.new(26, 0, 28)
local FOUNTAIN_SPOUT = 9 -- studs over the ground to the fish statue's mouth, where the spray starts
local FISH_GRAB = 4.5 -- studs (flat) from a fish that pick it up
local FISH_GRAB_HEIGHT = 8
local FISH_TRIES = 8 -- throws at finding open ground for one fish
local GROUND_SLACK = 1.5 -- a spot this far over or under the square's ground is on a prop or off the paving
local CRATE_FALL = 3 -- seconds from the drop to the landing (the client's parachute)
local CRATE_LIFE = 90
local CRATE_SIZE = Vector3.new(4.2, 3.4, 3.2) -- #4888: the Crate Drop model's body (3 x 3 x 3 before)
local CRATE_ART = "CatCafe_Prop_Crate_Drop"
local CRATE_GRAB = 7 -- #4888: studs (flat) from the crate's centre that open it; its sides are about 2 out
local CRATE_GRAB_HEIGHT = 8 -- and this far over or under it
local CRATE_GRAB_SECONDS = 0.2
local REMIND_SECONDS = 8 -- a player at a cap who keeps trying is told so this often
local CRATE_MARK_UP = 5.2 -- studs over the crate's middle to the "!"
local FISH_SIZE = Vector3.new(2.2, 1.6, 1.2) -- #4889: the golden fish model's box (a 1.6 x 0.6 x 0.9 bar before)
local GOLD = Color3.fromRGB(255, 196, 61)

type Run = {
	id: string,
	got: { [Player]: number }, -- fish or crates each player has had in this run
	out: { [Instance]: number }, -- each pickup or crate still out, and when it goes (server time)
	left: { [string]: number }, -- Crate Drop: seconds until each area's next crate
	told: { [Player]: number }, -- #4888: when a player at the cap was last told so (said again every REMIND_SECONDS)
}

local world: WorldBuilder.World
local folder: Folder
local rng = Random.new()
local fountain: Run? = nil
local crates: Run? = nil

local function newRun(id: string): Run
	return {
		id = id,
		got = setmetatable({}, { __mode = "k" }) :: any,
		out = {},
		left = {},
		told = setmetatable({}, { __mode = "k" }) :: any,
	}
end

local function clear(run: Run?)
	if run == nil then
		return
	end
	for thing in run.out do
		thing:Destroy()
	end
	table.clear(run.out)
end

local function playerOf(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model") :: Model?
	return if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- Fish Fountain ----------------------------------------------------------------------------------------------

-- A player at an event's cap who keeps trying is told why nothing happens, at most once every REMIND_SECONDS, so a
-- full player never reads the drop as broken (Derek 2026-11-16: "picking up ... does not work").
local function remind(run: Run, player: Player, text: string)
	local at = os.clock()
	local last = run.told[player]
	if last ~= nil and at - last < REMIND_SECONDS then
		return
	end
	run.told[player] = at
	Net.toast(player, text, "info")
end

local function grabFish(run: Run, fish: BasePart, player: Player)
	if run.out[fish] == nil or fountain ~= run then
		return
	end
	local profile = DataService.get(player)
	local had = run.got[player] or 0
	if profile == nil or had >= ADMIN.fountainCap then
		return -- full: the fish stays for someone else
	end
	run.out[fish] = nil
	fish:Destroy()
	local amount = math.min(ADMIN.fountainFish, ADMIN.fountainCap - had)
	run.got[player] = had + amount
	GoldenFish.credit(profile, amount)
	Telemetry.fishSource(player, profile, amount, "TimedReward", "fish_fountain")
	CafeService.sync(player)
	if had + amount >= ADMIN.fountainCap then
		run.told[player] = os.clock()
		Net.toast(
			player,
			string.format("Fish Fountain: you caught the most fish, %d!", ADMIN.fountainCap),
			"good"
		)
	end
end

-- #4889: the square's ground under (x, z): the top of whatever a ray down from high over it meets, drops and
-- characters left out; nil over nothing.
local function groundAt(x: number, z: number): number?
	local params = RaycastParams.new()
	local skip: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
	return if hit ~= nil then hit.Position.Y else nil
end

local fountainModel: Model? = nil
local fountainGround: number? = nil

-- #4889: stands the golden fish fountain up for this run (once); false when it cannot stand.
local function raiseFountain(): boolean
	if fountainModel ~= nil and fountainModel.Parent ~= nil then
		return true
	end
	-- the paving's top under the spot, or the square's own height (the cannon's) should the ray meet nothing
	local ground = groundAt(FOUNTAIN_AT.X, FOUNTAIN_AT.Z) or Layout.cannons.town.y
	fountainGround = ground
	local model: Model
	if AssetRegistry.has(FOUNTAIN_ART) then
		model = AssetRegistry.clone(FOUNTAIN_ART)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				local part = piece :: BasePart
				part.Anchored = true
				part.CanQuery = false -- so the fish's ground ray and the players' taps pass it by
				part.CanTouch = false
			end
		end
	else
		model = Instance.new("Model")
		local basin = Instance.new("Part")
		basin.Name = "Basin"
		basin.Shape = Enum.PartType.Cylinder
		basin.Size = Vector3.new(1.6, 9, 9)
		basin.Color = GOLD
		basin.Material = Enum.Material.Metal
		basin.Anchored = true
		basin.CanQuery = false
		basin.CanTouch = false
		basin.CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2)
		basin.Parent = model
		model.PrimaryPart = basin
		model.WorldPivot = CFrame.new()
	end
	model.Name = "AdminFountain"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("AdminFountain", true)
	model:PivotTo(CFrame.new(FOUNTAIN_AT.X, ground, FOUNTAIN_AT.Z))
	model.Parent = folder
	fountainModel = model
	return true
end

local function lowerFountain()
	if fountainModel ~= nil then
		fountainModel:Destroy()
		fountainModel = nil
	end
	fountainGround = nil
end

local function sprayFish(run: Run, at: number)
	local ground = fountainGround
	if ground == nil then
		return
	end
	-- a spot on open ground: one on a bench, a lamp or a station, or off the paving, is thrown again
	local spot: Vector3? = nil
	local angle = 0
	for _ = 1, FISH_TRIES do
		angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(RING_IN, RING_IN + RING_OUT)
		local x = FOUNTAIN_AT.X + math.cos(angle) * distance
		local z = FOUNTAIN_AT.Z + math.sin(angle) * distance
		local y = groundAt(x, z) or ground
		if math.abs(y - ground) <= GROUND_SLACK then
			spot = Vector3.new(x, y, z)
			break
		end
	end
	if spot == nil then
		return
	end
	local art: Model? = if AssetRegistry.has(FISH_ART) then AssetRegistry.clone(FISH_ART) else nil
	local turn = CFrame.Angles(0, angle, 0)
	local fish = Instance.new("Part")
	fish.Name = "AdminFish"
	fish.Size = FISH_SIZE
	fish.Color = GOLD
	fish.Material = Enum.Material.SmoothPlastic
	fish.Transparency = if art ~= nil then 1 else 0 -- the art is the look; the part is what is touched
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CanTouch = true
	fish.CFrame = CFrame.new(spot + Vector3.new(0, FISH_SIZE.Y / 2, 0)) * turn
	if art ~= nil then
		for _, piece in art:GetDescendants() do
			if piece:IsA("BasePart") then
				local part = piece :: BasePart
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		art.Name = "Art"
		art:PivotTo(CFrame.new(spot) * turn)
		art.Parent = fish
	end
	fish:SetAttribute("AdminFish", true)
	fish:SetAttribute("From", Vector3.new(FOUNTAIN_AT.X, ground + FOUNTAIN_SPOUT, FOUNTAIN_AT.Z))
	fish:SetAttribute("DroppedAt", Workspace:GetServerTimeNow()) -- #4788: a fish that streams in late skips its arc (Effects)
	fish.Touched:Connect(function(hit: BasePart)
		local player = playerOf(hit)
		if player ~= nil then
			grabFish(run, fish, player)
		end
	end)
	run.out[fish] = at + FISH_LIFE
	fish.Parent = folder
end

-- #4889: each fish goes to the nearest player within FISH_GRAB of it who can still take one. A touch works too.
local function grabFishNear()
	local run = fountain
	if run == nil then
		return
	end
	for thing in run.out do
		if not thing:IsA("BasePart") then
			continue
		end
		local where = (thing :: BasePart).Position
		local nearest: Player? = nil
		local best = FISH_GRAB
		for _, player in DataService.loadedPlayers() do
			local root = rootOf(player)
			if root ~= nil then
				local offset = root.Position - where
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if flat <= best and math.abs(offset.Y) <= FISH_GRAB_HEIGHT then
					if (run.got[player] or 0) < ADMIN.fountainCap then
						nearest = player
						best = flat
					else
						-- full: the fish stays for the others, and they are told why it does
						remind(
							run,
							player,
							string.format(
								"Fish Fountain: you have all %d fish from this fountain",
								ADMIN.fountainCap
							)
						)
					end
				end
			end
		end
		if nearest ~= nil then
			grabFish(run, thing :: BasePart, nearest)
		end
	end
end

local function fountainTick(at: number)
	local id = EventService.fishFountain()
	if fountain ~= nil and fountain.id ~= id then
		clear(fountain)
		fountain = nil
	end
	if id == nil then
		lowerFountain()
		return
	end
	if not raiseFountain() then
		return
	end
	local run = fountain
	if run == nil then
		run = newRun(id)
		fountain = run
	end
	assert(run ~= nil, "admin drop run")
	for thing, gone in run.out do
		if gone <= at then
			run.out[thing] = nil
			thing:Destroy()
		end
	end
	local count = 0
	for _ in run.out do
		count += 1
	end
	for _ = 1, math.min(FOUNTAIN_PER_SECOND, FOUNTAIN_OUT - count) do
		sprayFish(run, at)
	end
end

-- Crate Drop -------------------------------------------------------------------------------------------------

local function openCrate(run: Run, crate: Model, player: Player, at: number)
	if
		run.out[crate] == nil
		or crates ~= run
		or at < ((crate:GetAttribute("LandsAt") :: number?) or 0)
	then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	local where = crate:GetPivot().Position
	local winners: { Player } = { player }
	for _, other in DataService.loadedPlayers() do
		local otherRoot = rootOf(other)
		if
			other ~= player
			and otherRoot ~= nil
			and (otherRoot.Position - where).Magnitude <= ADMIN.crateShareStuds
		then
			table.insert(winners, other)
		end
	end
	local paid = false
	for _, winner in winners do
		local profile = DataService.get(winner)
		local had = run.got[winner] or 0
		local crateId = if profile ~= nil
			then Prizes.crateFor(Prizes.HIGHEST_GOLDEN, Economy.tier(profile))
			else nil
		if profile == nil or crateId == nil then
			continue
		end
		if had >= ADMIN.crateCap then
			-- #4888: said once, so a crate that does nothing for them is not a mystery; it stays for the others
			if winner == player then
				remind(
					run,
					winner,
					string.format(
						"Crate Drop: you have all %d crates from this drop",
						ADMIN.crateCap
					)
				)
			end
			continue
		end
		run.got[winner] = had + 1
		paid = true
		local owned = profile.crates[crateId :: string] or 0
		profile.crates[crateId :: string] = owned + 1
		Telemetry.custom(winner, "admin_drop", 1, { "crate", run.id })
		CafeService.sync(winner)
		Net.toast(winner, "Crate Drop: +1 golden crate!", "good")
	end
	if paid then
		run.out[crate] = nil
		crate:Destroy()
	end
end

-- #4888: the "!" over a crate, off until it lands.
local function crateMark(box: BasePart): BillboardGui
	local mark = Instance.new("BillboardGui")
	mark.Name = "Mark"
	mark.Adornee = box
	mark.Size = UDim2.fromScale(2.4, 3)
	mark.StudsOffsetWorldSpace = Vector3.new(0, CRATE_MARK_UP, 0)
	mark.MaxDistance = 160
	mark.LightInfluence = 0
	mark.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "!"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = GOLD
	label.Parent = mark
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 30, 0)
	stroke.Parent = label
	mark.Parent = box
	return mark
end

local function dropCrate(run: Run, area: WorldBuilder.AreaInfo, at: number)
	if #area.spawnPoints == 0 then
		return
	end
	local point = area.spawnPoints[rng:NextInteger(1, #area.spawnPoints)]
	local spot = Vector3.new(point.Position.X, area.floorY, point.Position.Z)
	local turn = CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	local crate = Instance.new("Model")
	crate.Name = "AdminCrate"
	crate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local art: Model? = if AssetRegistry.has(CRATE_ART) then AssetRegistry.clone(CRATE_ART) else nil
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = CRATE_SIZE
	box.Color = GOLD
	box.Material = Enum.Material.WoodPlanks
	box.Transparency = if art ~= nil then 1 else 0 -- the art is the look; the box is what is solid and touched
	box.Anchored = true
	box.CanCollide = false -- solid from the landing on, so nobody walks into an unseen wall while it falls
	box.CanQuery = false
	box.CanTouch = true
	box.CFrame = CFrame.new(spot + Vector3.new(0, CRATE_SIZE.Y / 2, 0)) * turn
	box.Parent = crate
	crate.PrimaryPart = box
	if art ~= nil then
		for _, piece in art:GetDescendants() do
			if piece:IsA("BasePart") then
				local part = piece :: BasePart
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		art.Name = "Art"
		art:PivotTo(CFrame.new(spot) * turn)
		art.Parent = crate
	end
	local mark = crateMark(box)
	crate:SetAttribute("AdminCrate", true)
	crate:SetAttribute("LandsAt", at + CRATE_FALL)
	crate:SetAttribute("Area", area.id)
	box.Touched:Connect(function(hit: BasePart)
		local player = playerOf(hit)
		if player ~= nil then
			openCrate(run, crate, player, Workspace:GetServerTimeNow())
		end
	end)
	task.delay(CRATE_FALL, function()
		if run.out[crate] ~= nil then
			box.CanCollide = true
			mark.Enabled = true
		end
	end)
	run.out[crate] = at + CRATE_FALL + CRATE_LIFE
	crate.Parent = folder
end

-- #4888: opens each landed crate for the nearest player within CRATE_GRAB of it. A touch still opens one too.
local function grabCrates()
	local run = crates
	if run == nil then
		return
	end
	local at = Workspace:GetServerTimeNow()
	for thing in run.out do
		if not thing:IsA("Model") or at < ((thing:GetAttribute("LandsAt") :: number?) or 0) then
			continue
		end
		local where = (thing :: Model):GetPivot().Position
		local nearest: Player? = nil
		local best = CRATE_GRAB
		for _, player in DataService.loadedPlayers() do
			local root = rootOf(player)
			if root ~= nil then
				local offset = root.Position - where
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				-- a player with every crate of this drop is passed over, so they never block someone behind them
				if
					flat <= best
					and math.abs(offset.Y) <= CRATE_GRAB_HEIGHT
					and ((run.got[player] or 0) < ADMIN.crateCap or nearest == nil)
				then
					nearest = player
					best = flat
				end
			end
		end
		if nearest ~= nil then
			openCrate(run, thing :: Model, nearest, at)
		end
	end
end

local function crateTick(at: number, dt: number)
	local id = EventService.crateDrop()
	if crates ~= nil and crates.id ~= id then
		clear(crates)
		crates = nil
	end
	if id == nil then
		return
	end
	local run = crates
	if run == nil then
		run = newRun(id)
		crates = run
	end
	assert(run ~= nil, "admin drop run")
	for thing, gone in run.out do
		if gone <= at then
			run.out[thing] = nil
			thing:Destroy()
		end
	end
	if not ClockService.areasOpen() then
		return -- nights close the areas; the drops pick up at sunrise
	end
	local open: { [string]: boolean } = {}
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			local tier = Economy.tier(profile)
			for _, areaDef in Catalog.areas do
				if tier >= areaDef.tier then
					open[areaDef.id] = true
				end
			end
		end
	end
	for index, areaDef in Catalog.areas do
		local area = world.areas[areaDef.id]
		if area == nil or not open[areaDef.id] then
			continue
		end
		-- the first crate of each area lands a little apart from the others, not all on the same second
		local left = (run.left[areaDef.id] or (index - 1) % 5) - dt
		if left <= 0 then
			left = ADMIN.crateGap
			dropCrate(run, area, at)
		end
		run.left[areaDef.id] = left
	end
end

function AdminDropService.start(built: WorldBuilder.World)
	world = built
	folder = Instance.new("Folder")
	folder.Name = "AdminDrops"
	folder.Parent = Workspace
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local nowClock = os.clock()
			local at = Workspace:GetServerTimeNow()
			xpcall(fountainTick, function(err: unknown)
				warn("[AdminDropService] fountain: " .. tostring(err))
			end, at)
			xpcall(crateTick, function(err: unknown)
				warn("[AdminDropService] crates: " .. tostring(err))
			end, at, nowClock - last)
			last = nowClock
		end
	end)
	-- #4888: crates open for a player standing by them, checked far more often than the drops tick
	task.spawn(function()
		while true do
			task.wait(CRATE_GRAB_SECONDS)
			xpcall(grabCrates, function(err: unknown)
				warn("[AdminDropService] crate grab: " .. tostring(err))
			end)
			xpcall(grabFishNear, function(err: unknown)
				warn("[AdminDropService] fish grab: " .. tostring(err))
			end)
		end
	end)
end

return AdminDropService
