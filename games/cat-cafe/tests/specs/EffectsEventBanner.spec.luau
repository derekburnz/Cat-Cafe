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
			for _, kind in { "party", "giftSoon", "gift", "secrets" } do
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
		it(
			"shows the Secret cats as black shapes under the words, a few sparkles and no fish",
			function()
				local p = Presets.eventBanner
				local plan = EventBanner.plan({
					kind = "secrets",
					title = "Secret cats are out!",
					lines = { "Three hidden cats roam every area" },
				})
				expect(plan.kind).to.equal("secrets")
				expect(plan.title).to.equal("Secret cats are out!")
				-- the card grows by the row of shapes, and only this kind has it
				expect(EventBanner.height("secrets", 1)).to.equal(
					EventBanner.height("party", 1) + p.shapeRow
				)
				expect(p.shapeSize <= p.shapeRow).to.equal(true)
				-- every shape is one of the Secret cats' own models, so a redesigned model changes its shape by itself
				local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog) :: any
				local names = EventBanner.shapeModels()
				expect(#names >= 1 and #names <= p.shapeMost).to.equal(true)
				for i, name in names do
					expect(name).to.equal(Catalog.catModelName(Catalog.secretCats[i].id))
				end
				-- the row fits the narrowest card (a 320 px phone at the card's width)
				local row = #names * p.shapeSize + (#names - 1) * p.shapeGap
				expect(row <= 320 * p.widthScale - p.pad * 2).to.equal(true)
				-- black, with the "?" readable on it
				local c = p.shapeColour
				expect(math.max(c.R, c.G, c.B) < 0.06).to.equal(true)
				local m = p.markColour
				expect(math.min(m.R, m.G, m.B) > 0.7).to.equal(true)
				-- a bigger box stands further back and a whole cat fits its square
				local near =
					EventBanner.shapeDistance(Vector3.new(2, 2, 3), p.shapeFov, p.shapeFill)
				local far = EventBanner.shapeDistance(Vector3.new(4, 4, 6), p.shapeFov, p.shapeFill)
				expect(far > near).to.equal(true)
				local half = math.sqrt(2 * 2 + 3 * 3) / 2
				expect(half / (near - half) <= math.tan(math.rad(p.shapeFov / 2))).to.equal(true)
				expect(EventBanner.shapeDistance(Vector3.zero, p.shapeFov, p.shapeFill) > 0).to.equal(
					true
				)
				-- only the loose bits of a Secret cat's own named prop are left off, never a body, head or ear
				for _, name in p.shapeLeaveOff do
					local prop = string.match(name, "^CatCafe_Cat_%a+_Prop%d?$") ~= nil
					local glow = string.match(name, "^CatCafe_Cat_%a+_Glow$") ~= nil
					expect(prop or glow).to.equal(true)
				end
				-- Glitch's pixels (0.12 to 0.22 studs) go, the torn bars at its head's sides (0.71 long) stay
				expect(EventBanner.loose(0.22, 0.22, 0.22, p.shapeLoose)).to.equal(true)
				expect(EventBanner.loose(0.12, 0.12, 0.12, p.shapeLoose)).to.equal(true)
				expect(EventBanner.loose(0.17, 0.13, 0.71, p.shapeLoose)).to.equal(false)
				-- a cat held back on the day stays off the row: the caller names the ones that are out
				local first = Catalog.secretCats[1].id
				local some = EventBanner.shapeModels({ first, "tabby", "nope" })
				expect(#some).to.equal(1)
				expect(some[1]).to.equal(Catalog.catModelName(first))
				expect(#EventBanner.shapeModels({})).to.equal(0)
				local named = EventBanner.plan({
					kind = "secrets",
					title = "Secret cats are out!",
					cats = { first, 5, "glitch" },
				})
				expect(#named.cats).to.equal(2)
				expect(plan.cats).to.equal(nil)
				local confetti, fish = EventBanner.counts("secrets", false, false)
				expect(confetti).to.equal(p.confettiSoon)
				expect(fish).to.equal(0)
			end
		)
		it(
			"announces a Secret spawn with the area only, a few sparkles and no row of cats",
			function()
				local p = Presets.eventBanner
				local plan = EventBanner.plan({
					kind = "secretSpawn",
					title = "A Secret cat!",
					lines = { "A Secret cat is roaming the Park!" },
				})
				expect(plan.kind).to.equal("secretSpawn")
				expect(plan.lines[1]).to.equal("A Secret cat is roaming the Park!")
				-- the longest area name still fits a line
				expect(#"A Secret cat is roaming the Desert!" <= p.lineLength).to.equal(true)
				-- no row of the cats' shapes: the card is as tall as any other, and its badge is drawn from plain shapes
				expect(EventBanner.height("secretSpawn", 1)).to.equal(
					EventBanner.height("party", 1)
				)
				local confetti, fish = EventBanner.counts("secretSpawn", false, false)
				expect(confetti).to.equal(p.confettiSoon)
				expect(fish).to.equal(0)
				confetti = EventBanner.counts("secretSpawn", false, true)
				expect(confetti).to.equal(0)
				-- it never stacks: a second spawn while one shows or waits is dropped
				expect(EventBanner.accepts("secretSpawn", {}, "secretSpawn", p.queue)).to.equal(
					false
				)
				-- the "?" reads on the black head and the head reads on the starlight disc
				expect(p.spawnBadge).to.equal(Color3.fromRGB(226, 214, 255))
			end
		)
	end)
end
