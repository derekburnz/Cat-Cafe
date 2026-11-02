--!strict
-- The camp extras' water (F100, camp-extras.md section 3): the Sewer pipe's drip swelling and falling onto the Lost
-- and Found's lid, and the Woods pond's fish jumping out and swimming home. Written by the vfx-animator for QA to
-- move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function near(a: number, b: number, within: number): boolean
		return math.abs(a - b) < within
	end

	describe("Effects camp water", function()
		it("swells a drip at the mouth, then lets it fall from rest", function()
			local o = Presets.campWater.drip
			local g0: number, f0: number = Logic.dripAt(0, o.swell, o.gravity)
			expect(g0).to.equal(0)
			expect(f0).to.equal(0)
			local before = 0
			local t = 0.01
			while t < o.swell do
				local grown: number, fallen: number = Logic.dripAt(t, o.swell, o.gravity)
				expect(grown >= before).to.equal(true)
				expect(fallen).to.equal(0) -- it hangs until full grown
				before = grown
				t += 0.01
			end
			local full: number, still: number = Logic.dripAt(o.swell, o.swell, o.gravity)
			expect(full).to.equal(1)
			expect(still).to.equal(0)
			-- it falls the lid's stud in the time dripFall gives
			local seconds = Logic.dripFall(1, o.gravity)
			local _, fallen: number = Logic.dripAt(o.swell + seconds, o.swell, o.gravity)
			expect(near(fallen, 1, 1e-6)).to.equal(true)
			expect(Logic.dripFall(0, o.gravity)).to.equal(0)
			expect(Logic.dripFall(-1, o.gravity)).to.equal(0)
			-- slow enough to read, quick enough to look like water
			expect(seconds > 0.2 and seconds < 0.5).to.equal(true)
			expect(o.gap[1] > 0 and o.gap[2] >= o.gap[1]).to.equal(true)
			expect(Presets.emitters.dripSplash ~= nil).to.equal(true)
		end)

		it("arcs the fish out of the water and back in a little way on", function()
			local f = Presets.campWater.fish
			local depth = 0.14 -- Model-Agent's pond: the fish rests 0.14 under FishJump
			local x0: number, y0: number, p0: number = Logic.fishArc(0, f.length, depth, f.peak)
			expect(x0).to.equal(0)
			expect(y0).to.equal(0)
			expect(p0 > 0).to.equal(true) -- nose up as it climbs
			local x1: number, y1: number, p1: number = Logic.fishArc(1, f.length, depth, f.peak)
			expect(near(x1, f.length, 1e-9)).to.equal(true)
			expect(near(y1, 0, 1e-9)).to.equal(true)
			expect(p1 < 0).to.equal(true) -- nose down as it dives
			expect(near(p0, -p1, 1e-9)).to.equal(true)
			local _, top: number, flat: number = Logic.fishArc(0.5, f.length, depth, f.peak)
			expect(near(top, depth + f.peak, 1e-9)).to.equal(true)
			expect(near(flat, 0, 1e-9)).to.equal(true)
			-- it leaves the water where the arc reaches the surface, and comes back in where it falls to it
			local out: number, back: number = Logic.fishSurface(depth, f.peak)
			expect(out > 0 and out < 0.5).to.equal(true)
			expect(near(out + back, 1, 1e-9)).to.equal(true)
			local _, atOut: number = Logic.fishArc(out, f.length, depth, f.peak)
			expect(near(atOut, depth, 1e-9)).to.equal(true)
			local a: number, b: number = Logic.fishSurface(0, f.peak)
			expect(a).to.equal(0)
			expect(b).to.equal(1)
			-- a small jump that lands in the pond (its west stones are 1.25 studs past the fish's head)
			expect(f.length <= 1.1).to.equal(true)
			expect(f.peak <= 1.5).to.equal(true)
			expect(f.headX == 1 or f.headX == -1).to.equal(true)
		end)

		it("swims the fish home under the water, turning round on the way", function()
			local f = Presets.campWater.fish
			local dive = -1.3
			local x0: number, yaw0: number, p0: number = Logic.fishReturn(0, f.length, f.turn, dive)
			expect(near(x0, f.length, 1e-9)).to.equal(true)
			expect(yaw0).to.equal(0)
			expect(near(p0, dive, 1e-9)).to.equal(true) -- it carries on from the dive
			local _, yawMid: number, pMid: number = Logic.fishReturn(0.5, f.length, f.turn, dive)
			expect(near(yawMid, math.pi, 1e-9)).to.equal(true) -- heading home, head first
			expect(near(pMid, 0, 1e-9)).to.equal(true)
			local x1: number, yaw1: number, p1: number = Logic.fishReturn(1, f.length, f.turn, dive)
			expect(near(x1, 0, 1e-9)).to.equal(true)
			expect(near(yaw1, 2 * math.pi, 1e-9)).to.equal(true) -- rests as modelled
			expect(near(p1, 0, 1e-9)).to.equal(true)
			local before = math.huge
			local u = 0
			while u <= 1 do
				local along: number = Logic.fishReturn(u, f.length, f.turn, dive)
				expect(along <= before + 1e-9).to.equal(true)
				before = along
				u += 0.02
			end
		end)

		it("jumps now and then, inside the budget, and never in Low performance", function()
			local f = Presets.campWater.fish
			expect(f.every[1] >= 5 and f.every[2] >= f.every[1]).to.equal(true)
			expect(f.first[1] > 0 and f.first[2] <= f.every[2]).to.equal(true)
			expect(f.seconds + f.back < f.every[1]).to.equal(true) -- home before the next jump
			expect(f.turn > 0 and f.turn <= 0.5).to.equal(true)
			local b = Presets.budget
			expect(b.lowPerformance.campFish).to.equal(0)
			expect(b.low.campFish <= b.high.campFish).to.equal(true)
			expect(b.lowPerformance.campDrips <= b.low.campDrips).to.equal(true)
			expect(b.low.campDrips <= b.high.campDrips).to.equal(true)
		end)
	end)
end
