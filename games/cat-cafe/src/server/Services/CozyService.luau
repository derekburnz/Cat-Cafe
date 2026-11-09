--!strict
-- #2798 (retention-ideas.md idea 10, shared/CozyCafe): Cozy Cafe. Once a second, each owner standing inside their own
-- cafe (the plot's footprint, PlotWidth by PlotDepth about its centre) counts time there; leaving resets it. After
-- CozyStartSeconds the plot's CozyActive attribute turns on (a cat curls up on the counter: Model and Animation draw it);
-- CozyBagSeconds later a gift bag appears on the counter (a CozyBag part with a one-press prompt, owner only, also
-- taken by touching it). One bag waits at a time and the timer stops until it is taken; a bag left behind when the
-- owner leaves the cafe stays until the plot is released. The prize is paid on taking (Payout). Attributes for the
-- client's HUD line ("Cozy gift in 2:10"): CozyActive, CozyNextAt (os.time() the next bag drops while counting, else
-- 0) and CozyBagAt (os.time() the waiting bag dropped, else 0).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafeService = require(script.Parent.CafeService)
local Config = require(ReplicatedStorage.Shared.Config)
local CozyCafe = require(ReplicatedStorage.Shared.CozyCafe)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CozyService = {}

local TICK_SECONDS = 1
local RANGE_STUDS = 10 -- the prompt's reach; taking needs this plus 2 of slack
local rng = Random.new()

type Stay = {
	seconds: number, -- counted toward the next bag
	curled: boolean, -- CozyStartSeconds passed this stay
}

local stays: { [Player]: Stay } = {}
local bags: { [number]: BasePart } = {} -- plot index -> its waiting bag

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- Whether `position` is inside the plot's cafe footprint (its local X along the width, Z along the depth).
local function insideCafe(plot: WorldBuilder.Plot, position: Vector3): boolean
	local W = Config.World
	local at = plot.cframe:PointToObjectSpace(position)
	return math.abs(at.X) <= W.PlotWidth / 2
		and math.abs(at.Z) <= W.PlotDepth / 2
		and at.Y > -4
		and at.Y < 30
end

local function setAttributes(plot: WorldBuilder.Plot, curled: boolean, nextAt: number)
	plot.model:SetAttribute("CozyActive", curled)
	plot.model:SetAttribute("CozyNextAt", nextAt)
end

local function removeBag(index: number, plot: WorldBuilder.Plot?)
	local bag: BasePart? = bags[index]
	if bag ~= nil then
		bags[index] = nil
		bag:Destroy()
	end
	if plot ~= nil then
		plot.model:SetAttribute("CozyBagAt", 0)
	end
end

local function take(player: Player)
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return
	end
	local bag: BasePart? = bags[plot.index]
	local root = rootOf(player)
	if bag == nil or root == nil or (root.Position - bag.Position).Magnitude > RANGE_STUDS + 2 then
		return
	end
	removeBag(plot.index, plot)
	local now = os.time()
	CozyCafe.note(profile.cozy, now)
	local prize = CozyCafe.prize(rng:NextNumber(), rng:NextNumber())
	local paid = Payout.pay(player, profile, prize, "cozy_bag")
	local what = "coins"
		.. (if prize.lures ~= nil then "+lure" else "")
		.. (if prize.fish ~= nil then "+fish" else "")
	Telemetry.custom(player, "cozy_bag", CozyCafe.bagsToday(profile.cozy, now), { what })
	Net.toast(player, "Cozy gift! " .. table.concat(paid, ", "), "good")
	CafeService.sync(player)
end

local function dropBag(player: Player, plot: WorldBuilder.Plot)
	local counter = plot.counter
	local cf, size = counter:GetBoundingBox()
	local bag = Instance.new("Part")
	bag.Name = "CozyBag"
	bag.Size = Vector3.new(1.2, 1.2, 1.2)
	bag.Color = Color3.fromRGB(196, 140, 88)
	bag.Material = Enum.Material.Fabric
	bag.Anchored = true
	bag.CanCollide = false
	bag.CanQuery = false
	bag.CFrame = cf * CFrame.new(0, size.Y / 2 + 0.6, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CozyPrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = "Cozy gift"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = RANGE_STUDS
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(who: Player)
		if who == player then
			take(who)
		end
	end)
	prompt.Parent = bag
	bag.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model") :: Model?
		if character ~= nil and Players:GetPlayerFromCharacter(character) == player then
			take(player)
		end
	end)
	bag.Parent = plot.model
	bags[plot.index] = bag
	plot.model:SetAttribute("CozyBagAt", os.time())
end

local function tick(dt: number)
	local now = os.time()
	for _, player in DataService.loadedPlayers() do
		local plot = PlotService.get(player)
		local profile = DataService.get(player)
		local root = rootOf(player)
		if plot == nil or profile == nil then
			continue
		end
		local inside = root ~= nil and insideCafe(plot, root.Position)
		if not inside or not CozyCafe.eligible(profile, now) then
			if stays[player] ~= nil then
				stays[player] = nil
				setAttributes(plot, false, 0)
			end
			continue
		end
		local current: Stay? = stays[player]
		local stay: Stay = if current ~= nil then current else { seconds = 0, curled = false }
		stays[player] = stay
		local waiting: BasePart? = bags[plot.index]
		if waiting ~= nil then
			setAttributes(plot, stay.curled, 0) -- waiting to be taken: the timer stops
			continue
		end
		stay.seconds += dt
		if not stay.curled and stay.seconds >= Config.CozyStartSeconds then
			stay.curled = true
			stay.seconds -= Config.CozyStartSeconds
		end
		local left = CozyCafe.secondsToBag(stay.curled, stay.seconds)
		if left <= 0 then
			stay.seconds = 0
			dropBag(player, plot)
			setAttributes(plot, stay.curled, 0)
		else
			setAttributes(plot, stay.curled, now + math.ceil(left))
		end
	end
end

function CozyService.start()
	DataService.beforeRelease(function(player: Player)
		stays[player] = nil
		local plot = PlotService.get(player)
		if plot ~= nil then
			removeBag(plot.index, plot)
			setAttributes(plot, false, 0)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_SECONDS)
			local nowClock = os.clock()
			local ok, err = pcall(function()
				tick(nowClock - last)
			end)
			last = nowClock
			if not ok then
				warn("[CozyService] " .. tostring(err))
			end
		end
	end)
end

-- Studio-only test hook: drops a bag at the player's cafe now. Returns whether it did.
function CozyService.debugDrop(player: Player): boolean
	assert(RunService:IsStudio(), "debugDrop is Studio only")
	local plot = PlotService.get(player)
	local waiting: BasePart? = if plot ~= nil then bags[plot.index] else nil
	if plot == nil or waiting ~= nil then
		return false
	end
	dropBag(player, plot)
	return true
end

-- The waiting bag's part at `player`'s cafe, for the specs and Studio.
function CozyService.bagOf(player: Player): BasePart?
	local plot = PlotService.get(player)
	local bag: BasePart? = if plot ~= nil then bags[plot.index] else nil
	return bag
end

return CozyService
