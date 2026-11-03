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

	describe("Cannon.heading (CannonHeading, Derek 2026-11-03)", function()
		it("points from the cannon toward the pad on the ground plane, one stud long", function()
			local heading =
				Cannon.heading(Vector3.new(0, 5, 0), Vector3.new(300, -20, 400), Vector3.zero)
			expect(heading.X).to.be.near(0.6, 1e-9)
			expect(heading.Y).to.equal(0)
			expect(heading.Z).to.be.near(0.8, 1e-9)
		end)

		it("falls back on the barrel's facing for a pad under the cannon or none", function()
			local facing = Vector3.new(0, 0.7, 0.7)
			expect(Cannon.heading(Vector3.zero, Vector3.new(0.2, 0, 0.3), facing)).to.equal(
				Vector3.new(0, 0, 1)
			)
			expect(Cannon.heading(Vector3.zero, nil, facing)).to.equal(Vector3.new(0, 0, 1))
			expect(Cannon.heading(Vector3.zero, nil, Vector3.new(0, 1, 0))).to.equal(
				Vector3.new(0, 0, -1)
			)
		end)
	end)

	describe("the flight's beats (Derek 2026-11-03: much further, no visible teleport)", function()
		it(
			"moves the character while the body is in the clouds, before the feet touch down",
			function()
				expect(Config.CannonLaunchSeconds).to.be.near(4.0, 1e-12)
				expect(Config.CannonTeleportAtSeconds).to.be.near(2.6, 1e-12)
				expect(Config.CannonCloudsAt < Config.CannonTeleportAtSeconds).to.equal(true)
				expect(Config.CannonTeleportAtSeconds < Config.CannonTouchdownAt).to.equal(true)
				expect(Config.CannonTouchdownAt < Config.CannonLaunchSeconds).to.equal(true)
			end
		)
	end)
end
