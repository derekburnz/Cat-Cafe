--!strict
-- Developer products (#1182 step 1; monetization-policy, remote-security-checklist). Owns
-- MarketplaceService.ProcessReceipt, which Roblox calls on the server for every Robux purchase of a product and
-- again until it is answered PurchaseGranted. There is no remote: the client only opens Roblox's own purchase prompt,
-- and Roblox, not the client, tells this server what was bought.
--
-- A receipt is granted once per PurchaseId (shared/Products): the id is recorded in profile.receipts and the
-- product's fixed potions are paid in the same step, with no yield between, so two deliveries of one receipt can
-- never both pay. The answer is PurchaseGranted only after a save holding the id has reached the DataStore; until
-- then it is NotProcessedYet, and Roblox delivers the receipt again (at the player's next join, in whichever server),
-- where the recorded id pays nothing and only the save is waited for. A product id Config does not name, or a
-- player not in this server, is never granted here. Nothing a product holds is random, so no PolicyService check
-- applies (ArePaidRandomItemsRestricted is for paid random items).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Products = require(ReplicatedStorage.Shared.Products)
local Types = require(ReplicatedStorage.Shared.Types)

local ProductService = {}

local LOAD_WAIT_SECONDS = 20 -- how long a receipt waits for a joining player's profile to load
local SAVE_WAIT_SECONDS = 30 -- how long it waits for the save that holds its id

-- The player's profile, waiting up to LOAD_WAIT_SECONDS while it loads; nil if they leave or it never loads.
local function profileOf(player: Player): Types.PlayerProfile?
	local deadline = os.clock() + LOAD_WAIT_SECONDS
	local profile = DataService.get(player)
	while profile == nil and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.5)
		profile = DataService.get(player)
	end
	return profile
end

-- Saves the profile and waits for a save whose data holds `purchaseId`; true once one has.
local function saveHolding(player: Player, purchaseId: string): boolean
	local saved = false
	local watching = DataService.whenSaved(player, function(data: any): boolean
		return type(data) == "table"
			and type(data.receipts) == "table"
			and table.find(data.receipts, purchaseId) ~= nil
	end, function()
		saved = true
	end)
	if not watching then
		return false
	end
	DataService.save(player)
	local deadline = os.clock() + SAVE_WAIT_SECONDS
	while not saved and os.clock() < deadline do
		task.wait(0.25)
	end
	return saved
end

-- The ProcessReceipt answer for one receipt (see the header).
function ProductService.processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = receipt.PurchaseId
	local product = Products.forProductId(receipt.ProductId)
	if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > Products.ID_BYTES then
		warn("[ProductService] receipt without a usable PurchaseId")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product == nil then
		warn("[ProductService] receipt for a product id Config does not name:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = if type(receipt.PlayerId) == "number"
		then Players:GetPlayerByUserId(receipt.PlayerId)
		else nil
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = profileOf(player)
	if profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not Products.granted(profile.receipts, purchaseId) then
		Products.record(profile.receipts, purchaseId)
		local prize: Types.IndexPrize = { potions = product.prize.potions }
		local paid = Payout.pay(player, profile, prize, "product_" .. product.id, "Shop")
		Net.fire(player, "Toast", "Thank you! " .. table.concat(paid, ", "), "good")
		CafeService.sync(player)
	end
	if saveHolding(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProductService.start()
	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(ProductService.processReceipt, receipt)
		if ok then
			return decision
		end
		warn("[ProductService] receipt failed: " .. tostring(decision))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return ProductService
