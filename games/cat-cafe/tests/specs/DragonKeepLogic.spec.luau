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
				"3 cards of one family light a set bonus · tap to see them"
			)
		end)
		it("counts each family in the slots", function()
			expect(Logic.setsLine({ slots = { "warmTips", "emberTips", "sharpEye" } })).to.equal(
				"Sets: Flame 2/3 · Claw 1/3 · tap to see"
			)
			-- #4576: past 3 the count goes on to 5
			expect(
				Logic.setsLine({ slots = { "warmTips", "emberTips", "toastyTables", "hotSeats" } })
			).to.equal("Sets: Flame 4/5 · tap to see")
		end)
		it("lists every family's 3 and 5 card bonuses (#4576)", function()
			local rows = Logic.setRows({ slots = { "warmTips", "emberTips", "toastyTables" } })
			expect(#rows).to.equal(6)
			expect(rows[1].family).to.equal("flame")
			expect(rows[1].count).to.equal("3/5")
			expect(rows[1].level).to.equal(3)
			expect(string.sub(rows[1].three, 1, 9)).to.equal("3 cards: ")
			expect(rows[1].five ~= nil).to.equal(true)
			expect(rows[2].level).to.equal(0)
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

	describe("DragonKeepLogic.candidates, byRarity and picked", function()
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
		it("leaves out event cats only with keepNoEvent on (#5428)", function()
			local mixed = { a = { catId = "tabby" }, k = { catId = "hay_bale" } }
			expect(#Logic.candidates(mixed, nil)).to.equal(2)
			local list = Logic.candidates(mixed, nil, true)
			expect(#list).to.equal(1)
			expect(list[1].uid).to.equal("a")
		end)

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
		it("picks every cat of one rarity but working ones (#4566)", function()
			local list = Logic.candidates(cats, nil)
			local commons = Logic.byRarity(list, "Common", 10)
			expect(#commons > 0).to.equal(true)
			local rarity: { [string]: string } = {}
			for _, cand in list do
				rarity[cand.uid] = cand.rarity
			end
			for _, uid in commons do
				expect(rarity[uid]).to.equal("Common")
				expect(uid ~= "c").to.equal(true) -- the working tabby stays
			end
			-- never all the player's cats: the cap is total - 1
			expect(#Logic.byRarity(list, "Common", 2)).to.equal(1)
			expect(#Logic.byRarity(Logic.candidates({ x = { catId = "smoke" } }, nil), "Common", 1)).to.equal(
				0
			)
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

	describe("DragonKeepLogic.pickerLine", function()
		it("shows the Keep on the Castle card only while it is open", function()
			local line = Logic.pickerLine({ stageName = "Drake" }, "castle")
			expect(line ~= nil).to.equal(true)
			expect(line.extraId).to.equal("dragon")
			expect(line.name).to.equal("Dragon Keep")
			expect(line.state).to.equal("Cinder the Drake")
			expect(Logic.pickerLine({}, "castle").state).to.equal("Cinder the Egg")
			expect(Logic.pickerLine({ stageName = "Drake" }, "waterpark")).to.equal(nil)
			expect(Logic.pickerLine(false, "castle")).to.equal(nil)
			expect(Logic.pickerLine(nil, "castle")).to.equal(nil)
		end)
	end)
end
