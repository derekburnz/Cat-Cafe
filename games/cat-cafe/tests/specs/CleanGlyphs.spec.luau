--!strict
-- UI/Components/CleanGlyphs.luau: windows draw the clean symbols the HUD uses (#1027).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CleanGlyphs = require(Components:WaitForChild("CleanGlyphs")) :: any
	local ShopIcons = require(Components:WaitForChild("ShopIcons")) :: any

	describe("CleanGlyphs", function()
		it("names an uploaded clean symbol for every entry", function()
			for _, name in CleanGlyphs.icons do
				expect(ShopIcons.clean(name)).to.be.ok()
			end
			for _, name in CleanGlyphs.foods do
				expect(ShopIcons.clean(name)).to.be.ok()
			end
		end)
		it("maps the Tip Jar and Daily Treat badges to the Rewards gift", function()
			expect(CleanGlyphs.icons.gifts).to.equal("Rewards")
			expect(CleanGlyphs.icons.daily).to.equal("Rewards")
		end)
		it("builds a glyph map and skips keys the icon tables lack", function()
			local map = CleanGlyphs.map(
				{ crate = "📦", potion = "🧪", spin = "🎡" },
				{ kibble = "🥣" }
			)
			expect(map["📦"]).to.equal("Crate")
			expect(map["🧪"]).to.equal("Potion")
			expect(map["🥣"]).to.equal("Kibble")
			expect(map["🎡"]).to.equal(nil)
		end)
	end)
end
