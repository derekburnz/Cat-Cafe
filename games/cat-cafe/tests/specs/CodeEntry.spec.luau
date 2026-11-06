--!strict
-- UI/Components/CodeEntry.luau: what the code box lets through (F65, data-model section 11d).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CodeEntry = require(Components:WaitForChild("CodeEntry")) :: any
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config) :: any

	describe("CodeEntry.clean", function()
		it(
			"keeps letters, digits and the code symbols in either case and drops the rest",
			function()
				expect(CodeEntry.clean("PlayTest")).to.equal("PlayTest")
				expect(CodeEntry.clean(" play test! ")).to.equal("playtest!")
				expect(CodeEntry.clean("likes-1000")).to.equal("likes-1000")
				expect(CodeEntry.clean("cat@cafe#1?")).to.equal("cat@cafe#1?")
				expect(CodeEntry.clean('gr/ou"p')).to.equal("group")
				expect(CodeEntry.clean("caf\u{E9}")).to.equal("caf")
				expect(CodeEntry.clean("")).to.equal("")
			end
		)

		it("stops at the server's CodeMaxLength", function()
			local max = Config.CodeMaxLength or 20
			expect(CodeEntry.MAX_LENGTH).to.equal(max)
			local long = string.rep("a", max + 5)
			expect(#CodeEntry.clean(long)).to.equal(max)
		end)
	end)

	describe("CodeEntry.canRedeem", function()
		it("lights Redeem once a letter, digit or symbol is in", function()
			expect(CodeEntry.canRedeem("")).to.equal(false)
			expect(CodeEntry.canRedeem("   ")).to.equal(false)
			expect(CodeEntry.canRedeem("/ ()")).to.equal(false)
			expect(CodeEntry.canRedeem("!?")).to.equal(true)
			expect(CodeEntry.canRedeem("a")).to.equal(true)
			expect(CodeEntry.canRedeem("7")).to.equal(true)
		end)
	end)

	describe("CodeEntry.used (#1714)", function()
		it(
			"lists the used codes newest first, in caps, with the prize while the code is known",
			function()
				local codes = { playtest = { id = "playtest", prize = { spins = 3 } } }
				local list = CodeEntry.used({ playtest = 200, old_code = 100, newer = 300 }, codes)
				expect(#list).to.equal(3)
				expect(list[1].code).to.equal("NEWER")
				expect(list[1].prize).to.equal(nil)
				expect(list[2].code).to.equal("PLAYTEST")
				expect(list[2].prize.spins).to.equal(3)
				expect(list[3].at).to.equal(100)
			end
		)
		it("is empty with nothing used or no state", function()
			expect(#CodeEntry.used(nil, nil)).to.equal(0)
			expect(#CodeEntry.used({}, {})).to.equal(0)
			expect(#CodeEntry.used({ [1] = 5 } :: any, nil)).to.equal(0)
		end)
	end)
end
