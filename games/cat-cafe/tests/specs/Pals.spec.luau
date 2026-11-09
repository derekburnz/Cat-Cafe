--!strict
-- Pals.luau and Economy's pal bonus against playing-together.md sections 1 and 2 (F92): +10% tips with one pal and
-- +15% with two or more, on top of the potions, settled over a window, never in offline pay; the invite's launch data.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Pals = require(Shared.Pals)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 100000

	-- A Tier 1 cafe with its starter cat at work, so the day rate is above 0.
	local function cafe(): Types.PlayerProfile
		local profile = ProfileSchema.template(NOW)
		expect(Economy.incomePerSecond(profile) > 0).to.equal(true)
		return profile
	end

	describe("the bonus", function()
		it("is +10% with one pal, +5% for each more, at most +20% from three (#1165, #1347)", function()
			expect(Config.PalTipBonus).to.equal(0.10)
			expect(Config.PalTipBonusStep).to.equal(0.05)
			expect(Config.PalTipBonusMax).to.equal(0.20)
			expect(Pals.bonus(0)).to.equal(0)
			expect(Pals.bonus(1)).to.be.near(0.10, 1e-9)
			expect(Pals.bonus(2)).to.be.near(0.15, 1e-9)
			expect(Pals.bonus(3)).to.be.near(0.20, 1e-9)
			expect(Pals.bonus(4)).to.be.near(0.20, 1e-9)
			expect(Pals.bonus(9)).to.be.near(0.20, 1e-9)
		end)

		it("is held per profile for the session and cleared at 0", function()
			local profile = cafe()
			expect(Economy.pals(profile)).to.equal(0)
			expect(Economy.palBonus(profile)).to.equal(0)
			Economy.setPals(profile, 2)
			expect(Economy.pals(profile)).to.equal(2)
			expect(Economy.palBonus(profile)).to.be.near(0.15, 1e-9)
			Economy.setPals(profile, 0)
			expect(Economy.pals(profile)).to.equal(0)
			-- another profile never sees it
			Economy.setPals(profile, 1)
			expect(Economy.pals(cafe())).to.equal(0)
		end)

		it("adds to the potions' share for income, the tip piles and rich visitors", function()
			local profile = cafe()
			expect(Economy.tipMultiplier(profile, NOW)).to.equal(1)
			Economy.setPals(profile, 1)
			expect(Economy.tipMultiplier(profile, NOW)).to.be.near(1.10, 1e-9)
			profile.buffs[Potions.TIP] = 600
			expect(Economy.tipMultiplier(profile, NOW)).to.be.near(
				1 + Config.TipPotionBonus + 0.10,
				1e-9
			)
		end)
	end)

	describe("settling", function()
		it(
			"pays the bonus over the window on top of the day rate and counts it for pal_bonus",
			function()
				local alone, together = cafe(), cafe()
				Economy.setPals(together, 1)
				local rate = Economy.incomePerSecond(alone)
				local soloEarned = Economy.settle(alone, NOW + 100)
				local palEarned = Economy.settle(together, NOW + 100)
				expect(soloEarned).to.be.near(rate * 100, 1e-6)
				expect(palEarned).to.be.near(rate * 100 * 1.10, 1e-6)
				expect(Economy.takePalEarned(together)).to.be.near(rate * 100 * 0.10, 1e-6)
				expect(Economy.takePalEarned(together)).to.equal(0) -- taken once
				expect(Economy.takePalEarned(alone)).to.equal(0)
			end
		)

		it(
			"never touches the day rate, so offline pay and the HUD's base rate stay as they were",
			function()
				local profile = cafe()
				local rate = Economy.incomePerSecond(profile)
				Economy.setPals(profile, 3)
				expect(Economy.incomePerSecond(profile)).to.equal(rate)
			end
		)
	end)

	describe("invites", function()
		it("carry the inviter's id in the launch data and read it back", function()
			expect(Pals.inviteData(12345)).to.equal("pal:12345")
			expect(Pals.inviterOf(Pals.inviteData(12345))).to.equal(12345)
		end)

		it("read nothing else as an inviter", function()
			for _, bad in
				{
					nil :: any,
					42,
					"",
					"pal:",
					"pal:0",
					"pal:-5",
					"pal:12a",
					"12345",
					" pal:12345",
					"pal:12345 ",
					"pal:" .. string.rep("9", 20),
					string.rep("x", 100),
				}
			do
				expect(Pals.inviterOf(bad)).to.equal(nil)
			end
		end)
	end)

	describe("the invite nudge (section 5)", function()
		local Tips = require(Shared.Tips)
		local TODAY = NOW // 86400

		-- past the first loop, every other ask seen, on its first day
		local function settled(tier: number): any
			local profile: any = ProfileSchema.template(NOW)
			profile.tutorialStep = 5
			profile.tier = tier
			profile.telemetry.firstDay = TODAY
			for _, id in { Tips.NOTIFY_ASK, Tips.FAVORITE_ASK, Tips.LIKE_ASK } do
				profile.tipsSeen[id] = true
			end
			return profile
		end

		it("comes once an account after the first rank up, as the last ask", function()
			expect(Tips.ASKS[#Tips.ASKS]).to.equal(Tips.INVITE_ASK)
			expect(Tips.isAsk(Tips.INVITE_ASK)).to.equal(true)
			expect(Tips.dueAsk(settled(1), NOW, TODAY)).to.equal(nil)
			local ranked = settled(2)
			expect(Tips.dueAsk(ranked, NOW, TODAY)).to.equal(Tips.INVITE_ASK)
			ranked.tipsSeen[Tips.INVITE_ASK] = true
			expect(Tips.dueAsk(ranked, NOW, TODAY + 30)).to.equal(nil)
		end)

		it("waits behind the other asks and the first loop", function()
			local profile = settled(3)
			profile.tipsSeen[Tips.FAVORITE_ASK] = nil
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.FAVORITE_ASK)
			profile.tipsSeen[Tips.FAVORITE_ASK] = true
			profile.tutorialStep = 4
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(nil)
		end)

		it("stays put through a save and Show tips again", function()
			local raw: any = { invite_ask = true }
			expect(Tips.sanitizeSeen(raw, false) :: any).to.deepEqual(raw)
			expect(Tips.cleared(raw) :: any).to.deepEqual(raw)
		end)
	end)
end
