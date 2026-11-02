--!strict
-- UI/Components/ProgressRing.luau: the making bubble's ring (F90, cats-make-orders.md section 2) fills clockwise
-- from twelve o'clock, the right half first, then the left.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ProgressRing = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ProgressRing")
	) :: any

	local function turns(progress: number): string
		local right, left = ProgressRing.rotations(progress)
		return string.format("%d,%d", right, left)
	end

	describe("ProgressRing.rotations", function()
		it("hides both halves when empty and shows both when full", function()
			expect(turns(0)).to.equal("0,180")
			expect(turns(1)).to.equal("180,360")
		end)

		it("fills the right half first, then the left", function()
			expect(turns(0.25)).to.equal("90,180")
			expect(turns(0.5)).to.equal("180,180")
			expect(turns(0.75)).to.equal("180,270")
		end)

		it("stays between empty and full for any number", function()
			expect(turns(-1)).to.equal("0,180")
			expect(turns(3)).to.equal("180,360")
			expect(turns(0 / 0)).to.equal("0,180")
		end)
	end)
end
