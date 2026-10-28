--!strict
-- The Cat Collector's card as plain rules (F63, data-model section 12b):
--   prize(offer, area) -> IndexPrize?   his offer in the prize shape PrizeChips draws: a zone crate is `area`'s
--                                       crate ("park_crate") and a golden crate its golden one ("park_golden_crate")
--   needsConfirm(rarity, variant)       Trade asks for a second tap from Rare up and for any gold cat, as Sell does
--   near(distance, wasNear)             the card opens at CollectorRangeStuds (12) from him and closes a stud past
--                                       it, so it does not flicker at the edge
--   catLine(rarity, variant) -> "Gold Rare"
--   clock(seconds) -> "2:41"
-- No Theme, Format or CFrame here, so the cloud test runner (no fonts, no CFrame) can load and test it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatVariant = require(script.Parent.CatVariant)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local RANGE: number = Config.CollectorRangeStuds or 12
local CONFIRM_RARITIES: { [string]: boolean } =
	{ Rare = true, Epic = true, Legendary = true, Mythical = true }

local CollectorLogic = {}

CollectorLogic.RANGE = RANGE

local function positive(value: any): number?
	if type(value) == "number" and value == value and value > 0 and value ~= math.huge then
		return math.floor(value)
	end
	return nil
end

function CollectorLogic.prize(offer: Types.CollectorOffer?, area: string?): Types.IndexPrize?
	if type(offer) ~= "table" then
		return nil
	end
	local prize: Types.IndexPrize = { fish = positive(offer.fish), spins = positive(offer.spins) }
	if type(offer.lures) == "table" then
		local lures: { [string]: number } = {}
		for lureId, count in offer.lures do
			local amount = positive(count)
			if type(lureId) == "string" and amount then
				lures[lureId] = amount
			end
		end
		if next(lures) ~= nil then
			prize.lures = lures
		end
	end
	local crates = offer.crates
	if type(crates) == "table" and type(area) == "string" and area ~= "" then
		local paid: { [string]: number } = {}
		local zone = positive(crates.zone)
		if zone then
			paid[area .. "_crate"] = zone
		end
		local golden = positive(crates.golden)
		if golden then
			paid[area .. "_golden_crate"] = golden
		end
		if next(paid) ~= nil then
			prize.crates = paid
		end
	end
	return prize
end

function CollectorLogic.needsConfirm(rarity: string?, variant: string?): boolean
	return CatVariant.isGold(variant) or (rarity ~= nil and CONFIRM_RARITIES[rarity] == true)
end

function CollectorLogic.near(distance: number?, wasNear: boolean): boolean
	if distance == nil then
		return false
	end
	return distance <= (if wasNear then RANGE + 1 else RANGE)
end

function CollectorLogic.catLine(rarity: string?, variant: string?): string
	local name = rarity or "Common"
	return if CatVariant.isGold(variant) then "Gold " .. name else name
end

function CollectorLogic.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

return CollectorLogic
