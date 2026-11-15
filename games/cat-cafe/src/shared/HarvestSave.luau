--!strict
-- #4251 Harvest Hollow, the save and the rules the server checks (harvest-hollow-spec sections 3 to 5). Pure: no
-- services, so the cloud specs read it. shared/HarvestHollow (Design-Agent) holds the Stall's items and dates.
--   fresh() / sanitize(raw)            profile.harvest (save version 51): pumpkins, Stall items bought, the last day
--                                      the arch's +10 was given, whether this player caught a harvest cat (Feast Pie)
--   areaBlocker(now, tier, flagOn)     why the area is shut for this player, or nil
--   buyBlocker(save, id, now, tier, flagOn) why a Stall buy is refused, or nil
--   buy(save, id)                      spends the pumpkins and marks the item bought (after buyBlocker said nil)
--   give(save, n)                      adds pumpkins, capped at MAX_PUMPKINS; returns what was added
--   visit(save, now)                   the first visit of the UTC day: +VISIT_PUMPKINS once a day; returns it or 0
--   catchPumpkins(rarity)              pumpkins for a harvest cat caught (Common 1 to Mythical 10)
--   regrowSeconds(playersNear)         a picked patch spot's regrow time: 90 s, 45 s with BUSY_PLAYERS or more near
--   forClient(save)                    PlayerState.harvest
--   pieGoal(low) / pieSlices(count, goal) the Feast Pie's goal (PIE_GOAL, or PIE_GOAL_LOW with the harvestPieLow switch
--                                      on) and its slices baked, 0 to PIE_SLICES (spec section 5)
--   NOTES / pinNote(list, userId, note) the Thankful Board's six fixed notes and its last NOTE_KEEP pins (spec section 6)
--   pieRewardDue(save, slices)        whether the full pie's reward is owed: a helper, the pie at PIE_SLICES, not given
--   FEAST_PIE / PIE_REWARD_SPINS      the reward (spec section 5): the Feast Pie decor (pieReward marks it owned) and
--                                      one banked Spin Wheel spin
--   AREA / ODDS / STRAY_CAP / TOPUP_SECONDS the harvest strays (spec 3b): the area id the harvest cats carry, the odds
--                                      shown on the area's card, at most STRAY_CAP out at once, one more every
--                                      TOPUP_SECONDS by day while under it
-- Fixed prices, nothing random, nothing sold for Robux. Nothing owned is taken away when the area closes.

local HarvestHollow = require(script.Parent.HarvestHollow)

local HarvestSave = {}

export type Save = {
	pumpkins: number,
	bought: { [string]: boolean },
	visitDay: number, -- the UTC day (os.time // 86400) of the last arch +10; 0 for never
	helped: boolean, -- caught at least one harvest cat (the Feast Pie reward goes to everyone who helped)
	pieReward: boolean, -- #4251 part 6: got the full Feast Pie's reward (the Feast Pie decor and a banked spin)
}

HarvestSave.FLAG = "harvestHollow" -- a kill switch, on by default; the dates in HarvestHollow open and close the area
HarvestSave.MAX_PUMPKINS = 100000
HarvestSave.VISIT_PUMPKINS = 10
HarvestSave.REGROW_SECONDS = 90
HarvestSave.BUSY_REGROW_SECONDS = 45
HarvestSave.BUSY_PLAYERS = 6
HarvestSave.DAY = 86400

-- #4251 section 5: the Feast Pie, one slice of eight per eighth of the goal. The goal is a server read: the
-- harvestPieLow switch (off by default) drops it to PIE_GOAL_LOW after Growth's first-day read.
HarvestSave.PIE_GOAL = 25000
HarvestSave.PIE_GOAL_LOW = 15000
HarvestSave.PIE_LOW_FLAG = "harvestPieLow"
HarvestSave.PIE_SLICES = 8

-- #4251 section 6: the Thankful Board's fixed notes (no typed text, so nothing to filter) and how many it shows.
HarvestSave.NOTES = table.freeze({
	"Thank you, cats!",
	"Thanks for the pie!",
	"Happy harvest!",
	"Best pumpkin patch ever!",
	"Grateful for friends!",
	"See you next autumn!",
})
HarvestSave.NOTE_KEEP = 12

-- #4251 part 6 (spec section 5): the full pie's reward for everyone who helped, at once or at their next join.
HarvestSave.FEAST_PIE = "feast_pie" -- CatCafe_Decor_FeastPie (Catalog decor "decor_feast_pie"); owned when save.pieReward

-- #4251 part 7: where a Stall item (or the Feast Pie) is owned for good: a decor piece in profile.decorOwned under
-- decorId, a hat as the Looks accessory lookId (the Style tab), read from save.bought (lookItems).
function HarvestSave.decorId(itemId: string): string
	return "decor_" .. itemId
end

function HarvestSave.lookId(itemId: string): string
	return "acc_" .. itemId
end

-- Puts every Stall decor piece bought (and the Feast Pie, with pieReward) into `decorOwned` (profile.decorOwned), so
-- the Decor window lists them. Run on each buy, on the reward and at each join, so a save is always whole. Returns
-- how many it added.
function HarvestSave.grantOwned(save: Save, decorOwned: { [string]: boolean }): number
	local added = 0
	local function give(id: string)
		if decorOwned[id] ~= true then
			decorOwned[id] = true
			added += 1
		end
	end
	for itemId, yes in save.bought do
		local item = if yes then HarvestHollow.item(itemId) else nil
		if item ~= nil and item.kind == "decor" then
			give(HarvestSave.decorId(itemId))
		end
	end
	if save.pieReward then
		give(HarvestSave.decorId(HarvestSave.FEAST_PIE))
	end
	return added
end

-- The items Looks reads for this player (profile.pass.items) with the Stall hats bought added under lookId. A copy;
-- nothing is saved, so the hats stay owned through save.bought alone.
function HarvestSave.lookItems(save: Save, items: { [string]: boolean }): { [string]: boolean }
	local out = table.clone(items)
	for itemId, yes in save.bought do
		local item = if yes then HarvestHollow.item(itemId) else nil
		if item ~= nil and item.kind == "outfit" then
			out[HarvestSave.lookId(itemId)] = true
		end
	end
	return out
end
HarvestSave.PIE_REWARD_SPINS = 1

function HarvestSave.pieRewardDue(save: Save, slices: number): boolean
	return save.helped and not save.pieReward and slices >= HarvestSave.PIE_SLICES
end

-- #4251 (spec 3b): the harvest strays. AREA is the `area` of the eight harvest cats (Catalog.harvestCats). ODDS sum
-- to 100 and are the ones the area's card shows; like the Park's, with a little more at the top, since every harvest
-- cat is kept and the Feast Pie counts each one.
HarvestSave.AREA = "harvest"
HarvestSave.ODDS =
	table.freeze({ Common = 55, Rare = 32, Epic = 9, Legendary = 3.5, Mythical = 0.5 })
HarvestSave.STRAY_CAP = 10 -- of the 14 spots and the nook
HarvestSave.TOPUP_SECONDS = 8

HarvestSave.CATCH_PUMPKINS = table.freeze({
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 5,
	Mythical = 10,
} :: { [string]: number })

local function whole(value: unknown, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value :: number), 0, max)
end

function HarvestSave.fresh(): Save
	return { pumpkins = 0, bought = {}, visitDay = 0, helped = false, pieReward = false }
end

function HarvestSave.sanitize(raw: unknown): Save
	local out = HarvestSave.fresh()
	if type(raw) ~= "table" then
		return out
	end
	local t = raw :: any
	out.pumpkins = whole(t.pumpkins, HarvestSave.MAX_PUMPKINS)
	out.visitDay = whole(t.visitDay, 1e7)
	out.helped = t.helped == true
	out.pieReward = t.pieReward == true
	if type(t.bought) == "table" then
		for id, yes in t.bought do
			if yes == true and HarvestHollow.item(id) ~= nil then
				out.bought[id :: string] = true
			end
		end
	end
	return out
end

function HarvestSave.areaBlocker(now: number, tier: number, flagOn: boolean): string?
	if not flagOn or not HarvestHollow.open(now) then
		return "Harvest Hollow is closed"
	end
	if tier < HarvestHollow.TIER then
		return string.format("Harvest Hollow opens at Tier %d", HarvestHollow.TIER)
	end
	return nil
end

function HarvestSave.buyBlocker(
	save: Save,
	id: string,
	now: number,
	tier: number,
	flagOn: boolean
): string?
	local item = HarvestHollow.item(id)
	if item == nil then
		return "That isn't on the Stall"
	end
	local shut = HarvestSave.areaBlocker(now, tier, flagOn)
	if shut ~= nil then
		return shut
	end
	if save.bought[item.id] == true then
		return "You already have it"
	end
	if save.pumpkins < item.price then
		return string.format("You need %d more pumpkins", item.price - save.pumpkins)
	end
	return nil
end

function HarvestSave.buy(save: Save, id: string): boolean
	local item = HarvestHollow.item(id)
	if item == nil or save.bought[item.id] == true or save.pumpkins < item.price then
		return false
	end
	save.pumpkins -= item.price
	save.bought[item.id] = true
	return true
end

function HarvestSave.give(save: Save, n: number): number
	local before = save.pumpkins
	save.pumpkins = math.min(HarvestSave.MAX_PUMPKINS, before + math.max(0, math.floor(n)))
	return save.pumpkins - before
end

function HarvestSave.visit(save: Save, now: number): number
	local day = math.floor(now / HarvestSave.DAY)
	if save.visitDay == day then
		return 0
	end
	save.visitDay = day
	return HarvestSave.give(save, HarvestSave.VISIT_PUMPKINS)
end

function HarvestSave.pieGoal(low: boolean): number
	return if low then HarvestSave.PIE_GOAL_LOW else HarvestSave.PIE_GOAL
end

function HarvestSave.pieSlices(count: number, goal: number): number
	if goal <= 0 or count ~= count then
		return 0
	end
	return math.clamp(math.floor(count * HarvestSave.PIE_SLICES / goal), 0, HarvestSave.PIE_SLICES)
end

export type Note = { userId: number, note: number }

-- Whether `note` is one of NOTES by its index (1 to 6).
function HarvestSave.validNote(note: unknown): boolean
	return type(note) == "number"
		and note == math.floor(note)
		and note >= 1
		and note <= #HarvestSave.NOTES
end

-- The board's list with this pin added last, the player's own older pin dropped, at most NOTE_KEEP. A copy.
function HarvestSave.pinNote(list: { Note }, userId: number, note: number): { Note }
	local out: { Note } = {}
	for _, row in list do
		if row.userId ~= userId then
			table.insert(out, { userId = row.userId, note = row.note })
		end
	end
	table.insert(out, { userId = userId, note = note })
	while #out > HarvestSave.NOTE_KEEP do
		table.remove(out, 1)
	end
	return out
end

function HarvestSave.catchPumpkins(rarity: string): number
	return HarvestSave.CATCH_PUMPKINS[rarity] or 1
end

function HarvestSave.regrowSeconds(playersNear: number): number
	return if playersNear >= HarvestSave.BUSY_PLAYERS
		then HarvestSave.BUSY_REGROW_SECONDS
		else HarvestSave.REGROW_SECONDS
end

-- PlayerState.harvest (Types.PlayerState): the Feast Pie's `pie` is added by the shared goal's part.
export type ForClient = {
	pumpkins: number,
	bought: { [string]: boolean }?,
	pie: { count: number, goal: number }?,
	helped: boolean?,
	pieReward: boolean?,
}
function HarvestSave.forClient(save: Save): ForClient
	return {
		pumpkins = save.pumpkins,
		bought = table.clone(save.bought),
		helped = save.helped,
		pieReward = save.pieReward,
	}
end

return HarvestSave
