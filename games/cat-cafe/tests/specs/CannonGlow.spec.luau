--!strict
-- shared/CannonGlow (#5533 v2, switch cannonGlow): the cannon glows for the area a rank up opens until the first flight.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CannonGlow = require(Shared.CannonGlow)

	describe("CannonGlow.opened", function()
		it("names the area a rank up to that tier opens, nil when none", function()
			local areas = {
				{ id = "alley", tier = 1 },
				{ id = "park", tier = 2 },
				{ id = "woods", tier = 3 },
			}
			expect(CannonGlow.opened(2, areas)).to.equal("park")
			expect(CannonGlow.opened(3, areas)).to.equal("woods")
			expect(CannonGlow.opened(9, areas)).to.equal(nil)
			expect(CannonGlow.opened(2, areas, { park = true })).to.equal(nil) -- already has a Park cat
		end)
	end)

	describe("CannonGlow.clears and direct", function()
		it("clears on the first flight to the glowing area only", function()
			expect(CannonGlow.clears("park", "park")).to.equal(true)
			expect(CannonGlow.clears("park", "town")).to.equal(false)
			expect(CannonGlow.clears(nil, "park")).to.equal(false)
		end)
		it("flies straight to the glowing area only with the switch on", function()
			expect(CannonGlow.direct(true, "park", "town")).to.equal("park")
			expect(CannonGlow.direct(false, "park", "town")).to.equal(nil)
			expect(CannonGlow.direct(true, nil, "town")).to.equal(nil)
			expect(CannonGlow.direct(true, "", "town")).to.equal(nil)
		end)
		it("flies straight from the lit camp cannon too (#5547)", function()
			expect(CannonGlow.direct(true, "park", "alley")).to.equal("park")
			expect(CannonGlow.direct(true, "park", "park")).to.equal(nil) -- already in the Park
		end)
		it("reads off when the switch's attribute is missing", function()
			expect(CannonGlow.on()).to.equal(false)
		end)
	end)
end
