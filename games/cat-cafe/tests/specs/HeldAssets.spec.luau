--!strict
-- Models merged behind an off switch (Derek 2026-11-20). Cherry Blossom Grove, the only held set, was removed with its
-- models (Derek 2026-11-24), so nothing is held.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local HeldAssets = require(ServerScriptService.Server.World.HeldAssets)

	describe("HeldAssets", function()
		it("holds nothing, and leaves every model alone", function()
			for _, name in
				{
					"CatCafe_Cat_Tabby",
					"CatCafe_Cat_Lantern",
					"CatCafe_Decor_BlossomTree",
					"CatCafe_Snowglobe_Set",
				}
			do
				expect(HeldAssets.switchFor(name)).to.equal(nil)
			end
			expect(#HeldAssets.names("cherryGrove")).to.equal(0)
			expect(#HeldAssets.names("noSuchSwitch")).to.equal(0)
		end)
	end)
end
