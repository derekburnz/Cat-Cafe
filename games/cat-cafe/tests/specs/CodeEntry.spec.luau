--!strict
-- UI/Components/CodeEntry.luau: what the code box lets through (F65, data-model section 11d).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CodeEntry = require(Components:WaitForChild("CodeEntry")) :: any
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config) :: any

	describe("CodeEntry.clean", function()
		it("keeps letters and digits in either case and drops the rest", function()
			expect(CodeEntry.clean("PlayTest")).to.equal("PlayTest")
			expect(CodeEntry.clean(" play test! ")).to.equal("playtest")
			expect(CodeEntry.clean("likes-1000")).to.equal("likes1000")
			expect(CodeEntry.clean("caf\u{E9}")).to.equal("caf")
			expect(CodeEntry.clean("")).to.equal("")
		end)

		it("stops at the server's CodeMaxLength", function()
			local max = Config.CodeMaxLength or 20
			expect(CodeEntry.MAX_LENGTH).to.equal(max)
			local long = string.rep("a", max + 5)
			expect(#CodeEntry.clean(long)).to.equal(max)
		end)
	end)

	describe("CodeEntry.canRedeem", function()
		it("lights Redeem once a letter or digit is in", function()
			expect(CodeEntry.canRedeem("")).to.equal(false)
			expect(CodeEntry.canRedeem("   ")).to.equal(false)
			expect(CodeEntry.canRedeem("!?")).to.equal(false)
			expect(CodeEntry.canRedeem("a")).to.equal(true)
			expect(CodeEntry.canRedeem("7")).to.equal(true)
		end)
	end)
end
