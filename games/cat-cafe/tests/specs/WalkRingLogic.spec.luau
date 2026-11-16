--!strict
-- UI/Components/WalkRingLogic.luau: the walk-through's Alleyway ring on the Cat Cannon picker (#4674).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local WalkRingLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("WalkRingLogic")
	) :: any

	local function view(props: { [string]: any }?): { [string]: any }
		local made: { [string]: any } =
			{ bowlFirst = true, tier = 1, secondCatDone = false, cannonId = "town" }
		for key, value in props or {} do
			made[key] = value
		end
		return made
	end

	describe("WalkRingLogic.area", function()
		it("rings the Alleyway at the Town Square cannon while the two catches are owed", function()
			expect(WalkRingLogic.area(view())).to.equal("alley")
		end)
		it("rings nothing in the catch first order", function()
			expect(WalkRingLogic.area(view({ bowlFirst = false }))).to.equal(nil)
		end)
		it("rings nothing once the two catches are in, or when the goal is unknown", function()
			expect(WalkRingLogic.area(view({ secondCatDone = true }))).to.equal(nil)
			local unknown = view()
			unknown.secondCatDone = nil
			expect(WalkRingLogic.area(unknown)).to.equal(nil)
		end)
		it("rings nothing from Tier 2", function()
			expect(WalkRingLogic.area(view({ tier = 2 }))).to.equal(nil)
		end)
		it("leaves the Park ring from Rank Up alone", function()
			expect(WalkRingLogic.area(view({ flyRing = "park" }))).to.equal(nil)
		end)
		it("rings nothing at the Alleyway camp's own cannon", function()
			expect(WalkRingLogic.area(view({ cannonId = "alley" }))).to.equal(nil)
		end)

		it(
			"flies the walk-through's first flight from the Town Square straight to the Alleyway (#4920)",
			function()
				expect(WalkRingLogic.direct(view({}), true)).to.equal("alley")
				expect(WalkRingLogic.direct(view({}), false)).to.equal(nil) -- the switch off: the picker
				expect(WalkRingLogic.direct(view({ cannonId = "alley" }), true)).to.equal(nil)
				expect(WalkRingLogic.direct(view({ tier = 2 }), true)).to.equal(nil)
				expect(WalkRingLogic.direct(view({ flyRing = "park" }), true)).to.equal(nil)
				expect(WalkRingLogic.direct(view({ bowlFirst = false }), true)).to.equal(nil)
				expect(WalkRingLogic.FLAG).to.equal("firstFlightDirect")
			end
		)
	end)
end
