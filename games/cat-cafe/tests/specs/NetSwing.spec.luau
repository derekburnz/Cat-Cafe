--!strict
-- shared/NetSwing.luau against catch-rework.md section 1 (F93): what a swing lands on (reach, slack and the arc), the
-- nearest of several, a near miss's hop, the new player rule, the refusals and the net_swing result. QA check 3: a
-- free stray 7 studs ahead is hit; one 9 studs away or behind the player is not.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local NetSwing = require(Shared.NetSwing)

	local ORIGIN = Vector3.new(10, 3, -4)
	local AHEAD = Vector3.new(0, 0, -1) -- the root's LookVector

	-- A point `studs` from the origin on the ground plane, `degrees` off the facing (positive to the right).
	local function at(studs: number, degrees: number, up: number?): Vector3
		local r = math.rad(degrees)
		return ORIGIN + Vector3.new(math.sin(r) * studs, up or 0, -math.cos(r) * studs)
	end

	local function check(overrides: { [string]: any }?): NetSwing.SwingCheck
		local base: { [string]: any } = {
			carrying = false,
			busy = false,
			inFlight = false,
			inCamp = false,
			sinceSwing = nil,
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base :: any
	end

	describe("the numbers (catch-rework.md section 5)", function()
		it("reaches NetReachStuds 7 plus NetSlackStuds 1.5, 60 degrees either side", function()
			expect(Config.NetReachStuds).to.equal(7)
			expect(Config.NetSlackStuds).to.be.near(1.5, 1e-12)
			expect(NetSwing.reach()).to.be.near(8.5, 1e-12)
			expect(Config.NetArcDegrees).to.equal(60)
			expect(Config.NetSwingCooldown).to.be.near(0.8, 1e-12)
			expect(Config.NetSmackDelay).to.be.near(0.15, 1e-12)
		end)

		it(
			"the smack lands inside the cooldown, so one swing is judged before the next can go",
			function()
				expect(Config.NetSmackDelay < Config.NetSwingCooldown - NetSwing.COOLDOWN_SLACK).to.equal(
					true
				)
			end
		)
	end)

	describe("reach (QA check 3)", function()
		it("hits a stray 7 studs straight ahead", function()
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(7, 0))).to.equal(true)
		end)

		it("misses one 9 studs ahead and one right behind the player", function()
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(9, 0))).to.equal(false)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(3, 180))).to.equal(false)
		end)

		it("takes the slack for latency: 8.4 studs is in, 8.6 out", function()
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(8.4, 10))).to.equal(true)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(8.6, 10))).to.equal(false)
		end)

		it("covers 60 degrees either side of the facing and no more", function()
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(5, 59))).to.equal(true)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(5, -59))).to.equal(true)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(5, 61))).to.equal(false)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(5, -61))).to.equal(false)
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(5, 90))).to.equal(false)
		end)

		it("a cat at the feet is hit whichever way the player faces", function()
			expect(NetSwing.inReach(ORIGIN, AHEAD, at(0.5, 180))).to.equal(true)
		end)

		it(
			"measures reach in 3D, so a cat up on a perch stays out of reach from the ground",
			function()
				expect(NetSwing.inReach(ORIGIN, AHEAD, at(3, 0, 2))).to.equal(true)
				expect(NetSwing.inReach(ORIGIN, AHEAD, at(3, 0, 9))).to.equal(false)
			end
		)

		it("ignores how far the facing tips up or down", function()
			local tipped = Vector3.new(0, -0.6, -0.8)
			expect(NetSwing.inReach(ORIGIN, tipped, at(6, 20))).to.equal(true)
			expect(NetSwing.inReach(ORIGIN, Vector3.new(0, 1, 0), at(6, 20))).to.equal(false)
		end)
	end)

	describe("pick", function()
		it("lands on the nearest stray in reach", function()
			local picked = NetSwing.pick(ORIGIN, AHEAD, {
				{ id = "far", position = at(7, 0) },
				{ id = "near", position = at(4, 40) },
				{ id = "behind", position = at(2, 170) },
			})
			expect(picked).to.be.ok()
			expect((picked :: NetSwing.Target).id).to.equal("near")
		end)

		it("lands on nothing when every stray is out of reach or out of the arc", function()
			expect(NetSwing.pick(ORIGIN, AHEAD, {
				{ id = "far", position = at(10, 0) },
				{ id = "side", position = at(4, 75) },
			})).never.to.be.ok()
			expect(NetSwing.pick(ORIGIN, AHEAD, {})).never.to.be.ok()
		end)
	end)

	describe("a near miss (QA check 4)", function()
		it(
			"counts free strays within NetMissHopStuds 12 on the ground, whichever way the player faces",
			function()
				expect(Config.NetMissHopStuds).to.equal(12)
				expect(NetSwing.nearMiss(ORIGIN, at(11.9, 180))).to.equal(true)
				expect(NetSwing.nearMiss(ORIGIN, at(12.1, 0))).to.equal(false)
				expect(NetSwing.nearMiss(ORIGIN, at(5, 0, 40))).to.equal(true) -- height does not count
			end
		)

		it(
			"hops a quarter of the rarity's sprint: 6 studs for a Common up to 16 for a Mythical",
			function()
				expect(Config.NetMissHopShare).to.be.near(0.25, 1e-12)
				expect(NetSwing.hopStuds("Common")).to.be.near(6, 1e-9)
				expect(NetSwing.hopStuds("Mythical")).to.be.near(16, 1e-9)
				for _, rarity in Catalog.rarityOrder do
					expect(NetSwing.hopStuds(rarity)).to.be.near(
						Catalog.rarities[rarity].fleeStuds / 4,
						1e-9
					)
				end
			end
		)

		it(
			"a player who has not caught a cat yet never makes one hop (easy-start.md section 2b)",
			function()
				expect(NetSwing.missHops(0)).to.equal(false)
				expect(NetSwing.missHops(1)).to.equal(false)
				expect(NetSwing.missHops(2)).to.equal(true)
				expect(NetSwing.missHops(9)).to.equal(true)
			end
		)

		it("reports hit, miss_near or miss_empty for net_swing", function()
			expect(NetSwing.result(true, 0)).to.equal("hit")
			expect(NetSwing.result(true, 3)).to.equal("hit")
			expect(NetSwing.result(false, 2)).to.equal("miss_near")
			expect(NetSwing.result(false, 0)).to.equal("miss_empty")
		end)
	end)

	describe("refusals (catch-rework.md section 1)", function()
		it("swings when nothing stands in the way, the first time and a cooldown later", function()
			expect(NetSwing.refusal(check())).never.to.be.ok()
			expect(NetSwing.refusal(check({ sinceSwing = 0.8 }))).never.to.be.ok()
		end)

		it("never while carrying, mid catch or rescue, flying or in a camp", function()
			expect(NetSwing.refusal(check({ carrying = true }))).to.equal("carrying")
			expect(NetSwing.refusal(check({ busy = true }))).to.equal("busy")
			expect(NetSwing.refusal(check({ inFlight = true }))).to.equal("flight")
			expect(NetSwing.refusal(check({ inCamp = true }))).to.equal("camp")
		end)

		it(
			"once per NetSwingCooldown, with a little slack for the ping between two presses",
			function()
				expect(NetSwing.refusal(check({ sinceSwing = 0.2 }))).to.equal("cooldown")
				expect(NetSwing.refusal(check({ sinceSwing = 0.69 }))).to.equal("cooldown")
				expect(NetSwing.refusal(check({ sinceSwing = 0.71 }))).never.to.be.ok()
			end
		)
	end)
end
