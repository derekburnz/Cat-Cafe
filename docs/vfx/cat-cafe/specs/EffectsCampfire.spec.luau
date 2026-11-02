--!strict
-- The campfires' moving flames (Derek 2026-10-30: "The fire from the camp fire isnt moving"): each tongue of
-- Model-Agent's flame stretches, leans and flickers within bounds, the discs group into their tongues, and the
-- budget keeps it small. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects campfire flame", function()
		it("stretches, leans and flickers within its bounds and keeps moving", function()
			local c = Presets.campfire
			local lean = math.rad(c.lean)
			local seen: { number } = {}
			for i = 0, 300 do
				local stretch, leanX, leanZ, flicker = Logic.flame(i / 60, 1.3, c)
				expect(stretch >= 1 - c.stretch - 1e-9 and stretch <= 1 + c.stretch + 1e-9).to.equal(
					true
				)
				expect(math.abs(leanX) <= lean + 1e-9 and math.abs(leanZ) <= lean + 1e-9).to.equal(
					true
				)
				expect(flicker >= 0 and flicker <= 1).to.equal(true)
				table.insert(seen, stretch)
			end
			table.sort(seen)
			expect(seen[#seen] - seen[1] > c.stretch).to.equal(true) -- it really moves
			local a = Logic.flame(0.5, 0, c)
			local b = Logic.flame(0.5, 2.1, c)
			expect(close(a, b)).to.equal(false) -- tongues out of step
		end)

		it("groups the flame's discs into its three tongues, lowest first", function()
			-- the Woods campfire's discs as Model-Agent's set places them (CatCafe_Woods_SetV32_065_Campfire_Glow)
			local points = {
				Vector3.new(80, 1.6333, -100),
				Vector3.new(80, 0.5667, -100),
				Vector3.new(80, 1.1, -100),
				Vector3.new(79.75, 0.4933, -99.9),
				Vector3.new(79.75, 0.86, -99.9),
				Vector3.new(79.75, 1.2267, -99.9),
				Vector3.new(80.3, 0.4867, -100.2),
				Vector3.new(80.3, 0.82, -100.2),
				Vector3.new(80.3, 1.1533, -100.2),
			}
			local tongues = Logic.flameTongues(points, Presets.campfire.gap)
			expect(#tongues).to.equal(3)
			for _, list in tongues do
				expect(#list).to.equal(3)
				expect(points[list[1]].Y < points[list[2]].Y).to.equal(true)
				expect(points[list[2]].Y < points[list[3]].Y).to.equal(true)
			end
			expect(tongues[1][1]).to.equal(2)
		end)

		it("finds the upright axis of a disc turned to stand up", function()
			-- a Cylinder stood up: CFrame.Angles(0, 0, pi / 2) turns its X axis to point up
			expect(Logic.upAxis(1, 0, 0)).to.equal(1)
			expect(Logic.upAxis(0, 1, 0)).to.equal(2)
			expect(Logic.upAxis(0, 0, -1)).to.equal(3)
			expect(Logic.upAxis(0.2, -0.95, 0.1)).to.equal(2)
		end)

		it("stretches a disc upward, thins it and bends the top more than the bottom", function()
			local offset = Vector3.new(0, 1, 0)
			local same, ax0, az0 = Logic.flameLift(offset, 2, 1, 0, 0)
			expect((same - offset).Magnitude < 1e-6 and ax0 == 0 and az0 == 0).to.equal(true)
			local tall = Logic.flameLift(offset, 2, 1.2, 0, 0)
			expect(close(tall.Y, 1.2)).to.equal(true)
			local scale = Logic.flameScale(1, 1.2)
			expect(close(scale.X, 1.2)).to.equal(true)
			expect(close(scale.Y, 1 / math.sqrt(1.2)) and close(scale.Z, scale.Y)).to.equal(true)
			local low, _, lowTurn = Logic.flameLift(Vector3.new(0, 0.5, 0), 2, 1, 0, 0.1)
			local high, _, highTurn = Logic.flameLift(Vector3.new(0, 1.5, 0), 2, 1, 0, 0.1)
			expect(math.abs(high.X) > math.abs(low.X)).to.equal(true)
			expect(close(highTurn, 0.075) and close(lowTurn, 0.025)).to.equal(true)
			expect(high.X < 0).to.equal(true) -- turning about Z tips the top toward -X
			local leaned = Logic.flameLift(Vector3.new(0, 1.5, 0), 2, 1, 0.1, 0)
			expect(leaned.Z > 0).to.equal(true) -- turning about X tips it toward +Z
			expect(close(leaned.Magnitude, 1.5)).to.equal(true) -- a turn, not a stretch
		end)

		it("stays in budget", function()
			local b = Presets.budget
			expect(b.lowPerformance.campfires <= b.low.campfires).to.equal(true)
			expect(b.low.campfires <= b.high.campfires).to.equal(true)
			expect(b.lowPerformance.campfires >= 1).to.equal(true)
			expect(Presets.emitters.ember ~= nil).to.equal(true)
			expect(Presets.emitters.ember.rate <= 4).to.equal(true)
			expect(Presets.campfire.pop <= 6).to.equal(true)
			expect(Presets.campfire.still > 0 and Presets.campfire.still < 1).to.equal(true)
		end)
	end)
end
