--!strict
-- #4251 Harvest Hollow, the save and the rules the server checks (harvest-hollow-spec sections 3 to 5). Pure: no
-- services, so the cloud specs read it. shared/HarvestHollow (Design-Agent) holds the Stall's items and dates.
--   fresh() / sanitize(raw)            profile.harvest (save version 50): pumpkins, Stall items bought, the last day
--                                      the arch's +10 was given, whether this player caught a harvest cat (Feast Pie)
--   areaBlocker(now, tier, flagOn)     why the area is shut for this player, or nil
--   buyBlocker(save, id, now, tier, flagOn) why a Stall buy is refused, or nil
--   buy(save, id)                      spends the pumpkins and marks the item bought (after buyBlocker said nil)
--   give(save, n)                      adds pumpkins, capped at MAX_PUMPKINS; returns what was added
--   visit(save, now)                   the first visit of the UTC day: +VISIT_PUMPKINS once a day; returns it or 0
--   catchPumpkins(rarity)              pumpkins for a harvest cat caught (Common 1 to Mythical 10)
--   regrowSeconds(playersNear)         a picked patch spot's regrow time: 90 s, 45 s with BUSY_PLAYERS or more near
--   forClient(save)                    PlayerState.harvest
-- Fixed prices, nothing random, nothing sold for Robux. Nothing owned is taken away when the area closes.

local HarvestHollow = require(script.Parent.HarvestHollow)

local HarvestSave = {}

export type Save = {
	pumpkins: number,
	bought: { [string]: boolean },
	visitDay: number, -- the UTC day (os.time // 86400) of the last arch +10; 0 for never
	helped: boolean, -- caught at least one harvest cat (the Feast Pie reward goes to everyone who helped)
}

HarvestSave.FLAG = "harvestHollow" -- a kill switch, on by default; the dates in HarvestHollow open and close the area
HarvestSave.MAX_PUMPKINS = 100000
HarvestSave.VISIT_PUMPKINS = 10
HarvestSave.REGROW_SECONDS = 90
HarvestSave.BUSY_REGROW_SECONDS = 45
HarvestSave.BUSY_PLAYERS = 6
HarvestSave.DAY = 86400

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
	return { pumpkins = 0, bought = {}, visitDay = 0, helped = false }
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
}
function HarvestSave.forClient(save: Save): ForClient
	return { pumpkins = save.pumpkins, bought = table.clone(save.bought), helped = save.helped }
end

return HarvestSave
