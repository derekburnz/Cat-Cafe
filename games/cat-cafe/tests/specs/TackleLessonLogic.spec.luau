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

		it("shows the Tackle cue on the third caption with that device's key (#2469)", function()
			expect(TackleLessonLogic.CUE_SHOT).to.equal(3)
			expect(TackleLessonLogic.cueKey("keyboard")).to.equal("Q")
			expect(TackleLessonLogic.cueKey("gamepad")).to.equal("Y")
			expect(TackleLessonLogic.cueKey("touch")).to.equal("")
			expect(TackleLessonLogic.cueKey("toaster" :: any)).to.equal("Q")
		end)

		it(
			"holds each caption briefly, 0.6 s plus 0.3 s a word, never under the staged beats (#2474)",
			function()
				expect(
					math.abs(TackleLessonLogic.hold("Get tackled and you drop your cat!") - 2.7)
						< 1e-9
				).to.equal(true)
				expect(TackleLessonLogic.hold("Hi")).to.equal(TackleLessonLogic.MIN_HOLD)
				for _, device in { "keyboard", "touch", "gamepad" } do
					local lines = TackleLessonLogic.lines(device)
					local total = 0
					for _, line in lines do
						total += TackleLessonLogic.hold(line)
					end
					expect(total <= 12).to.equal(true)
					-- shot 2's hit at 1.35 s, shot 3's pick-up by about 2.1 s, shot 4's net at 1.05 s
					expect(TackleLessonLogic.hold(lines[2]) >= 1.35 + 0.5).to.equal(true)
					expect(TackleLessonLogic.hold(lines[3]) >= 2.1 + 0.3).to.equal(true)
					expect(TackleLessonLogic.hold(lines[4]) >= 1.05 + 0.5).to.equal(true)
				end
			end
		)

		it(
			"is due as a context tip once a tackled player is safe again, after the tutorial strip (#2626)",
			function()
				local function due(over: { [string]: any }): boolean
					local view: any = { tackled = true, safe = true, seen = false, step = 5 }
					for key, value in over do
						view[key] = value
					end
					return TackleLessonLogic.contextDue(view)
				end
				expect(due({})).to.equal(true)
				expect(due({ tackled = false })).to.equal(false) -- never tackled this session
				expect(due({ safe = false })).to.equal(false) -- still in the catching area
				expect(due({ seen = true })).to.equal(false) -- once per account
				expect(due({ step = 3 })).to.equal(false) -- not during the tutorial
				expect(due({ step = 9 })).to.equal(true)
				local older: any = { tackled = true, safe = true, seen = false } -- an older server sends no step
				expect(TackleLessonLogic.contextDue(older)).to.equal(true)
			end
		)
	end)

	describe("IntroLogic.shotCount (#2198)", function()
		it("takes a lesson's shot count, within 1 and the intro's", function()
			expect(IntroLogic.shotCount(nil)).to.equal(IntroLogic.SHOTS)
			expect(IntroLogic.shotCount({})).to.equal(IntroLogic.SHOTS)
			expect(IntroLogic.shotCount({ shots = 4 })).to.equal(4)
			expect(IntroLogic.shotCount({ shots = 0 })).to.equal(1)
			expect(IntroLogic.shotCount({ shots = 99 })).to.equal(IntroLogic.MAX_SHOTS)
			expect(IntroLogic.shotCount({ shots = 0 / 0 })).to.equal(IntroLogic.SHOTS)
		end)

		it(
			"makes room for the lesson's four captions after the intro's last shot (#2495)",
			function()
				expect(IntroLogic.MAX_SHOTS).to.equal(IntroLogic.SHOTS + 4)
				expect(IntroLogic.LESSON_SHOTS).to.equal(#TackleLessonLogic.lines("keyboard"))
				local tail = IntroLogic.SHOTS + 4
				expect(IntroLogic.shotCount({ shots = tail })).to.equal(tail)
				expect(IntroLogic.shotCount({ shots = tail + 1 })).to.equal(IntroLogic.MAX_SHOTS)
			end
		)
	end)
end
