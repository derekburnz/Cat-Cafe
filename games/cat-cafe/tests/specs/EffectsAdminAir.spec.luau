--!strict
-- Effects/AdminAir and the part 2 words of Effects/AdminEventLogic (#4197): the effects read by name, their lines
-- and badge, which of them hangs a drift round you, and that the drift stops for Reduce Motion and Low performance.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local AdminAir = require(Effects:WaitForChild("AdminAir")) :: any
	local AdminEventLogic = require(Effects:WaitForChild("AdminEventLogic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local NOW = 1800000000

	local function view(effects: { [string]: any }, running: boolean?): any
		local values: { [string]: any } = {
			AdminEventId = "owner-admin-2",
			AdminEventTitle = "Golden Hour",
			AdminEventStartsAt = NOW,
			AdminEventEndsAt = NOW + 900,
			AdminEventEffects = "json",
			AdminEventRunning = running ~= false,
		}
		return AdminEventLogic.read(function(name: string): any
			return values[name]
		end, function(_json: string): any
			return effects
		end)
	end

	describe("Effects admin air", function()
		it("reads part 2's effects by name and drops the ones that do nothing", function()
			local golden = view({ goldBoost = 10, rainbowBoost = 5 })
			expect(golden.extra.goldBoost).to.equal(10)
			expect(golden.extra.rainbowBoost).to.equal(5)
			expect(golden.bowlSpeed).to.equal(1)
			expect(view({ moneyStorm = 1 }).extra).never.to.be.ok() -- 1x is no boost
			expect(view({ moneyStorm = "5", traitParty = 0 }).extra).never.to.be.ok()
			expect(view({ traitParty = true }).extra.traitParty).to.equal(1)
			expect(view({ secretHunt = 3 }).extra.secretHunt).to.equal(3)
			expect(view({ nothingWeKnow = 4 }).extra).never.to.be.ok()
		end)

		it("says each effect in one calm line, with the biggest number on the badge", function()
			local golden = view({ goldBoost = 10, rainbowBoost = 5 })
			local lines = AdminEventLogic.effectLines(golden)
			expect(lines[1]).to.equal("Gold coats 10x as likely")
			expect(lines[2]).to.equal("Rainbow coats 5x as likely")
			expect(AdminEventLogic.badge(golden)).to.equal("10x")
			expect(AdminEventLogic.effectLines(view({ moneyStorm = 5 }))[1]).to.equal(
				"Cafe money 5x for everyone"
			)
			expect(AdminEventLogic.effectLines(view({ secretHunt = 3 }))[1]).to.equal(
				"3 Secret cats are hiding"
			)
			expect(AdminEventLogic.badge(view({ secretHunt = 3 }))).to.equal("!")
			for _, row in AdminEventLogic.EXTRA do
				local got = AdminEventLogic.effectLines(view({ [row.name] = 2 }))
				expect(#got).to.equal(1)
				expect(string.find(got[1], "%", 1, true)).never.to.be.ok()
				expect(#got[1] <= 48).to.equal(true) -- fits the banner's line
			end
		end)

		it("hangs a drift for Golden Hour and Money Storm only, each with its emitter", function()
			expect(AdminEventLogic.airOf(view({ goldBoost = 10 }))).to.equal("goldBoost")
			expect(AdminEventLogic.airOf(view({ moneyStorm = 5 }))).to.equal("moneyStorm")
			expect(AdminEventLogic.airOf(view({ speedRush = 1 }))).never.to.be.ok()
			expect(AdminEventLogic.airOf(view({ catStorm = 10 }))).never.to.be.ok()
			expect(AdminEventLogic.airOf(nil)).never.to.be.ok()
			for _, name in AdminEventLogic.AIR do
				local preset = Presets.adminAir.kinds[name]
				expect(preset).to.be.ok()
				expect(Presets.emitters[preset]).to.be.ok()
				expect(Presets.emitters[preset].rate <= 15).to.equal(true)
			end
		end)

		it("runs only while the event does, never with Reduce Motion or Low performance", function()
			local kinds = Presets.adminAir.kinds
			expect(AdminAir.pick("goldBoost", true, false, kinds)).to.equal("goldHourDrift")
			expect(AdminAir.pick("moneyStorm", true, false, kinds)).to.equal("moneyStormDrift")
			expect(AdminAir.pick("goldBoost", false, false, kinds)).never.to.be.ok()
			expect(AdminAir.pick("goldBoost", true, true, kinds)).never.to.be.ok()
			expect(AdminAir.pick(nil, true, false, kinds)).never.to.be.ok()
			expect(AdminAir.pick("speedRush", true, false, kinds)).never.to.be.ok()
		end)
	end)
end
