--!strict
-- shared/PicnicParty and CampExtras' party rule (#5572): the Picnic Party's basket in the existing picnic slot.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CampExtras = require(Shared.CampExtras)
	local PicnicParty = require(Shared.PicnicParty)
	local LiveFlags = require(Shared.LiveFlags) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CampExtrasLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CampExtrasLogic")
	) :: any

	local DAY = 86400
	local NOON = 20000 * DAY + 43200

	describe("#5707 picnicFlow", function()
		it("is off by default and says what sits down next", function()
			expect(PicnicParty.FLOW_FLAG).to.equal("picnicFlow")
			expect(LiveFlags.defaults().picnicFlow).to.equal(false)
			expect(PicnicParty.nextLine("Common", false)).to.equal(PicnicParty.NEXT_LINE)
			expect(PicnicParty.nextLine("Rare", true)).to.equal(
				"Last picnic cat: a Rare is sitting down on the blanket!"
			)
			expect(PicnicParty.nextLine("Epic", true)).to.equal(
				"Last picnic cat: an Epic is sitting down on the blanket!"
			)
			expect(PicnicParty.nextLine(nil, true)).to.equal(nil)
		end)
	end)

	describe("PicnicParty.start", function()
		it("empties a ready basket and starts its clock", function()
			local slot = { at = NOON - 5000, held = 1 }
			expect(PicnicParty.start(slot, NOON)).to.equal(true)
			expect(slot.held).to.equal(0)
			expect(slot.at).to.equal(NOON)
		end)
		it("starts nothing from an empty basket", function()
			local slot = { at = NOON - 10, held = 0 }
			expect(PicnicParty.start(slot, NOON)).to.equal(false)
			expect(slot.at).to.equal(NOON - 10)
		end)
	end)

	describe("PicnicParty.dayFill", function()
		it("readies an empty basket from an earlier UTC day", function()
			local slot = { at = NOON - DAY, held = 0 }
			expect(PicnicParty.dayFill(slot, NOON)).to.equal(true)
			expect(slot.held).to.equal(1)
		end)
		it("leaves a basket emptied today alone", function()
			local slot = { at = NOON - 60, held = 0 }
			expect(PicnicParty.dayFill(slot, NOON)).to.equal(false)
			expect(slot.held).to.equal(0)
		end)
	end)

	describe("CampExtras with the party", function()
		it("is ready the moment the Park opens, then every 20 minutes, holding one", function()
			local save = CampExtras.fresh(NOON)
			CampExtras.settle(save, 2, NOON, false, true)
			expect(save.picnic.held).to.equal(1)
			expect(PicnicParty.start(save.picnic, NOON)).to.equal(true)
			CampExtras.settle(save, 2, NOON + PicnicParty.EVERY - 1, false, true)
			expect(save.picnic.held).to.equal(0)
			CampExtras.settle(save, 2, NOON + PicnicParty.EVERY, false, true)
			expect(save.picnic.held).to.equal(1)
			CampExtras.settle(save, 2, NOON + 5 * PicnicParty.EVERY, false, true)
			expect(save.picnic.held).to.equal(1)
		end)
		it("views as a party with no treats and its next time while empty", function()
			local save = CampExtras.fresh(NOON)
			CampExtras.settle(save, 2, NOON, false, true)
			PicnicParty.start(save.picnic, NOON)
			local view = CampExtras.view(save, 2, NOON + 60, nil, nil, false, true)
			expect(view.picnic.party).to.equal(true)
			expect(view.picnic.treats).to.equal(nil)
			expect(view.picnic.nextAt).to.equal(NOON + PicnicParty.EVERY)
		end)
		it("keeps the slot an older server reads: only at and held", function()
			local save = CampExtras.fresh(NOON)
			CampExtras.settle(save, 2, NOON, false, true)
			local keys = {}
			for key in save.picnic :: any do
				table.insert(keys, key)
			end
			table.sort(keys)
			expect(table.concat(keys, ",")).to.equal("at,held")
		end)
	end)

	describe("the party's lines", function()
		it(
			"reads Picnic ready on the cannon row and leaves the station line to its sign",
			function()
				local save = CampExtras.fresh(NOON)
				CampExtras.settle(save, 2, NOON, false, true)
				local view = CampExtras.view(save, 2, NOON, nil, nil, false, true)
				local line, bang = CampExtras.pickerLine(view, "park", NOON)
				expect(line).to.equal("Picnic ready !")
				expect(bang).to.equal(true)
				local _, action = CampExtras.promptText("picnic", view.picnic, NOON)
				expect(action).to.equal("")
			end
		)
		it("reads the wait on the cannon row while the basket is empty", function()
			local save = CampExtras.fresh(NOON)
			CampExtras.settle(save, 2, NOON, false, true)
			PicnicParty.start(save.picnic, NOON)
			local view = CampExtras.view(save, 2, NOON + 60, nil, nil, false, true)
			local line, bang = CampExtras.pickerLine(view, "park", NOON + 60)
			expect(line).to.equal("Next picnic in " .. CampExtras.waitText(PicnicParty.EVERY - 60))
			expect(bang).to.equal(false)
		end)
		it(
			"shows no station bubble over a party basket, so its sign is the only countdown",
			function()
				local save = CampExtras.fresh(NOON)
				CampExtras.settle(save, 2, NOON, false, true)
				local view = CampExtras.view(save, 2, NOON, nil, nil, false, true)
				expect(CampExtrasLogic.bubble(view, "picnic", NOON)).to.equal(nil)
				local plain = CampExtras.view(save, 2, NOON, nil, nil, false, false)
				expect(CampExtrasLogic.bubble(plain, "picnic", NOON)).never.to.equal(nil)
			end
		)
	end)
end
