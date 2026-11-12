--!strict
-- The Golden Fish Market (F53, golden-fish.md sections 3 and 4): a stall in the street plaza tagged FishMarket.
-- OpenCrate(crateId) opens a banked crate, or buys one for its price in golden fish, for a player within
-- FishMarketRange, with no other open of theirs in flight and CrateOpenCooldownSeconds (a 0.3 s spam limit, #1146)
-- after their last. The server rolls with its own Random (the lucky
-- twentieth on golden odds), adds the piece or pays its duplicate refund, puts a new furniture or decoration piece on
-- a free decor spot and answers CrateResult(crateId, decorId, duplicate, refund), so leaving mid-reveal keeps the
-- piece. BuyCrateBundle(crateId) (#1051) banks CrateBundleCount crates of one kind for CrateBundlePrice golden fish
-- and opens none. OpenAllCrates(crateId) (#2402) opens every banked crate of one kind at once, banked only.
-- #2745: a crate kind the player has on offer in an open trade can't be opened ("This crate is in a trade").
-- BuyFishItem(itemId) buys a food or a perk level. Every cost comes from Catalog.fishShop and Config, never
-- from the client. Golden fish are earned only: nothing here is sold for Robux (monetization-policy).
-- #3118 (Derek2 2026-11-10): the F94 Fresh Catch shelf is gone; its potions sell on the Day Cart (CornerService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local Crates = require(ReplicatedStorage.Shared.Crates)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Luck = require(ReplicatedStorage.Shared.Luck)
local LuckyCharm = require(ReplicatedStorage.Shared.LuckyCharm)
local Net = require(script.Parent.Net)
local RareMomentService = require(script.Parent.RareMomentService)
local SwiftPaws = require(ReplicatedStorage.Shared.SwiftPaws)
local Telemetry = require(script.Parent.Telemetry)
local Trade = require(ReplicatedStorage.Shared.Trade)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local FishMarketService = {}

FishMarketService.TAG = "FishMarket"

local random = Random.new()
local lastOpenAt: { [Player]: number } = {} -- os.clock() of each player's last crate start, for the spam limit
-- #1146: os.clock() of an open that has started and not yet sent its CrateResult. An open that errors part way never
-- clears it, so it counts only for IN_FLIGHT_SECONDS: an error cannot lock the player out of crates for good.
local inFlight: { [Player]: number } = {}
local IN_FLIGHT_SECONDS = 5
local luckLogs: { [Player]: number } = {} -- F88: luck_used crate events this session
local LUCK_LOGS_PER_SESSION = 20

local PERK_NAMES: { [string]: string } = {
	golden_espresso = "Golden Espresso",
	big_bowl = "Big Bowl",
	extra_decor_spot = "Extra Decor Spot",
	swift_paws = "Swift Paws", -- #3063
	[LuckyCharm.ID] = LuckyCharm.NAME, -- #3298
}

-- Saves a count, leaving a 0 out of the map (crates and crateLuck keep only what is there).
local function setCount(map: { [string]: number }, key: string, n: number)
	if n > 0 then
		map[key] = n
	else
		map[key] = nil
	end
end

-- True when the player stands within FishMarketRange of a Market stall.
local function nearMarket(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(FishMarketService.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - position).Magnitude <= Config.FishMarketRange
		then
			return true
		end
	end
	return false
end

-- Opens one crate for the player, the checks already passed: takes a banked crate or the price, rolls, pays.
-- Returns the piece, whether it was a duplicate, the refund and whether a new piece went on a decor spot.
local function open(
	player: Player,
	profile: Types.PlayerProfile,
	crate: Types.CrateDef
): (Types.DecorDef, boolean, number, boolean)
	-- roll first (pure), then pay, so an error in the roll never takes the crate or the fish (review N168)
	local luck = profile.crateLuck[crate.area] or 0
	-- F88: the player's Luck now multiplies a plain open's Epic and rarer chances (not the twentieth or golden ones)
	local playerLuck = Luck.of(
		profile,
		os.time(),
		ClockService.luckyDay(),
		EventService.luck(),
		LiveFlagService.on(LuckyCharm.FLAG) -- #3298
	)
	local decorId, lucky =
		Crates.roll(crate, luck, random:NextNumber(), random:NextNumber(), playerLuck)
	local def = Catalog.getDecor(decorId) :: Types.DecorDef
	local rarity: Types.Rarity = def.rarity or "Common"
	local banked = profile.crates[crate.id] or 0
	if banked > 0 then
		setCount(profile.crates, crate.id, banked - 1)
	else
		local price = crate.price :: number
		GoldenFish.trySpend(profile, price)
		Telemetry.fishSink(player, profile, price, "Shop", "crate")
	end
	setCount(profile.crateLuck, crate.area, Crates.luckAfter(luck, rarity))
	profile.stats.cratesOpened += 1

	local duplicate = profile.decorOwned[decorId] == true
	local refund = 0
	local placed = false
	if duplicate then
		refund = Crates.refund(rarity)
		GoldenFish.credit(profile, refund)
		Telemetry.fishSource(player, profile, refund, "Gameplay", "crate_refund")
	else
		profile.decorOwned[decorId] = true
		-- a new furniture or decoration piece takes a free spot by itself; a new wallpaper, floor or paint waits for
		-- the window's "Use it" (ToggleDecor). An old coin piece (F97: no kind, its own anchor, no spot) goes out at
		-- once, as the shop's did.
		local cap = Crates.spotCap(Economy.tier(profile), profile.fishPerks.extra_decor_spot or 0)
		if
			def.kind == nil
			or (
				Crates.takesSpot(def)
				and Crates.spotsUsed(profile, Economy.replacedDecor(profile)) < cap
			)
		then
			profile.decorPlaced[decorId] = true
			placed = true
		end
		if not placed then
			-- #2068: with Auto Equip on, it takes the weakest piece's place when it earns more
			placed = CafeService.autoEquipNewDecor(player, profile, decorId)
		end
	end
	-- Analytics keeps three custom fields (review N169): the crate, "<rarity> <kind>" and the outcome, so the odds
	-- can be checked against results.
	local outcome = (if duplicate then "duplicate" else "new") .. (if lucky then " lucky" else "")
	Telemetry.custom(
		player,
		"crate_opened",
		1,
		{ crate.id, rarity .. " " .. (def.kind or "unknown"), outcome }
	)
	-- at most LUCK_LOGS_PER_SESSION a session: an open is 1 a second, and on a Lucky Day every open qualifies (S109)
	local logged = luckLogs[player] or 0
	if playerLuck > 1 and not lucky and not crate.golden and logged < LUCK_LOGS_PER_SESSION then
		luckLogs[player] = logged + 1
		Telemetry.custom(
			player,
			"luck_used",
			playerLuck,
			{ "crate", rarity, tostring(Economy.tier(profile)) }
		)
	end
	return def, duplicate, refund, placed
end

-- #3362: an open never goes unanswered once its crate id is a real id. The Market window waits for the answer, and
-- with none its Open button gave up with "That didn't go through. Try again!" while nothing said why.
local STILL_LOADING = "Your save is still loading. Try again in a moment"
local FAILED = "That crate didn't open. Try again!"

local function traceback(message: any): string
	return debug.traceback(tostring(message), 2)
end

-- #3362: Net's answer to an OpenCrate dropped by its rate limit: the quiet empty CrateResult a spam refusal sends.
local function answerDroppedOpen(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	if crateId ~= nil then
		Net.fire(player, "CrateResult", crateId, "", false, 0)
	end
end

-- #3362: the same for a dropped Open all.
local function answerDroppedOpenAll(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	if crateId ~= nil then
		Net.fire(player, "CrateAllResult", crateId, {})
	end
end

local function onOpenCrate(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	if crateId == nil then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		-- #3362: just joined or just after a restart, before the save has loaded
		Net.toast(player, STILL_LOADING, "warn")
		Net.fire(player, "CrateResult", crateId, "", false, 0)
		return
	end
	local function refuse(reason: string)
		Net.toast(player, reason, "warn")
		Net.fire(player, "CrateResult", crateId, "", false, 0)
		CafeService.sync(player)
	end
	if not nearMarket(player) then
		refuse("Walk to the Golden Fish Market first")
		return
	end
	-- #1146: refused only while another open is in flight or within the short spam limit. The Market window waits
	-- out both itself, so a player never sees this; a spam refusal stays quiet (the empty CrateResult still frees the
	-- button). An open never yields today, so "busy" guards a future yield more than a race; the spam limit is what
	-- stops a script.
	local now = os.clock()
	local started = inFlight[player]
	local gate = Crates.openRefusal(
		started ~= nil and now - started < IN_FLIGHT_SECONDS,
		lastOpenAt[player],
		now
	)
	if gate == "busy" then
		refuse("One crate at a time")
		return
	elseif gate == "spam" then
		Net.fire(player, "CrateResult", crateId, "", false, 0)
		return
	end
	local blocker: string? = Crates.openBlocker(profile, Economy.tier(profile), crateId)
	if blocker == nil and CafeService.crateOffered(player, crateId) > 0 then
		blocker = Trade.Messages.crateInTrade -- #2745: a crate on offer waits for the trade
	end
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	-- #2745 (section 1d): an open paid with fish waits for the trade too
	local frozen = TradeService.fishSpendBlocker(player)
	if frozen ~= nil and (profile.crates[crateId] or 0) < 1 then
		refuse(frozen)
		return
	end
	lastOpenAt[player] = now
	inFlight[player] = now
	-- #3362: an error in the open still answers (and syncs, so the count shown is the server's), instead of leaving
	-- the button waiting and the in-flight flag set for IN_FLIGHT_SECONDS
	local ok, def, duplicate, refund, placed =
		xpcall(open, traceback, player, profile, Catalog.getCrate(crateId) :: Types.CrateDef)
	if not ok then
		inFlight[player] = nil
		warn(
			string.format(
				"[FishMarket] OpenCrate %s failed for user %d: %s",
				crateId,
				player.UserId,
				tostring(def)
			)
		)
		refuse(FAILED)
		return
	end
	Net.fire(player, "CrateResult", crateId, def.id, duplicate, refund)
	inFlight[player] = nil
	RareMomentService.foundDecor(player, def) -- F89: a Mythical piece toasts the server
	if placed then
		CafeService.refreshPlot(player)
	end
	CafeService.sync(player)
end

-- #2402: Open all. Every banked crate of `crateId`, up to Crates.OPEN_ALL_MAX, opened one after the other as OpenCrate
-- opens one (same roll, same crate luck between them), under the same range, in-flight and spam rules. Banked only:
-- it never spends golden fish. Answers CrateAllResult(crateId, opened), empty when refused, then one sync.
local function onOpenAllCrates(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	if crateId == nil then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		Net.toast(player, STILL_LOADING, "warn") -- #3362
		Net.fire(player, "CrateAllResult", crateId, {})
		return
	end
	local function refuse(reason: string?)
		if reason ~= nil then
			Net.toast(player, reason, "warn")
		end
		Net.fire(player, "CrateAllResult", crateId, {})
		CafeService.sync(player)
	end
	if not nearMarket(player) then
		refuse("Walk to the Golden Fish Market first")
		return
	end
	local now = os.clock()
	local started = inFlight[player]
	local gate = Crates.openRefusal(
		started ~= nil and now - started < IN_FLIGHT_SECONDS,
		lastOpenAt[player],
		now
	)
	if gate == "busy" then
		refuse("One crate at a time")
		return
	elseif gate == "spam" then
		refuse(nil)
		return
	end
	local crate = Catalog.getCrate(crateId)
	local count = Crates.openAllCount(profile, crateId)
	if crate == nil or count < 1 then
		refuse("No crates of this kind to open")
		return
	end
	local blocker: string? = Crates.openBlocker(profile, Economy.tier(profile), crateId)
	if blocker == nil and CafeService.crateOffered(player, crateId) > 0 then
		blocker = Trade.Messages.crateInTrade -- #2745
	end
	if blocker ~= nil then
		refuse(blocker)
		return
	end
	lastOpenAt[player] = now
	inFlight[player] = now
	local opened: { Crates.Opened } = {}
	local placedAny = false
	-- #3362: an error part way still answers with the pieces already opened (they are the player's), then syncs
	local ok, err = xpcall(function(): any
		for _ = 1, count do
			if (profile.crates[crateId] or 0) < 1 then
				break -- banked only: open() would buy one with golden fish
			end
			local def, duplicate, refund, placed = open(player, profile, crate :: Types.CrateDef)
			table.insert(opened, { decorId = def.id, duplicate = duplicate, refund = refund })
			placedAny = placedAny or placed
			RareMomentService.foundDecor(player, def) -- F89: a Mythical piece toasts the server
		end
		return nil :: any
	end, traceback)
	if not ok then
		warn(
			string.format(
				"[FishMarket] OpenAllCrates %s failed for user %d after %d: %s",
				crateId,
				player.UserId,
				#opened,
				tostring(err)
			)
		)
		if #opened == 0 then
			Net.toast(player, FAILED, "warn")
		end
	end
	Net.fire(player, "CrateAllResult", crateId, opened)
	inFlight[player] = nil
	if placedAny then
		CafeService.refreshPlot(player)
	end
	CafeService.sync(player)
end

-- Buy 5 (#1051, crate-prices.md section 3): CrateBundleCount crates of one kind banked for CrateBundlePrice golden
-- fish, none opened, so each still shows its own odds and lucky count when it opens. Net allows 1 a second.
local function onBuyCrateBundle(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	local profile = DataService.get(player)
	if crateId == nil or profile == nil then
		return
	end
	if not nearMarket(player) then
		Net.toast(player, "Walk to the Golden Fish Market first", "warn")
		return
	end
	local blocker = Crates.bundleBlocker(profile, Economy.tier(profile), crateId)
		or TradeService.fishSpendBlocker(player) -- #2745 (section 1d)
	local price = Config.CrateBundlePrice
	if blocker ~= nil or not GoldenFish.trySpend(profile, price) then
		Net.toast(player, blocker or "Not enough golden fish", "warn")
		CafeService.sync(player)
		return
	end
	local count = Config.CrateBundleCount
	profile.crates[crateId] = (profile.crates[crateId] or 0) + count
	Telemetry.fishSink(player, profile, price, "Shop", "crate_bundle")
	local crate = Catalog.getCrate(crateId) :: Types.CrateDef
	Net.toast(
		player,
		string.format("%d %ss banked. Open them one by one", count, crate.name),
		"good"
	)
	CafeService.sync(player)
end

local function onBuyFishItem(player: Player, rawItemId: unknown)
	local itemId = Guard.id(rawItemId)
	local profile = DataService.get(player)
	if itemId == nil or profile == nil then
		return
	end
	local row = Catalog.getFishShopRow(itemId)
	if row == nil then
		return
	end
	if itemId == SwiftPaws.ID and not LiveFlagService.on(SwiftPaws.FLAG) then
		-- #3063: the live switch is off, so the row is hidden; nothing is spent
		Net.toast(player, "Swift Paws is resting for now", "warn")
		return
	end
	if itemId == LuckyCharm.ID and not LiveFlagService.on(LuckyCharm.FLAG) then
		-- #3298: the live switch is off, so the row is hidden; nothing is spent
		Net.toast(player, "The Lucky Charm is not here yet", "warn")
		return
	end
	if not nearMarket(player) then
		Net.toast(player, "Walk to the Golden Fish Market first", "warn")
		return
	end
	if
		itemId == SwiftPaws.ID
		and (profile.fishPerks[itemId] or 0)
			>= SwiftPaws.topLevel(row.maxLevel or 1, LiveFlagService.on(SwiftPaws.FLAG_FIVE))
	then
		-- #3317: levels 3 to 5 wait on their own switch until no older server is left; nothing is spent
		Net.toast(player, "Swift Paws levels 3 to 5 open soon", "warn")
		CafeService.sync(player)
		return
	end
	local cost, reason = Crates.buyCost(profile, row)
	local frozen = TradeService.fishSpendBlocker(player) -- #2745 (section 1d)
	if frozen ~= nil then
		cost, reason = nil, frozen
	end
	if cost == nil or not GoldenFish.trySpend(profile, cost) then
		Net.toast(player, reason or "Not enough golden fish", "warn")
		CafeService.sync(player)
		return
	end
	if row.kind == "lure" then
		profile.lures[itemId] = (profile.lures[itemId] or 0) + 1
		Telemetry.fishSink(player, profile, cost, "Shop", "lure")
		local lure = Catalog.getLure(itemId)
		Net.toast(
			player,
			string.format("Bought a %s", if lure ~= nil then lure.name else itemId),
			"good"
		)
	else
		local level = (profile.fishPerks[itemId] or 0) + 1
		profile.fishPerks[itemId] = level
		Telemetry.fishSink(player, profile, cost, "Shop", "perk")
		Net.toast(
			player,
			if itemId == SwiftPaws.ID
				-- #3330: say it is speed, and how much in all
				then string.format(
					"Swift Paws level %d: +%s speed, yours forever",
					level,
					tostring(SwiftPaws.speedAt(level))
				)
				elseif itemId == LuckyCharm.ID then string.format(
					"Lucky Charm level %d: +%s Luck, yours forever",
					level,
					tostring(LuckyCharm.luckAt(level))
				)
				else string.format(
					"%s level %d, yours forever",
					PERK_NAMES[itemId] or itemId,
					level
				),
			"good"
		)
		if itemId == "big_bowl" then
			-- the next food waits less; a bowl filled since F54 keeps the readyAt UseLure gave it, as with Index
			-- claims, and only an older bowl without one moves up
			CafeService.refreshPlot(player)
		elseif itemId == SwiftPaws.ID then
			CatService.refreshSpeed(player) -- #3063: the new speed at once
		end
	end
	CafeService.sync(player)
end

function FishMarketService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastOpenAt[player] = nil
		inFlight[player] = nil
		luckLogs[player] = nil
	end)
	Net.on("OpenCrate", onOpenCrate, answerDroppedOpen) -- #3362: a rate limit drop still answers
	Net.on("OpenAllCrates", onOpenAllCrates, answerDroppedOpenAll) -- #2402
	Net.on("BuyCrateBundle", onBuyCrateBundle)
	Net.on("BuyFishItem", onBuyFishItem)
end

-- Studio-only test hook (Debug.giveCrate): banks `count` of a crate, which the Market then opens for free.
function FishMarketService.debugGive(
	player: Player,
	profile: Types.PlayerProfile,
	crateId: string,
	count: number
)
	assert(Catalog.getCrate(crateId) ~= nil, "unknown crate " .. crateId)
	setCount(profile.crates, crateId, math.floor(count))
	lastOpenAt[player] = nil
	inFlight[player] = nil
	CafeService.sync(player)
end

return FishMarketService
