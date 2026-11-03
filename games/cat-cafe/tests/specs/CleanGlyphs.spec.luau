--!strict
-- UI/Theme.cleanGlyphs and Components/IconArt: windows draw the clean symbols the HUD uses (#1027).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local UI = Client:WaitForChild("UI")
	local Theme = require(UI:WaitForChild("Theme")) :: any
	local Components = UI:WaitForChild("Components")
	local ShopIcons = require(Components:WaitForChild("ShopIcons")) :: any
	local IconArt = require(Components:WaitForChild("IconArt")) :: any

	describe("Theme.cleanGlyphs", function()
		it("names an uploaded clean symbol for every glyph", function()
			for glyph, name in Theme.cleanGlyphs do
				expect(ShopIcons.clean(name)).to.be.ok()
				expect(type(glyph)).to.equal("string")
			end
		end)
		it("covers the Tip Jar, Daily Treat, crate and potion badges", function()
			expect(Theme.cleanGlyphs[Theme.icons.gifts]).to.equal("Rewards")
			expect(Theme.cleanGlyphs[Theme.icons.daily]).to.equal("Rewards")
			expect(Theme.cleanGlyphs[Theme.icons.crate]).to.equal("Crate")
			expect(Theme.cleanGlyphs[Theme.icons.potion]).to.equal("Potion")
		end)
	end)

	describe("IconArt.set", function()
		it("draws the clean symbol, not the old sheet cell", function()
			local label = Instance.new("TextLabel")
			IconArt.set(label, Theme.icons.gifts)
			local art = label:FindFirstChild("IconArt") :: ImageLabel
			expect(art).to.be.ok()
			expect(art.Image).to.equal(ShopIcons.clean("Rewards"))
			expect(art.ImageRectSize).to.equal(Vector2.zero)
			label:Destroy()
		end)
		it("keeps the golden fish picture", function()
			local label = Instance.new("TextLabel")
			IconArt.set(label, Theme.icons.goldenFish)
			local art = label:FindFirstChild("IconArt") :: ImageLabel
			expect(art.Image).to.equal(Theme.glyphImages[Theme.icons.goldenFish])
			label:Destroy()
		end)
		it("still uses the sheet for a glyph with no clean symbol", function()
			local label = Instance.new("TextLabel")
			IconArt.set(label, Theme.icons.spin)
			local art = label:FindFirstChild("IconArt") :: ImageLabel
			expect(art.Image).to.equal(Theme.iconSheet.image)
			label:Destroy()
		end)
	end)
end
