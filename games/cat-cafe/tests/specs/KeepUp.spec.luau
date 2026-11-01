--!strict
-- UI/Components/KeepUp.luau: when the "Keeps up" tag shows on an older Legendary or Mythical, and its tip (F86).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local KeepUp = require(Components:WaitForChild("KeepUp")) :: any
	local Catalog =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))

	local function find(area: string, rarity: string): any
		for _, def in Catalog.cats do
			if (def.area or "alley") == area and def.rarity == rarity then
				return def
			end
		end
		error(("no %s %s cat in the catalog"):format(area, rarity))
	end

	describe("KeepUp.keepsUp", function()
		it("tags an older Legendary or Mythical once a rank up lifts its pay", function()
			local legendary = find("alley", "Legendary")
			expect(KeepUp.keepsUp(legendary, 1)).to.equal(false)
			expect(KeepUp.keepsUp(legendary, 2)).to.equal(false)
			expect(KeepUp.keepsUp(legendary, 3)).to.equal(true)
			expect(KeepUp.keepsUp(legendary, 5)).to.equal(true)
			expect(KeepUp.keepsUp(find("park", "Mythical"), 4)).to.equal(true)
		end)

		it("leaves the newest two areas, Epic and below and a missing tier alone", function()
			expect(KeepUp.keepsUp(find("woods", "Legendary"), 5)).to.equal(false)
			expect(KeepUp.keepsUp(find("sewer", "Legendary"), 5)).to.equal(false)
			expect(KeepUp.keepsUp(find("alley", "Epic"), 5)).to.equal(false)
			expect(KeepUp.keepsUp(find("alley", "Legendary"), nil)).to.equal(false)
			expect(KeepUp.keepsUp(nil, 5)).to.equal(false)
		end)
	end)

	describe("KeepUp.tip", function()
		it("names the area it earns like and the newest one", function()
			expect(KeepUp.tip(5)).to.equal("Earns like a Woods cat now that you have reached the Sewer.")
			expect(KeepUp.tip(3)).to.equal("Earns like a Park cat now that you have reached the Neighbourhood.")
		end)
	end)
end
