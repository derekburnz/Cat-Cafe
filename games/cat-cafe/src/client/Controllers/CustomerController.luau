--!strict
-- Cosmetic customers (features.md F15, F37). Runs entirely on this client: customers walk into every running cafe
-- within Config.World.CafeLifeRangeStuds of the camera, not just this player's own, so the street looks busy
-- (world-and-feel.md section 4). Each one walks in from the street, orders at the counter, takes a free chair,
-- sits a while and walks out. Between the counter and a chair it keeps to the aisle and the walkway beside the
-- chair's row (the chair's Aisle and Approach attributes), and leaves the same way, so it never cuts through a table. Coin text pops only over this player's own cafe. The cafe closes at night (v0.5 F44):
-- no customers come, and at nightfall the ones inside skip the rest of their visit and walk out.
-- A rich customer (F31, data-model section 12) comes to any nearby cafe whose plot shows a rich tip
-- (RichTipAmount), sits at table 1 beside the gold coin pile on its RichTipAnchor and stays until the tip is paid.
-- The server decides the tip; this is only what the street sees.
-- A customer model carries Order ("coffee", "cake" or "milk") from the counter on and Served once it sits, for the
-- order bubble and the heart.
-- Tip piles (F61, data-model section 12): while a plot's TipPiles is above 0, that many small coin piles sit on its
-- tables, each on the table a customer last left (else the table with the fewest), in a ring round the middle so
-- table 1's rich tip keeps the centre. They vanish when the count drops; on your own cafe walking within
-- TipPileCollectRangeStuds of one sends CollectTips, and the collect floats "+$" with TipPilesAmount.
-- The Mystery Visitor (F64, data-model 12b) is built the same way from its plot's attributes: while
-- MysteryVisitorUntil is ahead, a hooded visitor sits at the MysteryTable chair nearest the gift, and while
-- MysteryGiftAt is set the wrapped gift sits on the plot's MysteryGiftAnchor. Both are models under the plot, tagged
-- MysteryVisitor and MysteryGift for the puffs, sparkle and ribbon pop (Effects/Mystery); the server holds the gift.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Effects = require(script.Parent.Parent.Effects)
local Moments = require(script.Parent.Parent.Moments)
local Mover = require(Shared:WaitForChild("Mover"))
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CustomerController = {}

local rng = Random.new()
local folder: Folder? = nil
local busySeats: { [BasePart]: boolean } = {}
local activeByPlot: { [Model]: number } = {}
local activeCustomers = 0
local variants = { "A", "B", "C" }
local orders = { "coffee", "cake", "milk" }
local clock: Instance? = nil -- ReplicatedStorage.Clock once it has replicated
local richVisits: { [Model]: boolean } = {} -- plots with a rich customer on the way or seated
local coinPiles: { [Model]: Model } = {} -- plot -> the coin pile on its RichTipAnchor while a tip shows
-- A plot's Mystery Visitor (and the seat it holds) and gift while this client shows them (F64).
type Mystery = { visitor: Model?, seat: BasePart?, gift: Model? }
local mysteries: { [Model]: Mystery } = {}
local watchedPlots: { [Model]: boolean } = {} -- plots whose Mystery attributes this client follows
-- Tip piles (F61): the piles this client shows per plot, and the tables customers just left (newest last).
type Pile = { model: Model, tableModel: Model, slot: number }
local tipPiles: { [Model]: { Pile } } = {}
local leftTables: { [Model]: { Model } } = {}
local tipAmounts: { [Model]: number } = {} -- each shown plot's TipPilesAmount, for the "+$" when it is collected
local collectSentAt = -math.huge -- os.clock() of the last CollectTips

-- How a customer visits: which model, and for a rich customer how long it stays (while its tip shows).
type Visit = {
	asset: string,
	staysWhile: (() -> boolean)?,
}

local function isDay(): boolean
	return clock == nil or clock:GetAttribute("Phase") ~= "night"
end

local function container(): Folder
	if folder ~= nil then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "LocalCustomers"
	created.Parent = Workspace
	folder = created
	return created
end

local function isOwnPlot(plot: Model): boolean
	local state = UIController.state
	return state ~= nil
		and state.plotIndex ~= 0
		and plot:GetAttribute("PlotIndex") == state.plotIndex
end

-- Cafes that take customers now: owned, earning, and near the camera.
local function runningPlots(): { Model }
	local found: { Model } = {}
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	local camera = Workspace.CurrentCamera
	if plots == nil or camera == nil then
		return found
	end
	local eye = camera.CFrame.Position
	for _, plot in plots:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		local model = plot :: Model
		local owner = model:GetAttribute("OwnerUserId")
		local rate = model:GetAttribute("Rate")
		local running = type(owner) == "number"
			and owner ~= 0
			and type(rate) == "number"
			and rate > 0
		-- this player's own cafe also runs on the synced rate, before the plot attribute has replicated
		if not running and isOwnPlot(model) then
			local state = UIController.state
			running = state ~= nil and state.incomePerSecond > 0
		end
		if
			running
			and (model:GetPivot().Position - eye).Magnitude <= Config.World.CafeLifeRangeStuds
		then
			table.insert(found, model)
		end
	end
	return found
end

local function waypoint(plot: Model, name: string): Vector3?
	local waypoints = plot:FindFirstChild("CustomerWaypoints")
	local point = if waypoints ~= nil then waypoints:FindFirstChild(name) else nil
	return if point ~= nil and point:IsA("BasePart") then (point :: BasePart).Position else nil
end

local function freeSeat(plot: Model): (BasePart?, BasePart?)
	local tables = plot:FindFirstChild("Tables")
	if tables == nil then
		return nil, nil
	end
	local candidates: { { seat: BasePart, tableTop: BasePart? } } = {}
	for _, group in tables:GetChildren() do
		local tableTop = group:FindFirstChild("Top", true)
		for _, child in group:GetChildren() do
			if child.Name:match("^Chair_") and child:IsA("Model") then
				local seat = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
				if seat ~= nil and not busySeats[seat] then
					table.insert(candidates, {
						seat = seat,
						tableTop = if tableTop ~= nil and tableTop:IsA("BasePart")
							then tableTop :: BasePart
							else nil,
					})
				end
			end
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	return pick.seat, pick.tableTop
end

-- The points between the aisle and `seat`, from its chair's Aisle and Approach (CafeService); none on an old chair.
local function seatRoute(seat: BasePart): { Vector3 }
	local chair = seat:FindFirstAncestorWhichIsA("Model")
	while chair ~= nil and not chair.Name:match("^Chair_") do
		chair = chair:FindFirstAncestorWhichIsA("Model")
	end
	local route: { Vector3 } = {}
	if chair ~= nil then
		for _, name in { "Aisle", "Approach" } do
			local point = chair:GetAttribute(name)
			if typeof(point) == "Vector3" then
				table.insert(route, point)
			end
		end
	end
	return route
end

-- The table (not a chair) in the Tables group `seat` belongs to.
local function tableModelOf(seat: BasePart): Model?
	local group: Instance? = seat
	while group ~= nil and not group.Name:match("^table_") do
		group = group.Parent
	end
	if group == nil then
		return nil
	end
	for _, child in group:GetChildren() do
		if child:IsA("Model") and not child.Name:match("^Chair_") then
			return child :: Model
		end
	end
	return nil
end

local function runCustomer(plot: Model, seat: BasePart, tableTop: BasePart?, visit: Visit?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local assetName = if visit ~= nil
		then visit.asset
		else "CatCafe_NPC_Customer_" .. variants[rng:NextInteger(1, #variants)]
	local source = if assets ~= nil then assets:FindFirstChild(assetName) else nil
	local entry = waypoint(plot, "Entry")
	local door = waypoint(plot, "Door")
	local order = waypoint(plot, "Order")
	if source == nil or entry == nil or door == nil then
		return
	end
	busySeats[seat] = true
	activeCustomers += 1
	activeByPlot[plot] = (activeByPlot[plot] or 0) + 1
	local cloned = source:Clone()
	if not cloned:IsA("Model") then
		cloned:Destroy()
		busySeats[seat] = nil
		activeCustomers -= 1
		activeByPlot[plot] = math.max(0, (activeByPlot[plot] or 1) - 1)
		return
	end
	local model = cloned :: Model
	local alive = true
	local function isAlive(): boolean
		return alive and seat.Parent ~= nil and plot.Parent ~= nil
	end
	model.Name = "Customer"
	model:PivotTo(CFrame.new(entry))
	model.Parent = container()

	local seatPosition = Vector3.new(seat.Position.X, entry.Y, seat.Position.Z)
	local route = seatRoute(seat)
	local walked = 0 -- how many route points it reached, to retrace on the way out
	local sat = false
	local speed = Config.CustomerWalkSpeed
	local arrived = Mover.walkTo(model, door, speed, isAlive)
	-- order at the counter, standing a little to one side so a queue spreads out
	if arrived and order ~= nil and (visit ~= nil or isDay()) then
		local counter = order :: Vector3
		local inward = ((counter - door) * Vector3.new(1, 0, 1)).Unit -- from the door toward the counter
		local spot = Vector3.new(counter.X, entry.Y, counter.Z)
			+ inward:Cross(Vector3.yAxis) * rng:NextNumber(-3, 3)
		arrived = Mover.walkTo(model, spot, speed, isAlive)
		if arrived then
			Mover.face(model, spot + inward)
			model:SetAttribute("Order", orders[rng:NextInteger(1, #orders)])
			task.wait(Config.World.CustomerOrderSeconds)
		end
	end
	for _, point in route do
		if not (arrived and (visit ~= nil or isDay())) then
			break
		end
		arrived = Mover.walkTo(model, Vector3.new(point.X, entry.Y, point.Z), speed, isAlive)
		if arrived then
			walked += 1
		end
	end
	if
		arrived
		and (visit ~= nil or isDay())
		and Mover.walkTo(model, seatPosition, speed, isAlive)
	then
		if tableTop ~= nil then
			Mover.face(model, tableTop.Position)
		end
		model:SetAttribute("Served", true)
		sat = true
		local own = isOwnPlot(plot)
		local stay = rng:NextNumber(Config.CustomerStayMin, Config.CustomerStayMax)
		local elapsed = 0
		local staysWhile = if visit ~= nil then visit.staysWhile else nil
		local function staying(): boolean
			if staysWhile ~= nil then
				return staysWhile()
			end
			return elapsed < stay and isDay()
		end
		while isAlive() and staying() do
			task.wait(Config.CustomerCoinPopSeconds)
			elapsed += Config.CustomerCoinPopSeconds
			if own then
				local state = UIController.state
				local rate = if state ~= nil then state.incomePerSecond else 0
				local tip = math.max(
					1,
					math.floor(
						rate * Config.CustomerCoinPopSeconds / math.max(1, activeByPlot[plot] or 1)
					)
				)
				local above = model:GetPivot().Position + Vector3.new(0, 5.5, 0)
				UI.floatText(above, "+$" .. tip)
				Moments.CoinPop:Fire(above)
			end
		end
	end
	-- a tip pile that comes next goes on the table this customer just left (F61)
	if sat and visit == nil then
		local tableModel = tableModelOf(seat)
		if tableModel ~= nil then
			local recent = leftTables[plot] or {}
			table.insert(recent, tableModel)
			if #recent > Config.TipPilesMax then
				table.remove(recent, 1)
			end
			leftTables[plot] = recent
		end
	end
	-- out again: after the visit, or at once when the cafe closes for the night on the way in
	if isAlive() then
		for i = walked, 1, -1 do
			Mover.walkTo(model, Vector3.new(route[i].X, entry.Y, route[i].Z), speed, isAlive)
		end
		Mover.walkTo(model, door, speed, isAlive)
		Mover.walkTo(model, entry, speed, isAlive)
	end
	alive = false
	model:Destroy()
	busySeats[seat] = nil
	activeCustomers -= 1
	local left = (activeByPlot[plot] or 1) - 1
	if left > 0 then
		activeByPlot[plot] = left
	else
		activeByPlot[plot] = nil
	end
end

-- A rich tip shows on the plot (the server mirrors its amount and expiry for display).
local function tipShows(plot: Model): boolean
	local amount = plot:GetAttribute("RichTipAmount")
	local expiresAt = plot:GetAttribute("RichTipExpiresAt")
	return type(amount) == "number"
		and amount > 0
		and type(expiresAt) == "number"
		and expiresAt > Workspace:GetServerTimeNow()
end

local function tipAnchor(plot: Model): BasePart?
	local anchor = plot:FindFirstChild("RichTipAnchor")
	return if anchor ~= nil and anchor:IsA("BasePart") then anchor :: BasePart else nil
end

-- A free chair at table 1, the table under the coin pile.
local function richSeat(plot: Model): (BasePart?, BasePart?)
	local tables = plot:FindFirstChild("Tables")
	local group = if tables ~= nil then tables:FindFirstChild("table_1") else nil
	if group == nil then
		return nil, nil
	end
	local tableTop = group:FindFirstChild("Top", true)
	for _, child in group:GetChildren() do
		if child.Name:match("^Chair_") and child:IsA("Model") then
			local seat = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
			if seat ~= nil and not busySeats[seat] then
				return seat,
					if tableTop ~= nil and tableTop:IsA("BasePart")
						then tableTop :: BasePart
						else nil
			end
		end
	end
	return nil, nil
end

-- A few gold coins stacked on the anchor (its centre sits just over the table top), local to this client.
local function buildCoinPile(anchor: BasePart): Model
	local pile = Instance.new("Model")
	pile.Name = "RichTipCoins"
	local top = anchor.Position.Y - anchor.Size.Y / 2 + 0.4 -- the table top under the anchor
	local stacks = { { x = -0.35, z = 0.1, coins = 4 }, { x = 0.4, z = -0.15, coins = 2 } }
	for _, stack in stacks do
		for n = 1, stack.coins do
			local coin = Instance.new("Part")
			coin.Name = "Coin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.14, 0.7, 0.7)
			coin.Color = Color3.fromRGB(255, 196, 56)
			coin.Material = Enum.Material.Metal
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.CastShadow = false
			local position = Vector3.new(
				anchor.Position.X + stack.x + rng:NextNumber(-0.04, 0.04),
				top + 0.07 + (n - 1) * 0.14,
				anchor.Position.Z + stack.z + rng:NextNumber(-0.04, 0.04)
			)
			coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) -- the round face up
			coin.Parent = pile
		end
	end
	pile.Parent = container()
	return pile
end

-- Once a second: a coin pile on every nearby cafe with a rich tip showing and a rich customer on the way to it;
-- piles go when the tip is paid or the cafe is out of range.
local function updateRich()
	local nearby: { [Model]: boolean } = {}
	for _, plot in runningPlots() do
		if not tipShows(plot) then
			continue
		end
		nearby[plot] = true
		local anchor = tipAnchor(plot)
		if anchor ~= nil and not coinPiles[plot] then
			coinPiles[plot] = buildCoinPile(anchor)
		end
		if not richVisits[plot] and isDay() then -- a rich customer already seated stays for its tip at nightfall
			local seat, tableTop = richSeat(plot)
			if seat ~= nil then
				richVisits[plot] = true
				task.spawn(function()
					runCustomer(plot, seat, tableTop, {
						asset = "CatCafe_NPC_Customer_Rich",
						staysWhile = function()
							local amount = plot:GetAttribute("RichTipAmount")
							return type(amount) == "number" and amount > 0
						end,
					})
					richVisits[plot] = nil
				end)
			end
		end
	end
	for plot, pile in coinPiles do
		if not nearby[plot] then
			pile:Destroy()
			coinPiles[plot] = nil
		end
	end
end

-- The Mystery Visitor and its gift (F64) ------------------------------------------------------------------------

local function plotsFolder(): Instance?
	local world = Workspace:FindFirstChild("World")
	return if world ~= nil then world:FindFirstChild("Plots") else nil
end

local function nearCamera(plot: Model): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil
		and (plot:GetPivot().Position - camera.CFrame.Position).Magnitude
			<= Config.World.CafeLifeRangeStuds
end

-- A Mystery model from ReplicatedStorage.Assets at `at` under the plot, tagged for the effects; nil without it.
local function buildMystery(plot: Model, assetName: string, tag: string, at: CFrame): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil then assets:FindFirstChild(assetName) else nil
	if source == nil then
		return nil
	end
	local cloned = source:Clone()
	if not cloned:IsA("Model") then
		cloned:Destroy()
		return nil
	end
	local model = cloned :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model:PivotTo(at)
	CollectionService:AddTag(model, tag)
	model.Parent = plot
	return model
end

-- The chair at the plot's MysteryTable for the visitor: the one nearest the gift that no customer holds, else the
-- nearest; and the table top it faces.
local function mysterySeat(plot: Model): (BasePart?, BasePart?)
	local tables = plot:FindFirstChild("Tables")
	local index = plot:GetAttribute("MysteryTable")
	local group = if tables ~= nil and type(index) == "number"
		then tables:FindFirstChild("table_" .. index)
		else nil
	if group == nil then
		return nil, nil
	end
	local top = group:FindFirstChild("Top", true)
	local tableTop = if top ~= nil and top:IsA("BasePart") then top :: BasePart else nil
	local anchor = plot:FindFirstChild("MysteryGiftAnchor")
	local toward = if anchor ~= nil and anchor:IsA("BasePart")
		then (anchor :: BasePart).Position
		elseif tableTop ~= nil then tableTop.Position
		else nil
	local best: BasePart? = nil
	local bestScore = math.huge
	for _, child in group:GetChildren() do
		if child.Name:match("^Chair_") and child:IsA("Model") then
			local seat = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
			if seat ~= nil then
				local score = (if toward ~= nil then (seat.Position - toward).Magnitude else 0)
					+ (if busySeats[seat] then 1000 else 0)
				if score < bestScore then
					best, bestScore = seat, score
				end
			end
		end
	end
	return best, tableTop
end

-- Builds or clears this plot's visitor and gift to match its attributes now.
local function refreshMystery(plot: Model)
	local shown: Mystery = mysteries[plot] or { visitor = nil, seat = nil, gift = nil }
	mysteries[plot] = shown
	local inRange = plot.Parent ~= nil and nearCamera(plot)
	local visitorUntil = plot:GetAttribute("MysteryVisitorUntil")
	local wantVisitor = inRange
		and type(visitorUntil) == "number"
		and visitorUntil > Workspace:GetServerTimeNow()
	local visitor = shown.visitor
	if wantVisitor then
		local seat, tableTop = mysterySeat(plot)
		if visitor == nil and seat ~= nil then
			local floorY = plot:GetPivot().Position.Y
			local position = Vector3.new(seat.Position.X, floorY, seat.Position.Z)
			local look = if tableTop ~= nil
				then Vector3.new(tableTop.Position.X, floorY, tableTop.Position.Z)
				else position + plot:GetPivot().LookVector
			shown.visitor = buildMystery(
				plot,
				"CatCafe_NPC_MysteryVisitor",
				"MysteryVisitor",
				CFrame.lookAt(position, look)
			)
			if shown.visitor ~= nil then
				shown.seat = seat
				busySeats[seat] = true
			end
		end
	elseif visitor ~= nil then
		visitor:Destroy()
		shown.visitor = nil
		local seat = shown.seat
		if seat ~= nil then
			busySeats[seat] = nil
			shown.seat = nil
		end
	end
	local giftAt = plot:GetAttribute("MysteryGiftAt")
	local anchor = plot:FindFirstChild("MysteryGiftAnchor")
	local wantGift = inRange
		and type(giftAt) == "number"
		and giftAt > 0
		and anchor ~= nil
		and anchor:IsA("BasePart")
	local gift = shown.gift
	if wantGift then
		if gift == nil then
			-- the anchor is a 1 stud box resting on the table top: the gift's base goes on its bottom face
			local base = (anchor :: BasePart).CFrame * CFrame.new(0, -0.5, 0)
			shown.gift = buildMystery(plot, "CatCafe_Item_MysteryGift", "MysteryGift", base)
		end
	elseif gift ~= nil then
		gift:Destroy()
		shown.gift = nil
	end
	if shown.visitor == nil and shown.gift == nil then
		mysteries[plot] = nil
	end
end

-- Once a second: every plot's visitor and gift follow the attributes and the camera's range; a plot is also
-- followed at once when its attributes change, so an opened gift goes before its ribbon pop.
local function updateMysteries()
	local plots = plotsFolder()
	if plots == nil then
		return
	end
	for _, child in plots:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		local plot = child :: Model
		if not watchedPlots[plot] then
			watchedPlots[plot] = true
			for _, name in { "MysteryVisitorUntil", "MysteryGiftAt", "MysteryTable" } do
				plot:GetAttributeChangedSignal(name):Connect(function()
					refreshMystery(plot)
				end)
			end
		end
		refreshMystery(plot)
	end
end

-- Tip piles (F61) ------------------------------------------------------------------------------------------------

local PILE_SLOTS = 6 -- per table, in a ring round the middle

-- The table models under a plot's Tables, one per table group.
local function tableModels(plot: Model): { Model }
	local found: { Model } = {}
	local tables = plot:FindFirstChild("Tables")
	if tables == nil then
		return found
	end
	for _, group in tables:GetChildren() do
		for _, child in group:GetChildren() do
			if child:IsA("Model") and not child.Name:match("^Chair_") then
				table.insert(found, child :: Model)
				break
			end
		end
	end
	return found
end

-- Where pile `slot` sits on `tableModel`: on its top, in a ring a third of the way out.
local function pileSpot(tableModel: Model, slot: number): Vector3
	local cframe, size = tableModel:GetBoundingBox()
	local radius = math.clamp(math.min(size.X, size.Z) * 0.32, 0.9, 2.5)
	local angle = math.rad(30 + (slot - 1) * (360 / PILE_SLOTS))
	local centre = cframe.Position
	return Vector3.new(
		centre.X + math.cos(angle) * radius,
		centre.Y + size.Y / 2,
		centre.Z + math.sin(angle) * radius
	)
end

-- A small pile of coins on a table top, smaller than the rich tip's, local to this client (tag TipPile).
local function buildTipPile(at: Vector3): Model
	local pile = Instance.new("Model")
	pile.Name = "TipPile"
	local stacks = { { x = 0, z = 0, coins = 2 }, { x = 0.3, z = 0.25, coins = 1 } }
	for _, stack in stacks do
		for n = 1, stack.coins do
			local coin = Instance.new("Part")
			coin.Name = "Coin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.12, 0.55, 0.55)
			coin.Color = Color3.fromRGB(255, 196, 56)
			coin.Material = Enum.Material.Metal
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.CastShadow = false
			local position = Vector3.new(
				at.X + stack.x + rng:NextNumber(-0.04, 0.04),
				at.Y + 0.06 + (n - 1) * 0.12,
				at.Z + stack.z + rng:NextNumber(-0.04, 0.04)
			)
			coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) -- the round face up
			coin.Parent = pile
		end
	end
	CollectionService:AddTag(pile, "TipPile")
	pile.Parent = container()
	return pile
end

-- One more pile on `plot`: on the table a customer last left if it has room, else the table with the fewest.
local function placePile(plot: Model, shown: { Pile }): boolean
	local used: { [Model]: { [number]: boolean } } = {}
	local counts: { [Model]: number } = {}
	for _, pile in shown do
		used[pile.tableModel] = used[pile.tableModel] or {}
		used[pile.tableModel][pile.slot] = true
		counts[pile.tableModel] = (counts[pile.tableModel] or 0) + 1
	end
	local function freeSlot(tableModel: Model): number?
		for slot = 1, PILE_SLOTS do
			if not (used[tableModel] ~= nil and used[tableModel][slot]) then
				return slot
			end
		end
		return nil
	end
	local pick: Model? = nil
	local slot: number? = nil
	local recent = leftTables[plot]
	while recent ~= nil and #recent > 0 and pick == nil do
		local candidate = table.remove(recent) :: Model
		if candidate.Parent ~= nil then
			slot = freeSlot(candidate)
			pick = if slot ~= nil then candidate else nil
		end
	end
	if pick == nil then
		for _, candidate in tableModels(plot) do
			local free = freeSlot(candidate)
			if
				free ~= nil
				and (pick == nil or (counts[candidate] or 0) < (counts[pick :: Model] or 0))
			then
				pick, slot = candidate, free
			end
		end
	end
	if pick == nil or slot == nil then
		return false
	end
	local tableModel = pick :: Model
	local at = slot :: number
	table.insert(shown, {
		model = buildTipPile(pileSpot(tableModel, at)),
		tableModel = tableModel,
		slot = at,
	})
	return true
end

local function clearPiles(plot: Model)
	local shown = tipPiles[plot]
	if shown ~= nil then
		for _, pile in shown do
			pile.model:Destroy()
		end
	end
	tipPiles[plot] = nil
	tipAmounts[plot] = nil
end

-- Matches every nearby plot's piles to its TipPiles. Your own piles going to none floats what they paid.
local function updatePiles()
	local plots = plotsFolder()
	local seen: { [Model]: boolean } = {}
	if plots ~= nil then
		for _, child in plots:GetChildren() do
			if not child:IsA("Model") then
				continue
			end
			local plot = child :: Model
			local raw = plot:GetAttribute("TipPiles")
			local count = if type(raw) == "number" then math.clamp(math.floor(raw), 0, 64) else 0
			local shown = tipPiles[plot]
			if count == 0 or not nearCamera(plot) then
				if shown ~= nil and #shown > 0 and count == 0 and isOwnPlot(plot) then
					local amount = tipAmounts[plot] or 0
					if amount > 0 then
						local above = shown[1].model:GetPivot().Position + Vector3.new(0, 2.5, 0)
						UI.floatText(above, "+$" .. amount)
						Moments.CoinPop:Fire(above)
					end
				end
				clearPiles(plot)
				continue
			end
			seen[plot] = true
			local list = shown or {}
			tipPiles[plot] = list
			while #list > count do
				local last = table.remove(list) :: Pile
				last.model:Destroy()
			end
			while #list < count do
				if not placePile(plot, list) then
					break -- every slot on every table is full
				end
			end
			local amount = plot:GetAttribute("TipPilesAmount")
			tipAmounts[plot] = if type(amount) == "number" then amount else 0
		end
	end
	for plot in tipPiles do
		if not seen[plot] then
			clearPiles(plot)
		end
	end
end

-- On your own cafe: within TipPileCollectRangeStuds of any of its piles sends CollectTips, once a second at most.
local function checkCollect()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or os.clock() - collectSentAt < 1 then
		return
	end
	local position = (root :: BasePart).Position
	for plot, shown in tipPiles do
		if not isOwnPlot(plot) then
			continue
		end
		for _, pile in shown do
			if
				(pile.model:GetPivot().Position - position).Magnitude
				<= Config.TipPileCollectRangeStuds
			then
				collectSentAt = os.clock()
				Net.fire("CollectTips")
				return
			end
		end
	end
end

function CustomerController.start()
	task.spawn(function()
		clock = ReplicatedStorage:WaitForChild("Clock")
	end)
	task.spawn(function()
		while true do
			task.wait(Config.CustomerSpawnSeconds)
			if not isDay() then
				continue -- closed for the night (F44)
			end
			-- one new customer per running cafe per tick, while seats and the street-wide cap allow (reviewer N59:
			-- fewer on a phone)
			local cap = if Effects.tier() == "low"
				then Config.World.CustomersMaxLow
				else Config.World.CustomersMax
			for _, plot in runningPlots() do
				if activeCustomers >= cap then
					break
				end
				local seat, tableTop = freeSeat(plot)
				if seat ~= nil then
					task.spawn(runCustomer, plot, seat, tableTop, nil)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			updateRich()
			updateMysteries()
		end
	end)
	-- tip piles (F61) a few times a second, so walking past one collects and a collect clears them at once
	task.spawn(function()
		while true do
			task.wait(0.25)
			updatePiles()
			checkCollect()
		end
	end)
end

return CustomerController
