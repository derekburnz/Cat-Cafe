--!strict
-- The Grand Opening roadmap (#1893, first-hour.md section 1): once a second, every loaded player whose roadmap is
-- active (tutorialStep 5 on, not finished) has each milestone that is met and not yet done marked and paid at once
-- (Payout), lowest first. The client hears ProfileSync first, then RoadmapStep(n) for the toast, the confetti and,
-- on the last, the Grand Opening; the last one also gives the [Grand Opener] chat tag (CafePassService's tag items).
-- Everything is read from the profile (shared/GrandOpening), so a milestone met while offline pays on the next join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local GrandOpening = require(ReplicatedStorage.Shared.GrandOpening)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local GrandOpeningService = {}

local CHECK_SECONDS = 1

-- Marks and pays every milestone due for the player; true when any was.
function GrandOpeningService.check(player: Player, profile: Types.PlayerProfile): boolean
	local due = GrandOpening.due(profile)
	if #due == 0 then
		return false
	end
	for _, n in due do
		-- marked before paying, so a failure inside the payout never pays it twice
		GrandOpening.mark(profile.grandOpening, n)
		Payout.pay(player, profile, GrandOpening.STEPS[n].prize, "grand_opening")
		Telemetry.grandOpening(player, profile, n)
		if n == GrandOpening.COUNT then
			CafePassService.refreshTag(player, profile) -- the [Grand Opener] tag shows at once
		end
	end
	CafeService.sync(player)
	for _, n in due do
		Net.fire(player, "RoadmapStep", n)
	end
	return true
end

function GrandOpeningService.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil then
					-- one bad profile must not end the loop for the server's life (as review N185)
					local ok, err = pcall(GrandOpeningService.check, player, profile)
					if not ok then
						warn("[GrandOpeningService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return GrandOpeningService
