--!strict
-- shared/TownGround.luau (#5357): the townGround switch keeps the Town paving and paw paths whole.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	local TownGround = require(ReplicatedStorage.Shared.TownGround)

	describe("TownGround", function()
		it("is behind an off by default switch", function()
			expect(table.find(LiveFlags.KEYS, TownGround.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[TownGround.FLAG]).to.equal(true)
		end)

		it("keeps the tag WorldBuilder writes", function()
			expect(TownGround.TAG).to.equal("TownGround")
		end)

		it("is Persistent on and Default off", function()
			expect(TownGround.mode(true)).to.equal(Enum.ModelStreamingMode.Persistent)
			expect(TownGround.mode(false)).to.equal(Enum.ModelStreamingMode.Default)
		end)

		it("puts the paws in the floor behind an off by default switch (#5471)", function()
			expect(table.find(LiveFlags.KEYS, TownGround.FLOOR_FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[TownGround.FLOOR_FLAG]).to.equal(true)
			expect(TownGround.PATHS_NAME).to.equal("PawPaths")
		end)

		it("maps a point on a floor to its top face canvas (#5471)", function()
			local x, y = TownGround.pixel(0, 0, 14.8, 161, 20)
			expect(x).to.equal(148)
			expect(y).to.equal(1610)
			local x2, y2 = TownGround.pixel(-0.7, -40, 14.8, 161, 20)
			expect(math.abs(x2 - 134) < 1e-6).to.equal(true)
			expect(math.abs(y2 - 810) < 1e-6).to.equal(true)
		end)

		it(
			"reads a print's turn from its look and turns the canvas the other way (#5471)",
			function()
				expect(math.abs(TownGround.turnOf(0, -1)) < 1e-6).to.equal(true) -- looking -Z: no turn
				expect(
					math.abs(TownGround.turnOf(0, 1) - 180) < 1e-6
						or math.abs(TownGround.turnOf(0, 1) + 180) < 1e-6
				).to.equal(true)
				expect(math.abs(TownGround.turnOf(-1, 0) - 90) < 1e-6).to.equal(true) -- a quarter turn: -Z to -X
				expect(TownGround.canvasTurn(90)).to.equal(-90)
			end
		)

		it("keeps every toe inside the print's box", function()
			for _, toe in TownGround.TOES do
				expect(math.abs(toe[1]) + TownGround.TOE / 2 <= TownGround.BOX / 2).to.equal(true)
				expect(math.abs(toe[2]) + TownGround.TOE / 2 <= TownGround.BOX / 2).to.equal(true)
			end
		end)
	end)
end
