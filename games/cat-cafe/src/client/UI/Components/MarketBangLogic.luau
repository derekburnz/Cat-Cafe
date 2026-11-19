--!strict
-- #2214: what the "!" over the Fish Market (Components/MarketBang) says, pure so the cloud specs check it.
--   count(crates)   how many unopened crates in all
--   line(crates, treatsNew?)   the bubble's words ("📦 2 crates to open"), or nil when there are none, so no "!"
--                              shows. #2571: with no crates and treatsNew, "🍪 Treats and perks to check out!"
--   treatsNew(storeSeen)       #2571: the Treats and perks tab has not been opened yet (shared/StoreTabs "treats")

local StoreTabs =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StoreTabs"))

local MarketBangLogic = {}

MarketBangLogic.TREATS_TAB = "treats" -- shared/StoreTabs id, sent with MarkStoreSeen
-- #4677: a fixed line break, so the scaled text no longer re-wraps between "to / check out!" and "to check / out!"
-- as you walk up (Sync's Studio look)
MarketBangLogic.TREATS_LINE = "🍪 Treats and perks\nto check out!"

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

function MarketBangLogic.line(crates: { [string]: number }?, treatsNew: boolean?): string?
	local total = MarketBangLogic.count(crates)
	if total <= 0 then
		return if treatsNew == true then MarketBangLogic.TREATS_LINE else nil
	end
	return ("📦 %d %s to open"):format(total, if total == 1 then "crate" else "crates")
end

-- True while the save's storeSeen is below the Treats tab's version: never opened, or a bump since. False until the
-- first sync brings storeSeen, so a "!" never flashes on for someone who has seen it.
function MarketBangLogic.treatsNew(storeSeen: unknown): boolean
	if type(storeSeen) ~= "table" then
		return false
	end
	local version = StoreTabs.VERSIONS[MarketBangLogic.TREATS_TAB]
	if version == nil then
		return false
	end
	local seen = (storeSeen :: any)[MarketBangLogic.TREATS_TAB]
	return (if type(seen) == "number" then seen else 0) < version
end

-- #5390: the "!" bubble's text size, worked out by hand (Components/MarketBang.fixText).
MarketBangLogic.CHAR_WIDTH = 0.6 -- a display-font character's width, as a share of the text size (emoji included)
MarketBangLogic.LINE_HEIGHT = 1.15 -- a line's height, as a share of the text size

-- The text size that fits `words` in a box `width` x `height` px, between 8 and 100. Pure.
function MarketBangLogic.fitSize(words: string, width: number, height: number): number
	local lines, longest = 0, 1
	for _, part in string.split(words, "\n") do
		lines += 1
		longest = math.max(longest, utf8.len(part) or #part)
	end
	lines = math.max(lines, 1)
	local byHeight = height / (lines * MarketBangLogic.LINE_HEIGHT)
	local byWidth = width / (longest * MarketBangLogic.CHAR_WIDTH)
	return math.clamp(math.floor(math.min(byHeight, byWidth)), 8, 100)
end

return MarketBangLogic
