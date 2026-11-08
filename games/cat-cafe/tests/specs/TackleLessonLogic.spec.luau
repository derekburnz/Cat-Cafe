--!strict
-- UI/Components/TackleLessonLogic.luau: the tackling lesson's words and timing (#2198).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TackleLessonLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TackleLessonLogic")
	) :: any
	local IntroLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("IntroLogic")
	) :: any

	describe("TackleLessonLogic", function()
		it("plays for the server's tackle_lesson tip (#2409)", function()
			expect(TackleLessonLogic.TIP).to.equal("tackle_lesson")
		end)

		it(
			"has four short captions on every device, the third naming that device's input",
			function()
				for _, device in { "keyboard", "touch", "gamepad" } do
					local lines = TackleLessonLogic.lines(device)
					expect(#lines).to.equal(4)
					for _, line in lines do
						expect(#line <= IntroLogic.MAX_CAPTION).to.equal(true)
					end
				end
				expect(TackleLessonLogic.lines("keyboard")[3]:find("Q", 1, true) ~= nil).to.equal(
					true
				)
				expect(TackleLessonLogic.lines("gamepad")[3]:find("Y", 1, true) ~= nil).to.equal(
					true
				)
				local touch = TackleLessonLogic.lines("touch")[3]
				expect(touch:find("Tap Tackle", 1, true) ~= nil).to.equal(true)
				expect(touch:find("Q", 1, true) == nil).to.equal(true)
			end
		)

		it("holds each caption 1 s plus 0.4 s a word, as the intro does", function()
			expect(
				math.abs(TackleLessonLogic.hold("Get tackled and you drop your cat!") - 3.8) < 1e-9
			).to.equal(true)
			local total = 0
			for _, line in TackleLessonLogic.lines("keyboard") do
				total += TackleLessonLogic.hold(line)
			end
			expect(total < 20).to.equal(true)
		end)
	end)

	describe("IntroLogic.shotCount (#2198)", function()
		it("takes a lesson's shot count, within 1 and the intro's", function()
			expect(IntroLogic.shotCount(nil)).to.equal(IntroLogic.SHOTS)
			expect(IntroLogic.shotCount({})).to.equal(IntroLogic.SHOTS)
			expect(IntroLogic.shotCount({ shots = 4 })).to.equal(4)
			expect(IntroLogic.shotCount({ shots = 0 })).to.equal(1)
			expect(IntroLogic.shotCount({ shots = 99 })).to.equal(IntroLogic.SHOTS)
			expect(IntroLogic.shotCount({ shots = 0 / 0 })).to.equal(IntroLogic.SHOTS)
		end)
	end)
end
