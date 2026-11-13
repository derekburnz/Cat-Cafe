--!strict
-- Juniper's Mystery Market (#2565, mystery-market.md sections 2 and 5). Every item of Catalog.mysteryItems is on the
-- shelf at its full price all the time, bought once with golden fish. One item a week is featured at
-- MysterySaleShare of its price (rounded to the nearest 5). The week runs on the global clock, so every server shows
-- the same item at the same moment: slot = floor((now - MysteryEpoch) / MysteryRotateSeconds), and the featured item
-- is mysteryItems[slot % #items + 1]. MysteryEpoch is a Saturday 00:00 UTC, so each sale starts with the Saturday
-- update. #3535: Config.MysteryFeatured names featured weeks by date (an update's own item), which win over the
-- rotation while they run; an item with a `flag` is on the shelf only while that live switch is on. Nothing is random, nothing is limited and nothing is sold for Robux (rule 9, section 2d). Pure: `now` is
-- os.time() on the server and the server clock on the client.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local MysteryMarket = {}

MysteryMarket.OWNED_TEXT = "You have this!"
MysteryMarket.FISH_TEXT = "Not enough golden fish"
MysteryMarket.SALE_ENDED_TEXT = "The sale just ended"

-- The week number at `now` (0 is the week starting MysteryEpoch).
function MysteryMarket.slot(now: number): number
	return math.floor((now - Config.MysteryEpoch) / Config.MysteryRotateSeconds)
end

-- The dated featured week running at `now` (Config.MysteryFeatured), or nil.
local function dated(now: number): { from: number, to: number, id: string }?
	for _, entry in Config.MysteryFeatured do
		if now >= entry.from and now < entry.to and Catalog.getMysteryItem(entry.id) ~= nil then
			return entry
		end
	end
	return nil
end

-- The id of the item on sale at `now`, or nil when the shelf is empty: a dated week's item, else the rotation's.
function MysteryMarket.featuredAt(now: number): string?
	local entry = dated(now)
	if entry ~= nil then
		return entry.id
	end
	local items = Catalog.mysteryItems
	if #items == 0 then
		return nil
	end
	return items[MysteryMarket.slot(now) % #items + 1].id
end

-- Whether `item` is on the shelf: always, or only while its live switch is on (`flags`: key -> on).
function MysteryMarket.listed(item: Types.MysteryItem, flags: { [string]: boolean }?): boolean
	return item.flag == nil or (flags ~= nil and flags[item.flag] == true)
end

-- The id of next week's featured item (the window's "?" teaser), or nil when the shelf is empty.
function MysteryMarket.nextFeatured(now: number): string?
	return MysteryMarket.featuredAt(MysteryMarket.nextAt(now))
end

-- When this sale ends and the next one starts (os.time() seconds): the end of a dated week, else the rotation's
-- next week or the start of a dated week, whichever comes first.
function MysteryMarket.nextAt(now: number): number
	local entry = dated(now)
	if entry ~= nil then
		return entry.to
	end
	local nextAt = Config.MysteryEpoch + (MysteryMarket.slot(now) + 1) * Config.MysteryRotateSeconds
	for _, later in Config.MysteryFeatured do
		if later.from > now and later.from < nextAt and Catalog.getMysteryItem(later.id) ~= nil then
			nextAt = later.from
		end
	end
	return nextAt
end

-- The sale price of a full price `cost`: MysterySaleShare of it, to the nearest 5.
function MysteryMarket.salePrice(cost: number): number
	return math.floor(cost * Config.MysterySaleShare / 5 + 0.5) * 5
end

-- What `item` costs at `now`: its sale price in its featured week, else its full price.
function MysteryMarket.priceOf(item: Types.MysteryItem, now: number): number
	if MysteryMarket.featuredAt(now) == item.id then
		return MysteryMarket.salePrice(item.cost)
	end
	return item.cost
end

function MysteryMarket.owns(profile: Types.PlayerProfile, itemId: string): boolean
	return profile.mystery[itemId] == true
end

-- Whether `profile` can buy `item` at `now`, and why not: owned, below its tier, or short of golden fish.
function MysteryMarket.canBuy(
	profile: Types.PlayerProfile,
	item: Types.MysteryItem,
	now: number
): (boolean, string?)
	if MysteryMarket.owns(profile, item.id) then
		return false, MysteryMarket.OWNED_TEXT
	end
	if Economy.tier(profile) < item.minTier then
		return false, string.format("Opens at Tier %d", item.minTier)
	end
	if profile.goldenFish < MysteryMarket.priceOf(item, now) then
		return false, MysteryMarket.FISH_TEXT
	end
	return true, nil
end

-- The owned map from a save: known item ids set to true, everything else dropped.
function MysteryMarket.sanitize(value: unknown): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(value) == "table" then
		for id, owned in value :: { [any]: any } do
			if type(id) == "string" and owned == true and Catalog.getMysteryItem(id) ~= nil then
				out[id] = true
			end
		end
	end
	return out
end

return MysteryMarket
