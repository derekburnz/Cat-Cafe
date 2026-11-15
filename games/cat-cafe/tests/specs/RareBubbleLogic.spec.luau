--!strict
-- UI/Components/RareBubbleLogic.luau (#4227): the Mythical and Secret counts per area for the Cannon bubbles.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local RareBubbleLogic = require(Components:WaitForChild("RareBubbleLogic")) :: any

	describe("decode", function()
		it("reads each area's counts and drops empty or bad ones", function()
			local map = RareBubbleLogic.fromData({
				park = { m = 2, s = 0 },
				woods = { m = 1, s = 1 },
				alley = { m = 0, s = 0 },
				sewer = { m = -3, s = "x" },
			})
			expect(map.park.m).to.equal(2)
			expect(map.park.s).to.equal(0)
			expect(map.woods.s).to.equal(1)
			expect(map.alley).to.equal(nil)
			expect(map.sewer).to.equal(nil)
		end)

		it("is empty for nothing, a number or a bad table", function()
			expect(next(RareBubbleLogic.decode(nil))).to.equal(nil)
			expect(next(RareBubbleLogic.decode(""))).to.equal(nil)
			expect(next(RareBubbleLogic.decode(5))).to.equal(nil)
			expect(next(RareBubbleLogic.fromData("park"))).to.equal(nil)
			expect(next(RareBubbleLogic.fromData({ 1, 2 }))).to.equal(nil)
		end)
	end)

	describe("counts and totals", function()
		it("adds up only the open areas", function()
			local map =
				RareBubbleLogic.fromData({ park = { m = 2, s = 0 }, woods = { m = 1, s = 1 } })
			local some = RareBubbleLogic.totals(map, { park = true })
			expect(some.m).to.equal(2)
			expect(some.s).to.equal(0)
			local all = RareBubbleLogic.totals(map, { park = true, woods = true })
			expect(all.m).to.equal(3)
			expect(all.s).to.equal(1)
			expect(RareBubbleLogic.counts(map, "alley").m).to.equal(0)
		end)

		it("says 9+ past nine", function()
			expect(RareBubbleLogic.text(3)).to.equal("3")
			expect(RareBubbleLogic.text(12)).to.equal("9+")
		end)
	end)
end
