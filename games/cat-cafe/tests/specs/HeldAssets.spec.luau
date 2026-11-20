--!strict
-- Models merged behind an off switch (Derek 2026-11-20): the Cherry Blossom Grove ones are held back under
-- cherryGrove, everything else is not held.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HeldAssets = require(ServerScriptService.Server.World.HeldAssets)
	local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared").LiveFlags)

	describe("HeldAssets", function()
		it("holds the Grove set, portal, stall, petals, items and all three poses of the eight cats", function()
			for _, name in
				{
					"CatCafe_Cherry_Set",
					"CatCafe_Cherry_Portal",
					"CatCafe_Cherry_Stall",
					"CatCafe_Cherry_Petals",
					"CatCafe_Accessory_FlowerCrown",
					"CatCafe_Decor_GroveBlossomTree",
					"CatCafe_Cat_Sakura",
					"CatCafe_Cat_PaperLantern_Sit",
					"CatCafe_Cat_PetalDragon_Work",
				}
			do
				expect(HeldAssets.switchFor(name)).to.equal("cherryGrove")
			end
			expect(#HeldAssets.names("cherryGrove")).to.equal(34)
		end)

		it("leaves every other model alone", function()
			for _, name in
				{ "CatCafe_Cat_Tabby", "CatCafe_Cat_Lantern", "CatCafe_Decor_BlossomTree", "CatCafe_Snowglobe_Set" }
			do
				expect(HeldAssets.switchFor(name)).to.equal(nil)
			end
			expect(#HeldAssets.names("noSuchSwitch")).to.equal(0)
		end)

		it("holds only under switches that exist and start off", function()
			expect(table.find(LiveFlags.KEYS, "cherryGrove") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.cherryGrove).to.equal(true)
		end)
	end)
end
