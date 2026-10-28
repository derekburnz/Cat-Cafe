--!strict
-- The red "!" over a stuck cat only in view (Derek 2026-10-28 12:13) with the cat's rarity gem over it (12:14), and
-- Common strays wearing a gem too (12:15). Written by the vfx-animator (VFX PR #543); QA moved it into tests/specs
-- and added the edges.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects stuck mark in view", function()
		it("stays a moment after the cat was last seen, then hides", function()
			local m = Presets.stuckMark
			expect(Logic.stillInView(nil, 10, m.lostAfter)).to.equal(false) -- never seen
			expect(Logic.stillInView(10, 10, m.lostAfter)).to.equal(true)
			expect(Logic.stillInView(10, 10 + m.lostAfter, m.lostAfter)).to.equal(true)
			expect(Logic.stillInView(10, 10 + m.lostAfter + 0.01, m.lostAfter)).to.equal(false)
		end)

		it(
			"outlasts one check, looks past a few see-through parts and stays fairly close",
			function()
				local m = Presets.stuckMark
				expect(m.lostAfter > m.checkEvery).to.equal(true) -- one missed check never pops it
				expect(m.lostAfter <= 1).to.equal(true)
				expect(m.seeThrough >= 1 and m.seeThrough <= 5).to.equal(true)
				expect(m.maxDistance > m.hideWithin + m.showAfter and m.maxDistance <= 120).to.equal(
					true
				)
			end
		)

		it("holds the cat's gem just over the red mark", function()
			local m = Presets.stuckMark
			expect(m.gem > 0 and m.gem <= m.size).to.equal(true)
			expect(m.gemGap > 0 and m.gemGap < m.gem).to.equal(true)
			expect(m.gem).to.equal(Presets.rarityMark.size)
		end)

		it("gives Common strays a gem in the Common colour", function()
			expect(Presets.rarityMark.shows.Common).to.equal(true)
			expect(Presets.rarity.Common ~= nil).to.equal(true)
			expect(Presets.rarityMark.glints.Common == true).to.equal(false)
		end)

		it("keeps Rare and better ahead of Commons for the gem slots", function()
			local rares = { { key = "epic", distance = 50 }, { key = "rare", distance = 70 } }
			local commons = {}
			for i = 1, 14 do
				table.insert(commons, { key = "common" .. i, distance = i * 3 })
			end
			local keys = Logic.nearestFirst(rares, commons, 80, 12)
			expect(#keys).to.equal(12)
			expect(keys[1]).to.equal("epic")
			expect(keys[2]).to.equal("rare")
			expect(keys[3]).to.equal("common1")
			expect(keys[12]).to.equal("common10")
			-- out of range is still out, and with no Rares the Commons get every slot
			expect(#Logic.nearestFirst({ { key = "far", distance = 81 } }, {}, 80, 12)).to.equal(0)
			expect(#Logic.nearestFirst({}, commons, 80, 12)).to.equal(12)
			expect(#Logic.nearestFirst(rares, commons, 80, 1)).to.equal(1)
		end)
	end)

	describe("Effects stuck mark in view edges (QA)", function()
		it("matches the effects list: in view to 100 studs, the 6 nearest, gone half a second after", function()
			local m = Presets.stuckMark
			expect(m.maxDistance).to.equal(100)
			expect(m.most).to.equal(6)
			expect(m.lostAfter).to.equal(0.5)
			expect(m.seeThrough).to.equal(3)
			expect(m.gem).to.equal(0.8)
			expect(m.gemGap).to.equal(0.15)
			expect(m.hideWithin).to.equal(10)
			expect(m.hideWithin + m.showAfter).to.equal(11)
			expect(m.size).to.equal(1.4)
			expect(m.pixels).to.equal(18)
			expect(m.checkEvery).to.equal(0.25)
		end)

		it("counts a cat seen this instant as in view, even with no grace", function()
			expect(Logic.stillInView(5, 5, 0)).to.equal(true)
			expect(Logic.stillInView(5, 5.01, 0)).to.equal(false)
			expect(Logic.stillInView(nil, 0, 1)).to.equal(false)
		end)

		it("never lets a Rare out of range or a broken distance take a Common's slot", function()
			local commons = {}
			for i = 1, 20 do
				table.insert(commons, { key = "common" .. i, distance = 81 - i * 4 })
			end
			local rares = {
				{ key = "far", distance = 81 },
				{ key = "broken", distance = 0 / 0 },
				{ key = "lost", distance = math.huge },
				{ key = "epic", distance = 79 },
			}
			local keys = Logic.nearestFirst(rares, commons, 80, 12)
			expect(#keys).to.equal(12)
			expect(keys[1]).to.equal("epic") -- the only Rare in range, ahead of every nearer Common
			local seen: { [string]: boolean } = {}
			for i, key in keys do
				expect(seen[key] == nil).to.equal(true)
				seen[key] = true
				if i > 1 then
					expect(string.sub(key, 1, 6)).to.equal("common")
				end
			end
			-- the Commons that fill in are the nearest ones, nearest first
			expect(keys[2]).to.equal("common20")
			expect(keys[12]).to.equal("common10")
		end)

		it("gives every slot to the nearest Rares when there are more of them than slots", function()
			local rares = {}
			for i = 1, 15 do
				table.insert(rares, { key = "rare" .. i, distance = 100 - i * 5 })
			end
			local keys = Logic.nearestFirst(rares, { { key = "common", distance = 1 } }, 80, 12)
			expect(#keys).to.equal(12)
			expect(keys[1]).to.equal("rare15")
			expect(keys[12]).to.equal("rare4")
			for _, key in keys do
				expect(key ~= "common").to.equal(true)
			end
			expect(#Logic.nearestFirst(rares, {}, 80, 0)).to.equal(0)
		end)
	end)
end
