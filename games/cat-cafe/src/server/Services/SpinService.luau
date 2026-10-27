--!strict
-- The Spin Wheel station (F49, data-model section 11c). SpinWheel() spins for a player standing within
-- SpinStationRange of a station tagged SpinWheel, with a free spin due or one banked, SpinCooldownSeconds after
-- their last spin. The server picks the slice with its own Random and pays at once, so leaving mid-animation keeps
-- the prize; then SpinResult(slice, amount) tells the window where to land, ProfileSync carries `spin`, and the
-- station's LastSpinAt turns the world wheel on every client (show only). A refused spin answers SpinResult(0, 0).
-- Spins are free only: nothing sells them (monetization-policy).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local Spin = require(ReplicatedStorage.Shared.Spin)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local SpinService = {}

SpinService.TAG = "SpinWheel"

local random = Random.new()
local lastSpinAt: { [Player]: number } = {} -- os.clock() of each player's last spin, for the cooldown

-- The station the player stands within SpinStationRange of, or nil.
local function stationNear(player: Player): Model?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(SpinService.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - position).Magnitude <= Config.SpinStationRange
		then
			return instance :: Model
		end
	end
	return nil
end

local function pay(player: Player, profile: Types.PlayerProfile, row: Types.SpinSlice): number
	local amount = Spin.amount(row, Economy.incomePerSecond(profile))
	if row.kind == "coins" then
		Economy.credit(profile, amount)
		Telemetry.source(player, profile, amount, "Gameplay", "spin_wheel")
	else
		local lureId = row.lureId :: string
		profile.lures[lureId] = (profile.lures[lureId] or 0) + amount
	end
	return amount
end

local function onSpinWheel(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local last = lastSpinAt[player]
	local station = stationNear(player)
	local kind = if station ~= nil
			and (last == nil or os.clock() - last >= Config.SpinCooldownSeconds)
		then Spin.take(profile.spin, os.time())
		else nil
	if station == nil or kind == nil then
		Net.fire(player, "SpinResult", 0, 0)
		return
	end
	lastSpinAt[player] = os.clock()
	local row = Spin.pick(random:NextNumber())
	local amount = pay(player, profile, row)
	profile.stats.spins += 1
	Telemetry.custom(player, "spin", row.slice, { kind :: string })
	Net.fire(player, "SpinResult", row.slice, amount)
	CafeService.sync(player)
	station:SetAttribute("LastSpinAt", Workspace:GetServerTimeNow())
end

function SpinService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastSpinAt[player] = nil
	end)
	Net.on("SpinWheel", onSpinWheel)
end

-- Studio-only test hook (Debug.spins): sets the banked spins and, with `freeDue`, makes today's free spin due
-- again; the cooldown is cleared too. Returns the spins available now.
function SpinService.debugSet(
	player: Player,
	profile: Types.PlayerProfile,
	banked: number,
	freeDue: boolean
): number
	profile.spin.banked = math.clamp(math.floor(banked), 0, Config.SpinBankCap)
	if freeDue then
		profile.spin.lastFreeDay = Spin.day(os.time()) - 1
	end
	lastSpinAt[player] = nil
	CafeService.sync(player)
	return Spin.available(profile.spin, os.time())
end

return SpinService
