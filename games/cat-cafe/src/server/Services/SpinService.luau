--!strict
-- The Spin Wheel station (F49, data-model section 11c). SpinWheel() spins for a player standing within
-- SpinStationRange of a station tagged SpinWheel, with a free spin due or one banked, SpinCooldownSeconds after
-- their last spin. The server picks the slice with its own Random and pays at once, so leaving mid-animation keeps
-- the prize; then SpinResult(slice, amount) tells the window where to land, ProfileSync carries `spin`, and the
-- station's LastSlice and LastSpinAt turn the world wheel on every client onto the same slice (show only). A
-- refused spin answers SpinResult(0, 0). SpinAll() (#1078) spends them all at once (onSpinAll). Spins are free only: nothing sells them (monetization-policy).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Net = require(script.Parent.Net)
local Prizes = require(ReplicatedStorage.Shared.Prizes)
local Spin = require(ReplicatedStorage.Shared.Spin)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local SpinService = {}

SpinService.TAG = "SpinWheel"

local random = Random.new()
local lastSpinAt: { [Player]: number } = {} -- os.clock() of each player's last spin, for the cooldown
local forcedSlice: { [Player]: number } = {} -- Studio only (Debug.spinSlice): the slice this player's next spin lands on

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

-- Pays the slice: coins, golden fish, a crate (banked for the Golden Fish Market; "highest" is the crate of the
-- player's highest open zone, F54) or foods. Returns the amount.
local function pay(player: Player, profile: Types.PlayerProfile, row: Types.SpinSlice): number
	local amount = Spin.amount(row, Economy.incomePerSecond(profile))
	if row.kind == "coins" then
		Economy.credit(profile, amount)
		Telemetry.source(player, profile, amount, "Gameplay", "spin_wheel")
	elseif row.kind == "fish" then
		GoldenFish.credit(profile, amount)
		Telemetry.fishSource(player, profile, amount, "Gameplay", "spin_wheel")
	elseif row.kind == "crate" then
		local crateId = Prizes.crateFor(row.crate or Prizes.HIGHEST, Economy.tier(profile))
		if crateId ~= nil then
			profile.crates[crateId] = (profile.crates[crateId] or 0) + amount
		end
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
	local forced = forcedSlice[player]
	forcedSlice[player] = nil
	local row = if forced ~= nil then Catalog.spinWheel[forced] else Spin.pick(random:NextNumber())
	local amount = pay(player, profile, row)
	profile.stats.spins += 1
	Telemetry.custom(player, "spin", row.slice, { kind :: string })
	Net.fire(player, "SpinResult", row.slice, amount)
	CafeService.sync(player)
	-- the slice first, so every client's world wheel rests on the real one when LastSpinAt turns it (review S64)
	station:SetAttribute("LastSlice", row.slice)
	station:SetAttribute("LastSpinAt", Workspace:GetServerTimeNow())
end

-- Use all spins (#1078, Derek 2026-11-04): SpinAll() spends every spin the player has, up to SpinAllMax, with the
-- same checks as one spin (the station's range, the cooldown) and the same odds (Spin.pick with the server's Random,
-- one roll each), paying each as one spin pays. One SpinAllResult(rolls, totals) answers for the one results card;
-- nothing to spend answers SpinAllResult({}, {}). The world wheel rests on the last slice.
local function onSpinAll(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local last = lastSpinAt[player]
	local station = stationNear(player)
	local now = os.time()
	if
		station == nil
		or (last ~= nil and os.clock() - last < Config.SpinCooldownSeconds)
		or Spin.available(profile.spin, now) == 0
	then
		Net.fire(player, "SpinAllResult", {}, {})
		return
	end
	lastSpinAt[player] = os.clock()
	local rolls: { Spin.SpinRoll } = {}
	while #rolls < Config.SpinAllMax do
		local kind = Spin.take(profile.spin, now)
		if kind == nil then
			break
		end
		local row = Spin.pick(random:NextNumber())
		local amount = pay(player, profile, row)
		profile.stats.spins += 1
		Telemetry.custom(player, "spin", row.slice, { kind :: string, "all" })
		table.insert(rolls, { slice = row.slice, amount = amount })
	end
	Net.fire(player, "SpinAllResult", rolls, Spin.summarize(rolls))
	CafeService.sync(player)
	station:SetAttribute("LastSlice", rolls[#rolls].slice)
	station:SetAttribute("LastSpinAt", Workspace:GetServerTimeNow())
end

function SpinService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastSpinAt[player] = nil
		forcedSlice[player] = nil
	end)
	Net.on("SpinWheel", onSpinWheel)
	Net.on("SpinAll", onSpinAll)
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

-- Studio-only test hook (Debug.spinSlice, QA S63): this player's next spin lands on `slice` (1 to #Catalog.spinWheel)
-- and pays it, with every other check as normal; nil goes back to the random pick. Returns the slice set.
function SpinService.debugForceSlice(player: Player, slice: number?): number?
	if slice == nil then
		forcedSlice[player] = nil
		return nil
	end
	assert(Catalog.spinWheel[slice] ~= nil, "no such slice")
	forcedSlice[player] = slice
	return slice
end

return SpinService
