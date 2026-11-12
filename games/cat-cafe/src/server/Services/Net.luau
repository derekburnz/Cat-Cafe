--!strict
-- Owns the RemoteEvents. Creates them from the shared list, rate limits every client -> server call,
-- and gives services typed-ish helpers to fire. Handlers get already rate-limited calls; they still validate args.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Net = {}

local events: { [string]: RemoteEvent } = {}
-- Three layers: one bucket for everything a player sends (the ceiling), one per remote, and slower buckets for
-- remotes that do real work per call (a grab or rescue attempt, a full profile serialize, a claim, a tutorial step).
local globalLimiter = RateLimiter.new(Config.RemoteRateLimitPerSecond * 3, 1)
local defaultLimiter = RateLimiter.new(Config.RemoteRateLimitPerSecond, 1)
local slowLimiters: { [string]: RateLimiter.RateLimiter } = {
	SwingNet = RateLimiter.new(3, 1), -- F93: a flood guard; CatService holds NetSwingCooldown from each swing
	RescueBegin = RateLimiter.new(1, 1),
	RescueCancel = RateLimiter.new(1, 1),
	ArcadeStart = RateLimiter.new(1, 1), -- #3062
	ArcadeQuit = RateLimiter.new(1, 1),
	MouseDashStart = RateLimiter.new(1, 1), -- #3296
	MouseDashTap = RateLimiter.new(12, 1),
	MouseDashQuit = RateLimiter.new(1, 1),
	RollTrait = RateLimiter.new(1, 1), -- #3196
	ChooseTrait = RateLimiter.new(1, 1),
	CollectTraitTokens = RateLimiter.new(1, 1),
	RescueHelp = RateLimiter.new(1, 1), -- F92 (playing-together.md section 6): 1 a second
	DropCat = RateLimiter.new(1, 1),
	RequestSync = RateLimiter.new(1, 2),
	ClaimOffline = RateLimiter.new(1, 2),
	EquipBest = RateLimiter.new(1, 2), -- sorts, solves, rebuilds the plot and sends a full sync
	UnequipAll = RateLimiter.new(1, 2), -- rebuilds the plot and sends a full sync, like EquipBest
	EquipBestDecor = RateLimiter.new(1, 2), -- rebuilds the plot's decor and sends a full sync, like EquipBest
	ResetSave = RateLimiter.new(1, 5), -- testers only; kicks on success
	RankUp = RateLimiter.new(1, 2), -- data-model section 15: 1 per 2 s
	TutorialAdvance = RateLimiter.new(1, 1),
	Travel = RateLimiter.new(1, 1), -- a flood guard; TravelService answers TravelCooldownSeconds with a reason
	LaunchCannon = RateLimiter.new(1, 1), -- hometown-cannon.md section 7: 1 a second
	BuyDealerFood = RateLimiter.new(2, 1), -- recomputes the stock and answers with DealerStock every time
	BuyDealerAll = RateLimiter.new(1, 2), -- #2573: a whole plan at once, so slower than one buy
	UseLure = RateLimiter.new(2, 1), -- rolls a cat and rebuilds the bowl; 2 so both bowls can fill at once (#1161)
	ResolveBait = RateLimiter.new(2, 1), -- the card retries after 6 s at most; 2 for both bowls' cats (#1161)
	ClaimRichTip = RateLimiter.new(1, 1), -- the Collect button waits 3 s for an answer
	TakeCozy = RateLimiter.new(1, 1), -- #2854: one bag waits at a time
	Tackle = RateLimiter.new(2, 1), -- a flood guard; ShoveService holds TackleCooldownSeconds from each press
	LockCat = RateLimiter.new(4, 1), -- data-model section 15: 4 a second (tapping the lock icon on cat cards)
	LockDecor = RateLimiter.new(4, 1), -- #1574: as LockCat, the lock on a decor card
	RenameCat = RateLimiter.new(1, 1), -- a flood guard; NameService answers RenameCooldownSeconds with a reason
	-- data-model section 15 said 10 a minute; #1273 adds the intro's eleven shots, the tutorial cards and the screen
	-- open, each allowlisted and logged at most once a player or a session (Telemetry's onReport)
	TelemetryReport = RateLimiter.new(40, 60),
	SetSetting = RateLimiter.new(4, 1), -- a toggle tap; each call sends a full sync
	PassClaim = RateLimiter.new(4, 1), -- #1645: a Claim tap on the Pass screen
	PassClaimAll = RateLimiter.new(1, 1), -- #1645
	PassSetTag = RateLimiter.new(2, 1), -- #1626: the Pass screen's tag picker
	SetSignStyle = RateLimiter.new(2, 1), -- #1625: a pick on the Style panel; each one refreshes the plot
	SetLook = RateLimiter.new(2, 1), -- #1624: a theme or uniform pick on the Style tab; each refreshes the plot
	-- #1168 row 2: a song pick on the Jukebox card; #3299: 4 a second, so the last of a few quick taps through the list
	-- still lands (the live log showed drops, and a dropped last pick leaves the card and the music apart)
	SetJukeboxTrack = RateLimiter.new(4, 1),
	MarkStoreSeen = RateLimiter.new(2, 1), -- #1842: a Store tab opened (only a change syncs)
	ClaimTipJar = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	ClaimIndexReward = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	SpinAll = RateLimiter.new(1, 1), -- #1078: 1 a second (and the spin cooldown)
	SpinWheel = RateLimiter.new(2, 1), -- SpinService also holds each player to SpinCooldownSeconds between spins
	-- #1146: a flood guard only; FishMarketService refuses an open while one is in flight or within
	-- CrateOpenCooldownSeconds (0.3 s) of the last, so Quick open and Buy 5's crates one by one go through
	OpenCrate = RateLimiter.new(3, 1),
	BuyCrateBundle = RateLimiter.new(1, 1), -- #1051: 1 a second
	OpenAllCrates = RateLimiter.new(1, 2), -- #2402: 1 every 2 seconds (and the crate spam limit)
	BuyFishItem = RateLimiter.new(2, 1), -- golden-fish.md section 8: 2 a second
	BuyMystery = RateLimiter.new(1, 1), -- #2565 (mystery-market.md section 5): 1 a second
	MarkMysterySeen = RateLimiter.new(1, 2), -- #2565: one save flag
	RedeemCode = RateLimiter.new(1, 2), -- data-model section 11d: 1 per 2 s; CodeService locks after wrong codes
	IntroDone = RateLimiter.new(1, 1), -- intro-cutscene.md section 3: 1 a second; each call logs one event
	SetHideCredit = RateLimiter.new(1, 1), -- #1083: 1 a second
	OwnerGrant = RateLimiter.new(1, 1), -- #1770: owner test mode, 1 a second
	ReportBug = RateLimiter.new(1, 1), -- a flood guard; BugReportService answers its own 1 per 20 s with a toast
	UsePotion = RateLimiter.new(2, 1), -- data-model section 15: 2 a second
	UsePotionAll = RateLimiter.new(1, 2), -- #3326: 1 per 2 s; one call drinks the whole bag
	OpenMysteryGift = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	AnswerCollector = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	ClaimQuest = RateLimiter.new(2, 1), -- quests.md section 6: 2 a second
	RerollQuest = RateLimiter.new(1, 1), -- 1 a second
	ClaimAchievement = RateLimiter.new(2, 1), -- 2 a second
	ClaimAll = RateLimiter.new(2, 2), -- 2 per 2 s, so daily then weekly both land; each pays every ready one and syncs
	ClaimDailyTreat = RateLimiter.new(1, 1), -- data-model section 15: 1 a second
	TipSeen = RateLimiter.new(1, 1), -- F87 (easy-start.md section 6): 1 a second
	ClearTips = RateLimiter.new(1, 10), -- F87: 1 per 10 s; each call sends a full sync
	-- #2910: a count only. #3299: 4 a second, as a ring and its prompt can both fire as a player walks in and taps
	StationOpened = RateLimiter.new(4, 1),
	SendFeedback = RateLimiter.new(1, 10), -- F87: 1 per 10 s; TipService also holds FeedbackSessionLimit a session
	SessionFeedback = RateLimiter.new(1, 30), -- #3272: 1 per 30 s; TipService also holds it to once a UTC day
	ClaimStarterCat = RateLimiter.new(1, 2), -- F96 (starter-cat.md section 4): 1 per 2 s
	CollectCampExtra = RateLimiter.new(1, 1), -- F100 (camp-extras.md section 4): 1 a second
	-- #2651 part 4 (late-stations.md section 3): 1 a second each. #3299: the live log showed drops on the Spa and the
	-- Museum, where a player fills slots or donates relics with quick taps one after another and a dropped tap just
	-- does nothing; 3 a second for those (each call is checked in LateStationService as before). Buying a slot stays 1.
	SpaPut = RateLimiter.new(3, 1),
	SpaTakeOut = RateLimiter.new(3, 1),
	SpaCollect = RateLimiter.new(3, 1),
	SpaBuySlot = RateLimiter.new(1, 1),
	MuseumDonate = RateLimiter.new(3, 1),
	MuseumFill = RateLimiter.new(1, 2), -- #3130: Auto fill, a whole hall in one call
	InviteCard = RateLimiter.new(1, 2), -- #2797: the invite card's report, 1 per 2 s
	BuyYardSale = RateLimiter.new(1, 1), -- F100: 1 a second
	BuyCornerShop = RateLimiter.new(2, 1), -- #1052: 2 a second
	BuyCornerShopAll = RateLimiter.new(1, 2), -- #2593: a section's Buy all
	SellExtraCommons = RateLimiter.new(1, 2), -- #1573: 1 per 2 s; sells many at once and sends a full sync
	FeedCat = RateLimiter.new(4, 1), -- #1181: 4 a second
	-- F91 (front-lawn.md section 5): each rebuilds the lawn and sends a full sync
	BuyLawn = RateLimiter.new(2, 1),
	SetLawnSpot = RateLimiter.new(4, 1),
	SetLawnStyle = RateLimiter.new(2, 1),
	-- F102 (trading.md section 4): 5 trade calls a second, one request out at a time (TradeBook)
	TradeRequest = RateLimiter.new(1, 1),
	TradeRespond = RateLimiter.new(2, 1),
	TradeOffer = RateLimiter.new(5, 1),
	TradeReady = RateLimiter.new(2, 1),
	TradeConfirm = RateLimiter.new(2, 1),
	TradeCancel = RateLimiter.new(1, 1),
}
local overLimitLog: { [number]: number } = {} -- userId -> last handler-failure warn time
-- #2630: rate limit drops are counted per player and remote, and written as one summary line a minute at most.
-- A drop is harmless (the server just ignores the extra tap), so one warning each hid the real errors in the log.
local DROP_SUMMARY_SECONDS = 60
-- #3478: remotes whose extra calls are expected and already spaced on the client (a Tackle key held down, a second
-- press on the cannon while it loads). A summary line made only of these is a note (print), not a warning, so it
-- stays out of the Creator Hub error list.
local QUIET_DROPS: { [string]: boolean } = {
	Tackle = true,
	LaunchCannon = true,
}
local dropCounts: { [number]: { [string]: number } } = {} -- userId -> remote -> drops since the last summary
local dropLoggedAt: { [number]: number } = {} -- userId -> when the last summary line was written
-- #3362: a remote connected with an onDrop answer (Net.on's third argument) still answers a dropped call, so a client
-- waiting on that answer frees its button at once instead of timing out. At most 2 such answers a second per player
-- and remote, so a flood of calls cannot turn into a flood of answers.
local dropAnswerLimiter = RateLimiter.new(2, 1)

local function limiterFor(name: string): RateLimiter.RateLimiter
	return slowLimiters[name] or defaultLimiter
end

-- Logged at most once a second per player so a fuzzing client cannot fill the server log.
local function logOnce(player: Player, message: string)
	local now = os.clock()
	if (overLimitLog[player.UserId] or 0) + 1 < now then
		overLimitLog[player.UserId] = now
		warn(message)
	end
end

-- #2630: count a dropped call; write "user N: Remote xK, ..." when the minute since the last line is up, so the
-- first drop of a quiet player still shows at once and a burst becomes one line.
local function noteDrop(player: Player, name: string)
	local userId = player.UserId
	local counts = dropCounts[userId]
	if counts == nil then
		counts = {}
		dropCounts[userId] = counts
	end
	counts[name] = (counts[name] or 0) + 1
	local now = os.clock()
	local last = dropLoggedAt[userId]
	if last ~= nil and last + DROP_SUMMARY_SECONDS > now then
		return
	end
	dropLoggedAt[userId] = now
	local parts = {}
	local quiet = true
	for remote, count in counts do
		table.insert(parts, string.format("%s x%d", remote, count))
		if QUIET_DROPS[remote] ~= true then
			quiet = false
		end
	end
	table.sort(parts)
	dropCounts[userId] = nil
	local line =
		string.format("[Net] rate limit drops for user %d: %s", userId, table.concat(parts, ", "))
	if quiet then
		print(line)
	else
		warn(line)
	end
end

function Net.start()
	local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = Remotes.FolderName
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, list in { Remotes.ClientToServer, Remotes.ServerToClient } do
		for _, name in list do
			local existing = (folder :: Folder):FindFirstChild(name)
			if existing == nil then
				local event = Instance.new("RemoteEvent")
				event.Name = name
				event.Parent = folder
				existing = event
			end
			events[name] = existing :: RemoteEvent
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local key = tostring(player.UserId)
		globalLimiter:forget(key)
		for name in events do
			defaultLimiter:forget(key .. name)
		end
		for name, limiter in slowLimiters do
			limiter:forget(key .. name)
		end
		for name in events do
			dropAnswerLimiter:forget(key .. name)
		end
		overLimitLog[player.UserId] = nil
		dropCounts[player.UserId] = nil
		dropLoggedAt[player.UserId] = nil
	end)
end

-- Connects a client -> server handler behind the rate limiter. Over the limit: dropped, counted in a summary line.
-- #3362: `onDrop`, when given, runs for a dropped call (its own limit, see dropAnswerLimiter) so it can send the
-- refusal answer the client waits for. It gets the raw arguments: validate them as the handler would.
function Net.on(
	name: string,
	handler: (player: Player, ...any) -> (),
	onDrop: ((player: Player, ...any) -> ())?
)
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event.OnServerEvent:Connect(function(player: Player, ...: any)
		local key = tostring(player.UserId)
		if not (globalLimiter:allow(key) and limiterFor(name):allow(key .. name)) then
			noteDrop(player, name)
			if onDrop ~= nil and dropAnswerLimiter:allow(key .. name) then
				local answer = onDrop
				local args = table.pack(...)
				local ok, err = pcall(function()
					answer(player, table.unpack(args, 1, args.n))
				end)
				if not ok then
					logOnce(
						player,
						string.format(
							"[Net] %s drop answer failed for user %d: %s",
							name,
							player.UserId,
							tostring(err)
						)
					)
				end
			end
			return
		end
		local ok, err = xpcall(function(...: any)
			handler(player, ...)
			return nil :: any
		end, function(message: any): string
			return debug.traceback(tostring(message), 2)
		end, ...)
		if not ok then
			logOnce(
				player,
				string.format(
					"[Net] %s handler failed for user %d: %s",
					name,
					player.UserId,
					tostring(err)
				)
			)
		end
	end)
end

function Net.fire(player: Player, name: string, ...: any)
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	local event: RemoteEvent? = events[name]
	if event == nil then
		error("[Net] unknown remote " .. name)
	end
	event:FireAllClients(...)
end

function Net.toast(player: Player, text: string, kind: Types.ToastKind?)
	Net.fire(player, "Toast", text, kind or "info")
end

return Net
