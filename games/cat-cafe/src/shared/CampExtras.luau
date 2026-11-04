--!strict
-- The camp extras (F100, camp-extras.md): one extra thing at each camp from the Park on, opening with its area, so
-- every rank up from Tier 2 to Tier 5 opens one. Pure rules for the server (CampExtraService) and the client (the
-- prompt's lines and the cannon picker's line):
--   Picnic Basket (Park): one PicnicPotion every PicnicEverySeconds, up to PicnicHold.
--   Yard Sale (Neighbourhood): one zone crate a UTC day, free, taken once a day and banked for the Market, which opens
--     it (crate-prices.md section 5, #1051). The crate is the player's open areas' crates in Catalog order picked by
--     the day number, so every server gives the same one.
--   Fish Pond (Woods): PondFishPerStep golden fish every PondStepSeconds, up to PondHold.
--   Lost and Found (Sewer): one prize a UTC day from LostFoundTable, up to LostFoundHold.
-- Each keeps filling while the player is away. An extra whose area is shut does not fill, and the moment it opens one
-- fill waits (a basket, two fish, a prize), so each rank up has something to fetch. Collecting takes everything that
-- waits. Nothing here is sold, sped up or refilled for Robux.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local CampExtras = {}

local DAY = 86400

CampExtras.TAG = "CampExtra" -- the placed models, with attributes ExtraId and Area
CampExtras.PROMPT = "CampExtraPrompt" -- each model's ProximityPrompt, at its PromptAnchor
CampExtras.YARD_SALE = "yardSale"
CampExtras.COLLECT = { "picnic", "pond", "lostFound" } -- what CollectCampExtra takes
CampExtras.CLASSIC_CRATE = "classic_crate"
CampExtras.TAKEN = "You took today's crate. A new one tomorrow"

-- The UTC day number of os.time() `now`.
function CampExtras.day(now: number): number
	return math.floor(now / DAY)
end

-- The tier that opens an extra (its area's), or nil for an unknown id.
function CampExtras.tierOf(extraId: string): number?
	local def = Catalog.getCampExtra(extraId)
	local area = if def ~= nil then Catalog.getArea(def.area) else nil
	return if area ~= nil then area.tier else nil
end

function CampExtras.isOpen(extraId: string, tier: number): boolean
	local need = CampExtras.tierOf(extraId)
	return need ~= nil and tier >= need
end

-- What every shut extra holds at os.time() `now`: one fill short of nothing, so the first fill waits the moment its
-- area opens. A new save starts here.
function CampExtras.fresh(now: number): Types.CampExtrasSave
	local today = CampExtras.day(now)
	return {
		picnic = { at = now - Config.PicnicEverySeconds, held = 0 },
		yardSale = { day = today, bought = {} },
		pond = { at = now - Config.PondStepSeconds },
		lostFound = { day = today - 1, held = 0 },
	}
end

-- A saved value made whole at `now`: whole numbers, no time or day in the future, holds within their caps and only
-- known crates bought (a damaged or future-dated save would otherwise hold an extra shut until real time caught up).
function CampExtras.sanitize(raw: unknown, now: number): Types.CampExtrasSave
	local save = CampExtras.fresh(now)
	if type(raw) ~= "table" then
		return save
	end
	local value = raw :: any
	local today = CampExtras.day(now)
	local function whole(x: unknown, high: number, default: number): number
		if type(x) == "number" and x == x and math.abs(x) < 2 ^ 40 then
			return math.min(math.floor(x), high)
		end
		return default
	end
	if type(value.picnic) == "table" then
		save.picnic.at = whole(value.picnic.at, now, save.picnic.at)
		save.picnic.held = math.max(0, whole(value.picnic.held, Config.PicnicHold, 0))
	end
	if type(value.pond) == "table" then
		save.pond.at = whole(value.pond.at, now, save.pond.at)
	end
	if type(value.lostFound) == "table" then
		save.lostFound.day = whole(value.lostFound.day, today, save.lostFound.day)
		save.lostFound.held = math.max(0, whole(value.lostFound.held, Config.LostFoundHold, 0))
	end
	if type(value.yardSale) == "table" then
		save.yardSale.day = whole(value.yardSale.day, today, today)
		if type(value.yardSale.bought) == "table" then
			for crateId, bought in value.yardSale.bought do
				if
					type(crateId) == "string"
					and bought == true
					and Catalog.getCrate(crateId) ~= nil
				then
					save.yardSale.bought[crateId] = true
				end
			end
		end
	end
	return save
end

-- Whole Fish Pond steps since its fill started (never below 0).
local function pondSteps(save: Types.CampExtrasSave, now: number): number
	return math.max(0, math.floor((now - save.pond.at) / Config.PondStepSeconds))
end

-- The golden fish waiting in the Fish Pond.
function CampExtras.pondFish(save: Types.CampExtrasSave, now: number): number
	return math.min(Config.PondHold, pondSteps(save, now) * Config.PondFishPerStep)
end

-- Brings a save up to `now` for a player of `tier`, in place: each open extra fills by the time passed up to its hold
-- (a full one's clock waits, so the next fill counts from when it is emptied), the Yard Sale rolls over to today, and
-- a shut extra goes back to its fresh state.
function CampExtras.settle(save: Types.CampExtrasSave, tier: number, now: number)
	local today = CampExtras.day(now)
	local fresh = CampExtras.fresh(now)
	if not CampExtras.isOpen("picnic", tier) then
		save.picnic = fresh.picnic
	else
		local picnic = save.picnic
		local every = Config.PicnicEverySeconds
		local steps = math.max(0, math.floor((now - picnic.at) / every))
		local add = math.min(steps, math.max(0, Config.PicnicHold - picnic.held))
		picnic.held = math.min(Config.PicnicHold, picnic.held + add)
		picnic.at = if picnic.held >= Config.PicnicHold then now else picnic.at + add * every
	end
	if not CampExtras.isOpen("pond", tier) then
		save.pond = fresh.pond
	end
	if not CampExtras.isOpen("lostFound", tier) then
		save.lostFound = fresh.lostFound
	elseif today > save.lostFound.day then
		local lostFound = save.lostFound
		lostFound.held = math.min(Config.LostFoundHold, lostFound.held + today - lostFound.day)
		lostFound.day = today
	end
	if save.yardSale.day ~= today then
		save.yardSale = { day = today, bought = {} }
	end
end

-- The Yard Sale's crate on UTC day `day` for a player of `tier`: the plain crate of one of the player's open areas
-- (Catalog order, picked by the day number), none while the Neighbourhood is shut. A list, as the view sends it.
function CampExtras.yardStock(tier: number, day: number): { string }
	if not CampExtras.isOpen(CampExtras.YARD_SALE, tier) then
		return {}
	end
	local zones: { string } = {}
	for _, area in Catalog.areas do
		local crateId = area.id .. "_crate"
		if area.tier <= tier and Catalog.getCrate(crateId) ~= nil then
			table.insert(zones, crateId)
		end
	end
	local stock: { string } = {}
	if #zones > 0 then
		table.insert(stock, zones[day % #zones + 1])
	end
	return stock
end

local function shut(): Types.CampExtraView
	return { open = false, held = 0 }
end

-- What CampExtrasState sends for a settled save: each extra's view and the day.
function CampExtras.view(
	save: Types.CampExtrasSave,
	tier: number,
	now: number
): Types.CampExtrasState
	local today = CampExtras.day(now)
	local tomorrow = (today + 1) * DAY
	local picnic = shut()
	if CampExtras.isOpen("picnic", tier) then
		picnic.open = true
		picnic.held = save.picnic.held
		if save.picnic.held < Config.PicnicHold then
			picnic.nextAt = save.picnic.at + Config.PicnicEverySeconds
		end
	end
	local pond = shut()
	if CampExtras.isOpen("pond", tier) then
		local steps = pondSteps(save, now)
		pond.open = true
		pond.held = CampExtras.pondFish(save, now)
		if pond.held < Config.PondHold then
			pond.nextAt = save.pond.at + (steps + 1) * Config.PondStepSeconds
		end
	end
	local lostFound = shut()
	if CampExtras.isOpen("lostFound", tier) then
		lostFound.open = true
		lostFound.held = save.lostFound.held
		if save.lostFound.held < Config.LostFoundHold then
			lostFound.nextAt = tomorrow
		end
	end
	local yardSale = shut()
	if CampExtras.isOpen(CampExtras.YARD_SALE, tier) then
		local stock: { Types.YardSaleCrate } = {}
		for _, crateId in CampExtras.yardStock(tier, today) do
			local bought = save.yardSale.day == today and save.yardSale.bought[crateId] == true
			table.insert(
				stock,
				{ crateId = crateId, price = 0, bought = bought }
			)
			if not bought then
				yardSale.held += 1
			end
		end
		yardSale.open = true
		yardSale.nextAt = tomorrow
		yardSale.stock = stock
	end
	return { day = today, picnic = picnic, yardSale = yardSale, pond = pond, lostFound = lostFound }
end

-- A LostFoundTable row as a prize.
local function rowPrize(
	row: { chance: number, fish: number?, potion: string?, crate: string? }
): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	if row.fish ~= nil then
		prize.fish = row.fish
	end
	if row.potion ~= nil then
		prize.potions = { [row.potion] = 1 }
	end
	if row.crate ~= nil then
		prize.crates = { [row.crate] = 1 }
	end
	return prize
end

-- One Lost and Found prize for a roll in [0, 1): the LostFoundTable row the roll lands in.
function CampExtras.lostFoundPrize(roll: number): Types.IndexPrize
	local rows = Config.LostFoundTable
	local total = 0
	for _, row in rows do
		total += row.chance
		if roll < total then
			return rowPrize(row)
		end
	end
	return rowPrize(rows[#rows])
end

local function addCounts(
	into: { [string]: number }?,
	from: { [string]: number }?
): { [string]: number }?
	if from == nil then
		return into
	end
	local counts: { [string]: number } = into or {}
	for id, count in from do
		counts[id] = (counts[id] or 0) + count
	end
	return counts
end

-- Two prizes as one: their golden fish, potions and crates added up.
function CampExtras.merge(a: Types.IndexPrize, b: Types.IndexPrize): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	local fish = (a.fish or 0) + (b.fish or 0)
	if fish > 0 then
		prize.fish = fish
	end
	prize.potions = addCounts(addCounts(nil, a.potions), b.potions)
	prize.crates = addCounts(addCounts(nil, a.crates), b.crates)
	return prize
end

-- Short wait text: "2 h 10 m", "3 h", "25 m", at least "1 m".
function CampExtras.waitText(seconds: number): string
	local minutes = math.max(1, math.ceil(seconds / 60))
	if minutes >= 60 then
		local hours, rest = math.floor(minutes / 60), minutes % 60
		return if rest > 0
			then string.format("%d h %d m", hours, rest)
			else string.format("%d h", hours)
	end
	return string.format("%d m", minutes)
end

local function extraName(extraId: string): string
	local def = Catalog.getCampExtra(extraId)
	return if def ~= nil then def.name else extraId
end

-- Why a collect of `extraId` would be refused for a settled save, or nil when something waits. The server checks the
-- player's range itself.
function CampExtras.collectBlocker(
	save: Types.CampExtrasSave,
	extraId: string,
	tier: number,
	now: number
): string?
	if table.find(CampExtras.COLLECT, extraId) == nil then
		return "There is nothing to collect there"
	end
	if not CampExtras.isOpen(extraId, tier) then
		return string.format(
			"The %s opens at Tier %d",
			extraName(extraId),
			CampExtras.tierOf(extraId) or 0
		)
	end
	local view = (CampExtras.view(save, tier, now) :: any)[extraId] :: Types.CampExtraView
	if view.held <= 0 then
		return if view.nextAt ~= nil
			then string.format("Nothing yet. Next in %s", CampExtras.waitText(view.nextAt - now))
			else "Nothing yet"
	end
	return nil
end

-- Takes everything `extraId` holds from a save for a player of `tier` (settling it first): the prize and how many
-- fills it was, or nil and 0 when nothing waits. `roll` gives the Lost and Found's rolls in [0, 1), one a prize.
function CampExtras.take(
	save: Types.CampExtrasSave,
	extraId: string,
	tier: number,
	now: number,
	roll: () -> number
): (Types.IndexPrize?, number)
	CampExtras.settle(save, tier, now)
	if not CampExtras.isOpen(extraId, tier) then
		return nil, 0
	end
	if extraId == "picnic" then
		local held = save.picnic.held
		if held <= 0 then
			return nil, 0
		end
		save.picnic.held = 0
		return { potions = { [Config.PicnicPotion] = held } }, held
	elseif extraId == "pond" then
		local steps = pondSteps(save, now)
		local fish = CampExtras.pondFish(save, now)
		if fish <= 0 then
			return nil, 0
		end
		save.pond.at = if steps * Config.PondFishPerStep >= Config.PondHold
			then now
			else save.pond.at + steps * Config.PondStepSeconds
		return { fish = fish }, fish
	elseif extraId == "lostFound" then
		local held = save.lostFound.held
		if held <= 0 then
			return nil, 0
		end
		local prize: Types.IndexPrize = {}
		for _ = 1, held do
			prize = CampExtras.merge(prize, CampExtras.lostFoundPrize(roll()))
		end
		save.lostFound.held = 0
		return prize, held
	end
	return nil, 0
end

-- Why taking `crateId` at the Yard Sale would be refused for a settled save, or nil. It is free, so golden fish are
-- never checked. The server checks the player's range itself.
function CampExtras.buyBlocker(
	save: Types.CampExtrasSave,
	crateId: string,
	tier: number,
	now: number
): string?
	if not CampExtras.isOpen(CampExtras.YARD_SALE, tier) then
		return string.format(
			"The Yard Sale opens at Tier %d",
			CampExtras.tierOf(CampExtras.YARD_SALE) or 0
		)
	end
	local today = CampExtras.day(now)
	if table.find(CampExtras.yardStock(tier, today), crateId) == nil then
		return "That crate is not at the Yard Sale today"
	end
	if save.yardSale.day == today and save.yardSale.bought[crateId] == true then
		return CampExtras.TAKEN
	end
	return nil
end

-- The first crate still for sale today in a Yard Sale view, or nil.
function CampExtras.nextYardCrate(view: Types.CampExtraView): Types.YardSaleCrate?
	local stock: { Types.YardSaleCrate } = view.stock or {}
	for _, crate in stock do
		if not crate.bought then
			return crate
		end
	end
	return nil
end

local function plural(count: number, one: string, many: string): string
	return string.format("%d %s", count, if count == 1 then one else many)
end

-- The prompt's two lines for one extra's view: its name (ObjectText) and what a press does or when the next fill
-- comes (ActionText), as in "Fish Pond" / "Collect 14 fish" or "Picnic Basket" / "Next in 2 h 10 m".
function CampExtras.promptText(
	extraId: string,
	view: Types.CampExtraView,
	now: number
): (string, string)
	local name = extraName(extraId)
	if not view.open then
		return name, string.format("Opens at Tier %d", CampExtras.tierOf(extraId) or 0)
	end
	if view.held > 0 then
		if extraId == "picnic" then
			local potion = Catalog.getPotion(Config.PicnicPotion)
			local potionName = if potion ~= nil then potion.name else "potion"
			return name, "Collect " .. plural(view.held, potionName, potionName .. "s")
		elseif extraId == "pond" then
			return name, string.format("Collect %d fish", view.held)
		elseif extraId == "lostFound" then
			return name, "Collect " .. plural(view.held, "prize", "prizes")
		end
		return name, "Take a free crate"
	end
	if extraId == CampExtras.YARD_SALE then
		return name,
			if view.nextAt ~= nil
				then string.format("Taken, new crate in %s", CampExtras.waitText(view.nextAt - now))
				else "Taken"
	end
	return name,
		if view.nextAt ~= nil
			then string.format("Next in %s", CampExtras.waitText(view.nextAt - now))
			else "Nothing yet"
end

-- The cannon picker's line under an area's card (section 3), or nil when the area has no extra or it is shut, and
-- whether something waits to be claimed (the "!"; the Yard Sale's free crate is one since #1051):
-- "Picnic Basket: 1 ready !", "Yard Sale: free crate !", "Fish Pond: 14 fish !", "Lost and Found: 2 to claim !".
function CampExtras.pickerLine(
	state: Types.CampExtrasState,
	areaId: string,
	now: number
): (string?, boolean)
	for _, def in Catalog.campExtras do
		if def.area == areaId then
			local view = (state :: any)[def.id] :: Types.CampExtraView?
			if view == nil or not view.open then
				return nil, false
			end
			local wait = if view.nextAt ~= nil then CampExtras.waitText(view.nextAt - now) else nil
			if def.id == CampExtras.YARD_SALE then
				if view.held > 0 then
					return "Yard Sale: free crate !", true
				end
				return if wait ~= nil
					then "Yard Sale: new crate in " .. wait
					else "Yard Sale: taken",
					false
			end
			if view.held > 0 then
				local what = if def.id == "picnic"
					then string.format("%d ready", view.held)
					elseif def.id == "pond" then string.format("%d fish", view.held)
					else string.format("%d to claim", view.held)
				return string.format("%s: %s !", def.name, what), true
			end
			return if wait ~= nil then string.format("%s: next in %s", def.name, wait) else def.name,
				false
		end
	end
	return nil, false
end

return CampExtras
