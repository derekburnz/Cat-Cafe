--!strict
-- #4249 (Derek 2026-11-14: "replace the feedback button with a mailbox so I can give rewards to players as a thanks
-- for playing and give aways through mailbox instead there where they can claim them"): the pure half of the
-- Mailbox (Screens/Mailbox, the HUD's Mailbox tile). The server sends this player's letters in state.mail, newest
-- first, already filtered to them; this module says which wait to be claimed, how each card reads and the gift's
-- words. No instances here, so the spec can check it.
--   MailLogic.waiting(mail, now)        how many letters wait to be claimed (the tile's red number)
--   MailLogic.rows(mail, now, names)    the window's cards: waiting letters first, then claimed ones
--   MailLogic.gift(prize, names)        the gift chip: its glyph and words, and the odds line when it holds crates
--   MailLogic.ends(endsAt, now)         "ends in 3 days" and so on, or nil without an end

local MailLogic = {}

MailLogic.FLAG = "mailbox" -- shared/LiveFlags: off keeps the Feedback tile
MailLogic.FROM = "Derek" -- a letter without its own `from`
MailLogic.EMPTY = "No letters yet. Gifts from Derek land here."
MailLogic.SUBTITLE = "Gifts from the Catch a Cat Cafe team"
MailLogic.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

-- The server's prize shape (shared/Types IndexPrize, paid through Payout); the Mailbox words these kinds.
export type Prize = {
	coins: number?,
	coinSeconds: number?, -- pays max(coins, floor(day rate x coinSeconds))
	fish: number?, -- golden fish
	crates: { [string]: number }?, -- crate id (or "highest_golden") to count
	potions: { [string]: number }?, -- potion id to count
	spins: number?,
	lures: { [string]: number }?, -- bait id to count
	catFood: { [string]: number }?, -- food id to count
	traitTokens: number?,
}

export type Letter = {
	id: string,
	title: string,
	note: string,
	from: string?, -- "Derek" or "Catch a Cat Cafe"
	sentAt: number,
	endsAt: number?,
	prize: Prize,
	claimed: boolean,
}

-- What the window needs to name things: a crate's name and its odds by rarity, a potion's, a bait's and a cat food's
-- name, and the player's day rate for a `coinSeconds` prize. Each may answer nil, and the words fall back to the
-- plain kind.
export type Names = {
	crate: ((id: string) -> (string?, { [string]: number }?))?,
	potion: ((id: string) -> string?)?,
	lure: ((id: string) -> string?)?,
	food: ((id: string) -> string?)?,
	rate: number?,
}

export type Gift = {
	glyph: string,
	text: string,
	odds: string?, -- "Odds: Epic 70%, Legendary 24%, Mythical 6%" for a letter with crates
}

export type Row = {
	id: string,
	title: string,
	note: string,
	from: string, -- "From Derek · ends in 3 days"
	gift: Gift,
	claimed: boolean,
}

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local function plural(count: number, name: string): string
	if count == 1 then
		return "1 " .. name
	end
	local many = if name:sub(-1) == "h" then name else name .. "s" -- "Golden Fish" stays
	return commas(count) .. " " .. many
end

-- True while a letter can still be claimed: not claimed and not past its end.
function MailLogic.open(letter: Letter, now: number): boolean
	if letter.claimed then
		return false
	end
	local endsAt = letter.endsAt
	return endsAt == nil or now < endsAt
end

function MailLogic.waiting(mail: { Letter }?, now: number): number
	local count = 0
	for _, letter in (mail or {}) :: { Letter } do
		if MailLogic.open(letter, now) then
			count += 1
		end
	end
	return count
end

-- "ends in 3 days", "ends in 5 h", "ends in 12 min", "ended"; nil without an end.
function MailLogic.ends(endsAt: number?, now: number): string?
	if endsAt == nil then
		return nil
	end
	local left = endsAt - now
	if left <= 0 then
		return "ended"
	elseif left >= 2 * 86400 then
		return ("ends in %d days"):format(math.floor(left / 86400))
	elseif left >= 3600 then
		return ("ends in %d h"):format(math.floor(left / 3600))
	end
	return ("ends in %d min"):format(math.max(1, math.floor(left / 60)))
end

-- "Odds: Epic 70%, Legendary 24%, Mythical 6%", rarities in order, none at 0.
function MailLogic.oddsLine(odds: { [string]: number }): string?
	local parts: { string } = {}
	for _, rarity in MailLogic.RARITY_ORDER do
		local share = odds[rarity]
		if share ~= nil and share > 0 then
			table.insert(
				parts,
				("%s %s%%"):format(rarity, tostring(math.floor(share * 10 + 0.5) / 10))
			)
		end
	end
	return if #parts > 0 then "Odds: " .. table.concat(parts, ", ") else nil
end

local function sortedKeys(map: { [string]: number }): { string }
	local keys: { string } = {}
	for key, count in map do
		if count > 0 then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

-- The gift chip: the first part's glyph and every part's words, "250 Golden Fish + 3 Golden Crates".
function MailLogic.gift(prize: Prize, names: Names?): Gift
	local parts: { string } = {}
	local glyph: string? = nil
	local odds: string? = nil
	local function add(mark: string, words: string)
		glyph = glyph or mark
		table.insert(parts, words)
	end
	local fish = prize.fish
	if fish and fish > 0 then
		add("🐟", plural(fish, "Golden Fish"))
	end
	local coins = prize.coins or 0
	local rate = names and names.rate
	if prize.coinSeconds and rate then
		coins = math.max(coins, math.floor(rate * prize.coinSeconds))
	end
	if coins > 0 then
		add("🪙", commas(coins) .. " coins")
	end
	local spins = prize.spins
	if spins and spins > 0 then
		add("🎡", plural(spins, "free spin"))
	end
	local tokens = prize.traitTokens
	if tokens and tokens > 0 then
		add("🎟️", plural(tokens, "Trait Token"))
	end
	local crateName = names and names.crate
	for _, id in sortedKeys(prize.crates or {}) do
		local count = (prize.crates :: { [string]: number })[id]
		local name, crateOdds = nil, nil
		if crateName then
			name, crateOdds = crateName(id)
		end
		add("📦", plural(count, name or (if id:find("golden") then "Golden Crate" else "Crate")))
		if odds == nil and crateOdds ~= nil then
			odds = MailLogic.oddsLine(crateOdds)
		end
	end
	local potionName = names and names.potion
	for _, id in sortedKeys(prize.potions or {}) do
		local count = (prize.potions :: { [string]: number })[id]
		local name = if potionName then potionName(id) else nil
		add("🧪", plural(count, name or "Potion"))
	end
	for _, kind in
		{
			{ key = "lures", glyph = "🥣", fallback = "bait" },
			{ key = "catFood", glyph = "🍖", fallback = "cat food" },
		}
	do
		local map: { [string]: number } = (prize :: any)[kind.key] or {}
		local namer: ((id: string) -> string?)? = if names == nil
			then nil
			elseif kind.key == "lures" then names.lure
			else names.food
		for _, id in sortedKeys(map) do
			local name = if namer then namer(id) else nil
			add(kind.glyph, ("%s %s"):format(commas(map[id]), name or kind.fallback)) -- "5 Kibble": foods stay singular
		end
	end
	return {
		glyph = glyph or "🎁",
		text = if #parts > 0 then table.concat(parts, " + ") else "A thank you",
		odds = odds,
	}
end

-- The window's cards: letters still to claim first, then the claimed ones, each newest first. A letter that ended
-- unclaimed is left out (it can no longer be claimed).
function MailLogic.rows(mail: { Letter }?, now: number, names: Names?): { Row }
	local waiting: { Letter } = {}
	local claimed: { Letter } = {}
	for _, letter in (mail or {}) :: { Letter } do
		if letter.claimed then
			table.insert(claimed, letter)
		elseif MailLogic.open(letter, now) then
			table.insert(waiting, letter)
		end
	end
	local function newest(a: Letter, b: Letter): boolean
		if a.sentAt ~= b.sentAt then
			return a.sentAt > b.sentAt
		end
		return a.id < b.id
	end
	table.sort(waiting, newest)
	table.sort(claimed, newest)
	local rows: { Row } = {}
	for _, list in { waiting, claimed } do
		for _, letter in list do
			local ends = if letter.claimed then nil else MailLogic.ends(letter.endsAt, now)
			table.insert(rows, {
				id = letter.id,
				title = letter.title,
				note = letter.note,
				from = "From " .. (letter.from or MailLogic.FROM) .. (if ends
					then " · " .. ends
					else ""),
				gift = MailLogic.gift(letter.prize, names),
				claimed = letter.claimed,
			})
		end
	end
	return rows
end

return MailLogic
