--!strict
-- UI/Components/TackleLogic.luau: the Tackle button's down states, look and toasts (F74, data-model section 10c).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TackleLogic = require(Components:WaitForChild("TackleLogic")) :: any

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end

	describe("TackleLogic numbers", function()
		it("keeps the design's reach, cooldown and recover times", function()
			expect(TackleLogic.REACH).to.equal(12)
			expect(TackleLogic.COOLDOWN).to.equal(8)
			expect(TackleLogic.LUNGE).to.equal(0.35)
			expect(TackleLogic.HIT_RECOVER).to.equal(0.4)
			expect(TackleLogic.MISS_RECOVER).to.equal(1.2)
			expect(near(TackleLogic.TACKLED, 1.05)).to.equal(true)
		end)
	end)

	describe("TackleLogic.downUntil", function()
		it("is never down without marks", function()
			expect(TackleLogic.downUntil({})).to.equal(-math.huge)
		end)

		it("covers the lunge, the miss slide and a tackle on you", function()
			expect(near(TackleLogic.downUntil({ tackleAt = 100 }), 100.35)).to.equal(true)
			expect(near(TackleLogic.downUntil({ missAt = 100.6 }), 101.8)).to.equal(true)
			expect(near(TackleLogic.downUntil({ shovedAt = 50 }), 51.05)).to.equal(true)
		end)

		it("takes the latest of them", function()
			local marks = { tackleAt = 100, missAt = 100.6, shovedAt = 90 }
			expect(near(TackleLogic.downUntil(marks), 101.8)).to.equal(true)
		end)
	end)

	describe("TackleLogic.look", function()
		it("shows the cooldown first, then down, then ready", function()
			expect(TackleLogic.look(3, true)).to.equal("cooling")
			expect(TackleLogic.look(3, false)).to.equal("cooling")
			expect(TackleLogic.look(0, true)).to.equal("down")
			expect(TackleLogic.look(0, false)).to.equal("ready")
			expect(TackleLogic.look(-1, false)).to.equal("ready")
		end)

		it("drains the wipe from the whole button to nothing", function()
			expect(TackleLogic.share(8)).to.equal(1)
			expect(TackleLogic.share(2)).to.equal(0.25)
			expect(TackleLogic.share(0)).to.equal(0)
			expect(TackleLogic.share(20)).to.equal(1)
		end)
	end)

	describe("TackleLogic.toast", function()
		it("says Missed! on a miss", function()
			local text, kind = TackleLogic.toast(true, "miss", nil)
			expect(text).to.equal("Missed!")
			expect(kind).to.equal("warn")
		end)

		it("names who you tackled on any hit", function()
			for _, outcome in { "shove", "loose", "held" } do
				local text, kind = TackleLogic.toast(true, outcome, "Alex")
				expect(text).to.equal("Tackled Alex!")
				expect(kind).to.equal("good")
			end
			expect(TackleLogic.toast(true, "shove", nil)).to.equal("Tackled!")
			expect(TackleLogic.toast(true, "loose", "")).to.equal("Tackled!")
		end)

		it("says nothing for a refusal or an outcome it does not know", function()
			expect(TackleLogic.toast(false, "refused", "Alex")).never.to.be.ok()
			expect(TackleLogic.toast(true, nil, "Alex")).never.to.be.ok()
			expect(TackleLogic.toast(true, "bump", "Alex")).never.to.be.ok()
		end)
	end)
end
