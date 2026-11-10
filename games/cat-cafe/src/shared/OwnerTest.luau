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

-- #2754: whether a chat line is the owner's `/event` test command ("/event" alone or "/event ..."), any case. Read by
-- both chat paths in OwnerTestService.
function OwnerTest.isEventCommand(text: unknown): boolean
	if type(text) ~= "string" then
		return false
	end
	local lower = string.lower(text)
	return lower == "/event" or string.sub(lower, 1, 7) == "/event "
end

-- #2754: whether a command from `userId` with `text` at `now` repeats `last` (the one answered before) within
-- `window` seconds, so a line two chat paths both deliver is answered once.
function OwnerTest.isRepeat(
	last: { userId: number, text: string, at: number }?,
	userId: number,
	text: string,
	now: number,
	window: number
): boolean
	return last ~= nil and last.userId == userId and last.text == text and now - last.at < window
end

return OwnerTest
