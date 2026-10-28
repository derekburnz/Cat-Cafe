--!strict
-- DayLight.luau: the sky follows the clock through the day and night (Derek 2026-10-27 22:37), never jumps at a
-- phase change, the sun only runs forward, the day is less bright than the old preset and the night is #239's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local DayLight = require(Shared.DayLight)

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	local function sameColor(a: Color3, b: Color3): boolean
		return near(a.R, b.R) and near(a.G, b.G) and near(a.B, b.B)
	end

	-- every field but ClockTime, which may differ by whole days
	local function sameLook(a: DayLight.Look, b: DayLight.Look): boolean
		return near(a.Brightness, b.Brightness)
			and sameColor(a.OutdoorAmbient, b.OutdoorAmbient)
			and sameColor(a.Ambient, b.Ambient)
			and near(a.ExposureCompensation, b.ExposureCompensation)
			and sameColor(a.ColorShift_Top, b.ColorShift_Top)
			and near(a.Density, b.Density)
			and sameColor(a.Color, b.Color)
			and sameColor(a.Decay, b.Decay)
			and near(a.Glare, b.Glare)
			and near(a.Haze, b.Haze)
	end

	local function sameHour(a: number, b: number): boolean
		local gap = (a - b) % 24
		return gap < 1e-6 or gap > 24 - 1e-6
	end

	describe("progress", function()
		it("runs from 0 at the start of a phase to 1 at its end", function()
			local day = Config.DayLengthSeconds
			expect(DayLight.progress("day", 1000 + day, 1000)).to.equal(0)
			expect(near(DayLight.progress("day", 1000 + day, 1000 + day / 2), 0.5)).to.equal(true)
			expect(DayLight.progress("day", 1000 + day, 1000 + day)).to.equal(1)
			local night = Config.NightLengthSeconds
			expect(near(DayLight.progress("night", 500 + night, 500 + night / 4), 0.25)).to.equal(true)
		end)

		it("holds at the ends when the clock reads outside the phase", function()
			expect(DayLight.progress("day", 2000, 0)).to.equal(0) -- a first day longer than a day
			expect(DayLight.progress("night", 100, 400)).to.equal(1)
		end)
	end)

	describe("the curve", function()
		it("ends each phase on the look the next one starts with", function()
			local sunset, dusk = DayLight.at("day", 1), DayLight.at("night", 0)
			expect(sameLook(sunset, dusk)).to.equal(true)
			expect(sameHour(sunset.ClockTime, dusk.ClockTime)).to.equal(true)
			local dawn, sunrise = DayLight.at("night", 1), DayLight.at("day", 0)
			expect(sameLook(dawn, sunrise)).to.equal(true)
			expect(sameHour(dawn.ClockTime, sunrise.ClockTime)).to.equal(true)
		end)

		it("moves the sun only forward and in small steps", function()
			for _, phase in { "day", "night" } do
				local last = DayLight.at(phase, 0).ClockTime
				for i = 1, 200 do
					local now = DayLight.at(phase, i / 200).ClockTime
					expect(now >= last).to.equal(true)
					expect(now - last < 0.5).to.equal(true)
					last = now
				end
			end
		end)

		it("changes nothing by more than a little between two close moments", function()
			for _, phase in { "day", "night" } do
				local last = DayLight.at(phase, 0)
				for i = 1, 400 do
					local now = DayLight.at(phase, i / 400)
					expect(math.abs(now.Brightness - last.Brightness) < 0.05).to.equal(true)
					expect(math.abs(now.Haze - last.Haze) < 0.2).to.equal(true)
					last = now
				end
			end
		end)

		it("keeps the day below the old preset's Brightness 2 and exposure 0", function()
			for i = 0, 100 do
				local look = DayLight.at("day", i / 100)
				expect(look.Brightness < 2).to.equal(true)
				expect(look.ExposureCompensation <= 0).to.equal(true)
			end
		end)

		it("keeps the day's haze light and none at midday, so no grey veil from the high camera (Derek 00:45)", function()
			for i = 0, 100 do
				local look = DayLight.at("day", i / 100)
				expect(look.Haze <= 0.6).to.equal(true)
				expect(look.Density <= 0.3).to.equal(true)
			end
			expect(DayLight.at("day", 0.45).Haze).to.equal(0)
		end)

		it("is brightest around midday and dimmer at sunrise and sunset", function()
			local midday = DayLight.at("day", 0.45).Brightness
			expect(DayLight.at("day", 0).Brightness < midday).to.equal(true)
			expect(DayLight.at("day", 0.85).Brightness < midday).to.equal(true)
			expect(DayLight.at("day", 1).Brightness < DayLight.at("day", 0.85).Brightness).to.equal(true)
		end)

		it("holds the #239 night look through the middle of the night", function()
			for _, p in { 0.2, 0.5, 0.85 } do
				local look = DayLight.at("night", p)
				expect(sameLook(look, DayLight.NIGHT)).to.equal(true)
				expect(near(look.Brightness, 0.6)).to.equal(true)
				expect(near(look.ExposureCompensation, 0)).to.equal(true)
				expect(sameColor(look.OutdoorAmbient, Color3.fromRGB(45, 55, 85))).to.equal(true)
				expect(sameColor(look.Ambient, Color3.fromRGB(30, 35, 55))).to.equal(true)
				expect(sameColor(look.ColorShift_Top, Color3.fromRGB(150, 170, 220))).to.equal(true)
				expect(near(look.Density, 0.4)).to.equal(true)
				expect(sameColor(look.Color, Color3.fromRGB(110, 120, 160))).to.equal(true)
			end
		end)

		it("puts the sun up by day and down by night", function()
			for i = 0, 20 do
				local hour = DayLight.at("day", i / 20).ClockTime % 24
				expect(hour >= 6 and hour <= 18.5).to.equal(true)
				local night = DayLight.at("night", 0.2 + 0.65 * i / 20).ClockTime % 24
				expect(night < 6 or night > 18.5).to.equal(true)
			end
		end)

		it("treats any phase but night as day", function()
			expect(sameLook(DayLight.at("dawn", 0.45), DayLight.at("day", 0.45))).to.equal(true)
		end)
	end)

	describe("blend", function()
		it("runs from the first look to the second", function()
			local a, b = DayLight.at("day", 0.45), DayLight.NIGHT
			expect(sameLook(DayLight.blend(a, b, 0), a)).to.equal(true)
			expect(sameLook(DayLight.blend(a, b, 1), b)).to.equal(true)
			local half = DayLight.blend(a, b, 0.5)
			expect(near(half.Brightness, (a.Brightness + b.Brightness) / 2)).to.equal(true)
		end)

		it("moves the sun forward past midnight", function()
			local from = DayLight.at("day", 1) -- 18.3
			local to = DayLight.at("day", 0) -- 6.4 the next morning
			local half = DayLight.blend(from, to, 0.5).ClockTime
			expect(near(half, (18.3 + (24 - 18.3 + 6.4) / 2) % 24)).to.equal(true)
			local done = DayLight.blend(from, to, 1).ClockTime
			expect(sameHour(done, 6.4)).to.equal(true)
		end)

		it("keeps a small step back small instead of a lap of the sun", function()
			local from = DayLight.at("day", 0.5)
			local to = DayLight.at("day", 0.49)
			local half = DayLight.blend(from, to, 0.5).ClockTime
			expect(half < from.ClockTime and half > to.ClockTime).to.equal(true)
		end)
	end)
end
