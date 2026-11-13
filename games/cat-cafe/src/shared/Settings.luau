--!strict
-- The player's saved settings (data-model section 14 `settings`; Derek 2026-10-27: a settings menu with music,
-- volume, screen shake and the like). One table of keys says what each holds, so SetSetting, the save migration
-- and the client all validate the same way. Pure.
-- Switches are booleans. Volumes are numbers from 0 to 1, kept to two decimals so a slider cannot bloat the save.
-- Choices are one of a short list of strings (Settings.choices).

local Types = require(script.Parent.Types)

local Settings = {}

export type Kind = "switch" | "volume" | "choice"

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
	tutorialButton = "switch", -- the HUD's Tutorial tile that replays the intro (F72); its x turns this off
	-- F94 (rewards-and-shops.md section 3): the Fresh Catch's ShopAlert for a Gold Rush Potion (no crate since #1051)
	shopAlerts = "switch",
	-- F102 (trading.md section 2): who may ask to trade (TradeService reads it on each request)
	tradeRequests = "choice",
	roadmapOpen = "switch", -- #1893: the Grand Opening strip opened into its list (remembered)
	sessionRecap = "switch", -- #1920: the session recap card after about 40 minutes of play
	-- #1955 (auto-equip.md): Equip Best runs by itself after a new or better cat. On for new accounts; a save from
	-- before it has no value and reads as off until the player turns it on (Settings.sanitize)
	autoEquip = "switch",
	-- #2551 (Derek2 11-09: "a toggle to turn it off"): the "+$3/s" rate tags over working cats in every cafe (UI
	-- WorldTags). On by default, as they always showed; a save from before it has no value and reads as on
	catIncome = "switch",
	-- #2714 (Derek2 11-09: "let you shrink down your goal so they have more screen space"): the HUD's goal card folded
	-- into its one-line chip (touch only reads it). Off by default, so new players see their goal
	goalFolded = "switch",
	-- #3940 (Derek 2026-11-13: "mystic pool remembers your filter settings for working/etc and keeps them next time you
	-- open"): the pick-a-cat list's Sort, its direction and the Show chips that are on (CatPickLogic.packShown)
	catPickSort = "choice",
	catPickFlipped = "switch",
	catPickShow = "choice",
} :: { [string]: Kind }

-- #3940: every way the four Show chips can be on, as CatPickLogic.packShown writes them (chip names in this order,
-- joined by commas; "" for none, which is All)
local SHOW_CHIPS = { "Working", "Resting", "No trait", "Has trait" }
local showChoices: { string } = {}
for mask = 0, 2 ^ #SHOW_CHIPS - 1 do
	local on: { string } = {}
	for index, chip in SHOW_CHIPS do
		if bit32.btest(mask, 2 ^ (index - 1)) then
			table.insert(on, chip)
		end
	end
	table.insert(showChoices, table.concat(on, ","))
end

-- A choice key -> the strings it takes, the default first.
Settings.choices = {
	tradeRequests = { "everyone", "friends", "off" },
	catPickSort = { "Money", "Level", "Rarity" }, -- CatPickLogic.MENU_SORTS, Money the default
	catPickShow = showChoices,
} :: { [string]: { string } }

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
		tutorialButton = true,
		shopAlerts = true,
		tradeRequests = "everyone",
		roadmapOpen = false,
		sessionRecap = true,
		autoEquip = true,
		catIncome = true,
		goalFolded = false,
		catPickSort = "Money",
		catPickFlipped = false,
		catPickShow = "",
	}
end

-- The value to save for `key`, or nil when the key is unknown or the value does not fit it. A volume is clamped to
-- 0 to 1 and rounded to two decimals; NaN and infinities are refused. A choice takes one of its strings exactly.
function Settings.clean(key: unknown, value: unknown): (boolean | number | string)?
	local kind = if type(key) == "string" then Settings.kinds[key] else nil
	if kind == "choice" then
		local options = Settings.choices[key :: string]
		return if type(value) == "string"
				and options ~= nil
				and table.find(options, value) ~= nil
			then value
			else nil
	elseif kind == "switch" then
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
		settings.autoEquip = false -- #1955: a save from before Auto Equip starts with it off
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
