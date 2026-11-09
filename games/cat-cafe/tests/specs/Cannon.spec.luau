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

	-- #1205: every cannon turns to the pad it fires at, so the seat's look (WorldBuilder.cannonSeat: fireTurn +
	-- AimTurn) is CannonHeading and the client bends the flight by 0 degrees.
	describe("aimTurn (#1205)", function()
		local Layout = require(game:GetService("ServerScriptService").Server.World.Layout)

		it("points every cannon's seat at every landing pad, within 1 degree", function()
			local checked = 0
			for cannonId, spec in Layout.cannons do
				local from = Vector3.new(spec.x, spec.y, spec.z)
				local fireTurn = spec.rotY or 0
				local rest = Vector3.new(math.sin(math.rad(fireTurn)), 0, math.cos(math.rad(fireTurn)))
				for destination, pad in Layout.landingPads do
					if destination ~= cannonId then
						local heading =
							Cannon.heading(from, Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z), rest)
						local turn = math.rad(fireTurn + Cannon.aimTurn(heading, fireTurn))
						local look = Vector3.new(math.sin(turn), 0, math.cos(turn))
						expect(look:Dot(heading) >= math.cos(math.rad(1))).to.equal(true)
						checked += 1
					end
				end
			end
			expect(checked > 0).to.equal(true)
		end)

		it("keeps a cannon's own look when the pad is under it", function()
			local heading = Cannon.heading(Vector3.zero, Vector3.new(0.2, 0, 0.2), Vector3.new(1, 0, 0))
			expect(Cannon.aimTurn(heading, 90)).to.be.near(0, 1e-6)
		end)
	end)
end
