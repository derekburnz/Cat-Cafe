--!strict
-- Big pulls (F89, luck-and-rare-moments.md 2a and 2b): which pulls are big, the confetti's count, flight and fade,
-- and the numbers the spec names. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects big pull", function()
		it("is big for a Legendary, a Mythical or a gold Epic only", function()
			expect(Logic.bigPull("Legendary", false)).to.equal(true)
			expect(Logic.bigPull("Mythical", false)).to.equal(true)
			expect(Logic.bigPull("Mythical", true)).to.equal(true)
			expect(Logic.bigPull("Epic", true)).to.equal(true)
			expect(Logic.bigPull("Epic", false)).to.equal(false)
			expect(Logic.bigPull("Rare", true)).to.equal(false)
			expect(Logic.bigPull("Common", false)).to.equal(false)
			expect(Logic.bigPull(nil, true)).to.equal(false)
		end)

		it("throws the budget's confetti, half with Reduce Motion", function()
			local b = Presets.budget
			expect(Logic.pullCount(b.high.pullConfetti, false)).to.equal(b.high.pullConfetti)
			expect(Logic.pullCount(b.high.pullConfetti, true)).to.equal(
				math.floor(b.high.pullConfetti / 2)
			)
			expect(Logic.pullCount(1, true)).to.equal(2) -- one from each side at least
			expect(b.low.pullConfetti <= b.high.pullConfetti / 2).to.equal(true) -- phones half
			expect(b.lowPerformance.pullConfetti <= math.ceil(b.high.pullConfetti / 3)).to.equal(
				true
			)
			expect(b.lowPerformance.pullConfetti <= b.low.pullConfetti).to.equal(true)
		end)

		it("bursts in from both edges, up and toward the middle", function()
			local c = Presets.bigPull
			local view = Vector2.new(1000, 600)
			local left, leftV = Logic.pullLaunch(-1, 0, 0.5, 0.5, view, c)
			local right, rightV = Logic.pullLaunch(1, 1, 0.5, 0.5, view, c)
			expect(left.X).to.equal(0)
			expect(right.X).to.equal(1000)
			expect(leftV.X > 0 and rightV.X < 0).to.equal(true)
			expect(leftV.Y < 0 and rightV.Y < 0).to.equal(true) -- up the screen
			expect(close(leftV.X, -rightV.X)).to.equal(true)
			expect(close(left.Y, 600 * c.height[1])).to.equal(true)
			expect(close(right.Y, 600 * c.height[2])).to.equal(true)
		end)

		it("rises, slows and falls the same on every frame", function()
			local from, velocity = Vector2.new(0, 400), Vector2.new(500, -600)
			local start = Logic.confettiAt(from, velocity, 900, 1.1, 0)
			expect(close(start.X, 0) and close(start.Y, 400)).to.equal(true)
			local early = Logic.confettiAt(from, velocity, 900, 1.1, 0.2)
			local late = Logic.confettiAt(from, velocity, 900, 1.1, 2)
			expect(early.Y < 400).to.equal(true) -- went up first
			expect(late.Y > early.Y).to.equal(true) -- then fell
			expect(late.X < 500 * 2).to.equal(true) -- drag slowed it
			local plain = Logic.confettiAt(from, velocity, 900, 0, 1)
			expect(close(plain.X, 500) and close(plain.Y, 400 - 600 + 450)).to.equal(true)
		end)

		it("fades out at the end of the card's stay", function()
			local c = Presets.bigPull
			expect(Logic.pullFade(0, c.seconds, c.fade)).to.equal(0)
			expect(Logic.pullFade(c.seconds - c.fade, c.seconds, c.fade)).to.equal(0)
			expect(close(Logic.pullFade(c.seconds - c.fade / 2, c.seconds, c.fade), 0.5)).to.equal(
				true
			)
			expect(Logic.pullFade(c.seconds, c.seconds, c.fade)).to.equal(1)
		end)

		it("matches the spec's numbers and sits over the card", function()
			local c = Presets.bigPull
			expect(c.seconds).to.equal(2.4)
			expect(c.crateShake).to.equal(0.6)
			expect(c.shockwave.diameter).to.equal(20)
			expect(c.displayOrder > 46 and c.displayOrder < 50).to.equal(true) -- over the card (44) and name card
			expect(c.sparkles.at < c.seconds).to.equal(true)
		end)
	end)
end
