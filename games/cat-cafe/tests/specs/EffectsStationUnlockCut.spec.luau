--!strict
-- #5112 the station unlock cutscene's timeline and its stations (Design-Agent's station-unlock-cutscene.md). Written by
-- the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Cut = require(Effects:WaitForChild("StationUnlockCut")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects station unlock cutscene", function()
		it("has a station for Tiers 3, 4, 8, 9 and 10 only", function()
			expect(Cut.stationFor(8).tag).to.equal("FusionObservatory")
			expect(Cut.stationFor(9).tag).to.equal("TicketBooth")
			expect(Cut.stationFor(10).tag).to.equal("DragonKeep")
			expect(Cut.stationFor(3).tag).to.equal("ArcadeCabinet")
			expect(Cut.stationFor(4).tag).to.equal("MysticPool")
			expect(Cut.stationFor(2)).never.to.be.ok()
			expect(Cut.stationFor(7)).never.to.be.ok()
			expect(Cut.stationFor("8")).never.to.be.ok()
			for _, station in Presets.stationCut.stations do
				expect(#station.name > 0 and #station.line > 0).to.equal(true)
			end
		end)

		it("fades to the station, shows it, labels it and fades back in about 4.5 s", function()
			local p = Presets.stationCut
			expect(Cut.length(p)).to.be.near(4.4, 0.2)
			local fade, there, _, grow, label = Cut.at(0, p)
			expect(fade).to.equal(0)
			expect(there).to.equal(false)
			expect(grow).never.to.be.ok()
			expect(label).to.equal(0)
			fade, there = Cut.at(p.fade, p)
			expect(fade).to.be.near(1, 1e-6)
			expect(there).to.equal(true)
			fade, there, _, grow = Cut.at(p.appearAt + p.grow / 2, p)
			expect(fade).to.equal(0)
			expect(grow).to.be.near(0.5, 1e-6)
			local _, _, push, _, shown = Cut.at(p.labelAt + p.labelIn, p)
			expect(shown).to.equal(1)
			expect(push > 0 and push < 1).to.equal(true)
			fade, there = Cut.at(p.endAt + p.fade, p)
			expect(fade).to.be.near(1, 1e-6)
			expect(there).to.equal(false)
			fade = Cut.at(Cut.length(p), p)
			expect(fade).to.equal(0)
		end)

		it("keeps the station's appear in the spec's order and phone sizes", function()
			local p = Presets.stationCut
			expect(p.fade * 2 <= p.appearAt).to.equal(true)
			expect(p.appearAt < p.labelAt and p.labelAt < p.endAt).to.equal(true)
			expect(p.fromScale).to.equal(0.85)
			expect(p.skipAfter <= 0.5).to.equal(true)
			expect(p.scaleHz <= 30).to.equal(true)
			expect(p.burst.sparkles > Presets.stationReveal.sparkles).to.equal(true)
		end)

		it("films from the first clear view, else the roomiest (Sync's gate run)", function()
			local views = {
				{ yaw = 35, free = 10 },
				{ yaw = -35, free = 50 },
				{ yaw = 0, free = 60 },
			}
			expect(Cut.bestView(views, 40).yaw).to.equal(-35)
			expect(Cut.bestView(views, 80).yaw).to.equal(0)
			expect(Cut.bestView({}, 40)).never.to.be.ok()
			local p = Presets.stationCut
			expect(p.views[1]).to.equal(p.yaw)
			expect(p.closest < p.nearest).to.equal(true)
			-- the Town Square's tier stations come back shown, not as their lock hid them
			expect(p.stations[3].locked).to.equal(true)
			expect(p.stations[4].locked).to.equal(true)
			expect(p.stations[8].locked).never.to.be.ok()
		end)
	end)
end
