--!strict
-- Cosmetic customers (features.md F15, F37). Runs entirely on this client: customers walk into every running cafe
-- within Config.World.CafeLifeRangeStuds of the camera, not just this player's own, so the street looks busy
-- (world-and-feel.md section 4). Each one walks in from the street, orders at the counter, takes a free chair,
-- sits a while and walks out. Coin text pops only over this player's own cafe. The cafe closes at night (v0.5 F44):
-- no customers come, and at nightfall the ones inside skip the rest of their visit and walk out.
-- A rich customer (F31, data-model section 12) comes to any nearby cafe whose plot shows a rich tip
-- (RichTipAmount), sits at table 1 beside the gold coin pile on its RichTipAnchor and stays until the tip is paid.
-- The server decides the tip; this is only what the street sees.
-- A customer model carries Order ("coffee", "cake" or "milk") from the counter on and Served once it sits, for the
-- order bubble and the heart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Effects = require(script.Parent.Parent.Effects)
local Moments = require(script.Parent.Parent.Moments)
local Mover = require(Shared:WaitForChild("Mover"))
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
	if
		arrived
		and (visit ~= nil or isDay())
		and Mover.walkTo(model, seatPosition, speed, isAlive)
	then
		if tableTop ~= nil then
			Mover.face(model, tableTop.Position)
		end
		model:SetAttribute("Served", true)
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
	-- out again: after the visit, or at once when the cafe closes for the night on the way in
	if isAlive() then
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
		end
	end)
end

return CustomerController
