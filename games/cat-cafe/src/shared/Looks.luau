--!strict
-- Cafe looks (#1624, store-pass-looks.md), pure: the cafe theme, the staff uniform and the cats' accessory a player
-- picks on the Decor window's Style tab, which they own, and what shows. A look is owned through a pass (looked up
-- each session, so nothing is saved for it) or, for the Cafe Pass's season uniform colours and accessories, through
-- profile.pass.items (kept forever). profile.looks = { theme, uniform, accessory } holds the picks, nil for the default (Classic); a pick the player no longer owns
-- shows the default. Every look is cosmetic: the money of the Cafe Style, Grand Cafe and Uniform Styles passes is in
-- Economy (economy-ladder.md section 6a) and never depends on what is picked.
--   owned(kind, ownsPass, items) -> { id }          every owned id of `kind`, in list order
--   shown(kind, pick, ownsPass, items) -> id?       the pick if it is owned, else nil (the default)
--   pickFor(kind, raw, ownsPass, items) -> (ok, id?) what SetLook may save: the default, or an owned id
--   sanitize(raw) -> Picks                          saved picks made whole (known ids only)
-- CafeService puts the theme (THEME_ATTRIBUTE and its models), the uniform (UNIFORM_ATTRIBUTE), the accessory
-- (ACCESSORY_ATTRIBUTE) and the VIP plate (VIP_PLATE_ATTRIBUTE and its model) on the owner's plot.

local Config = require(script.Parent.Config)

local Looks = {}

export type Kind = "theme" | "uniform" | "accessory"
export type Rgb = { number }
-- A theme's models, each placed at the plot pivot (themes.py, signstyles.py): `front` the outside pieces, `sign` the
-- theme's own name sign (with a SignBoard), shown while no sign style is picked, and `inside` the extra inside pieces.
-- `alsoKey` names a second pass that gives the theme as a look only (#1822: the King Cat Pack's Grand look; the Grand
-- Cafe pass's money and job slot stay on GrandThemePassId in Economy).
export type Theme = {
	id: string,
	name: string,
	passKey: string,
	alsoKey: string?,
	front: string,
	sign: string,
	inside: { string },
}
-- A uniform style: the colour of every job's outfit pieces (`main`) and their trim. `passKey` names the pass that
-- gives it; a Cafe Pass season colour has none and is owned through profile.pass.items.
export type Uniform = { id: string, name: string, passKey: string?, main: Rgb, trim: Rgb }
-- A cat accessory (store-pass-looks.md section 6): `piece` is the CatCafe_Accessory_<piece> model, worn at the cat's
-- Outfit_<piece> Attachment, and `slot` the data-model prop slot it fills. `passKey` names the pass that gives it; a
-- Cafe Pass piece has none and is owned through profile.pass.items.
-- #2109: "Tail" is a slot no cat's own prop uses, so a Tail piece shows on every working cat.
export type Slot = "Head" | "Face" | "Back" | "Tail"
-- #4026: `at` names the cat's Outfit_<at> Attachment when the piece is made for an existing spot (the packs' pieces
-- sit at Outfit_Glasses or Outfit_Hat, so no cat model changes); nil uses Outfit_<piece>.
export type Accessory = {
	id: string,
	name: string,
	passKey: string?,
	piece: string,
	slot: Slot,
	at: string?,
}
export type Picks = { theme: string?, uniform: string?, accessory: string? }

local KINDS: { Kind } = { "theme", "uniform", "accessory" }
table.freeze(KINDS)
Looks.KINDS = KINDS
Looks.DEFAULT = "default" -- the Style tab's Classic; "" and nil mean the same
Looks.THEME_ATTRIBUTE = "Theme"
Looks.UNIFORM_ATTRIBUTE = "UniformStyle"
Looks.ACCESSORY_ATTRIBUTE = "Accessory" -- on the plot and on each dressed working cat: the Looks accessory id
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
		alsoKey = "KingPackPassId",
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
	-- #4026: the outfit packs' uniforms (storepacks.py UNIFORM_COLOURS)
	{
		id = "uniform_club_suit",
		name = "Club Suit",
		passKey = "StylishPackPassId",
		main = { 40, 38, 48 },
		trim = { 242, 193, 78 },
	},
	{
		id = "uniform_winter_coat",
		name = "Winter Coat",
		passKey = "WinterPackPassId",
		main = { 196, 48, 56 },
		trim = { 250, 248, 244 },
	},
	{
		id = "uniform_chef_whites",
		name = "Chef Whites",
		passKey = "ChefPackPassId",
		main = { 250, 248, 242 },
		trim = { 92, 62, 44 },
	},
	{
		id = "uniform_space_suit",
		name = "Space Suit",
		passKey = "SpacePackPassId",
		main = { 222, 228, 240 },
		trim = { 96, 200, 180 },
	},
}
for _, uniform in UNIFORMS do
	table.freeze(uniform)
end
table.freeze(UNIFORMS)
Looks.UNIFORMS = UNIFORMS

-- Section 6: the Cat Accessories pass gives the Tail Bow and Round Glasses; the Cafe Pass pieces (cafe-pass.md
-- section 3) are looks only. The pass's +15% is in Economy and never depends on the pick.
-- #2109 (store-pass-looks.md 6a, Derek2 2026-11-07: "replace the tiny hat with something else"): the Tail Bow took the
-- Tiny Hat's place, as a cat's own head prop kept the hat off about half the working cats. A saved "hat" reads as
-- "tail_bow" (RENAMED); the CatCafe_Accessory_Hat model stays in the Assets folder, unused.
local ACCESSORIES: { Accessory } = {
	{
		id = "tail_bow",
		name = "Tail Bow",
		passKey = "CatAccessoriesPassId",
		piece = "TailBow", -- CatCafe_Accessory_TailBow at the cat's Outfit_TailBow Attachment
		slot = "Tail",
	},
	{
		id = "glasses",
		name = "Round Glasses",
		passKey = "CatAccessoriesPassId",
		piece = "Glasses",
		slot = "Face",
	},
	{ id = "acc_leaf_beret", name = "Leaf Beret", piece = "LeafBeret", slot = "Head" },
	-- #1883 part C: the Cafe Pass's level 31 (Model-Agent's #1921, the Outfit_LeafCrown slot)
	{ id = "acc_leaf_crown", name = "Autumn Leaf Crown", piece = "LeafCrown", slot = "Head" },
	{ id = "acc_mushroom_cap", name = "Mushroom Cap", piece = "MushroomCap", slot = "Head" },
	{
		id = "acc_acorn_hair_clip",
		name = "Acorn Hair Clip",
		piece = "AcornHairClip",
		slot = "Head",
	},
	{
		id = "acc_round_reading_glasses",
		name = "Round Reading Glasses",
		piece = "ReadingGlasses",
		slot = "Face",
	},
	{ id = "acc_tiny_lantern", name = "Tiny Lantern", piece = "TinyLantern", slot = "Back" },
	-- #4026: the outfit packs' wearables (storepacks.py ACCESSORY_SLOTS), on the face or the head only
	{
		id = "acc_cool_shades",
		name = "Cool Shades",
		passKey = "StylishPackPassId",
		piece = "CoolShades",
		slot = "Face",
		at = "Glasses",
	},
	{
		id = "acc_bobble_hat",
		name = "Bobble Hat",
		passKey = "WinterPackPassId",
		piece = "WinterBobble",
		slot = "Head",
		at = "Hat",
	},
	{
		id = "acc_chef_hat",
		name = "Chef Hat",
		passKey = "ChefPackPassId",
		piece = "PackChefHat",
		slot = "Head",
		at = "Hat",
	},
	{
		id = "acc_bubble_helmet",
		name = "Bubble Helmet",
		passKey = "SpacePackPassId",
		piece = "BubbleHelmet",
		slot = "Head",
		at = "Hat",
	},
}
for _, accessory in ACCESSORIES do
	table.freeze(accessory)
end
table.freeze(ACCESSORIES)
Looks.ACCESSORIES = ACCESSORIES

local themesById: { [string]: Theme } = {}
for _, theme in THEMES do
	themesById[theme.id] = theme
end
local uniformsById: { [string]: Uniform } = {}
for _, uniform in UNIFORMS do
	uniformsById[uniform.id] = uniform
end
local accessoriesById: { [string]: Accessory } = {}
for _, accessory in ACCESSORIES do
	accessoriesById[accessory.id] = accessory
end

function Looks.theme(id: string): Theme?
	return themesById[id]
end

function Looks.uniform(id: string): Uniform?
	return uniformsById[id]
end

-- #2109: retired accessory ids and the id that took their place, for saves and old clients.
local RENAMED: { [string]: string } = { hat = "tail_bow" }
Looks.RENAMED_ACCESSORIES = table.freeze(RENAMED)

-- The accessory id `id` stands for now: a retired one's replacement, else itself.
local function current(id: string): string
	return RENAMED[id] or id
end

function Looks.accessory(id: string): Accessory?
	return accessoriesById[current(id)]
end

-- #4026: the name of the cat Attachment `accessory` is worn at: Outfit_<at>, else Outfit_<piece>.
function Looks.attachmentOf(accessory: Accessory): string
	return "Outfit_" .. (accessory.at or accessory.piece)
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
	if kind == "theme" then
		return themesById[id] ~= nil
	elseif kind == "uniform" then
		return uniformsById[id] ~= nil
	end
	return accessoriesById[id] ~= nil
end

-- Whether a uniform or accessory is owned: through its pass while `passKey` names one, else through `items`.
local function has(
	id: string,
	passKey: string?,
	ownsPass: (passId: number) -> boolean,
	items: { [string]: boolean }
): boolean
	if passKey ~= nil then
		local passId = passIdOf(passKey)
		return passId ~= 0 and ownsPass(passId)
	end
	return items[id] == true
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
			local alsoId = passIdOf(theme.alsoKey)
			if (passId ~= 0 and ownsPass(passId)) or (alsoId ~= 0 and ownsPass(alsoId)) then
				table.insert(ids, theme.id)
			end
		end
	elseif kind == "uniform" then
		for _, uniform in UNIFORMS do
			if has(uniform.id, uniform.passKey, ownsPass, items) then
				table.insert(ids, uniform.id)
			end
		end
	else
		for _, accessory in ACCESSORIES do
			if has(accessory.id, accessory.passKey, ownsPass, items) then
				table.insert(ids, accessory.id)
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
	if kind ~= "theme" and kind ~= "uniform" and kind ~= "accessory" then
		return false, nil
	end
	if raw == nil or raw == "" or raw == Looks.DEFAULT then
		return true, nil
	end
	if type(raw) ~= "string" then
		return false, nil
	end
	local k: Kind = if kind == "theme"
		then "theme"
		elseif kind == "uniform" then "uniform"
		else "accessory"
	local id = if k == "accessory" then current(raw :: string) else raw :: string -- #2109: an old client's "hat"
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
	local accessory = t.accessory
	return {
		theme = if type(theme) == "string" and themesById[theme] ~= nil then theme else nil,
		uniform = if type(uniform) == "string" and uniformsById[uniform] ~= nil
			then uniform
			else nil,
		accessory = if type(accessory) == "string"
				and accessoriesById[current(accessory)] ~= nil
			then current(accessory)
			else nil,
	}
end

return Looks
