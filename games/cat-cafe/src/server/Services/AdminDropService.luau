--!strict
-- #4197 part 2: the two admin events that put things on the ground to grab (shared/CafeEvents, EventService).
-- - Fish Fountain (`fishFountain`): golden fish pickups land in a ring around the Town Square cannon plinth, where
--   the fountain stood until v4, FOUNTAIN_PER_SECOND a second while fewer than FOUNTAIN_OUT are out. The first
--   player to touch one gets ADMIN.fountainFish golden fish, at most ADMIN.fountainCap in one fountain. One left
--   untouched goes after FISH_LIFE seconds.
-- - Crate Drop (`crateDrop`): by day, every ADMIN.crateGap seconds, a golden crate drops into each area somebody
--   here has open, on one of its stray spawn points. It lands at its `LandsAt` (server time) and the first touch
--   after that opens it: the toucher and every player within ADMIN.crateShareStuds get one golden crate of their
--   best open area (Prizes.HIGHEST_GOLDEN), at most ADMIN.crateCap each in one drop. One left untouched goes after
--   CRATE_LIFE seconds; all of them go when the event ends.
-- For the client's effects (Motion-FX): pickups are Parts named "AdminFish" with attribute AdminFish = true and
-- `From` (the plinth's centre, for the spray's arc); crates are Models named "AdminCrate" with attribute
-- AdminCrate = true and `LandsAt` (for the parachute). Both sit in Workspace.AdminDrops. Nothing here is sold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
local RING_IN = 3 -- studs past the plinth's edge
local RING_OUT = 16
local CRATE_FALL = 3 -- seconds from the drop to the landing (the client's parachute)
local CRATE_LIFE = 90
local CRATE_SIZE = Vector3.new(3, 3, 3)
local FISH_SIZE = Vector3.new(1.6, 0.6, 0.9)
local GOLD = Color3.fromRGB(255, 196, 61)

type Run = {
	id: string,
	got: { [Player]: number }, -- fish or crates each player has had in this run
	out: { [Instance]: number }, -- each pickup or crate still out, and when it goes (server time)
	left: { [string]: number }, -- Crate Drop: seconds until each area's next crate
}

local world: WorldBuilder.World
local folder: Folder
local rng = Random.new()
local fountain: Run? = nil
local crates: Run? = nil

local function newRun(id: string): Run
	return { id = id, got = setmetatable({}, { __mode = "k" }) :: any, out = {}, left = {} }
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
		Net.toast(
			player,
			string.format("Fish Fountain: you caught the most fish, %d!", ADMIN.fountainCap),
			"good"
		)
	end
end

local function sprayFish(run: Run, at: number)
	local cannon = world.cannons.town
	if cannon == nil then
		return
	end
	local centre = cannon:GetPivot().Position
	local inner = Layout.townSquare.fountainRadius + RING_IN
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(inner, inner + RING_OUT)
	local spot = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local fish = Instance.new("Part")
	fish.Name = "AdminFish"
	fish.Size = FISH_SIZE
	fish.Color = GOLD
	fish.Material = Enum.Material.SmoothPlastic
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CanTouch = true
	fish.CFrame = CFrame.new(spot + Vector3.new(0, FISH_SIZE.Y / 2 + 0.4, 0))
		* CFrame.Angles(0, angle, 0)
	fish:SetAttribute("AdminFish", true)
	fish:SetAttribute("From", centre)
	fish.Touched:Connect(function(hit: BasePart)
		local player = playerOf(hit)
		if player ~= nil then
			grabFish(run, fish, player)
		end
	end)
	run.out[fish] = at + FISH_LIFE
	fish.Parent = folder
end

local function fountainTick(at: number)
	local id = EventService.fishFountain()
	if fountain ~= nil and fountain.id ~= id then
		clear(fountain)
		fountain = nil
	end
	if id == nil then
		return
	end
	local run = fountain
	if run == nil then
		run = newRun(id)
		fountain = run
	end
	assert(run ~= nil)
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
		if profile == nil or crateId == nil or had >= ADMIN.crateCap then
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

local function dropCrate(run: Run, area: WorldBuilder.AreaInfo, at: number)
	if #area.spawnPoints == 0 then
		return
	end
	local point = area.spawnPoints[rng:NextInteger(1, #area.spawnPoints)]
	local spot = Vector3.new(point.Position.X, area.floorY, point.Position.Z)
	local crate = Instance.new("Model")
	crate.Name = "AdminCrate"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = CRATE_SIZE
	box.Color = GOLD
	box.Material = Enum.Material.WoodPlanks
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = true
	box.CFrame = CFrame.new(spot + Vector3.new(0, CRATE_SIZE.Y / 2, 0))
		* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	box.Parent = crate
	crate.PrimaryPart = box
	crate:SetAttribute("AdminCrate", true)
	crate:SetAttribute("LandsAt", at + CRATE_FALL)
	crate:SetAttribute("Area", area.id)
	box.Touched:Connect(function(hit: BasePart)
		local player = playerOf(hit)
		if player ~= nil then
			openCrate(run, crate, player, Workspace:GetServerTimeNow())
		end
	end)
	run.out[crate] = at + CRATE_FALL + CRATE_LIFE
	crate.Parent = folder
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
	assert(run ~= nil)
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
end

return AdminDropService
