--!strict
-- UI/Components/PipWindow.luau: the catch strip shows at most ten pips and slides with the play (#2332).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PipWindow = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PipWindow")
	) :: any

	local function range(count: number, upTo: number): string
		local first, last = PipWindow.range(count, upTo)
		return first .. "-" .. last
	end

	describe("PipWindow.range", function()
		it("shows every pip of a short catch", function()
			expect(range(6, 1)).to.equal("1-6")
			expect(range(6, 6)).to.equal("1-6")
		end)

		it("shows the first ten of a long catch until the play passes them", function()
			expect(range(30, 1)).to.equal("1-10")
			expect(range(30, 10)).to.equal("1-10")
		end)

		it("slides so the next ring stays the rightmost", function()
			expect(range(30, 11)).to.equal("2-11")
			expect(range(30, 30)).to.equal("21-30")
			expect(range(30, 40)).to.equal("21-30")
		end)

		it("shows nothing with no rings", function()
			expect(range(0, 1)).to.equal("1-0")
		end)
	end)
end
