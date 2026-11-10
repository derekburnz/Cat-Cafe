--!strict
-- #2913 (Research-Agent, Nov 8 and 9: phone players miss about as many first circles as they catch, and the logs
-- carry no screen size): the viewport's short side as one of the server's SCREEN_SHORTS buckets, for the
-- once-a-session TelemetryReport "screen_short". Pure, so the specs check it.
--   bucket(viewport) -> "lt400" | "400_600" | "gt600"

local ScreenShort = {}

function ScreenShort.bucket(viewport: Vector2): string
	local short = math.min(viewport.X, viewport.Y)
	if short < 400 then
		return "lt400"
	elseif short <= 600 then
		return "400_600"
	end
	return "gt600"
end

return ScreenShort
