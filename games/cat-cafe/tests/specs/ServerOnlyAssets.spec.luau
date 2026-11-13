--!strict
-- The templates only the server clones (#3743): area kit sets and backdrop rings are kept out of
-- ReplicatedStorage, everything a client looks up stays in it.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Layout = require(ServerScriptService.Server.World.Layout)
	local ServerOnlyAssets = require(ServerScriptService.Server.World.ServerOnlyAssets)

	describe("ServerOnlyAssets.matches", function()
		it("takes the area sets and backdrops, with or without a version tag", function()
			for _, name in
				{
					"CatCafe_Park_Set",
					"CatCafe_Park_SetF85",
					"CatCafe_Sewer_SetV32",
					"CatCafe_Ruins_Set",
					"CatCafe_Town_Backdrop",
					"CatCafe_Alleyway_Backdrop",
					"CatCafe_Woods_BackdropF85",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
		end)

		it("takes every set the layout names", function()
			for _, spec in Layout.areas do
				if spec.set ~= nil then
					expect(ServerOnlyAssets.matches(spec.set)).to.equal(true)
				end
			end
		end)

		it("leaves the models a client clones or draws", function()
			for _, name in
				{
					"CatCafe_Sky",
					"CatCafe_Camp_Park_Growth",
					"CatCafe_Furniture_TableRound",
					"CatCafe_Furniture_Chair",
					"CatCafe_Cat_Tabby",
					"CatCafe_Cat_Tabby_Sit",
					"CatCafe_Item_SpeedShoes",
					"CatCafe_Accessory_Sash",
					"CatCafe_Alley_Blocker_Bins",
					"CatCafe_Square_Paving",
					"CatCafe_Station_Settee",
					"CatCafe_Park_Setting_Table",
					"Park_Set",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(false)
			end
		end)
	end)
end
