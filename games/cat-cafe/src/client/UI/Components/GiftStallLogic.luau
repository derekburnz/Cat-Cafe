--!strict
-- The Christmas Event's Gift Stall on the client (snowglobe-village-spec section 5): what the window shows. Pure: no
-- instances, so the cloud specs run it. The server (Gameplay-Engineer's event row) decides every buy; the window only
-- reads a view:
--   View                 { snowflakes: number, items: { { id, name, cost, owned } } }, from the server's sync
--   ITEMS                the spec's 8 items in the window's order, each with its kind (tab) and picture model;
--                        their prices total TOTAL (1,800 Snowflakes)
--   defaultView(state)   the view before the server sends one: PlayerState.snowflakes (nil is 0) and nothing owned
--   rows(view, tab)      a tab's rows ("outfit" or "decor"), the view's cost and owned over ITEMS' kind and picture;
--                        a view item that ITEMS does not know shows on the Decor tab with no picture
--   flakes(view)         the Snowflakes in the view, a whole number 0 or more
--   action(view, row)    the row's button: Owned (grey), or the price, gold when affordable and grey when short

local GiftStallLogic = {}

GiftStallLogic.FLAKE = "❄"
GiftStallLogic.TOTAL = 1800

export type Tab = "outfit" | "decor"
export type ViewItem = { id: string, name: string, cost: number, owned: boolean }
export type View = { snowflakes: number?, items: { ViewItem } }
export type Item = { id: string, kind: Tab, name: string, cost: number, model: string? }
export type Row = {
	id: string,
	kind: Tab,
	name: string,
	cost: number,
	owned: boolean,
	model: string?,
}
export type Action = {
	mode: string, -- "owned", "short" or "buy"
	text: string,
	style: string, -- the Button style
	enabled: boolean,
}

GiftStallLogic.ITEMS = table.freeze({
	{
		id = "santa_hat",
		kind = "outfit",
		name = "Santa Hat",
		cost = 150,
		model = "CatCafe_Accessory_SantaHat",
	},
	{
		id = "reindeer_antlers",
		kind = "outfit",
		name = "Reindeer Antlers",
		cost = 200,
		model = "CatCafe_Accessory_ReindeerAntlers",
	},
	{
		id = "knit_beanie",
		kind = "outfit",
		name = "Knit Beanie",
		cost = 250,
		model = "CatCafe_Accessory_KnitBeanie",
	},
	{
		id = "present_pile",
		kind = "decor",
		name = "Present Pile",
		cost = 150,
		model = "CatCafe_Decor_PresentPile",
	},
	{
		id = "snowman",
		kind = "decor",
		name = "Snowman",
		cost = 200,
		model = "CatCafe_Decor_Snowman",
	},
	{
		id = "gingerbread_house",
		kind = "decor",
		name = "Gingerbread House",
		cost = 250,
		model = "CatCafe_Decor_GingerbreadHouse",
	},
	{
		id = "stocking_wall",
		kind = "decor",
		name = "Stocking Wall",
		cost = 250,
		model = "CatCafe_Decor_StockingWall",
	},
	{
		id = "little_tree",
		kind = "decor",
		name = "Little Lit Tree",
		cost = 350,
		model = "CatCafe_Decor_LittleLitTree",
	},
} :: { Item })

local function known(id: string): Item?
	for _, item in GiftStallLogic.ITEMS do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function whole(n: unknown): number
	return if type(n) == "number" and n == n then math.max(0, math.floor(n)) else 0
end

function GiftStallLogic.defaultView(state: any): View
	local count = if type(state) == "table" then state.snowflakes else nil
	local items: { ViewItem } = {}
	for _, item in GiftStallLogic.ITEMS do
		table.insert(items, { id = item.id, name = item.name, cost = item.cost, owned = false })
	end
	return { snowflakes = whole(count), items = items }
end

function GiftStallLogic.flakes(view: View?): number
	return if view ~= nil then whole(view.snowflakes) else 0
end

function GiftStallLogic.rows(view: View, tab: Tab): { Row }
	local out: { Row } = {}
	for _, entry in view.items do
		if type(entry) == "table" and type(entry.id) == "string" then
			local item = known(entry.id)
			local kind: Tab = if item ~= nil then item.kind else "decor"
			if kind == tab then
				table.insert(out, {
					id = entry.id,
					kind = kind,
					name = if type(entry.name) == "string"
						then entry.name
						elseif item then item.name
						else entry.id,
					cost = whole(entry.cost),
					owned = entry.owned == true,
					model = if item ~= nil then item.model else nil,
				})
			end
		end
	end
	return out
end

function GiftStallLogic.owns(view: View?, id: string): boolean
	if view == nil then
		return false
	end
	for _, entry in view.items do
		if type(entry) == "table" and entry.id == id then
			return entry.owned == true
		end
	end
	return false
end

function GiftStallLogic.action(view: View?, row: Row): Action
	if row.owned then
		return { mode = "owned", text = "Owned", style = "ghost", enabled = false }
	end
	local price = ("%s %d"):format(GiftStallLogic.FLAKE, row.cost)
	if GiftStallLogic.flakes(view) < row.cost then
		return { mode = "short", text = price, style = "ghost", enabled = false }
	end
	return { mode = "buy", text = price, style = "gold", enabled = true }
end

return GiftStallLogic
