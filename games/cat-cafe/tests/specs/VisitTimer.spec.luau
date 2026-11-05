--!strict
-- shared/VisitTimer.luau (#1135): special visitors come on a timer drawn from a range, counted only while the cafe
-- could have one, with about the same average as the old check-and-chance rolls.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local VisitTimer = require(Shared.VisitTimer)

	describe("VisitTimer", function()
		it("draws inside the range, from min to max", function()
			expect(VisitTimer.draw(300, 900, 0)).to.equal(300)
			expect(VisitTimer.draw(300, 900, 0.5)).to.equal(600)
			expect(VisitTimer.draw(300, 900, 0.999)).to.be.near(899.4, 1e-6)
			expect(VisitTimer.draw(300, 900, 2)).to.equal(900)
		end)

		it("counts down only while counting, never below 0, and is due at 0", function()
			local left, due = VisitTimer.tick(10, 4, true)
			expect(left).to.equal(6)
			expect(due).to.equal(false)
			left, due = VisitTimer.tick(left, 30, false)
			expect(left).to.equal(6)
			expect(due).to.equal(false)
			left, due = VisitTimer.tick(left, 7, true)
			expect(left).to.equal(0)
			expect(due).to.equal(true)
			left, due = VisitTimer.tick(5, -3, true)
			expect(left).to.equal(5)
		end)

		it("keeps the rich and collector old average rates, the Mystery Visitor a fifth more often (#1638)", function()
			expect((Config.RichEveryMin + Config.RichEveryMax) / 2).to.equal(600)
			expect((Config.MysteryEveryMin + Config.MysteryEveryMax) / 2).to.equal(1250)
			expect((Config.CollectorEveryMin + Config.CollectorEveryMax) / 2).to.equal(1000)
			-- never two visits closer than the minimum: each min is well past its stay
			expect(Config.RichEveryMin > Config.RichTipStaySeconds).to.equal(true)
			expect(Config.MysteryEveryMin > Config.MysteryStaySeconds).to.equal(true)
			expect(Config.CollectorEveryMin > Config.CollectorStaySeconds).to.equal(true)
		end)
	end)
end
