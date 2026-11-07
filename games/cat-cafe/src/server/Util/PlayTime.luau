--!strict
-- Seconds of play on the account: the saved stats.playtimeSeconds plus this session's so far (DataService adds the
-- session on leave). The Grand Opening's bunting (#1922), the badges' minutes played (#1934) and the client's store
-- guard (#1936) read it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Parent.Services.DataService)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayTime = {}

function PlayTime.seconds(player: Player, profile: Types.PlayerProfile): number
	local joinedAt = DataService.joinedAt(player)
	local session = if joinedAt ~= nil then math.max(0, os.time() - joinedAt) else 0
	return profile.stats.playtimeSeconds + session
end

return PlayTime
