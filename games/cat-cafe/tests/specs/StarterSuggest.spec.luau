--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterSuggest = require(ReplicatedStorage.Shared.StarterSuggest)

local function moment(over: { [string]: any }?): StarterSuggest.Moment
	local m: any = {
		on = true,
		done = false,
		played = 700,
		rankedAt = 600,
		firstDay = 20000,
		owned = false,
		quietUntil = nil,
		now = 20000 * 86400 + 1000,
		tutorialDone = true,
		clear = true,
		priced = true,
	}
	for key, value in over or {} do
		m[key] = value
	end
	return m :: StarterSuggest.Moment
end

-- a moment with no rank up this session (a nil in `over` would be skipped)
local function unranked(over: { [string]: any }?): StarterSuggest.Moment
	local m: any = moment(over)
	m.rankedAt = nil
	return m :: StarterSuggest.Moment
end

return function()
	describe("StarterSuggest (#4174)", function()
		it("keeps its picture", function()
			expect(StarterSuggest.PICTURE).to.equal("rbxassetid://125781962090599")
		end)

		it("comes 45 s after a rank up to Tier 2 or higher (#4438)", function()
			expect(StarterSuggest.due(moment({ rankedAt = 600, played = 645 }))).to.equal(true)
			expect(StarterSuggest.due(moment({ rankedAt = 600, played = 644 }))).to.equal(false)
		end)

		it("comes 2 minutes into a session on a later day than the first (#4438)", function()
			local later = 20001 * 86400 + 50
			expect(StarterSuggest.due(unranked({ now = later, played = 120 }))).to.equal(true)
			expect(StarterSuggest.due(unranked({ now = later, played = 119 }))).to.equal(false)
		end)

		it(
			"never comes on a first day with no rank up, whatever the time played (#4438)",
			function()
				expect(StarterSuggest.due(unranked({ played = 3600 }))).to.equal(false)
				local noDay: any = unranked({ played = 3600 })
				noDay.firstDay = nil
				expect(StarterSuggest.due(noDay)).to.equal(false)
				expect(StarterSuggest.due(unranked({ firstDay = 0, played = 3600 }))).to.equal(
					false
				)
			end
		)

		it("shows once a clear moment comes after its time", function()
			expect(StarterSuggest.due(moment())).to.equal(true)
			expect(StarterSuggest.due(moment({ played = 620 }))).to.equal(false)
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
			expect(StarterSuggest.due(moment({ quietUntil = 20000 * 86400 + 1200 }))).to.equal(
				false
			)
			expect(StarterSuggest.due(moment({ quietUntil = 20000 * 86400 + 900 }))).to.equal(true)
			expect(StarterSuggest.due(moment({ quietUntil = "x" }))).to.equal(true)
			expect(StarterSuggest.due(moment({ tutorialDone = false }))).to.equal(false)
		end)

		it("says the live price on its one button", function()
			expect(StarterSuggest.buyLabel(99)).to.equal("Buy R$99")
			expect(StarterSuggest.buyLabel(149.7)).to.equal("Buy R$149")
		end)
	end)
end
