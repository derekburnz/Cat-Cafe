--!strict
-- The update party's banner (#3419, Effects/EventBanner): it only draws words it can fit, never stacks two of a kind,
-- lands and leaves cleanly, stays inside the phone's burst cap and is still with Reduce Motion. Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local EventBanner = require(Effects:WaitForChild("EventBanner")) :: any

	describe("Effects event banner", function()
		it("takes the launch's words as they are", function()
			local plan = EventBanner.plan({
				kind = "party",
				title = "Update Party!",
				lines = {
					"x2 cafe earnings until 12:00 PM",
					"New: Mystic Pool and Mouse Dash",
					"Rare cat showers all hour",
				},
			})
			expect(plan.kind).to.equal("party")
			expect(plan.title).to.equal("Update Party!")
			expect(#plan.lines).to.equal(3)
			expect(plan.lines[1]).to.equal("x2 cafe earnings until 12:00 PM")
			expect(plan.lines[2]).to.equal("New: Mystic Pool and Mouse Dash")
			expect(plan.seconds).to.equal(Presets.eventBanner.hold)
			local gift = EventBanner.plan({ kind = "gift", title = "A gift for everyone!" })
			expect(gift.title).to.equal("A gift for everyone!")
			expect(#gift.lines).to.equal(0)
		end)

		it("draws nothing for words it cannot use and trims the rest", function()
			expect(EventBanner.plan(nil)).to.equal(nil)
			expect(EventBanner.plan("party")).to.equal(nil)
			expect(EventBanner.plan({ kind = "sale", title = "Sale!" })).to.equal(nil)
			expect(EventBanner.plan({ kind = "party" })).to.equal(nil)
			expect(EventBanner.plan({ kind = "party", title = "   " })).to.equal(nil)
			expect(EventBanner.plan({ kind = "party", title = 5 })).to.equal(nil)
			local plan = EventBanner.plan({
				kind = "giftSoon",
				title = "  " .. string.rep("A", 40),
				lines = { "one", 2, "", "  two  ", string.rep("b", 60), "four" },
				seconds = 99,
			})
			expect(plan.title).to.equal(string.rep("A", Presets.eventBanner.titleLength))
			expect(#plan.lines).to.equal(3)
			expect(plan.lines[1]).to.equal("one")
			expect(plan.lines[2]).to.equal("two")
			expect(#plan.lines[3]).to.equal(Presets.eventBanner.lineLength)
			expect(plan.seconds).to.equal(Presets.eventBanner.holdMax)
			local short = EventBanner.plan({ kind = "gift", title = "Hi", seconds = 0 })
			expect(short.seconds).to.equal(Presets.eventBanner.holdMin)
			local odd = EventBanner.plan({ kind = "gift", title = "Hi", seconds = 0 / 0 })
			expect(odd.seconds).to.equal(Presets.eventBanner.hold)
			-- a cut never splits a character
			local fish = EventBanner.plan({ kind = "gift", title = string.rep("🐟", 30) })
			expect(utf8.len(fish.title)).to.equal(Presets.eventBanner.titleLength)
		end)

		it("never stacks two of a kind and keeps the line short", function()
			expect(EventBanner.accepts(nil, {}, "party", 3)).to.equal(true)
			expect(EventBanner.accepts("party", {}, "party", 3)).to.equal(false)
			expect(EventBanner.accepts("party", {}, "gift", 3)).to.equal(true)
			expect(EventBanner.accepts("party", { "gift" }, "gift", 3)).to.equal(false)
			expect(EventBanner.accepts("party", { "giftSoon" }, "gift", 3)).to.equal(true)
			expect(EventBanner.accepts(nil, { "a", "b", "c" }, "gift", 3)).to.equal(false)
		end)

		it("drops in from off the screen, rests, and leaves the same way", function()
			local p = Presets.eventBanner
			expect(EventBanner.lift(0, 6, 200)).to.equal(200)
			expect(EventBanner.lift(p.dropSeconds, 6, 200)).to.equal(0)
			expect(EventBanner.lift(p.dropSeconds + 3, 6, 200)).to.equal(0)
			expect(EventBanner.lift(p.dropSeconds + 6 + p.leaveSeconds + 0.01, 6, 200)).to.equal(
				200
			)
			expect(EventBanner.lift(999, 6, 200)).to.equal(200)
			-- one small overshoot past its resting place on the way down, never by more than a fifth of the way
			local lowest = 0
			for i = 1, 100 do
				lowest = math.min(lowest, EventBanner.lift(p.dropSeconds * i / 100, 6, 200))
			end
			expect(lowest < 0).to.equal(true)
			expect(lowest > -40).to.equal(true)
		end)

		it("leaves at once when tapped, after landing if it was still on its way in", function()
			local p = Presets.eventBanner
			local enter = p.dropSeconds
			-- tapped 2 seconds into its rest: the hold becomes those 2 seconds, so it is leaving from now
			local hold = EventBanner.holdAfterTap(enter + 2, 5, enter)
			expect(hold).to.equal(2)
			expect(EventBanner.lift(enter + 2, hold, 200)).to.equal(0)
			expect(EventBanner.lift(enter + 2 + p.leaveSeconds / 2, hold, 200) > 0).to.equal(true)
			-- tapped on its way in: it lands, then leaves with no hold
			expect(EventBanner.holdAfterTap(enter / 2, 5, enter)).to.equal(0)
			-- a tap once it is already leaving changes nothing
			expect(EventBanner.holdAfterTap(enter + 9, 5, enter)).to.equal(5)
		end)

		it("fades in place with Reduce Motion, with no confetti and no fish", function()
			local p = Presets.eventBanner
			expect(EventBanner.fade(0, 6)).to.equal(1)
			expect(EventBanner.fade(p.fadeSeconds, 6)).to.equal(0)
			expect(EventBanner.fade(p.fadeSeconds + 6, 6)).to.equal(0)
			expect(EventBanner.fade(p.fadeSeconds * 2 + 6 + 0.01, 6)).to.equal(1)
			for _, kind in { "party", "giftSoon", "gift" } do
				local confetti, fish = EventBanner.counts(kind, false, true)
				expect(confetti).to.equal(0)
				expect(fish).to.equal(0)
			end
		end)

		it(
			"keeps the confetti inside the phone's burst cap and gives fish to the gift only",
			function()
				local p = Presets.eventBanner
				local most = Presets.budget.low.maxBurst
				local confetti, fish = EventBanner.counts("party", false, false)
				expect(confetti <= most).to.equal(true)
				expect(fish).to.equal(0)
				confetti, fish = EventBanner.counts("giftSoon", false, false)
				expect(confetti).to.equal(p.confettiSoon)
				expect(fish).to.equal(0)
				confetti, fish = EventBanner.counts("gift", false, false)
				expect(confetti <= most).to.equal(true)
				expect(fish).to.equal(p.fish)
				expect(fish <= most).to.equal(true)
				confetti, fish = EventBanner.counts("gift", true, false)
				expect(confetti).to.equal(math.ceil(p.confetti / 2))
				expect(fish).to.equal(math.ceil(p.fish / 2))
				-- a calm banner: it holds long enough to read and the shine is one sweep, not a flash
				expect(p.hold >= 3 and p.hold <= 5).to.equal(true)
				expect(p.holdMax <= 5).to.equal(true)
				expect(p.shineSeconds >= 0.5).to.equal(true)
			end
		)
	end)
end
