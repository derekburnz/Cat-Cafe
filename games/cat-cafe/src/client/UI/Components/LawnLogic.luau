--!strict
-- The front lawn's cards and counts (F91, front-lawn.md section 3; lawn-nursery.md section 6e) for the Decor
-- screen's Lawn chip (Screens/LawnTab). Pure: it reads the PlayerState's lawnOwned, lawn and lawnStyles with
-- shared/Lawn's own rules. Since #1283 the server lays the best owned pieces and styles by itself (LawnService,
-- Lawn.best), so the chip only shows what is out and what is stored.
--
--   live(state, lawnPath)   whether the chip shows: the plot's LawnPath attribute is set (the lawn art is in) and
--                           ProfileSync has sent the lawn
--   cards(state)                       the Lawn chip's cards (#1283): each owned piece, path and fence, highest
--                                      rarity first (#1751), then out first
--   total(state)                       its line on top: "Lawn: 6 out, +18% money", the Money boosts row's number
--   pieceAction(state, piece)          a piece's button from before #1283 (no screen shows it now)
--   styleAction(state, style)          a path or fence's button from before #1283 (no screen shows it now)
--   spotChoices(state, spotId)         the old edit view's picker rows (no screen shows them now)
--   stallRows(tab)                     the Garden Nursery's rows for "pieces", "path" or "fence" (lawn-nursery.md 2)
--   stallAction(state, row)            a nursery row's button: Buy with the price, Owned, or Opens at Tier n
--   NURSERY_LINE, nurseryNote(state)   where lawn pieces are sold
--   counts(state)                      lawn spots used and open at the cafe's tier
--   inUse(state, kind)                 the path or fence in use (nil: no fence)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local Lawn = require(Shared:WaitForChild("Lawn")) :: any

export type Mode =
	"buy" -- not owned, open at the tier: price; buys it (a piece onto a free spot, a style in use)
	| "locked" -- a later tier sells it
	| "place" -- owned, off the lawn: onto `spotId`
	| "away" -- owned, on `spotId`: back to the player's pieces
	| "full" -- owned, off the lawn, and every open spot of its size has a piece
	| "here" -- the picker: already on this spot
	| "use" -- an owned style not in use
	| "inUse" -- the path in use
	| "takeDown" -- the fence in use: no fence
	| "owned" -- the nursery: already bought

export type Action = {
	mode: Mode,
	text: string,
	style: string, -- a Button style
	enabled: boolean,
	spotId: string?, -- "place", "away" and the picker's "buy": the spot it goes on or comes off
}

export type Choice = {
	piece: Types.LawnPieceDef,
	action: Action,
	owned: boolean,
}

local LawnLogic = {}

LawnLogic.SPOTS = Lawn.SPOTS :: { Types.LawnSpot }
LawnLogic.DEFAULT_PATH = Lawn.DEFAULT_PATH :: string

-- The lawn rows of the shared catalog (empty on a build without F91).
function LawnLogic.pieces(): { Types.LawnPieceDef }
	return (Catalog.lawn or {}) :: { Types.LawnPieceDef }
end

function LawnLogic.styles(kind: string): { Types.LawnStyleDef } -- "path" or "fence"
	local out: { Types.LawnStyleDef } = {}
	for _, style in (Catalog.lawnStyles or {}) :: { Types.LawnStyleDef } do
		if style.kind == kind then
			table.insert(out, style)
		end
	end
	return out
end

function LawnLogic.getPiece(id: string): Types.LawnPieceDef?
	return Catalog.getLawn(id)
end

function LawnLogic.getStyle(id: string): Types.LawnStyleDef?
	return Catalog.getLawnStyle(id)
end

function LawnLogic.getSpot(id: string): Types.LawnSpot?
	return Lawn.getSpot(id)
end

-- The state as the profile shape shared/Lawn reads; missing fields read as an empty lawn.
local function view(state: Types.PlayerState): any
	return {
		tier = state.tier,
		lawnOwned = state.lawnOwned or {},
		lawn = state.lawn or {},
		lawnStyles = state.lawnStyles or Lawn.freshStyles(),
	}
end

function LawnLogic.live(state: Types.PlayerState?, lawnPath: any): boolean
	return state ~= nil
		and state.lawnStyles ~= nil
		and type(lawnPath) == "string"
		and lawnPath ~= ""
		and #LawnLogic.pieces() > 0
end

function LawnLogic.owns(state: Types.PlayerState, id: string): boolean
	return Lawn.owns(view(state), id)
end

-- The spot a piece stands in, or nil.
function LawnLogic.spotOf(state: Types.PlayerState, pieceId: string): string?
	return Lawn.spotOf(view(state), pieceId)
end

function LawnLogic.inUse(state: Types.PlayerState, kind: Types.LawnStyleKind): string?
	local styles = view(state).lawnStyles
	return if kind == "path" then styles.path or Lawn.DEFAULT_PATH else styles.fence
end

-- Lawn spots with a piece and lawn spots open at the cafe's tier.
function LawnLogic.counts(state: Types.PlayerState): (number, number)
	local lawn = state.lawn or {}
	local used, open = 0, 0
	for _, spot in LawnLogic.SPOTS do
		if state.tier >= spot.tier then
			open += 1
			if lawn[spot.id] ~= nil then
				used += 1
			end
		end
	end
	return used, open
end

local function buyOrLocked(
	state: Types.PlayerState,
	price: number,
	tier: number,
	spotId: string?
): Action
	if state.tier < tier then
		return {
			mode = "locked",
			text = "Tier " .. tostring(tier),
			style = "ghost",
			enabled = false,
		}
	end
	return {
		mode = "buy",
		text = "$" .. ShortNumber.format(price), -- Format.money, without Theme so the spec runner loads it
		style = "primary",
		enabled = state.money >= price,
		spotId = spotId,
	}
end

-- A piece card in the tab: Put away when it stands on the lawn, Place onto the first open spot of its size, Spots
-- full, else its price or the tier that sells it.
function LawnLogic.pieceAction(state: Types.PlayerState, piece: Types.LawnPieceDef): Action
	local profile = view(state)
	if Lawn.owns(profile, piece.id) then
		local at = Lawn.spotOf(profile, piece.id)
		if at ~= nil then
			return {
				mode = "away",
				text = "Put away",
				style = "ghost",
				enabled = true,
				spotId = at,
			}
		end
		local free = Lawn.firstFreeSpot(profile, piece.spot)
		if free ~= nil then
			return {
				mode = "place",
				text = "Place",
				style = "secondary",
				enabled = true,
				spotId = free,
			}
		end
		return {
			mode = "full",
			text = "Spots full",
			style = "ghost",
			enabled = false,
		}
	end
	return buyOrLocked(state, piece.price, piece.tier, nil)
end

-- A path or fence card: In use (the path) or Take down (the fence), Use it when owned, else its price or tier.
function LawnLogic.styleAction(state: Types.PlayerState, style: Types.LawnStyleDef): Action
	if LawnLogic.inUse(state, style.kind) == style.id then
		if style.kind == "fence" then
			return {
				mode = "takeDown",
				text = "Take down",
				style = "ghost",
				enabled = true,
			}
		end
		return {
			mode = "inUse",
			text = "In use",
			style = "ghost",
			enabled = false,
		}
	end
	if Lawn.owns(view(state), style.id) then
		return {
			mode = "use",
			text = "Use it",
			style = "primary",
			enabled = true,
		}
	end
	return buyOrLocked(state, style.price, style.tier, nil)
end

-- The picker for one open spot: the piece on it, then the other owned pieces of its size (Place, which moves one
-- off another spot). Lawn pieces are bought only at the Garden Nursery since #1200 (lawn-nursery.md section 3), so
-- the shop's pieces are no longer offered here.
function LawnLogic.spotChoices(state: Types.PlayerState, spotId: string): { Choice }
	local spot = Lawn.getSpot(spotId)
	if spot == nil then
		return {}
	end
	local profile = view(state)
	local here = profile.lawn[spotId]
	local first: { Choice } = {}
	local mine: { Choice } = {}
	for _, piece in LawnLogic.pieces() do
		if piece.spot ~= spot.size then
			continue
		end
		if piece.id == here then
			local stays: Action = {
				mode = "here",
				text = "Here",
				style = "ghost",
				enabled = false,
				spotId = spotId,
			}
			table.insert(first, { piece = piece, owned = true, action = stays })
		elseif Lawn.owns(profile, piece.id) then
			local from = Lawn.spotOf(profile, piece.id)
			local place: Action = {
				mode = "place",
				text = if from ~= nil then "Move here" else "Place",
				style = "secondary",
				enabled = true,
				spotId = spotId,
			}
			table.insert(mine, { piece = piece, owned = true, action = place })
		end
	end
	local out: { Choice } = {}
	for _, list in { first, mine } do
		for _, choice in list do
			table.insert(out, choice)
		end
	end
	return out
end

-- The Garden Nursery (#1200, lawn-nursery.md section 2) -------------------------------------------------------------

export type StallTab = "pieces" | "path" | "fence"

-- One row in the nursery window: a piece or a style for sale (the free Grey Slabs never shows).
export type StallRow = {
	id: string,
	name: string,
	model: string,
	tier: number,
	price: number,
	rarity: string,
	detail: string, -- "Small spot", "Big spot", "Path" or "Fence"
}

LawnLogic.NURSERY_LINE = "Get lawn pieces at the Garden Nursery in the Park"
LawnLogic.NURSERY_TIER = 2 -- the Park opens at Tier 2, so the nursery does too

-- Where lawn pieces are sold: the Tier 1 line names the tier that opens the Park.
function LawnLogic.nurseryNote(state: Types.PlayerState?): string
	if state ~= nil and state.tier < LawnLogic.NURSERY_TIER then
		return ("Lawn pieces are sold at the Garden Nursery in the Park (Tier %d)"):format(
			LawnLogic.NURSERY_TIER
		)
	end
	return LawnLogic.NURSERY_LINE
end

function LawnLogic.stallRows(tab: StallTab): { StallRow }
	local out: { StallRow } = {}
	if tab == "pieces" then
		for _, piece in LawnLogic.pieces() do
			local rarity: string = piece.rarity or "Common"
			local row: StallRow = {
				id = piece.id,
				name = piece.name,
				model = piece.model,
				tier = piece.tier,
				price = piece.price,
				rarity = rarity,
				detail = LawnLogic.sizeName(piece.spot),
			}
			table.insert(out, row)
		end
		return out
	end
	for _, style in LawnLogic.styles(tab) do
		if style.price <= 0 then
			continue -- Grey Slabs: every cafe has it
		end
		local rarity: string = style.rarity or "Common"
		local row: StallRow = {
			id = style.id,
			name = style.name,
			model = style.model,
			tier = style.tier,
			price = style.price,
			rarity = rarity,
			detail = if tab == "path" then "Path" else "Fence",
		}
		table.insert(out, row)
	end
	return out
end

-- A nursery row's button: Owned (grey) once bought, "Opens at Tier 3" (grey) before its tier, else Buy with the price,
-- greyed while the coins are short. The server still checks the tier, the coins and the distance to the stall.
function LawnLogic.stallAction(state: Types.PlayerState, row: StallRow): Action
	if Lawn.owns(view(state), row.id) then
		return { mode = "owned", text = "Owned", style = "ghost", enabled = false }
	end
	if state.tier < row.tier then
		return {
			mode = "locked",
			text = ("Opens at Tier %d"):format(row.tier),
			style = "ghost",
			enabled = false,
		}
	end
	return {
		mode = "buy",
		text = "$" .. ShortNumber.format(row.price),
		style = "gold",
		enabled = state.money >= row.price,
	}
end

-- 0.035 -> "3.5%", 0.18 -> "18%" (Format.percent's rule; Format needs Theme, which the pure specs leave out)
local function percent(fraction: number): string
	local value = fraction * 100
	local text = string.format(if value >= 10 or value == 0 then "%.0f" else "%.1f", value)
	return (text:gsub("%.0$", "")) .. "%"
end

-- The Lawn chip (#1283, lawn-nursery.md section 6e) ---------------------------------------------------------------

-- One card: an owned piece, path or fence, its rarity and the money it adds while out, and whether it is out now.
export type Card = {
	id: string,
	name: string,
	model: string,
	kind: string, -- "piece", "path" or "fence"
	rarity: string?, -- "Common" to "Golden"; nil for none
	bonus: number, -- the fraction it adds while out (0.03 for "+3% money")
	out: boolean, -- on a lawn spot, or the path or fence in use
}

-- Each owned piece, path and fence (not the free Grey Slabs, which adds nothing): the ones out first, then the bigger
-- bonus, then by name.
function LawnLogic.cards(state: Types.PlayerState): { Card }
	local owned = state.lawnOwned or {}
	local list: { Card } = {}
	for _, piece in LawnLogic.pieces() do
		if owned[piece.id] == true then
			table.insert(list, {
				id = piece.id,
				name = piece.name,
				model = piece.model,
				kind = "piece",
				rarity = piece.rarity :: string?,
				bonus = Lawn.rarityBonus(piece.rarity),
				out = LawnLogic.spotOf(state, piece.id) ~= nil,
			})
		end
	end
	local function addStyles(kind: Types.LawnStyleKind)
		local using = LawnLogic.inUse(state, kind)
		for _, style in LawnLogic.styles(kind) do
			if owned[style.id] == true and style.rarity ~= nil then
				table.insert(list, {
					id = style.id,
					name = style.name,
					model = style.model,
					kind = style.kind :: string,
					rarity = style.rarity :: string?,
					bonus = Lawn.rarityBonus(style.rarity),
					out = using == style.id,
				})
			end
		end
	end
	addStyles("path")
	addStyles("fence")
	-- #1751 (Derek2 11-06): highest rarity first (the bonus follows the rarity), then what is out
	table.sort(list, function(a: Card, b: Card): boolean
		if a.bonus ~= b.bonus then
			return a.bonus > b.bonus
		end
		if a.out ~= b.out then
			return a.out
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.id < b.id
	end)
	return list
end

-- The line under a card's name: "+3% money", "Path · +2% money" or "Fence · +2% money".
function LawnLogic.cardLine(card: Card): string
	local money = ("+%s money"):format(percent(card.bonus))
	if card.kind == "path" then
		return "Path · " .. money
	elseif card.kind == "fence" then
		return "Fence · " .. money
	end
	return money
end

-- The Lawn chip's line on top: "Lawn: 6 out, +18% money" (the same sum as the Money boosts row, Lawn.bonusOf), or
-- "Lawn: nothing out yet".
function LawnLogic.total(state: Types.PlayerState): string
	local v = view(state)
	local bonus, out = Lawn.bonusOf(v.lawnOwned, v.lawn, v.lawnStyles)
	if out <= 0 then
		return "Lawn: nothing out yet"
	end
	return ("Lawn: %d out, +%s money"):format(out, percent(bonus))
end

-- Where to buy more, for the grid's last card (lawn-nursery.md section 7: only the Yard Sale sells lawn pieces).
LawnLogic.SHOP_TITLE = "Find more lawn decor"
LawnLogic.SHOP_WHERE = "Yard Sale"

-- #1751 part 3 (Derek2: "lawn section is missing remove/use it buttons"): a Lawn card's one button. An out piece
-- reads Remove (SetLawnSpot(spot, "") takes it in), a stored one Use onto the first open spot of its size, or "Spots
-- full", off; the path or fence in use reads Remove (SetLawnStyle(kind, ""): Grey Slabs, no fence), another owned one
-- Use. The server (LawnService, #1758) decides and toasts any refusal.
export type CardAction = {
	text: string,
	style: string, -- a Button style
	enabled: boolean,
	spotId: string?, -- a piece: the spot it goes on or comes off
	pieceId: string?, -- a piece: its id for Use, "" for Remove
	styleKind: string?, -- a path or fence: "path" or "fence"
	styleId: string?, -- a path or fence: its id for Use, "" for Remove
}

function LawnLogic.cardAction(state: Types.PlayerState, card: Card): CardAction
	if card.kind == "piece" then
		local piece = LawnLogic.getPiece(card.id)
		local action = if piece then LawnLogic.pieceAction(state, piece) else nil
		if action ~= nil and action.mode == "away" then
			return {
				text = "Remove",
				style = "ghost",
				enabled = true,
				spotId = action.spotId,
				pieceId = "",
			}
		elseif action ~= nil and action.mode == "place" then
			return {
				text = "Use",
				style = "primary",
				enabled = true,
				spotId = action.spotId,
				pieceId = card.id,
			}
		end
		return { text = "Spots full", style = "ghost", enabled = false }
	end
	if LawnLogic.inUse(state, card.kind :: any) == card.id then
		return {
			text = "Remove",
			style = "ghost",
			enabled = true,
			styleKind = card.kind,
			styleId = "",
		}
	end
	return {
		text = "Use",
		style = "primary",
		enabled = true,
		styleKind = card.kind,
		styleId = card.id,
	}
end

-- "Small spot" or "Big spot".
function LawnLogic.sizeName(size: Types.LawnSize): string
	return if size == "big" then "Big spot" else "Small spot"
end

return LawnLogic
