--!strict
-- shared/AwayNotify (#2768): what the server notes at logout for the "your cats earned X while you were away"
-- notification. The amount must be the welcome back card's own sum, counted to the moment the message is due.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AwayNotify = require(Shared.AwayNotify)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local JoinSource = require(Shared.JoinSource)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ShortNumber = require(Shared.ShortNumber)

	local NOW = 1_800_000_000

	local function earning(): any
		local profile: any = ProfileSchema.template(NOW)
		expect(Economy.incomePerSecond(profile) > 0).to.equal(true)
		return profile
	end

	describe("AwayNotify.plan", function()
		it("is due AwayNotifySeconds after leaving and lives the grace longer", function()
			local plan: any = AwayNotify.plan(earning(), NOW)
			expect(plan).never.to.equal(nil)
			expect(plan.dueAt).to.equal(NOW + Config.AwayNotifySeconds)
			expect(plan.ttl).to.equal(Config.AwayNotifySeconds + Config.AwayNotifyGraceSeconds)
			expect(Config.AwayNotifySeconds).to.equal(12 * 3600) -- Derek2 2026-11-10: 12 h after leaving
		end)

		it("says exactly what the welcome back card will pay by then", function()
			local profile = earning()
			local rate = Economy.incomePerSecond(profile)
			local plan: any = AwayNotify.plan(profile, NOW)
			-- 12 h away is past the 8 h cap, so the card pays the capped sum at the offline rate
			local paid = Economy.offlineGain(rate, NOW, NOW + Config.AwayNotifySeconds, false)
			expect(paid).to.equal(math.floor(rate * Config.OfflineRate * Config.OfflineCapSeconds))
			expect(plan.text).to.equal("$" .. ShortNumber.format(paid))
		end)

		it("counts the Long Nap pass's rate and longer cap", function()
			local profile = earning()
			local plain: any = AwayNotify.plan(profile, NOW)
			Economy.setPasses(profile, { money = 1, longNap = true, slots = 0 } :: any)
			local rate = Economy.incomePerSecond(profile)
			local napped: any = AwayNotify.plan(profile, NOW)
			local paid = Economy.offlineGain(rate, NOW, NOW + Config.AwayNotifySeconds, true)
			expect(paid).to.equal(math.floor(rate * Config.OfflineRatePass * Config.AwayNotifySeconds))
			expect(napped.text).to.equal("$" .. ShortNumber.format(paid))
			expect(napped.text).never.to.equal(plain.text)
			Economy.setPasses(profile, nil)
		end)

		it("notes nothing for a cafe that earns too little to mention", function()
			local profile = earning()
			for uid in profile.cats do
				profile.cats[uid].role = nil
			end
			if Economy.incomePerSecond(profile) == 0 then
				expect(AwayNotify.plan(profile, NOW)).to.equal(nil)
			end
			local empty: any = ProfileSchema.template(NOW)
			empty.cats = {}
			expect(AwayNotify.plan(empty, NOW)).to.equal(nil)
		end)

		it("never promises more than AwayNotifyMinCoins allows through", function()
			local plan: any = AwayNotify.plan(earning(), NOW)
			local paid = Economy.offlineGain(
				Economy.incomePerSecond(earning()),
				NOW,
				NOW + Config.AwayNotifySeconds,
				false
			)
			expect(paid >= Config.AwayNotifyMinCoins).to.equal(true)
			expect(string.sub(plan.text, 1, 1)).to.equal("$")
		end)
	end)

	describe("AwayNotify names", function()
		it("keys a note by the user id and tags the join it brings", function()
			expect(AwayNotify.key(123456789)).to.equal("123456789")
			expect(AwayNotify.LAUNCH_DATA).to.equal(JoinSource.NOTIFY)
			expect(JoinSource.parse(AwayNotify.LAUNCH_DATA)).to.equal(JoinSource.NOTIFY)
			expect(#AwayNotify.MAP <= 50).to.equal(true)
		end)
	end)
end
