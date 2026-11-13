--!strict
-- The Mystic Pool on the UI (#3196, #3314, trait-station.md sections 1 and 3). Pure, so the cloud spec runner checks
-- it. The rules are the server's (shared/Traits, TraitService); this shapes PlayerState.traits and the player's cats
-- for the card:
--   card(trait)                 a trait's card: its name, rarity name and colour and one line per effect; a plain
--                               "No trait yet" card for none
--   roll(view, hasTrait, fish)  the Roll button: its words ("Free roll (5 left)", "Re-roll · 1 Trait Token",
--                               "Roll · 10 golden fish") and whether the player can pay; nothing rolls while a
--                               re-roll waits for Keep old or Take new
--   pending(view, cats)         the waiting re-roll: its cat, the old card and the new one side by side
--   haveLine(view, fish)        "5 free rolls · 2 Trait Tokens · 34 golden fish" (free rolls only while any are left)
--   tokens(view, now)           the station's free tokens: "1 Trait Token ready" with Collect, or "Next free token in
--                               3h 12m"
--   odds()                      the Odds list: one row per rarity with its colour and percent, and the line under it
--   ODDS_LINE, ODDS_LINES       the odds line every card shows (Traits.oddsText), whole and as two short lines
--   cats(cats)                  the picker's list: working cats first (only their traits count), then the highest
--                               level, best rate and uid
--   key(list)                   changes when the list's rows would (a level, a name, a trait, a job)
--   stamp(view, fish, trait)    changes when the server has answered a press (a payment, a trait, a waiting re-roll,
--                               a collected token), so the buttons wake
--   rolled(view, uid, hadTrait, trait)  the trait id a roll on `uid` gave, once the state shows it: the waiting
--                               re-roll, or a first trait
--   rarityId(traitId)           "rare", for the pool's colour (Effects/MysticPool.roll)
-- Button words stay neutral ("Roll again" is never "so close"), for a young audience (spec section 1a).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traits = require(Shared:WaitForChild("Traits")) :: any

local MysticPoolLogic = {}

MysticPoolLogic.WINDOW = "MysticPool"
MysticPoolLogic.NO_TRAIT = "No trait yet"
MysticPoolLogic.NO_TRAIT_COLOR = "#9AA0A6"
MysticPoolLogic.KEEP_OLD = "Keep old"
MysticPoolLogic.TAKE_NEW = "Take new"
MysticPoolLogic.EQUAL_LINE = "Each trait inside a rarity is equally likely."
MysticPoolLogic.ODDS_LINE = Traits.oddsText() :: string
-- The same words as two short lines, for a narrow card: the rarity odds, then "Each trait inside a rarity ...".
MysticPoolLogic.ODDS_LINES = (function(): { string }
	local line: string = Traits.oddsText()
	local cut = string.find(line, ". ", 1, true)
	if cut == nil then
		return { line, "" }
	end
	return { string.sub(line, 1, cut - 1), string.sub(line, cut + 2) }
end)()

export type Card = {
	has: boolean,
	name: string, -- "Big Tipper", or "No trait yet"
	rarity: string, -- "Rare", or "" for none
	color: string, -- hex with its "#"
	lines: { string }, -- "+12% this cat's income"
}

export type Roll = { text: string, enabled: boolean, why: string? }

export type Pending = { uid: string, old: Card, new: Card }

export type OddsRow = { name: string, color: string, percent: number }

-- What the card reads from PlayerState.traits (Types.TraitsView); every field checked, as it crosses the network.
type View = {
	tokens: number?,
	freeLeft: number?,
	held: number?,
	nextAt: number?,
	pending: { uid: string?, id: string? }?,
	bundles: boolean?, -- #3864: the server's word that the token bundles may be offered
}

local function whole(value: any): number
	return if type(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
end

local function plural(count: number, one: string, many: string): string
	return string.format("%d %s", count, if count == 1 then one else many)
end

-- "3h 12m", "12m", "45s": time left, rounded up to the unit shown so it never reads 0.
local function span(seconds: number): string
	local left = math.max(1, math.ceil(seconds))
	if left >= 3600 then
		local minutes = math.ceil(left / 60)
		return string.format("%dh %02dm", minutes // 60, minutes % 60)
	elseif left >= 60 then
		return string.format("%dm", math.ceil(left / 60))
	end
	return string.format("%ds", left)
end

function MysticPoolLogic.card(trait: any): Card
	local def: any = nil
	if type(trait) == "table" and type(trait.id) == "string" then
		def = Traits.get(trait.id)
	end
	if def == nil then
		return {
			has = false,
			name = MysticPoolLogic.NO_TRAIT,
			rarity = "",
			color = MysticPoolLogic.NO_TRAIT_COLOR,
			lines = {},
		}
	end
	return {
		has = true,
		name = def.name,
		rarity = def.rarity.name,
		color = def.rarity.color,
		lines = Traits.effectLines(trait),
	}
end

-- The Roll button for the picked cat. `fish` is the player's golden fish.
function MysticPoolLogic.roll(view: View?, hasTrait: boolean, fish: number): Roll
	if view == nil then
		return { text = "Roll", enabled = false, why = "The Mystic Pool is closed for now" }
	end
	local freeLeft = math.min(whole(view.freeLeft), Traits.FREE_ROLLS)
	local tokens = whole(view.tokens)
	local text = Traits.rollText(Traits.FREE_ROLLS - freeLeft, tokens, hasTrait)
	if view.pending ~= nil then
		return { text = text, enabled = false, why = "Pick Keep old or Take new first" }
	end
	if Traits.payment(Traits.FREE_ROLLS - freeLeft, tokens, whole(fish)) == nil then
		return {
			text = text,
			enabled = false,
			why = string.format("You need a Trait Token or %d golden fish", Traits.COST_FISH),
		}
	end
	return { text = text, enabled = true }
end

-- The re-roll waiting for its choice, or nil. `cats` maps uid to the cat (its `trait` is the old one). A cat that
-- is gone (traded away since) still gets its two cards, so the player can clear the choice.
function MysticPoolLogic.pending(view: View?, cats: { [string]: any }): Pending?
	local waiting = if view ~= nil then view.pending else nil
	if
		type(waiting) ~= "table"
		or type(waiting.uid) ~= "string"
		or type(waiting.id) ~= "string"
	then
		return nil
	end
	local cat = cats[waiting.uid]
	return {
		uid = waiting.uid,
		old = MysticPoolLogic.card(if type(cat) == "table" then cat.trait else nil),
		new = MysticPoolLogic.card({ id = waiting.id }),
	}
end

function MysticPoolLogic.haveLine(view: View?, fish: number): string
	local parts: { string } = {}
	local freeLeft = if view ~= nil then whole(view.freeLeft) else 0
	if freeLeft > 0 then
		table.insert(parts, plural(freeLeft, "free roll", "free rolls"))
	end
	table.insert(
		parts,
		plural(if view ~= nil then whole(view.tokens) else 0, "Trait Token", "Trait Tokens")
	)
	table.insert(parts, string.format("%d golden fish", whole(fish)))
	return table.concat(parts, " · ")
end

-- #3196: the Mystic Pool's strip on the Park's card in the Cat Cannon's menu (Screens/Cannon), in the shape of a
-- camp extra's line: its Open button brings the card up from anywhere. nil while the pool is shut. Free tokens
-- waiting at the station read in green, as a station with something to collect does.
-- #3715: the pool stands in the Town Square now, where the cannon is, so no area's card carries its strip: AREA is
-- no area's id (a camp cannon's Town Square card is "town", and must not open the pool from anywhere)
MysticPoolLogic.AREA = ""
MysticPoolLogic.STATION = "mysticPool"
MysticPoolLogic.ICON = "🔮"

function MysticPoolLogic.pickerLine(
	view: View?,
	areaId: string
): {
	extraId: string,
	icon: string,
	name: string,
	state: string,
	ready: boolean,
}?
	if view == nil or areaId ~= MysticPoolLogic.AREA then
		return nil
	end
	local held = view.held or 0
	local free = view.freeLeft or 0
	local words = if held > 0
		then string.format("%d free token%s", held, if held == 1 then "" else "s")
		elseif free > 0 then string.format(
			"%d free roll%s",
			free,
			if free == 1 then "" else "s"
		)
		else "Give a cat a trait"
	return {
		extraId = MysticPoolLogic.STATION,
		icon = MysticPoolLogic.ICON,
		name = Traits.NAME,
		state = words,
		ready = held > 0,
	}
end

-- #3936: whether the red "!" hangs over the pool (Components/PoolBang): a free roll left, a Trait Token banked or
-- free tokens waiting at the station, and no Keep old / Take new choice waiting. False while the pool is shut.
function MysticPoolLogic.bangShows(view: View?): boolean
	if view == nil or view.pending ~= nil then
		return false
	end
	return whole(view.freeLeft) > 0 or whole(view.tokens) > 0 or whole(view.held) > 0
end

-- The station's free tokens: the line, and whether Collect has something to take. `now` is the server's time.
function MysticPoolLogic.tokens(view: View?, now: number): (string, boolean)
	if view == nil then
		return "", false
	end
	local held = whole(view.held)
	if held > 0 then
		return plural(held, "Trait Token", "Trait Tokens") .. " ready", true
	end
	local nextAt = view.nextAt
	if type(nextAt) == "number" and nextAt > now then
		return "Next free token in " .. span(nextAt - now), false
	end
	return "Next free token soon", false
end

function MysticPoolLogic.odds(): { OddsRow }
	local rows: { OddsRow } = {}
	for _, rarity in Traits.RARITIES do
		table.insert(rows, { name = rarity.name, color = rarity.color, percent = rarity.odds })
	end
	return rows
end

-- The picker's cats. `cats` is PlayerState.cats (uid -> cat).
function MysticPoolLogic.cats(cats: { [string]: any }?): { any }
	local out: { any } = {}
	if cats == nil then
		return out
	end
	for _, cat in cats do
		if type(cat) == "table" and type(cat.uid) == "string" then
			table.insert(out, cat)
		end
	end
	table.sort(out, function(a: any, b: any): boolean
		local aWorks, bWorks = a.spotId ~= nil, b.spotId ~= nil
		if aWorks ~= bWorks then
			return aWorks
		end
		local aLevel, bLevel = whole(a.level), whole(b.level)
		if aLevel ~= bLevel then
			return aLevel > bLevel
		end
		local aRate: number = if type(a.rating) == "number" then a.rating else 0
		local bRate: number = if type(b.rating) == "number" then b.rating else 0
		if aRate ~= bRate then
			return aRate > bRate
		end
		return a.uid < b.uid
	end)
	return out
end

local function traitId(trait: any): string
	return if type(trait) == "table" and type(trait.id) == "string" then trait.id else ""
end

function MysticPoolLogic.key(list: { any }): string
	local parts = table.create(#list)
	for index, cat in list do
		local job: string = if cat.spotId ~= nil then "w" else "r"
		parts[index] = string.format(
			"%s:%d:%s:%s:%s:%s",
			tostring(cat.uid),
			whole(cat.level),
			tostring(cat.variant),
			job,
			tostring(cat.name),
			traitId(cat.trait)
		)
	end
	return table.concat(parts, "|")
end

function MysticPoolLogic.stamp(view: View?, fish: number, trait: any): string
	if view == nil then
		return "shut"
	end
	local waiting = view.pending
	local waitingKey: string = if type(waiting) == "table"
		then tostring(waiting.uid) .. "=" .. tostring(waiting.id)
		else ""
	return string.format(
		"%d:%d:%d:%d:%s:%s",
		whole(view.tokens),
		whole(view.freeLeft),
		whole(view.held),
		whole(fish),
		waitingKey,
		traitId(trait)
	)
end

function MysticPoolLogic.rolled(view: View?, uid: string, hadTrait: boolean, trait: any): string?
	local waiting = if view ~= nil then view.pending else nil
	if type(waiting) == "table" and waiting.uid == uid and type(waiting.id) == "string" then
		return if Traits.get(waiting.id) ~= nil then waiting.id else nil
	end
	local id = traitId(trait)
	if not hadTrait and id ~= "" and Traits.get(id) ~= nil then
		return id
	end
	return nil
end

function MysticPoolLogic.rarityId(id: string): string
	local def: any = Traits.get(id)
	return if def ~= nil then def.rarity.id else Traits.RARITIES[1].id
end

-- #3864 (Derek 2026-11-13): the Trait Token bundles, offered on the card once the free rolls are used. A roll from a
-- bought token is a paid random item (monetization-policy section 2), so the offer carries the full odds, plain words
-- and a "No thanks" that holds for the session; it never shows unless the server says `bundles` (the traitBundles
-- switch on and the player's policy read and not restricting paid random items).
MysticPoolLogic.OFFER_TITLE = "More rolls with Trait Tokens"
MysticPoolLogic.OFFER_LINE =
	"One Trait Token is one roll. A cat never gets worse: keep the old trait or take the new."
MysticPoolLogic.OFFER_NO = "No thanks"

export type Bundle = { product: string, id: number, label: string }

-- The bundles to offer now, or nil: `view` the card's numbers, `ids` Config.ProductIds, `seen` true once the offer
-- has shown (or been declined) this session. Only made products (an id) are offered.
function MysticPoolLogic.bundles(view: View?, ids: { [string]: any }?, seen: boolean): { Bundle }?
	if seen or view == nil or view.bundles ~= true or type(ids) ~= "table" then
		return nil
	end
	if whole(view.freeLeft) > 0 or view.pending ~= nil then
		return nil
	end
	local out: { Bundle } = {}
	for _, bundle in Traits.BUNDLES do
		local id = ids[bundle.product]
		if type(id) == "number" and id > 0 then
			table.insert(out, {
				product = bundle.product,
				id = id,
				label = string.format("%d Tokens · R$%d", bundle.tokens, bundle.robux),
			})
		end
	end
	return if #out > 0 then out else nil
end

return MysticPoolLogic
