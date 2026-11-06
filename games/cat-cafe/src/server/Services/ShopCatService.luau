--!strict
-- The shop-only cats on game passes (#1447, shared/ShopCats): Duchess Marzipan on the Royal Cat pass and King
-- Croissant on the King Cat Pack. At each join (DataService.onLoaded) and whenever PassService learns of a pass
-- (a purchase in game, or a join lookup that failed and then answered), every cat whose pass the player owns and
-- that is not in their cafe is given with CafeService.addGiftCat: level 1, base coat, charm 50 (exactly 1.0x, so it
-- earns just like its rarity from the newest area), in a free role slot or resting in the cat room. Nothing is
-- saved: owning the pass is the record, so a cat is never given twice while it is home. Logs `shop_cat`.
-- #1822: at the same moments, a King Cat Pack owner who has not had the pack's gift (shared/KingPack) gets the Royal
-- Velvet Booth and Potion Pack M's potions, once per account (profile.onceBought), so owners from before the pack held
-- them get them on their next join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local KingPack = require(ReplicatedStorage.Shared.KingPack)
local Net = require(script.Parent.Net)
local PassService = require(script.Parent.PassService)
local Payout = require(script.Parent.Payout)
local ShopCats = require(ReplicatedStorage.Shared.ShopCats)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local ShopCatService = {}

local function give(player: Player)
	local profile = DataService.get(player)
	if profile == nil or player.Parent ~= Players then
		return
	end
	local catIds = ShopCats.toGive(profile, function(passId: number): boolean
		return PassService.owns(player, passId)
	end)
	for _, catId in catIds do
		local def = Catalog.getCat(catId)
		if def ~= nil then
			CafeService.addGiftCat(player, profile, def, CatStats.DEFAULT_CHARM)
			Telemetry.custom(player, "shop_cat", 1, { catId })
		end
	end
	-- #1822: the mark, the booth and the potions land in one step, no yield
	local potions = KingPack.gift(profile, PassService.owns(player, KingPack.passId()))
	if potions ~= nil then
		local prize: Types.IndexPrize = { potions = potions }
		local paid = Payout.pay(player, profile, prize, "king_cat_pack", "Shop")
		table.insert(paid, 1, "the Royal Velvet Booth")
		Net.fire(player, "Toast", "King Cat Pack: " .. table.concat(paid, ", "), "good")
		CafeService.sync(player)
	end
end

function ShopCatService.start()
	-- deferred, so the cafe's own join set-up (CafeService's onLoaded) is done before a cat joins it
	DataService.onLoaded:Connect(function(player: Player)
		task.defer(give, player)
	end)
	PassService.changed:Connect(function(player: Player)
		task.defer(give, player)
	end)
end

return ShopCatService
