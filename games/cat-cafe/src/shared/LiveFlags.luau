--!strict
-- Live switches for features that may need to go off fast after a release (#2119), beside trading's own `trading`
-- and `tradeMinTier` (TradeVault). They live in the CatCafe_Flags DataStore (`_dev` in Studio), one boolean key
-- each, written by the flags workflow (tools/opencloud/flags.sh). LiveFlagService reads them every CHECK_SECONDS,
-- so a change reaches every running server within about a minute, with no publish and no restart.
-- - `codes`: false answers every RedeemCode with PAUSED and pays nothing (CodeService).
-- - `rally`: false stops a running Rescue Rally and keeps the next one from starting (RallyService). What was
--   already paid stays paid; turned on again mid-weekend, the bar starts again at lap 1 and the save's laps cap holds.
-- - `tradeCrates` (#2745, trading.md section 1c): false takes every crate off the open trades and refuses new crate
--   offers (TradeService); cat and decor trades go on.
-- - `tradeFish` (#2745, trading.md section 1d): golden fish in trades. It starts OFF (OFF_BY_DEFAULT) until QA and the
--   security review pass. Off takes every fish amount off the open trades, refuses new fish offers and lifts the
--   fish-spend freeze (TradeService).
-- - `awayNotes` (#2768): false stops the server noting who is due an away notification (AwayNotifyService). The
--   notes share MemoryStore's one quota with the pity cats' timers (64 KB plus 1 KB a player online), so this is
--   the way to stop them filling it without a publish. Notes already written expire by themselves.
-- - `nightCatch` (#3035): night catching for a Tier 1 player in their first session (shared/NightPass). It starts OFF
--   (OFF_BY_DEFAULT); true opens the Alleyway to them at night, and off again sends them home at the next night sweep.
-- - `swiftPaws` (#3063): false hides the Golden Fish Market's Swift Paws row, refuses a buy and drops its speed at
--   the next speed set (shared/SwiftPaws); saved levels are kept.
-- - `loadingScreen` (#3179, Derek2 2026-11-10: "remove the loading screen honestly I think that would make people
--   leave faster then before"): the loading screen before the opening scenes (#3105, #3109). It starts OFF
--   (OFF_BY_DEFAULT); true brings it back for players who join after, so the leave rates can be compared. Read by
--   the client alone (UI.intro.waiting), from the ReplicatedStorage attribute below.
-- - `alleyBin` (#3050): false hides the Rummage Bin's prompt at the Alleyway camp and refuses a rummage (BinService).
--   Saves keep their wait and wins.
-- - `goldenDrops` (#3222): the rare drop-only Golden lawn pieces from freed cats (Lawn.dropPick). It starts OFF
--   (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added the pieces is running, since
--   an older server's save check drops a lawn id it does not know.
-- LiveFlagService also copies each switch to a ReplicatedStorage attribute (ATTRIBUTE_PREFIX .. key) for the client.
-- Only an explicit false turns a feature off: a missing key, a value of another type or a failed read leaves it on
-- (a failed read keeps what the server had), so a broken store can't switch the game off. A key in OFF_BY_DEFAULT is
-- the other way round: only an explicit true turns it on, so a missing key or a broken store never switches it on.

local LiveFlags = {}

LiveFlags.STORE = "CatCafe_Flags"
-- - `starterRefill` (#3049): false stops the starting areas' camp trap refilling during the day for players who have
--   never rescued (RescueService), back to one cat a day there.
LiveFlags.KEYS = {
	"codes",
	"rally",
	"tradeCrates",
	"tradeFish",
	"awayNotes",
	"nightCatch",
	"starterRefill",
	"swiftPaws",
	"loadingScreen",
	"alleyBin",
	"goldenDrops",
}
-- Switches that stay off until the store holds an explicit true.
LiveFlags.OFF_BY_DEFAULT = {
	tradeFish = true,
	nightCatch = true,
	loadingScreen = true,
	goldenDrops = true,
} :: { [string]: boolean }
LiveFlags.CHECK_SECONDS = 60
LiveFlags.ATTRIBUTE_PREFIX = "LiveFlag_" -- #3063: the ReplicatedStorage attribute each switch is copied to

export type Flags = { [string]: boolean }

-- What a client makes of a switch's ReplicatedStorage attribute: a key in OFF_BY_DEFAULT is on only at an explicit
-- true (so it is off before the attribute has arrived), any other key is on unless it reads false.
function LiveFlags.shown(key: string, attribute: unknown): boolean
	if LiveFlags.OFF_BY_DEFAULT[key] then
		return attribute == true
	end
	return attribute ~= false
end

-- Every feature on, but those in OFF_BY_DEFAULT.
function LiveFlags.defaults(): Flags
	local out: Flags = {}
	for _, key in LiveFlags.KEYS do
		out[key] = LiveFlags.OFF_BY_DEFAULT[key] ~= true
	end
	return out
end

-- The switches from `raw`, the values read by key (nil for a missing key); keys not in KEYS are ignored.
function LiveFlags.parse(raw: unknown): Flags
	local out = LiveFlags.defaults()
	if type(raw) ~= "table" then
		return out
	end
	local values = raw :: { [any]: any }
	for _, key in LiveFlags.KEYS do
		if LiveFlags.OFF_BY_DEFAULT[key] then
			if values[key] == true then
				out[key] = true
			end
		elseif values[key] == false then
			out[key] = false
		end
	end
	return out
end

-- The keys whose value differs between `old` and `new`, in KEYS order.
function LiveFlags.changed(old: Flags, new: Flags): { string }
	local out: { string } = {}
	for _, key in LiveFlags.KEYS do
		if old[key] ~= new[key] then
			table.insert(out, key)
		end
	end
	return out
end

return LiveFlags
