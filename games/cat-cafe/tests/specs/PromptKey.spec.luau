--!strict
-- UI/Components/PromptKey.luau: the key cap text on the action pills (custom ProximityPrompts).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local PromptKey = require(Components:WaitForChild("PromptKey")) :: any

	describe("PromptKey.label", function()
		it("shows a letter key as itself", function()
			expect(PromptKey.label("Keyboard", "E")).to.equal("E")
			expect(PromptKey.label("Keyboard", "F")).to.equal("F")
		end)

		it("shortens number and modifier keys", function()
			expect(PromptKey.label("Keyboard", "One")).to.equal("1")
			expect(PromptKey.label("Keyboard", "LeftShift")).to.equal("Shift")
			expect(PromptKey.label("Keyboard", "Return")).to.equal("Enter")
		end)

		it("drops the Button prefix on gamepad keys", function()
			expect(PromptKey.label("Gamepad", "ButtonX")).to.equal("X")
			expect(PromptKey.label("Gamepad", "ButtonR1")).to.equal("R1")
			expect(PromptKey.label("Gamepad", "DPadUp")).to.equal("↑")
		end)

		it("names no key on touch, where the pill is the button", function()
			expect(PromptKey.label("Touch", "E")).to.equal("")
		end)
	end)

	describe("PromptKey.width", function()
		it("keeps one and two character caps square", function()
			expect(PromptKey.width("E", 38)).to.equal(38)
			expect(PromptKey.width("R1", 38)).to.equal(38)
		end)

		it("widens caps for words", function()
			expect(PromptKey.width("Shift", 38) > 38).to.equal(true)
			expect(PromptKey.width("Space", 38) > PromptKey.width("Tab", 38)).to.equal(true)
		end)
	end)
end
