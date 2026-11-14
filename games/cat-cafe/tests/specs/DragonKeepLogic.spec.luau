--!strict
-- UI/Components/DragonKeepLogic.luau: what the Dragon Keep window shows (#4062).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("DragonKeepLogic")
	) :: any

	describe("DragonKeepLogic.title and warmth", function()
		it("names the stage, or Egg before the first", function()
			expect(Logic.title({ stageName = "Drake" })).to.equal("Cinder · Drake")
			expect(Logic.title({})).to.equal("Cinder · Egg")
		end)
		it("runs the bar from the stage reached to the next mark", function()
			local text, share = Logic.warmth({ warmth = 650, stage = 2, nextAt = 1000 })
			expect(text).to.equal("650 / 1,000 warmth")
			expect(share).to.equal(0.5)
			local _, egg = Logic.warmth({ warmth = 25, stage = 0, nextAt = 50 })
			expect(egg).to.equal(0.5)
		end)
		it("runs it over the last Rekindle after the top stage", function()
			local text, share = Logic.warmth({ warmth = 5750, stage = 5, nextAt = 6500 })
			expect(text).to.equal("5,750 / 6,500 warmth")
			expect(share).to.equal(0.5)
		end)
	end)

	describe("DragonKeepLogic.slots", function()
		it("shows open slots and the stages that open the rest", function()
			local slots = Logic.slots({ slots = { "warmTips", "" } })
			expect(#slots).to.equal(5)
			expect(slots[1].card).to.equal("warmTips")
			expect(slots[1].label).to.equal("Warm Tips")
			expect(slots[2].card).to.equal(nil)
			expect(slots[2].label).to.equal("Empty")
			expect(slots[3].locked).to.equal(true)
			expect(slots[3].label).to.equal("Stage 3")
		end)
	end)

	describe("DragonKeepLogic.setsLine and oddsLine", function()
		it("explains sets before any card is slotted", function()
			expect(Logic.setsLine({ slots = { "" } })).to.equal(
				"3 cards of one family in your slots light a set bonus"
			)
		end)
		it("counts each family in the slots", function()
			expect(Logic.setsLine({ slots = { "warmTips", "emberTips", "sharpEye" } })).to.equal(
				"Sets: Flame 2/3 · Claw 1/3"
			)
		end)
		it("lists the odds in rarity order", function()
			expect(Logic.oddsLine({ Rare = 30, Common = 45, Epic = 25 })).to.equal(
				"Card odds: Common 45% · Rare 30% · Epic 25%"
			)
		end)
	end)

	describe("DragonKeepLogic.binder", function()
		it("lists all 54 cards with the owned and slotted ones marked", function()
			local view = { binder = { warmTips = true, sharpEye = true }, slots = { "sharpEye" } }
			local list = Logic.binder(view)
			expect(#list).to.equal(54)
			expect(list[1].family).to.equal("flame")
			local owned, slotted = 0, nil
			for _, entry in list do
				if entry.owned then
					owned += 1
				end
				if entry.slot ~= nil then
					slotted = entry.id
				end
			end
			expect(owned).to.equal(2)
			expect(slotted).to.equal("sharpEye")
			expect(Logic.ownedCount(view)).to.equal(2)
		end)
	end)

	describe("DragonKeepLogic.candidates, quick and picked", function()
		local cats = {
			a = { catId = "tabby" },
			b = { catId = "tabby" },
			c = { catId = "tabby", spotId = "spot1" },
			d = { catId = "tuxedo" },
			e = { catId = "tuxedo", variant = "gold" },
			f = { catId = "binbag" },
			g = { catId = "binbag" },
			h = { catId = "void" },
			i = { catId = "ginger", locked = true },
			j = { catId = "smoke" },
		}
		it("leaves out locked and busy cats and sorts weakest first", function()
			local list = Logic.candidates(cats, { j = true })
			expect(#list).to.equal(8)
			expect(list[1].warmth <= list[#list].warmth).to.equal(true)
			for _, cand in list do
				expect(cand.uid ~= "i" and cand.uid ~= "j").to.equal(true)
			end
		end)
		it("marks gold coats and Legendary cats special", function()
			local special = {}
			for _, cand in Logic.candidates(cats, nil) do
				special[cand.uid] = cand.special
			end
			expect(special.e).to.equal(true)
			expect(special.h).to.equal(true)
			expect(special.a).to.equal(false)
		end)
		it("keeps one copy of each cat and skips working and special cats", function()
			local list = Logic.candidates(cats, nil)
			local commons = Logic.quick(list, "commons", 10)
			-- the working tabby is the copy kept, so both free tabbies go; the gold tuxedo stays, so the plain one goes
			expect(#commons).to.equal(3)
			local repeats = Logic.quick(list, "repeats", 10)
			expect(#repeats).to.equal(4) -- two tabbies, the plain tuxedo and one binbag
			-- never the last copy: a lone Smoke stays
			local twins =
				Logic.quick(Logic.candidates({ x = { catId = "smoke" } }, nil), "commons", 10)
			expect(#twins).to.equal(0)
			for _, uid in repeats do
				expect(uid ~= "c" and uid ~= "e" and uid ~= "h").to.equal(true)
			end
		end)
		it("adds up the picked warmth and special cats", function()
			local list = Logic.candidates(cats, nil)
			local count, warmth, special = Logic.picked(list, { a = true, f = true, e = true })
			expect(count).to.equal(3)
			expect(warmth).to.equal(1 + 2 + 2)
			expect(special).to.equal(1)
		end)
	end)

	describe("DragonKeepLogic.giveText", function()
		it("says what one press does", function()
			expect(Logic.giveText(0, 0, 0, false)).to.equal("Pick cats to move in")
			expect(Logic.giveText(12, 1800, 0, false)).to.equal("Move 12 cats in · +1,800 warmth")
			expect(Logic.giveText(1, 1, 0, false)).to.equal("Move 1 cat in · +1 warmth")
			expect(Logic.giveText(3, 9, 1, true)).to.equal("Tap again: 1 special cat moves in")
			expect(Logic.giveText(3, 9, 2, true)).to.equal("Tap again: 2 special cats move in")
		end)
	end)
end
