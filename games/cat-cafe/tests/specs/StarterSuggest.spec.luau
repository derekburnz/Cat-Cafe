--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterSuggest = require(ReplicatedStorage.Shared.StarterSuggest)

local function moment(over: { [string]: any }?): StarterSuggest.Moment
	local m: any = {
		on = true,
		done = false,
		played = 700,
		dueAt = 650,
		owned = false,
		quietUntil = nil,
		now = 1000,
		tutorialDone = true,
		clear = true,
		priced = true,
	}
	for key, value in over or {} do
		m[key] = value
	end
	return m :: StarterSuggest.Moment
end

return function()
	describe("StarterSuggest (#4174)", function()
		it("is due between 10 and 15 minutes into the session", function()
			expect(StarterSuggest.dueAt(0)).to.equal(600)
			expect(StarterSuggest.dueAt(0.5)).to.equal(750)
			expect(StarterSuggest.dueAt(0.9999)).to.equal(899)
			expect(StarterSuggest.dueAt(-1)).to.equal(600)
			expect(StarterSuggest.dueAt(2)).to.equal(900)
			expect(StarterSuggest.PICTURE).to.equal("rbxassetid://125781962090599")
		end)

		it("shows once a clear moment comes after its time", function()
			expect(StarterSuggest.due(moment())).to.equal(true)
			expect(StarterSuggest.due(moment({ played = 600 }))).to.equal(false)
			expect(StarterSuggest.due(moment({ clear = false }))).to.equal(false)
		end)

		it("never shows with the switch off, once done, owned or with no word on it", function()
			expect(StarterSuggest.due(moment({ on = false }))).to.equal(false)
			expect(StarterSuggest.due(moment({ done = true }))).to.equal(false)
			expect(StarterSuggest.due(moment({ owned = true }))).to.equal(false)
			local unknown = moment()
			unknown.owned = nil
			expect(StarterSuggest.due(unknown)).to.equal(false)
			expect(StarterSuggest.due(moment({ priced = false }))).to.equal(false)
		end)

		it("waits through the quiet start and the tutorial", function()
			expect(StarterSuggest.due(moment({ quietUntil = 1200 }))).to.equal(false)
			expect(StarterSuggest.due(moment({ quietUntil = 900 }))).to.equal(true)
			expect(StarterSuggest.due(moment({ quietUntil = "x" }))).to.equal(true)
			expect(StarterSuggest.due(moment({ tutorialDone = false }))).to.equal(false)
		end)

		it("says the live price on its one button", function()
			expect(StarterSuggest.buyLabel(99)).to.equal("Buy R$99")
			expect(StarterSuggest.buyLabel(149.7)).to.equal("Buy R$149")
		end)
	end)
end
