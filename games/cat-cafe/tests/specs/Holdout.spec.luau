--!strict
-- shared/Holdout.luau: the frozen control group for the new retention switches (#5499).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Holdout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Holdout")) :: any

	describe("Holdout.group", function()
		it("holds one account in ten, the same every time", function()
			local held = 0
			for userId = 1, 4000 do
				local group = Holdout.group(userId)
				expect(group == Holdout.HELD or group == Holdout.LIVE).to.equal(true)
				expect(Holdout.group(userId)).to.equal(group)
				if group == Holdout.HELD then
					held += 1
				end
			end
			expect(held).to.equal(400)
		end)

		it("does not follow the two low bits the other tests split on", function()
			for low = 0, 3 do
				local held = 0
				for n = 0, 99 do
					if Holdout.group(n * 4 + low) == Holdout.HELD then
						held += 1
					end
				end
				expect(held).to.equal(10)
			end
		end)
	end)

	describe("Holdout.joins", function()
		it("takes only a first session save with no group, while the switch is on", function()
			expect(Holdout.joins(true, 1, 0, nil)).to.equal(true)
			expect(Holdout.joins(false, 1, 0, nil)).to.equal(false)
			expect(Holdout.joins(true, 2, 0, nil)).to.equal(false)
			expect(Holdout.joins(true, 1, 3, nil)).to.equal(false)
			expect(Holdout.joins(true, 1, 0, Holdout.LIVE)).to.equal(false)
		end)
	end)

	describe("Holdout.held", function()
		it("holds a held save for seven days from its first day, then lets it go", function()
			local day = 20400
			local start = day * Holdout.DAY_SECONDS
			expect(Holdout.held(Holdout.HELD, day, start)).to.equal(true)
			expect(Holdout.held(Holdout.HELD, day, start + 6 * Holdout.DAY_SECONDS + 100)).to.equal(
				true
			)
			expect(Holdout.held(Holdout.HELD, day, start + 7 * Holdout.DAY_SECONDS)).to.equal(false)
			expect(Holdout.held(Holdout.LIVE, day, start)).to.equal(false)
			expect(Holdout.held(nil, day, start)).to.equal(false)
		end)
	end)

	describe("Holdout.gated and valid", function()
		it("holds back only the listed switches and keeps only known groups", function()
			expect(Holdout.gated("dailyGifts")).to.equal(true)
			expect(Holdout.gated("awayPromise")).to.equal(true)
			expect(Holdout.gated("returnMoment")).to.equal(true)
			expect(Holdout.gated("orderSplit")).to.equal(true)
			expect(Holdout.gated("bigNet")).to.equal(false)
			expect(Holdout.valid("holdout")).to.equal("holdout")
			expect(Holdout.valid("live")).to.equal("live")
			expect(Holdout.valid("other")).to.equal(nil)
			expect(Holdout.valid(3)).to.equal(nil)
		end)
	end)
end
