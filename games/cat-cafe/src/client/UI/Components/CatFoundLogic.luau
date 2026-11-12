--!strict
-- #2833 (Derek2 11-09: "only do the double pop-up if its a legendary+ or any new cat. No need to try and make a common
-- a big pop up everytime its annoying"): which catches get the big centre card (Screens/Popups' cat found card) after
-- the catch's own grades; the rest get nothing more (#2844: no toast either, the catch's small pop-up says it). The big
-- card stays for a cat new to the Index, Legendary or better (and the Golden cats), a gold or rainbow coat, and any card
-- with its own banner or line (the Bellhop Cat, the starter cat). Pure, so the cloud specs check it.
--   big(rarity, isNew, extra) -> boolean   the big card, or nothing more

local CatFoundLogic = {}

local BIG: { [string]: boolean } =
	{ Legendary = true, Mythical = true, Secret = true, Golden = true }
CatFoundLogic.BIG = BIG

function CatFoundLogic.big(rarity: unknown, isNew: boolean?, extra: unknown): boolean
	if isNew == true or (type(rarity) == "string" and BIG[rarity] == true) then
		return true
	end
	if type(extra) == "table" then
		local raw = extra :: any
		if raw.shiny == true or raw.rainbow == true or raw.banner ~= nil or raw.line ~= nil then
			return true
		end
	end
	return false
end

return CatFoundLogic
