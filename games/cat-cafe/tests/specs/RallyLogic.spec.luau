--!strict
-- UI/Components/RallyLogic.luau: the Rescue Rally banner and board words, the line under the clock before a
-- Rally and the Cat Cannon's night tag (F101, rescue-rally.md sections 1 to 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RallyLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RallyLogic")
	) :: any

	local NOW = 100000
	local HOUR = 3600

	local function rally(extra: { [string]: any }?): any
		local state: { [string]: any } = {
			active = true,
			endsAt = NOW + 28 * HOUR,
			startsAt = NOW - 20 * HOUR,
			lap = 1,
			goal = 90,
			points = 50,
			myPoints = 7,
			lapsPaid = 0,
			lapsDone = false,
		}
		for key, value in extra or {} do
			state[key] = value
		end
		return state
	end

	describe("RallyLogic.left", function()
		it("reads days and hours, hours and minutes, or minutes", function()
			expect(RallyLogic.left(28 * HOUR)).to.equal("1d 4h")
			expect(RallyLogic.left(24 * HOUR)).to.equal("1d")
			expect(RallyLogic.left(5 * HOUR + 20 * 60)).to.equal("5h 20m")
			expect(RallyLogic.left(2 * HOUR)).to.equal("2h")
			expect(RallyLogic.left(12 * 60)).to.equal("12m")
		end)

		it("rounds up and never reads less than a minute", function()
			expect(RallyLogic.left(HOUR - 30)).to.equal("1h")
			expect(RallyLogic.left(10)).to.equal("1m")
			expect(RallyLogic.left(0)).to.equal("1m")
		end)
	end)

	describe("RallyLogic.stepPicture", function()
		it("shows the crate first, then the potion, else the golden fish", function()
			local crate = RallyLogic.stepPicture({ fish = 15, crates = { rally_crate = 1 } })
			expect(crate.kind).to.equal("crate")
			expect(crate.id).to.equal("rally_crate")
			local potion = RallyLogic.stepPicture({ fish = 10, potions = { tip_potion = 1 } })
			expect(potion.kind).to.equal("potion")
			expect(potion.id).to.equal("tip_potion")
			expect(RallyLogic.stepPicture({ fish = 5 }).kind).to.equal("fish")
			expect(RallyLogic.stepPicture(nil).kind).to.equal("fish")
		end)
	end)

	describe("RallyLogic.view", function()
		it("is nil with no Rally, before it starts and once it ends", function()
			expect(RallyLogic.view(nil, NOW)).to.equal(nil)
			expect(RallyLogic.view(rally({ active = false }), NOW)).to.equal(nil)
			expect(RallyLogic.view(rally({ endsAt = NOW - 1 }), NOW)).to.equal(nil)
			expect(RallyLogic.view(rally({ endsAt = 0 }), NOW)).to.equal(nil)
		end)

		it("fills the bar and reads the points and the time left", function()
			local view = RallyLogic.view(rally(), NOW)
			expect(view.lap).to.equal(nil)
			expect(view.fill).to.equal(50 / 90)
			expect(view.points).to.equal("50 / 90")
			expect(view.left).to.equal("1d 4h left")
			expect(view.done).to.equal(false)
		end)

		it("puts the three steps at 25%, 50% and the end with their pictures", function()
			local view = RallyLogic.view(rally(), NOW)
			expect(#view.steps).to.equal(3)
			expect(view.steps[1].share).to.equal(0.25)
			expect(view.steps[2].share).to.equal(0.5)
			expect(view.steps[3].share).to.equal(1)
			expect(view.steps[1].picture.kind).to.equal("fish")
			expect(view.steps[2].picture.kind).to.equal("potion")
			expect(view.steps[3].picture.kind).to.equal("crate")
			expect(view.steps[1].reached).to.equal(true)
			expect(view.steps[2].reached).to.equal(true)
			expect(view.steps[3].reached).to.equal(false)
		end)

		it("reaches a step at the server's point (Rally.stepAt rounds up)", function()
			-- 25% of 90 is 22.5, so the first step pays at 23
			expect(RallyLogic.view(rally({ points = 22 }), NOW).steps[1].reached).to.equal(false)
			expect(RallyLogic.view(rally({ points = 23 }), NOW).steps[1].reached).to.equal(true)
		end)

		it("shows the lap from the second and keeps the bar inside its goal", function()
			local view = RallyLogic.view(rally({ lap = 2, points = 95 }), NOW)
			expect(view.lap).to.equal("Lap 2")
			expect(view.fill).to.equal(1)
			expect(view.points).to.equal("90 / 90")
			expect(RallyLogic.view(rally({ goal = 0, points = 0 }), NOW).points).to.equal("0 / 1")
		end)

		it("tells this player how far they are from sharing the prizes", function()
			local function mine(points: number): string
				return RallyLogic.view(rally({ myPoints = points }), NOW).mine
			end
			expect(mine(0)).to.equal("Score 3 points to share the prizes")
			expect(mine(1)).to.equal("2 more points to share the prizes")
			expect(mine(2)).to.equal("1 more point to share the prizes")
			expect(mine(3)).to.equal("You: 3 points")
			expect(mine(7)).to.equal("You: 7 points")
		end)

		it("says when this player's laps are used up", function()
			local view = RallyLogic.view(rally({ lapsPaid = 4, lapsDone = true }), NOW)
			expect(view.mine).to.equal("You've done your laps this weekend")
			expect(view.done).to.equal(true)
		end)
	end)

	describe("RallyLogic.soon", function()
		local function waiting(startsAt: number): any
			return rally({ active = false, endsAt = 0, startsAt = startsAt })
		end

		it("counts down in the last 12 hours before a Rally", function()
			expect(RallyLogic.soon(waiting(NOW + 5 * HOUR + 20 * 60), NOW)).to.equal("Rescue Rally in 5h 20m")
			expect(RallyLogic.soon(waiting(NOW + 12 * HOUR), NOW)).to.equal("Rescue Rally in 12h")
		end)

		it("is nil further out, while it runs, once it is due and with no state", function()
			expect(RallyLogic.soon(waiting(NOW + 13 * HOUR), NOW)).to.equal(nil)
			expect(RallyLogic.soon(rally({ startsAt = NOW + HOUR }), NOW)).to.equal(nil)
			expect(RallyLogic.soon(waiting(NOW - 1), NOW)).to.equal(nil)
			expect(RallyLogic.soon(nil, NOW)).to.equal(nil)
		end)
	end)

	describe("RallyLogic.nightLine", function()
		it("tags the Cat Cannon's cards at night while a Rally runs", function()
			expect(RallyLogic.nightLine(rally(), NOW, true)).to.equal("Rally: rescues x3")
		end)

		it("is nil by day, with no Rally and once it ends", function()
			expect(RallyLogic.nightLine(rally(), NOW, false)).to.equal(nil)
			expect(RallyLogic.nightLine(rally({ active = false }), NOW, true)).to.equal(nil)
			expect(RallyLogic.nightLine(rally({ endsAt = NOW - 1 }), NOW, true)).to.equal(nil)
			expect(RallyLogic.nightLine(nil, NOW, true)).to.equal(nil)
		end)
	end)
end
