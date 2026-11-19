--!strict
-- Effects/AdventFx (#5502): the advent board shows nothing until the server's view is live, swings only doors opened
-- since the last live view, and opens each door out to its front about its hinge.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local AdventFx = require(Effects:WaitForChild("AdventFx")) :: any

	describe("AdventFx", function()
		it("reads the server's view, closed for junk", function()
			local junk = AdventFx.read(nil)
			expect(junk.live).to.equal(false)
			expect(junk.opened).to.equal(0)
			local v = AdventFx.read({ live = true, opened = 30, ready = true })
			expect(v.opened).to.equal(24)
			expect(AdventFx.read({ live = "yes", opened = 0 / 0 }).live).to.equal(false)
		end)

		it("swings only doors opened between two live views", function()
			local a = { live = true, opened = 3, ready = true }
			local b = { live = true, opened = 5, ready = false }
			local list = AdventFx.newlyOpened(a, b)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal(4)
			expect(list[2]).to.equal(5)
			expect(#AdventFx.newlyOpened({ live = false, opened = 0, ready = false }, b)).to.equal(
				0
			)
			expect(#AdventFx.newlyOpened(b, a)).to.equal(0)
		end)

		it("glows the next door only while live and ready", function()
			expect(AdventFx.readyDoor({ live = true, opened = 5, ready = true })).to.equal(6)
			expect(AdventFx.readyDoor({ live = true, opened = 5, ready = false })).to.equal(0)
			expect(AdventFx.readyDoor({ live = false, opened = 0, ready = true })).to.equal(0)
			expect(AdventFx.readyDoor({ live = true, opened = 24, ready = true })).to.equal(0)
			expect(AdventFx.isCatDoor(6)).to.equal(true)
			expect(AdventFx.isCatDoor(7)).to.equal(false)
		end)

		it("swings from shut to open with a little overshoot", function()
			expect(AdventFx.swing(0, 0.5, 0.17)).to.equal(0)
			expect(AdventFx.swing(0.5, 0.5, 0.17)).to.equal(1)
			local most = 0
			for i = 1, 49 do
				most = math.max(most, AdventFx.swing(i / 100, 0.5, 0.17))
			end
			expect(most > 1 and most < 1.25).to.equal(true)
		end)

		it("opens a door out to its front about its +X hinge", function()
			local x, z = AdventFx.hingeShift(2, math.rad(90))
			-- a quarter turn: the middle ends 1 stud toward the hinge and 1 stud out the front
			expect(math.abs(x - 1) < 1e-6).to.equal(true)
			expect(math.abs(z + 1) < 1e-6).to.equal(true)
			local x0, z0 = AdventFx.hingeShift(2, 0)
			expect(math.abs(x0) < 1e-9 and math.abs(z0) < 1e-9).to.equal(true)
			-- the hinge edge (+1, 0) stays put: the middle's shift plus the turned half width
			local a = math.rad(105)
			local hx, hz = AdventFx.hingeShift(2, a)
			expect(math.abs(hx + math.cos(a) - 1) < 1e-6).to.equal(true)
			expect(math.abs(hz + math.sin(a)) < 1e-6).to.equal(true)
		end)
	end)
end
