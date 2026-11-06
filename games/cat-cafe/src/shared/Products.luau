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
local KingPack = require(script.Parent.KingPack)
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

-- #1625: what a receipt for `product` gives `profile`: the whole prize the first time, and for a once-per-account
-- product already bought only its potions (a second purchase can only come from a prompt the Store never shows, and
-- the Robux are not taken for nothing). `first` says which. Pure; ProductService pays it and calls markBought.
function Products.prizeFor(
	profile: Types.PlayerProfile,
	product: Types.ProductDef
): ({
	potions: { [string]: number },
	cats: { string },
	signStyles: { string },
}, boolean)
	local first = not (product.oncePerAccount == true and profile.onceBought[product.id] == true)
	local cats: { string } = {}
	local styles: { string } = {}
	local prizeCats: { string } = product.prize.cats or {}
	local prizeStyles: { string } = product.prize.signStyles or {}
	if first then
		for _, catId in prizeCats do
			table.insert(cats, catId)
		end
		for _, styleId in prizeStyles do
			table.insert(styles, styleId)
		end
	end
	return { potions = product.prize.potions, cats = cats, signStyles = styles }, first
end

-- #1625: notes a once-per-account product bought and its sign styles owned, in the same step as the receipt.
function Products.markBought(
	profile: Types.PlayerProfile,
	product: Types.ProductDef,
	signStyles: { string }
)
	if product.oncePerAccount == true then
		profile.onceBought[product.id] = true
	end
	for _, styleId in signStyles do
		profile.signStyles[styleId] = true
	end
end

-- #1625: a saved onceBought set made whole: known once-per-account product ids set to true, and (#1822) the King
-- Cat Pack's gift mark.
function Products.sanitizeOnce(raw: unknown): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) == "table" then
		for id, value in raw :: { [any]: any } do
			if type(id) == "string" and value == true then
				local product = Catalog.getProduct(id)
				if id == KingPack.MARK or (product ~= nil and product.oncePerAccount == true) then
					out[id] = true
				end
			end
		end
	end
	return out
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
