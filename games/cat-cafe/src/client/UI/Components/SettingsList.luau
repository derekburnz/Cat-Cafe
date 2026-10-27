--!strict
-- The Settings screen's rows and what each one shows (UI plan 2026-10-27, wave 2; Derek 2026-10-27: volume,
-- screen shake and the like). Pure: no Theme, so the cloud spec runner can load it.
--
-- Switches hold booleans and volumes numbers from 0 to 1 (shared/Settings, which also gives each key's default:
-- Low performance starts off, everything else on and at full volume). A tap or a slider release shows at once and
-- fires events.setSetting; the row then follows the saved value from ProfileSync. While the server has not caught
-- up (HOLD_SECONDS) the player's choice wins, and a key the server does not send keeps it for the session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

export type Kind = "switch" | "volume"

export type Row = {
	key: string,
	kind: Kind,
	icon: string,
	name: string,
	detail: string,
}

export type Section = { title: string, rows: { Row } }

export type Tap = { value: boolean | number, at: number }

local SettingsList = {}

SettingsList.HOLD_SECONDS = 5
SettingsList.VOLUME_STEPS = 20 -- a slider moves in 5% steps, so the saved two decimals match what it shows

SettingsList.SECTIONS = {
	{
		title = "Sound",
		rows = {
			{
				key = "music",
				kind = "switch",
				icon = "🎵",
				name = "Music",
				detail = "Cafe tunes by day, the night song after dark",
			},
			{
				key = "musicVolume",
				kind = "volume",
				icon = "🎚️",
				name = "Music volume",
				detail = "",
			},
			{
				key = "sfx",
				kind = "switch",
				icon = "🔊",
				name = "Sound effects",
				detail = "Meows, coins, buttons and the street",
			},
			{
				key = "sfxVolume",
				kind = "volume",
				icon = "🔉",
				name = "Sound volume",
				detail = "",
			},
		},
	},
	{
		title = "Screen",
		rows = {
			{
				key = "screenShake",
				kind = "switch",
				icon = "📳",
				name = "Screen shake",
				detail = "The camera bump on shoves and catches",
			},
			{
				key = "lowPerformance",
				kind = "switch",
				icon = "🐢",
				name = "Low performance",
				detail = "Fewer sparkles, lights and far details",
			},
			{
				key = "showOtherCats",
				kind = "switch",
				icon = "🐈",
				name = "Other players' cats",
				detail = "Cats in other cafes and in other arms",
			},
			{
				key = "markers",
				kind = "switch",
				icon = "📍",
				name = "Place icons",
				detail = "Icons over My Cafe, the areas and the cart",
			},
		},
	},
} :: { Section }

-- Every row in screen order.
SettingsList.ROWS = {} :: { Row }
for _, section in SettingsList.SECTIONS do
	for _, row in section.rows do
		table.insert(SettingsList.ROWS, row)
	end
end

local DEFAULTS = Settings.defaults() :: any

function SettingsList.isKey(key: unknown): boolean
	for _, row in SettingsList.ROWS do
		if row.key == key then
			return true
		end
	end
	return false
end

function SettingsList.kind(key: string): Kind?
	for _, row in SettingsList.ROWS do
		if row.key == key then
			return row.kind
		end
	end
	return nil
end

-- What a key shows before the server sends it (shared/Settings.defaults, N122).
function SettingsList.default(key: string): boolean | number
	local value = DEFAULTS[key]
	if SettingsList.kind(key) == "volume" then
		return if type(value) == "number" then value else 1
	end
	return value ~= false
end

-- A volume as the slider holds it: 0 to 1 in 5% steps (dividing, so 0.35 is exactly the number 0.35).
function SettingsList.step(volume: number): number
	local steps = SettingsList.VOLUME_STEPS
	return math.clamp(math.floor(volume * steps + 0.5), 0, steps) / steps
end

-- "75%"
function SettingsList.percent(volume: number): string
	return ("%d%%"):format(math.floor(volume * 100 + 0.5))
end

-- The saved value, or nil when the server sends no settings or no usable value for this key.
function SettingsList.saved(settings: { [string]: unknown }?, key: string): (boolean | number)?
	if settings == nil then
		return nil
	end
	local value = settings[key]
	if value == nil then
		return nil
	end
	if SettingsList.kind(key) == "volume" then
		return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else nil
	end
	return value ~= false
end

local function same(a: boolean | number, b: boolean | number): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 0.001
	end
	return a == b
end

-- What the row shows: a fresh choice until the server agrees or HOLD_SECONDS pass, a choice on a key the server
-- does not send for the rest of the session, else the saved value, else the default.
function SettingsList.shown(
	settings: { [string]: unknown }?,
	taps: { [string]: Tap },
	key: string,
	now: number
): boolean | number
	local saved = SettingsList.saved(settings, key)
	local tap = taps[key]
	if saved == nil then
		return if tap then tap.value else SettingsList.default(key)
	end
	if tap and not same(tap.value, saved) and now - tap.at < SettingsList.HOLD_SECONDS then
		return tap.value
	end
	return saved
end

return SettingsList
