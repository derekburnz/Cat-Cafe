--!strict
-- The player's saved settings (data-model section 14 `settings`; Derek 2026-10-27: a settings menu with music,
-- volume, screen shake and the like). One table of keys says what each holds, so SetSetting, the save migration
-- and the client all validate the same way. Pure.
-- Switches are booleans. Volumes are numbers from 0 to 1, kept to two decimals so a slider cannot bloat the save.

local Types = require(script.Parent.Types)

local Settings = {}

export type Kind = "switch" | "volume"

-- key -> what it holds; every key the profile saves
Settings.kinds = {
	music = "switch", -- music on or off
	sfx = "switch", -- sound effects, ambience and UI sounds on or off
	musicVolume = "volume",
	sfxVolume = "volume",
	screenShake = "switch", -- camera shake on shoves, catches and the like
	lowPerformance = "switch", -- fewer particles, lights and far details on weak devices
	showOtherCats = "switch", -- other players' cats in their cafes and in their arms
	markers = "switch", -- the location markers (the Settings screen's Place icons)
} :: { [string]: Kind }

function Settings.defaults(): Types.Settings
	return {
		music = true,
		sfx = true,
		musicVolume = 1,
		sfxVolume = 1,
		screenShake = true,
		lowPerformance = false,
		showOtherCats = true,
		markers = true,
	}
end

-- The value to save for `key`, or nil when the key is unknown or the value does not fit it. A volume is clamped to
-- 0 to 1 and rounded to two decimals; NaN and infinities are refused.
function Settings.clean(key: unknown, value: unknown): (boolean | number)?
	local kind = if type(key) == "string" then Settings.kinds[key] else nil
	if kind == "switch" then
		return if type(value) == "boolean" then value else nil
	elseif kind == "volume" then
		if
			type(value) ~= "number"
			or value ~= value
			or value == math.huge
			or value == -math.huge
		then
			return nil
		end
		return math.floor(math.clamp(value, 0, 1) * 100 + 0.5) / 100
	end
	return nil
end

-- A saved settings table made whole: every key present, every value valid, anything else dropped.
function Settings.sanitize(raw: unknown): Types.Settings
	local settings = Settings.defaults()
	if type(raw) == "table" then
		local out = settings :: any
		for key in Settings.kinds do
			local value = Settings.clean(key, (raw :: any)[key])
			if value ~= nil then
				out[key] = value
			end
		end
	end
	return settings
end

-- A copy for ProfileSync, so the client never holds the profile's own table.
function Settings.copy(settings: Types.Settings): Types.Settings
	return table.clone(settings)
end

return Settings
