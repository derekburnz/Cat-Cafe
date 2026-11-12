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
-- - `traits` (#3196): the Mystic Pool's cat traits (shared/Traits). It starts OFF (OFF_BY_DEFAULT): switch it on only with
--   the restart publish that ships the trait save fields, so no older server can drop a cat's trait.
-- - `swiftPaws5` (#3317): Swift Paws levels 3 to 5 in the Golden Fish Market (shared/SwiftPaws). It starts OFF
--   (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added them is running, since an
--   older server keeps a saved level only up to 2.
-- - `mouseDash` (#3296): the Cat Arcade's second game, Mouse Dash (shared/MouseDash). It starts OFF (OFF_BY_DEFAULT)
--   until QA passes: off refuses a start; a game already running finishes and pays. On, it is the game the
--   cabinet and the Menu row open (Derek 2026-11-11: "Swap this in for the current arcade game and vault the other
--   one").
-- - `circleStreak` (#3296): false vaults Circle Streak: no start from the cabinet, the Menu row or the remote. Its
--   code, save and board stay, so switching it back on brings the game back. The swap is `mouseDash` on and this
--   off; while both are on (testing) the Mouse Dash card has a button to Circle Streak.
-- - `cartTier6` (#3462): the Day Cart's Tier 6 shelf, its own two baits and three potions (shared/CornerShop's top
--   shelf). It starts OFF (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added the
--   items is running, since an older server's save check drops a food or potion id it does not know.
-- - `secretCats` (#3470): Secret cats, the rarity above Mythical. It starts OFF (OFF_BY_DEFAULT): off, nothing rolls
--   Secret anywhere. Switch it on only once no server older than the publish that added them is running, since an
--   older server's save check drops a cat id it does not know.
-- - `luckyCharm` (#3298): the Golden Fish Market's Lucky Charm perk (shared/LuckyCharm). It starts OFF
--   (OFF_BY_DEFAULT): off hides the row, refuses a buy and adds no Luck. Switch it on only once no server older than
--   the publish that added the row is running, since an older server's save check drops a perk id it does not know.
-- - `rareCatsTab` (#3053): the chat's own "Rare Cats" tab with every Mythical or better line from every server
--   (shared/RareCatsTab). It starts OFF (OFF_BY_DEFAULT): off, no channel is made and the chat has no tab bar. Derek
--   said on 2026-11-10 he did not want a tab of our own, so it goes on only after he has seen the pictures.
-- - `afkCafe` (#3573): resting in your own cafe pays the cats' cafe pay double (shared/AfkCafe). It starts OFF
--   (OFF_BY_DEFAULT); off, nobody rests, a rest under way ends at the next check and the lines do not show.
-- - `autoRejoin` (#3602): a player resting in their cafe with no input for Config.AutoRejoinSeconds is teleported back into
--   the game before Roblox's 20 minute idle disconnect (shared/AfkCafe). It starts OFF (OFF_BY_DEFAULT) and does
--   nothing while `afkCafe` is off.
-- - `binRoll` (#3608): the Rummage Bin rolls its prize before the bar, from Config.BinRollTable, and keeps it for the
--   player until they win it (shared/RummageBin); the board, the roll and the pad come with it. It starts OFF
--   (OFF_BY_DEFAULT); off, the bin is as it was.
-- - `yardSaleRoll` (#3609): the Yard Sale's free crate becomes a free lucky pick every Config.YardSaleRollHours that
--   lands on a crate, golden crates included (shared/YardPick). It starts OFF (OFF_BY_DEFAULT); off, the Yard Sale
--   is as it was.
-- - `introSplit` (#3666): the intro scene plays itself for half of new players (shared/IntroSplit), so the two
--   halves' first minutes can be compared. It starts OFF (OFF_BY_DEFAULT); off, nobody new joins the test and no
--   intro plays itself.
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
	"arcade", -- #3062: false hides the Cat Arcade's prompt and menu tile; a game already running finishes and pays
	"goldenDrops",
	"traits",
	"swiftPaws5",
	"mouseDash",
	"circleStreak",
	"cartTier6",
	"secretCats",
	"luckyCharm",
	"rareCatsTab",
	"afkCafe",
	"autoRejoin",
	"binRoll",
	"yardSaleRoll",
	"introSplit",
}
-- Switches that stay off until the store holds an explicit true.
LiveFlags.OFF_BY_DEFAULT = {
	tradeFish = true,
	nightCatch = true,
	loadingScreen = true,
	goldenDrops = true,
	traits = true,
	swiftPaws5 = true,
	mouseDash = true,
	cartTier6 = true,
	secretCats = true,
	luckyCharm = true,
	rareCatsTab = true,
	afkCafe = true,
	autoRejoin = true,
	binRoll = true,
	yardSaleRoll = true,
	introSplit = true,
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
