--!strict
-- UI/Components/ParkFirstLogic.luau: the Park-first hint's rules (#2915).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ParkFirstLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ParkFirstLogic")
	) :: any

	local AREAS: { [string]: string } = { tabby = "alley", poodle = "park", bella = "park" }
	local function areaOf(catId: string): string?
		return AREAS[catId]
	end

	local function stray(x: number, props: { [string]: any }?): { [string]: any }
		local made: { [string]: any } = {
			position = Vector3.new(x, 0, 0),
			area = "park",
			lockedBy = 0,
			beginner = 0,
			dropped = false,
		}
		for key, value in props or {} do
			made[key] = value
		end
		return made
	end

	describe("ParkFirstLogic.caught", function()
		it("counts any Park cat in the collection", function()
			expect(ParkFirstLogic.caught({ tabby = 1, poodle = 2 }, areaOf)).to.equal(true)
		end)

		it("is false with only Alleyway cats or no collection", function()
			expect(ParkFirstLogic.caught({ tabby = 1 }, areaOf)).to.equal(false)
			expect(ParkFirstLogic.caught(nil, areaOf)).to.equal(false)
		end)
	end)

	describe("ParkFirstLogic.toastDue", function()
		it("toasts the first Park landing", function()
			expect(ParkFirstLogic.toastDue("park", {}, false)).to.equal(true)
			expect(ParkFirstLogic.toastDue("park", nil, false)).to.equal(true)
		end)

		it("never toasts twice on an account, elsewhere, or after a Park catch", function()
			expect(ParkFirstLogic.toastDue("park", { park_first = true }, false)).to.equal(false)
			expect(ParkFirstLogic.toastDue("woods", {}, false)).to.equal(false)
			expect(ParkFirstLogic.toastDue("park", {}, true)).to.equal(false)
		end)
	end)

	describe("ParkFirstLogic.nudgeDue", function()
		it("rings after 90 s in the Park with no Park cat, once", function()
			expect(ParkFirstLogic.nudgeDue(89, false, false)).to.equal(false)
			expect(ParkFirstLogic.nudgeDue(90, false, false)).to.equal(true)
			expect(ParkFirstLogic.nudgeDue(120, false, true)).to.equal(false)
			expect(ParkFirstLogic.nudgeDue(120, true, false)).to.equal(false)
		end)
	end)

	describe("ParkFirstLogic.pick", function()
		local ME = 7

		it("picks the nearest free Park stray in range", function()
			local list = { stray(40), stray(12), stray(25) }
			expect(ParkFirstLogic.pick(list, Vector3.zero, ME, 60)).to.equal(2)
		end)

		it(
			"skips strays out of range, in other areas, dropped, locked or another player's beginner",
			function()
				local list = {
					stray(70),
					stray(5, { area = "alley" }),
					stray(6, { dropped = true }),
					stray(7, { lockedBy = 99 }),
					stray(8, { beginner = 99 }),
				}
				expect(ParkFirstLogic.pick(list, Vector3.zero, ME, 60)).to.equal(nil)
			end
		)

		it("keeps a stray this player holds the lock or the beginner tag on", function()
			local list = { stray(30), stray(9, { lockedBy = ME }), stray(10, { beginner = ME }) }
			expect(ParkFirstLogic.pick(list, Vector3.zero, ME, 60)).to.equal(2)
		end)
	end)
end
