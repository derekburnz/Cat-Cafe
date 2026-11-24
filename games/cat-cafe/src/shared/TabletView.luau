--!strict
-- #5696 (Design, after #5686: tablets keep 62% from the first Park catch to Tier 3 against 83% on phones): Roblox's
-- Camera.FieldOfView is the vertical angle, so a 4:3 iPad at 70 sees about 86 degrees sideways against 113 on a phone
-- and has fewer Park strays on screen. With the tabletView switch on, a touch screen held sideways and narrower than
-- 16:9 gets the vertical view that matches a 16:9 screen's sideways view at 70, at most MAX. Pure, so the cloud specs
-- check it; Controllers/TabletViewController applies it, and Telemetry adds "v<fov>" to client_fps field 3.
--   FLAG, BASE, MAX, WIDE, HALF_SIDE, REPORT
--   fov(aspect, touch) -> number   the camera's vertical view for a screen `aspect` (width / height) wide

local TabletView = {}

TabletView.FLAG = "tabletView"
TabletView.BASE = 70 -- Roblox's default vertical view, kept on phones, PCs and consoles
TabletView.MAX = 80
TabletView.WIDE = 16 / 9 -- at this aspect and wider nothing changes
TabletView.HALF_SIDE = 51 -- degrees: half of a 16:9 screen's sideways view at 70
TabletView.REPORT = "tablet_view" -- TelemetryReport name: the vertical view set, BASE to MAX, once a session

function TabletView.fov(aspect: number, touch: boolean): number
	-- a portrait screen (aspect under 1) is left alone: the cap would only zoom a phone held upright out
	if not touch or aspect ~= aspect or aspect < 1 or aspect >= TabletView.WIDE then
		return TabletView.BASE
	end
	local vertical = math.deg(2 * math.atan(math.tan(math.rad(TabletView.HALF_SIDE)) / aspect))
	return math.clamp(math.floor(vertical + 0.5), TabletView.BASE, TabletView.MAX)
end

return TabletView
