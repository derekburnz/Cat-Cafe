--!strict
-- #3696 (Derek 2026-11-12: "the cat standing on the table has his money inside of him"): how a cat's name and
-- money label follows the top of its model. The label's height was measured once, when the cat arrived (sitting,
-- no hat yet), so a cat that then stood up, or was dressed in a hat, reached into it. WorldTags now measures the
-- model's top every CHECK_SECONDS and asks `settle` where the label should be.
--
-- A cat's parts move a little all the time (the breath, the tail), so the label does not chase every measure: it
-- goes up at once when the model's top passes it by more than RISE, and comes down only when the top has dropped
-- by more than FALL, so a cat that bobs never makes its label shake. Pure.

local TagHeight = {}

TagHeight.CHECK_SECONDS = 0.5
TagHeight.RISE = 0.08 -- studs the top may pass the label's height before the label goes up
TagHeight.FALL = 0.45 -- studs the top must drop before the label comes down
TagHeight.MAX = 12 -- studs: a measure past this is a stray part (a thrown toy, a streamed piece), not the cat

-- The height (studs over the anchor part's centre) the label should hang at: `current` is where it hangs now,
-- `measured` the model's top now.
function TagHeight.settle(current: number, measured: number): number
	if measured ~= measured or measured < 0 or measured > TagHeight.MAX then
		return current
	end
	if measured > current + TagHeight.RISE or measured < current - TagHeight.FALL then
		return measured
	end
	return current
end

return TagHeight
