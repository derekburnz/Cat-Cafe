--!strict
-- #5112 (Derek 2026-11-17: "just so they don't miss it unlocking but do for stuff unlocked for tiers that unlock
-- important stuff"; Design-Agent's station-unlock-cutscene.md): the rank ups that cut the camera to the station they
-- unlock, once per account. The server streams the station's spot to the player as the rank up lands
-- (CafeService); the client (Controllers/StationCutController) waits up to WAIT seconds for the station to stream in,
-- plays Effects/StationUnlockCut and saves the key in tipsSeen (TipSeen, logged once as tip_shown with skipped
-- yes or no). A station that does not arrive in time gets an "Unlocked" toast instead (also saved, logged as skipped).
-- `stationCut` (LiveFlags, off by default) false plays nothing. Pure.

local StationCut = {}

StationCut.FLAG = "stationCut"
StationCut.PREFIX = "station_cut_"
StationCut.WAIT = 2 -- seconds the client waits for the station to stream in

-- The station each tier's rank up cuts to, by its CollectionService tag (Effects/Presets.stationCut has its words).
StationCut.TAGS = table.freeze({
	[3] = "ArcadeCabinet", -- the Town Square's StationTiers stations
	[4] = "MysticPool",
	[8] = "FusionObservatory",
	[9] = "TicketBooth",
	[10] = "DragonKeep",
} :: { [number]: string })

-- The tipsSeen key for `tier`'s cut.
function StationCut.key(tier: number): string
	return StationCut.PREFIX .. tostring(tier)
end

-- Whether `id` is one of these keys.
function StationCut.isKey(id: string): boolean
	if string.sub(id, 1, #StationCut.PREFIX) ~= StationCut.PREFIX then
		return false
	end
	local tier = tonumber(string.sub(id, #StationCut.PREFIX + 1))
	return tier ~= nil and StationCut.TAGS[tier] ~= nil and StationCut.key(tier) == id
end

-- The tag of the station a rank up to `tier` should cut to, or nil: the switch is off, no cut for that tier, or the
-- account has seen it (`seen` is tipsSeen).
function StationCut.due(tier: unknown, seen: { [string]: boolean }?, on: boolean): string?
	if not on or type(tier) ~= "number" then
		return nil
	end
	local tag = StationCut.TAGS[tier]
	if tag == nil or (seen ~= nil and seen[StationCut.key(tier)] == true) then
		return nil
	end
	return tag
end

return StationCut
