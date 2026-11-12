--!strict
-- UI/Components/RestChipLogic (#3574): the rest chip's words and its slow z's.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local RestChipLogic = require(Components:WaitForChild("RestChipLogic")) :: any

	describe("Rest chip", function()
		it("names 2x only while it is true", function()
			expect(string.find(RestChipLogic.words(true), "2x", 1, true) ~= nil).to.equal(true)
			expect(string.find(RestChipLogic.words(false), "2x", 1, true)).to.equal(nil)
			-- gentle words: nothing that hurries or tells the player to stay
			for _, doubled in { true, false } do
				local words = string.lower(RestChipLogic.words(doubled))
				for _, bad in { "hurry", "now", "left", "stay", "don't", "miss", "!" } do
					expect(string.find(words, bad, 1, true)).to.equal(nil)
				end
			end
		end)

		it("drifts each z up and to the right, in and out of sight, inside its room", function()
			for index = 1, RestChipLogic.Z_COUNT do
				for step = 0, 72 do
					local x, y, size, gone = RestChipLogic.z(index, step * 0.05)
					expect(x >= 0 and x <= RestChipLogic.Z_SIDE).to.equal(true)
					expect(y <= 0 and y >= -RestChipLogic.Z_RISE).to.equal(true)
					expect(size >= RestChipLogic.Z_SMALL and size <= RestChipLogic.Z_BIG).to.equal(
						true
					)
					expect(gone >= 0 and gone <= 1).to.equal(true)
				end
			end
			-- a z starts and ends out of sight, so its jump back to the start is never seen
			local _, _, _, startGone = RestChipLogic.z(1, 0)
			local _, _, _, endGone = RestChipLogic.z(1, RestChipLogic.Z_SECONDS - 0.001)
			expect(startGone > 0.99).to.equal(true)
			expect(endGone > 0.99).to.equal(true)
		end)

		it("is slow: a new z no more than once a second", function()
			expect(RestChipLogic.Z_SECONDS / RestChipLogic.Z_COUNT >= 1).to.equal(true)
		end)
	end)
end
