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

		it("takes the world pieces no client names (#4601) and leaves their ring art", function()
			for _, name in
				{
					"CatCafe_Square_Fountain",
					"CatCafe_Square_MysteryCart",
					"CatCafe_Street_SpinWheel",
					"CatCafe_Street_FishMarket",
					"CatCafe_Town_DayCart",
					"CatCafe_Town_LeaderboardRow",
					"CatCafe_Park_IndexBoard",
					"CatCafe_Snowy_IndexBoard",
					"CatCafe_WaterPark_IndexBoard", -- #5026
					"CatCafe_Castle_IndexBoard",
					"CatCafe_Town_ArcadeCabinet",
					"CatCafe_Town_FeedbackStand",
					"CatCafe_Square_FishFountain",
					"CatCafe_Plot_Interior",
					"CatCafe_Plot_Tier3",
					"CatCafe_Plot_YardFence",
					"CatCafe_Alley_CrateStack",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
			for _, name in
				{
					"CatCafe_Street_DealerCart_RingIcon_Decor",
					"CatCafe_Square_MysteryCart_RingIcon_Decor",
					"CatCafe_Plot_BackDoor",
					"CatCafe_Plot_LuckyCat_3",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(false)
			end
		end)
		it("takes the cafe's bigger room sizes, and leaves what a client names (#4543)", function()
			for _, name in
				{
					"CatCafe_Plot_Cafe_Mint_48x37",
					"CatCafe_Plot_Cafe_Lilac_60x46",
					"CatCafe_Plot_Interior_52x40",
					"CatCafe_Plot_ForRent_56x43",
					"CatCafe_Plot_Tier4_60x46",
					"CatCafe_Plot_YardFence_48x37",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
			for _, name in
				{

					"CatCafe_Plot_BackDoor",
					"CatCafe_Plot_LuckyCat_3",
					"CatCafe_Plot_SignSnowyBanner",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(false)
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
					-- #4601: the seated body is the server's alone too, but the three a client script names
					local seated = Catalog.sitModelName(model)
					expect(ServerOnlyAssets.matches(seated)).to.equal(
						ServerOnlyAssets.CLIENT_SIT[seated] ~= true
					)
					expect(ServerOnlyAssets.matches(Catalog.goldModelName(cat.id))).to.equal(false)
					-- #4601: the standing worker body is the server's alone
					expect(ServerOnlyAssets.matches(Catalog.workModelName(model))).to.equal(true)
				end
				-- #4601: a camp station is placed by the server, and the client reads the placed model
				for _, extra in Catalog.campExtras do
					expect(ServerOnlyAssets.matches(extra.model)).to.equal(true)
				end
			end
		)

		it("takes every cat's standing worker body and leaves its walking one (#4601)", function()
			for _, name in
				{
					"CatCafe_Cat_Tabby_Work",
					"CatCafe_Cat_BellhopCat_Work",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
			for _, name in
				{
					"CatCafe_Cat_Tabby",
					"CatCafe_Cat_Tabby_Gold",
					"CatCafe_Cat_Work", -- a cat named Work would be a walking body
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(false)
			end
		end)

		it(
			"takes every cat's seated body but the three a client script copies by name (#4601)",
			function()
				for _, name in
					{
						"CatCafe_Cat_Siamese_Sit",
						"CatCafe_Cat_SnowLeopard_Sit",
					}
				do
					expect(ServerOnlyAssets.matches(name)).to.equal(true)
				end
				-- the three stay with the clients, and they are the ones the client scripts name
				local Intro =
					require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Intro)
				local kept = {
					Catalog.sitModelName(Catalog.catModelName(Intro.DEMO_CAT)), -- IntroController's demo cat
					"CatCafe_Cat_BellhopCat_Sit", -- Effects Presets.bellhop.sitModel
					"CatCafe_Cat_Tabby_Sit", -- Effects Presets.mysticIntro.cat
				}
				local count = 0
				for _ in ServerOnlyAssets.CLIENT_SIT do
					count += 1
				end
				expect(count).to.equal(#kept)
				for _, name in kept do
					expect(ServerOnlyAssets.CLIENT_SIT[name]).to.equal(true)
					expect(ServerOnlyAssets.matches(name)).to.equal(false)
				end
				-- a customer's seated twin and an accessory's seated cut are not cats
				expect(ServerOnlyAssets.matches("CatCafe_NPC_Customer_A_Sit")).to.equal(false)
				expect(ServerOnlyAssets.matches("CatCafe_Accessory_Vest_Sit")).to.equal(false)
				expect(ServerOnlyAssets.matches("CatCafe_Cat_Sit")).to.equal(false) -- a cat named Sit
			end
		)

		it("takes the Cat Cannons, the Town Square's and every camp's (#4601)", function()
			for _, name in
				{
					"CatCafe_Square_Cannon",
					"CatCafe_Camp_Cannon_Alleyway",
					"CatCafe_Camp_Cannon_Park",
					"CatCafe_Camp_Cannon_WaterPark",
					"CatCafe_Camp_Cannon_Castle",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
			-- not a model today; a part of a cannon or a plain name is left alone
			expect(ServerOnlyAssets.matches("CatCafe_Camp_Cannon")).to.equal(false)
			expect(ServerOnlyAssets.matches("CatCafe_Camp_Cannon_Barrel")).to.equal(false)
		end)

		it("takes the camp stations and leaves the camp pieces a client copies (#4601)", function()
			for _, name in
				{
					"CatCafe_Camp_Alley_RummageBin",
					"CatCafe_Camp_Park_MysticPool",
					"CatCafe_Camp_Park_GardenNursery",
					"CatCafe_Camp_Desert_OasisSpa",
					"CatCafe_Camp_Ruins_RelicMuseum",
					"CatCafe_Camp_Snowy_CocoaStand",
					"CatCafe_Camp_Snowy_FusionObservatory",
					"CatCafe_Camp_WaterPark_TicketBooth",
					"CatCafe_Camp_Castle_DragonKeep",
					"CatCafe_Camp_Castle_HoardChest",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(true)
			end
			for _, name in
				{
					"CatCafe_Camp_Woods_FishingHut_Gold", -- GoldHutController reads its looks
					"CatCafe_Camp_Desert_SpaTowel", -- SpaPoolController clones it
					"CatCafe_Camp_Park_Growth", -- Effects/CampGrowth clones it
					"CatCafe_Camp_Castle_Growth",
				}
			do
				expect(ServerOnlyAssets.matches(name)).to.equal(false)
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
					"CatCafe_Camp_Cannon",
					"CatCafe_Camp_Cannon_Barrel",
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
