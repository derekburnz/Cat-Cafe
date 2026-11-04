--!strict
-- Developer product receipts (#1182 step 1), pure. ProductService grants a receipt once: its PurchaseId goes into
-- profile.receipts before the prize is paid, so a receipt Roblox delivers again (after a failed save, a rejoin or a
-- server hop) finds the id and pays nothing. The list keeps the newest RECEIPT_LIMIT ids; Roblox stops resending a
-- receipt once it is answered PurchaseGranted, which happens only after a save holding its id.
--
-- Roblox terms: a developer product is a Robux purchase that can be bought again (a game pass is bought once).
-- MarketplaceService.ProcessReceipt is the server callback Roblox calls for each one; PurchaseId names that purchase.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Products = {}

Products.RECEIPT_LIMIT = 100
Products.ID_BYTES = 64 -- a PurchaseId is a short hex string; anything longer in a save is damage
-- The only potions a Robux item may hold (monetization-policy, decision 2026-11-01 22:42): never ones that change
-- odds or bait speed (Lucky, Gold Rush, Quick Bait).
local ALLOWED: { [string]: boolean } =
	{ big_tip_potion = true, swift_potion = true, steady_potion = true }
Products.ALLOWED_POTIONS = table.freeze(ALLOWED)

-- A saved receipts list made whole: strings of 1 to ID_BYTES bytes, no repeats, the newest RECEIPT_LIMIT.
function Products.sanitize(raw: unknown): { string }
	local list: { string } = {}
	if type(raw) ~= "table" then
		return list
	end
	local seen: { [string]: boolean } = {}
	for _, id in raw :: { any } do
		if type(id) == "string" and #id > 0 and #id <= Products.ID_BYTES and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	while #list > Products.RECEIPT_LIMIT do
		table.remove(list, 1)
	end
	return list
end

function Products.granted(receipts: { string }, purchaseId: string): boolean
	return table.find(receipts, purchaseId) ~= nil
end

-- Marks `purchaseId` granted (newest last), dropping the oldest past RECEIPT_LIMIT. Already there: no change.
function Products.record(receipts: { string }, purchaseId: string)
	if Products.granted(receipts, purchaseId) then
		return
	end
	table.insert(receipts, purchaseId)
	while #receipts > Products.RECEIPT_LIMIT do
		table.remove(receipts, 1)
	end
end

-- The product a Roblox product id sells, or nil for an id Config does not name (or a 0, a product not made yet).
function Products.forProductId(productId: unknown): Types.ProductDef?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for id, made in Config.ProductIds do
		if made == productId then
			return Catalog.getProduct(id)
		end
	end
	return nil
end

return Products
