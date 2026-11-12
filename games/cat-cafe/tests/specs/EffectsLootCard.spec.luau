--!strict
-- A loot card's pop-in (#3464, Effects/LootCardFx): the card settles on its own size, the rows land in order 0.15 s
-- apart and all of them are in well inside the card's 4 seconds. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local LootCardFx = require(Effects:WaitForChild("LootCardFx")) :: any

	describe("Effects loot card", function()
		it("pops the card in from a little small and settles on exactly its own size", function()
			local p = Presets.lootCard
			expect(LootCardFx.cardScale(0)).to.equal(p.from)
			expect(LootCardFx.cardScale(-1)).to.equal(p.from)
			expect(LootCardFx.cardScale(p.popSeconds)).to.equal(1)
			expect(LootCardFx.cardScale(9)).to.equal(1)
			local most = 0
			for i = 0, 100 do
				most = math.max(most, LootCardFx.cardScale(p.popSeconds * i / 100))
			end
			-- one soft overshoot, never a big one
			expect(most > 1).to.equal(true)
			expect(most < 1.1).to.equal(true)
		end)

		it("lands the rows top to bottom, 0.15 s apart", function()
			local p = Presets.lootCard
			expect(p.gap).to.equal(0.15)
			expect(LootCardFx.rowAt(1)).to.equal(p.firstRow)
			expect(math.abs(LootCardFx.rowAt(3) - LootCardFx.rowAt(2) - p.gap) < 1e-9).to.equal(
				true
			)
			expect(LootCardFx.landed(0, 3)).to.equal(0)
			expect(LootCardFx.landed(p.firstRow + 0.01, 3)).to.equal(1)
			expect(LootCardFx.landed(p.firstRow + p.gap + 0.01, 3)).to.equal(2)
			expect(LootCardFx.landed(99, 3)).to.equal(3)
			expect(LootCardFx.landed(99, 0)).to.equal(0)
			local last = 0
			local t = 0
			while t < 2 do
				local now = LootCardFx.landed(t, 4)
				expect(now >= last).to.equal(true)
				expect(now - last <= 1).to.equal(true)
				last = now
				t += 0.01
			end
			expect(last).to.equal(4)
		end)

		it("has every row in long before the card's 4 seconds are up", function()
			local p = Presets.lootCard
			-- the biggest win today is two rows; six would still be in within a second and a half
			expect(LootCardFx.seconds(2) < 1).to.equal(true)
			expect(LootCardFx.seconds(6) < 1.5).to.equal(true)
			expect(LootCardFx.seconds(0) >= p.popSeconds).to.equal(true)
			expect(p.bounceSeconds).to.equal(Presets.mouseDash.bounce.seconds)
		end)
	end)
end
