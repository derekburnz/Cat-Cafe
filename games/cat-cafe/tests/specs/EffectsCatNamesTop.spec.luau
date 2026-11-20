--!strict
-- #5633 (Derek 2026-11-20: "put cat names on top of the diamond/new so people can read it"): Effects/CatNames' top
-- mode places the name clear over the rarity gem's NEW pill, near and far, and wins over catNamesLow.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local CatNames = require(Effects.CatNames) :: any
	local Presets = require(Effects.Presets) :: any

	describe("CatNames top mode", function()
		it("measures the NEW pill's top at about 0.535 of the gem's side", function()
			expect(CatNames.topShare()).to.be.near(0.535, 0.01)
		end)

		it("sits over the pill at the top of the bob, near and far", function()
			local r = Presets.rarityMark
			local studs, pixels = CatNames.topPlace()
			local share = CatNames.topShare()
			expect(studs > r.above + r.bob + share * r.size).to.equal(true)
			expect(pixels > share * r.finder.pixels).to.equal(true)
			expect(pixels > share * r.pixels).to.equal(true)
			expect(math.floor(pixels)).to.equal(pixels)
		end)

		it("wins over catNamesLow, and only an explicit true turns a mode on", function()
			expect(CatNames.mode(true, true)).to.equal("top")
			expect(CatNames.mode(true, nil)).to.equal("top")
			expect(CatNames.mode(nil, true)).to.equal("low")
			expect(CatNames.mode(false, false)).to.equal("under")
			expect(CatNames.mode("yes", 1)).to.equal("under")
		end)
	end)
end
