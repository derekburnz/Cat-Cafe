--!strict
-- The Settings screen's rows and what each switch shows (UI plan 2026-10-27, wave 2). Pure: no Theme, so the
-- cloud spec runner can load it.
--
-- Every setting is on until the player turns it off. A tap shows at once and fires events.setSetting; the
-- switch then follows the saved value from ProfileSync. While the server has not caught up (HOLD_SECONDS) the
-- tap wins, and a key the server does not save yet (`markers` until the engineer adds it) keeps the tap for
-- the session.

export type Row = {
	key: string,
	icon: string,
	name: string,
	detail: string,
}

export type Tap = { value: boolean, at: number }

local SettingsList = {}

SettingsList.HOLD_SECONDS = 5

SettingsList.ROWS = {
	{
		key = "music",
		icon = "🎵",
		name = "Music",
		detail = "Cafe tunes by day, the night song after dark",
	},
	{
		key = "sfx",
		icon = "🔊",
		name = "Sound effects",
		detail = "Meows, coins, buttons and the street",
	},
	{
		key = "markers",
		icon = "📍",
		name = "Place icons",
		detail = "Icons over My Cafe, the areas and the cart",
	},
} :: { Row }

function SettingsList.isKey(key: unknown): boolean
	for _, row in SettingsList.ROWS do
		if row.key == key then
			return true
		end
	end
	return false
end

-- The saved value, or nil when the server sends no settings or does not save this key yet.
function SettingsList.saved(settings: { [string]: unknown }?, key: string): boolean?
	if settings == nil then
		return nil
	end
	local value = settings[key]
	if value == nil then
		return nil
	end
	return value ~= false
end

-- What the switch shows: a fresh tap until the server agrees or HOLD_SECONDS pass, a tap on a key the server
-- does not save for the rest of the session, else the saved value, else on.
function SettingsList.shown(
	settings: { [string]: unknown }?,
	taps: { [string]: Tap },
	key: string,
	now: number
): boolean
	local saved = SettingsList.saved(settings, key)
	local tap = taps[key]
	if saved == nil then
		return if tap then tap.value else true
	end
	if tap and tap.value ~= saved and now - tap.at < SettingsList.HOLD_SECONDS then
		return tap.value
	end
	return saved
end

return SettingsList
