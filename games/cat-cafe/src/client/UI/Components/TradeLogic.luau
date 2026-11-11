--!strict
-- Trading on the UI (F102, trading.md sections 2 and 3), pure so the cloud spec runner checks it. The server holds the
-- trade (TradeState through UI.trade.state); these say what the trade window, the request card and the players list
-- show, and which buttons can be pressed.
--   minTier(attribute) -> number         the live minimum tier: Workspace's TradeMinTier, else Config, else 3
--   shown(tier, minTier) -> boolean      the HUD's Trade tile works from that tier (greyed below it, #2462)
--   lockedText(minTier) -> string        "Unlocks at Tier 3", a tap on the greyed tile (#2462)
--   askTitle(name) -> string             the request card: "Sam wants to trade"
--   rate(n, forMe) -> string             a card's earnings, short: "$24/s" on your cats, "+$1.2K/s" on theirs
--   compact(n) -> string                 950, 1.2K, 12K, 1.5M (cut down)
--   totals(state) -> (give, get)         "Your cats: $180/s now", "Their cats: +$240/s in your cafe"
--   headline(state, now) -> string       the window's subtitle for each phase
--   countdown(state, now) -> number?     the big number while both are ready
--   readyButton(state) -> ButtonView     Ready, Not ready, or Ready greyed with both offers empty
--   warning(state) -> string?            the confirm screen's red line: a gift or a lopsided trade
--   confirmButton(state, shownFor, now)  Confirm, "Confirm (2)" until the server's confirmAt (else for the first
--                                        CONFIRM_WAIT seconds of a warning), or
--                                        "Waiting for Sam" once pressed
--   changed(state, now) -> Changed?      the tile that changed in the last CHANGED_SECONDS, for the yellow flash
--   myCats(cats, defOf, offered) -> { Pick }   your cats under the grids: rarest first, each with why it cannot go
--   pickHint(pick, full) -> string?      "Unlock it on its card to trade", "This cat can't be traded", ...
--   playerButton(row, minTier) -> ButtonView   a players list row: Trade, Asked (open, then REASK_SECONDS), Busy or
--                                        "Tier 3 needed"
--   doneLine(got, gotDecor?, gotCrates?, gotFish?) "Trade done! 2 new cats" (and "1 new decor", #1574, "3 new crates"
--                                        and "50 golden fish", #2745)
-- #1574 (section 1b): decor and lawn pieces, on the Decor tab beside Cats.
--   myPieces(owned, unlocked, pieceOf, offered, theyHave) -> { PiecePick }   your tradeable pieces: rarest first,
--                                        each with why it cannot go (locked, or the other player has it)
--   pieceHint(pick, full) -> string?     "Unlock it on its card to trade", "They already have this", ...
--   bonusText(bonus) -> string?          a piece's tip bonus on its card: "+5%"
--   pieceRarity(rarity, bonus) -> string "Rare · +5%" under a piece on the confirm face
--   offerCount(side) -> number           the cats, pieces and crate kinds on one side, and 1 for any fish
-- #2745 (section 1c): banked crates, on the Crates tab while the server's cratesOn says so.
--   myCrates(banked, defOf, offered, blocked) -> { CratePick }   your tradeable crates (never a golden one), in
--                                        catalog order, each with how many are banked and on offer
--   crateHint(pick, side) -> string?     why a tap adds none: the server's reason, "You don't have that many", the caps
--   crateMax(pick, side) -> number       the long press picker's top: banked, within the caps
--   crateChange(offered, wanted)         what the picker sends: ("add" | "remove", count), or nil for no change
--   countText(n) -> string               "x3"
-- #2745 (section 1d): golden fish, an amount on each side while the server's fishOn says so.
--   fishOf(side) -> number               the fish on offer, a whole number, 0 for none
--   fishMax(wallet, room) -> number      the fish picker's top: the wallet, MAX_FISH and the other player's room today
--   fishHint(wallet, room, offered)      why the picker can't open: "You have no golden fish", the daily cap
--   fishRoomLine(room) -> string         "They can get 150 more today"
--   fishQuick(10 | 50 | "max", most)     the picker's quick amounts
-- Part 2 (trading.md sections 1 and 5): the Trade requests setting and the Trades page.
--   REQUEST_MODES, modeLabel(mode)       "everyone", "friends", "off" and "Everyone", "Friends only", "Off"
--   requestsMode(saved, tap, now)        what the setting shows: a fresh press for HOLD_SECONDS, else the saved
--                                        value, else Everyone
--   ago(at, now) -> string               "Just now", "12m ago", "3h ago", "Yesterday", "4 days ago", "3 weeks ago"
--   logRows(log, now) -> { LogRow }      the Trades page, newest first, at most LOG_MAX

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type ButtonView = {
	text: string,
	enabled: boolean,
	style: "primary" | "ghost" | "danger",
	ready: boolean?, -- readyButton: the Ready value a press sends
}

export type Changed = { side: "me" | "them", uid: string }

export type PickStatus = "ok" | "offered" | "locked" | "exclusive"

export type Pick = {
	uid: string,
	catId: string,
	name: string,
	rarity: string,
	variant: string?,
	level: number,
	rating: number,
	status: PickStatus,
}

-- #1574: a decor or lawn piece in the Decor tab; "theyHave" is greyed with "They already have this"
export type PieceStatus = "ok" | "offered" | "locked" | "theyHave"

export type PiecePick = {
	id: string,
	name: string,
	kind: string, -- "decor" or "lawn"
	rarity: string,
	bonus: number, -- 0.05 is +5%
	status: PieceStatus,
}

-- what the shared Trade.piece says about a tradeable piece (nil for one that can't be traded)
export type PieceInfo = { kind: string, name: string, rarity: string, bonus: number }

-- #2745: a crate kind in the Crates tab: "offered" once every banked one is on offer, "blocked" when the other
-- player can't take it yet (`reason`, the server's crateBlocked)
export type CrateStatus = "ok" | "offered" | "blocked"

export type CratePick = {
	id: string,
	name: string,
	banked: number,
	offered: number,
	status: CrateStatus,
	reason: string?,
}

-- what the catalog says about a crate (UI Types' CrateDef, kept loose); `order` is its place in Catalog.crates
export type CrateInfo = { name: string, golden: boolean?, order: number }

export type RequestMode = "everyone" | "friends" | "off"

export type Tap = { value: string, at: number } -- a press on one of REQUEST_MODES

-- a cat on the Trades page (UI Types' TradeCat)
export type LogCat = { catId: string, rarity: string, variant: string?, level: number }
-- #1574: a decor or lawn piece in a log entry (Types.DecorSummary); `kind` "decor" or "lawn"
export type LogPiece = { id: string, kind: string, rarity: string }
-- #2745: a banked crate kind in a log entry (Types.CrateSummary)
export type LogCrate = { id: string, count: number }

export type LogRow = {
	id: string,
	partner: string, -- "With Sam"
	when: string, -- "3h ago"
	gave: { LogCat },
	got: { LogCat },
	gaveDecor: { LogPiece }, -- #1574: empty for entries from before decor trading
	gotDecor: { LogPiece },
	gaveCrates: { LogCrate }, -- #2745: empty for entries from before crate trading
	gotCrates: { LogCrate },
	gaveFish: number, -- #2745 (section 1d): golden fish, 0 for none
	gotFish: number,
}

export type PlayerRow = {
	tier: number?, -- the Player's Tier attribute, nil before the server sends it
	trading: boolean?, -- the Player's Trading attribute
	asked: boolean, -- this player asked them in the last TradeReaskSeconds
}

-- the cats the window reads (UI Types' CatInstance and TradeState, kept loose so this loads on its own)
type Cat = {
	uid: string,
	catId: string,
	variant: string?,
	level: number?,
	rating: number?,
	locked: boolean?,
	name: string?,
}

type Def = { name: string, rarity: string, exclusive: boolean? }

local TradeLogic = {}

TradeLogic.ICON = "🤝"
TradeLogic.TITLE = "Trade"
TradeLogic.CHANGED_SECONDS = 2 -- how long a changed tile flashes and its side says "Changed!"
TradeLogic.CONFIRM_WAIT = (Config.TradeConfirmWaitSeconds or 2) :: number -- Confirm stays off this long on a gift or a lopsided trade
TradeLogic.MAX_CATS = (Config.TradeMaxCats or 9) :: number
TradeLogic.REQUEST_SECONDS = (Config.TradeRequestSeconds or 20) :: number
-- a declined or lapsed ask cannot be repeated this long, so a players row says "Asked" for it (review N332); 3 s
-- since #2550, counted from the server's TradeAskEnded
TradeLogic.REASK_SECONDS = (Config.TradeReaskSeconds or 60) :: number

TradeLogic.MAX_DECOR = (Config.TradeMaxDecor or 9) :: number
TradeLogic.MAX_CRATES = (Config.TradeMaxCrates or 20) :: number -- #2745: crates a side in all
TradeLogic.MAX_CRATE_KINDS = (Config.TradeMaxCrateKinds or 6) :: number -- and kinds of crate
TradeLogic.MAX_FISH = (Config.TradeMaxFish or 200) :: number -- #2745 (section 1d): golden fish a side

local MIN_TIER: number = Config.TradeMinTier or 3
-- Theme.rarityOrder, kept here so this module loads without Theme's fonts (the cloud test runner has no Font)
local RANK: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
local COAT: { [string]: number } = { gold = 1, rainbow = 2 }
local STATUS_ORDER: { [PickStatus]: number } = { ok = 1, offered = 1, locked = 2, exclusive = 3 }

function TradeLogic.minTier(attribute: any): number
	return if type(attribute) == "number" then attribute else MIN_TIER
end

function TradeLogic.shown(tier: number?, minTier: number): boolean
	return (tier or 0) >= minTier
end

-- #2462: what a tap on the greyed Trade tile says below the trading tier
function TradeLogic.lockedText(minTier: number): string
	return string.format("Unlocks at Tier %d", minTier)
end

function TradeLogic.askTitle(name: string): string
	return string.format("%s wants to trade", name)
end

local UNITS = { "K", "M", "B", "T", "Qa", "Qi" }

-- Short enough for a cat card: 950, 1.2K, 12K, 125K, 1.5M, cut down and never rounded up.
function TradeLogic.compact(n: number): string
	local value = math.max(0, math.floor(n))
	if value < 1000 then
		return tostring(value)
	end
	local unit = 0
	while value >= 1000 and unit < #UNITS do
		value /= 1000
		unit += 1
	end
	if value < 10 then
		local tenths = math.floor(value * 10) / 10
		return (
			if tenths == math.floor(tenths)
				then string.format("%d", tenths)
				else string.format("%.1f", tenths)
		) .. UNITS[unit]
	end
	return string.format("%d", math.floor(value)) .. UNITS[unit]
end

-- A cat card's earnings, short: "$24/s", "+$1.2K/s" on their side. The totals use the HUD's numbers.
function TradeLogic.rate(n: number, forMe: boolean): string
	local text = "$" .. TradeLogic.compact(n) .. "/s"
	return if forMe then "+" .. text else text
end

local function total(n: number, forMe: boolean): string
	local text = "$" .. ShortNumber.format(math.max(0, math.floor(n))) .. "/s"
	return if forMe then "+" .. text else text
end

function TradeLogic.totals(state: any): (string, string)
	return string.format("Your cats: %s now", total(state.myRateNow or 0, false)),
		string.format("Their cats: %s in your cafe", total(state.theirRateForMe or 0, true))
end

function TradeLogic.countdown(state: any, now: number): number?
	if state.phase ~= "countdown" or state.countdownEndsAt == nil then
		return nil
	end
	return math.max(1, math.ceil(state.countdownEndsAt - now))
end

function TradeLogic.headline(state: any, now: number): string
	local them: string = state.them.name
	if state.phase == "countdown" then
		return string.format("Both ready! Trading in %d...", TradeLogic.countdown(state, now) or 1)
	elseif state.phase == "confirm" then
		if state.me.confirmed then
			return string.format("Waiting for %s to confirm", them)
		elseif state.them.confirmed then
			return string.format("%s confirmed. Check it, then confirm", them)
		end
		return "Check the trade, then confirm"
	elseif state.me.ready then
		return string.format("Waiting for %s to press Ready", them)
	elseif state.them.ready then
		return string.format("%s is ready. Press Ready when you are", them)
	end
	return "Add cats, then press Ready"
end

function TradeLogic.readyButton(state: any): ButtonView
	if state.me.ready or state.phase == "countdown" then
		return { text = "Not ready", enabled = true, style = "ghost", ready = false }
	end
	local empty = TradeLogic.offerCount(state.me) == 0 and TradeLogic.offerCount(state.them) == 0
	return { text = "Ready", enabled = not empty, style = "primary", ready = true }
end

function TradeLogic.warning(state: any): string?
	if state.gift then
		return "You get nothing back"
	elseif state.lopsided then
		return "You're giving much more than you get. Are you sure?"
	end
	return nil
end

-- `shownFor` is how long the confirm screen has been up, in seconds, and `now` the server time. The server's
-- confirmAt (when it starts to accept this player's Confirm) decides the wait; a state without one waits CONFIRM_WAIT
-- from the screen showing on a warning. Never more than CONFIRM_WAIT, so an odd confirmAt cannot hold it longer.
function TradeLogic.confirmButton(state: any, shownFor: number, now: number?): ButtonView
	if state.me.confirmed then
		return {
			text = string.format("Waiting for %s", state.them.name),
			enabled = false,
			style = "primary",
		}
	end
	local warned = TradeLogic.warning(state) ~= nil
	local confirmAt = state.confirmAt
	local left = 0
	if type(confirmAt) == "number" and confirmAt == confirmAt and now ~= nil then
		left = confirmAt - now
	elseif warned then
		left = TradeLogic.CONFIRM_WAIT - shownFor
	end
	local wait = math.ceil(math.min(left, TradeLogic.CONFIRM_WAIT))
	if wait > 0 then
		return {
			text = string.format("Confirm (%d)", wait),
			enabled = false,
			style = if warned then "danger" else "primary",
		}
	end
	return {
		text = "Confirm",
		enabled = true,
		style = if TradeLogic.warning(state) ~= nil then "danger" else "primary",
	}
end

function TradeLogic.changed(state: any, now: number): Changed?
	local change = state.changed
	if change == nil or now - change.at >= TradeLogic.CHANGED_SECONDS or now < change.at - 1 then
		return nil
	end
	return { side = change.side, uid = change.uid }
end

-- #3211 (Derek2 11-11: "sort trade by highest rarity first for all sections"): the rarest first, whatever a card's
-- state; a locked or offered cat keeps its place among its rarity (it sorted below every free cat before, so the
-- best cats, which players lock, sat at the bottom). Within a rarity: free cards, then coat, level and rating.
local function before(a: Pick, b: Pick): boolean
	local ra, rb = RANK[a.rarity] or 0, RANK[b.rarity] or 0
	if ra ~= rb then
		return ra > rb
	end
	local sa, sb = STATUS_ORDER[a.status], STATUS_ORDER[b.status]
	if sa ~= sb then
		return sa < sb
	end
	local ca, cb = COAT[a.variant or ""] or 0, COAT[b.variant or ""] or 0
	if ca ~= cb then
		return ca > cb
	end
	if a.level ~= b.level then
		return a.level > b.level
	end
	if a.rating ~= b.rating then
		return a.rating > b.rating
	end
	return a.uid < b.uid
end

-- Your cats for the list under the grids. `defOf` finds a cat's catalog entry; `offered` holds the uids already in
-- your offer. Cats with no catalog entry are left out.
function TradeLogic.myCats(
	cats: { [string]: Cat }?,
	defOf: (catId: string) -> Def?,
	offered: { [string]: boolean }
): { Pick }
	local picks: { Pick } = {}
	local all: { [string]: Cat } = cats or {}
	for uid, cat in all do
		local def = defOf(cat.catId)
		if def ~= nil then
			local status: PickStatus = if def.exclusive == true
				then "exclusive"
				elseif offered[uid] then "offered"
				elseif cat.locked == true then "locked"
				else "ok"
			local variant: string? = if cat.variant == "gold" or cat.variant == "rainbow"
				then cat.variant
				else nil
			local pick: Pick = {
				uid = uid,
				catId = cat.catId,
				name = if cat.name ~= nil and cat.name ~= "" then cat.name else def.name,
				rarity = def.rarity,
				variant = variant,
				level = cat.level or 1,
				rating = cat.rating or 0,
				status = status,
			}
			table.insert(picks, pick)
		end
	end
	table.sort(picks, before)
	return picks
end

-- What a press on a cat in the list does not do, and why; nil when it goes into the offer.
function TradeLogic.pickHint(pick: Pick, full: boolean): string?
	if pick.status == "locked" then
		return "Unlock it on its card to trade"
	elseif pick.status == "exclusive" then
		return "This cat can't be traded"
	elseif pick.status == "ok" and full then
		return string.format("Up to %d cats a trade", TradeLogic.MAX_CATS)
	end
	return nil
end

-- #2745 (section 1d): the golden fish on one side of the trade, a whole number, 0 for none or before fish trading.
function TradeLogic.fishOf(side: any): number
	local fish = if type(side) == "table" then side.fish else nil
	if type(fish) ~= "number" or fish ~= fish or fish == math.huge then
		return 0
	end
	return math.max(0, math.floor(fish))
end

-- The cats and pieces on one side of the trade (#1574: decor counts toward Ready too, and #2745 crates and fish).
function TradeLogic.offerCount(side: any): number
	local decor = if type(side.decor) == "table" then #side.decor else 0
	local crates = if type(side.crates) == "table" then #side.crates else 0
	local fish = if TradeLogic.fishOf(side) > 0 then 1 else 0
	return #side.cats + decor + crates + fish
end

-- #1574: the rarities whose pieces arrive locked (the shared Trade.LOCKED_RARITIES), and the lawn's own rungs in
-- the cats' order (Uncommon between Common and Rare, Golden at the top).
local LOCKABLE: { [string]: boolean } = { Legendary = true, Mythical = true, Golden = true }
local PIECE_RANK: { [string]: number } =
	{ Common = 1, Uncommon = 1.5, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5, Golden = 6 }
local PIECE_STATUS_ORDER: { [PieceStatus]: number } =
	{ ok = 1, offered = 1, locked = 2, theyHave = 3 }

-- Your pieces for the Decor tab: every owned id (`owned`, the decor and lawn pieces owned) that `pieceOf` says can
-- be traded, rarest first; locked when its rarity is lockable and `unlocked` lacks it, "theyHave" when the other
-- player owns it (the server's `theyHave`), "offered" when already on your side.
function TradeLogic.myPieces(
	owned: { [string]: boolean }?,
	unlocked: { [string]: boolean }?,
	pieceOf: (id: string) -> PieceInfo?,
	offered: { [string]: boolean },
	theyHave: { string }?
): { PiecePick }
	local has: { [string]: boolean } = {}
	local theirs: { string } = theyHave or {}
	for _, id in theirs do
		has[id] = true
	end
	local open: { [string]: boolean } = unlocked or {}
	local picks: { PiecePick } = {}
	local mine: { [string]: boolean } = owned or {}
	for id, yes in mine do
		local info = if yes == true then pieceOf(id) else nil
		if info ~= nil then
			local status: PieceStatus = if offered[id]
				then "offered"
				elseif LOCKABLE[info.rarity] == true and open[id] ~= true then "locked"
				elseif has[id] then "theyHave"
				else "ok"
			table.insert(picks, {
				id = id,
				name = info.name,
				kind = info.kind,
				rarity = info.rarity,
				bonus = info.bonus,
				status = status,
			})
		end
	end
	table.sort(picks, function(a: PiecePick, b: PiecePick): boolean
		local ra, rb = PIECE_RANK[a.rarity] or 0, PIECE_RANK[b.rarity] or 0
		if ra ~= rb then
			return ra > rb -- #3211: the rarest first, then the free ones within a rarity
		end
		local sa, sb = PIECE_STATUS_ORDER[a.status], PIECE_STATUS_ORDER[b.status]
		if sa ~= sb then
			return sa < sb
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.id < b.id
	end)
	return picks
end

-- What a press on a piece in the Decor tab does not do, and why; nil when it goes into the offer (or comes back).
function TradeLogic.pieceHint(pick: PiecePick, full: boolean): string?
	if pick.status == "locked" then
		return "Unlock it on its card to trade"
	elseif pick.status == "theyHave" then
		return "They already have this"
	elseif pick.status == "ok" and full then
		return string.format("Up to %d decor each", TradeLogic.MAX_DECOR)
	end
	return nil
end

-- A piece's tip bonus on its card ("+5%"), nil without one.
function TradeLogic.bonusText(bonus: number?): string?
	if type(bonus) ~= "number" or bonus ~= bonus or bonus <= 0 then
		return nil
	end
	return string.format("+%d%%", math.max(1, math.floor(bonus * 100 + 0.5)))
end

-- Under a piece on the confirm face: its rarity and bonus, "Rare · +5%".
function TradeLogic.pieceRarity(rarity: string, bonus: number?): string
	local extra = TradeLogic.bonusText(bonus)
	return if extra then rarity .. " · " .. extra else rarity
end

-- #2745: one side's crates as (kinds, crates in all) from its TradeCrateTile list.
local function crateTotals(side: any): (number, number)
	local list: { any } = if type(side) == "table" and type(side.crates) == "table"
		then side.crates
		else {}
	local total = 0
	for _, crate in list do
		total += crate.count
	end
	return #list, total
end

-- #2745: your banked crates for the Crates tab: every crate id with a count of 1 or more that `defOf` knows and isn't
-- golden, the last in the catalog first (#3211); `offered` is crate id -> how many are on your side, `blocked` the server's crateBlocked.
function TradeLogic.myCrates(
	banked: { [string]: number }?,
	defOf: (id: string) -> CrateInfo?,
	offered: { [string]: number },
	blocked: { [string]: string }?
): { CratePick }
	local why: { [string]: string } = blocked or {}
	local counts: { [string]: number } = banked or {}
	local picks: { CratePick } = {}
	local order: { [string]: number } = {}
	for id, raw in counts do
		local count = if type(raw) == "number" and raw == raw then math.floor(raw) else 0
		local def = if count > 0 then defOf(id) else nil
		if def ~= nil and def.golden ~= true then
			local on = math.min(count, offered[id] or 0)
			local reason = why[id]
			local status: CrateStatus = if reason ~= nil
				then "blocked"
				elseif on >= count then "offered"
				else "ok"
			local pick: CratePick = {
				id = id,
				name = def.name,
				banked = count,
				offered = on,
				status = status,
				reason = reason,
			}
			table.insert(picks, pick)
			order[id] = def.order
		end
	end
	table.sort(picks, function(a: CratePick, b: CratePick): boolean
		-- #3211: a crate has no rarity of its own; the later a crate comes in the catalog (a further area, a dearer
		-- crate) the rarer its pieces, so the last comes first
		if order[a.id] ~= order[b.id] then
			return order[a.id] > order[b.id]
		end
		return a.id < b.id
	end)
	return picks
end

-- #2745: the most of `pick` your side (`side`, a TradeSide) can hold: what is banked, within TradeMaxCrates in all,
-- and 0 for a new kind past TradeMaxCrateKinds.
function TradeLogic.crateMax(pick: CratePick, side: any): number
	local kinds, total = crateTotals(side)
	if pick.offered == 0 and kinds >= TradeLogic.MAX_CRATE_KINDS then
		return 0
	end
	return math.max(0, math.min(pick.banked, TradeLogic.MAX_CRATES - (total - pick.offered)))
end

-- #2745: why a tap on `pick` adds none, or nil when it adds one.
function TradeLogic.crateHint(pick: CratePick, side: any): string?
	if pick.status == "blocked" then
		return pick.reason or "This crate can't be traded"
	elseif pick.offered >= pick.banked then
		return "You don't have that many"
	end
	local kinds, total = crateTotals(side)
	if pick.offered == 0 and kinds >= TradeLogic.MAX_CRATE_KINDS then
		return string.format("Up to %d kinds of crate each", TradeLogic.MAX_CRATE_KINDS)
	elseif total >= TradeLogic.MAX_CRATES then
		return string.format("Up to %d crates each", TradeLogic.MAX_CRATES)
	end
	return nil
end

-- #2745: what the long press picker sends to go from `offered` to `wanted`: the server takes a difference.
function TradeLogic.crateChange(offered: number, wanted: number): (string?, number)
	if wanted > offered then
		return "add", wanted - offered
	elseif wanted < offered then
		return "remove", offered - wanted
	end
	return nil, 0
end

-- #2745 (section 1d): the most golden fish you can put on offer: your wallet, TradeMaxFish and the other player's
-- room left today (the state's fishRoom; nil reads as no limit past TradeMaxFish).
function TradeLogic.fishMax(wallet: number?, room: number?): number
	local most = TradeLogic.MAX_FISH
	if type(wallet) == "number" and wallet == wallet then
		most = math.min(most, math.floor(wallet))
	else
		most = 0
	end
	if type(room) == "number" and room == room then
		most = math.min(most, math.floor(room))
	end
	return math.max(0, most)
end

-- #2745: why the fish picker can't open (nothing can go and none is on offer), or nil.
function TradeLogic.fishHint(wallet: number?, room: number?, offered: number): string?
	if offered > 0 or TradeLogic.fishMax(wallet, room) > 0 then
		return nil
	elseif type(wallet) ~= "number" or wallet < 1 then
		return "You have no golden fish"
	end
	return "They can't get more golden fish today"
end

-- #2745: the picker's line under its title: the other player's room left today.
function TradeLogic.fishRoomLine(room: number?): string
	if type(room) ~= "number" or room ~= room or room >= TradeLogic.MAX_FISH then
		return string.format("Up to %d a trade", TradeLogic.MAX_FISH)
	elseif room < 1 then
		return "They can't get more today"
	end
	return string.format("They can get %d more today", math.floor(room))
end

-- #2745: a quick amount (10, 50 or "max") in the fish picker, within 0 and `most`.
function TradeLogic.fishQuick(quick: number | "max", most: number): number
	if quick == "max" then
		return most
	end
	return math.clamp(quick :: number, 0, most)
end

function TradeLogic.countText(n: number): string
	return "x" .. tostring(math.max(0, math.floor(n)))
end

-- #3211: when a row's Asked wears off once the server says the ask ended at `at` (os.clock): after REASK_SECONDS
-- for a decline or a lapse, at once (`now`) for an ask that was refused or could not open.
function TradeLogic.askedUntil(at: number, now: boolean): number
	return if now then at else at + TradeLogic.REASK_SECONDS
end

function TradeLogic.playerButton(row: PlayerRow, minTier: number): ButtonView
	if row.asked then
		return { text = "Asked", enabled = false, style = "primary" }
	elseif row.trading == true then
		return { text = "Busy", enabled = false, style = "ghost" }
	elseif row.tier ~= nil and row.tier < minTier then
		return { text = string.format("Tier %d needed", minTier), enabled = false, style = "ghost" }
	end
	return { text = "Trade", enabled = true, style = "primary" }
end

-- #1574: `gotDecor`, the pieces that came, and #2745: `gotCrates` ({ id, count }) and `gotFish` (a number), join the
-- line: "Trade done! 1 new cat, 2 new decor, 3 new crates and 50 golden fish".
function TradeLogic.doneLine(
	got: { any }?,
	gotDecor: { any }?,
	gotCrates: { any }?,
	gotFish: number?
): string
	local count = if got then #got else 0
	local pieces = if type(gotDecor) == "table" then #gotDecor else 0
	local crates = 0
	if type(gotCrates) == "table" then
		for _, crate in gotCrates do
			crates += if type(crate) == "table" and type(crate.count) == "number"
				then crate.count
				else 0
		end
	end
	local parts: { string } = {}
	if count > 0 then
		table.insert(parts, string.format("%d new %s", count, if count == 1 then "cat" else "cats"))
	end
	if pieces > 0 then
		table.insert(parts, string.format("%d new decor", pieces))
	end
	if crates > 0 then
		table.insert(
			parts,
			string.format("%d new %s", crates, if crates == 1 then "crate" else "crates")
		)
	end
	local fish = TradeLogic.fishOf({ fish = gotFish })
	if fish > 0 then
		table.insert(parts, string.format("%d golden fish", fish))
	end
	if #parts == 0 then
		return "Trade done!"
	elseif #parts == 1 then
		return "Trade done! " .. parts[1]
	end
	local last = table.remove(parts) :: string
	return string.format("Trade done! %s and %s", table.concat(parts, ", "), last)
end

local REQUEST_MODES: { RequestMode } = { "everyone", "friends", "off" }
TradeLogic.REQUEST_MODES = REQUEST_MODES
TradeLogic.HOLD_SECONDS = 5 -- a press shows this long while the server has not agreed (SettingsList.HOLD_SECONDS)
TradeLogic.LOG_MAX = (Config.TradeLogMax or 20) :: number

local MODE_LABELS: { [string]: string } =
	{ everyone = "Everyone", friends = "Friends only", off = "Off" }

function TradeLogic.modeLabel(mode: string): string
	return MODE_LABELS[mode] or mode
end

local function asMode(value: unknown): string?
	if value == "everyone" or value == "friends" or value == "off" then
		return value :: string
	end
	return nil
end

-- "everyone", "friends" or "off"
function TradeLogic.requestsMode(saved: unknown, tap: Tap?, now: number): string
	local mode = asMode(saved)
	if
		tap ~= nil
		and (mode == nil or (tap.value ~= mode and now - tap.at < TradeLogic.HOLD_SECONDS))
	then
		return tap.value
	end
	return mode or "everyone"
end

function TradeLogic.ago(at: number, now: number): string
	local seconds = math.max(0, now - at)
	if seconds < 60 then
		return "Just now"
	elseif seconds < 3600 then
		return string.format("%dm ago", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%dh ago", math.floor(seconds / 3600))
	elseif seconds < 2 * 86400 then
		return "Yesterday"
	elseif seconds < 14 * 86400 then
		return string.format("%d days ago", math.floor(seconds / 86400))
	end
	return string.format("%d weeks ago", math.floor(seconds / (7 * 86400)))
end

local function cats(list: unknown): { LogCat }
	local out: { LogCat } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, cat in list :: { any } do
		if type(cat) == "table" and type(cat.catId) == "string" then
			local variant: string? = if cat.variant == "gold" or cat.variant == "rainbow"
				then cat.variant
				else nil
			local entry: LogCat = {
				catId = cat.catId,
				rarity = if type(cat.rarity) == "string" then cat.rarity else "Common",
				variant = variant,
				level = if type(cat.level) == "number" then cat.level else 1,
			}
			table.insert(out, entry)
		end
	end
	return out
end

-- #1574: the pieces of a log entry's gaveDecor or gotDecor (nil before decor trading); broken ones left out
local function pieces(list: unknown): { LogPiece }
	local out: { LogPiece } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, piece in list :: { any } do
		if type(piece) == "table" and type(piece.id) == "string" then
			local entry: LogPiece = {
				id = piece.id,
				kind = if piece.kind == "lawn" then "lawn" else "decor",
				rarity = if type(piece.rarity) == "string" then piece.rarity else "Common",
			}
			table.insert(out, entry)
		end
	end
	return out
end

-- #2745: the crates of a log entry's gaveCrates or gotCrates (nil before crate trading); broken ones left out
local function logCrates(list: unknown): { LogCrate }
	local out: { LogCrate } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, crate in list :: { any } do
		if type(crate) == "table" and type(crate.id) == "string" then
			local count = TradeLogic.fishOf({ fish = crate.count }) -- a whole number, 0 for junk
			if count > 0 then
				local entry: LogCrate = { id = crate.id, count = count }
				table.insert(out, entry)
			end
		end
	end
	return out
end

-- The Trades page's rows from ProfileSync's tradeLog: newest first, at most LOG_MAX, entries without an id or a
-- time left out.
function TradeLogic.logRows(log: { any }?, now: number): { LogRow }
	local entries: { any } = {}
	local all: { any } = log or {}
	for _, entry in all do
		if type(entry) == "table" and type(entry.id) == "string" and type(entry.at) == "number" then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a: any, b: any): boolean
		if a.at ~= b.at then
			return a.at > b.at
		end
		return a.id < b.id
	end)
	local rows: { LogRow } = {}
	for index, entry in entries do
		if index > TradeLogic.LOG_MAX then
			break
		end
		local name = if type(entry.partnerName) == "string" and entry.partnerName ~= ""
			then entry.partnerName
			else "a player"
		table.insert(rows, {
			id = entry.id,
			partner = "With " .. name,
			when = TradeLogic.ago(entry.at, now),
			gave = cats(entry.gave),
			got = cats(entry.got),
			gaveDecor = pieces(entry.gaveDecor),
			gotDecor = pieces(entry.gotDecor),
			gaveCrates = logCrates(entry.gaveCrates),
			gotCrates = logCrates(entry.gotCrates),
			gaveFish = TradeLogic.fishOf({ fish = entry.gaveFish }),
			gotFish = TradeLogic.fishOf({ fish = entry.gotFish }),
		})
	end
	return rows
end

return TradeLogic
