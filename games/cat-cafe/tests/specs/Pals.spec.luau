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
		it("is +10% with one pal and +15% with two or more", function()
			expect(Config.PalTipBonus).to.equal(0.10)
			expect(Config.PalTipBonusMax).to.equal(0.15)
			expect(Pals.bonus(0)).to.equal(0)
			expect(Pals.bonus(1)).to.equal(0.10)
			expect(Pals.bonus(2)).to.equal(0.15)
			expect(Pals.bonus(9)).to.equal(0.15)
		end)

		it("is held per profile for the session and cleared at 0", function()
			local profile = cafe()
			expect(Economy.pals(profile)).to.equal(0)
			expect(Economy.palBonus(profile)).to.equal(0)
			Economy.setPals(profile, 2)
			expect(Economy.pals(profile)).to.equal(2)
			expect(Economy.palBonus(profile)).to.equal(0.15)
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
end
