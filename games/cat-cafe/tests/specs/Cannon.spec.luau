--!strict
-- shared/Cannon.luau: the knocked down refusal LaunchCannon and Travel share (F84, review N281, hometown-cannon.md
-- section 5).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Cannon = require(Shared.Cannon)
	local Config = require(Shared.Config)

	local function check(sinceTackled: number?): any
		return {
			cannonId = "town",
			destination = "alley",
			knownCannon = true,
			knownDestination = true,
			destinationName = "Alleyway",
			destinationTier = 1,
			tier = 1,
			areasOpen = true,
			duskWarning = false,
			distance = 1,
			carrying = false,
			busy = false,
			flying = false,
			sinceTackled = sinceTackled,
			sinceLanded = nil,
		}
	end

	describe("Cannon.downRefusal", function()
		it("refuses for TackledDownSeconds after a tackle lands, then lets go", function()
			expect(Cannon.downRefusal(0)).to.equal(Cannon.DOWN_TEXT)
			expect(Cannon.downRefusal(Config.TackledDownSeconds - 0.01)).to.equal(Cannon.DOWN_TEXT)
			expect(Cannon.downRefusal(Config.TackledDownSeconds)).to.equal(nil)
			expect(Cannon.downRefusal(nil)).to.equal(nil)
		end)

		it("is the refusal LaunchCannon gives a downed player", function()
			expect(Cannon.launchRefusal(check(nil))).to.equal(nil)
			expect(Cannon.launchRefusal(check(0.2))).to.equal(Cannon.DOWN_TEXT)
			expect(Cannon.launchRefusal(check(Config.TackledDownSeconds + 1))).to.equal(nil)
		end)
	end)
end
