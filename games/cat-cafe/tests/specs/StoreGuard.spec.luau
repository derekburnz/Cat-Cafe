--!strict
-- UI/Components/StoreGuard.luau: a Robux prompt only right after a tap and never during a catch, a rescue or a
-- cutscene, and the first 30 minutes of play kept quiet (#1936, release.md section 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StoreGuard = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("StoreGuard")
	) :: any

	describe("StoreGuard.allow", function()
		it("lets a prompt through within two seconds of a tap", function()
			expect(StoreGuard.allow({ now = 100, lastTap = 99, busy = false })).to.equal(true)
			expect(StoreGuard.allow({ now = 102, lastTap = 100, busy = false })).to.equal(true)
		end)

		it("refuses a prompt with no tap, an old tap or a tap from the future", function()
			local ok, reason = StoreGuard.allow({ now = 100, lastTap = nil, busy = false })
			expect(ok).to.equal(false)
			expect(reason).to.equal("no_tap")
			local late, lateReason = StoreGuard.allow({ now = 102.5, lastTap = 100, busy = false })
			expect(late).to.equal(false)
			expect(lateReason).to.equal("no_tap")
			expect(StoreGuard.allow({ now = 100, lastTap = 101, busy = false })).to.equal(false)
		end)

		it("refuses during a catch, a rescue or a cutscene even right after a tap", function()
			local ok, reason = StoreGuard.allow({ now = 100, lastTap = 100, busy = true })
			expect(ok).to.equal(false)
			expect(reason).to.equal("busy")
		end)
	end)

	describe("StoreGuard.quiet", function()
		it("is quiet under 30 minutes of total play and not after", function()
			expect(StoreGuard.quiet(0)).to.equal(true)
			expect(StoreGuard.quiet(1799)).to.equal(true)
			expect(StoreGuard.quiet(1800)).to.equal(false)
		end)

		it("treats an unknown play time as past the first half hour", function()
			expect(StoreGuard.quiet(nil)).to.equal(false)
		end)

		it("adds the time since the server sent its total", function()
			expect(StoreGuard.playSeconds(1700, 10, 110)).to.equal(1800)
			expect(StoreGuard.playSeconds(1700, 10, 5)).to.equal(1700)
			expect(StoreGuard.playSeconds(nil, 10, 110)).to.equal(nil)
			expect(StoreGuard.playSeconds(-1, 10, 110)).to.equal(nil)
			expect(StoreGuard.playSeconds(0 / 0, 10, 110)).to.equal(nil)
		end)
	end)
end
