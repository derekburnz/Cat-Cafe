--!strict
-- Invites.luau (#2797, retention-ideas.md 5d): the invite reward's rules. A new player who joined through an invite
-- links to the inviter once; the joiner is paid on their first catch, the inviter once the joiner has played 5
-- minutes or caught a cat, once per joiner and at most 5 a day; and the save survives a load.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Invites = require(Shared.Invites)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000
	local DAY = 86400

	local function fresh(): any
		return ProfileSchema.template(NOW)
	end

	describe("Invites (#2797)", function()
		it("pays 20 golden fish each side, after 5 minutes or a catch, 5 joiners a day", function()
			expect(Config.InviteRewardFish).to.equal(20)
			expect(Config.InviteQualifySeconds).to.equal(300)
			expect(Config.InviteDailyMax).to.equal(5)
			expect(Config.InviteCardFromSeconds).to.equal(300)
			expect(Config.InviteCardBySeconds).to.equal(900)
		end)

		it("links only a brand-new save to someone else's invite, once", function()
			local profile = fresh()
			expect(Invites.links(profile, 1, 2, 0)).to.equal(true)
			expect(Invites.links(profile, 1, nil, 0)).to.equal(false)
			expect(Invites.links(profile, 1, 0, 0)).to.equal(false)
			expect(Invites.links(profile, 1, 1, 0)).to.equal(false) -- their own link
			expect(Invites.links(profile, 1, 2, 30)).to.equal(false) -- played before
			profile.stats.catsCaught = 1
			expect(Invites.links(profile, 1, 2, 0)).to.equal(false)
			local linked = fresh()
			linked.referredBy = { userId = 3, paid = false, queued = false }
			expect(Invites.links(linked, 1, 2, 0)).to.equal(false)
		end)

		it("pays the joiner on their first catch and sends the inviter's at 5 minutes or a catch", function()
			local profile = fresh()
			profile.referredBy = { userId = 2, paid = false, queued = false }
			expect(Invites.joinerDue(profile)).to.equal(false)
			expect(Invites.inviterDue(profile, 299)).to.equal(false)
			expect(Invites.inviterDue(profile, 300)).to.equal(true)
			profile.stats.catsCaught = 1
			expect(Invites.joinerDue(profile)).to.equal(true)
			expect(Invites.inviterDue(profile, 10)).to.equal(true)
			profile.referredBy.paid = true
			profile.referredBy.queued = true
			expect(Invites.joinerDue(profile)).to.equal(false)
			expect(Invites.inviterDue(profile, 9999)).to.equal(false)
			expect(Invites.joinerDue(fresh())).to.equal(false)
		end)

		it("credits an inviter once per joiner and at most InviteDailyMax a day", function()
			local save = Invites.fresh()
			expect(Invites.leftToday(save, NOW)).to.equal(5)
			for joiner = 1, 5 do
				expect(Invites.creditBlocker(save, joiner, NOW)).to.equal(nil)
				Invites.credit(save, joiner, NOW)
			end
			expect(Invites.creditBlocker(save, 1, NOW)).to.equal("already")
			expect(Invites.creditBlocker(save, 6, NOW)).to.equal("daily")
			expect(Invites.leftToday(save, NOW)).to.equal(0)
			expect(Invites.creditBlocker(save, 6, NOW + DAY)).to.equal(nil)
			expect(Invites.leftToday(save, NOW + DAY)).to.equal(5)
			Invites.credit(save, 6, NOW + DAY)
			expect(save.today.count).to.equal(1)
			expect(Invites.creditBlocker(save, 3, NOW + 5 * DAY)).to.equal("already")
		end)

		it("remembers the last InviteRewardedMax joiners", function()
			local save = Invites.fresh()
			for joiner = 1, Config.InviteRewardedMax + 3 do
				Invites.credit(save, joiner, NOW + joiner * DAY)
			end
			expect(#save.rewarded).to.equal(Config.InviteRewardedMax)
			expect(save.rewarded[1]).to.equal(4)
		end)

		it("reads only the card's three reports", function()
			expect(Invites.cardAction("shown")).to.equal("shown")
			expect(Invites.cardAction("invite")).to.equal("invite")
			expect(Invites.cardAction("notnow")).to.equal("notnow")
			expect(Invites.cardAction("pay")).to.equal(nil)
			expect(Invites.cardAction(3)).to.equal(nil)
		end)

		it("keeps both sides through a load (version 47), and cleans a bad save", function()
			local profile = fresh()
			expect(profile.invites.cardShown).to.equal(false)
			expect(profile.referredBy).to.equal(nil)
			Invites.credit(profile.invites, 9, NOW)
			profile.invites.cardShown = true
			profile.referredBy = { userId = 7, paid = true, queued = false }
			local loaded: any = ProfileSchema.migrate(profile, NOW)
			expect(loaded.invites.rewarded).to.deepEqual({ 9 })
			expect(loaded.invites.cardShown).to.equal(true)
			expect(loaded.referredBy).to.deepEqual({ userId = 7, paid = true, queued = false })
			local raw: any = fresh()
			raw.invites = { rewarded = { 5, 5, -1, "x", 2.5, 8 }, today = { day = "x" }, cardShown = 1 }
			raw.referredBy = { userId = -3 }
			local bad: any = ProfileSchema.migrate(raw, NOW)
			expect(bad.invites.rewarded).to.deepEqual({ 5, 2, 8 })
			expect(bad.invites.today).to.deepEqual({ day = 0, count = 0 })
			expect(bad.invites.cardShown).to.equal(false)
			expect(bad.referredBy).to.equal(nil)
		end)

		it("views the card's window and today's room", function()
			local view = Invites.view(fresh(), NOW)
			expect(view :: any).to.deepEqual({ cardShown = false, fish = 20, leftToday = 5, cardFrom = 300, cardBy = 900 })
		end)
	end)
end
