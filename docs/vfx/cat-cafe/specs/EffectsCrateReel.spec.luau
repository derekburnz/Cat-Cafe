--!strict
-- The counter crate under the crate reel (F103, crate-reel.md): it opens at the reel's stop, worked out from the
-- shared CrateReel* numbers, and its lid knocks as hard as the reel runs, the same for every prize. Written by the
-- vfx-animator for QA to move into tests/specs.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function near(a: number, b: number, within: number): boolean
		return math.abs(a - b) < within
	end

	-- the spec's numbers: tile 34, 15 tiles a second, 0.3 s up, 0.8 s down over the last 4 tiles
	local LANDING, TOP, RAMP, SLOW = 34, 15, 0.3, 0.8

	-- how many tiles the reel travels by `upTo`, adding up its pace a small step at a time
	local function travelled(slowFrom: number, upTo: number): number
		local step = 0.0005
		local tiles = 0
		local t = step / 2
		while t < upTo do
			tiles += Logic.crateReelPace(t, RAMP, slowFrom, SLOW) * TOP * step
			t += step
		end
		return tiles
	end

	describe("Effects crate reel counter crate", function()
		it("stops about 2.9 s after CrateResult, slowing from about 2.08 s", function()
			local stop: number, slowFrom: number =
				Logic.crateReelStop(LANDING, TOP, RAMP, SLOW, Presets.marketCrate.reelSlowTiles)
			expect(near(stop, 2.8833, 0.001)).to.equal(true)
			expect(near(slowFrom, 2.0833, 0.001)).to.equal(true)
			expect(near(stop - slowFrom, SLOW, 1e-9)).to.equal(true)
		end)

		it(
			"travels the 33 tiles from tile 1 to the landing tile's centre by the stop, and no further",
			function()
				local stop: number, slowFrom: number =
					Logic.crateReelStop(LANDING, TOP, RAMP, SLOW, Presets.marketCrate.reelSlowTiles)
				expect(near(travelled(slowFrom, stop), LANDING - 1, 0.01)).to.equal(true)
				expect(near(travelled(slowFrom, stop + 1), LANDING - 1, 0.01)).to.equal(true)
				-- the last 4 tiles go by in the slow down
				expect(near(travelled(slowFrom, stop) - travelled(slowFrom, slowFrom), 4, 0.01)).to.equal(
					true
				)
			end
		)

		it("eases in, runs flat out, then settles to still at the stop with no jump", function()
			local stop: number, slowFrom: number =
				Logic.crateReelStop(LANDING, TOP, RAMP, SLOW, Presets.marketCrate.reelSlowTiles)
			local function pace(t: number): number
				return Logic.crateReelPace(t, RAMP, slowFrom, SLOW)
			end
			expect(pace(-1)).to.equal(0)
			expect(pace(0)).to.equal(0)
			expect(near(pace(RAMP / 2), 0.5, 1e-9)).to.equal(true)
			expect(pace(1)).to.equal(1)
			expect(near(pace(RAMP - 1e-6), 1, 1e-4)).to.equal(true)
			expect(near(pace(slowFrom + 1e-6), 1, 1e-4)).to.equal(true)
			expect(near(pace(stop - 1e-6), 0, 1e-4)).to.equal(true)
			expect(pace(stop)).to.equal(0)
			expect(pace(stop + 5)).to.equal(0)
			local before = 1
			local t = slowFrom
			while t <= stop do
				local now = pace(t)
				expect(now <= before + 1e-9).to.equal(true)
				expect(now >= 0 and now <= 1).to.equal(true)
				before = now
				t += 0.01
			end
		end)

		it("never runs backwards or waits a negative time on odd numbers", function()
			local stop: number, slowFrom: number = Logic.crateReelStop(2, 15, 0.3, 0.8, 4)
			expect(near(slowFrom, 0.3, 1e-9)).to.equal(true)
			expect(near(stop, 1.1, 1e-9)).to.equal(true)
			local still: number, still2: number = Logic.crateReelStop(34, 0, 0.3, 0.8, 4)
			expect(near(still2, 0.3, 1e-9)).to.equal(true)
			expect(near(still, 1.1, 1e-9)).to.equal(true)
			expect(Logic.crateReelPace(1, 0.3, 2, 0)).to.equal(1)
			expect(Logic.crateReelPace(2.5, 0.3, 2, 0)).to.equal(0)
		end)

		it("keeps the knock small and the fallback after the stop", function()
			local c = Presets.marketCrate
			expect(c.reelRattle > 0 and c.reelRattle <= 6).to.equal(true) -- a knock, not an opening
			expect(c.reelHop > 0 and c.reelHop <= 0.1).to.equal(true)
			expect(c.reelHz > 0).to.equal(true)
			expect(c.reelSafety > 0).to.equal(true)
			-- an ease-out cubic leaves at three times its average pace, so the slow down meets the top speed
			expect(near(3 * c.reelSlowTiles / SLOW, TOP, 1e-9)).to.equal(true)
		end)

		it(
			"times to the shared CrateReel numbers once the UI's reel puts them in Config",
			function()
				local landing = Config.CrateReelLandingTile
				if type(landing) ~= "number" then
					return -- the reel is not in yet: the crate opens at CrateResult as before
				end
				local top: number = Config.CrateReelTopSpeed
				local ramp: number = Config.CrateReelRampSeconds
				local slow: number = Config.CrateReelStopSeconds
				local stop: number =
					Logic.crateReelStop(landing, top, ramp, slow, Presets.marketCrate.reelSlowTiles)
				expect(stop > 2 and stop < 4).to.equal(true)
				expect(near(3 * Presets.marketCrate.reelSlowTiles / slow, top, 1e-6)).to.equal(true)
			end
		)
	end)
end
