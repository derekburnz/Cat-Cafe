--!strict
-- shared/LiveFlags.luau (#2119): the live switches `codes` and `rally` read from CatCafe_Flags. Only an explicit false
-- turns a feature off, so a missing key, a wrong type or an unreadable store never switches the game off.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local Codes = require(Shared.Codes)

	describe("parse", function()
		it("is every switch on when nothing is set", function()
			local flags = LiveFlags.parse({})
			expect(flags.codes).to.equal(true)
			expect(flags.rally).to.equal(true)
			expect(LiveFlags.parse(nil).codes).to.equal(true)
			expect(LiveFlags.parse("off").rally).to.equal(true)
		end)

		it("turns a switch off only for an explicit false", function()
			local flags = LiveFlags.parse({ codes = false })
			expect(flags.codes).to.equal(false)
			expect(flags.rally).to.equal(true)
			flags = LiveFlags.parse({ rally = false, codes = true })
			expect(flags.codes).to.equal(true)
			expect(flags.rally).to.equal(false)
		end)

		it("keeps a switch on for a value of another type", function()
			for _, value in { "false", 0, {}, "off" } do
				local flags = LiveFlags.parse({ codes = value, rally = value })
				expect(flags.codes).to.equal(true)
				expect(flags.rally).to.equal(true)
			end
		end)

		it("ignores keys it doesn't know", function()
			local flags = LiveFlags.parse({ trading = false, everything = false })
			for _, key in LiveFlags.KEYS do
				expect(flags[key]).to.equal(true)
			end
			expect(flags.trading).to.equal(nil)
		end)
	end)

	describe("changed", function()
		it("names the switches that moved, in KEYS order", function()
			local on = LiveFlags.defaults()
			expect(#LiveFlags.changed(on, LiveFlags.parse({}))).to.equal(0)
			local moved = LiveFlags.changed(on, LiveFlags.parse({ rally = false, codes = false }))
			expect(#moved).to.equal(2)
			expect(moved[1]).to.equal("codes")
			expect(moved[2]).to.equal("rally")
		end)
	end)

	it("reads the same store as trading's kill switch, within about a minute", function()
		expect(LiveFlags.STORE).to.equal("CatCafe_Flags")
		expect(LiveFlags.CHECK_SECONDS <= 60).to.equal(true)
		expect(table.find(LiveFlags.KEYS, "codes") ~= nil).to.equal(true)
		expect(table.find(LiveFlags.KEYS, "rally") ~= nil).to.equal(true)
	end)

	it("has a player-facing answer for paused codes", function()
		expect(type(Codes.PAUSED)).to.equal("string")
		expect(Codes.PAUSED ~= Codes.UNKNOWN).to.equal(true)
	end)
end
