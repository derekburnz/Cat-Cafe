--!strict
-- #4251 Harvest Hollow on the client: what the Harvest Stall window shows (spec section 4) and the "Yours to keep"
-- line on a harvest cat (section 3b). Pure: no instances, so the cloud specs run it.
--   rows(tab)                  the Stall's items on one tab ("outfit" or "decor"), in shared/HarvestHollow's order
--   pumpkins(state)            the player's pumpkins (0 before ProfileSync sends them)
--   owns(state, id)            bought at the Stall
--   action(state, item)        the item's button: Owned, Opens at Tier 2, or the pumpkin price (grey when short)
--   keepLine(rarity, area)     "Yours to keep · earns like a Woods Epic"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HarvestHollow =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HarvestHollow"))

local HarvestLogic = {}

HarvestLogic.PUMPKIN = "🎃"

export type Tab = "outfit" | "decor"
export type Action = {
	mode: string, -- "owned", "locked" or "buy"
	text: string,
	style: string, -- the Button style
	enabled: boolean,
}

local function view(state: any): any
	return if type(state) == "table" and type(state.harvest) == "table" then state.harvest else nil
end

function HarvestLogic.rows(tab: Tab): { HarvestHollow.Item }
	local out: { HarvestHollow.Item } = {}
	for _, item in HarvestHollow.STALL do
		if item.kind == tab then
			table.insert(out, item)
		end
	end
	return out
end

function HarvestLogic.pumpkins(state: any): number
	local harvest = view(state)
	local count = if harvest then harvest.pumpkins else nil
	return if type(count) == "number" then math.max(0, math.floor(count)) else 0
end

function HarvestLogic.owns(state: any, id: string): boolean
	local harvest = view(state)
	local bought = if harvest then harvest.bought else nil
	return type(bought) == "table" and bought[id] == true
end

function HarvestLogic.action(state: any, item: HarvestHollow.Item): Action
	if HarvestLogic.owns(state, item.id) then
		return { mode = "owned", text = "Owned", style = "ghost", enabled = false }
	end
	local tier = if type(state) == "table" and type(state.tier) == "number" then state.tier else 1
	if tier < HarvestHollow.TIER then
		return {
			mode = "locked",
			text = ("Opens at Tier %d"):format(HarvestHollow.TIER),
			style = "ghost",
			enabled = false,
		}
	end
	local enough = HarvestLogic.pumpkins(state) >= item.price
	return {
		mode = "buy",
		text = ("%s %d"):format(HarvestLogic.PUMPKIN, item.price),
		style = if enough then "gold" else "ghost",
		enabled = enough,
	}
end

-- "Yours to keep · earns like a Woods Epic" (section 3b); "an" before a vowel ("an Alleyway Common")
function HarvestLogic.keepLine(rarity: string, area: string?): string
	local like = HarvestHollow.earnsLike(rarity)
	local words = if area ~= nil and area ~= "" then area .. " " .. like else like
	local first = string.lower(string.sub(words, 1, 1))
	local article = if string.find("aeiou", first, 1, true) then "an" else "a"
	return ("Yours to keep · earns like %s %s"):format(article, words)
end

return HarvestLogic
