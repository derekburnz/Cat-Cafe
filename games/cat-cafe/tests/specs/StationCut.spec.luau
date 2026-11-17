--!strict
-- #5112 shared/StationCut: which rank ups cut to the station they unlock, and their tipsSeen keys.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local StationCut = require(Shared:WaitForChild("StationCut")) :: any
	local Tips = require(Shared:WaitForChild("Tips")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("StationCut", function()
		it("cuts only for its tiers, once, and only while the switch is on", function()
			expect(StationCut.due(8, {}, true)).to.equal("FusionObservatory")
			expect(StationCut.due(9, nil, true)).to.equal("TicketBooth")
			expect(StationCut.due(10, {}, false)).never.to.be.ok()
			expect(StationCut.due(2, {}, true)).never.to.be.ok()
			expect(StationCut.due(7, {}, true)).never.to.be.ok()
			expect(StationCut.due("8", {}, true)).never.to.be.ok()
			expect(StationCut.due(8, { [StationCut.key(8)] = true }, true)).never.to.be.ok()
		end)

		it("has keys the save keeps and the server takes", function()
			expect(StationCut.key(3)).to.equal("station_cut_3")
			expect(StationCut.isKey("station_cut_3")).to.equal(true)
			expect(StationCut.isKey("station_cut_2")).to.equal(false)
			expect(StationCut.isKey("station_cut_08")).to.equal(false)
			expect(StationCut.isKey("station_cut_")).to.equal(false)
			expect(Tips.seenId("station_cut_10")).to.equal(true)
			local seen = Tips.sanitizeSeen({ station_cut_4 = true, station_cut_5 = true }, false)
			expect(seen.station_cut_4).to.equal(true)
			expect(seen.station_cut_5).never.to.be.ok()
		end)

		it("matches the Effects cut's stations and starts off", function()
			for tier, tag in StationCut.TAGS do
				expect(Presets.stationCut.stations[tier].tag).to.equal(tag)
			end
			for tier in Presets.stationCut.stations do
				expect(StationCut.TAGS[tier]).to.be.ok()
			end
			expect(LiveFlags.OFF_BY_DEFAULT[StationCut.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, StationCut.FLAG) ~= nil).to.equal(true)
		end)
	end)
end
