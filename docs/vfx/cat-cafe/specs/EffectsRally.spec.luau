--!strict
-- The Rescue Rally (F101, rescue-rally.md section 4) and Trade done (F102, trading.md section 3 step 6): how full
-- the bar is and which steps a state crossed, the flight of a "+1" or a traded cat's picture, the bunting's hinge
-- and flutter, and the budgets. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	local function list(t: { number }): string
		local out = {}
		for _, v in t do
			table.insert(out, tostring(v))
		end
		return table.concat(out, ",")
	end

	describe("Effects Rescue Rally and Trade done", function()
		it("fills the bar from the points and the goal", function()
			expect(Logic.rallyFill(0, 90)).to.equal(0)
			expect(close(Logic.rallyFill(45, 90), 0.5)).to.equal(true)
			expect(Logic.rallyFill(120, 90)).to.equal(1)
			expect(Logic.rallyFill(5, 0)).to.equal(0)
		end)

		it("plays each step once, the full bar on a new lap", function()
			local steps = Presets.rally.steps
			expect(list(steps)).to.equal("0.25,0.5,1")
			expect(list(Logic.rallySteps(0.2, 1, 0.3, 1, steps))).to.equal("0.25")
			expect(list(Logic.rallySteps(0.3, 1, 0.4, 1, steps))).to.equal("")
			expect(list(Logic.rallySteps(0.2, 1, 0.6, 1, steps))).to.equal("0.25,0.5")
			-- the bar filled: the next lap starts near empty
			expect(list(Logic.rallySteps(0.9, 1, 0.02, 2, steps))).to.equal("1")
			expect(list(Logic.rallySteps(0.4, 1, 0.3, 2, steps))).to.equal("0.5,1,0.25")
			-- a state at the full bar before the new lap still plays the full bar once, with the new lap
			expect(list(Logic.rallySteps(0.9, 1, 1, 1, steps))).to.equal("")
			expect(list(Logic.rallySteps(1, 1, 0, 2, steps))).to.equal("1")
			-- a new weekend or a fresh server
			expect(list(Logic.rallySteps(0.6, 3, 0.1, 1, steps))).to.equal("")
		end)

		it("flies a pop along a curve that starts and ends where it should", function()
			local from, to = Vector2.new(100, 400), Vector2.new(300, 50)
			local bend = Logic.flyBend(from, to, 0.2)
			local start = Logic.curve(from, bend, to, 0)
			local finish = Logic.curve(from, bend, to, 1)
			expect(close(start.X, 100) and close(start.Y, 400)).to.equal(true)
			expect(close(finish.X, 300) and close(finish.Y, 50)).to.equal(true)
			-- a flight to the left with lift above 0 arcs up (smaller y on the screen)
			local left = Logic.flyBend(Vector2.new(600, 300), Vector2.new(60, 300), 0.22)
			expect(left.Y < 300).to.equal(true)
			expect(close(left.X, 330)).to.equal(true)
			expect(Logic.easeInOut(0)).to.equal(0)
			expect(Logic.easeInOut(1)).to.equal(1)
			expect(close(Logic.easeInOut(0.5), 0.5)).to.equal(true)
		end)

		it("pops in with a little overshoot and lands smaller", function()
			local r = Presets.rally
			expect(close(Logic.popScale(0, r.seconds, r.popIn, r.land), 0)).to.equal(true)
			local peak = 0
			for i = 1, 20 do
				peak = math.max(peak, Logic.popScale(r.popIn * i / 20, r.seconds, r.popIn, r.land))
			end
			expect(peak > 1 and peak < 1.2).to.equal(true)
			expect(close(Logic.popScale(r.popIn, r.seconds, r.popIn, r.land), 1)).to.equal(true)
			expect(close(Logic.popScale(r.seconds, r.seconds, r.popIn, r.land), r.land)).to.equal(
				true
			)
		end)

		it("hinges a pennant on its top edge along the string", function()
			-- a flat pennant 2 wide (X), 1.6 tall (Y) and 0.1 thick (Z), hanging upright
			local along, up, half = Logic.pennantHinge(
				Vector3.xAxis,
				Vector3.yAxis,
				Vector3.zAxis,
				Vector3.new(2, 1.6, 0.1)
			)
			expect(along == Vector3.xAxis).to.equal(true)
			expect(up == Vector3.yAxis).to.equal(true)
			expect(close(half, 0.8)).to.equal(true)
			-- the same pennant modelled upside down and lying along Z: thin X, tall Y turned down, string along Z
			local along2, up2, half2 = Logic.pennantHinge(
				Vector3.xAxis,
				-Vector3.yAxis,
				Vector3.zAxis,
				Vector3.new(0.1, 1.6, 2)
			)
			expect(along2 == Vector3.zAxis).to.equal(true)
			expect(up2 == Vector3.yAxis).to.equal(true)
			expect(close(half2, 0.8)).to.equal(true)
		end)

		it("runs a gust across the bunting with the wind and keeps the swing gentle", function()
			local b = Presets.bunting
			local wind = Vector3.new(3, 0, 0)
			expect(close(Logic.windPhase(Vector3.new(0, 5, 0), wind, b.wavelength), 0)).to.equal(
				true
			)
			expect(
				close(
					Logic.windPhase(Vector3.new(b.wavelength, 5, 0), wind, b.wavelength),
					2 * math.pi
				)
			).to.equal(true)
			expect(close(Logic.windPhase(Vector3.new(0, 0, 7), wind, b.wavelength), 0)).to.equal(
				true
			)
			expect(
				close(
					Logic.windPhase(Vector3.new(9, 0, 0), Vector3.zero, b.wavelength),
					Logic.windPhase(Vector3.new(9, 0, 0), Vector3.xAxis, b.wavelength)
				)
			).to.equal(true)
			local least: number, most: number = math.huge, -math.huge
			for i = 0, 200 do
				local angle: number = Logic.flutter(i * 0.05, 0.3, b)
				least, most = math.min(least, angle), math.max(most, angle)
			end
			expect(most <= b.lean + b.swing + 1e-6).to.equal(true)
			expect(least >= b.lean - b.swing - 1e-6).to.equal(true)
			local width: number = most - least
			expect(width > b.swing).to.equal(true)
		end)

		it("keeps the screen pops and the bunting in budget", function()
			local budget = Presets.budget
			expect(budget.high.rallyPops >= budget.low.rallyPops).to.equal(true)
			expect(budget.low.rallyPops >= budget.lowPerformance.rallyPops).to.equal(true)
			expect(budget.high.pennants >= budget.low.pennants).to.equal(true)
			expect(budget.lowPerformance.pennants).to.equal(0)
			expect(Presets.rally.displayOrder).to.equal(11)
			expect(Presets.tradeFly.displayOrder).to.equal(21)
			expect(Presets.tradeFly.seconds < 1).to.equal(true)
		end)
	end)
end
