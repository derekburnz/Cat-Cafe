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
-- player not in this server, is never granted here. Nothing a product holds is random. #3864: the Trait Token bundles
-- buy rolls that are, so their offer (the Mystic Pool card) is hidden where ArePaidRandomItemsRestricted holds
-- (CafeService.traitsView); a receipt that still comes is paid, since Roblox took the Robux.
-- #1625: the Starter Bundle is once per account (Catalog.products oncePerAccount, saved in profile.onceBought). Its
-- first receipt gives Sprinkles (CafeService.addGiftCat), the potions and the Bakery Stripes sign, which the sign then
-- shows; a second one, which only a prompt the Store never shows could start, pays only the potions.
-- #1626: the Cafe Pass (Catalog.products seasonPass) unlocks the paid track of the season running at the receipt, in
-- the same step as the id (CafePassService.buyPaid). With no season running it is not granted (NotProcessedYet), so
-- Roblox delivers it again once one is; the product is off sale then anyway. A second one in the same season, which
-- only a prompt the Pass screen never shows could start, changes nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Grant = require(ReplicatedStorage.Shared.Grant)
local IdeaCreditsService = require(script.Parent.IdeaCreditsService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Products = require(ReplicatedStorage.Shared.Products)
local SignStyles = require(ReplicatedStorage.Shared.SignStyles)
local Telemetry = require(script.Parent.Telemetry)
local Traits = require(ReplicatedStorage.Shared.Traits)
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

local function catCount(profile: Types.PlayerProfile): number
	local count = 0
	for _ in profile.cats do
		count += 1
	end
	return count
end

-- Pays what `product` (not the Cafe Pass) holds, with no yield: the cats first, then the once-per-account mark and
-- the sign styles, the potions (Payout, as `sku`), the supporter badge, a toast that starts with `thanks` and a sync.
-- #2127: each step runs on its own (shared/Grant), so one that throws loses only itself; if the cats throw before one
-- is added, nothing is paid and the result is undone. A receipt records its id first; owner test mode (#1770,
-- OwnerTestService) records none and passes an owner_test_ sku.
function ProductService.give(
	player: Player,
	profile: Types.PlayerProfile,
	product: Types.ProductDef,
	sku: string,
	thanks: string
): Grant.Result
	local give, first = Products.prizeFor(profile, product)
	local paid: { string } = {}
	local catsBefore = catCount(profile)
	local result = Grant.run({
		name = "cats",
		run = function()
			for _, catId in give.cats do
				local def = Catalog.getCat(catId)
				if def ~= nil then
					CafeService.addGiftCat(player, profile, def, CatStats.DEFAULT_CHARM)
				end
			end
		end,
	}, function(): boolean
		return catCount(profile) ~= catsBefore
	end, {
		{
			name = "mark",
			run = function()
				Products.markBought(profile, product, give.signStyles)
				for _, styleId in give.signStyles do
					if profile.signStyle == nil then
						profile.signStyle = styleId -- a new sign shows straight away; the Style panel can change it
					end
				end
			end,
		},
		{
			name = "potions",
			run = function()
				local prize: Types.IndexPrize = { potions = give.potions }
				for _, line in Payout.pay(player, profile, prize, sku, "Shop") do
					table.insert(paid, line)
				end
			end,
		},
		{
			-- #3864: the token bundles (Catalog.products prize.traitTokens), paid whatever the switches say, since
			-- Roblox took the Robux; a bank near Traits.TOKEN_MAX keeps only what fits (no real bank comes near it)
			name = "tokens",
			run = function()
				local count = product.prize.traitTokens
				if count ~= nil and count > 0 then
					local added = Traits.give(profile.traits, count)
					Telemetry.custom(player, "trait_token", added, { "product" })
					table.insert(paid, string.format("%d Trait Tokens", added))
				end
			end,
		},
		{
			name = "supporter",
			run = function()
				for _, styleId in give.signStyles do
					local style = SignStyles.get(styleId)
					table.insert(
						paid,
						"the " .. (if style ~= nil then style.name else styleId) .. " sign"
					)
				end
				if first and product.supporter == true then
					-- #1168 row 4: the mark is profile.onceBought (markBought); the board, chat tag and attribute follow
					IdeaCreditsService.markSupporter(player, profile)
					CafePassService.refreshTag(player, profile)
					table.insert(paid, "your gold Thank You badge")
				end
			end,
		},
		{
			name = "toast",
			run = function()
				Net.fire(player, "Toast", thanks .. table.concat(paid, ", "), "good")
			end,
		},
		{
			name = "sync",
			run = function()
				CafeService.refreshPlot(player)
				CafeService.sync(player)
			end,
		},
	})
	for index, name in result.failed do
		warn(
			string.format(
				"[ProductService] %s: the %s step failed%s: %s",
				product.id,
				name,
				if result.undone then " before anything was paid, so it is not granted yet" else "",
				result.errors[index]
			)
		)
	end
	if not first then
		warn("[ProductService] a second", product.id, "for", player.UserId, "paid only its potions")
	end
	return result
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
	if product.seasonPass == true and not Products.granted(profile.receipts, purchaseId) then
		if CafePassService.running() == 0 then
			warn("[ProductService] a Cafe Pass receipt with no season running, for", player.UserId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Products.record(profile.receipts, purchaseId)
		Telemetry.productBought(player, profile, receipt.ProductId, receipt.CurrencySpent) -- #1888
		if CafePassService.buyPaid(player, profile) then
			Net.fire(
				player,
				"Toast",
				"Thank you! The Cafe Pass paid track is yours this season",
				"good"
			)
		else
			warn("[ProductService] a second Cafe Pass this season for", player.UserId)
			Net.fire(player, "Toast", "This season's Cafe Pass is already yours", "warn")
		end
		CafePassService.send(player, profile)
		CafeService.sync(player)
	elseif not Products.granted(profile.receipts, purchaseId) then
		-- #1625: the id, the once-per-account mark, the sign styles and the cats all land in this one step, no yield
		Products.record(profile.receipts, purchaseId)
		local result =
			ProductService.give(player, profile, product, "product_" .. product.id, "Thank you! ")
		for _, step in result.failed do
			Telemetry.custom(
				player,
				"grant_failed",
				1,
				{ product.id, step, if result.undone then "retry" else "kept" }
			)
		end
		if result.undone then
			-- #2127: nothing was paid, so the id goes again and Roblox's next delivery pays the whole prize
			Products.forget(profile.receipts, purchaseId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Telemetry.productBought(player, profile, receipt.ProductId, receipt.CurrencySpent) -- #1888
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
