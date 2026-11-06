--!strict
-- Cafe looks (#1624, store-pass-looks.md), pure: the cafe theme and the staff uniform a player picks on the Decor
-- window's Style tab, which they own, and what shows. A look is owned through a pass (looked up each session, so
-- nothing is saved for it) or, for the Cafe Pass's season uniform colours, through profile.pass.items (kept forever).
-- profile.looks = { theme, uniform } holds the picks, nil for the default (Classic); a pick the player no longer owns
-- shows the default. Every look is cosmetic: the money of the Cafe Style, Grand Cafe and Uniform Styles passes is in
-- Economy (economy-ladder.md section 6a) and never depends on what is picked.
--   owned(kind, ownsPass, items) -> { id }          every owned id of `kind`, in list order
--   shown(kind, pick, ownsPass, items) -> id?       the pick if it is owned, else nil (the default)
--   pickFor(kind, raw, ownsPass, items) -> (ok, id?) what SetLook may save: the default, or an owned id
--   sanitize(raw) -> { theme, uniform }             saved picks made whole (known ids only)
-- CafeService puts the theme (THEME_ATTRIBUTE and its models), the uniform (UNIFORM_ATTRIBUTE) and the VIP plate
-- (VIP_PLATE_ATTRIBUTE and its model) on the owner's plot.

local Config = require(script.Parent.Config)

local Looks = {}

export type Kind = "theme" | "uniform"
export type Rgb = { number }
-- A theme's models, each placed at the plot pivot (themes.py, signstyles.py): `front` the outside pieces, `sign` the
-- theme's own name sign (with a SignBoard), shown while no sign style is picked, and `inside` the extra inside pieces.
export type Theme = {
	id: string,
	name: string,
	passKey: string,
	front: string,
	sign: string,
	inside: { string },
}
-- A uniform style: the colour of every job's outfit pieces (`main`) and their trim. `passKey` names the pass that
-- gives it; a Cafe Pass season colour has none and is owned through profile.pass.items.
export type Uniform = { id: string, name: string, passKey: string?, main: Rgb, trim: Rgb }
export type Picks = { theme: string?, uniform: string? }

local KINDS: { Kind } = { "theme", "uniform" }
table.freeze(KINDS)
Looks.KINDS = KINDS
Looks.DEFAULT = "default" -- the Style tab's Classic; "" and nil mean the same
Looks.THEME_ATTRIBUTE = "Theme"
Looks.UNIFORM_ATTRIBUTE = "UniformStyle"
Looks.VIP_PLATE_ATTRIBUTE = "VipPlate"
Looks.VIP_PLATE_MODEL = "CatCafe_Plot_SignVipPlate" -- #1650: the gold plate with a paw, under the name on the sign

local THEMES: { Theme } = {
	{
		id = "garden",
		name = "Garden",
		passKey = "CafeStylePassId",
		front = "CatCafe_Plot_ThemeGarden",
		sign = "CatCafe_Plot_SignGarden",
		inside = {},
	},
	{
		id = "grand",
		name = "Grand",
		passKey = "GrandThemePassId",
		front = "CatCafe_Plot_ThemeGrand",
		sign = "CatCafe_Plot_SignGrand",
		inside = { "CatCafe_Plot_ThemeGrandChandelier" },
	},
}
for _, theme in THEMES do
	table.freeze(theme.inside)
	table.freeze(theme)
end
table.freeze(THEMES)
Looks.THEMES = THEMES

-- Colours from the Cozy Cream palette (docs/art/style-guide.md): Striped is cream with caramel, Midnight navy with
-- gold, Mint mint with cream (store-pass-looks.md section 2); the season colours (cafe-pass.md section 3) trim cream.
local CREAM: Rgb = { 246, 235, 221 }
local UNIFORMS: { Uniform } = {
	{
		id = "striped",
		name = "Striped",
		passKey = "UniformStylesPassId",
		main = CREAM,
		trim = { 201, 138, 75 },
	},
	{
		id = "midnight",
		name = "Midnight",
		passKey = "UniformStylesPassId",
		main = { 47, 62, 92 },
		trim = { 242, 193, 78 },
	},
	{
		id = "mint",
		name = "Mint",
		passKey = "UniformStylesPassId",
		main = { 143, 211, 193 },
		trim = CREAM,
	},
	{ id = "uniform_pumpkin", name = "Pumpkin", main = { 217, 102, 46 }, trim = CREAM },
	{ id = "uniform_acorn_brown", name = "Acorn Brown", main = { 160, 104, 58 }, trim = CREAM },
	{ id = "uniform_forest_green", name = "Forest Green", main = { 63, 111, 94 }, trim = CREAM },
	{ id = "uniform_cranberry", name = "Cranberry", main = { 142, 42, 74 }, trim = CREAM },
}
for _, uniform in UNIFORMS do
	table.freeze(uniform)
end
table.freeze(UNIFORMS)
Looks.UNIFORMS = UNIFORMS

local themesById: { [string]: Theme } = {}
for _, theme in THEMES do
	themesById[theme.id] = theme
end
local uniformsById: { [string]: Uniform } = {}
for _, uniform in UNIFORMS do
	uniformsById[uniform.id] = uniform
end

function Looks.theme(id: string): Theme?
	return themesById[id]
end

function Looks.uniform(id: string): Uniform?
	return uniformsById[id]
end

-- The pass id Config holds under `key`, or 0 (not made, or no key).
local function passIdOf(key: string?): number
	if key == nil then
		return 0
	end
	local id = (Config :: any)[key]
	return if type(id) == "number" then id else 0
end
Looks.passIdOf = passIdOf

local function known(kind: Kind, id: string): boolean
	return if kind == "theme" then themesById[id] ~= nil else uniformsById[id] ~= nil
end

-- Every owned id of `kind`, in list order: a pass look while `ownsPass` says the player has its pass, a season colour
-- while `items` (profile.pass.items) holds it.
function Looks.owned(
	kind: Kind,
	ownsPass: (passId: number) -> boolean,
	items: { [string]: boolean }
): { string }
	local ids: { string } = {}
	if kind == "theme" then
		for _, theme in THEMES do
			local passId = passIdOf(theme.passKey)
			if passId ~= 0 and ownsPass(passId) then
				table.insert(ids, theme.id)
			end
		end
	else
		for _, uniform in UNIFORMS do
			local has = if uniform.passKey ~= nil
				then passIdOf(uniform.passKey) ~= 0 and ownsPass(passIdOf(uniform.passKey))
				else items[uniform.id] == true
			if has then
				table.insert(ids, uniform.id)
			end
		end
	end
	return ids
end

-- The look of `kind` that shows: the pick while it is owned, else nil (the default).
function Looks.shown(
	kind: Kind,
	pick: string?,
	ownsPass: (passId: number) -> boolean,
	items: { [string]: boolean }
): string?
	if pick == nil or not known(kind, pick) then
		return nil
	end
	return if table.find(Looks.owned(kind, ownsPass, items), pick) ~= nil then pick else nil
end

-- What SetLook(kind, raw) may save (the remote's whole check): nil, "" or "default" is the default (ok, nil); an
-- owned id of `kind` is (ok, id); anything else (an id not owned, an unknown id or kind, a non-string) is refused
-- (false, nil).
function Looks.pickFor(
	kind: unknown,
	raw: unknown,
	ownsPass: (passId: number) -> boolean,
	items: { [string]: boolean }
): (boolean, string?)
	if kind ~= "theme" and kind ~= "uniform" then
		return false, nil
	end
	if raw == nil or raw == "" or raw == Looks.DEFAULT then
		return true, nil
	end
	if type(raw) ~= "string" then
		return false, nil
	end
	local k: Kind = if kind == "theme" then "theme" else "uniform"
	local id = raw :: string
	if not known(k, id) or table.find(Looks.owned(k, ownsPass, items), id) == nil then
		return false, nil
	end
	return true, id
end

-- Saved picks made whole: a known id of each kind, else nil.
function Looks.sanitize(raw: unknown): Picks
	local t: { [any]: any } = if type(raw) == "table" then raw :: any else {}
	local theme = t.theme
	local uniform = t.uniform
	return {
		theme = if type(theme) == "string" and themesById[theme] ~= nil then theme else nil,
		uniform = if type(uniform) == "string" and uniformsById[uniform] ~= nil
			then uniform
			else nil,
	}
end

return Looks
