--!strict
-- UI/Components/LawnLogic.luau: the Front lawn tab's and the edit view's buttons and counts (F91, front-lawn.md
-- section 3), on shared/Lawn's rules and Catalog.lawn's prices.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LawnLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LawnLogic")
	) :: any

	local function piece(id: string): any
		local def = LawnLogic.getPiece(id)
		assert(def, id)
		return def
	end

	local function style(id: string): any
		local def = LawnLogic.getStyle(id)
		assert(def, id)
		return def
	end

	-- a player's state with only what the lawn reads
	local function player(
		tier: number,
		money: number,
		owned: { string }?,
		lawn: { [string]: string }?,
		styles: any?
	): any
		local map = {}
		for _, id in owned or {} do
			map[id] = true
		end
		return {
			tier = tier,
			money = money,
			lawnOwned = map,
			lawn = lawn or {},
			lawnStyles = styles or { path = "grey_slabs" },
		}
	end

	describe("LawnLogic.live", function()
		it("needs the plot's LawnPath and the lawn in the state", function()
			local state = player(1, 0)
			expect(LawnLogic.live(state, "grey_slabs")).to.equal(true)
			expect(LawnLogic.live(state, nil)).to.equal(false)
			expect(LawnLogic.live(state, "")).to.equal(false)
			expect(LawnLogic.live(nil, "grey_slabs")).to.equal(false)
			local unsynced = player(1, 0)
			unsynced.lawnStyles = nil
			expect(LawnLogic.live(unsynced, "grey_slabs")).to.equal(false)
		end)
	end)

	describe("LawnLogic.counts", function()
		it("counts the spots open at the tier and the ones with a piece", function()
			expect(select(2, LawnLogic.counts(player(1, 0)))).to.equal(2)
			expect(select(2, LawnLogic.counts(player(2, 0)))).to.equal(4)
			expect(select(2, LawnLogic.counts(player(3, 0)))).to.equal(6)
			local used, open =
				LawnLogic.counts(player(1, 0, { "tulip_bed" }, { small1 = "tulip_bed" }))
			expect(used).to.equal(1)
			expect(open).to.equal(2)
		end)
	end)

	describe("LawnLogic.pieceAction", function()
		it("sells an open piece at its price, grey when the coins fall short", function()
			local action = LawnLogic.pieceAction(player(1, 500), piece("tulip_bed"))
			expect(action.mode).to.equal("buy")
			expect(action.enabled).to.equal(true)
			expect(LawnLogic.pieceAction(player(1, 499), piece("tulip_bed")).enabled).to.equal(
				false
			)
		end)

		it("names the tier that sells a later piece", function()
			local action = LawnLogic.pieceAction(player(1, 1e9), piece("garden_bench"))
			expect(action.mode).to.equal("locked")
			expect(action.text).to.equal("Tier 2")
			expect(action.enabled).to.equal(false)
		end)

		it(
			"places an owned piece on the first open spot of its size, or says the spots are full",
			function()
				local place =
					LawnLogic.pieceAction(player(1, 0, { "tulip_bed" }), piece("tulip_bed"))
				expect(place.mode).to.equal("place")
				expect(place.spotId).to.equal("small1")
				local full = player(1, 0, { "tulip_bed", "mailbox", "sandwich_board" }, {
					small1 = "mailbox",
					small2 = "sandwich_board",
				})
				expect(LawnLogic.pieceAction(full, piece("tulip_bed")).mode).to.equal("full")
			end
		)

		it("puts away a piece on the lawn from its own spot", function()
			local action = LawnLogic.pieceAction(
				player(1, 0, { "tulip_bed" }, { small2 = "tulip_bed" }),
				piece("tulip_bed")
			)
			expect(action.mode).to.equal("away")
			expect(action.spotId).to.equal("small2")
			expect(action.enabled).to.equal(true)
		end)
	end)

	describe("LawnLogic.styleAction", function()
		it("shows the path in use and lets the fence in use come down", function()
			local state = player(
				1,
				0,
				{ "white_picket" },
				nil,
				{ path = "grey_slabs", fence = "white_picket" }
			)
			expect(LawnLogic.styleAction(state, style("grey_slabs")).mode).to.equal("inUse")
			expect(LawnLogic.styleAction(state, style("white_picket")).mode).to.equal("takeDown")
		end)

		it("offers an owned style, sells an open one and names the tier of a later one", function()
			local state = player(1, 2000, { "red_brick" })
			expect(LawnLogic.styleAction(state, style("red_brick")).mode).to.equal("use")
			local buy = LawnLogic.styleAction(state, style("white_picket"))
			expect(buy.mode).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			expect(LawnLogic.styleAction(state, style("low_hedge")).text).to.equal("Tier 2")
		end)

		it("reads Grey Slabs as owned and in use on a fresh lawn", function()
			local state = player(1, 0)
			expect(LawnLogic.owns(state, "grey_slabs")).to.equal(true)
			expect(LawnLogic.inUse(state, "path")).to.equal("grey_slabs")
			expect(LawnLogic.inUse(state, "fence")).to.equal(nil)
		end)
	end)

	describe("LawnLogic.spotChoices", function()
		it(
			"lists the piece here, the other owned pieces of the size, the shop, then later tiers",
			function()
				local state = player(
					1,
					1000,
					{ "tulip_bed", "mailbox" },
					{ small1 = "tulip_bed", small2 = "mailbox" }
				)
				local choices = LawnLogic.spotChoices(state, "small1")
				expect(choices[1].piece.id).to.equal("tulip_bed")
				expect(choices[1].action.mode).to.equal("here")
				expect(choices[2].piece.id).to.equal("mailbox")
				expect(choices[2].action.mode).to.equal("place")
				expect(choices[2].action.text).to.equal("Move here")
				expect(choices[3].action.mode).to.equal("buy")
				expect(choices[3].action.spotId).to.equal("small1")
				expect(choices[#choices].action.mode).to.equal("locked")
				for _, choice in choices do
					expect(choice.piece.spot).to.equal("small")
				end
			end
		)

		it(
			"offers only big pieces on a big spot, and nothing for a spot that is not one",
			function()
				for _, choice in LawnLogic.spotChoices(player(2, 0), "big1") do
					expect(choice.piece.spot).to.equal("big")
				end
				expect(#LawnLogic.spotChoices(player(2, 0), "nowhere")).to.equal(0)
			end
		)
	end)

	describe("LawnLogic.editDistance", function()
		it("stands back far enough for the lawn's width, within its limits", function()
			local wide = LawnLogic.editDistance(17, 70, 16 / 9)
			expect(wide >= LawnLogic.EDIT_MIN).to.equal(true)
			expect(wide <= LawnLogic.EDIT_MAX).to.equal(true)
			-- the half width plus a stud fits the screen at that distance
			local across = math.tan(math.rad(70) / 2) * (16 / 9) * wide
			expect(across >= 18 - 1e-6).to.equal(true)
			expect(LawnLogic.editDistance(17, 70, 0.6) > LawnLogic.editDistance(17, 70, 2)).to.equal(
				true
			)
			expect(LawnLogic.editDistance(500, 70, 1)).to.equal(LawnLogic.EDIT_MAX)
		end)
	end)
end
