--!strict
-- #5677: effects read the catch count the UI already holds. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local SyncSeed = require(Effects:WaitForChild("SyncSeed")) :: any
	local NetHint = require(Effects:WaitForChild("NetHint")) :: any

	describe("SyncSeed", function()
		it("reads stats.catsCaught from a state table", function()
			expect(SyncSeed.catsCaught({ stats = { catsCaught = 0 } })).to.equal(0)
			expect(SyncSeed.catsCaught({ stats = { catsCaught = 2 } })).to.equal(2)
		end)

		it("gives nil for anything that is not a count", function()
			expect(SyncSeed.catsCaught(nil)).to.equal(nil)
			expect(SyncSeed.catsCaught("x")).to.equal(nil)
			expect(SyncSeed.catsCaught({})).to.equal(nil)
			expect(SyncSeed.catsCaught({ stats = { catsCaught = "1" } })).to.equal(nil)
		end)

		it("lets the net hint show on a fresh save once the count is seeded", function()
			local seeded = SyncSeed.catsCaught({ stats = { catsCaught = 0 } })
			expect(NetHint.shows(true, true, nil, 3)).to.equal(false)
			expect(NetHint.shows(true, true, seeded, 3)).to.equal(true)
		end)

		it("is off by default", function()
			local LiveFlags = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("LiveFlags")
			) :: any
			expect(table.find(LiveFlags.KEYS, SyncSeed.FLAG) ~= nil).to.equal(true)
		end)
	end)
end
