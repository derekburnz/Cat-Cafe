--!strict
-- The templates only the server clones (#3743): area kit sets and backdrop rings are kept out of
-- ReplicatedStorage, everything a client looks up stays in it.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Catalog)
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

		it("takes the world pieces only the server builds (#3790)", function()
			for _, name in
				{
					"CatCafe_Alley_Blocker_RowCamp",
					"CatCafe_Alley_Blocker_BinsShort",
					"CatCafe_Alley_Building_ClockHouse",
					"CatCafe_Camp_Alleyway",
					"CatCafe_Camp_ParkF85",
					"CatCafe_Camp_Ruins",
					"CatCafe_Plot_Cafe_Mint",
					"CatCafe_Park_Gate",
					"CatCafe_Park_GateF85",
					"CatCafe_Sewer_NightFence",
					"CatCafe_Woods_NightFenceF85",
					"CatCafe_Alley_NightFence",
					"CatCafe_Alley_NightFenceSegment",
					"CatCafe_Nook_Desert",
					-- #4070: the Snowy Mountain's and the Water Park's
					"CatCafe_Camp_Snowy",
					"CatCafe_Camp_WaterPark",
					"CatCafe_Nook_Snowy",
					"CatCafe_Nook_WaterPark",
					"CatCafe_WaterPark_Gate",
					-- #4184: the Medieval Castle's
					"CatCafe_Camp_Castle",
					"CatCafe_Nook_Castle",
					"CatCafe_Castle_Gate",
					"CatCafe_Square_Paving",
					"CatCafe_Town_WelcomeArch",
					"CatCafe_Alley_Mural",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
		end)

		it(
			"leaves everything the catalog names for a client: cats, decor, pieces and crates",
			function()
				for _, def in Catalog.decorById do
					if def.asset ~= nil then
						expect(ServerOnlyAssets.matches(def.asset)).to.equal(false)
					end
				end
				for _, cat in Catalog.cats do
					local model = Catalog.catModelName(cat.id)
					expect(ServerOnlyAssets.matches(model)).to.equal(false)
					expect(ServerOnlyAssets.matches(Catalog.sitModelName(model))).to.equal(false)
					expect(ServerOnlyAssets.matches(Catalog.workModelName(model))).to.equal(false)
					expect(ServerOnlyAssets.matches(Catalog.goldModelName(cat.id))).to.equal(false)
				end
				for _, extra in Catalog.campExtras do
					expect(ServerOnlyAssets.matches(extra.model)).to.equal(false)
				end
			end
		)

		it("leaves the models a client clones or draws", function()
			for _, name in
				{
					"CatCafe_Sky",
					"CatCafe_Camp_Park_Growth",
					"CatCafe_Camp_Snowy_FusionObservatory", -- #4070: a camp's station stays with the client
					"CatCafe_Camp_Snowy_CocoaStand",
					"CatCafe_Camp_WaterPark_TicketBooth",
					"CatCafe_Camp_Cannon_WaterPark",
					"CatCafe_Camp_Castle_DragonKeep",
					"CatCafe_Camp_Cannon_Castle",
					"CatCafe_Furniture_TableRound",
					"CatCafe_Furniture_Chair",
					"CatCafe_Cat_Tabby",
					"CatCafe_Cat_Tabby_Sit",
					"CatCafe_Item_SpeedShoes",
					"CatCafe_Accessory_Sash",
					"CatCafe_Camp_Cannon",
					"CatCafe_Camp_Cannon_Barrel",
					"CatCafe_Camp_Park_PicnicStation",
					"CatCafe_Camp_Park_MysticPool",
					"CatCafe_Camp_Woods_FishingHut_Gold",
					"CatCafe_Camp_Sewer_Growth",
					"CatCafe_Camp_Town",
					"CatCafe_Door_ArchGate_Back",
					"CatCafe_Door_GardenGate_Front",
					"CatCafe_Plot_BackDoor",
					"CatCafe_Plot_SignGrand",
					"CatCafe_Plot_ThemeGarden",
					"CatCafe_Plot_Cafe_Oven",
					"CatCafe_Cafe_Oven",
					"CatCafe_Square_Cannon",
					"CatCafe_Town_FeedbackStand",
					"CatCafe_Town_ArcadeCabinet",
					"CatCafe_Town_Gate",
					"CatCafe_Nook_Town",
					"CatCafe_NPC_Townsfolk_Baker",
					"CatCafe_Prop_Crate_Alley",
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
