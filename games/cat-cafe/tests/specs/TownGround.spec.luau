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

		it(
			"maps a point on a floor to its top face canvas, X along the part's Z (#5471)",
			function()
				local c = TownGround.CANVAS
				-- the canvas is the part's Z long and its X high (Sync: 2950 x 640 on a 32 x 147.5 street half)
				local w, h = TownGround.pixel(16, 73.75, 32, 147.5, 20)
				local w2, h2 = TownGround.pixel(-16, -73.75, 32, 147.5, 20)
				expect(math.abs(math.abs(w - w2) - 2950) < 1e-6).to.equal(true)
				expect(math.abs(math.abs(h - h2) - 640) < 1e-6).to.equal(true)
				local x, y = TownGround.pixel(0, 0, 14.8, 161, 20)
				expect(x).to.equal(1610)
				expect(y).to.equal(148)
				local x2, y2 = TownGround.pixel(-0.7, -40, 14.8, 161, 20)
				expect(math.abs(x2 - (1610 + c.xSign * -40 * 20)) < 1e-6).to.equal(true)
				expect(math.abs(y2 - (148 + c.ySign * -0.7 * 20)) < 1e-6).to.equal(true)
			end
		)

		it("turns a print so its toes point the way it looks (#5471)", function()
			for _, way in { { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0.6, -0.8 } } do
				local turn = math.rad(TownGround.facing(way[1], way[2]))
				-- toes drawn toward canvas -Y, turned clockwise by `turn`
				local tu, tv = math.sin(turn), -math.cos(turn)
				-- where the look lands on the canvas, a little way along from the middle
				local u0, v0 = TownGround.pixel(0, 0, 10, 10, 1)
				local u1, v1 = TownGround.pixel(way[1], way[2], 10, 10, 1)
				expect(math.abs(tu - (u1 - u0)) < 1e-6).to.equal(true)
				expect(math.abs(tv - (v1 - v0)) < 1e-6).to.equal(true)
			end
		end)

		it("keeps every toe inside the print's box", function()
			for _, toe in TownGround.TOES do
				expect(math.abs(toe[1]) + TownGround.TOE / 2 <= TownGround.BOX / 2).to.equal(true)
				expect(math.abs(toe[2]) + TownGround.TOE / 2 <= TownGround.BOX / 2).to.equal(true)
			end
		end)
	end)
end
