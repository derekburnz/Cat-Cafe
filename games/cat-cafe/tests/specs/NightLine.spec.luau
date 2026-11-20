--!strict
-- #5330 UI/Components/NightLine: when the night line shows and its words.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local NightLine = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("NightLine")
	) :: any
	local LiveFlags = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LiveFlags")
	) :: any

	describe("NightLine", function()
		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[NightLine.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, NightLine.FLAG)).to.be.ok()
		end)

		it("shows at night past the tutorial up to Tier 4, with no window open", function()
			expect(NightLine.shows(true, 2, 5, false, false)).to.equal(true)
			expect(NightLine.shows(true, 4, 5, false, false)).to.equal(true)
			expect(NightLine.shows(true, 5, 5, false, false)).to.equal(false)
			expect(NightLine.shows(true, 2, 4, false, false)).to.equal(false)
			expect(NightLine.shows(true, 2, 5, true, false)).to.equal(false)
			expect(NightLine.shows(true, 2, 5, false, true)).to.equal(false)
			expect(NightLine.shows(false, 2, 5, false, false)).to.equal(false)
		end)

		it("drops the ring and arrow on Upgrades with nightLineNoArrow on (#5459)", function()
			expect(NightLine.NO_ARROW_FLAG).to.equal("nightLineNoArrow")
			expect(NightLine.arrow(true, false)).to.equal(true)
			expect(NightLine.arrow(true, true)).to.equal(false)
			expect(NightLine.arrow(false, false)).to.equal(false)
		end)

		it("counts down in minutes and seconds", function()
			expect(NightLine.text(42)).to.equal(
				"Areas open at sunrise in 0:42. Upgrade your cafe while you wait"
			)
			expect(NightLine.text(61.2)).to.equal(
				"Areas open at sunrise in 1:02. Upgrade your cafe while you wait"
			)
			expect(NightLine.text(-3)).to.equal(
				"Areas open at sunrise in 0:00. Upgrade your cafe while you wait"
			)
		end)
	end)
end
