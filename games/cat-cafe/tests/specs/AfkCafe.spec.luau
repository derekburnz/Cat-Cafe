--!strict
-- shared/AfkCafe.luau and Economy's rest slot (#3573): resting in your own cafe doubles the cats' cafe pay, in the
-- event's money slot, never above EventMoneyMax.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local AfkCafe = require(Shared.AfkCafe)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)

	local W, D = 60, 40

	describe("AfkCafe.inZone", function()
		local doorstep = Vector3.new(4, 3, -26)

		it("is the cafe's footprint", function()
			expect(AfkCafe.inZone(Vector3.new(0, 3, 0), doorstep, W, D)).to.equal(true)
			expect(AfkCafe.inZone(Vector3.new(30, 3, -20), doorstep, W, D)).to.equal(true)
			expect(AfkCafe.inZone(Vector3.new(31, 3, 21), doorstep, W, D)).to.equal(false)
			expect(AfkCafe.inZone(Vector3.new(0, 31, 0), doorstep, W, D)).to.equal(false)
			expect(AfkCafe.inZone(Vector3.new(0, -5, 0), doorstep, W, D)).to.equal(false)
		end)

		it("and the doorstep, DOORSTEP_STUDS around the home landing", function()
			expect(AfkCafe.DOORSTEP_STUDS).to.equal(12)
			expect(AfkCafe.inZone(doorstep, doorstep, W, D)).to.equal(true)
			expect(AfkCafe.inZone(doorstep + Vector3.new(0, 0, -12), doorstep, W, D)).to.equal(true)
			expect(AfkCafe.inZone(doorstep + Vector3.new(0, 0, -12.5), doorstep, W, D)).to.equal(
				false
			)
			-- no landing known: the footprint alone
			expect(AfkCafe.inZone(doorstep, nil, W, D)).to.equal(false)
		end)
	end)

	describe("AfkCafe.resting", function()
		it("needs idle, the whole wait standing still, the zone and nothing in hand", function()
			local wait = Config.AfkCafeSeconds
			expect(wait).to.equal(120)
			expect(AfkCafe.resting(true, wait, true, false)).to.equal(true)
			expect(AfkCafe.resting(false, wait, true, false)).to.equal(false)
			expect(AfkCafe.resting(true, wait - 1, true, false)).to.equal(false)
			expect(AfkCafe.resting(true, wait, false, false)).to.equal(false)
			expect(AfkCafe.resting(true, wait, true, true)).to.equal(false)
		end)
	end)

	describe("AfkCafe.money", function()
		it("is 2x at rest, the event's when larger, and never above EventMoneyMax", function()
			expect(Config.AfkCafeMoney).to.equal(2)
			expect(AfkCafe.money(1, false)).to.equal(1)
			expect(AfkCafe.money(1, true)).to.equal(2)
			expect(AfkCafe.money(1.5, true)).to.equal(2)
			expect(AfkCafe.money(2, true)).to.equal(2)
			expect(AfkCafe.money(2, false)).to.equal(2)
			expect(AfkCafe.money(2, true) <= Config.EventMoneyMax).to.equal(true)
			expect(AfkCafe.doubled(1)).to.equal(true)
			expect(AfkCafe.doubled(2)).to.equal(false)
		end)

		it("words that promise nothing about staying connected", function()
			-- in a 2x party the once a visit line does not say 2x
			expect(AfkCafe.line(true)).to.equal(AfkCafe.LINE)
			expect(AfkCafe.line(false)).to.equal(AfkCafe.PARTY_LINE)
			expect(string.find(AfkCafe.PARTY_LINE, "2x", 1, true)).never.to.be.ok()
			for _, line in { AfkCafe.LINE, AfkCafe.PARTY_LINE, AfkCafe.welcome("$1.2K") } do
				local lower = string.lower(line)
				expect(string.find(lower, "kick", 1, true)).never.to.be.ok()
				expect(string.find(lower, "disconnect", 1, true)).never.to.be.ok()
			end
			expect(AfkCafe.welcome("$1.2K")).to.equal(
				"Welcome back! Your cats earned $1.2K while you rested 💤"
			)
		end)
	end)

	describe("Economy's rest slot", function()
		local function cafe()
			local profile = ProfileSchema.template(1000)
			profile.lastTick = 1000
			return profile
		end

		it("pays a resting cafe double for the settled window, and counts it", function()
			local plain, rested = cafe(), cafe()
			local rate = Economy.incomePerSecond(plain)
			expect(rate > 0).to.equal(true)
			Economy.setResting(rested, true)
			expect(Economy.isResting(rested)).to.equal(true)
			expect(Economy.moneyFor(plain)).to.equal(1)
			expect(Economy.moneyFor(rested)).to.equal(2)
			local a = Economy.settle(plain, 1100)
			local b = Economy.settle(rested, 1100)
			expect(math.abs(b - 2 * a) < 1e-6).to.equal(true)
			expect(math.abs(Economy.takeRestEarned(rested) - b) < 1e-6).to.equal(true)
			expect(Economy.takeRestEarned(rested)).to.equal(0)
			expect(Economy.takeRestEarned(plain)).to.equal(0)
			-- the rest's share is not the event's
			expect(Economy.takeEventExtra(rested)).to.equal(0)
			Economy.setResting(rested, false)
			expect(Economy.moneyFor(rested)).to.equal(1)
		end)

		it("adds nothing in a 2x party", function()
			local plain, rested = cafe(), cafe()
			Economy.setEventMoney(2)
			Economy.setResting(rested, true)
			expect(Economy.moneyFor(rested)).to.equal(2)
			local a = Economy.settle(plain, 1100)
			local b = Economy.settle(rested, 1100)
			Economy.setEventMoney(1)
			Economy.setResting(rested, false)
			expect(math.abs(a - b) < 1e-6).to.equal(true)
			expect(math.abs(Economy.takeEventExtra(rested) - b / 2) < 1e-6).to.equal(true)
		end)
	end)
	describe("AfkCafe auto rejoin (#3602)", function()
		it(
			"is due once the player has had no input for Config.AutoRejoinSeconds, and again only after the retry wait",
			function()
				local after = Config.AutoRejoinSeconds
				expect(AfkCafe.rejoinDue(after - 1, nil, 5000)).to.equal(false)
				expect(AfkCafe.rejoinDue(after, nil, 5000)).to.equal(true)
				expect(AfkCafe.rejoinDue(after + 5, 4995, 5000)).to.equal(false)
				expect(AfkCafe.rejoinDue(after + 40, 5000 - AfkCafe.REJOIN_RETRY_SECONDS, 5000)).to.equal(
					true
				)
			end
		)

		it("rejoins ahead of Roblox's 20 minute idle disconnect, with room for retries", function()
			expect(Config.AutoRejoinSeconds + 3 * AfkCafe.REJOIN_RETRY_SECONDS <= 20 * 60).to.equal(
				true
			)
			expect(Config.AutoRejoinSeconds > Config.AfkCafeSeconds).to.equal(true)
		end)

		it("knows its own arrival and nothing else", function()
			local data = AfkCafe.teleportData()
			expect(AfkCafe.arrivedResting(data, 77, 77)).to.equal(true)
			expect(AfkCafe.arrivedResting(data, 78, 77)).to.equal(false)
			expect(AfkCafe.arrivedResting(data, nil, 77)).to.equal(false)
			expect(AfkCafe.arrivedResting(nil, 77, 77)).to.equal(false)
			expect(AfkCafe.arrivedResting("cafeRest", 77, 77)).to.equal(false)
			expect(AfkCafe.arrivedResting({ cafeRest = "yes" }, 77, 77)).to.equal(false)
		end)

		it("takes the rest up again only in the zone, still, free and inside the window", function()
			local still = AfkCafe.ARRIVAL_STILL_SECONDS
			expect(AfkCafe.arrivalRests(10, still, true, false)).to.equal(true)
			expect(AfkCafe.arrivalRests(10, still - 1, true, false)).to.equal(false)
			expect(AfkCafe.arrivalRests(10, still, false, false)).to.equal(false)
			expect(AfkCafe.arrivalRests(10, still, true, true)).to.equal(false)
			expect(AfkCafe.arrivalRests(AfkCafe.ARRIVAL_SECONDS + 1, still, true, false)).to.equal(
				false
			)
		end)

		it("keeps its window open past the rejoin's longest wait for the move home", function()
			local Cannon =
				require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Cannon)
			local landed = Cannon.REJOIN_HOME_WAIT_SECONDS + AfkCafe.ARRIVAL_STILL_SECONDS
			expect(AfkCafe.arrivalRests(landed, AfkCafe.ARRIVAL_STILL_SECONDS, true, false)).to.equal(
				true
			)
		end)
	end)
end
