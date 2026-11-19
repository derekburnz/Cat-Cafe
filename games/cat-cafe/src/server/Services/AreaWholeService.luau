--!strict
-- Derek 2026-11-18: the areaWhole switch (shared/AreaWhole). At start each catching area's Set and Backdrop are cut
-- into ground-cell chunks (Default Models, so nothing changes while the switch is off). With it on, the chunks turn
-- PersistentPerPlayer and each player is added to the chunks of the one area they stand in (WorldBuilder.areaAt) or
-- fly to, a few chunks every AreaWhole.SPREAD seconds and nearest first, so the area arrives over a couple of
-- seconds and not in one frame. The area they held before is let go at once for another area, or RELEASE_AFTER
-- seconds after they left it for the street or a cafe. A cannon flight calls AreaWholeService.heading at launch, so
-- the area streams in during the flight, starting at the landing pad.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaWhole = require(ReplicatedStorage.Shared.AreaWhole)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
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
-- A child Model bigger than this is cut too, down to MAX_DEPTH levels: a kit set's pieces (the Camp's CampSet) are one
-- Model, and one Park Set piece of 1,154 instances spans the whole set (Sync's round 3).
local SPLIT = 400
local MAX_DEPTH = 4

local switchOn = false
local chunks: { [string]: { Chunk } } = {} -- area id: its chunks
local holds: { [Player]: Hold } = {}
local dropping: { [Player]: { Chunk } } = {} -- chunks of an area let go, taken off a few at a time
local flying: { [Player]: AreaWhole.Flight } = {} -- a cannon flight's destination, until they stand in it
local outSince: { [Player]: number } = {} -- when they left their held area for the street or a cafe
-- #5381 areasKept: every unlocked area stays on the device. Chunks only ever go on, the area stood in first.
local keptOn = false
local keptHave: { [Player]: { [Model]: boolean } } = {} -- chunks on this player's list
local keptQueue: { [Player]: { Chunk } } = {} -- chunks still to add, in order
local keptAreas: { [Player]: { [string]: boolean } } = {} -- areas whose chunks are on or queued
local keptCurrent: { [Player]: string } = {} -- the area last put at the front

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
-- Model over SPLIT instances is cut in turn, unless something may rely on it staying whole: Atomic or Persistent, a
-- PrimaryPart, a tag, or a Motion _Swing piece.
local function cut(container: Instance, into: { Chunk }, depth: number?)
	local level = depth or 0
	local groups: { [string]: { Instance } } = {}
	for _, child in container:GetChildren() do
		local at = pieceAt(child)
		if
			at ~= nil
			and level < MAX_DEPTH
			and child:IsA("Model")
			and (child :: Model).ModelStreamingMode == Enum.ModelStreamingMode.Default
			and #child:GetChildren() > 1
			and (child :: Model).PrimaryPart == nil
			and #CollectionService:GetTags(child) == 0
			and not string.find(child.Name, "_Swing", 1, true)
			and sizeOf(child) > SPLIT
		then
			cut(child, into, level + 1)
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
	-- Sync's round 3: one cell of the Alleyway's Props held 1,918 instances, so a cell's pieces are shared out
	-- between chunks of about BUDGET each.
	for _, group in groups do
		local model: Model? = nil
		local size = 0
		local function close()
			if model ~= nil then
				local done = model :: Model
				done.Parent = container
				table.insert(into, {
					model = done,
					at = done:GetBoundingBox().Position,
					size = size,
					mode = Enum.ModelStreamingMode.Default,
				})
			end
			model = nil
			size = 0
		end
		for _, child in group do
			local piece = sizeOf(child)
			if model ~= nil and size + piece > AreaWhole.BUDGET then
				close()
			end
			if model == nil then
				local made = Instance.new("Model")
				made.Name = AreaWhole.CHUNK
				made.ModelStreamingMode = Enum.ModelStreamingMode.Default
				model = made
				size = 1
			end
			child.Parent = model
			size += piece
		end
		close()
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
	local all: { Chunk } = list :: { Chunk }
	local mine: { [Model]: boolean } = {}
	for _, chunk in all do
		mine[chunk.model] = true
	end
	local kept: { Chunk } = {}
	local still: { Chunk } = {}
	local queue: { Chunk } = dropping[player] or {}
	for _, chunk in queue do
		if mine[chunk.model] then
			table.insert(kept, chunk)
		else
			table.insert(still, chunk)
		end
	end
	if #still > 0 then
		dropping[player] = still
	else
		dropping[player] = nil
	end
	local have: { [Model]: boolean } = {}
	for _, chunk in kept do
		have[chunk.model] = true
	end
	local waiting: { Chunk } = {}
	for _, chunk in all do
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

-- #5381: the areas this player has unlocked (CatService's gate or tier), in a fixed order.
local function unlockedAreas(player: Player): { string }
	local DataService = require(script.Parent.DataService) :: any
	local CatService = require(script.Parent.CatService) :: any
	local profile = DataService.get(player)
	local list: { string } = {}
	if profile == nil then
		return list
	end
	for id in chunks do
		local ok, open = pcall(CatService.areaUnlocked, profile, id)
		if ok and open == true then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- #5381: puts `areaId`'s chunks that are not on the device yet at the front of the player's queue, nearest the
-- character (or the landing pad on a flight) first.
local function keptFront(player: Player, areaId: string)
	local list = chunks[areaId]
	if list == nil then
		return
	end
	keptCurrent[player] = areaId
	local have = keptHave[player] or {}
	keptHave[player] = have
	local areas = keptAreas[player] or {}
	keptAreas[player] = areas
	local inArea: { [Model]: boolean } = {}
	for _, chunk in list do
		inArea[chunk.model] = true
	end
	local front: { Chunk } = {}
	local rest: { Chunk } = {}
	for _, chunk in keptQueue[player] or {} do
		table.insert(if inArea[chunk.model] then front else rest, chunk)
	end
	if not areas[areaId] then
		areas[areaId] = true
		for _, chunk in list do
			if not have[chunk.model] then
				table.insert(front, chunk)
			end
		end
	end
	local aim = aimFor(player, areaId)
	if aim ~= nil then
		local from = aim :: Vector3
		table.sort(front, function(a: Chunk, b: Chunk): boolean
			return (a.at - from).Magnitude < (b.at - from).Magnitude
		end)
	end
	for _, chunk in rest do
		table.insert(front, chunk)
	end
	keptQueue[player] = front
end

-- #5381: the area stood in (or flown to) goes first; every other unlocked area not queued yet goes on the end.
local function keptStep(player: Player, area: string?)
	if area ~= nil and keptCurrent[player] ~= area then
		keptFront(player, area)
	end
	local have = keptHave[player] or {}
	keptHave[player] = have
	local areas = keptAreas[player] or {}
	keptAreas[player] = areas
	local queue = keptQueue[player] or {}
	keptQueue[player] = queue
	for _, id in unlockedAreas(player) do
		if not areas[id] then
			areas[id] = true
			for _, chunk in chunks[id] do
				if not have[chunk.model] then
					table.insert(queue, chunk)
				end
			end
		end
	end
end

-- #5381: areasKept off (or areaWhole off): everything kept comes off a few at a time, as a let-go area does.
local function keptRelease()
	for player, have in keptHave do
		local queue = dropping[player] or {}
		for model in have do
			table.insert(queue, {
				model = model,
				at = Vector3.zero,
				size = sizeOf(model),
				mode = model.ModelStreamingMode,
			})
		end
		if #queue > 0 then
			dropping[player] = queue
		end
	end
	table.clear(keptHave)
	table.clear(keptQueue)
	table.clear(keptAreas)
	table.clear(keptCurrent)
end

-- #5381: areasKept on: what the player's held area already has stays on and counts as kept.
local function keptTake()
	for player, hold in holds do
		local have = keptHave[player] or {}
		keptHave[player] = have
		for _, chunk in hold.added do
			have[chunk.model] = true
		end
		local queue = dropping[player]
		if queue ~= nil then
			-- a let-go area's chunks still waiting to come off stay on now
			for _, chunk in queue do
				have[chunk.model] = true
			end
			dropping[player] = nil
		end
	end
	table.clear(holds)
end

-- One SPREAD step: each player gets the next few waiting chunks, up to AreaWhole.BUDGET instances, and with what
-- is left of it the next few of a let-go area come off (one at least when none went on).
-- `tick` counts FLIGHT_SPREAD steps: a player on a cannon flight is fed every one, everyone else every SPREAD.
local function spread(tick: number)
	local every = math.max(1, math.round(AreaWhole.SPREAD / AreaWhole.FLIGHT_SPREAD))
	for _, player in Players:GetPlayers() do
		if flying[player] == nil and tick % every ~= 0 then
			continue
		end
		local hold = holds[player]
		local spent = 0
		local kept = keptQueue[player]
		if keptOn and kept ~= nil and #kept > 0 then
			local have = keptHave[player] or {}
			keptHave[player] = have
			local sizes: { number } = {}
			for _, chunk in kept do
				table.insert(sizes, chunk.size)
			end
			for _ = 1, AreaWhole.take(sizes) do
				local chunk = table.remove(kept, 1) :: Chunk
				spent += chunk.size
				local ok = pcall(function()
					chunk.model:AddPersistentPlayer(player)
				end)
				if ok then
					have[chunk.model] = true
				end
			end
		elseif hold ~= nil and #hold.waiting > 0 then
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
		for player, have in keptHave do
			for model in have do
				pcall(function()
					model:RemovePersistentPlayer(player)
				end)
			end
		end
		table.clear(holds)
		table.clear(dropping)
		table.clear(flying)
		table.clear(outSince)
		table.clear(keptHave)
		table.clear(keptQueue)
		table.clear(keptAreas)
		table.clear(keptCurrent)
		keptOn = false
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
		if keptOn then
			keptStep(player, area)
		else
			keep(player, area)
		end
	end
end

-- A cannon flight to `areaId` has started (CannonService): the device gets that area during the flight, from the
-- landing pad out. The town and anything that is not a catching area are left alone. True when it took the flight:
-- the caller then skips its launch stream-around, which pulled every chunk near the pad at once (Sync's round 3:
-- chunks are Atomic for a player not yet on their list).
function AreaWholeService.heading(player: Player, areaId: string): boolean
	if not switchOn or chunks[areaId] == nil then
		return false
	end
	flying[player] = { area = areaId, untilAt = os.clock() + AreaWhole.FLIGHT_HOLD }
	outSince[player] = nil
	if keptOn then
		keptFront(player, areaId)
	else
		keep(player, areaId)
	end
	return true
end

-- The area this player's device is keeping whole (or getting), or nil (Debug and specs).
function AreaWholeService.heldBy(player: Player): string?
	if keptOn then
		return keptCurrent[player]
	end
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
		keptHave[player] = nil
		keptQueue[player] = nil
		keptAreas[player] = nil
		keptCurrent[player] = nil
	end)
	task.spawn(function()
		local tick = 0
		while true do
			tick += 1
			if switchOn then
				xpcall(spread, function(err: unknown)
					warn("[AreaWholeService] " .. tostring(err))
				end, tick)
			end
			task.wait(AreaWhole.FLIGHT_SPREAD)
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
			local kept = on
				and table.find(LiveFlags.KEYS, AreaWhole.KEPT_FLAG) ~= nil
				and LiveFlagService.on(AreaWhole.KEPT_FLAG)
			if on and kept ~= keptOn then
				keptOn = kept
				if kept then
					keptTake()
				else
					keptRelease()
				end
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
