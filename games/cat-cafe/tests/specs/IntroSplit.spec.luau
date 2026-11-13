--!strict
-- IntroSplit.luau (#3666): the intro scene for half of new players, by account number, kept in the save.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local IntroSplit = require(Shared.IntroSplit)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("IntroSplit", function()
		it("is a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, IntroSplit.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[IntroSplit.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[IntroSplit.FLAG]).to.equal(false)
		end)

		it("splits accounts in two by their number, the same every time", function()
			expect(IntroSplit.group(2)).to.equal(IntroSplit.ON)
			expect(IntroSplit.group(3)).to.equal(IntroSplit.OFF)
			local on = 0
			for id = 1000, 1999 do
				if IntroSplit.group(id) == IntroSplit.ON then
					on += 1
				end
				expect(IntroSplit.group(id)).to.equal(IntroSplit.group(id))
			end
			expect(on).to.equal(500)
		end)

		it("takes in only a new save, once, while the switch is on", function()
			expect(IntroSplit.joins(true, 1, false, nil)).to.equal(true)
			expect(IntroSplit.joins(true, 0, false, nil)).to.equal(true)
			expect(IntroSplit.joins(false, 1, false, nil)).to.equal(false) -- the switch off
			expect(IntroSplit.joins(true, 2, false, nil)).to.equal(false) -- a returning player
			expect(IntroSplit.joins(true, 1, true, nil)).to.equal(false) -- the intro already seen
			expect(IntroSplit.joins(true, 1, false, IntroSplit.OFF)).to.equal(false) -- already in
		end)

		it("plays the scene for the scene half alone, and only while the switch is on", function()
			expect(IntroSplit.plays(IntroSplit.ON, true, false)).to.equal(true)
			expect(IntroSplit.plays(IntroSplit.OFF, true, false)).to.equal(false)
			expect(IntroSplit.plays(nil, true, false)).to.equal(false)
			expect(IntroSplit.plays(IntroSplit.ON, false, false)).to.equal(false)
			-- Config.IntroAutoPlay on plays it for everyone, as before
			expect(IntroSplit.plays(IntroSplit.OFF, true, true)).to.equal(true)
			expect(IntroSplit.plays(nil, false, true)).to.equal(true)
		end)

		it(
			"puts the group in a step's third field and leaves a save outside the test alone",
			function()
				local none = { "a" }
				expect(IntroSplit.fields(nil, none)).to.equal(none)
				local fields = IntroSplit.fields(IntroSplit.ON, {})
				expect(#fields).to.equal(3)
				expect(fields[1]).to.equal("-")
				expect(fields[2]).to.equal("-")
				expect(fields[3]).to.equal("intro_on")
				local kept = IntroSplit.fields(IntroSplit.OFF, { "x", "y", "z" })
				expect(kept[1]).to.equal("x")
				expect(kept[2]).to.equal("y")
				expect(kept[3]).to.equal("intro_off")
			end
		)

		it("keeps a valid group through a save and load and drops anything else", function()
			expect(IntroSplit.valid("intro_on")).to.equal("intro_on")
			expect(IntroSplit.valid("intro_off")).to.equal("intro_off")
			expect(IntroSplit.valid("other")).to.equal(nil)
			expect(IntroSplit.valid(1)).to.equal(nil)
			local profile: any = ProfileSchema.template(1700000000)
			expect(profile.telemetry.introGroup).to.equal(nil)
			profile.telemetry.introGroup = IntroSplit.ON
			expect(ProfileSchema.migrate(profile, 1700000000).telemetry.introGroup).to.equal(
				IntroSplit.ON
			)
			profile.telemetry.introGroup = "half"
			expect(ProfileSchema.migrate(profile, 1700000000).telemetry.introGroup).to.equal(nil)
		end)

		it(
			"#4001: an Experiment's introMode picks full, short or none, and full and short play themselves",
			function()
				expect(IntroSplit.fromMode("full")).to.equal(IntroSplit.FULL)
				expect(IntroSplit.fromMode("short")).to.equal(IntroSplit.SHORT)
				expect(IntroSplit.valid(IntroSplit.FULL)).to.equal(IntroSplit.FULL)
				expect(IntroSplit.plays(IntroSplit.FULL, false, false)).to.equal(true)
				expect(IntroSplit.fromMode("none")).to.equal(IntroSplit.OFF)
				expect(IntroSplit.fromMode("long")).to.equal(nil)
				expect(IntroSplit.fromMode(nil)).to.equal(nil)
				expect(IntroSplit.valid(IntroSplit.SHORT)).to.equal(IntroSplit.SHORT)
				-- the short arm plays whatever the switch says; none never does
				expect(IntroSplit.plays(IntroSplit.SHORT, false, false)).to.equal(true)
				expect(IntroSplit.plays(IntroSplit.OFF, true, false)).to.equal(false)
				expect(IntroSplit.short(IntroSplit.SHORT)).to.equal(true)
				expect(IntroSplit.short(IntroSplit.ON)).to.equal(false)
				expect(IntroSplit.short(nil)).to.equal(false)
			end
		)
	end)
end
