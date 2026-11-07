--!strict
-- UI/Components/TouchPrompt.luau (#2315): when the catch card offers its press-and-hold button instead of "[E] HOLD".
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TouchPrompt = require(Components:WaitForChild("TouchPrompt")) :: any

	describe("TouchPrompt.wants", function()
		it(
			"shows the button when Roblox says the prompt is pressed by touch, keyboard or not",
			function()
				expect(TouchPrompt.wants(true, "Keyboard", false)).to.equal(true)
			end
		)

		it("shows the button when the last input was a touch", function()
			expect(TouchPrompt.wants(nil, "Touch", false)).to.equal(true)
			expect(TouchPrompt.wants(false, "Touch", false)).to.equal(true)
		end)

		it("shows the button on a touch-only device", function()
			expect(TouchPrompt.wants(nil, "None", true)).to.equal(true)
		end)

		it("shows the key cap on a keyboard and mouse or a gamepad", function()
			expect(TouchPrompt.wants(false, "MouseMovement", false)).to.equal(false)
			expect(TouchPrompt.wants(false, "Keyboard", false)).to.equal(false)
			expect(TouchPrompt.wants(nil, "Gamepad1", false)).to.equal(false)
		end)
	end)
end
