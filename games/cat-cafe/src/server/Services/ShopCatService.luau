--!strict
-- The shop-only cats on game passes (#1447, shared/ShopCats): Duchess Marzipan on the Royal Cat pass and King
-- Croissant on the King Cat Pack. At each join (DataService.onLoaded) and whenever PassService learns of a pass
-- (a purchase in game, or a join lookup that failed and then answered), every cat whose pass the player owns and
-- that is not in their cafe is given with CafeService.addGiftCat: level 1, base coat, charm 50 (exactly 1.0x, so it
-- earns just like its rarity from the newest area), in a free role slot or resting in the cat room. Nothing is
-- saved: owning the pass is the record, so a cat is never given twice while it is home. Logs `shop_cat`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local ShopCats = require(ReplicatedStorage.Shared.ShopCats)
local Telemetry = require(script.Parent.Telemetry)

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
