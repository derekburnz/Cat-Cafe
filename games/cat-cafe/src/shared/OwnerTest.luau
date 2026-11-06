--!strict
-- Owner test mode (#1770, Monetization-Agent's policy): lets the game's owner test passes and products in the live game
-- without spending Robux. Only the server decides who is an owner (Config.OwnerTestUserIds, by user id); the client
-- reads the player attribute ATTRIBUTE, set by OwnerTestService, to show LABEL to that player and to send OwnerGrant
-- in place of Roblox's purchase prompt. A grant writes no receipt record and pays through the normal grant path, and
-- everything a product holds is untradeable (`tradeableIn` lists anything that is not; OwnerTest.spec keeps it empty).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local OwnerTest = {}

OwnerTest.ATTRIBUTE = "OwnerTest"
OwnerTest.LABEL = "Owner test mode"
OwnerTest.SKU_PREFIX = "owner_test_" -- Payout's sku for a grant, kept apart from "product_" sales

-- Whether `userId` is in owner test mode. Server only decides with it.
function OwnerTest.isOwner(userId: unknown): boolean
	if type(userId) ~= "number" or userId <= 0 then
		return false
	end
	return table.find(Config.OwnerTestUserIds, userId) ~= nil
end

-- What `product` gives that a trade could move: its cats that are not exclusive. Sign styles and potions never
-- trade, and the Cafe Pass's paid track pays only what CafePass's own rewards give.
function OwnerTest.tradeableIn(product: Types.ProductDef): { string }
	local out: { string } = {}
	local cats: { string } = product.prize.cats or {}
	for _, catId in cats do
		local def = Catalog.getCat(catId)
		if def == nil or def.exclusive ~= true then
			table.insert(out, catId)
		end
	end
	return out
end

return OwnerTest
