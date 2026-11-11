--!strict
-- Trading (F102, docs/design/cat-cafe/trading.md; Derek 2026-10-30: "trading allowed but for now lock it after Tier 3
-- ... make sure its secure and not possible to scam people"). The pure rules, so the specs and TradeService read the
-- same ones: which cats may go on offer, when a player may ask or be asked, what a side is worth, the lopsided and
-- gift warnings, what a traded cat looks like when it arrives, and the save's trade log and applied ids.
-- - Cats only (section 1): never an exclusive cat (the Bellhop Cat, shop cats, anything had for Robux), never a
--   locked one (the player locks and unlocks one on its card; since #2906 no cat arrives locked).
-- - A traded cat keeps its rarity, coat, charm, level, xp and rescued flag; its name goes back to its kind's, it
--   rests in the cat room, arrives unlocked (#2906), and counts as found in the new
--   owner's Index pages (the coat's too). It pays no golden fish (GoldenFish.forCatch is for catches).
-- - `apply` is the one place a side of a trade changes a save, for the live swap and for finishing a trade after a
--   shutdown (section 4), and it does nothing for a trade id the save has applied already.
-- - #1574 (section 1b): decor joins. A piece is a crate decor id or a lawn piece id (never a lawn style, the free
--   Tier 2 and 3 lawn gifts, or shop decor). Saves own pieces with no counts, so a piece the partner already owns
--   can't go on offer ("They already have this"). #3276 (Derek, 2026-11-11): pieces no longer arrive locked. A piece
--   of a lockable rarity (Legendary and up) is locked only when the save's `decorLocked` has it (LockDecor), so a
--   crate, the lawn shop or a trade lands it unlocked. `decorUnlocked`, the list before #3276, is kept as the mirror
--   (every owned lockable piece that isn't locked) so an older server sees the same locks. Up to TradeMaxDecor a side. The swap takes a placed piece off its spot; TradeService runs both
--   sides' Equip Best for decor and the lawn afterwards.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local Crates = require(script.Parent.Crates)
local Lawn = require(script.Parent.Lawn)
local Types = require(script.Parent.Types)

local Trade = {}

-- What a refused ask or offer toasts (section 2 and 3).
Trade.Messages = {
	off = "Trading is resting for now",
	tier = "Trading opens at Tier %d",
	theirTier = "%s can trade from Tier %d",
	busy = "Finish what you're doing first",
	theirBusy = "%s is busy right now",
	inTrade = "You're already trading",
	theirInTrade = "%s is already trading",
	asking = "You already asked someone",
	requestsOff = "%s isn't taking trade requests",
	friendsOnly = "%s only trades with friends",
	reask = "Wait a moment before asking %s again",
	declinedOut = "%s said no for now. They can still ask you", -- #2550 review: TradeDeclinesToStop declines in a row
	cooldown = "Wait a moment before your next trade",
	daily = "That's all the trades for today",
	theirDaily = "%s has traded enough for today", -- review N335: a line of its own, not theirBusy
	notOwned = "That cat isn't yours",
	locked = "Unlock it on its card to trade",
	exclusive = "This cat can't be traded",
	full = "Up to %d cats each",
	self = "You can't trade with yourself",
	-- part 2 (TradeService)
	sent = "Asked %s to trade",
	declined = "%s said no thanks",
	noAnswer = "%s didn't answer",
	lastCat = "Keep at least one cat",
	catInTrade = "This cat is in a trade",
	finishTrade = "Finish your trade first",
	-- #1574 (section 1b): decor
	pieceNotOwned = "That piece isn't yours",
	pieceNotTradable = "This piece can't be traded",
	theyHaveIt = "They already have this",
	fullDecor = "Up to %d decor each",
	pieceInTrade = "This piece is in a trade",
	-- #2745 (section 1c): crates
	crateNotTradable = "This crate can't be traded",
	crateNotEnough = "You don't have that many",
	crateCount = "Pick how many crates",
	fullCrates = "Up to %d crates each",
	fullCrateKinds = "Up to %d kinds of crate each",
	theyCantOpen = "They haven't reached the %s yet",
	crateInTrade = "This crate is in a trade",
	cratesOff = "Crate trading is resting for now",
	-- #2745 (section 1d): golden fish
	fishAmount = "Pick how many golden fish",
	fishNotEnough = "You don't have that many golden fish",
	fullFish = "Up to %d golden fish each",
	fishRoom = "They can get %d more golden fish today",
	fishOff = "Golden fish trading is resting for now",
}

-- #1574: the rarities whose pieces can be locked (Legendary and up; Golden is the lawn's top rung).
Trade.LOCKED_RARITIES =
	table.freeze({ Legendary = true, Mythical = true, Golden = true }) :: { [string]: boolean }

-- #1574: a piece's Collector value for the lopsided warning, by rarity: the cats' CollectorValue, with the lawn-only
-- rungs between theirs (Uncommon between Common and Rare, Golden with Mythical).
local PIECE_VALUE_EXTRA: { [string]: number } = { Uncommon = 2, Golden = 50 }

-- What the trade knows about a tradeable piece (#1574), or nil for any id that can't be traded: unknown, shop
-- decor, a lawn style or a lawn tier gift.
export type PieceInfo = { kind: string, name: string, rarity: string, bonus: number }

function Trade.piece(id: string): PieceInfo?
	local decor = Catalog.getDecor(id)
	if decor ~= nil then
		if decor.source ~= "crate" then
			return nil
		end
		return {
			kind = "decor",
			name = decor.name,
			rarity = (decor.rarity or "Common") :: string,
			bonus = decor.bonus,
		}
	end
	local lawn = Catalog.getLawn(id)
	if lawn == nil then
		return nil
	end
	for _, gift in Lawn.TIER_GIFTS do
		if gift == id then
			return nil
		end
	end
	return {
		kind = "lawn",
		name = lawn.name,
		rarity = lawn.rarity :: string,
		bonus = Lawn.rarityBonus(lawn.rarity),
	}
end

-- Whether the save owns piece `id` (a crate decor id or a lawn piece id).
function Trade.ownsPiece(profile: Types.PlayerProfile, id: string): boolean
	return profile.decorOwned[id] == true
		or (Catalog.getLawn(id) ~= nil and profile.lawnOwned[id] == true)
end

-- Whether a piece of `rarity` can be locked (Legendary and up; #3276: none arrives locked).
function Trade.lockable(rarity: string?): boolean
	return rarity ~= nil and Trade.LOCKED_RARITIES[rarity] == true
end

local function pieceRarity(id: string): string?
	local decor, lawn = Catalog.getDecor(id), Catalog.getLawn(id)
	return if decor ~= nil then decor.rarity elseif lawn ~= nil then lawn.rarity else nil
end

-- Whether piece `id` is locked in the save: a lockable rarity the player locked on its card (#3276: nothing arrives
-- locked any more).
function Trade.pieceLocked(profile: Types.PlayerProfile, id: string): boolean
	return Trade.lockable(pieceRarity(id)) and profile.decorLocked[id] == true
end

-- #3276: the owned lockable pieces that aren't locked, as `decorUnlocked` held them before. The save keeps this
-- mirror for older servers, and the client's state gets it (the Trade window's Decor tab greys a piece it lacks).
function Trade.unlockedPieces(profile: Types.PlayerProfile): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local function add(id: string)
		if Trade.lockable(pieceRarity(id)) and profile.decorLocked[id] ~= true then
			out[id] = true
		end
	end
	for id, yes in profile.decorOwned do
		if yes == true then
			add(id)
		end
	end
	for id, yes in profile.lawnOwned do
		if yes == true and Catalog.getLawn(id) ~= nil then
			add(id)
		end
	end
	return out
end

-- #3276: lock or unlock owned piece `id` on its card, keeping the old servers' mirror in step.
function Trade.setPieceLocked(profile: Types.PlayerProfile, id: string, locked: boolean)
	profile.decorLocked[id] = if locked then true else nil
	profile.decorUnlocked[id] = if locked then nil else true
end

-- Why piece `id` cannot go on `profile`'s side next to `offered` (the ids already there), in a trade with
-- `partner`, or nil when it can. A piece already on offer is fine (adding it again does nothing).
function Trade.pieceRefusal(
	profile: Types.PlayerProfile,
	partner: Types.PlayerProfile,
	id: string,
	offered: { string }
): string?
	if not Trade.ownsPiece(profile, id) then
		return Trade.Messages.pieceNotOwned
	end
	if table.find(offered, id) ~= nil then
		return nil
	end
	if Trade.piece(id) == nil then
		return Trade.Messages.pieceNotTradable
	end
	if Trade.pieceLocked(profile, id) then
		return Trade.Messages.locked
	end
	if Trade.ownsPiece(partner, id) then
		return Trade.Messages.theyHaveIt
	end
	if #offered >= Config.TradeMaxDecor then
		return string.format(Trade.Messages.fullDecor, Config.TradeMaxDecor)
	end
	return nil
end

-- A piece's Collector value (section 1b: decor counts next to the cats in the lopsided warning).
function Trade.pieceValue(id: string): number
	local info = Trade.piece(id)
	if info == nil then
		return 0
	end
	return Config.CollectorValue[info.rarity] or PIECE_VALUE_EXTRA[info.rarity] or 0
end

-- One piece as the log and the done card show it.
function Trade.pieceSummary(id: string): Types.DecorSummary
	local info = Trade.piece(id)
	return {
		id = id,
		kind = if info ~= nil then info.kind else "decor",
		rarity = if info ~= nil then info.rarity else "Common",
	}
end

function Trade.pieceSummaries(ids: { string }): { Types.DecorSummary }
	local out: { Types.DecorSummary } = {}
	for _, id in ids do
		table.insert(out, Trade.pieceSummary(id))
	end
	return out
end

-- Piece `id` leaves `profile`: off its spot (decor placed, or the lawn spot it stands on) and out of the owned and
-- unlocked lists.
local function takePiece(profile: Types.PlayerProfile, id: string)
	profile.decorOwned[id] = nil
	profile.decorPlaced[id] = nil
	if Catalog.getLawn(id) ~= nil then
		profile.lawnOwned[id] = nil
		for _, spot in Lawn.SPOTS do
			if profile.lawn[spot.id] == id then
				profile.lawn[spot.id] = nil
			end
		end
	end
	profile.decorUnlocked[id] = nil
	profile.decorLocked[id] = nil
end

-- Piece `id` arrives in `profile`, owned, not placed (Equip Best places it) and unlocked (#3276). A piece the save
-- owns already is left as it is.
local function givePiece(profile: Types.PlayerProfile, id: string)
	local info = Trade.piece(id)
	if info == nil or Trade.ownsPiece(profile, id) then
		return
	end
	if info.kind == "lawn" then
		profile.lawnOwned[id] = true
	else
		profile.decorOwned[id] = true
	end
	Trade.setPieceLocked(profile, id, false)
end

-- #2745 (section 1c): whether crate `id` can change hands: a known crate that isn't golden (golden crates come only
-- from one-off rewards, so trading them would let spare accounts feed a main).
function Trade.crateTradable(id: string): boolean
	local def = Catalog.getCrate(id)
	return def ~= nil and not def.golden
end

-- Why a player at `tier` can't take crate `id` yet (its zone isn't open to them), or nil. The Classic and Rally crates
-- have no zone and open from Tier 1, as Crates.openBlocker has it.
function Trade.crateAreaBlocker(tier: number, id: string): string?
	local def = Catalog.getCrate(id)
	if def == nil or def.area == "classic" or def.area == Catalog.RALLY_POOL then
		return nil
	end
	local area = Catalog.getArea(def.area)
	if area == nil then
		return Trade.Messages.crateNotTradable
	end
	if tier < area.tier then
		return string.format(Trade.Messages.theyCantOpen, area.name)
	end
	return nil
end

-- The crates on one side, counted: (kinds, crates in all).
function Trade.crateTotals(offered: { [string]: number }): (number, number)
	local kinds, total = 0, 0
	for _, count in offered do
		kinds += 1
		total += count
	end
	return kinds, total
end

-- Why `count` more of crate `id` cannot go on `profile`'s side next to `offered` (crate id -> count already there), in
-- a trade with a partner at `partnerTier`, or nil when they can: a crate that can be traded, a whole count of at least
-- 1, no more than the save has banked, the partner's zone open, and at most TradeMaxCrateKinds kinds and TradeMaxCrates
-- crates a side.
function Trade.crateRefusal(
	profile: Types.PlayerProfile,
	partnerTier: number,
	id: string,
	count: number,
	offered: { [string]: number }
): string?
	if not Trade.crateTradable(id) then
		return Trade.Messages.crateNotTradable
	end
	if count ~= count or count < 1 or count ~= math.floor(count) or count == math.huge then
		return Trade.Messages.crateCount
	end
	local already = offered[id] or 0
	if already + count > math.floor(profile.crates[id] or 0) then
		return Trade.Messages.crateNotEnough
	end
	local blocker = Trade.crateAreaBlocker(partnerTier, id)
	if blocker ~= nil then
		return blocker
	end
	local kinds, total = Trade.crateTotals(offered)
	if already == 0 and kinds >= Config.TradeMaxCrateKinds then
		return string.format(Trade.Messages.fullCrateKinds, Config.TradeMaxCrateKinds)
	end
	if total + count > Config.TradeMaxCrates then
		return string.format(Trade.Messages.fullCrates, Config.TradeMaxCrates)
	end
	return nil
end

local crateValues: { [string]: number } = {}

-- One crate's Collector value for the lopsided warning (section 1c): its expected piece, the sum over its pieces of
-- chance x Trade.pieceValue, rounded to one decimal. 0 for a crate that can't be traded. Worked out once a crate.
function Trade.crateValue(id: string): number
	local known = crateValues[id]
	if known ~= nil then
		return known
	end
	local def = Catalog.getCrate(id)
	if def == nil or def.golden then
		return 0
	end
	local total = 0
	for decorId, chance in Crates.pieceChances(def, def.odds) do
		local piece = Catalog.getDecor(decorId)
		local rarity = if piece ~= nil then piece.rarity else nil
		if rarity ~= nil then
			total += chance / 100 * (Config.CollectorValue[rarity] or PIECE_VALUE_EXTRA[rarity] or 0)
		end
	end
	local value = math.round(total * 10) / 10
	crateValues[id] = value
	return value
end

-- A side's crates as the log, the done card and TradeState list them: one entry a kind, sorted by crate id.
function Trade.crateSummaries(crates: { [string]: number }?): { Types.CrateSummary }
	local out: { Types.CrateSummary } = {}
	local none: { [string]: number } = {}
	for id, count in crates or none do
		table.insert(out, { id = id, count = count })
	end
	table.sort(out, function(a: Types.CrateSummary, b: Types.CrateSummary): boolean
		return a.id < b.id
	end)
	return out
end

-- Crates from a stored record or the client made safe: tradeable crate ids with whole counts of at least 1, at most
-- TradeMaxCrateKinds kinds and TradeMaxCrates crates in all (the ids sorted, so what is kept never depends on the
-- table's order).
function Trade.sanitizeCrates(raw: unknown): { [string]: number }
	local out: { [string]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	local ids: { string } = {}
	for id, count in raw :: { [any]: any } do
		if
			type(id) == "string"
			and #id <= 64
			and type(count) == "number"
			and count == count
			and count >= 1
			and count < math.huge
			and Trade.crateTradable(id)
		then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local kinds, total = 0, 0
	for _, id in ids do
		local count = math.floor((raw :: any)[id])
		if kinds >= Config.TradeMaxCrateKinds or total + count > Config.TradeMaxCrates then
			break
		end
		out[id] = count
		kinds += 1
		total += count
	end
	return out
end

-- Crates leave `profile` (`gave`, subtracted first, never below 0) and arrive (`got`, added after), banked.
local function moveCrates(
	profile: Types.PlayerProfile,
	gave: { [string]: number },
	got: { [string]: number }
)
	for id, count in gave do
		local left = math.max(0, (profile.crates[id] or 0) - count)
		if left > 0 then
			profile.crates[id] = left
		else
			profile.crates[id] = nil
		end
	end
	for id, count in got do
		if Trade.crateTradable(id) then
			profile.crates[id] = (profile.crates[id] or 0) + count
		end
	end
end

-- #2745 (section 1d): whether `amount` is a whole number of fish from 0 up (not NaN or infinite).
local function wholeFish(amount: unknown): boolean
	return type(amount) == "number"
		and amount == amount
		and amount >= 0
		and amount < math.huge
		and amount == math.floor(amount)
end

-- Golden fish `profile` has received in trades this game day (the TradeFishPerDay count).
function Trade.fishInToday(profile: Types.PlayerProfile, now: number): number
	local today = profile.stats.tradesToday
	return if today.day == Trade.day(now) then today.fishIn or 0 else 0
end

-- Golden fish `profile` can still receive in trades this game day.
function Trade.fishRoom(profile: Types.PlayerProfile, now: number): number
	return math.max(0, Config.TradeFishPerDay - Trade.fishInToday(profile, now))
end

-- Why `profile` can't have `amount` golden fish on its side in a trade with `partner` at `now`, or nil when it can: a
-- whole amount from 0, at most TradeMaxFish, no more than the wallet holds and no more than the partner's room today.
-- 0 always passes (taking every fish off).
function Trade.fishRefusal(
	profile: Types.PlayerProfile,
	partner: Types.PlayerProfile,
	amount: unknown,
	now: number
): string?
	if not wholeFish(amount) then
		return Trade.Messages.fishAmount
	end
	local n = amount :: number
	if n == 0 then
		return nil
	end
	if n > Config.TradeMaxFish then
		return string.format(Trade.Messages.fullFish, Config.TradeMaxFish)
	end
	if n > math.floor(profile.goldenFish) then
		return Trade.Messages.fishNotEnough
	end
	local room = Trade.fishRoom(partner, now)
	if n > room then
		return string.format(Trade.Messages.fishRoom, room)
	end
	return nil
end

-- `amount` golden fish's Collector value for the lopsided warning (TradeFishValue each).
function Trade.fishValue(amount: number): number
	return amount * Config.TradeFishValue
end

-- A fish amount from a stored record made safe: a whole number from 0 to TradeMaxFish, 0 for anything else.
function Trade.sanitizeFish(raw: unknown): number
	if not wholeFish(raw) then
		return 0
	end
	return math.min(raw :: number, Config.TradeMaxFish)
end

-- What a trade ends with (TradeEnded's words).
Trade.Ended = {
	cancelled = "Trade cancelled",
	left = "%s left",
	busy = "Trade cancelled: someone got busy",
	off = "Trading is resting for now",
	failed = "The trade couldn't finish. Nothing moved.",
	gone = "A cat on offer is gone",
	cratesOff = "Crate trading is resting for now", -- #2745: the tradeCrates switch went off mid swap
	fishOff = "Golden fish trading is resting for now", -- #2745 (section 1d): the tradeFish switch went off mid swap
}

-- Why `instance` (looked up by its uid in the player's own cats, nil when not theirs) cannot go on offer next to
-- `offered` (the uids already on that side), or nil when it can. A cat already on offer is fine (adding it again
-- does nothing).
function Trade.offerRefusal(instance: Types.CatInstance?, offered: { string }): string?
	if instance == nil then
		return Trade.Messages.notOwned
	end
	if table.find(offered, instance.uid) ~= nil then
		return nil
	end
	local def = Catalog.getCat(instance.catId)
	if def == nil or def.exclusive == true then
		return Trade.Messages.exclusive
	end
	if instance.locked == true then
		return Trade.Messages.locked
	end
	if #offered >= Config.TradeMaxCats then
		return string.format(Trade.Messages.full, Config.TradeMaxCats)
	end
	return nil
end

-- Whether `instance` may still change hands at the swap: owned (not nil), its kind known and not exclusive, unlocked.
function Trade.tradable(instance: Types.CatInstance?): boolean
	if instance == nil or instance.locked == true then
		return false
	end
	local def = Catalog.getCat(instance.catId)
	return def ~= nil and def.exclusive ~= true
end

-- The Cat Collector's value of a cat (section 3): its rarity's CollectorValue, times CollectorGoldMultiplier for
-- gold and CollectorRainbowMultiplier for rainbow.
function Trade.value(instance: Types.CatInstance): number
	local def = Catalog.getCat(instance.catId)
	local base = if def ~= nil then Config.CollectorValue[def.rarity] or 0 else 0
	if instance.variant == "gold" then
		return base * Config.CollectorGoldMultiplier
	elseif instance.variant == "rainbow" then
		return base * Config.CollectorRainbowMultiplier
	end
	return base
end

function Trade.sideValue(cats: { Types.CatInstance }): number
	local total = 0
	for _, instance in cats do
		total += Trade.value(instance)
	end
	return total
end

-- The confirm screen's warnings for the side giving `give` and getting `get` (Collector values) with `gets` cats and
-- pieces coming back: lopsided when it gives at least TradeLopsidedRatio times what it gets and gets something; a gift
-- when it gets nothing at all.
function Trade.warnings(give: number, get: number, gets: number): (boolean, boolean)
	local gift = gets == 0
	local lopsided = not gift and give > 0 and give >= Config.TradeLopsidedRatio * get
	return lopsided, gift
end

-- One cat as the log and the done card show it.
function Trade.summary(instance: Types.CatInstance): Types.CatSummary
	local def = Catalog.getCat(instance.catId)
	return {
		catId = instance.catId,
		rarity = if def ~= nil then def.rarity else "Common",
		variant = if instance.variant == "gold" or instance.variant == "rainbow"
			then instance.variant
			else nil,
		level = CatStats.level(instance),
	}
end

function Trade.summaries(cats: { Types.CatInstance }): { Types.CatSummary }
	local out: { Types.CatSummary } = {}
	for _, instance in cats do
		table.insert(out, Trade.summary(instance))
	end
	return out
end

-- The cat as it arrives in its new owner's save at `now`: the same uid, kind, coat, level, xp, charm and rescued
-- flag; no name and no slot; method "trade"; unlocked (#2906).
function Trade.arrival(instance: Types.CatInstance, now: number): Types.CatInstance
	local arrived: Types.CatInstance = {
		uid = instance.uid,
		catId = instance.catId,
		variant = instance.variant,
		caughtAt = now,
		spotId = nil,
		level = instance.level,
		xp = instance.xp,
		charm = instance.charm,
		rescued = if instance.rescued == true then true else nil,
		name = nil,
		method = "trade",
		locked = nil, -- #2906: never auto-locked
	}
	return arrived
end

-- Whether the save has applied trade `id` already.
function Trade.applied(profile: Types.PlayerProfile, id: string): boolean
	return table.find(profile.tradeIds, id) ~= nil
end

-- Applies one side of trade `id` to `profile` at `now`: the cats in `gave` (uids) leave, the cats in `got` arrive
-- (Trade.arrival; one whose uid the save already has is skipped), each counts in the Index, the stats count the
-- trade and the log gets an entry for `partnerName`. False, and nothing changed, when the save has applied `id`.
-- `gaveSummaries` are what the log shows for the cats that left (taken before they left). #1574: the pieces in
-- `pieces.gave` leave (off their spots) and those in `pieces.got` arrive unplaced (one the save owns is skipped).
-- #2745: the crates in `crates.gave` leave the bank and those in `crates.got` join it (subtract first, then add).
-- #2745 (section 1d): `fish.gave` golden fish leave the wallet and `fish.got` arrive, counted in today's fishIn.
function Trade.apply(
	profile: Types.PlayerProfile,
	id: string,
	partnerName: string,
	gave: { string },
	gaveSummaries: { Types.CatSummary },
	got: { Types.CatInstance },
	now: number,
	pieces: { gave: { string }, got: { string } }?,
	crates: { gave: { [string]: number }, got: { [string]: number } }?,
	fish: { gave: number, got: number }?
): boolean
	if Trade.applied(profile, id) then
		return false
	end
	-- #2745 (section 1d): fish leave the wallet (never below 0) and arrive in it. Received fish are not earned: they
	-- add nothing to lifetimeGoldenFish or stats.fishEarned (GoldenFish.credit is for earning only).
	local gaveFish = if fish ~= nil then Trade.sanitizeFish(fish.gave) else 0
	local gotFish = if fish ~= nil then Trade.sanitizeFish(fish.got) else 0
	profile.goldenFish = math.max(0, profile.goldenFish - gaveFish) + gotFish
	local noCrates: { [string]: number } = {}
	local gaveCrates = if crates ~= nil then crates.gave else noCrates
	local gotCrates = if crates ~= nil then crates.got else noCrates
	moveCrates(profile, gaveCrates, gotCrates) -- #2745
	for _, uid in gave do
		profile.cats[uid] = nil
	end
	local none: { string } = {}
	local gavePieces: { string } = if pieces ~= nil then pieces.gave else none
	local gotPieces: { string } = if pieces ~= nil then pieces.got else none
	for _, piece in gavePieces do
		takePiece(profile, piece)
	end
	for _, piece in gotPieces do
		givePiece(profile, piece)
	end
	for _, instance in got do
		if profile.cats[instance.uid] == nil then
			local arrived = Trade.arrival(instance, now)
			profile.cats[arrived.uid] = arrived
			if profile.collection[arrived.catId] == nil then
				profile.collection[arrived.catId] = now
			end
			if arrived.variant == "gold" and profile.goldCollection[arrived.catId] == nil then
				profile.goldCollection[arrived.catId] = now
			elseif
				arrived.variant == "rainbow" and profile.rainbowCollection[arrived.catId] == nil
			then
				profile.rainbowCollection[arrived.catId] = now
			end
		end
	end
	table.insert(profile.tradeIds, id)
	while #profile.tradeIds > Config.TradeIdsMax do
		table.remove(profile.tradeIds, 1)
	end
	table.insert(profile.tradeLog, 1, {
		id = id,
		at = now,
		partnerName = partnerName,
		gave = gaveSummaries,
		got = Trade.summaries(got),
		gaveDecor = Trade.pieceSummaries(gavePieces),
		gotDecor = Trade.pieceSummaries(gotPieces),
		gaveCrates = Trade.crateSummaries(gaveCrates),
		gotCrates = Trade.crateSummaries(gotCrates),
		gaveFish = if gaveFish > 0 then gaveFish else nil,
		gotFish = if gotFish > 0 then gotFish else nil,
	})
	while #profile.tradeLog > Config.TradeLogMax do
		table.remove(profile.tradeLog)
	end
	profile.stats.trades += 1
	Trade.countToday(profile, now, gotFish)
	return true
end

-- The global game day of `now` (os.time()), the day TradesPerDay counts. #1629 (Derek2: "nothing about real world day
-- for limits"): it turns at every in-game sunrise, the same on every server (was the UTC day; a saved UTC day number
-- never matches a game day, so an old count just starts afresh).
function Trade.day(now: number): number
	return Clock.dayAt(now - Config.ClockEpoch)
end

-- Trades the player has done today.
function Trade.today(profile: Types.PlayerProfile, now: number): number
	local today = profile.stats.tradesToday
	return if today.day == Trade.day(now) then today.count else 0
end

-- Counts one more trade today, and (#2745) `fishIn` more golden fish received today.
function Trade.countToday(profile: Types.PlayerProfile, now: number, fishIn: number?)
	local fish = Trade.fishInToday(profile, now) + (fishIn or 0)
	profile.stats.tradesToday = {
		day = Trade.day(now),
		count = Trade.today(profile, now) + 1,
		fishIn = if fish > 0 then fish else nil,
	}
end

-- What TradeService knows about one player when they ask or are asked (section 2).
export type Facts = {
	tier: number,
	busy: boolean, -- Trade.busy: catching, rescuing or flying when a trade opens; never at the ask (#3211)
	inTrade: boolean,
	sinceLastTrade: number, -- seconds since their last trade ended in a swap, math.huge for none
	today: number, -- trades today
	name: string, -- the display name, for the asker's toasts
}

-- #3211 (Derek2 11-11: "trade says busy but should go through at any time"): what a player is doing, and whether it
-- keeps them from a trade. Carrying (or packing) a cat never does: that is most of the game. An ask goes out and
-- arrives whatever either player is doing (`asking`); only opening a trade, and a trade already open, wait for a
-- catch, a rescue or a flight to end.
export type Doing = { flying: boolean, catching: boolean, rescuing: boolean }

function Trade.busy(doing: Doing, asking: boolean): boolean
	if asking then
		return false
	end
	return doing.flying or doing.catching or doing.rescuing
end

-- Why `from` cannot ask `to` to trade, or nil when they can. `minTier` is the live TradeMinTier, `on` the kill
-- switch, `asking` whether `from` has a request out already, `reaskLeft` the seconds until `from` may ask `to`
-- again, `setting` `to`'s tradeRequests and `friends` whether they are friends.
function Trade.askRefusal(
	from: Facts,
	to: Facts,
	minTier: number,
	on: boolean,
	asking: boolean,
	reaskLeft: number,
	setting: string,
	friends: boolean
): string?
	if not on then
		return Trade.Messages.off
	elseif from.tier < minTier then
		return string.format(Trade.Messages.tier, minTier)
	elseif from.inTrade then
		return Trade.Messages.inTrade
	elseif asking then
		return Trade.Messages.asking
	elseif from.busy then
		return Trade.Messages.busy
	elseif from.sinceLastTrade < Config.TradeCooldownSeconds then
		return Trade.Messages.cooldown
	elseif from.today >= Config.TradesPerDay then
		return Trade.Messages.daily
	elseif setting == "off" then
		return string.format(Trade.Messages.requestsOff, to.name)
	elseif setting == "friends" and not friends then
		return string.format(Trade.Messages.friendsOnly, to.name)
	elseif reaskLeft > 0 then
		return string.format(Trade.Messages.reask, to.name)
	elseif to.tier < minTier then
		return string.format(Trade.Messages.theirTier, to.name, minTier)
	elseif to.inTrade then
		return string.format(Trade.Messages.theirInTrade, to.name)
	elseif to.busy then
		return string.format(Trade.Messages.theirBusy, to.name)
	elseif to.today >= Config.TradesPerDay then
		return string.format(Trade.Messages.theirDaily, to.name)
	end
	return nil
end

-- Why a trade open between two players must end now, or nil: the kill switch, or either busy. #2568 (Derek2
-- 2026-11-09: "add trading from anywhere"): where they stand no longer matters.
function Trade.endReason(on: boolean, aBusy: boolean, bBusy: boolean): string?
	if not on then
		return Trade.Ended.off
	elseif aBusy or bBusy then
		return Trade.Ended.busy
	end
	return nil
end

-- A saved trade log made whole: up to TradeLogMax well formed entries, newest first.
function Trade.sanitizeLog(raw: unknown): { Types.TradeLogEntry }
	local out: { Types.TradeLogEntry } = {}
	if type(raw) ~= "table" then
		return out
	end
	local function summaries(value: any): { Types.CatSummary }
		local list: { Types.CatSummary } = {}
		if type(value) == "table" then
			for _, entry in value do
				if
					type(entry) == "table"
					and type(entry.catId) == "string"
					and type(entry.rarity) == "string"
					and #list < Config.TradeMaxCats
				then
					local variant: string? = if entry.variant == "gold"
							or entry.variant == "rainbow"
						then entry.variant
						else nil
					local summary: Types.CatSummary = {
						catId = entry.catId,
						rarity = entry.rarity,
						variant = variant,
						level = if type(entry.level) == "number"
								and entry.level == entry.level
							then math.floor(entry.level)
							else 1,
					}
					table.insert(list, summary)
				end
			end
		end
		return list
	end
	local function pieceSummaries(value: any): { Types.DecorSummary }
		local list: { Types.DecorSummary } = {}
		if type(value) == "table" then
			for _, entry in value do
				if
					type(entry) == "table"
					and type(entry.id) == "string"
					and #entry.id <= 64
					and type(entry.rarity) == "string"
					and #list < Config.TradeMaxDecor
				then
					table.insert(list, {
						id = entry.id,
						kind = if entry.kind == "lawn" then "lawn" else "decor",
						rarity = string.sub(entry.rarity, 1, 16),
					})
				end
			end
		end
		return list
	end
	local function crateSummaries(value: any): { Types.CrateSummary }
		local list: { Types.CrateSummary } = {}
		if type(value) == "table" then
			for _, entry in value do
				if
					type(entry) == "table"
					and type(entry.id) == "string"
					and #entry.id <= 64
					and type(entry.count) == "number"
					and entry.count == entry.count
					and entry.count >= 1
					and #list < Config.TradeMaxCrateKinds
				then
					table.insert(list, {
						id = entry.id,
						count = math.min(math.floor(entry.count), Config.TradeMaxCrates),
					})
				end
			end
		end
		return list
	end
	local function fishCount(value: any): number?
		local n = Trade.sanitizeFish(value)
		return if n > 0 then n else nil
	end
	for _, entry in raw :: { any } do
		if #out >= Config.TradeLogMax then
			break
		end
		if
			type(entry) == "table"
			and type(entry.id) == "string"
			and type(entry.at) == "number"
			and entry.at == entry.at
			and type(entry.partnerName) == "string"
		then
			table.insert(out, {
				id = entry.id,
				at = math.floor(entry.at),
				partnerName = entry.partnerName,
				gave = summaries(entry.gave),
				got = summaries(entry.got),
				gaveDecor = pieceSummaries(entry.gaveDecor),
				gotDecor = pieceSummaries(entry.gotDecor),
				gaveCrates = crateSummaries(entry.gaveCrates),
				gotCrates = crateSummaries(entry.gotCrates),
				gaveFish = fishCount(entry.gaveFish),
				gotFish = fishCount(entry.gotFish),
			})
		end
	end
	return out
end

-- Saved applied trade ids made whole: strings only, the last TradeIdsMax.
function Trade.sanitizeIds(raw: unknown): { string }
	local out: { string } = {}
	if type(raw) == "table" then
		for _, id in raw :: { any } do
			if type(id) == "string" then
				table.insert(out, id)
			end
		end
	end
	while #out > Config.TradeIdsMax do
		table.remove(out, 1)
	end
	return out
end

-- Saved stats.tradesToday made whole.
function Trade.sanitizeToday(raw: unknown): Types.TradesToday
	if type(raw) == "table" then
		local day, count = (raw :: any).day, (raw :: any).count
		if type(day) == "number" and day == day and type(count) == "number" and count == count then
			-- #2745: fishIn kept as a whole number from 1 (any amount, so a save over the cap stays over it)
			local fishIn = (raw :: any).fishIn
			local fish = if wholeFish(fishIn) and fishIn > 0 then fishIn else nil
			return { day = math.floor(day), count = math.max(0, math.floor(count)), fishIn = fish }
		end
	end
	return { day = 0, count = 0 }
end

return Trade
