--!strict
-- #5164 (player feedback "the game lags every night and day"; Sync's Studio read of a forced phase change at Tier 4:
-- dusk took 44 to 76 ms in one server frame, mostly CatService.nightFalls sending every stray away, and sunrise 63 to
-- 74 ms, mostly RescueService.sunrise cloning every area's stuck cats). With the switch `nightSpread` on
-- (LiveFlags.OFF_BY_DEFAULT) that work is spread over frames: the strays leave PER_STEP at a time, and the stuck
-- cats roll one area a frame. Off, both run in one frame as before. Pure.
--   chunks(list, size) -> { { T } }   the list cut into runs of at most `size`, in order

local NightSpread = {}

NightSpread.FLAG = "nightSpread"
NightSpread.PER_STEP = 8 -- strays sent away a frame at dusk

function NightSpread.chunks<T>(list: { T }, size: number): { { T } }
	local out: { { T } } = {}
	local step = math.max(1, math.floor(size))
	for i = 1, #list, step do
		table.insert(out, table.move(list, i, math.min(#list, i + step - 1), 1, {}))
	end
	return out
end

return NightSpread
