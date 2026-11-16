--!strict
-- Effects/WowBaitGlow (#4822): the tag's words per rarity, which rarities get the look, the claim window, and the
-- phone budget of the sparkle (about a dozen alive, never over 15).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local WowBaitGlow = require(Effects:WaitForChild("WowBaitGlow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects wow bait glow", function()
		it("tags Rare and Epic and skips plain rarities and junk", function()
			expect(WowBaitGlow.tagFor("Rare")).to.equal("RARE!")
			expect(WowBaitGlow.tagFor("Epic")).to.equal("EPIC!")
			expect(WowBaitGlow.tagFor("Common")).never.to.be.ok()
			expect(WowBaitGlow.tagFor("Uncommon")).never.to.be.ok()
			expect(WowBaitGlow.tagFor(5)).never.to.be.ok()
			expect(WowBaitGlow.tagFor(nil)).never.to.be.ok()
		end)

		it("has a rarity colour for every rarity it tags", function()
			for rarity in Presets.wowBait.rarities do
				expect(Presets.rarity[rarity]).to.be.ok()
			end
		end)

		it("counts a claim only near the moment the cat went", function()
			local w = Presets.wowBait.claimWindow
			expect(WowBaitGlow.claimed(100, 99.5, w)).to.equal(true)
			expect(WowBaitGlow.claimed(100, 101, w)).to.equal(true)
			expect(WowBaitGlow.claimed(100, 90, w)).to.equal(false)
			expect(WowBaitGlow.claimed(100, -math.huge, w)).to.equal(false)
		end)

		it("keeps the sparkle inside the phone budget of 10 to 15 alive", function()
			local e = Presets.emitters[Presets.wowBait.sparkle]
			local alive = e.rate * e.lifetime[2]
			expect(alive >= 10 and alive <= 15).to.equal(true)
		end)
	end)
end
