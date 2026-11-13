--!strict
-- #3699 (Derek 2026-11-12: "let people customize their bag color at the featured shop anytime let them change the
-- purple and pink to different colors"; Design-Agent's picks on the issue): the Backpack's owner picks one of twelve
-- colours for the bag's main part (purple today) and one for its trim (pink today), free, as often as they like.
-- The server keeps two ids from LIST and nothing else (SetBagColours); every player sees the worn bag in them.
--
-- The model's parts carry no names for this, but its purples and pinks are a small fixed set of colours, so a part
-- is known by the colour it was built with (slotOf): the two purples are "main", the three pinks "trim". A part
-- keeps its own light or dark step under a new pick (shade), and the default ids put the built colours back
-- exactly, so nobody's bag changes on the day this ships.
--
-- Saved as profile.bagColours ({ main, trim }, nil while both are the defaults). No VERSION bump: an older server
-- dropping it only loses a colour pick, and the `bagColours` switch goes on after a restart that carries this code.
-- Pure but for tint, which only sets part colours.

local BagColours = {}

BagColours.FLAG = "bagColours"
BagColours.ITEM = "backpack" -- the Mystery Market item that must be owned
BagColours.DEFAULT_MAIN = "plum"
BagColours.DEFAULT_TRIM = "rose"
BagColours.WORDS = {
	title = "Bag colours",
	main = "Bag",
	trim = "Trim",
	save = "Save",
	reset = "Reset",
	open = "Colours",
	locked = "Get the Backpack to pick its colours",
}
BagColours.TELEMETRY = "bag_colours"

export type Slot = "main" | "trim"
export type Row = { id: string, name: string, color: Color3 }
export type Picks = { main: string, trim: string }

-- Design-Agent's twelve, in the order the swatches show. `plum` and `rose` are the built bag's own colours. No pure
-- black, no neon, no gold or rainbow (those looks belong to gold and rainbow cats). Model-Agent tunes the values.
BagColours.LIST = {
	{ id = "plum", name = "Plum", color = Color3.fromHex("9479BE") },
	{ id = "rose", name = "Rose", color = Color3.fromHex("E07A8C") },
	{ id = "berry", name = "Berry Red", color = Color3.fromHex("C8434F") },
	{ id = "pumpkin", name = "Pumpkin", color = Color3.fromHex("E8873A") },
	{ id = "honey", name = "Honey Yellow", color = Color3.fromHex("EBC24A") },
	{ id = "cream", name = "Cream", color = Color3.fromHex("F1E4C8") },
	{ id = "sky", name = "Sky Blue", color = Color3.fromHex("7DBFE8") },
	{ id = "navy", name = "Navy", color = Color3.fromHex("3D4F8F") },
	{ id = "mint", name = "Mint", color = Color3.fromHex("8FD3C1") },
	{ id = "forest", name = "Forest Green", color = Color3.fromHex("4F8F5A") },
	{ id = "cocoa", name = "Cocoa Brown", color = Color3.fromHex("8A5E44") },
	{ id = "charcoal", name = "Charcoal", color = Color3.fromHex("4A4650") },
} :: { Row }

local BY_ID: { [string]: Row } = {}
for _, row in BagColours.LIST do
	BY_ID[row.id] = row
end

-- The colours the bag is built with (CatCafe_Item_Backpack), by slot. The first of each is the slot's own colour,
-- the one a pick replaces; the others are its lighter steps.
BagColours.BUILT = {
	main = { Color3.fromHex("9479BE"), Color3.fromHex("C9B8E8") },
	trim = { Color3.fromHex("E07A8C"), Color3.fromHex("F28FAA"), Color3.fromHex("F6B9CB") },
} :: { [string]: { Color3 } }

local NEAR = 0.02 -- a colour channel this close is the same colour (the model file rounds to four places)
local BASE_ATTRIBUTE = "BagBuilt" -- a tinted part's built colour, so a later pick or Reset starts from it

function BagColours.row(id: unknown): Row?
	return if type(id) == "string" then BY_ID[id] else nil
end

function BagColours.valid(id: unknown): boolean
	return BagColours.row(id) ~= nil
end

-- A save's or a remote's picks: two known ids, or nil for anything else and for the two defaults (nothing to keep).
function BagColours.sanitize(raw: unknown): Picks?
	if type(raw) ~= "table" then
		return nil
	end
	local main, trim = (raw :: any).main, (raw :: any).trim
	if not BagColours.valid(main) or not BagColours.valid(trim) then
		return nil
	end
	if main == BagColours.DEFAULT_MAIN and trim == BagColours.DEFAULT_TRIM then
		return nil
	end
	return { main = main, trim = trim }
end

-- The picks in force for a saved value: the defaults where nothing is saved.
function BagColours.picks(saved: Picks?): Picks
	return {
		main = if saved ~= nil and BagColours.valid(saved.main)
			then saved.main
			else BagColours.DEFAULT_MAIN,
		trim = if saved ~= nil and BagColours.valid(saved.trim)
			then saved.trim
			else BagColours.DEFAULT_TRIM,
	}
end

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) <= NEAR
		and math.abs(a.G - b.G) <= NEAR
		and math.abs(a.B - b.B) <= NEAR
end

-- Which slot a part built in `built` belongs to, nil for the bag's cream, gold and mint parts.
function BagColours.slotOf(built: Color3): Slot?
	for _, color in BagColours.BUILT.main do
		if same(built, color) then
			return "main"
		end
	end
	for _, color in BagColours.BUILT.trim do
		if same(built, color) then
			return "trim"
		end
	end
	return nil
end

-- Hue, saturation and value of a colour, each 0 to 1 (written out so the cloud tests' Color3 stand-in runs it).
local function toHSV(color: Color3): (number, number, number)
	local r, g, b = color.R, color.G, color.B
	local high, low = math.max(r, g, b), math.min(r, g, b)
	local span = high - low
	local h = 0
	if span > 0 then
		if high == r then
			h = ((g - b) / span) % 6
		elseif high == g then
			h = (b - r) / span + 2
		else
			h = (r - g) / span + 4
		end
		h /= 6
	end
	return h, if high > 0 then span / high else 0, high
end

local function fromHSV(h: number, s: number, v: number): Color3
	local sector = (h % 1) * 6
	local index = math.floor(sector)
	local f = sector - index
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	if index == 0 then
		return Color3.new(v, t, p)
	elseif index == 1 then
		return Color3.new(q, v, p)
	elseif index == 2 then
		return Color3.new(p, v, t)
	elseif index == 3 then
		return Color3.new(p, q, v)
	elseif index == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

-- How light a colour is, 0 to 1 (its value).
function BagColours.value(color: Color3): number
	local _, _, v = toHSV(color)
	return v
end

-- The colour of a part built in `built` once its slot is picked as `pick`: the pick's hue, with the part's own step
-- lighter or paler than the slot's colour kept. The slot's own colour comes out as the pick exactly.
function BagColours.shade(built: Color3, slot: Slot, pick: Color3): Color3
	local own = BagColours.BUILT[slot][1]
	if same(built, own) then
		return pick
	end
	local _, ownS, ownV = toHSV(own)
	local _, builtS, builtV = toHSV(built)
	local h, s, v = toHSV(pick)
	local paler = if ownS > 0 then builtS / ownS else 1
	local lighter = if ownV > 0 then builtV / ownV else 1
	-- a lighter step also moves toward white, so a dark pick's light parts still read lighter
	local lift = math.clamp(lighter - 1, 0, 1)
	return fromHSV(h, math.clamp(s * paler, 0, 1), math.clamp(v + (1 - v) * lift * 1.6, 0, 1))
end

-- What a part built in `built` shows under `picks`: its built colour for the default of its slot and for parts of
-- no slot.
function BagColours.colorFor(built: Color3, picks: Picks): Color3
	local slot = BagColours.slotOf(built)
	if slot == nil then
		return built
	end
	local id = if slot == "main" then picks.main else picks.trim
	local default = if slot == "main" then BagColours.DEFAULT_MAIN else BagColours.DEFAULT_TRIM
	local row = BY_ID[id]
	if row == nil or id == default then
		return built
	end
	return BagColours.shade(built, slot :: any, row.color) -- the old solver reads `slot` as a plain string here
end

-- Colours every part of `pack` (a worn or shown Backpack) for `picks`. Safe to call again with other picks: each
-- part remembers the colour it was built with. Returns how many parts it coloured.
function BagColours.tint(pack: Instance, picks: Picks): number
	local count = 0
	for _, descendant in pack:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part: any = descendant -- typed loosely: the old checker reads the narrowed Color as read-only
			local built: Color3? = part:GetAttribute(BASE_ATTRIBUTE)
			if built == nil then
				local color: Color3 = part.Color
				if BagColours.slotOf(color) == nil then
					continue
				end
				part:SetAttribute(BASE_ATTRIBUTE, color)
				built = color
			end
			part.Color = BagColours.colorFor(built :: Color3, picks)
			count += 1
		end
	end
	return count
end

return BagColours
