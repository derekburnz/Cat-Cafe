--!strict
-- Rare customers by chance (#3889, shared/RareCustomers). With the LiveFlags `rareCustomers` switch on, every cafe that
-- is open (by day, before the last DuskWarningSeconds) gets a customer every Config.RareCustomerSeconds, and each one
-- rolls once: a rich customer (RichTipService.arriveRare), a Mystery Visitor (MysteryService.arriveRare), the Cat
-- Collector (CollectorService.arriveRare) or an everyday customer. Each service checks it can take the visit now (a
-- visit already on, no table, no cat to ask for) and an arrival it cannot take is an everyday customer. The three
-- services stop their own timers while the switch is on; off, this service does nothing and the timers run.
-- The chances: Config.RareChance, the working cats' rare customer chance traits on all three and the passes' rich
-- rate on the rich one (RareCustomers.chances). The rolls are the server's own; nothing here is sold or sped up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClockService = require(script.Parent.ClockService)
local CollectorService = require(script.Parent.CollectorService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MysteryService = require(script.Parent.MysteryService)
local RareCustomers = require(ReplicatedStorage.Shared.RareCustomers)
local RichTipService = require(script.Parent.RichTipService)
local Telemetry = require(script.Parent.Telemetry)

local RareCustomerService = {}

local rng = Random.new()
-- each player's seconds of open day toward the next arriving customer
local carried: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function send(player: Player, kind: RareCustomers.Kind): boolean
	if kind == "rich" then
		return RichTipService.arriveRare(player, rng:NextNumber())
	elseif kind == "mystery" then
		return MysteryService.arriveRare(player, rng:NextNumber())
	end
	return CollectorService.arriveRare(player)
end

local function tick(dt: number)
	if not LiveFlagService.on(RareCustomers.FLAG) then
		table.clear(carried)
		return
	end
	local now = os.time()
	local dusk = math.floor(ClockService.phaseEndsAt())
	if ClockService.isNight() or dusk - now <= Config.DuskWarningSeconds then
		return -- the cafe is shut, or about to: no one walks in (the old timers held the same way)
	end
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile == nil or Economy.level(profile, "tables") < 1 then
			continue
		end
		local count, left = RareCustomers.arrivals(carried[player] or 0, dt)
		carried[player] = left
		if count < 1 then
			continue
		end
		local chances = RareCustomers.chances(
			Economy.richRate(profile),
			Economy.traitBonus(profile, "rareCustomer")
		)
		for _ = 1, count do
			local kind = RareCustomers.pick(chances, rng:NextNumber())
			if kind ~= nil and send(player, kind) then
				Telemetry.custom(player, "rare_customer", 1, { kind })
			end
		end
	end
end

function RareCustomerService.start()
	task.spawn(function()
		local last = os.clock()
		local warnedAt = -math.huge
		while true do
			task.wait(1)
			local nowClock = os.clock()
			local dt = math.min(nowClock - last, 5) -- a long server hitch never sends a crowd at once
			last = nowClock
			local ok, problem = pcall(tick, dt)
			if not ok and warnedAt + 60 < nowClock then
				warnedAt = nowClock
				warn("[RareCustomerService] step failed: " .. tostring(problem))
			end
		end
	end)
end

return RareCustomerService
