--!strict
-- #2214: what the "!" over the Fish Market (Components/MarketBang) says, pure so the cloud specs check it.
--   count(crates)   how many unopened crates in all
--   line(crates)    the bubble's words ("📦 2 crates to open"), or nil when there are none, so no "!" shows

local MarketBangLogic = {}

function MarketBangLogic.count(crates: { [string]: number }?): number
	local total = 0
	if crates == nil then
		return 0
	end
	for _, n in crates do
		if type(n) == "number" and n > 0 then
			total += math.floor(n)
		end
	end
	return total
end

function MarketBangLogic.line(crates: { [string]: number }?): string?
	local total = MarketBangLogic.count(crates)
	if total <= 0 then
		return nil
	end
	return ("📦 %d %s to open"):format(total, if total == 1 then "crate" else "crates")
end

return MarketBangLogic
