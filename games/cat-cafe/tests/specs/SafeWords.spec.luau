--!strict
-- Where a camp's SAFE ZONE words go (#1132; server World/SafeWords.luau, pure geometry).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local SafeWords = require(ServerScriptService.Server.World.SafeWords)

	local GAP = SafeWords.GAP

	local function clear(spot: SafeWords.Spot, box: SafeWords.Box): boolean
		local depth = spot.width * SafeWords.RATIO
		return spot.x + spot.width / 2 + GAP <= box.x1
			or spot.x - spot.width / 2 - GAP >= box.x2
			or spot.z + depth / 2 + GAP <= box.z1
			or spot.z - depth / 2 - GAP >= box.z2
	end

	describe("SafeWords.fit", function()
		it(
			"puts the full 12 wide words in the middle of an empty camp, behind the stripe",
			function()
				local spot = SafeWords.fit({}, 60)
				expect(spot ~= nil).to.equal(true)
				local at = spot :: SafeWords.Spot
				expect(at.width).to.equal(12)
				expect(at.x).to.equal(0)
				local nearEdge = at.z + at.width * SafeWords.RATIO / 2
				expect(nearEdge <= SafeWords.STRIPE_Z - SafeWords.STRIPE_HALF - GAP + 1e-9).to.equal(
					true
				)
			end
		)

		it("keeps a stud clear of a circle plaza dead ahead by shrinking or moving", function()
			-- a round plaza's box from z -5 deeper, 16 wide, as the Park's
			local plaza: SafeWords.Box = { x1 = -8, x2 = 8, z1 = -21, z2 = -5 }
			local spot = SafeWords.fit({ plaza }, 60)
			expect(spot ~= nil).to.equal(true)
			expect(clear(spot :: SafeWords.Spot, plaza)).to.equal(true)
		end)

		it("moves along the edge when the middle is taken", function()
			local block: SafeWords.Box = { x1 = -10, x2 = 10, z1 = -14, z2 = 0 }
			local spot = SafeWords.fit({ block }, 60)
			expect(spot ~= nil).to.equal(true)
			expect(clear(spot :: SafeWords.Spot, block)).to.equal(true)
			expect(math.abs((spot :: SafeWords.Spot).x) > 10).to.equal(true)
		end)

		it("leaves the words off when nothing fits", function()
			local wall: SafeWords.Box = { x1 = -100, x2 = 100, z1 = -30, z2 = 0 }
			expect(SafeWords.fit({ wall }, 60)).to.equal(nil)
		end)

		it("stays inside a narrow camp", function()
			local spot = SafeWords.fit({}, 7)
			expect(spot ~= nil).to.equal(true)
			local at = spot :: SafeWords.Spot
			expect(math.abs(at.x) + at.width / 2 + GAP <= 7 + 1e-9).to.equal(true)
		end)
	end)
end
