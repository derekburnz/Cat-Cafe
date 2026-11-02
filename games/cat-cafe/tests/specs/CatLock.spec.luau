--!strict
-- UI/Components/CatLock.luau: the cat lock as the cat room shows it (F62, data-model section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatLock = require(Components:WaitForChild("CatLock")) :: any

	describe("CatLock.live", function()
		it("stays off until the server sends locked on a cat", function()
			expect(CatLock.live(nil)).to.equal(false)
			expect(CatLock.live({})).to.equal(false)
			expect(CatLock.live({ a = { uid = "a" }, b = { uid = "b" } })).to.equal(false)
		end)

		it("comes on with a boolean locked, false included", function()
			local oneSent = { a = { uid = "a" }, b = { uid = "b", locked = false } }
			expect(CatLock.live(oneSent)).to.equal(true)
			expect(CatLock.live({ a = { uid = "a", locked = true } })).to.equal(true)
		end)
	end)

	describe("CatLock.shown", function()
		it("shows the saved lock, a missing one as unlocked", function()
			expect(CatLock.shown(true, nil, 100)).to.equal(true)
			expect(CatLock.shown(false, nil, 100)).to.equal(false)
			expect(CatLock.shown(nil, nil, 100)).to.equal(false)
		end)

		it("shows a fresh tap until the server agrees", function()
			local tap = { value = true, at = 100 }
			expect(CatLock.shown(false, tap, 101)).to.equal(true)
			expect(CatLock.shown(true, tap, 101)).to.equal(true)
			local unlock = { value = false, at = 100 }
			expect(CatLock.shown(true, unlock, 104.9)).to.equal(false)
		end)

		it("goes back to the saved lock once the hold is over", function()
			local tap = { value = false, at = 100 }
			expect(CatLock.shown(true, tap, 100 + CatLock.HOLD_SECONDS)).to.equal(true)
			expect(CatLock.HOLD_SECONDS).to.equal(5)
		end)
	end)

	describe("CatLock.arrivesLocked", function()
		it("locks gold, Legendary and Mythical cats as they arrive", function()
			expect(CatLock.arrivesLocked("Common", true)).to.equal(true)
			expect(CatLock.arrivesLocked("Legendary", false)).to.equal(true)
			expect(CatLock.arrivesLocked("Mythical", false)).to.equal(true)
		end)

		it("leaves the rest unlocked", function()
			expect(CatLock.arrivesLocked("Common", false)).to.equal(false)
			expect(CatLock.arrivesLocked("Epic", false)).to.equal(false)
			expect(CatLock.arrivesLocked(nil, false)).to.equal(false)
		end)
	end)
end
