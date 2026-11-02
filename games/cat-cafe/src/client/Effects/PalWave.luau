--!strict
-- The pal wave (F92, playing-together.md section 5: a player who joins through an invite or by following a pal
-- "spawns at that pal's cafe front door, facing the street, with a little wave from both characters"). When the
-- joiner stands on the path in front of the pal's door, both players' characters wave with the left arm (the right
-- keeps the net): the joiner at once and the pal Presets.palWave.palDelay seconds later, waving back. Tackle.luau asks
-- `PalWave.layer` every frame for each player's character it poses within budget.animRadius (so a pal who is far
-- away, in another area, does not wave on this screen) and blends it over the net hold and under a tackle; a
-- character carrying a cat keeps its arms on the cat, and one in a cannon flight is not waved.
--
-- Source: Gameplay-Engineer's `Moments.PalArrived(joinerUserId, palUserId)` from the UIController (F92 part 3), or
-- until Moments has it, the server's `PalArrived(joinerUserId, palUserId, palArea)` remote to every client once it
-- exists. Listening only: nothing here fires a remote or changes game state.

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local PalWave = {}

local starts: { [number]: number } = {} -- each waving player's UserId, and the os.clock() its wave starts
local started = false

local function arrived(joiner: unknown, pal: unknown)
	if type(joiner) ~= "number" or type(pal) ~= "number" then
		return
	end
	local now = os.clock()
	local length = Avatar.waveSeconds()
	for userId, at in starts do
		if now - at >= length then
			starts[userId] = nil -- a wave that ended off screen
		end
	end
	starts[joiner] = now
	if pal ~= joiner then
		starts[pal] = now + Presets.palWave.palDelay
	end
end

-- The wave over a player's character this frame: its left arm's Transforms and how much of them to show, or nil and
-- 0 when that player is not waving.
function PalWave.layer(userId: number, rig: Avatar.Rig): ({ [Avatar.Joint]: CFrame }?, number)
	local at = starts[userId]
	if at == nil then
		return nil, 0
	end
	local seconds = os.clock() - at
	if seconds >= Avatar.waveSeconds() then
		starts[userId] = nil
		return nil, 0
	end
	local weight, swing = Avatar.waveAt(seconds)
	if weight <= 0 then
		return nil, 0
	end
	return Avatar.waveArm(rig, swing), weight
end

function PalWave.start()
	if started then
		return
	end
	started = true
	local moment = (Moments :: any).PalArrived
	if moment ~= nil then
		moment:Connect(arrived)
	else
		Context.whenRemote("PalArrived", function(remote: RemoteEvent)
			remote.OnClientEvent:Connect(arrived)
		end)
	end
end

return PalWave
