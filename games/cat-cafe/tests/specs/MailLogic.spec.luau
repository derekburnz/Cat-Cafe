--!strict
-- UI/Components/MailLogic.luau (#4249): the Mailbox's waiting count, card order, end words and gift chip.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Mail = require(Components:WaitForChild("MailLogic")) :: any

	local NOW = 1800000000
	local DAY = 86400
	local names = {
		crate = function(id: string): (string?, { [string]: number }?)
			if id == "park_golden" then
				return "Golden Park Crate", { Epic = 70, Legendary = 24, Mythical = 6 }
			end
			return nil, nil
		end,
		potion = function(id: string)
			return if id == "luck" then "Luck Potion" else nil
		end,
	}
	local function letter(id: string, sentAt: number, overrides: { [string]: any }?): any
		local out: { [string]: any } = {
			id = id,
			title = "Thanks for playing!",
			note = "A little something for your cafe.",
			sentAt = sentAt,
			endsAt = nil,
			prize = { fish = 250 },
			claimed = false,
		}
		for key, value in overrides or {} do
			out[key] = value
		end
		return out
	end

	describe("MailLogic", function()
		it("is a switch that starts off", function()
			local LiveFlags = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("LiveFlags")
			) :: any
			expect(table.find(LiveFlags.KEYS, Mail.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[Mail.FLAG]).to.equal(true)
			expect(LiveFlags.shown(Mail.FLAG, nil)).to.equal(false)
		end)

		it("counts the letters still to claim, not claimed or ended ones", function()
			local mail = {
				letter("a", NOW - 10),
				letter("b", NOW - 20, { claimed = true }),
				letter("c", NOW - 30, { endsAt = NOW - 1 }),
				letter("d", NOW - 40, { endsAt = NOW + DAY }),
			}
			expect(Mail.waiting(mail, NOW)).to.equal(2)
			expect(Mail.waiting(nil, NOW)).to.equal(0)
		end)

		it(
			"puts waiting letters first, then claimed ones, newest first, and drops ended unclaimed ones",
			function()
				local rows = Mail.rows({
					letter("old", NOW - 300),
					letter("done", NOW - 10, { claimed = true }),
					letter("new", NOW - 100),
					letter("gone", NOW - 50, { endsAt = NOW - 5 }),
				}, NOW, names)
				expect(#rows).to.equal(3)
				expect(rows[1].id).to.equal("new")
				expect(rows[2].id).to.equal("old")
				expect(rows[3].id).to.equal("done")
				expect(rows[3].claimed).to.equal(true)
			end
		)

		it("says when a letter ends", function()
			expect(Mail.ends(nil, NOW)).to.equal(nil)
			expect(Mail.ends(NOW + 3 * DAY + 5, NOW)).to.equal("ends in 3 days")
			expect(Mail.ends(NOW + 5 * 3600 + 30, NOW)).to.equal("ends in 5 h")
			expect(Mail.ends(NOW + 12 * 60 + 10, NOW)).to.equal("ends in 12 min")
			expect(Mail.ends(NOW + 20, NOW)).to.equal("ends in 1 min")
			expect(Mail.ends(NOW, NOW)).to.equal("ended")
			local rows = Mail.rows({ letter("a", NOW, { endsAt = NOW + 3 * DAY + 5 }) }, NOW, names)
			expect(rows[1].from).to.equal("From Derek · ends in 3 days")
			local claimed =
				Mail.rows({ letter("a", NOW, { endsAt = NOW + DAY, claimed = true }) }, NOW, names)
			expect(claimed[1].from).to.equal("From Derek")
			local team = Mail.rows({ letter("a", NOW, { from = "Catch a Cat Cafe" }) }, NOW, names)
			expect(team[1].from).to.equal("From Catch a Cat Cafe")
		end)

		it("words the gift chip and shows the odds for crates", function()
			local fish = Mail.gift({ fish = 250 }, names)
			expect(fish.glyph).to.equal("🐟")
			expect(fish.text).to.equal("250 Golden Fish")
			expect(fish.odds).to.equal(nil)
			expect(Mail.gift({ coins = 5000 }, names).text).to.equal("5,000 coins")
			expect(Mail.gift({ traitTokens = 1 }, names).text).to.equal("1 Trait Token")
			local crates = Mail.gift({ crates = { park_golden = 3 } }, names)
			expect(crates.glyph).to.equal("📦")
			expect(crates.text).to.equal("3 Golden Park Crates")
			expect(crates.odds).to.equal("Odds: Epic 70%, Legendary 24%, Mythical 6%")
			local both = Mail.gift(
				{ fish = 100, crates = { highest_golden = 5 }, potions = { luck = 2 } },
				names
			)
			expect(both.text).to.equal("100 Golden Fish + 5 Golden Crates + 2 Luck Potions")
			expect(both.odds).to.equal(nil) -- no odds known for an unnamed crate
			expect(Mail.gift({}, names).text).to.equal("A thank you")
			expect(Mail.gift({ spins = 3 }, names).text).to.equal("3 free spins")
			expect(Mail.gift({ coins = 100, coinSeconds = 600 }, { rate = 10 }).text).to.equal(
				"6,000 coins"
			)
			expect(Mail.gift({ coins = 100, coinSeconds = 600 }, nil).text).to.equal("100 coins")
			expect(Mail.gift({ lures = { kibble = 5 } }, {
				lure = function()
					return "Kibble"
				end,
			}).text).to.equal("5 Kibble")
			expect(Mail.gift({ catFood = { cat_snack = 2 } }, nil).text).to.equal("2 cat food")
		end)
	end)
end
