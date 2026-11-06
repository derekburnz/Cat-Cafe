--!strict
-- The Store funnel (#1888): what the client may report about the Store (TelemetryReport) and the funnel's steps.
-- Analytics only: the server allowlists every value here, and nothing a report says pays or unlocks anything.
--
-- One funnel session per Store visit: opened (with where it was opened from), tab_viewed (each tab, the first one
-- counts for the step), buy_pressed (a pass or product's buy button, which opens Roblox's prompt) and completed
-- (Roblox says it was bought). A prompt closed without buying is the custom event store_cancelled. The price is
-- Roblox's own, looked up on the server; prices are never tested (Derek2, #1888).
--
-- The client side: the UI calls `noteSource` just before it opens the Store, and UIController takes it (`takeSource`)
-- as the Store's screen opens, so a tap on the HUD tile, its New dot or a nudge can be told apart.

local Config = require(script.Parent.Config)
local Products = require(script.Parent.Products)

local StoreFunnel = {}

StoreFunnel.NAME = "store"
StoreFunnel.STEPS = { "opened", "tab_viewed", "buy_pressed", "completed" }
StoreFunnel.SOURCES = { "hud_tile", "new_dot", "nudge", "other" }
StoreFunnel.TABS = { "featured", "passes", "cats", "potions", "cafePass", "codes" } -- StoreLogic.TABS' ids
StoreFunnel.VISITS_MAX = 30 -- Store funnels a session; a visit past it logs nothing

local noted: string? = nil

-- The client: the place the next Store open comes from (one of SOURCES; anything else is ignored).
function StoreFunnel.noteSource(source: string)
	if table.find(StoreFunnel.SOURCES, source) ~= nil then
		noted = source
	end
end

-- The client: the source noted for this open, or "other", and clears it.
function StoreFunnel.takeSource(): string
	local source = noted or "other"
	noted = nil
	return source
end

-- "GoldenPond" -> "golden_pond"
local function snake(name: string): string
	local out = string.gsub(name, "(%l)(%u)", "%1_%2")
	return string.lower(out)
end

-- Every made pass (not 0) Config names, by id: "<name>PassId" reads "<name>", a "<name>PassIds" list "<name>_<key>".
local passSkus: { [number]: string } = {}
for key, value in Config :: any do
	if type(key) ~= "string" then
		continue
	end
	local single = string.match(key, "^(%w+)PassId$")
	local list = string.match(key, "^(%w+)PassIds$")
	if single ~= nil and type(value) == "number" and value ~= 0 then
		passSkus[value] = snake(single)
	elseif list ~= nil and type(value) == "table" then
		for index, id in value do
			if type(id) == "number" and id ~= 0 then
				passSkus[id] = snake(list) .. "_" .. tostring(index)
			end
		end
	end
end

-- Every made pass of ours, in no order.
function StoreFunnel.passIds(): { number }
	local out: { number } = {}
	for id in passSkus do
		table.insert(out, id)
	end
	return out
end

-- The analytics name of pass `passId` ("pass_vip", "pass_money_3"), or nil for an id that is not one of ours.
function StoreFunnel.passSku(passId: unknown): string?
	local name = if type(passId) == "number" then passSkus[passId] else nil
	return if name ~= nil then "pass_" .. name else nil
end

-- The analytics name of product `productId` ("product_starter_bundle"), or nil for an id Config does not name.
function StoreFunnel.productSku(productId: unknown): string?
	local def = Products.forProductId(productId)
	return if def ~= nil then "product_" .. def.id else nil
end

-- The step number of `name`, 0 for none.
function StoreFunnel.index(name: string): number
	return table.find(StoreFunnel.STEPS, name) or 0
end

return StoreFunnel
