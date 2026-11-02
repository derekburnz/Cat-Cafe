--!strict
-- UI/Components/WelcomeBack.luau: the welcome back card's line on what time away pays (F95 section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local WelcomeBack = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("WelcomeBack")
	) :: any

	describe("WelcomeBack.note", function()
		it("says the free rate and cap, and the Long Nap pass's, in section 5's words", function()
			expect(WelcomeBack.note(nil)).to.equal("Half pay while away, up to 8 hours")
			expect(WelcomeBack.note(false)).to.equal("Half pay while away, up to 8 hours")
			expect(WelcomeBack.note(true)).to.equal("Full pay, up to 16 hours")
		end)
	end)

	describe("WelcomeBack words", function()
		it("names the rate", function()
			expect(WelcomeBack.payWord(1)).to.equal("Full pay")
			expect(WelcomeBack.payWord(0.5)).to.equal("Half pay")
			expect(WelcomeBack.payWord(0.25)).to.equal("Quarter pay")
			expect(WelcomeBack.payWord(0.4)).to.equal("40% pay")
		end)

		it("names the cap in hours or minutes", function()
			expect(WelcomeBack.span(28800)).to.equal("8 hours")
			expect(WelcomeBack.span(3600)).to.equal("1 hour")
			expect(WelcomeBack.span(1800)).to.equal("30 minutes")
			expect(WelcomeBack.span(5400)).to.equal("90 minutes")
		end)
	end)
end
