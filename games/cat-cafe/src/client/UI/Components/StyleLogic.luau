--!strict
-- The Decor window's Style tab (#1624, store-pass-looks.md): what the player can pick for the whole cafe, pure so the
-- specs can check it. One row per kind the player owns something for:
--   sign      the cafe's name sign: Plain or an owned shared/SignStyles style (#1625: Bakery Stripes from the Starter
--             Bundle, Royal Crest from the King Cat Pack); PlayerState.signStyles and signStyle, SetSignStyle(id?)
--   uniform   every job's uniform: Classic or an owned style (the Uniform Styles pass, Cafe Pass colours)
--   accessory the working cats' accessory (#1708, Cat Accessories pass and Cafe Pass pieces): None or an owned one
--   theme     the cafe's theme: Classic, Garden (Cafe Style pass) or Grand (Grand Cafe Theme)
--   music     the cafe's music (#1875: free for everyone): the day and night mix or a shared/Jukebox song;
--             PlayerState.jukeboxTracks (every song) and jukebox, SetJukeboxTrack(id or "default")
-- Uniforms, accessories and themes read PlayerState.looks = { theme, uniform, accessory, themes, uniforms,
-- accessories } once the server sends it (SetLook);
-- until then those rows stay hidden. A row shows only when the player owns more than the default, so the tab (and its
-- chip) shows only for a player with something to pick.
--   StyleLogic.rows(state, signNames?)   the rows, each with its options and which one is picked
--   StyleLogic.shows(state)              whether the Style chip shows
--   StyleLogic.icon(kind, id)            the symbol beside an option (#2007)
--   StyleLogic.inUse(row)                the row's title with the option in use, "Cafe sign: Royal Crest" (#2007)

local StyleLogic = {}

export type Kind = "sign" | "uniform" | "accessory" | "theme" | "music"
export type Option = {
	id: string, -- "" is the default (the plain sign, Classic)
	name: string,
	icon: string, -- #2007: a symbol beside the name, so the player sees what each option is
	picked: boolean,
}
export type Row = { kind: Kind, title: string, options: { Option } }

StyleLogic.DEFAULT = ""

-- Names until the catalog names them: the sign styles (shared/SignStyles), the uniform styles and themes
-- (store-pass-looks.md), and the Cafe Pass's season colours (cafe-pass.md section 3).
local NAMES: { [string]: string } = {
	bakery_stripes = "Bakery Stripes",
	royal_crest = "Royal Crest",
	-- #2007: the Sign Style Pack and Cafe Pass signs read "Pack Flower Box" and the like until named here
	frame_golden_leaf = "Golden Leaf",
	sign_maple_board = "Maple Board",
	pack_flower_box = "Flower Box",
	pack_starry_night = "Starry Night",
	pack_paw_chalkboard = "Paw Chalkboard",
	striped = "Striped",
	midnight = "Midnight",
	mint = "Mint",
	garden = "Garden",
	grand = "Grand",
	uniform_pumpkin = "Pumpkin",
	uniform_acorn_brown = "Acorn Brown",
	uniform_forest_green = "Forest Green",
	uniform_cranberry = "Cranberry",
	-- #1708: shared/Looks.ACCESSORIES
	hat = "Tiny Hat",
	glasses = "Round Glasses",
	acc_leaf_beret = "Leaf Beret",
	acc_leaf_crown = "Autumn Leaf Crown",
	acc_mushroom_cap = "Mushroom Cap",
	acc_acorn_hair_clip = "Acorn Hair Clip",
	acc_round_reading_glasses = "Round Reading Glasses",
	acc_tiny_lantern = "Tiny Lantern",
	-- #1168 row 2: shared/Jukebox.TRACKS (the spec keeps these in step)
	jukebox_rainy_window = "Rainy Window",
	jukebox_catnap_waltz = "Catnap Waltz",
	jukebox_bakery_bounce = "Bakery Bounce",
	jukebox_starlight_purr = "Starlight Purr",
	shuffle = "Shuffle", -- #2077: shared/Jukebox.SHUFFLE
}

-- #2007 (Derek2: "put symbols beside each one so it knows what player is equipping"): a symbol per option. Only
-- emoji from before Unicode 12, which Roblox's font draws (🪴 and 🪧 draw blank, #2015).
local ICONS: { [string]: string } = {
	bakery_stripes = "🧁",
	royal_crest = "👑",
	frame_golden_leaf = "🍂",
	sign_maple_board = "🍁",
	pack_flower_box = "🌸",
	pack_starry_night = "⭐",
	pack_paw_chalkboard = "🐾",
	garden = "🌿",
	grand = "🏛️",
	hat = "🎩",
	glasses = "👓",
	acc_leaf_beret = "🍃",
	acc_leaf_crown = "🍁",
	acc_mushroom_cap = "🍄",
	acc_acorn_hair_clip = "🌰",
	acc_round_reading_glasses = "👓",
	acc_tiny_lantern = "🏮",
	jukebox_rainy_window = "🌧️",
	jukebox_catnap_waltz = "💤",
	jukebox_bakery_bounce = "🥐",
	jukebox_starlight_purr = "🌟",
	shuffle = "🔀",
}

-- the default option's symbol, and the symbol for an owned id with none of its own
local DEFAULT_ICONS: { [Kind]: string } = {
	sign = "⬜",
	uniform = "👔",
	accessory = "❌",
	theme = "☕",
	music = "🎶",
}
local KIND_ICONS: { [Kind]: string } = {
	sign = "🏷️",
	uniform = "👕",
	accessory = "🎀",
	theme = "🏠",
	music = "🎵",
}

function StyleLogic.icon(kind: Kind, id: string): string
	if id == StyleLogic.DEFAULT or id == "default" then
		return DEFAULT_ICONS[kind]
	end
	return ICONS[id] or KIND_ICONS[kind]
end

local TITLES: { [Kind]: string } = {
	sign = "Cafe sign",
	uniform = "Uniforms",
	accessory = "Cat accessory",
	theme = "Cafe theme",
	music = "Cafe music",
}

local DEFAULT_NAMES: { [Kind]: string } = {
	sign = "Plain",
	uniform = "Classic",
	accessory = "None",
	theme = "Classic",
	music = "Day and night mix",
}

-- "acorn_brown" reads "Acorn Brown" when nothing names it.
local function titled(id: string): string
	local words: { string } = {}
	for _, word in id:split("_") do
		if word ~= "" then
			table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
		end
	end
	return table.concat(words, " ")
end

function StyleLogic.name(id: string, names: { [string]: string }?): string
	return (if names then names[id] else nil) or NAMES[id] or titled(id)
end

-- One row: the default first, then each owned id once (the default left out), the pick marked. A pick that is not
-- owned shows the default picked, as the server shows it.
local function row(kind: Kind, owned: { string }, pick: string?, names: { [string]: string }?): Row?
	local seen: { [string]: boolean } = { [StyleLogic.DEFAULT] = true, default = true }
	local ids: { string } = {}
	for _, id in owned do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return nil
	end
	local picked = if pick ~= nil
			and pick ~= "default"
			and table.find(ids, pick) ~= nil
		then pick
		else StyleLogic.DEFAULT
	local options: { Option } = {
		{
			id = StyleLogic.DEFAULT,
			name = DEFAULT_NAMES[kind],
			icon = DEFAULT_ICONS[kind],
			picked = picked == StyleLogic.DEFAULT,
		},
	}
	for _, id in ids do
		table.insert(options, {
			id = id,
			name = StyleLogic.name(id, names),
			icon = StyleLogic.icon(kind, id),
			picked = picked == id,
		})
	end
	return { kind = kind, title = TITLES[kind], options = options }
end

function StyleLogic.rows(state: any, names: { [string]: string }?): { Row }
	local out: { Row } = {}
	if type(state) ~= "table" then
		return out
	end
	local signs: { string } = if type(state.signStyles) == "table" then state.signStyles else {}
	local sign = row("sign", signs, state.signStyle, names)
	if sign then
		table.insert(out, sign)
	end
	local looks = state.looks
	if type(looks) == "table" then
		local uniforms: { string } = if type(looks.uniforms) == "table" then looks.uniforms else {}
		local uniform = row("uniform", uniforms, looks.uniform, names)
		if uniform then
			table.insert(out, uniform)
		end
		-- #1708: next to the uniform, as Design wants
		local accessories: { string } = if type(looks.accessories) == "table"
			then looks.accessories
			else {}
		local accessory = row("accessory", accessories, looks.accessory, names)
		if accessory then
			table.insert(out, accessory)
		end
		local themes: { string } = if type(looks.themes) == "table" then looks.themes else {}
		local theme = row("theme", themes, looks.theme, names)
		if theme then
			table.insert(out, theme)
		end
	end
	-- #1168 row 2: last, as it changes what you hear rather than what you see
	local tracks: { string } = if type(state.jukeboxTracks) == "table"
		then state.jukeboxTracks
		else {}
	-- #2077: Shuffle right after the mix, while the client can play it (state.jukeboxShuffle is its id)
	if type(state.jukeboxShuffle) == "string" and #tracks > 0 then
		tracks = table.clone(tracks)
		table.insert(tracks, 1, state.jukeboxShuffle)
	end
	local music = row("music", tracks, state.jukebox, names)
	if music then
		table.insert(out, music)
	end
	return out
end

-- #2147 (store-pass-looks.md 7.4): a small line under a row, so picking "None" never looks like losing the bonus.
-- StyleTab shows the accessory one only while the Cat Accessories pass is owned.
StyleLogic.NOTES = {
	accessory = "+15% money on every working cat, whatever you pick",
} :: { [string]: string }

function StyleLogic.inUse(row: Row): string
	for _, option in row.options do
		if option.picked then
			return ("%s: %s %s"):format(row.title, option.icon, option.name)
		end
	end
	return row.title
end

function StyleLogic.shows(state: any): boolean
	return #StyleLogic.rows(state) > 0
end

return StyleLogic
