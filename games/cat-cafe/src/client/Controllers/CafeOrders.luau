--!strict
-- Cats make the orders (F90, cats-make-orders.md), on this client only, like the customers they serve: the server, the
-- economy and the save never see an order.
--
-- CustomerController hands each customer's order over at the counter (order), waits there through atCounter, and
-- says when the customer sits (seated) and gets up to leave (left). Per cafe up to Config.World.OrderQueueMax orders
-- wait or are being made; a customer past that finds its dish on the table as it sits.
--
-- Making: a free Barista (a WorkingCat with Role "barista" in the plot's Cats, the one nearest the item's station
-- first) stays seated with the local attributes Making (the menu id) and MakeSeconds while it works, for the UI's
-- bubble with its filling ring and Animation's bob, and Moments.OrderMaking fires for the puff at the station (the
-- plot's Espresso or Oven model, or the Barista for the counter). When it is done the attributes clear, the dish
-- appears and Moments.OrderReady fires at the same station for the ding.
--
-- Your own cafe: as the making starts a free Waiter walks to the counter's Pickup point (Effects/CafeWalk), takes the
-- dish on its tray (CatCafe_Menu_Tray, or the dish alone without the tray's art), trots to the customer's table along
-- the chair's Aisle and Approach points, sets it down (Moments.OrderServed, and the customer's Served heart) and walks
-- back. With no Waiter working at all, the customer waits at the counter up to OrderHandOverSeconds and carries the
-- dish to its seat. Other cafes nearby show the making and the dish on the table, but no walks; on a phone or in Low
-- performance they show only the order bubble and the dish on the table.
--
-- When the customer leaves its plate stays empty OrderPlateSeconds, then fades. In your own cafe an idle Greeter (or
-- Waiter) sweeps each new tip pile TipSweepAfterSeconds after it appears into a coin bag on its head (TipSwept) and
-- drops it in the till (TipBanked): the server paid the pile as it appeared, so only where it sits changes.
--
-- Without a dish's art the flow still runs (bubbles, rings, walks and the heart) with nothing on the plate.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Types = require(Shared:WaitForChild("Types"))

local CafeOrders = {}

-- Effects and its CafeWalk load on first use, so the order rules can be required (and tested) without the rigs.
type CafeWalkApi = typeof(require(script.Parent.Parent.Effects.CafeWalk))
type EffectsApi = typeof(require(script.Parent.Parent.Effects))
local walkApi: CafeWalkApi? = nil
local effectsApi: EffectsApi? = nil
local function CafeWalk(): CafeWalkApi
	if walkApi == nil then
		walkApi = require(script.Parent.Parent.Effects.CafeWalk) :: any
	end
	return walkApi :: CafeWalkApi
end
local function lowTier(): boolean
	if effectsApi == nil then
		effectsApi = require(script.Parent.Parent.Effects) :: any
	end
	return (effectsApi :: EffectsApi).tier() == "low"
end

-- Where an order is served: the customer's seat, its chair (whose Aisle and Approach a Waiter walks), the table and
-- the spot on its top in front of the chair.
export type Place = {
	seat: BasePart,
	route: { Vector3 },
	tableModel: Model?,
	dishAt: CFrame?,
}

-- One customer's order. state: "queued" (waiting for a Barista), "making", "made" (the dish is ready and not yet on
-- the table), "table" (no making: the dish goes on the table as the customer sits), "served" (on the table) or
-- "gone" (the customer left before it was served).
export type Ticket = {
	plot: Model,
	item: Types.MenuItem,
	gold: boolean,
	own: boolean,
	customer: Model,
	place: Place,
	state: string,
	barista: Model?,
	station: Instance?, -- where the making plays: the plot's Espresso or Oven, or the Barista for the counter
	waiter: Model?,
	waiterReady: boolean, -- the Waiter stands at the Pickup point
	handOver: boolean, -- no Waiter: the customer carries the dish from the counter
	dish: Model?,
	carried: boolean, -- the Waiter has taken it from the counter
	tray: Model?, -- what rides on the Waiter's head: the tray with the dish on it, or the dish alone
	sat: boolean,
	left: boolean,
}

type Sweep = { plot: Model, pile: Model, tableModel: Model, due: number }

local rng = Random.new()
local folder: Folder? = nil
local queues: { [Model]: { Ticket } } = {} -- plot -> its orders waiting or being made, oldest first
local making: { [Model]: Ticket } = {} -- Barista -> the order it is making
local busy: { [Model]: boolean } = {} -- Waiters and Greeters on an errand
local carrying: { Ticket } = {} -- orders a Waiter has, for the watchdog
local sweeps: { Sweep } = {}
local started = false

-- where a handed over dish rides, from a standing customer's pivot (its feet)
local HANDS_UP, HANDS_OUT = 2.4, 0.9

local function container(): Folder
	if folder ~= nil and folder.Parent ~= nil then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "CafeOrders"
	created.Parent = Workspace
	folder = created
	return created
end

local function assetModel(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets ~= nil then assets:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found :: Model else nil
end

-- A copy of an asset that never collides, blocks a click or casts a shadow over the table.
local function cloneLocal(source: Model): Model
	local copy = source:Clone() :: Model
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return copy
end

local function waypoint(plot: Model, name: string): Vector3?
	local waypoints = plot:FindFirstChild("CustomerWaypoints")
	local point = if waypoints ~= nil then waypoints:FindFirstChild(name) else nil
	return if point ~= nil and point:IsA("BasePart") then (point :: BasePart).Position else nil
end

local function ownsCat(cat: Model): boolean
	local player = Players.LocalPlayer
	return player ~= nil and cat:GetAttribute("OwnerUserId") == player.UserId
end

-- The plot's station cats in `role` that are at work now (not off on a bedtime trip).
local function stationCats(plot: Model, role: string): { Model }
	local found: { Model } = {}
	local cats = plot:FindFirstChild("Cats")
	if cats == nil then
		return found
	end
	for _, child in cats:GetChildren() do
		if
			child:IsA("Model")
			and CollectionService:HasTag(child, "WorkingCat")
			and child:GetAttribute("Role") == role
			and child:GetAttribute("Bedtime") == nil
		then
			table.insert(found, child :: Model)
		end
	end
	return found
end

-- Where the item's station is in `plot`: its Oven or Espresso, else the Counter.
local function stationAt(plot: Model, station: string): Vector3?
	local name = if station == "oven"
		then "Oven"
		elseif station == "espresso" then "Espresso"
		else "Counter"
	local model = plot:FindFirstChild(name) or plot:FindFirstChild("Counter")
	return if model ~= nil and model:IsA("Model") then (model :: Model):GetPivot().Position else nil
end

-- The nearest of `cats` to `at` that `usable` allows, or nil.
local function nearest(cats: { Model }, at: Vector3?, usable: (Model) -> boolean): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, cat in cats do
		if usable(cat) then
			local distance = if at ~= nil then (cat:GetPivot().Position - at).Magnitude else 0
			if distance < bestDistance then
				best, bestDistance = cat, distance
			end
		end
	end
	return best
end

-- Dishes --------------------------------------------------------------------------------------------------------

-- The item on its plate (the gold-rimmed one for the rich customer), or nil without its art.
local function buildDish(ticket: Ticket): Model?
	local name = Catalog.menuModelName(ticket.item)
	local source = assetModel(name)
	if source == nil then
		return nil
	end
	local dish = cloneLocal(source :: Model)
	if ticket.gold then
		local plate = dish:FindFirstChild(name .. "_Plate", true)
		local gold = assetModel(Catalog.menuGoldPlate)
		if plate ~= nil and gold ~= nil then
			for _, descendant in plate:GetDescendants() do
				if descendant:IsA("BasePart") then
					(descendant :: BasePart).Transparency = 1
				end
			end
			local rim = cloneLocal(gold :: Model)
			rim.Name = "GoldPlate"
			rim:PivotTo(dish:GetPivot())
			rim.Parent = dish
		end
	end
	dish.Name = "Dish"
	dish:SetAttribute("Item", ticket.item.id)
	dish:SetAttribute("Rich", if ticket.gold then true else nil) -- the gold ding
	dish.Parent = container()
	return dish
end

-- Whether `part` belongs to the plate (kept for the empty plate) rather than the food.
local function onPlate(part: Instance, dish: Model): boolean
	local node: Instance? = part.Parent
	while node ~= nil and node ~= (dish :: Instance) do
		if node.Name == "GoldPlate" or string.sub(node.Name, -6) == "_Plate" then
			return true
		end
		node = node.Parent
	end
	return false
end

-- The empty plate: the food goes at once, the plate stays OrderPlateSeconds and fades over OrderPlateFadeSeconds.
local function clearPlate(dish: Model)
	local plate: { BasePart } = {}
	for _, descendant in dish:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			if onPlate(part, dish) then
				if part.Transparency < 1 then
					table.insert(plate, part)
				end
			else
				part.Transparency = 1
			end
		end
	end
	task.delay(Config.World.OrderPlateSeconds, function()
		local steps = 10
		local start: { [BasePart]: number } = {}
		for _, part in plate do
			start[part] = part.Transparency
		end
		for step = 1, steps do
			if dish.Parent == nil then
				return
			end
			for _, part in plate do
				local from = start[part]
				part.Transparency = from + (1 - from) * step / steps
			end
			task.wait(Config.World.OrderPlateFadeSeconds / steps)
		end
		dish:Destroy()
	end)
end

-- Sets the dish down on the customer's table and shows the heart if the customer sits there.
local function onTable(ticket: Ticket)
	local tray = ticket.tray
	ticket.tray = nil
	local dish = ticket.dish
	local spot = ticket.place.dishAt
	if dish ~= nil then
		dish.Parent = container()
		if spot ~= nil then
			dish:PivotTo(spot)
		end
	end
	if tray ~= nil and tray ~= dish then
		tray:Destroy()
	end
	if ticket.state ~= "gone" then
		ticket.state = "served"
	end
	local at = if spot ~= nil then spot.Position else ticket.place.seat.Position
	if ticket.sat and not ticket.left then
		ticket.customer:SetAttribute("Served", true)
		Moments.OrderServed:Fire(ticket.customer, ticket.item.id, at)
	end
	if ticket.left and dish ~= nil then
		clearPlate(dish)
	end
end

-- Making ---------------------------------------------------------------------------------------------------------

local pump: (plot: Model) -> ()

local function release(cat: Model?)
	if cat ~= nil then
		busy[cat] = nil
	end
end

local function forget(ticket: Ticket)
	local index = table.find(carrying, ticket)
	if index ~= nil then
		table.remove(carrying, index)
	end
end

-- What a cat carries on its head: the tray (CatCafe_Menu_Tray) with `load` on its Item attachment, or `load` alone
-- without the tray's art.
local function onTray(load: Model?): Model?
	local trayArt = assetModel(Catalog.menuTray)
	if trayArt == nil then
		return load
	end
	local tray = cloneLocal(trayArt :: Model)
	tray.Name = "Tray"
	tray.Parent = container()
	if load ~= nil then
		local item = tray:FindFirstChild("Item", true)
		if item ~= nil and item:IsA("Attachment") then
			load:PivotTo((item :: Attachment).WorldCFrame)
		else
			load:PivotTo(tray:GetPivot())
		end
		load.Parent = tray
	end
	return tray
end

-- The Waiter has the dish at the counter: on its tray, off to the table.
local function carry(ticket: Ticket)
	local waiter = ticket.waiter
	if waiter == nil or ticket.carried then
		return
	end
	ticket.carried = true
	local dish = ticket.dish
	local rides = onTray(dish)
	ticket.tray = rides
	local faceAt = if ticket.place.tableModel ~= nil
		then (ticket.place.tableModel :: Model):GetPivot().Position
		else ticket.place.seat.Position
	local route = table.clone(ticket.place.route)
	if #route == 0 then
		table.insert(route, ticket.place.seat.Position)
	end
	local going = CafeWalk().go(waiter, route, {
		tray = rides,
		faceAt = faceAt,
		speed = Config.World.OrderWaiterSpeed,
		arrived = function()
			forget(ticket)
			onTable(ticket)
			CafeWalk().home(waiter, function()
				release(waiter)
			end)
		end,
	})
	if not going then
		forget(ticket)
		onTable(ticket)
		CafeWalk().home(waiter)
		release(waiter)
	end
end

-- A free Waiter in your own cafe walks to the Pickup point for `ticket`; false when none can.
local function callWaiter(ticket: Ticket): boolean
	local plot = ticket.plot
	local pickup = waypoint(plot, "Pickup")
	if pickup == nil then
		return false
	end
	local waiter = nearest(stationCats(plot, "waiter"), pickup, function(cat: Model): boolean
		return not busy[cat] and ownsCat(cat)
	end)
	if waiter == nil then
		return false
	end
	local cat = waiter :: Model
	busy[cat] = true
	ticket.waiter = cat
	local going = CafeWalk().go(cat, { pickup :: Vector3 }, {
		faceAt = waypoint(plot, "Pass"),
		speed = Config.World.OrderWaiterSpeed,
		arrived = function()
			ticket.waiterReady = true
			if ticket.state == "made" then
				carry(ticket)
			end
		end,
	})
	if not going then
		busy[cat] = nil
		ticket.waiter = nil
		return false
	end
	table.insert(carrying, ticket)
	return true
end

-- The ding: where the dish appears depends on who takes it.
local function done(ticket: Ticket)
	local barista = ticket.barista
	if barista ~= nil then
		making[barista] = nil
		if barista.Parent ~= nil then
			barista:SetAttribute("Making", nil)
			barista:SetAttribute("MakeSeconds", nil)
		end
	end
	local queue = queues[ticket.plot]
	local index = if queue ~= nil then table.find(queue, ticket) else nil
	if index ~= nil and queue ~= nil then
		table.remove(queue, index)
	end
	if ticket.state == "gone" then
		pump(ticket.plot)
		return
	end
	ticket.state = "made"
	local dish = buildDish(ticket)
	ticket.dish = dish
	local pass = waypoint(ticket.plot, "Pass")
	if ticket.handOver and not ticket.sat then
		-- the Barista hands it over the counter: it rides in the customer's hands to the seat
		if dish ~= nil then
			dish:PivotTo(ticket.customer:GetPivot() * CFrame.new(0, HANDS_UP, -HANDS_OUT))
			dish.Parent = ticket.customer
		end
	elseif ticket.waiter ~= nil then
		if dish ~= nil and pass ~= nil then
			dish:PivotTo(CFrame.new(pass :: Vector3))
		end
		if ticket.waiterReady then
			carry(ticket)
		end
	elseif ticket.sat then
		onTable(ticket)
	elseif dish ~= nil then
		dish.Parent = nil -- out of sight until the customer sits and it goes on the table
	end
	local station = ticket.station
	if station ~= nil and station.Parent ~= nil then
		local shown = if dish ~= nil and dish:IsDescendantOf(Workspace) then dish else nil
		Moments.OrderReady:Fire(ticket.plot, ticket.item.station, station, shown)
	end
	pump(ticket.plot)
end

local function startMaking(ticket: Ticket, barista: Model)
	ticket.state = "making"
	ticket.barista = barista
	making[barista] = ticket
	barista:SetAttribute("Making", ticket.item.id)
	barista:SetAttribute("MakeSeconds", ticket.item.makeSeconds)
	local kind = ticket.item.station
	local machine = if kind == "oven"
		then ticket.plot:FindFirstChild("Oven")
		elseif kind == "espresso" then ticket.plot:FindFirstChild("Espresso")
		else nil
	local station: Instance = if machine ~= nil and machine:IsA("Model") then machine else barista
	ticket.station = station
	Moments.OrderMaking:Fire(ticket.plot, kind, station, ticket.item.makeSeconds)
	if ticket.own and not ticket.handOver then
		callWaiter(ticket)
	end
	task.delay(ticket.item.makeSeconds, done, ticket)
end

-- Starts every waiting order a free Barista can take. With no Barista at work, waiting orders go on the table.
pump = function(plot: Model)
	local queue = queues[plot]
	if queue == nil then
		return
	end
	local baristas = stationCats(plot, "barista")
	for _, ticket in table.clone(queue) do
		if ticket.state ~= "queued" then
			continue
		end
		if #baristas == 0 then
			table.remove(queue, table.find(queue, ticket) :: number)
			ticket.state = "table"
			if ticket.sat then
				ticket.dish = buildDish(ticket)
				onTable(ticket)
			end
			continue
		end
		local barista = nearest(
			baristas,
			stationAt(plot, ticket.item.station),
			function(cat: Model): boolean
				return making[cat] == nil and cat.Parent ~= nil
			end
		)
		if barista == nil then
			break -- every Barista is busy; the next done() pumps again
		end
		startMaking(ticket, barista :: Model)
	end
	if #queue == 0 then
		queues[plot] = nil
	end
end

-- Orders -----------------------------------------------------------------------------------------------------------

-- A customer orders at the counter: the item from its cafe's menu (the newest for the rich customer), shown in its
-- order bubble, and queued for a Barista when there is room and this client shows the making there.
function CafeOrders.order(
	plot: Model,
	customer: Model,
	place: Place,
	rich: boolean,
	own: boolean
): Ticket
	local rawTier = plot:GetAttribute("Tier")
	local tier = if type(rawTier) == "number" then rawTier else 1
	local item = Catalog.newestMenuItem(tier)
	if not rich then
		local open = Catalog.menuFor(tier)
		item = open[rng:NextInteger(1, #open)]
	end
	local ticket: Ticket = {
		plot = plot,
		item = item,
		gold = rich,
		own = own,
		customer = customer,
		place = place,
		state = "table",
		barista = nil,
		station = nil,
		waiter = nil,
		waiterReady = false,
		handOver = false,
		dish = nil,
		carried = false,
		tray = nil,
		sat = false,
		left = false,
	}
	customer:SetAttribute("Order", item.id)
	local queue = queues[plot] or {}
	local shows = own or not lowTier()
	if shows and #queue < Config.World.OrderQueueMax and #stationCats(plot, "barista") > 0 then
		ticket.state = "queued"
		-- in your own cafe with no Waiter at work, the customer waits at the counter for the hand-over
		ticket.handOver = own and #stationCats(plot, "waiter") == 0
		table.insert(queue, ticket)
		queues[plot] = queue
		pump(plot)
	end
	return ticket
end

-- The customer stands at the counter: CustomerOrderSeconds, or for a hand-over until the dish is made (at most
-- OrderHandOverSeconds). Yields.
function CafeOrders.atCounter(ticket: Ticket, alive: () -> boolean)
	task.wait(Config.World.CustomerOrderSeconds)
	if not ticket.handOver then
		return
	end
	local waited = Config.World.CustomerOrderSeconds
	while
		alive()
		and (ticket.state == "queued" or ticket.state == "making")
		and waited < Config.World.OrderHandOverSeconds
	do
		waited += task.wait(0.1)
	end
	if ticket.state == "queued" or ticket.state == "making" then
		ticket.handOver = false -- too long: it goes on the table when it is made
	end
end

-- The customer sits: `customer` is the model in the chair now (its seated twin, or itself). It keeps its order bubble
-- until the dish reaches the table, then the heart pops.
function CafeOrders.seated(ticket: Ticket, customer: Model)
	ticket.customer = customer
	ticket.sat = true
	customer:SetAttribute("Order", ticket.item.id)
	customer:SetAttribute("Served", nil)
	if ticket.state == "served" then
		customer:SetAttribute("Served", true)
	elseif ticket.state == "table" then
		ticket.dish = buildDish(ticket)
		onTable(ticket)
	elseif ticket.state == "made" and ticket.waiter == nil then
		-- carried in its own hands, or made while it walked here with no Waiter to bring it
		onTable(ticket)
	end
end

-- The customer gets up to leave (or is gone): its plate empties and fades; an order not yet made is dropped.
function CafeOrders.left(ticket: Ticket)
	if ticket.left then
		return
	end
	ticket.left = true
	local queue = queues[ticket.plot]
	if ticket.state == "queued" and queue ~= nil then
		local index = table.find(queue, ticket)
		if index ~= nil then
			table.remove(queue, index)
		end
	end
	if ticket.state == "served" then
		if ticket.dish ~= nil then
			clearPlate(ticket.dish :: Model)
		end
	elseif not ticket.carried and ticket.dish ~= nil then
		(ticket.dish :: Model):Destroy() -- on the counter, in its hands or not yet shown
		ticket.dish = nil
	end
	if ticket.state ~= "served" then
		ticket.state = "gone" -- a dish on a Waiter's tray still goes down, and then clears
	end
	if ticket.waiter ~= nil and not ticket.carried then
		-- the Waiter was on its way to the counter or waiting there: back to its spot
		local waiter = ticket.waiter :: Model
		ticket.waiter = nil
		forget(ticket)
		CafeWalk().home(waiter, function()
			release(waiter)
		end)
	end
end

-- Tip sweeps (your own cafe) ----------------------------------------------------------------------------------------

-- A new tip pile in your own cafe, on `tableModel`: swept to the till by an idle Greeter or Waiter a little later.
function CafeOrders.sweep(plot: Model, pile: Model, tableModel: Model)
	table.insert(sweeps, {
		plot = plot,
		pile = pile,
		tableModel = tableModel,
		due = os.clock() + Config.World.TipSweepAfterSeconds,
	})
end

-- The walk to a table's chair nearest `at`: its Aisle and Approach points.
local function routeTo(tableModel: Model, at: Vector3): { Vector3 }?
	local group = tableModel.Parent
	if group == nil then
		return nil
	end
	local best: { Vector3 }? = nil
	local bestDistance = math.huge
	for _, child in group:GetChildren() do
		if child:IsA("Model") and string.match(child.Name, "^Chair_") ~= nil then
			local aisle, approach = child:GetAttribute("Aisle"), child:GetAttribute("Approach")
			if typeof(aisle) == "Vector3" and typeof(approach) == "Vector3" then
				local distance = (approach - at).Magnitude
				if distance < bestDistance then
					best, bestDistance = { aisle, approach }, distance
				end
			end
		end
	end
	return best
end

local function startSweep(sweep: Sweep): boolean
	local plot = sweep.plot
	local at = sweep.pile:GetPivot().Position
	local till = waypoint(plot, "TillStack")
	local pickup = waypoint(plot, "Pickup")
	local route = routeTo(sweep.tableModel, at)
	if till == nil or pickup == nil or route == nil then
		return true -- nowhere to go: the pile stays on the table
	end
	local usable = function(cat: Model): boolean
		return not busy[cat] and ownsCat(cat)
	end
	local cat = nearest(stationCats(plot, "greeter"), at, usable)
		or nearest(stationCats(plot, "waiter"), at, usable)
	if cat == nil then
		return false -- try again in a moment
	end
	local sweeper = cat :: Model
	busy[sweeper] = true
	local back = { (route :: { Vector3 })[1], pickup :: Vector3 }
	local going = CafeWalk().go(sweeper, route :: { Vector3 }, {
		faceAt = at,
		speed = Config.World.OrderWaiterSpeed,
		arrived = function()
			if sweep.pile.Parent == nil then
				CafeWalk().home(sweeper, function()
					release(sweeper)
				end)
				return
			end
			sweep.pile.Parent = nil -- swept: CustomerController drops it when the server's count goes down
			Moments.TipSwept:Fire(sweeper, at)
			-- the bag rides on the tray's Item attachment like a dish (Model-Agent: a round bag alone floats between
			-- the ear tips)
			local bagArt = assetModel(Catalog.menuCoinBag)
			local bag = if bagArt ~= nil then cloneLocal(bagArt :: Model) else nil
			local rides = onTray(bag)
			if bag ~= nil then
				bag.Name = "CoinBag"
				if bag.Parent == nil then
					bag.Parent = container()
				end
			end
			local carried = CafeWalk().go(sweeper, back, {
				tray = rides,
				faceAt = till,
				speed = Config.World.OrderWaiterSpeed,
				arrived = function()
					if bag ~= nil then
						local dropped = bag :: Model
						dropped.Parent = container()
						dropped:PivotTo(CFrame.new(till :: Vector3))
						task.delay(0.6, function()
							dropped:Destroy()
						end)
					end
					if rides ~= nil and rides ~= bag then
						(rides :: Model):Destroy()
					end
					Moments.TipBanked:Fire(sweeper, till :: Vector3)
					CafeWalk().home(sweeper, function()
						release(sweeper)
					end)
				end,
			})
			if not carried then
				if rides ~= nil then
					(rides :: Model):Destroy()
				end
				if bag ~= nil then
					bag:Destroy()
				end
				CafeWalk().home(sweeper)
				release(sweeper)
			end
		end,
	})
	if not going then
		release(sweeper)
		return true -- it cannot walk now (night, too far): the pile stays
	end
	return true
end

-- Twice a second: due sweeps start, an order whose Waiter's walk ended early (the cafe closed, bedtime, out of range)
-- goes straight on the table, and a cat whose walk ended is free again.
local function tick()
	local now = os.clock()
	for i = #sweeps, 1, -1 do
		local sweep = sweeps[i]
		local gone = sweep.pile.Parent == nil or sweep.plot.Parent == nil
		if gone or (now >= sweep.due and startSweep(sweep)) then
			table.remove(sweeps, i)
		end
	end
	for i = #carrying, 1, -1 do
		local ticket = carrying[i]
		local waiter = ticket.waiter
		if waiter ~= nil and not CafeWalk().isAway(waiter) then
			table.remove(carrying, i)
			release(waiter)
			ticket.waiter = nil
			-- off the tray (a left customer's plate then clears), or off the counter for a customer already seated
			local made = ticket.state == "made" and (ticket.carried or ticket.sat)
			if made or (ticket.state == "gone" and ticket.carried) then
				onTable(ticket)
			end
		end
	end
	-- a Waiter or Greeter whose walk ended without its errand finishing (a sweep cut short by nightfall) is free again
	for cat in busy do
		if cat.Parent == nil or not CafeWalk().isAway(cat) then
			busy[cat] = nil
		end
	end
end

function CafeOrders.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
end

return CafeOrders
