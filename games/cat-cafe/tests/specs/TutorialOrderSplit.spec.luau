--!strict
-- shared/TutorialOrder.luau (#5498): the walk-through order test, catch first against bowl first.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local TutorialOrder = require(Shared.TutorialOrder)

	describe("TutorialOrder split", function()
		it("puts about half of accounts in each arm", function()
			local catch = 0
			for userId = 1, 1000 do
				if TutorialOrder.group(userId) == TutorialOrder.CATCH then
					catch += 1
				end
			end
			expect(catch).to.equal(500)
		end)

		it("joins only a new save with no arm, with the switch on", function()
			expect(TutorialOrder.joins(true, 1, 0, nil)).to.equal(true)
			expect(TutorialOrder.joins(true, 0, 0, nil)).to.equal(true)
			expect(TutorialOrder.joins(false, 1, 0, nil)).to.equal(false)
			expect(TutorialOrder.joins(true, 2, 0, nil)).to.equal(false)
			expect(TutorialOrder.joins(true, 1, 1, nil)).to.equal(false)
			expect(TutorialOrder.joins(true, 1, 0, TutorialOrder.BOWL)).to.equal(false)
		end)

		it("reads the arm before the switch", function()
			expect(TutorialOrder.fromGroup(TutorialOrder.CATCH)).to.equal(false)
			expect(TutorialOrder.fromGroup(TutorialOrder.BOWL)).to.equal(true)
		end)

		it("keeps a valid arm in the save and drops anything else", function()
			local profile: any = ProfileSchema.template(1700000000)
			expect(profile.telemetry.orderGroup).to.equal(nil)
			profile.telemetry.orderGroup = TutorialOrder.CATCH
			expect(ProfileSchema.migrate(profile, 1700000000).telemetry.orderGroup).to.equal(
				TutorialOrder.CATCH
			)
			profile.telemetry.orderGroup = "half"
			expect(ProfileSchema.migrate(profile, 1700000000).telemetry.orderGroup).to.equal(nil)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[TutorialOrder.SPLIT_FLAG]).to.equal(true)
		end)
	end)
end
