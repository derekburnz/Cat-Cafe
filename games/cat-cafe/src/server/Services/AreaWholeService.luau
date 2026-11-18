--!strict
-- Derek 2026-11-18: the areaWhole switch (shared/AreaWhole). At start each catching area's Set and Backdrop are cut
-- into ground-cell chunks (Default Models, so nothing changes while the switch is off). With it on, the chunks turn
-- PersistentPerPlayer and each player is added to the chunks of the one area they stand in (WorldBuilder.areaAt) or
-- fly to, a few chunks every AreaWhole.SPREAD seconds and nearest first, so the area arrives over a couple of
-- seconds and not in one frame. The area they held before is let go at once for another area, or RELEASE_AFTER
-- seconds after they left it for the street or a cafe. A cannon flight calls AreaWholeService.heading at launch, so
-- the area streams in during the flight, starting at the landing pad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaWhole = require(ReplicatedStorage.Shared.AreaWhole)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local PlotService = require(script.Parent.PlotService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local AreaWholeService = {}

type Chunk = { model: Model, at: Vector3, size: number, mode: Enum.ModelStreamingMode }
type Hold = {
	area: string,
	added: { Chunk }, -- chunks this player is on the list of
	waiting: { Chunk }, -- chunks still to add, nearest first
}

-- The area Model's children cut into chunks: nearly all of an area's instances (Sync's re-test: the Alleyway's
-- Props alone are 8,901). Only WorldBuilder looks inside them, and it is done before start.
local CUT = { "Set", "Backdrop", "Props", "Camp" }
-- Children kept whole as one chunk each (the Nook popped in at 450 studs).
local WHOLE = { "Nook", "SpawnPoints" }
-- A child Model bigger than this is cut too, one level down: a kit set's pieces (the Camp's CampSet) are one Model.
local SPLIT = 800

local switchOn = false
local chunks: { [string]: { Chunk } } = {} -- area id: its chunks
local holds: { [Player]: Hold } = {}
local dropping: { [Player]: { Chunk } } = {} -- chunks of an area let go, taken off a few at a time
local flying: { [Player]: AreaWhole.Flight } = {} -- a cannon flight's destination, until they stand in it
local outSince: { [Player]: number } = {} -- when they left their held area for the street or a cafe

-- A piece's middle. Not its pivot: a kit set's pieces all pivot at the area's centre (Sync's re-test).
local function pieceAt(item: Instance): Vector3?
	if item:IsA("Model") then
		local box = (item :: Model):GetBoundingBox()
		return box.Position
	elseif item:IsA("BasePart") then
		return (item :: BasePart).Position
	end
	return nil
end

local function sizeOf(item: Instance): number
	return #item:GetDescendants() + 1
end

-- Cuts `container`'s direct children into one Default Model per ground cell and adds the chunks to `into`. A child
-- Model over SPLIT instances (and not Atomic or Persistent, whose wholeness something relies on) is cut in turn.
local function cut(container: Instance, into: { Chunk }, depth: number?)
	local groups: { [string]: { Instance } } = {}
	for _, child in container:GetChildren() do
		local at = pieceAt(child)
		if
			at ~= nil
			and (depth or 0) == 0
			and child:IsA("Model")
			and (child :: Model).ModelStreamingMode == Enum.ModelStreamingMode.Default
			and sizeOf(child) > SPLIT
		then
			cut(child, into, 1)
		elseif at ~= nil then
			local key = AreaWhole.cell(at)
			local group = groups[key]
			if group == nil then
				group = {}
				groups[key] = group
			end
			table.insert(group, child)
		end
	end
	for _, group in groups do
		local model = Instance.new("Model")
		model.Name = AreaWhole.CHUNK
		model.ModelStreamingMode = Enum.ModelStreamingMode.Default
		local size = 1
		for _, child in group do
			child.Parent = model
			size += sizeOf(child)
		end
		model.Parent = container
		table.insert(into, {
			model = model,
			at = model:GetBoundingBox().Position,
			size = size,
			mode = Enum.ModelStreamingMode.Default,
		})
	end
end

local function cutAll()
	local ok, world = pcall(PlotService.world)
	if not ok or world == nil then
		return
	end
	for id, info in world.areas do
		local list: { Chunk } = {}
		for _, name in CUT do
			local container = info.model:FindFirstChild(name)
			if container ~= nil then
				cut(container, list)
			end
		end
		for _, name in WHOLE do
			local whole = info.model:FindFirstChild(name)
			if whole ~= nil and whole:IsA("Model") then
				local wholeModel = whole :: Model
				local mode = wholeModel.ModelStreamingMode
				-- one already Persistent (the Alleyway's spawn points) is on every device anyway
				if mode ~= Enum.ModelStreamingMode.Persistent then
					table.insert(list, {
						model = wholeModel,
						at = wholeModel:GetBoundingBox().Position,
						size = sizeOf(wholeModel),
						mode = mode,
					})
				end
			end
		end
		chunks[id] = list
	end
end

-- Lets go of the player's held area: its chunks come off a few at a time too (Sync: Snowy's Set, let go in one
-- frame, cost 278 ms on the client).
local function release(player: Player)
	local hold = holds[player]
	holds[player] = nil
	if hold == nil then
		return
	end
	local queue = dropping[player]
	if queue == nil then
		queue = {}
		dropping[player] = queue
	end
	for _, chunk in hold.added do
		table.insert(queue :: { Chunk }, chunk)
	end
end

local function dropNow(player: Player, chunk: Chunk)
	pcall(function()
		chunk.model:RemovePersistentPlayer(player)
	end)
end

-- Where the chunks should start from: the landing pad on a flight, else the character.
local function aimFor(player: Player, areaId: string): Vector3?
	if flying[player] ~= nil then
		local pad = Layout.landingPads[areaId]
		if pad ~= nil then
			return Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z)
		end
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function keep(player: Player, areaId: string?)
	local hold = holds[player]
	if hold ~= nil and hold.area == areaId then
		return
	end
	release(player)
	local list = if areaId ~= nil then chunks[areaId] else nil
	if areaId == nil or list == nil or #list == 0 then
		return
	end
	-- A chunk of this area still waiting to come off (a quick trip out and back) stays on, and is not sent again.
	local mine: { [Model]: boolean } = {}
	for _, chunk in list do
		mine[chunk.model] = true
	end
	local kept: { Chunk } = {}
	local still: { Chunk } = {}
	for _, chunk in dropping[player] or {} do
		table.insert(if mine[chunk.model] then kept else still, chunk)
	end
	dropping[player] = if #still > 0 then still else nil
	local have: { [Model]: boolean } = {}
	for _, chunk in kept do
		have[chunk.model] = true
	end
	local waiting: { Chunk } = {}
	for _, chunk in list do
		if not have[chunk.model] then
			table.insert(waiting, chunk)
		end
	end
	local aim = aimFor(player, areaId)
	if aim ~= nil then
		local from = aim :: Vector3
		table.sort(waiting, function(a: Chunk, b: Chunk): boolean
			return (a.at - from).Magnitude < (b.at - from).Magnitude
		end)
	end
	holds[player] = { area = areaId, added = kept, waiting = waiting }
end

-- One SPREAD step: each player gets the next few waiting chunks, up to AreaWhole.BUDGET instances, and with what
-- is left of it the next few of a let-go area come off (one at least when none went on).
local function spread()
	for _, player in Players:GetPlayers() do
		local hold = holds[player]
		local spent = 0
		if hold ~= nil and #hold.waiting > 0 then
			local sizes: { number } = {}
			for _, chunk in hold.waiting do
				table.insert(sizes, chunk.size)
			end
			for _ = 1, AreaWhole.take(sizes) do
				local chunk = table.remove(hold.waiting, 1) :: Chunk
				spent += chunk.size
				local ok = pcall(function()
					chunk.model:AddPersistentPlayer(player)
				end)
				if ok then
					table.insert(hold.added, chunk)
				end
			end
		end
		local queue = dropping[player]
		if queue ~= nil then
			local sizes: { number } = {}
			for _, chunk in queue do
				table.insert(sizes, chunk.size)
			end
			-- one at least when nothing went on, else only what fits in the rest of the budget
			local count = AreaWhole.take(sizes, AreaWhole.BUDGET - spent, spent == 0)
			for _ = 1, count do
				dropNow(player, table.remove(queue, 1) :: Chunk)
			end
			if #queue == 0 then
				dropping[player] = nil
			end
		end
	end
end

local function standingIn(player: Player): string?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local ok, world = pcall(PlotService.world)
	if not ok or world == nil then
		return nil
	end
	return WorldBuilder.areaAt(world, (root :: BasePart).Position)
end

local function apply(on: boolean)
	switchOn = on
	if not on then
		-- Review-QA: take everyone off every list by hand, since a mode change may not clear them, so a later switch
		-- on starts clean. The chunks go back to their own mode below, so the device cost is the same.
		for player, hold in holds do
			for _, chunk in hold.added do
				dropNow(player, chunk)
			end
		end
		for player, queue in dropping do
			for _, chunk in queue do
				dropNow(player, chunk)
			end
		end
		table.clear(holds)
		table.clear(dropping)
		table.clear(flying)
		table.clear(outSince)
	end
	for _, list in chunks do
		for _, chunk in list do
			local mode = if on then AreaWhole.mode(true) else chunk.mode
			if chunk.model.ModelStreamingMode ~= mode then
				chunk.model.ModelStreamingMode = mode
			end
		end
	end
end

local function step()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local hold = holds[player]
		local here = standingIn(player)
		if here ~= nil or hold == nil then
			outSince[player] = nil
		elseif outSince[player] == nil then
			outSince[player] = now
		end
		local area, flightStands = AreaWhole.pick(
			flying[player],
			now,
			here,
			if hold ~= nil then hold.area else nil,
			outSince[player]
		)
		if not flightStands then
			flying[player] = nil
		end
		keep(player, area)
	end
end

-- A cannon flight to `areaId` has started (CannonService): the device gets that area during the flight, from the
-- landing pad out. The town and anything that is not a catching area are left alone.
function AreaWholeService.heading(player: Player, areaId: string)
	if not switchOn or chunks[areaId] == nil then
		return
	end
	flying[player] = { area = areaId, untilAt = os.clock() + AreaWhole.FLIGHT_HOLD }
	outSince[player] = nil
	keep(player, areaId)
end

-- The area this player's device is keeping whole (or getting), or nil (Debug and specs).
function AreaWholeService.heldBy(player: Player): string?
	local hold = holds[player]
	return if hold ~= nil then hold.area else nil
end

function AreaWholeService.start()
	cutAll()
	Players.PlayerRemoving:Connect(function(player: Player)
		holds[player] = nil
		dropping[player] = nil
		flying[player] = nil
		outSince[player] = nil
	end)
	task.spawn(function()
		while true do
			if switchOn then
				xpcall(spread, function(err: unknown)
					warn("[AreaWholeService] " .. tostring(err))
				end)
			end
			task.wait(AreaWhole.SPREAD)
		end
	end)
	task.spawn(function()
		local last: boolean? = nil
		while true do
			local on = LiveFlagService.on(AreaWhole.FLAG)
			if on ~= last then
				last = on
				apply(on)
			end
			if on then
				xpcall(step, function(err: unknown)
					warn("[AreaWholeService] " .. tostring(err))
				end)
			end
			task.wait(AreaWhole.STEP)
		end
	end)
end

return AreaWholeService
