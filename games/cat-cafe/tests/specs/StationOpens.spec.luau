--!strict
-- #2910: shared/StationOpens, the prompt vs ring count's lists and its check of a client's StationOpened.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeedbackStand = require(ReplicatedStorage.Shared.FeedbackStand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StationOpens = require(ReplicatedStorage.Shared.StationOpens)

return function()
	describe("StationOpens", function()
		it("takes a known window and way only", function()
			expect(StationOpens.valid("Cannon", "ring")).to.equal(true)
			expect(StationOpens.valid("Bait", "prompt")).to.equal(true)
			expect(StationOpens.valid("Cannon", "teleport")).to.equal(false)
			expect(StationOpens.valid("Bank", "ring")).to.equal(false)
			expect(StationOpens.valid(7, "ring")).to.equal(false)
			expect(StationOpens.valid("Cannon", nil)).to.equal(false)
		end)

		it("maps every station prompt to a known window, and nothing else", function()
			for name, window in StationOpens.PROMPTS do
				expect(StationOpens.windowOfPrompt(name)).to.equal(window)
				expect(table.find(StationOpens.WINDOWS, window)).to.be.ok()
			end
			expect(StationOpens.windowOfPrompt("CodesPrompt")).to.equal(nil)
		end)

		it("counts the feedback stand's Feedback window, by ring and by prompt (#3066)", function()
			expect(StationOpens.valid(FeedbackStand.WINDOW, "ring")).to.equal(true)
			expect(StationOpens.valid(FeedbackStand.WINDOW, "prompt")).to.equal(true)
			expect(StationOpens.windowOfPrompt(FeedbackStand.PROMPT)).to.equal(FeedbackStand.WINDOW)
		end)

		it("counts the camp stations' and the Index Boards' ring opens (#3113)", function()
			for _, window in { "YardSale", "OasisSpa", "RelicMuseum", "Collection" } do
				expect(StationOpens.valid(window, "ring")).to.equal(true)
			end
		end)

		it("has its remote in the list", function()
			expect(table.find(Remotes.ClientToServer, "StationOpened")).to.be.ok()
		end)
	end)
end
