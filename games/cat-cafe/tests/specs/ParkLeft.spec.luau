--!strict
-- #5034: the park_left event's rules and buckets (shared/ParkLeft).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ParkLeft = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ParkLeft"))

	describe("ParkLeft", function()
		it("watches Tier 2 and up until the first Park cat", function()
			expect(ParkLeft.counts(1, false)).to.equal(false)
			expect(ParkLeft.counts(2, false)).to.equal(true)
			expect(ParkLeft.counts(5, false)).to.equal(true)
			expect(ParkLeft.counts(2, true)).to.equal(false)
		end)

		it("buckets the closest free stray", function()
			expect(ParkLeft.closestBucket(nil)).to.equal("none")
			expect(ParkLeft.closestBucket(3)).to.equal("lt15")
			expect(ParkLeft.closestBucket(15)).to.equal("15_40")
			expect(ParkLeft.closestBucket(39.9)).to.equal("15_40")
			expect(ParkLeft.closestBucket(40)).to.equal("40_100")
			expect(ParkLeft.closestBucket(100)).to.equal("100plus")
		end)

		it("buckets the seconds in the Park", function()
			expect(ParkLeft.secondsBucket(0)).to.equal("0-60")
			expect(ParkLeft.secondsBucket(60)).to.equal("60-180")
			expect(ParkLeft.secondsBucket(599)).to.equal("180-600")
			expect(ParkLeft.secondsBucket(600)).to.equal("600+")
		end)

		it("keeps to Roblox's three custom fields", function()
			local fields = ParkLeft.fields("phone", 22, 400)
			expect(#fields).to.equal(3)
			expect(fields[1]).to.equal("phone")
			expect(fields[2]).to.equal("15_40")
			expect(fields[3]).to.equal("180-600")
		end)
	end)
end
