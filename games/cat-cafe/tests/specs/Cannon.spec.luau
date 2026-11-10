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
				expect(Config.CannonLaunchSeconds).to.be.near(3.75, 1e-12)
				expect(Config.CannonTeleportAtSeconds).to.be.near(2.6, 1e-12)
				expect(Config.CannonCloudsAt < Config.CannonTeleportAtSeconds).to.equal(true)
				expect(Config.CannonTeleportAtSeconds < Config.CannonTouchdownAt).to.equal(true)
				expect(Config.CannonTouchdownAt < Config.CannonLaunchSeconds).to.equal(true)
			end
		)
		it("lets the landed player move again soon after the feet touch (#2690)", function()
			local held = Config.CannonLaunchSeconds - Config.CannonTouchdownAt
			expect(held > 0 and held <= 0.3).to.equal(true)
		end)
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
				local rest =
					Vector3.new(math.sin(math.rad(fireTurn)), 0, math.cos(math.rad(fireTurn)))
				for destination, pad in Layout.landingPads do
					if destination ~= cannonId then
						local heading = Cannon.heading(
							from,
							Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z),
							rest
						)
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
			local heading =
				Cannon.heading(Vector3.zero, Vector3.new(0.2, 0, 0.2), Vector3.new(1, 0, 0))
			expect(Cannon.aimTurn(heading, 90)).to.be.near(0, 1e-6)
		end)
	end)

	describe("besideStray (#2913, #2915)", function()
		it("lands the gap short of the stray, toward the pad, at the pad's height", function()
			local pad = Vector3.new(-1400, 0.1, -1261.5)
			local stray = Vector3.new(-1395, 1.2, -1285)
			local at = Cannon.besideStray(stray, pad, 7) :: Vector3
			expect(at).never.to.equal(nil)
			local flat = Vector3.new(at.X - stray.X, 0, at.Z - stray.Z)
			expect(flat.Magnitude).to.be.near(7, 1e-6)
			expect(at.Y).to.equal(0.1)
			-- closer to the pad than the stray is
			expect((at - pad).Magnitude < (stray - pad).Magnitude).to.equal(true)
		end)

		it("leaves it to the pad when the stray is that close already, or up a tree", function()
			local pad = Vector3.new(0, 0, 0)
			expect(Cannon.besideStray(Vector3.new(5, 0, 0), pad, 7)).to.equal(nil)
			expect(Cannon.besideStray(Vector3.new(30, 12, 0), pad, 7)).to.equal(nil)
			expect(Cannon.besideStray(Vector3.new(30, 2, 0), pad)).never.to.equal(nil)
		end)
	end)

	describe("a returning player's join at their own front door (#3072)", function()
		it(
			"sends home only a player whose intro has played and who has caught their first cat",
			function()
				expect(Cannon.joinsAtHome(true, true, 2, 2)).to.equal(true)
				expect(Cannon.joinsAtHome(true, true, 9, 2)).to.equal(true)
				-- the intro is still to play: it starts at the Town Square
				expect(Cannon.joinsAtHome(false, true, 5, 2)).to.equal(false)
				expect(Cannon.joinsAtHome(nil, true, 5, 2)).to.equal(false)
				-- the walk-through's first catch leads from the cannon
				expect(Cannon.joinsAtHome(true, true, 1, 2)).to.equal(false)
				expect(Cannon.joinsAtHome(true, true, 0, 2)).to.equal(false)
				expect(Cannon.joinsAtHome(true, true, nil, 2)).to.equal(false)
				-- with the intro switched off, an account that never saw it still goes home once it has a cat
				expect(Cannon.joinsAtHome(false, false, 2, 2)).to.equal(true)
				expect(Cannon.joinsAtHome(nil, false, 1, 2)).to.equal(false)
			end
		)

		it("moves only a character that still stands at the spawn", function()
			local spawn = Vector3.new(0, 0.6, -14)
			expect(Cannon.stillAtSpawn(Vector3.new(0, 3.6, -14), spawn)).to.equal(true)
			expect(Cannon.stillAtSpawn(Vector3.new(6, 3, -8), spawn)).to.equal(true)
			expect(Cannon.stillAtSpawn(Vector3.new(0, 3, -14 - Cannon.HOME_SPAWN_STUDS), spawn)).to.equal(
				true
			)
			expect(
				Cannon.stillAtSpawn(Vector3.new(0, 3, -14 - Cannon.HOME_SPAWN_STUDS - 0.5), spawn)
			).to.equal(false)
			expect(Cannon.stillAtSpawn(Vector3.new(40, 3, 85), spawn)).to.equal(false)
			-- height does not count: a jump at the spawn is still at the spawn
			expect(Cannon.stillAtSpawn(Vector3.new(0, 30, -14), spawn)).to.equal(true)
		end)

		it("puts the camera behind and above the character, looking the way it faces", function()
			-- at the Town Square spawn the character faces the cannon (+Z): the camera is south of it, not in the cannon
			local from, focus = Cannon.cameraBehind(Vector3.new(0, 3, -14), Vector3.new(0, 0, 1))
			expect(from.Z < -14 - 10).to.equal(true)
			expect(math.abs(from.X) < 1e-3).to.equal(true)
			expect(from.Y > 3 + 5).to.equal(true)
			expect((focus - Vector3.new(0, 3 + Cannon.HOME_CAMERA.look, -14)).Magnitude < 1e-3).to.equal(
				true
			)
			-- it looks toward what the character faces
			local toFocus = (focus - from).Unit
			expect(toFocus.Z > 0.8).to.equal(true)
			-- a character facing -X (a door to its west): the camera is east of it
			local fromWest = Cannon.cameraBehind(Vector3.new(-20, 3, 90), Vector3.new(-1, 0, 0))
			expect(fromWest.X > -20 + 10).to.equal(true)
			-- a character looking straight up or down still gets a level camera
			local fromUp, focusUp = Cannon.cameraBehind(Vector3.new(0, 3, 0), Vector3.new(0, 1, 0))
			expect(fromUp.Y).to.equal(3 + Cannon.HOME_CAMERA.up)
			expect(focusUp.Y).to.equal(3 + Cannon.HOME_CAMERA.look)
		end)
	end)
end
