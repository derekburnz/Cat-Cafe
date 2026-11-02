--!strict
-- Trading on the UI (F102, trading.md sections 2 and 3), pure so the cloud spec runner checks it. The server holds the
-- trade (TradeState through UI.trade.state); these say what the trade window, the request card and the players list
-- show, and which buttons can be pressed.
--   minTier(attribute) -> number         the live minimum tier: Workspace's TradeMinTier, else Config, else 3
--   shown(tier, minTier) -> boolean      the HUD's Trade tile shows from that tier
--   askTitle(name) -> string             the request card: "Sam wants to trade"
--   rate(n, forMe) -> string             a card's earnings, short: "$24/s" on your cats, "+$1.2K/s" on theirs
--   compact(n) -> string                 950, 1.2K, 12K, 1.5M (cut down)
--   totals(state) -> (give, get)         "Your cats: $180/s now", "Their cats: +$240/s in your cafe"
--   headline(state, now) -> string       the window's subtitle for each phase
--   countdown(state, now) -> number?     the big number while both are ready
--   readyButton(state) -> ButtonView     Ready, Not ready, or Ready greyed with both offers empty
--   warning(state) -> string?            the confirm screen's red line: a gift or a lopsided trade
--   confirmButton(state, shownFor)       Confirm, "Confirm (2)" for the first CONFIRM_WAIT seconds of a warning, or
--                                        "Waiting for Sam" once pressed
--   changed(state, now) -> Changed?      the tile that changed in the last CHANGED_SECONDS, for the yellow flash
--   myCats(cats, defOf, offered) -> { Pick }   your cats under the grids: rarest first, each with why it cannot go
--   pickHint(pick, full) -> string?      "Unlock it on its card to trade", "This cat can't be traded", ...
--   playerButton(row, minTier) -> ButtonView   a players list row: Trade, Asked (for REASK_SECONDS), Busy or
--                                        "Tier 3 needed"
--   doneLine(got) -> string              "Trade done! 2 new cats"

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
TradeLogic.CONFIRM_WAIT = 2 -- Confirm stays off this long on a gift or a lopsided trade
TradeLogic.MAX_CATS = (Config.TradeMaxCats or 9) :: number
TradeLogic.REQUEST_SECONDS = (Config.TradeRequestSeconds or 20) :: number
-- a declined or lapsed ask cannot be repeated this long, so a players row says "Asked" for it (review N332)
TradeLogic.REASK_SECONDS = (Config.TradeReaskSeconds or 60) :: number

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
	local empty = #state.me.cats == 0 and #state.them.cats == 0
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

-- `shownFor` is how long the confirm screen has been up, in seconds.
function TradeLogic.confirmButton(state: any, shownFor: number): ButtonView
	if state.me.confirmed then
		return {
			text = string.format("Waiting for %s", state.them.name),
			enabled = false,
			style = "primary",
		}
	end
	local wait = math.ceil(TradeLogic.CONFIRM_WAIT - shownFor)
	if TradeLogic.warning(state) ~= nil and wait > 0 then
		return { text = string.format("Confirm (%d)", wait), enabled = false, style = "danger" }
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

local function before(a: Pick, b: Pick): boolean
	local sa, sb = STATUS_ORDER[a.status], STATUS_ORDER[b.status]
	if sa ~= sb then
		return sa < sb
	end
	local ra, rb = RANK[a.rarity] or 0, RANK[b.rarity] or 0
	if ra ~= rb then
		return ra > rb
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

function TradeLogic.doneLine(got: { any }?): string
	local count = if got then #got else 0
	if count == 0 then
		return "Trade done!"
	end
	return string.format("Trade done! %d new %s", count, if count == 1 then "cat" else "cats")
end

return TradeLogic
