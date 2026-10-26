--!strict
-- Cosmetic customers for the local player's own cafe (features.md F15). Runs entirely on this client:
-- one customer per free chair, walks in from the street, sits a while popping coin text, walks out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Mover = require(Shared:WaitForChild("Mover"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CustomerController = {}

local rng = Random.new()
local folder: Folder? = nil
local busySeats: { [BasePart]: boolean } = {}
local activeCustomers = 0
local variants = { "A", "B", "C" }

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

local function ownPlot(): Model?
	local state = UIController.state
	if state == nil or state.plotIndex == 0 then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	local plot = if plots ~= nil then plots:FindFirstChild("Plot_" .. state.plotIndex) else nil
	return if plot ~= nil and plot:IsA("Model") then plot :: Model else nil
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
	if source == nil or entry == nil or door == nil then
		return
	end
	busySeats[seat] = true
	activeCustomers += 1
	local cloned = source:Clone()
	if not cloned:IsA("Model") then
		cloned:Destroy()
		busySeats[seat] = nil
		activeCustomers -= 1
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
	if
		Mover.walkTo(model, door, speed, isAlive)
		and Mover.walkTo(model, seatPosition, speed, isAlive)
	then
		if tableTop ~= nil then
			Mover.face(model, tableTop.Position)
		end
		local stay = rng:NextNumber(Config.CustomerStayMin, Config.CustomerStayMax)
		local elapsed = 0
		while isAlive() and elapsed < stay do
			task.wait(Config.CustomerCoinPopSeconds)
			elapsed += Config.CustomerCoinPopSeconds
			local state = UIController.state
			local rate = if state ~= nil then state.incomePerSecond else 0
			local tip = math.max(
				1,
				math.floor(rate * Config.CustomerCoinPopSeconds / math.max(1, activeCustomers))
			)
			UI.floatText(model:GetPivot().Position + Vector3.new(0, 5.5, 0), "+$" .. tip)
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
end

function CustomerController.start()
	task.spawn(function()
		while true do
			task.wait(Config.CustomerSpawnSeconds)
			local state = UIController.state
			local plot = ownPlot()
			if state == nil or plot == nil or state.incomePerSecond <= 0 then
				continue
			end
			local seat, tableTop = freeSeat(plot)
			if seat ~= nil then
				task.spawn(runCustomer, plot, seat, tableTop)
			end
		end
	end)
end

return CustomerController
