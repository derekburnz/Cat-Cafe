--!strict
-- The Tackle (F74, data-model 10c and 13 v0.11): the lunge's dust follows a lunge and not a walk or a Catch Rush,
-- the miss's skid ends once the slide stops, the hit's stars last as long as the tackled player is down, the
-- fallback seconds are the design's and the new bursts fit the budgets. Written by the vfx-animator for QA to move
-- into tests/specs next to EffectsChase.spec.luau.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function fits(count: number, budget: any): boolean
		return math.clamp(math.floor(count * budget.burstScale + 0.5), 1, budget.maxBurst) <= 12
	end

	-- A Config number once the engineer adds it, else the design's.
	local function tuning(name: string, fallback: number): number
		local value = Config[name]
		return if type(value) == "number" and value > 0 then value else fallback
	end

	describe("Effects tackle", function()
		it("keeps to the design's seconds until Config has them", function()
			local t = Presets.tackle
			expect(t.lungeSeconds).to.equal(0.35)
			expect(t.graceSeconds).to.equal(0.25)
			expect(t.downSeconds).to.equal(0.8)
			for _, name in { "TackleLungeSeconds", "TackleHitGraceSeconds", "TackledDownSeconds" } do
				local value = Config[name]
				expect(value == nil or (type(value) == "number" and value > 0)).to.equal(true)
			end
		end)

		it("kicks dust for a lunge but not for a walk, a carry or a Catch Rush", function()
			local t = Presets.tackle
			local lungeSpeed = tuning("TackleLungeStuds", 12) / tuning("TackleLungeSeconds", 0.35)
			expect(t.lungeSpeed < lungeSpeed).to.equal(true)
			for _, walk in
				{
					tuning("NormalWalkSpeed", 20),
					tuning("CarryWalkSpeed", 16),
					tuning("CatchRushWalkSpeed", 24),
				}
			do
				expect(t.lungeSpeed > walk).to.equal(true)
			end
		end)

		it(
			"follows a miss's slide only while it still slides, and not past the time down",
			function()
				local t = Presets.tackle
				expect(t.skidSpeed > 0 and t.skidSpeed < t.lungeSpeed).to.equal(true)
				expect(t.skidSeconds <= tuning("TackleMissRecoverSeconds", 1.2)).to.equal(true)
				expect(t.every > 0 and t.every <= 0.1).to.equal(true)
				-- the lunge's dust never outlasts its hit window
				expect(t.streakSeconds <= t.lungeSeconds + t.graceSeconds).to.equal(true)
			end
		)

		it("circles a tackled player's head while they are down and getting up", function()
			local t = Presets.tackle
			local down = tuning("TackledDownSeconds", t.downSeconds)
			local stars = down + t.starsAfter
			expect(stars > down + 0.3).to.equal(true) -- full stars for the whole fall, fading as they get up
			expect(stars <= down + 1).to.equal(true)
			expect(Presets.shove.starSeconds).to.equal(nil) -- one source for the time
		end)

		it("fits every tackle burst in the budgets", function()
			local t = Presets.tackle
			expect(Presets.emitters.kick ~= nil and Presets.emitters.dust ~= nil).to.equal(true)
			for _, budget in Presets.budget do
				for _, count in { t.kick, t.skidKick, t.skidDust } do
					expect(fits(count, budget)).to.equal(true)
				end
			end
		end)
	end)
end
