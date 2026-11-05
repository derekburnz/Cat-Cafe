--!strict
-- F102 trading (docs/design/cat-cafe/trading.md). Players from TradeMinTier swap cats in the town or a camp; the client
-- only asks, and this service holds every request and trade (Util/TradeBook) and decides.
-- - Asking (section 2): TradeRequest(userId) is checked with Trade.askRefusal on both players (tier, kill switch, safe
--   zone, busy, one request out, re-ask wait, cooldown, TradesPerDay, the target's Trade requests setting) and sends
--   the target TradeAsked. TradeRespond(requestId, accept) checks both again before the trade opens.
-- - The trade (section 3): TradeOffer adds a cat that Trade.offerRefusal lets go (theirs, unlocked, not exclusive, up
--   to TradeMaxCats) and that leaves the player a cat, or takes one away; either way both sides start over. Ready and
--   Confirm carry the version and are refused for an old one. Both players get TradeState after every change.
--   Walking into the wild, starting a carry, catch, rescue or flight, Cancel, leaving or the kill switch ends it.
-- - The swap (section 4): checked once more, then the record goes to CatCafe_Trades ("pending") and a pointer under
--   each player (TradeVault), the record is decided "commit", both profiles take their side (Trade.apply, apply once
--   per trade id) and save, and each pointer is cleared after a save that holds the trade. A server that stops after
--   the decision leaves pointers; the next join (DataService.onLoading, before anything can use the profile) finishes
--   that player's side from the record, or voids a trade nobody decided. When the decision cannot be read back, both
--   players are sent to rejoin so their joins settle it.
-- - Selling, the Cat Collector, locking and Reset my save wait for a cat on offer (CafeService.isOffered,
--   TradeService.isTrading).
-- - #1574 (section 1b): decor joins. TradeOffer with kind "decor" offers a crate decor or lawn piece that
--   Trade.pieceRefusal lets go (theirs, tradeable, unlocked, not the partner's already, up to TradeMaxDecor), checked
--   again at the swap. The record carries each side's piece ids; after the swap both sides' decor and lawn Equip Best
--   runs (CafeService.autoEquipDecor), so a placed piece that left is refilled and an arriving one goes out.
-- - Player attributes Tier and Trading, Workspace attributes TradingOn and TradeMinTier (the live minimum: Debug in
--   Studio, else CatCafe_Flags.tradeMinTier, else Config) for the UI. CatCafe_Flags is read every
--   TradeFlagCheckSeconds.
-- - Nothing here prints a user id, a name or a cat list (section 4: the repo and its CI logs are public); trade_done
--   logs counts and rarities only.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Telemetry = require(script.Parent.Telemetry)
local Trade = require(ReplicatedStorage.Shared.Trade)
local TradeBook = require(script.Parent.Parent.Util.TradeBook)
local TradeVault = require(script.Parent.TradeVault)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

type Profile = Types.PlayerProfile
type Swap = { player: Player, mine: TradeVault.RecordSide, theirs: TradeVault.RecordSide }

local TradeService = {}

TradeService.STEP_SECONDS = 0.25 -- the countdown, request and safe zone checks
TradeService.KICK_TEXT = "Your trade is still being saved. Please rejoin in a minute."

local book = TradeBook.new()
local tradingOn = true
local flagOn = true -- CatCafe_Flags.trading
local debugOn: boolean? = nil -- Studio's Debug.trading, over the flag
local flagMinTier: number? = nil -- CatCafe_Flags.tradeMinTier
local debugMinTier: number? = nil -- Studio's Debug.tradeMinTier, over the flag
local friendCache: { [string]: boolean } = {}
local settled: { [Player]: { string } } = {} -- trades a join applied, their pointers cleared after the next save

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newId(): string
	return string.lower(HttpService:GenerateGUID(false))
end

-- A trade or request id as the client sends it back: a lowercase GUID.
local function guardId(value: unknown): string?
	if type(value) ~= "string" or #value > 40 or value:match("^[%x%-]+$") == nil then
		return nil
	end
	return value
end

local function minTier(): number
	return debugMinTier or flagMinTier or Config.TradeMinTier
end

local function publish()
	Workspace:SetAttribute("TradingOn", tradingOn)
	Workspace:SetAttribute("TradeMinTier", minTier())
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- In the town (no catching area: the street, the square, a cafe) or a camp. `noBody` answers for a player between
-- characters.
local function isSafe(player: Player, noBody: boolean): boolean
	local root = rootOf(player)
	if root == nil then
		return noBody
	end
	local position = root.Position
	return WorldBuilder.areaAt(PlotService.world(), position) == nil
		or Layout.campAt(position.X, position.Z) ~= nil
end

local function isBusy(player: Player): boolean
	return CatService.busyReason(player) ~= nil
end

local function facts(player: Player, profile: Profile): Trade.Facts
	return {
		tier = profile.tier,
		safe = isSafe(player, false),
		busy = isBusy(player),
		inTrade = TradeBook.tradeFor(book, player.UserId) ~= nil,
		sinceLastTrade = TradeBook.sinceLastSwap(book, player.UserId, now()),
		today = Trade.today(profile, os.time()),
		name = player.DisplayName,
	}
end

-- The target's Trade requests setting: "everyone" (the default), "friends" or "off".
local function requestSetting(profile: Profile): string
	local value = (profile.settings :: any).tradeRequests
	return if value == "friends" or value == "off" then value else "everyone"
end

-- Asks Roblox once a pair a server (it yields); a failed lookup counts as not friends and is asked again next time.
local function areFriends(a: Player, b: Player): boolean
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = tostring(low) .. ":" .. tostring(high)
	local known = friendCache[key]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function(): boolean
		return a:IsFriendsWith(b.UserId)
	end)
	if ok then
		friendCache[key] = result == true
	end
	return ok and result == true
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

-- What `profile`'s money multipliers make of one cat's rate.
local function scale(profile: Profile): number
	return Economy.staffMultiplier(profile)
		* Economy.cafeMultiplier(profile)
		* Economy.tierMultiplier(profile)
		* Economy.passMultiplier(profile)
end

local function variantOf(instance: Types.CatInstance): string?
	local variant = instance.variant :: string?
	return if variant == "gold" or variant == "rainbow" then variant else nil
end

-- The tiles `viewer` sees: their own cats at what they earn now, the other player's at what they would earn in the
-- viewer's cafe (working, no favorite role bonus).
local function tilesFor(
	viewer: Player,
	viewerProfile: Profile
): (number, string) -> Types.TradeTile?
	return function(ownerId: number, uid: string): Types.TradeTile?
		local owner = playerOf(ownerId)
		local ownerProfile = if owner ~= nil then DataService.get(owner) else nil
		local instance = if ownerProfile ~= nil then ownerProfile.cats[uid] else nil
		local def = if instance ~= nil then Catalog.getCat(instance.catId) else nil
		if instance == nil or def == nil then
			return nil
		end
		local rate = if ownerId == viewer.UserId
			then Economy.catRate(instance, viewerProfile.tier) * scale(viewerProfile)
			else CatStats.rating(instance, viewerProfile.tier) * scale(viewerProfile)
		local rarity: string = def.rarity
		local shown: Types.TradeTile = {
			uid = uid,
			catId = instance.catId,
			rarity = rarity,
			variant = variantOf(instance),
			level = CatStats.level(instance),
			charm = CatStats.charm(instance),
			rateForMe = rate,
		}
		return shown
	end
end

-- #1574: a piece's tile, or nil for one that can't be traded.
local function pieceTile(id: string): Types.TradeDecorTile?
	local info = Trade.piece(id)
	if info == nil then
		return nil
	end
	return { id = id, name = info.name, kind = info.kind, rarity = info.rarity, bonus = info.bonus }
end

-- #1574: the viewer's tradeable pieces the other player owns already (greyed, "They already have this").
local function theyHave(profile: Profile, partner: Profile?): { string }
	local out: { string } = {}
	if partner == nil then
		return out
	end
	local function check(id: string)
		if Trade.piece(id) ~= nil and Trade.ownsPiece(partner, id) then
			table.insert(out, id)
		end
	end
	for id in profile.decorOwned do
		check(id)
	end
	for id in profile.lawnOwned do
		check(id)
	end
	table.sort(out)
	return out
end

local function sendStateTo(trade: TradeBook.OpenTrade, player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local _, theirs = TradeBook.sides(trade, player.UserId)
	local partner = if theirs ~= nil then playerOf(theirs.userId) else nil
	local partnerProfile = if partner ~= nil then DataService.get(partner) else nil
	Net.fire(
		player,
		"TradeState",
		TradeBook.view(
			trade,
			player.UserId,
			tilesFor(player, profile),
			pieceTile,
			theyHave(profile, partnerProfile)
		)
	)
end

local function sendState(trade: TradeBook.OpenTrade)
	for _, side in { trade.a, trade.b } do
		local player = playerOf(side.userId)
		if player ~= nil then
			sendStateTo(trade, player)
		end
	end
end

local function setTrading(player: Player?, on: boolean)
	if player ~= nil and player.Parent == Players then
		player:SetAttribute("Trading", on)
	end
end

-- Ends `trade` with nothing moved; each player still here gets TradeState nil and TradeEnded with `reasonFor` their
-- userId.
local function endTrade(trade: TradeBook.OpenTrade, reasonFor: (userId: number) -> string)
	TradeBook.close(book, trade, now(), false)
	for _, side in { trade.a, trade.b } do
		local player = playerOf(side.userId)
		if player ~= nil then
			setTrading(player, false)
			Net.fire(player, "TradeState", nil)
			Net.fire(player, "TradeEnded", trade.id, reasonFor(side.userId))
		end
	end
end

local function endAll(trade: TradeBook.OpenTrade, reason: string)
	endTrade(trade, function(): string
		return reason
	end)
end

local function savedHas(id: string): (data: any) -> boolean
	return function(data: any): boolean
		return type(data) == "table"
			and type(data.tradeIds) == "table"
			and table.find(data.tradeIds, id) ~= nil
	end
end

-- One side of a stored record made safe to use (each cat through the save's own cat sanitizer, review of #850), or nil.
-- A cat the sanitizer refuses (no uid, a kind no longer in the Catalog) is left out of the side.
local function recordSide(raw: any): TradeVault.RecordSide?
	if type(raw) ~= "table" or type(raw.userId) ~= "number" or type(raw.cats) ~= "table" then
		return nil
	end
	local cats: { Types.CatInstance } = {}
	for _, cat in raw.cats do
		local clean = ProfileSchema.cleanCat(cat, os.time())
		if clean ~= nil and #cats < Config.TradeMaxCats then
			table.insert(cats, clean)
		end
	end
	local name = if type(raw.name) == "string" then string.sub(raw.name, 1, 40) else "A player"
	-- #1574: known tradeable piece ids only, each once
	local decor: { string } = {}
	if type(raw.decor) == "table" then
		for _, id in raw.decor do
			if
				type(id) == "string"
				and Trade.piece(id) ~= nil
				and table.find(decor, id) == nil
				and #decor < Config.TradeMaxDecor
			then
				table.insert(decor, id)
			end
		end
	end
	return { userId = raw.userId, name = name, cats = cats, decor = decor }
end

-- `userId`'s side of `record` and the other one, or nil.
local function sidesOf(
	record: TradeVault.Record,
	userId: number
): (TradeVault.RecordSide?, TradeVault.RecordSide?)
	local a, b = recordSide(record.a), recordSide(record.b)
	if a == nil or b == nil then
		return nil, nil
	elseif a.userId == userId then
		return a, b
	elseif b.userId == userId then
		return b, a
	end
	return nil, nil
end

local function uidsOf(cats: { Types.CatInstance }): { string }
	local uids: { string } = {}
	for _, cat in cats do
		table.insert(uids, cat.uid)
	end
	return uids
end

-- `mine` gives, `theirs` gives back: the swap on `profile` (nothing for a trade it holds already).
local function applySide(
	profile: Profile,
	id: string,
	mine: TradeVault.RecordSide,
	theirs: TradeVault.RecordSide,
	at: number
): boolean
	return Trade.apply(
		profile,
		id,
		theirs.name,
		uidsOf(mine.cats),
		Trade.summaries(mine.cats),
		theirs.cats,
		at,
		{ gave = mine.decor or {}, got = theirs.decor or {} }
	)
end

local function bestRarity(cats: { Types.CatInstance }): string
	local best, bestRank = "none", -1
	for _, cat in cats do
		local def = Catalog.getCat(cat.catId)
		local rank = if def ~= nil then Catalog.rarityRank[def.rarity] or 0 else 0
		if def ~= nil and rank > bestRank then
			best, bestRank = def.rarity, rank
		end
	end
	return best
end

-- The cats `side` gives, copied, when every one is still theirs, unlocked and not exclusive and none is a uid the
-- other profile has; else nil.
local function stillGives(
	side: TradeBook.Side,
	profile: Profile,
	other: Profile
): { Types.CatInstance }?
	local cats: { Types.CatInstance } = {}
	for _, uid in side.cats do
		local instance = profile.cats[uid]
		if instance == nil or Trade.offerRefusal(instance, {}) ~= nil or other.cats[uid] ~= nil then
			return nil
		end
		table.insert(cats, table.clone(instance))
	end
	return cats
end

-- #1574: the pieces `side` gives, copied, when every one is still theirs, tradeable, unlocked and not owned by the
-- other profile; else nil.
local function stillGivesDecor(side: TradeBook.Side, profile: Profile, other: Profile): { string }?
	local pieces: { string } = {}
	for _, id in side.decor do
		if Trade.pieceRefusal(profile, other, id, {}) ~= nil then
			return nil
		end
		table.insert(pieces, id)
	end
	return pieces
end

-- Both confirmed: the swap (section 4). Runs in its own thread; the trade is "committing" and nothing changes it.
-- Whether `player` is still in this server with the same profile session as `profile`.
local function stillHere(player: Player, profile: Profile): boolean
	return player.Parent == Players and DataService.get(player) == profile
end

local function finish(trade: TradeBook.OpenTrade)
	local playerA, playerB = playerOf(trade.a.userId), playerOf(trade.b.userId)
	local profileA = if playerA ~= nil then DataService.get(playerA) else nil
	local profileB = if playerB ~= nil then DataService.get(playerB) else nil
	if playerA == nil or playerB == nil or profileA == nil or profileB == nil then
		endAll(trade, Trade.Ended.failed)
		return
	end
	local reason = Trade.endReason(
		tradingOn,
		isSafe(playerA, true),
		isSafe(playerB, true),
		isBusy(playerA),
		isBusy(playerB)
	)
	if reason ~= nil then
		endAll(trade, reason)
		return
	end
	local at = os.time()
	if
		Trade.today(profileA, at) >= Config.TradesPerDay
		or Trade.today(profileB, at) >= Config.TradesPerDay
	then
		endAll(trade, Trade.Messages.daily)
		return
	end
	local catsA, catsB =
		stillGives(trade.a, profileA, profileB), stillGives(trade.b, profileB, profileA)
	local decorA, decorB =
		stillGivesDecor(trade.a, profileA, profileB), stillGivesDecor(trade.b, profileB, profileA)
	if
		catsA == nil
		or catsB == nil
		or decorA == nil
		or decorB == nil
		or ProfileSchema.catCount(profileA) - #catsA + #catsB < 1
		or ProfileSchema.catCount(profileB) - #catsB + #catsA < 1
	then
		endAll(trade, Trade.Ended.gone)
		return
	end
	local record: TradeVault.Record = {
		id = trade.id,
		at = at,
		state = "pending",
		a = { userId = trade.a.userId, name = trade.a.name, cats = catsA, decor = decorA },
		b = { userId = trade.b.userId, name = trade.b.name, cats = catsB, decor = decorB },
	}
	if not TradeVault.write(record) then
		endAll(trade, Trade.Ended.failed)
		return
	end
	if
		not (
			TradeVault.point(record.a.userId, record.id)
			and TradeVault.point(record.b.userId, record.id)
		)
	then
		-- never decided: void it so no join ever applies it; a pointer left behind is cleared at that join
		TradeVault.decide(record.id, "void")
		endAll(trade, Trade.Ended.failed)
		return
	end
	-- QA on #854: a player who left while the record and pointers were written may already have loaded on another
	-- server before their pointer existed, so that join had nothing to settle and still holds the cats they gave. Only
	-- players still here with the profile checked above can be committed for. Past this check, a join elsewhere finds
	-- the pointer, and its void either wins (nothing moves here) or finds the commit and applies it.
	if not (stillHere(playerA, profileA) and stillHere(playerB, profileB)) then
		TradeVault.decide(record.id, "void")
		-- only this function ever commits, so a record left pending after this is dead and its pointers can go
		TradeVault.unpoint(record.a.userId, record.id)
		TradeVault.unpoint(record.b.userId, record.id)
		endAll(trade, Trade.Ended.failed)
		return
	end
	local known, decided = TradeVault.decide(record.id, "commit")
	if not known then
		known, decided = TradeVault.decide(record.id, "commit") -- the same ask again: a commit stays a commit
	end
	if not known then
		-- the DataStore has the answer and cannot be read: both rejoin, and each join settles it from the record
		TradeBook.close(book, trade, now(), false)
		for _, player in { playerA, playerB } do
			if player.Parent == Players then
				player:Kick(TradeService.KICK_TEXT)
			end
		end
		return
	end
	if decided == nil or decided.state ~= "commit" then
		-- voided by a join on another server (one of them left mid swap): nothing moved
		TradeVault.unpoint(record.a.userId, record.id)
		TradeVault.unpoint(record.b.userId, record.id)
		endAll(trade, Trade.Ended.failed)
		return
	end
	-- both profiles take their side before anything can yield, so no cat is ever unguarded while owned twice; a player
	-- who left after the decision gets their side at their next join, from the pointer
	local swaps: { Swap } = {}
	for _, swap: Swap in
		{
			{ player = playerA, mine = record.a, theirs = record.b },
			{ player = playerB, mine = record.b, theirs = record.a },
		}
	do
		local profile = if swap.player.Parent == Players then DataService.get(swap.player) else nil
		if profile ~= nil then
			applySide(profile, record.id, swap.mine, swap.theirs, at)
			table.insert(swaps, swap)
		end
	end
	TradeBook.close(book, trade, now(), true)
	for _, swap in swaps do
		local player = swap.player
		DataService.whenSaved(player, savedHas(record.id), function()
			TradeVault.unpoint(player.UserId, record.id)
		end)
		DataService.save(player)
		setTrading(player, false)
		Net.fire(player, "TradeState", nil)
		local gaveDecor, gotDecor = swap.mine.decor or {}, swap.theirs.decor or {}
		Net.fire(
			player,
			"TradeDone",
			record.id,
			Trade.summaries(swap.mine.cats),
			Trade.summaries(swap.theirs.cats),
			Trade.pieceSummaries(gaveDecor),
			Trade.pieceSummaries(gotDecor)
		)
		Telemetry.custom(
			player,
			"trade_done",
			#swap.mine.cats + #swap.theirs.cats + #gaveDecor + #gotDecor,
			{ tostring(#swap.mine.cats), tostring(#swap.theirs.cats), bestRarity(swap.theirs.cats) }
		)
		local landed = DataService.get(player)
		if landed ~= nil then
			CafeService.autoEquip(player, landed) -- #1534: the best cats, new ones too, fill the slots
			if #gaveDecor + #gotDecor > 0 then
				CafeService.autoEquipDecor(player, landed) -- #1574: refill what left, put out what arrived
			end
		end
		CafeService.refreshPlot(player)
		CafeService.sync(player)
	end
end

local function onRequest(player: Player, rawUserId: unknown)
	local targetId = Guard.int(rawUserId, 1, 2 ^ 53)
	local profile = DataService.get(player)
	if targetId == nil or profile == nil then
		return
	end
	local target = playerOf(targetId)
	if target == player then
		Net.toast(player, Trade.Messages.self, "warn")
		return
	end
	local targetProfile = if target ~= nil then DataService.get(target) else nil
	if target == nil or targetProfile == nil then
		return
	end
	local setting = requestSetting(targetProfile)
	local friends = setting == "friends" and areFriends(player, target)
	-- the friends lookup can yield: both are looked up again
	profile, targetProfile = DataService.get(player), DataService.get(target)
	if profile == nil or targetProfile == nil or target.Parent ~= Players then
		return
	end
	local at = now()
	local refusal = Trade.askRefusal(
		facts(player, profile),
		facts(target, targetProfile),
		minTier(),
		tradingOn,
		TradeBook.isAsking(book, player.UserId),
		TradeBook.reaskLeft(book, player.UserId, target.UserId, at),
		setting,
		friends
	)
	if refusal ~= nil then
		Net.toast(player, refusal, "warn")
		return
	end
	local request = TradeBook.ask(book, newId(), player.UserId, target.UserId, at)
	Net.fire(target, "TradeAsked", request.id, player.UserId, player.DisplayName, request.expiresAt)
	Net.toast(player, string.format(Trade.Messages.sent, target.DisplayName), "info")
end

local function onRespond(player: Player, rawId: unknown, rawAccept: unknown)
	local requestId, accept = guardId(rawId), Guard.bool(rawAccept)
	if requestId == nil or accept == nil then
		return
	end
	local request = TradeBook.answer(book, requestId, player.UserId, accept, now())
	if request == nil then
		return
	end
	local asker = playerOf(request.from)
	if not accept then
		if asker ~= nil then
			Net.toast(asker, string.format(Trade.Messages.declined, player.DisplayName), "info")
		end
		return
	end
	local profile = DataService.get(player)
	local askerProfile = if asker ~= nil then DataService.get(asker) else nil
	if asker == nil or profile == nil or askerProfile == nil then
		return
	end
	-- both checked again from each side, since either may have moved on; the setting and the re-ask wait were the
	-- ask's, answered now
	local mine, theirs = facts(player, profile), facts(asker, askerProfile)
	local forAsker =
		Trade.askRefusal(theirs, mine, minTier(), tradingOn, false, 0, "everyone", true)
	local forMe = Trade.askRefusal(mine, theirs, minTier(), tradingOn, false, 0, "everyone", true)
	if forAsker ~= nil or forMe ~= nil then
		if forAsker ~= nil then
			Net.toast(asker, forAsker, "warn")
		end
		if forMe ~= nil then
			Net.toast(player, forMe, "warn")
		end
		return
	end
	local trade = TradeBook.open(
		book,
		newId(),
		{ userId = asker.UserId, name = asker.DisplayName },
		{ userId = player.UserId, name = player.DisplayName },
		now()
	)
	setTrading(asker, true)
	setTrading(player, true)
	sendState(trade)
end

-- The trade `player` is in when it is `rawTradeId`, else nil.
local function tradeOf(player: Player, rawTradeId: unknown): TradeBook.OpenTrade?
	local tradeId = guardId(rawTradeId)
	local trade = TradeBook.tradeFor(book, player.UserId)
	return if tradeId ~= nil and trade ~= nil and trade.id == tradeId then trade else nil
end

-- #1574: a piece on or off the caller's side (TradeOffer with kind "decor").
local function onOfferDecor(
	player: Player,
	trade: TradeBook.OpenTrade,
	action: string,
	id: string,
	profile: Profile
)
	local at = now()
	if action == "remove" then
		if TradeBook.removeDecor(trade, player.UserId, id, at) then
			sendState(trade)
		end
		return
	end
	local mine, theirs = TradeBook.sides(trade, player.UserId)
	if
		mine == nil
		or theirs == nil
		or trade.phase == "committing"
		or table.find(mine.decor, id) ~= nil
	then
		return
	end
	local partner = playerOf(theirs.userId)
	local partnerProfile = if partner ~= nil then DataService.get(partner) else nil
	if partnerProfile == nil then
		return
	end
	local refusal = Trade.pieceRefusal(profile, partnerProfile, id, mine.decor)
	if refusal ~= nil then
		Net.toast(player, refusal, "warn")
		return
	end
	if TradeBook.addDecor(trade, player.UserId, id, Trade.pieceValue(id), at) then
		sendState(trade)
	end
end

local function onOffer(
	player: Player,
	rawTradeId: unknown,
	rawAction: unknown,
	rawUid: unknown,
	rawKind: unknown
)
	local trade = tradeOf(player, rawTradeId)
	local action = Guard.oneOf(rawAction, { "add", "remove" })
	local uid = Guard.id(rawUid)
	local kind = if rawKind == nil then "cat" else Guard.oneOf(rawKind, { "cat", "decor" })
	local profile = DataService.get(player)
	if trade == nil or action == nil or uid == nil or kind == nil or profile == nil then
		return
	end
	if kind == "decor" then
		onOfferDecor(player, trade, action, uid, profile)
		return
	end
	local at = now()
	if action == "remove" then
		if TradeBook.remove(trade, player.UserId, uid, at) then
			sendState(trade)
		end
		return
	end
	local mine = TradeBook.sides(trade, player.UserId)
	if mine == nil or trade.phase == "committing" or table.find(mine.cats, uid) ~= nil then
		return
	end
	local instance = profile.cats[uid]
	local refusal = Trade.offerRefusal(instance, mine.cats)
	if refusal == nil and #mine.cats + 1 >= ProfileSchema.catCount(profile) then
		refusal = Trade.Messages.lastCat
	end
	if refusal ~= nil or instance == nil then
		Net.toast(player, refusal or Trade.Messages.notOwned, "warn")
		return
	end
	if TradeBook.add(trade, player.UserId, uid, Trade.value(instance), at) then
		sendState(trade)
	end
end

local function onReady(player: Player, rawTradeId: unknown, rawVersion: unknown, rawReady: unknown)
	local trade = tradeOf(player, rawTradeId)
	local version, ready = Guard.int(rawVersion, 1, 1e9), Guard.bool(rawReady)
	if trade == nil or version == nil or ready == nil then
		return
	end
	if TradeBook.ready(trade, player.UserId, version, ready, now()) ~= nil then
		sendStateTo(trade, player) -- a stale or early press: the window catches up
		return
	end
	sendState(trade)
end

local function onConfirm(player: Player, rawTradeId: unknown, rawVersion: unknown)
	local trade = tradeOf(player, rawTradeId)
	local version = Guard.int(rawVersion, 1, 1e9)
	if trade == nil or version == nil then
		return
	end
	if TradeBook.confirm(trade, player.UserId, version, now()) ~= nil then
		sendStateTo(trade, player)
		return
	end
	if TradeBook.bothConfirmed(trade) then
		TradeBook.commit(trade)
		sendState(trade)
		task.spawn(function()
			local ok, err = pcall(function()
				finish(trade)
			end)
			if ok then
				return
			end
			-- a bug mid swap: whether it was decided is unknown here, so both rejoin and their joins settle it
			warn("[TradeService] swap failed:", err)
			if book.trades[trade.id] == trade then
				TradeBook.close(book, trade, now(), false)
			end
			for _, side in { trade.a, trade.b } do
				local p = playerOf(side.userId)
				if p ~= nil then
					p:Kick(TradeService.KICK_TEXT)
				end
			end
		end)
		return
	end
	sendState(trade)
end

local function onCancel(player: Player, rawTradeId: unknown)
	local trade = tradeOf(player, rawTradeId)
	if trade == nil or trade.phase == "committing" then
		return
	end
	endAll(trade, Trade.Ended.cancelled)
end

local function onLeave(player: Player)
	local trade = TradeBook.leave(book, player.UserId, now())
	settled[player] = nil
	if trade ~= nil and trade.phase ~= "committing" then
		local name = player.DisplayName
		endTrade(trade, function(): string
			return string.format(Trade.Ended.left, name)
		end)
	end
end

-- DataService.onLoading: a trade a stopped server still owes this player (section 4, step 4). Errors (the pointers or
-- a record cannot be read) send the player to rejoin, so nothing uses a profile that may owe a side.
local function settle(player: Player, profile: Profile)
	local ok, ids = TradeVault.pointers(player.UserId)
	if not ok or ids == nil then
		error("trade pointers could not be read")
	end
	local waiting: { string } = {}
	for _, id in ids do
		-- a trade nobody decided is voided here, so the server that wrote it can never commit it after this
		local known, record = TradeVault.decide(id, "void")
		if not known then
			error("a trade record could not be read")
		end
		local mine, theirs = nil, nil
		if record ~= nil and record.state == "commit" and not Trade.applied(profile, id) then
			mine, theirs = sidesOf(record, player.UserId)
		end
		if mine ~= nil and theirs ~= nil then
			applySide(profile, id, mine, theirs, os.time())
			table.insert(waiting, id) -- the pointer goes after a save holds the trade
		else
			TradeVault.unpoint(player.UserId, id) -- void, missing, or in the save already
		end
	end
	if #waiting > 0 then
		settled[player] = waiting
	end
end

local function onLoaded(player: Player, profile: Profile)
	player:SetAttribute("Tier", profile.tier)
	player:SetAttribute("Trading", false)
	local waiting = settled[player]
	settled[player] = nil
	if waiting ~= nil then
		for _, id in waiting do
			DataService.whenSaved(player, savedHas(id), function()
				TradeVault.unpoint(player.UserId, id)
			end)
		end
		DataService.save(player)
	end
end

-- The countdowns, requests running out, and the safe zone and busy checks on every open trade.
local function step()
	local at = now()
	for _, request in TradeBook.expire(book, at) do
		local asker, target = playerOf(request.from), playerOf(request.to)
		if asker ~= nil and target ~= nil then
			Net.toast(asker, string.format(Trade.Messages.noAnswer, target.DisplayName), "info")
		end
	end
	local open: { TradeBook.OpenTrade } = {}
	for _, trade in book.trades do
		table.insert(open, trade)
	end
	for _, trade in open do
		if trade.phase == "committing" then
			continue
		end
		local playerA, playerB = playerOf(trade.a.userId), playerOf(trade.b.userId)
		if playerA == nil or playerB == nil then
			continue -- onLeave ends it
		end
		local reason = Trade.endReason(
			tradingOn,
			isSafe(playerA, true),
			isSafe(playerB, true),
			isBusy(playerA),
			isBusy(playerB)
		)
		if reason ~= nil then
			endAll(trade, reason)
		elseif TradeBook.tick(trade, at) then
			sendState(trade)
		end
	end
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil and player:GetAttribute("Tier") ~= profile.tier then
			player:SetAttribute("Tier", profile.tier)
		end
	end
end

-- Trading on or off from the flag (or Debug); off ends every trade that is not swapping.
local function applyOn()
	tradingOn = if debugOn ~= nil then debugOn else flagOn
	publish()
	if not tradingOn then
		local open: { TradeBook.OpenTrade } = {}
		for _, trade in book.trades do
			if trade.phase ~= "committing" then
				table.insert(open, trade)
			end
		end
		for _, trade in open do
			endAll(trade, Trade.Ended.off)
		end
	end
end

local function readFlags()
	local ok, flags = TradeVault.flags()
	if not ok or flags == nil then
		return -- keep what this server had
	end
	flagOn = flags.trading ~= false
	flagMinTier = flags.tradeMinTier
	applyOn()
end

-- Whether `player` is in a trade (Reset my save waits for it).
function TradeService.isTrading(player: Player): boolean
	return TradeBook.tradeFor(book, player.UserId) ~= nil
end

-- Studio only (Debug.tradeMinTier): this server's minimum tier, nil for the flag or Config again.
function TradeService.debugMinTier(tier: number?): number
	assert(RunService:IsStudio(), "debugMinTier is Studio only")
	debugMinTier = tier
	publish()
	return minTier()
end

-- Studio only (Debug.trading): the kill switch in this server, over CatCafe_Flags (nil goes back to the flag).
function TradeService.debugTrading(on: boolean?): boolean
	assert(RunService:IsStudio(), "debugTrading is Studio only")
	debugOn = on
	applyOn()
	return tradingOn
end

function TradeService.start()
	publish()
	CafeService.setOfferCheck(function(player: Player, uid: string): boolean
		return TradeBook.isOffered(book, player.UserId, uid)
	end)
	CafeService.setPieceOfferCheck(function(player: Player, id: string): boolean
		return TradeBook.isPieceOffered(book, player.UserId, id)
	end)
	DataService.onLoading(settle)
	DataService.onLoaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(onLeave)
	Net.on("TradeRequest", onRequest)
	Net.on("TradeRespond", onRespond)
	Net.on("TradeOffer", onOffer)
	Net.on("TradeReady", onReady)
	Net.on("TradeConfirm", onConfirm)
	Net.on("TradeCancel", onCancel)
	task.spawn(function()
		while true do
			task.wait(TradeService.STEP_SECONDS)
			local ok, err = pcall(function()
				step()
			end)
			if not ok then
				warn("[TradeService] step failed:", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			readFlags()
			task.wait(Config.TradeFlagCheckSeconds)
		end
	end)
end

return TradeService
