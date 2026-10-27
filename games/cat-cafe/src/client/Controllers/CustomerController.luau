--!strict
-- Cosmetic customers (features.md F15, F37). Runs entirely on this client: customers walk into every running cafe
-- within Config.World.CafeLifeRangeStuds of the camera, not just this player's own, so the street looks busy
-- (world-and-feel.md section 4). Each one walks in from the street, orders at the counter, takes a free chair,
-- sits a while and walks out. Coin text pops only over this player's own cafe. Customers come by day only (F20):
-- at night none arrive and the seated ones finish up and leave.
-- A customer model carries Order ("coffee", "cake" or "milk") from the counter on and Served once it sits, for the
-- order bubble and the heart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Effects = require(script.Parent.Parent.Effects)
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

local function runCustomer(plot: Model, seat: BasePart, tableTop: BasePart?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil
		then assets:FindFirstChild(
			"CatCafe_NPC_Customer_" .. variants[rng:NextInteger(1, #variants)]
		)
		else nil
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
	if arrived and order ~= nil then
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
	if arrived and Mover.walkTo(model, seatPosition, speed, isAlive) then
		if tableTop ~= nil then
			Mover.face(model, tableTop.Position)
		end
		model:SetAttribute("Served", true)
		local own = isOwnPlot(plot)
		local stay = rng:NextNumber(Config.CustomerStayMin, Config.CustomerStayMax)
		local elapsed = 0
		while isAlive() and isDay() and elapsed < stay do
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
				UI.floatText(model:GetPivot().Position + Vector3.new(0, 5.5, 0), "+$" .. tip)
			end
		end
		if isAlive() then
			Mover.walkTo(model, door, speed, isAlive)
			Mover.walkTo(model, entry, speed, isAlive)
		end
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

function CustomerController.start()
	task.spawn(function()
		clock = ReplicatedStorage:WaitForChild("Clock")
	end)
	task.spawn(function()
		while true do
			task.wait(Config.CustomerSpawnSeconds)
			if not isDay() then
				continue
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
					task.spawn(runCustomer, plot, seat, tableTop)
				end
			end
		end
	end)
end

return CustomerController
