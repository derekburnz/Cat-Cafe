--!strict
-- The sky through the server's day and night (Derek 2026-10-27 22:37: brightness follows the clock, not just a flip at
-- night, and the day is less bright). Pure: Color3 only, no services, so tests can require it. The day runs a warm
-- sunrise, morning, a softer midday, golden late afternoon, dusk and sunset; the night falls to the #239 night look,
-- holds it and warms back to the sunrise just before the areas open. Each phase is a row of keyframes over its
-- progress (0 at its start, 1 at its end), linear between them, and each phase ends on the look the next one starts
-- with, so the sky never jumps at a phase change. WorldController applies the look to Lighting and its Atmosphere.
-- Haze stays light (Derek 2026-10-28 00:45: Haze 2 to 2.6 and Density 0.3 laid a grey fog over the whole screen
-- from the high camera): a little warm haze at sunrise and the golden hours, none at midday or night.
-- Visual only, so the numbers live here rather than in Config.

local Config = require(script.Parent.Config)

local DayLight = {}

export type Look = {
	ClockTime: number, -- may run past 24 inside a phase so it only goes forward; apply it % 24
	Brightness: number,
	OutdoorAmbient: Color3,
	Ambient: Color3,
	ExposureCompensation: number,
	ColorShift_Top: Color3,
	-- Atmosphere
	Density: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

type Key = { at: number, look: Look }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- `base` with the fields in `changes` replaced.
local function with(base: Look, changes: { [string]: any }): Look
	local look: any = table.clone(base)
	for name, value in changes do
		look[name] = value
	end
	return look :: Look
end

DayLight.SUNRISE = {
	ClockTime = 6.4,
	Brightness = 0.9,
	OutdoorAmbient = rgb(150, 125, 120),
	Ambient = rgb(95, 85, 85),
	ExposureCompensation = -0.1,
	ColorShift_Top = rgb(255, 190, 150),
	Density = 0.25,
	Color = rgb(255, 195, 160),
	Decay = rgb(140, 130, 170),
	Glare = 0.6,
	Haze = 0.6,
} :: Look

DayLight.MORNING = with(DayLight.SUNRISE, {
	ClockTime = 8.6,
	Brightness = 1.3,
	OutdoorAmbient = rgb(142, 134, 128),
	Ambient = rgb(98, 94, 90),
	ExposureCompensation = -0.2,
	ColorShift_Top = rgb(255, 225, 195),
	Color = rgb(235, 218, 205),
	Decay = rgb(150, 165, 205),
	Glare = 0.3,
	Haze = 0.3,
})

-- The brightest the day gets: Brightness 2, OutdoorAmbient 170,160,150 and exposure 0 before was too bright.
DayLight.MIDDAY = {
	ClockTime = 12.5,
	Brightness = 1.5,
	OutdoorAmbient = rgb(138, 132, 126),
	Ambient = rgb(100, 96, 92),
	ExposureCompensation = -0.2,
	ColorShift_Top = rgb(255, 245, 232),
	Density = 0.25,
	Color = rgb(210, 224, 238),
	Decay = rgb(150, 180, 215),
	Glare = 0,
	Haze = 0,
} :: Look

DayLight.GOLDEN = with(DayLight.MIDDAY, {
	ClockTime = 16.2,
	Brightness = 1.35,
	OutdoorAmbient = rgb(148, 132, 116),
	ColorShift_Top = rgb(255, 210, 160),
	Color = rgb(255, 212, 160),
	Decay = rgb(165, 160, 190),
	Glare = 0.5,
	Haze = 0.5,
})

DayLight.DUSK = with(DayLight.GOLDEN, {
	ClockTime = 17.7,
	Brightness = 0.95,
	OutdoorAmbient = rgb(125, 105, 115),
	Ambient = rgb(85, 78, 85),
	ExposureCompensation = -0.1,
	ColorShift_Top = rgb(255, 170, 140),
	Color = rgb(245, 160, 135),
	Decay = rgb(110, 95, 150),
	Glare = 0.4,
	Haze = 0.6,
})

DayLight.SUNSET = with(DayLight.DUSK, {
	ClockTime = 18.3,
	Brightness = 0.75,
	OutdoorAmbient = rgb(90, 85, 110),
	Ambient = rgb(60, 58, 78),
	ExposureCompensation = 0,
	ColorShift_Top = rgb(200, 165, 190),
	Color = rgb(190, 140, 150),
	Decay = rgb(80, 80, 130),
	Glare = 0.2,
	Haze = 0.3,
})

-- The night preset from the style guide (section 9, PR #239). Haze and Glare 0 as the place had them, so the night sky
-- looks as it did.
DayLight.NIGHT = {
	ClockTime = 24.5,
	Brightness = 0.6,
	OutdoorAmbient = rgb(45, 55, 85),
	Ambient = rgb(30, 35, 55),
	ExposureCompensation = 0,
	ColorShift_Top = rgb(150, 170, 220),
	Density = 0.4,
	Color = rgb(110, 120, 160),
	Decay = rgb(60, 68, 105),
	Glare = 0,
	Haze = 0,
} :: Look

local DAY: { Key } = {
	{ at = 0, look = DayLight.SUNRISE },
	{ at = 0.12, look = DayLight.MORNING },
	{ at = 0.45, look = DayLight.MIDDAY },
	{ at = 0.75, look = DayLight.GOLDEN },
	{ at = 0.93, look = DayLight.DUSK },
	{ at = 1, look = DayLight.SUNSET },
}

-- The night is NightLengthSeconds (90): the sky falls to night in its first fifth, holds, and from 85% warms to the
-- sunrise the next day starts on (ClockTime 30.4 is 6.4 the next morning).
local NIGHT: { Key } = {
	{ at = 0, look = DayLight.SUNSET },
	{ at = 0.2, look = DayLight.NIGHT },
	{ at = 0.85, look = with(DayLight.NIGHT, { ClockTime = 28.5 }) },
	{ at = 1, look = with(DayLight.SUNRISE, { ClockTime = DayLight.SUNRISE.ClockTime + 24 }) },
}

-- How far through `phase` the clock is: 0 at its start, 1 at its end. `endsAt` is the Clock folder's PhaseEndsAt
-- and `now` the synced server time. The first day can be longer than a day; it holds at sunrise until a day is left.
function DayLight.progress(phase: string, endsAt: number, now: number): number
	local length = if phase == "night" then Config.NightLengthSeconds else Config.DayLengthSeconds
	return math.clamp(1 - (endsAt - now) / length, 0, 1)
end

-- Every field of `a` moved `alpha` of the way to `b`, ClockTime included as given.
local function mix(a: Look, b: Look, alpha: number, clockTime: number): Look
	return {
		ClockTime = clockTime,
		Brightness = a.Brightness + (b.Brightness - a.Brightness) * alpha,
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, alpha),
		Ambient = a.Ambient:Lerp(b.Ambient, alpha),
		ExposureCompensation = a.ExposureCompensation
			+ (b.ExposureCompensation - a.ExposureCompensation) * alpha,
		ColorShift_Top = a.ColorShift_Top:Lerp(b.ColorShift_Top, alpha),
		Density = a.Density + (b.Density - a.Density) * alpha,
		Color = a.Color:Lerp(b.Color, alpha),
		Decay = a.Decay:Lerp(b.Decay, alpha),
		Glare = a.Glare + (b.Glare - a.Glare) * alpha,
		Haze = a.Haze + (b.Haze - a.Haze) * alpha,
	}
end

-- The sky `progress` (0 to 1) through `phase` ("night", anything else is day).
function DayLight.at(phase: string, progress: number): Look
	local keys = if phase == "night" then NIGHT else DAY
	local p = math.clamp(progress, 0, 1)
	for i = 2, #keys do
		local before, after = keys[i - 1], keys[i]
		if p <= after.at then
			local alpha = (p - before.at) / (after.at - before.at)
			local a, b = before.look, after.look
			return mix(a, b, alpha, a.ClockTime + (b.ClockTime - a.ClockTime) * alpha)
		end
	end
	return table.clone(keys[#keys].look)
end

-- `from` moved `alpha` of the way to `to`, the sun always forward round the clock (a small step back stays small).
-- For a jump of the clock and the intro's preview.
function DayLight.blend(from: Look, to: Look, alpha: number): Look
	local a = math.clamp(alpha, 0, 1)
	local step = (to.ClockTime - from.ClockTime) % 24
	if step > 22 then
		step -= 24
	end
	return mix(from, to, a, (from.ClockTime + step * a) % 24)
end

return DayLight
