--!strict
-- #5300 (shared/PerfectCatch): the perfectCatch switch's one charm migration. As a save loads with the switch on, and for
-- everyone in the server when it flips on, each owned cat with charm 80 or more is marked Perfect once per account
-- (tipsSeen PerfectCatch.KEY), with a perfect_migrate log of how many cats were marked and how many earn a little less.
-- The pay rule itself is in shared/CatStats (rating), and the catch's mark in CatService.checkIn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local PerfectCatch = require(ReplicatedStorage.Shared.PerfectCatch)
local Telemetry = require(script.Parent.Telemetry)

local PerfectCatchService = {}

local started = false

local function migrate(player: Player, profile: any): boolean
	if not PerfectCatch.on() or type(profile) ~= "table" or type(profile.cats) ~= "table" then
		return false
	end
	if type(profile.tipsSeen) ~= "table" then
		return false
	end
	if profile.tipsSeen[PerfectCatch.KEY] == true then
		return false
	end
	local owned = 0
	for _ in profile.cats do
		owned += 1
	end
	local marked, lower = PerfectCatch.migrate(profile.cats, profile.tipsSeen)
	Telemetry.custom(player, "perfect_migrate", marked, { tostring(lower), tostring(owned) })
	return marked > 0
end

function PerfectCatchService.start()
	if started then
		return
	end
	started = true
	-- before the offline pay and the first sync read the ratings
	DataService.onLoading(function(player, profile)
		migrate(player, profile)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. PerfectCatch.FLAG)
		:Connect(function()
			if not PerfectCatch.on() then
				return
			end
			local CafeService = require(script.Parent.CafeService) :: any
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil and migrate(player, profile) then
					CafeService.sync(player)
				end
			end
		end)
end

return PerfectCatchService
