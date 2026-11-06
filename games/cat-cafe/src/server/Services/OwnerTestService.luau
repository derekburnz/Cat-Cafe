--!strict
-- Owner test mode on the server (#1770, Monetization-Agent's policy; shared/OwnerTest). For a player in
-- Config.OwnerTestUserIds, keyed by user id and decided here only:
-- - the player gets the OwnerTest attribute, so their client shows "Owner test mode" and sends OwnerGrant in place of
--   Roblox's purchase prompt (PassService counts every made pass as owned for them);
-- - OwnerGrant(productId) grants a made product through the normal grant path (ProductService.give, or the Cafe
--   Pass's CafePassService.buyPaid) with no receipt record and no Robux, the potions paid under an owner_test_ sku;
-- - every grant, and every OwnerGrant from anyone else, is logged in the server output.
-- Nothing a product holds can be traded (OwnerTest.tradeableIn, OwnerTest.spec), and grants never reach the Thank
-- You board, which lists idea credits only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local ProductService = require(script.Parent.ProductService)
local Products = require(ReplicatedStorage.Shared.Products)

local OwnerTestService = {}

local function mark(player: Player)
	if OwnerTest.isOwner(player.UserId) then
		player:SetAttribute(OwnerTest.ATTRIBUTE, true)
		print(
			string.format(
				"[OwnerTest] %d (%s) joined in owner test mode",
				player.UserId,
				player.Name
			)
		)
	end
end

local function onOwnerGrant(player: Player, rawProductId: unknown)
	if not OwnerTest.isOwner(player.UserId) then
		warn(
			string.format(
				"[OwnerTest] OwnerGrant from %d, who is not an owner: dropped",
				player.UserId
			)
		)
		return
	end
	local product = Products.forProductId(rawProductId)
	if product == nil then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if product.seasonPass == true then
		if CafePassService.running() == 0 then
			Net.toast(player, "Owner test mode: no Cafe Pass season is running", "warn")
			return
		end
		local unlocked = CafePassService.buyPaid(player, profile)
		print(
			string.format(
				"[OwnerTest] %d granted %s (no receipt, no Robux): %s",
				player.UserId,
				product.id,
				if unlocked then "paid track unlocked" else "already unlocked"
			)
		)
		Net.toast(
			player,
			if unlocked
				then "Owner test mode: the Cafe Pass paid track is unlocked"
				else "Owner test mode: this season's paid track is already unlocked",
			"good"
		)
		CafePassService.send(player, profile)
		CafeService.sync(player)
		return
	end
	print(
		string.format("[OwnerTest] %d granted %s (no receipt, no Robux)", player.UserId, product.id)
	)
	ProductService.give(
		player,
		profile,
		product,
		OwnerTest.SKU_PREFIX .. product.id,
		"Owner test mode: "
	)
end

function OwnerTestService.start()
	Net.on("OwnerGrant", onOwnerGrant)
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

return OwnerTestService
