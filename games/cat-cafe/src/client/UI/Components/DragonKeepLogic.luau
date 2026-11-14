--!strict
-- #4062 Dragon Keep window (Design-Agent/notes/ticket-booth-and-dragon-keep.md section 2, the station menus picture Derek
-- OK'd 2026-11-14 00:43 UTC): what the window shows from PlayerState.dragon and the player's cats. Pure apart from the
-- shared modules it reads (DragonKeep, Catalog), so the specs check it.
--   title(view) -> string                     "Cinder · Drake", "Cinder · Egg" before the first stage
--   warmth(view) -> (string, number)          "1,480 / 2,500 warmth" and the bar's 0 to 1
--   slots(view) -> { Slot }                   the five slots: a card, empty or "Stage 4" locked
--   setsLine(view) -> string                  "Sets: Flame 2/3 · Wing 1/3", or how sets work
--   oddsLine(odds) -> string                  "Card odds: Common 45% · Rare 30% · ..."
--   binder(view) -> { Entry }                 every card in family order, owned or not, with its slot
--   candidates(cats, busy) -> { Candidate }   the cats that may move in, weakest first
--   quick(candidates, kind) -> { string }     the "Spare Commons" and "Repeats" picks
--   picked(candidates, set) -> (count, warmth, special)
--   FAMILY_NAMES, FAMILY_COLOURS, FAMILY_ICONS

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local DragonKeep = require(Shared:WaitForChild("DragonKeep")) :: any

local DragonKeepLogic = {}

DragonKeepLogic.NAME = "Cinder"
DragonKeepLogic.SLOTS = 5
DragonKeepLogic.FAMILIES = { "flame", "claw", "wing", "hoard", "heart", "crown" }
DragonKeepLogic.FAMILY_NAMES = {
	flame = "Flame",
	claw = "Claw",
	wing = "Wing",
	hoard = "Hoard",
	heart = "Heart",
	crown = "Crown",
} :: { [string]: string }
DragonKeepLogic.FAMILY_ICONS = {
	flame = "🔥",
	claw = "🐾",
	wing = "🪽",
	hoard = "💰",
	heart = "💖",
	crown = "👑",
} :: { [string]: string }
DragonKeepLogic.FAMILY_COLOURS = {
	flame = Color3.fromHex("F07A3A"),
	claw = Color3.fromHex("8C9AB0"),
	wing = Color3.fromHex("4DB8E8"),
	hoard = Color3.fromHex("E8B23A"),
	heart = Color3.fromHex("EE6FA8"),
	crown = Color3.fromHex("9A6BE0"),
} :: { [string]: Color3 }
DragonKeepLogic.MOST_SHOWN = 60 -- cat tiles in the give picker at most (the weakest first); the quick buttons reach all

local function commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local grouped, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		text = grouped
		if count == 0 then
			return text
		end
	end
end
DragonKeepLogic.commas = commas

function DragonKeepLogic.title(view: any): string
	local stage = if view ~= nil then view.stageName else nil
	return DragonKeepLogic.NAME .. " · " .. (if type(stage) == "string" then stage else "Egg")
end

function DragonKeepLogic.warmth(view: any): (string, number)
	if view == nil then
		return "", 0
	end
	local nextAt = math.max(view.nextAt or 0, 1)
	-- the bar runs from the stage reached (or the last Rekindle) to the next mark
	local from = 0
	local stage = view.stage or 0
	if stage >= 1 and stage < DragonKeep.MAX_STAGE then
		from = DragonKeep.STAGES[stage].warmth
	elseif stage >= DragonKeep.MAX_STAGE then
		from = nextAt - DragonKeep.REKINDLE
	end
	local share = math.clamp((view.warmth - from) / math.max(nextAt - from, 1), 0, 1)
	return ("%s / %s warmth"):format(commas(view.warmth), commas(nextAt)), share
end

export type Slot = { index: number, card: string?, locked: boolean, label: string }

function DragonKeepLogic.slots(view: any): { Slot }
	local out: { Slot } = {}
	local open = if view ~= nil then view.slots or {} else {}
	for index = 1, DragonKeepLogic.SLOTS do
		if index > #open then
			table.insert(out, { index = index, locked = true, label = "Stage " .. index })
		else
			local id = open[index]
			local card = if id ~= nil and id ~= "" then DragonKeep.card(id) else nil
			table.insert(out, {
				index = index,
				card = if card then id else nil,
				locked = false,
				label = if card then card.name else "Empty",
			})
		end
	end
	return out
end

function DragonKeepLogic.setsLine(view: any): string
	local counts: { [string]: number } = {}
	for _, id in (if view ~= nil then view.slots or {} else {}) do
		local card = if id ~= "" then DragonKeep.card(id) else nil
		if card then
			counts[card.family] = (counts[card.family] or 0) + 1
		end
	end
	local parts: { string } = {}
	for _, family in DragonKeepLogic.FAMILIES do
		if counts[family] and DragonKeep.SETS[family] ~= nil then
			table.insert(
				parts,
				("%s %d/%d"):format(
					DragonKeepLogic.FAMILY_NAMES[family],
					math.min(counts[family], DragonKeep.SET_SIZE),
					DragonKeep.SET_SIZE
				)
			)
		end
	end
	if #parts == 0 then
		return "3 cards of one family in your slots light a set bonus"
	end
	return "Sets: " .. table.concat(parts, " · ")
end

function DragonKeepLogic.oddsLine(odds: { [string]: number }?): string
	local parts: { string } = {}
	for _, rarity in DragonKeep.RARITIES do
		local percent = if odds then odds[rarity] else nil
		if percent ~= nil then
			table.insert(parts, ("%s %s%%"):format(rarity, tostring(percent)))
		end
	end
	return "Card odds: " .. table.concat(parts, " · ")
end

export type Entry = {
	id: string,
	name: string,
	family: string,
	rarity: string,
	text: string,
	owned: boolean,
	slot: number?,
}

function DragonKeepLogic.binder(view: any): { Entry }
	local owned = if view ~= nil then view.binder or {} else {}
	local slots = if view ~= nil then view.slots or {} else {}
	local out: { Entry } = {}
	for _, family in DragonKeepLogic.FAMILIES do
		for _, card in DragonKeep.CARDS do
			if card.family == family then
				table.insert(out, {
					id = card.id,
					name = card.name,
					family = card.family,
					rarity = card.rarity,
					text = card.text,
					owned = owned[card.id] == true,
					slot = table.find(slots, card.id),
				})
			end
		end
	end
	return out
end

function DragonKeepLogic.ownedCount(view: any): number
	local count = 0
	for _, value in (if view ~= nil then view.binder or {} else {}) do
		if value == true then
			count += 1
		end
	end
	return count
end

export type Candidate = {
	uid: string,
	catId: string,
	name: string,
	rarity: string,
	variant: string?,
	warmth: number,
	special: boolean, -- gold, rainbow or Legendary and better: asks once
	working: boolean,
	spare: boolean, -- not the last copy of its cat
	copies: number, -- copies of its cat the player has, locked and busy ones too (as the server counts)
	instance: any,
}

-- The cats that may move in: not locked, not at the spa or waiting on a new trait (`busy` uids), weakest first.
-- Working cats may (they leave their role); the quick picks skip them.
function DragonKeepLogic.candidates(
	cats: { [string]: any }?,
	busy: { [string]: boolean }?
): { Candidate }
	local copies: { [string]: number } = {}
	for _, instance in cats or {} do
		copies[instance.catId] = (copies[instance.catId] or 0) + 1
	end
	local out: { Candidate } = {}
	for uid, instance in cats or {} do
		if instance.locked == true or (busy and busy[uid]) then
			continue
		end
		local def = Catalog.getCat(instance.catId)
		if def == nil then
			continue
		end
		table.insert(out, {
			uid = uid,
			catId = instance.catId,
			name = def.name,
			rarity = def.rarity,
			variant = instance.variant,
			warmth = DragonKeep.warmthOf(instance),
			special = DragonKeep.special(instance),
			working = instance.spotId ~= nil,
			spare = (copies[instance.catId] or 0) > 1,
			copies = copies[instance.catId] or 0,
			instance = instance,
		})
	end
	table.sort(out, function(a: Candidate, b: Candidate): boolean
		if a.warmth ~= b.warmth then
			return a.warmth < b.warmth
		end
		if a.catId ~= b.catId then
			return a.catId < b.catId
		end
		return a.uid < b.uid
	end)
	return out
end

-- "commons": every spare Common; "repeats": every copy past the first of its cat. Both skip working and special cats
-- and keep one copy of each cat (as DragonKeep.quickPlan on the server). Never all the player's cats.
function DragonKeepLogic.quick(list: { Candidate }, kind: string, total: number): { string }
	local kept: { [string]: number } = {}
	local out: { string } = {}
	for _, cand in list do
		if cand.working or cand.special or not cand.spare then
			continue
		end
		if kind == "commons" and cand.rarity ~= "Common" then
			continue
		end
		-- the last copy stays (at most copies - 1 go, as the server's quickPlan); list is weakest first
		local used = kept[cand.catId] or 0
		if used >= cand.copies - 1 then
			continue
		end
		kept[cand.catId] = used + 1
		if #out >= math.min(DragonKeep.GIVE_MAX, total - 1) then
			break
		end
		table.insert(out, cand.uid)
	end
	return out
end

function DragonKeepLogic.picked(
	list: { Candidate },
	set: { [string]: boolean }
): (number, number, number)
	local count, warmth, special = 0, 0, 0
	for _, cand in list do
		if set[cand.uid] then
			count += 1
			warmth += cand.warmth
			if cand.special then
				special += 1
			end
		end
	end
	return count, warmth, special
end

-- The give button's words: "Move 12 cats in · +18 warmth", or the special cats' ask.
function DragonKeepLogic.giveText(
	count: number,
	warmth: number,
	special: number,
	asking: boolean
): string
	if count == 0 then
		return "Pick cats to move in"
	end
	if asking and special > 0 then
		return if special == 1
			then "Tap again: 1 special cat moves in"
			else ("Tap again: %d special cats move in"):format(special)
	end
	return ("Move %d cat%s in · +%s warmth"):format(
		count,
		if count == 1 then "" else "s",
		commas(warmth)
	)
end

return DragonKeepLogic
