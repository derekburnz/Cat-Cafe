--!strict
-- #5164 (player feedback "the game lags every night and day"; Sync's Studio read of a forced phase change at Tier 4:
-- dusk took 44 to 76 ms in one server frame, mostly CatService.nightFalls sending every stray away, and sunrise 63 to
-- 74 ms, mostly RescueService.sunrise cloning every area's stuck cats). With the switch `nightSpread` on
-- (LiveFlags.OFF_BY_DEFAULT) that work is spread over frames: the strays leave PER_STEP at a time, and the stuck
-- cats roll one area a frame. Off, both run in one frame as before. Pure.
-- Sync's MicroProfiler read (2026-11-18): a frame apart is still one network send, so the client got 11,156 removals
-- (dusk) or 5,403 new instances (sunrise) in one 133 to 204 ms frame. The steps are now STEP_SECONDS apart, and dusk's
-- stuck cats and sunrise's first strays are spread the same way.
--   chunks(list, size) -> { { T } }   the list cut into runs of at most `size`, in order

local NightSpread = {}

NightSpread.FLAG = "nightSpread"
NightSpread.PER_STEP = 8 -- strays (or stuck cats, or sunrise's first strays) a step
NightSpread.STEP_SECONDS = 0.15 -- between steps: a few network sends apart, about 2 s for a full Tier 10 server

function NightSpread.chunks<T>(list: { T }, size: number): { { T } }
	local out: { { T } } = {}
	local step = math.max(1, math.floor(size))
	for i = 1, #list, step do
		table.insert(out, table.move(list, i, math.min(#list, i + step - 1), 1, {}))
	end
	return out
end

return NightSpread
