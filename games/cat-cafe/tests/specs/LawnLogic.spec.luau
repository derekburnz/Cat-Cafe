--!strict
-- UI/Components/LawnLogic.luau: the Lawn chip's cards and total (#1283), the old Front lawn buttons and counts (F91,
-- front-lawn.md section 3), on shared/Lawn's rules and Catalog.lawn's prices.
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

	describe("LawnLogic.cardAction (#1751)", function()
		local function card(state: any, id: string): any
			for _, each in LawnLogic.cards(state) do
				if each.id == id then
					return each
				end
			end
			error("no card " .. id)
		end
		it("reads Remove for an out piece and Use for a stored one", function()
			local state = player(3, 0, { "garden_bench", "lamp_post" }, { big1 = "garden_bench" })
			local out = LawnLogic.cardAction(state, card(state, "garden_bench"))
			expect(out.text).to.equal("Remove")
			expect(out.spotId).to.equal("big1")
			expect(out.pieceId).to.equal("")
			local stored = LawnLogic.cardAction(state, card(state, "lamp_post"))
			expect(stored.text).to.equal("Use")
			expect(stored.pieceId).to.equal("lamp_post")
			expect(stored.spotId ~= nil).to.equal(true)
		end)
		it("reads Remove for the path in use and Use for another owned one", function()
			local state = player(3, 0, { "red_brick", "white_picket" }, {}, { path = "red_brick" })
			local path = LawnLogic.cardAction(state, card(state, "red_brick"))
			expect(path.text).to.equal("Remove")
			expect(path.styleKind).to.equal("path")
			expect(path.styleId).to.equal("")
			local fence = LawnLogic.cardAction(state, card(state, "white_picket"))
			expect(fence.text).to.equal("Use")
			expect(fence.styleKind).to.equal("fence")
			expect(fence.styleId).to.equal("white_picket")
		end)
	end)

	describe("LawnLogic.pieceAction", function()
		it("sells an open piece at its price, grey when the coins fall short", function()
			-- #1200: the Tulip Bed is a Common, 10,000 at the Garden Nursery; open from Tier 2 since #1382
			local action = LawnLogic.pieceAction(player(2, 10000), piece("tulip_bed"))
			expect(action.mode).to.equal("buy")
			expect(action.enabled).to.equal(true)
			expect(LawnLogic.pieceAction(player(2, 9999), piece("tulip_bed")).enabled).to.equal(
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
			local state = player(2, 10000, { "red_brick" }) -- the Commons open at Tier 2 since #1382
			expect(LawnLogic.styleAction(state, style("red_brick")).mode).to.equal("use")
			local buy = LawnLogic.styleAction(state, style("white_picket"))
			expect(buy.mode).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			expect(LawnLogic.styleAction(state, style("paw_print_path")).text).to.equal("Tier 3")
			expect(LawnLogic.styleAction(player(1, 10000), style("white_picket")).text).to.equal(
				"Tier 2"
			)
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
			"lists the piece here, then the other owned pieces of the size, and sells nothing (#1200)",
			function()
				local state = player(
					1,
					1e9,
					{ "tulip_bed", "mailbox" },
					{ small1 = "tulip_bed", small2 = "mailbox" }
				)
				local choices = LawnLogic.spotChoices(state, "small1")
				expect(#choices).to.equal(2)
				expect(choices[1].piece.id).to.equal("tulip_bed")
				expect(choices[1].action.mode).to.equal("here")
				expect(choices[2].piece.id).to.equal("mailbox")
				expect(choices[2].action.mode).to.equal("place")
				expect(choices[2].action.text).to.equal("Move here")
				for _, choice in choices do
					expect(choice.owned).to.equal(true)
				end
				expect(#LawnLogic.spotChoices(player(1, 1e9), "small1")).to.equal(0)
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

	describe("LawnLogic Garden Nursery (#1200)", function()
		it("lists every piece, and every path and fence but the free Grey Slabs", function()
			expect(#LawnLogic.stallRows("pieces")).to.equal(#LawnLogic.pieces())
			for _, kind in { "path", "fence" } do
				for _, row in LawnLogic.stallRows(kind :: any) do
					expect(row.price > 0).to.equal(true)
					expect(row.detail).to.equal(if kind == "path" then "Path" else "Fence")
				end
			end
			for _, row in LawnLogic.stallRows("path") do
				expect(row.id ~= "grey_slabs").to.equal(true)
			end
		end)

		it("reads Buy with the price, Owned, or the tier that opens it", function()
			local rows = LawnLogic.stallRows("pieces")
			local tulip, bench
			for _, row in rows do
				if row.id == "tulip_bed" then
					tulip = row
				elseif row.id == "garden_bench" then
					bench = row
				end
			end
			local buy = LawnLogic.stallAction(player(2, tulip.price), tulip)
			expect(buy.mode).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			expect(buy.style).to.equal("gold")
			expect(LawnLogic.stallAction(player(2, tulip.price - 1), tulip).enabled).to.equal(false)
			local owned = LawnLogic.stallAction(player(2, 0, { "tulip_bed" }), tulip)
			expect(owned.mode).to.equal("owned")
			expect(owned.text).to.equal("Owned")
			local locked = LawnLogic.stallAction(player(1, 1e12), bench)
			expect(locked.mode).to.equal("locked")
			expect(locked.text).to.equal("Opens at Tier 2")
		end)

		it("points below Tier 3 at the Yard Sale's tier and everyone else at the Yard Sale (#1760)", function()
			expect(LawnLogic.nurseryNote(player(1, 0))).to.equal("Sold at the Yard Sale (Tier 3)")
			expect(LawnLogic.nurseryNote(player(2, 0))).to.equal("Sold at the Yard Sale (Tier 3)")
			expect(LawnLogic.nurseryNote(player(3, 0))).to.equal("Sold at the Yard Sale, Neighbourhood camp")
			expect(string.find(LawnLogic.NURSERY_LINE, "Nursery", 1, true)).never.to.be.ok()
		end)
	end)

	describe("LawnLogic.cards (#1283)", function()
		it("lists each owned piece, path and fence, highest rarity first, then out first (#1751)", function()
			local state = player(
				3,
				0,
				{ "tulip_bed", "potted_cat_topiary", "mailbox", "red_brick", "stepping_stones" },
				{ small1 = "tulip_bed" },
				{ path = "red_brick" }
			)
			local cards = LawnLogic.cards(state)
			local ids = {}
			for _, card in cards do
				table.insert(ids, card.id)
			end
			-- the three Uncommons (stored) first, then the Commons: Red Brick and the Tulip Bed (both out, by name)
			expect(#cards).to.equal(5)
			for index = 2, #cards do
				expect(cards[index - 1].bonus >= cards[index].bonus).to.equal(true)
			end
			expect(cards[1].out).to.equal(false)
			expect(cards[3].out).to.equal(false)
			expect(cards[4].out).to.equal(true)
			expect(cards[5].out).to.equal(true)
			expect(table.concat(ids, ",", 4, 5)).to.equal("red_brick,tulip_bed")
		end)

		it("leaves out what is not owned and the free Grey Slabs", function()
			local cards = LawnLogic.cards(player(3, 0, { "tulip_bed" }))
			expect(#cards).to.equal(1)
			expect(cards[1].id).to.equal("tulip_bed")
			expect(cards[1].kind).to.equal("piece")
			expect(cards[1].out).to.equal(false)
			expect(#LawnLogic.cards(player(1, 0, nil))).to.equal(0)
		end)

		it("tags paths and fences on the bonus line", function()
			local path = LawnLogic.cards(player(3, 0, { "red_brick" }))[1]
			expect(LawnLogic.cardLine(path)).to.equal("Path · +1% money")
			expect(LawnLogic.cardLine({ kind = "fence", bonus = 0.03 })).to.equal(
				"Fence · +3% money"
			)
			expect(LawnLogic.cardLine({ kind = "piece", bonus = 0.015 })).to.equal("+1.5% money")
		end)
	end)

	describe("LawnLogic.total (#1283)", function()
		it("counts what is out and sums its bonus, as the Money boosts row does", function()
			local state = player(
				3,
				0,
				{ "tulip_bed", "potted_cat_topiary", "red_brick" },
				{ small1 = "tulip_bed", small2 = "potted_cat_topiary" },
				{ path = "red_brick" }
			)
			expect(LawnLogic.total(state)).to.equal("Lawn: 3 out, +3.5% money")
			expect(LawnLogic.total(player(3, 0, { "tulip_bed" }))).to.equal("Lawn: nothing out yet")
		end)
	end)

	-- QA edges (front-lawn.md section 3, against LawnService's handlers): a seeded player presses the buttons the Front
	-- lawn tab and the edit view's picker show, ranks up and gains or spends coins. After every step each button shown
	-- is checked: one the UI offers is a call LawnService takes that does what the button says, and a greyed one is
	-- a call it refuses or one that changes nothing, so the UI never offers what the server says no to.
	describe("LawnLogic edges (QA)", function()
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local Catalog = require(Shared:WaitForChild("Catalog")) :: any
		local Lawn = require(Shared:WaitForChild("Lawn")) :: any

		local function fail(pattern: string, ...: any)
			error(string.format(pattern, ...), 2)
		end

		local function clone(state: any): any
			return {
				tier = state.tier,
				money = state.money,
				lawnOwned = table.clone(state.lawnOwned),
				lawn = table.clone(state.lawn),
				lawnStyles = table.clone(state.lawnStyles),
			}
		end

		local function snapshot(state: any): string
			local parts: { string } = {}
			for _, def in LawnLogic.pieces() do
				table.insert(parts, def.id .. "=" .. tostring(state.lawnOwned[def.id]))
			end
			for _, def in Catalog.lawnStyles do
				table.insert(parts, def.id .. "=" .. tostring(state.lawnOwned[def.id]))
			end
			for _, spot in LawnLogic.SPOTS do
				table.insert(parts, spot.id .. ":" .. tostring(state.lawn[spot.id]))
			end
			table.insert(
				parts,
				tostring(state.lawnStyles.path) .. "/" .. tostring(state.lawnStyles.fence)
			)
			return table.concat(parts, " ") .. " $" .. tostring(state.money)
		end

		-- LawnService's three handlers as they run past Guard and WorldBuilder.lawnLive, on the state: "" or nil is
		-- no id, and SetLawnStyle drops a nil id unread. Returns the refusal, or nil when the call went through.
		local function server(state: any, remote: string, a: string?, b: string?): string?
			local optional = function(raw: string?): string?
				return if raw == "" then nil else raw
			end
			if remote == "BuyLawn" then
				local id, spotId = assert(a), optional(b)
				local blocker = Lawn.buyBlocker(state, id)
				if blocker ~= nil then
					return blocker
				end
				local piece, style = Catalog.getLawn(id), Catalog.getLawnStyle(id)
				local price = if piece ~= nil then piece.price else style.price
				if state.money < price then
					return "Not enough coins"
				end
				state.money -= price
				state.lawnOwned[id] = true
				if style ~= nil then
					Lawn.setStyle(state, style.kind, id)
				else
					local target: string? = Lawn.firstFreeSpot(state, piece.spot)
					if spotId ~= nil and Lawn.placeBlocker(state, spotId, id) == nil then
						target = spotId
					end
					if target ~= nil then
						Lawn.place(state, target, id)
					end
				end
				return nil
			elseif remote == "SetLawnSpot" then
				local spotId, pieceId = assert(a), optional(b)
				local blocker = Lawn.placeBlocker(state, spotId, pieceId)
				if blocker ~= nil then
					return blocker
				end
				Lawn.place(state, spotId, pieceId)
				return nil
			end
			if b == nil then
				return "dropped"
			end
			local blocker = Lawn.styleBlocker(state, assert(a), optional(b))
			if blocker ~= nil then
				return blocker
			end
			Lawn.setStyle(state, a, optional(b))
			return nil
		end

		-- Every button shown for the state and the call a press sends (Screens/LawnTab's and Screens/LawnEdit's
		-- handlers): the tab's piece and style cards, then for each open spot (a closed ring opens no picker) the
		-- picker's cards and Clear spot while a piece stands there.
		local function buttons(state: any): { any }
			local out: { any } = {}
			for _, piece in LawnLogic.pieces() do
				local action = LawnLogic.pieceAction(state, piece)
				local call: { any }? = if action.mode == "buy"
					then { "BuyLawn", piece.id, nil }
					elseif action.mode == "place" then {
						"SetLawnSpot",
						action.spotId,
						piece.id,
					}
					elseif action.mode == "away" then { "SetLawnSpot", action.spotId, "" }
					else nil
				table.insert(
					out,
					{ where = "tab", id = piece.id, piece = piece, action = action, call = call }
				)
			end
			for _, kind in { "path", "fence" } do
				for _, style in LawnLogic.styles(kind) do
					local action = LawnLogic.styleAction(state, style)
					local call: { any }? = if action.mode == "buy"
						then { "BuyLawn", style.id, nil }
						elseif action.mode == "use" then { "SetLawnStyle", kind, style.id }
						elseif action.mode == "takeDown" then { "SetLawnStyle", "fence", "" }
						else nil
					table.insert(out, {
						where = "tab",
						id = style.id,
						style = style,
						action = action,
						call = call,
					})
				end
			end
			for _, spot in LawnLogic.SPOTS do
				if state.tier < spot.tier then
					continue
				end
				for _, choice in LawnLogic.spotChoices(state, spot.id) do
					local action, piece = choice.action, choice.piece
					local call: { any }? = if action.mode == "buy"
						then { "BuyLawn", piece.id, spot.id }
						elseif action.mode == "place" then { "SetLawnSpot", spot.id, piece.id }
						else nil
					table.insert(out, {
						where = spot.id,
						id = piece.id,
						piece = piece,
						owned = choice.owned,
						action = action,
						call = call,
					})
				end
				if state.lawn[spot.id] ~= nil then
					local clear =
						{ mode = "clear", text = "Clear spot", style = "ghost", enabled = true }
					table.insert(
						out,
						{ where = spot.id, action = clear, call = { "SetLawnSpot", spot.id, "" } }
					)
				end
			end
			return out
		end

		-- A lawn the server could hold: each piece owned, on one spot open at the tier and of its size.
		local function checkLawn(state: any, label: string)
			local seen: { [string]: boolean } = {}
			for spotId, pieceId in state.lawn do
				local spot, piece = Lawn.getSpot(spotId), Catalog.getLawn(pieceId)
				if
					spot == nil
					or piece == nil
					or seen[pieceId]
					or spot.tier > state.tier
					or piece.spot ~= spot.size
				then
					fail("%s leaves %s on %s", label, tostring(pieceId), tostring(spotId))
				end
				if not Lawn.owns(state, pieceId) then
					fail("%s leaves %s on %s without owning it", label, pieceId, spotId)
				end
				seen[pieceId] = true
			end
		end

		local function check(state: any, button: any, label: string)
			local action = button.action
			local name =
				string.format("%s: %s %s %s", label, button.where, tostring(button.id), action.mode)
			local def: any = button.piece or button.style
			local after = clone(state)
			if not action.enabled then
				if action.mode == "locked" then
					if action.text ~= "Tier " .. def.tier or state.tier >= def.tier then
						fail("%s says %s at Tier %d", name, action.text, state.tier)
					end
					local refusal = server(after, "BuyLawn", def.id, nil)
					if
						refusal == nil
						or string.find(refusal, "opens at Tier " .. def.tier, 1, true) == nil
					then
						fail("%s: the server says %s", name, tostring(refusal))
					end
				elseif action.mode == "buy" then
					if
						state.money >= def.price
						or server(after, "BuyLawn", def.id, nil) ~= "Not enough coins"
					then
						fail("%s is greyed with $%d for a $%d piece", name, state.money, def.price)
					end
				elseif action.mode == "full" then
					local mine = Lawn.owns(state, def.id) and Lawn.spotOf(state, def.id) == nil
					if not mine or Lawn.firstFreeSpot(state, def.spot) ~= nil then
						fail("%s with an open %s spot free", name, def.spot)
					end
				elseif action.mode == "inUse" then
					if LawnLogic.inUse(state, def.kind) ~= def.id or def.kind ~= "path" then
						fail(
							"%s but %s is in use",
							name,
							tostring(LawnLogic.inUse(state, def.kind))
						)
					end
					server(after, "SetLawnStyle", def.kind, def.id)
				elseif action.mode == "here" then
					if state.lawn[button.where] ~= def.id then
						fail("%s but %s stands there", name, tostring(state.lawn[button.where]))
					end
					server(after, "SetLawnSpot", button.where, def.id)
				else
					fail("%s is greyed with no reason", name)
				end
				if snapshot(after) ~= snapshot(state) then
					fail("%s changes the lawn when pressed anyway", name)
				end
				return
			end
			local call = button.call
			if call == nil then
				fail("%s is lit but sends nothing", name)
				return
			end
			local refusal = server(after, call[1], call[2], call[3])
			if refusal ~= nil then
				fail("%s: the server refuses: %s", name, refusal)
			end
			checkLawn(after, name)
			local mode = action.mode
			if mode == "buy" then
				local price = def.price
				if not after.lawnOwned[def.id] or after.money ~= state.money - price then
					fail("%s does not buy it for $%d", name, price)
				end
				if button.style ~= nil then
					if LawnLogic.inUse(after, def.kind) ~= def.id then
						fail("%s does not put it in use", name)
					end
				elseif button.where == "tab" then
					local free = Lawn.firstFreeSpot(state, def.spot)
					if Lawn.spotOf(after, def.id) ~= free then
						fail(
							"%s lands on %s with %s free",
							name,
							tostring(Lawn.spotOf(after, def.id)),
							tostring(free)
						)
					end
				elseif after.lawn[button.where] ~= def.id then
					fail("%s does not put it on %s", name, button.where)
				end
			elseif mode == "place" then
				local spotId = if button.where == "tab" then action.spotId else button.where
				if action.spotId ~= spotId or after.lawn[spotId] ~= def.id then
					fail("%s does not put it on %s", name, tostring(spotId))
				end
				local from = Lawn.spotOf(state, def.id)
				local moving = action.text == "Move here"
				if
					(from ~= nil) ~= moving
					or (button.where == "tab" and (from ~= nil or state.lawn[spotId] ~= nil))
				then
					fail(
						"%s says %q, from %s onto %s's %s",
						name,
						action.text,
						tostring(from),
						spotId,
						tostring(state.lawn[spotId])
					)
				end
			elseif mode == "away" or mode == "clear" then
				local spotId = action.spotId or button.where
				if
					state.lawn[spotId] == nil
					or (button.id ~= nil and state.lawn[spotId] ~= button.id)
				then
					fail(
						"%s on %s, which holds %s",
						name,
						tostring(spotId),
						tostring(state.lawn[spotId])
					)
				end
				if after.lawn[spotId] ~= nil or not Lawn.owns(after, state.lawn[spotId]) then
					fail("%s does not put %s away", name, state.lawn[spotId])
				end
			elseif mode == "use" then
				if
					Lawn.owns(state, def.id) == false
					or LawnLogic.inUse(after, def.kind) ~= def.id
				then
					fail("%s does not put it in use", name)
				end
			elseif mode == "takeDown" then
				if
					def.kind ~= "fence"
					or state.lawnStyles.fence ~= def.id
					or after.lawnStyles.fence ~= nil
				then
					fail("%s does not take the fence down", name)
				end
				if after.lawnStyles.path ~= state.lawnStyles.path then
					fail("%s changes the path", name)
				end
			else
				fail("%s is lit with no rule", name)
			end
		end

		-- Each piece and style has one card in the tab, and each open spot's picker lists every piece of its size
		-- once: the one here, the player's others, the shop's, then later tiers.
		local function checkLists(state: any, list: { any }, label: string)
			local tab: { [string]: number } = {}
			local picks: { [string]: { [string]: number } } = {}
			local last: { [string]: number } = {}
			local rank = { here = 1, place = 2, buy = 3, locked = 4 }
			for _, button in list do
				if button.id == nil then
					continue
				end
				if button.where == "tab" then
					tab[button.id] = (tab[button.id] or 0) + 1
					continue
				end
				local spot = Lawn.getSpot(button.where)
				local into = picks[button.where] or {}
				picks[button.where] = into
				into[button.id] = (into[button.id] or 0) + 1
				local step = rank[button.action.mode]
				if
					button.piece.spot ~= spot.size
					or step == nil
					or step < (last[button.where] or 0)
				then
					fail(
						"%s: %s's picker has %s (%s) out of place",
						label,
						button.where,
						button.id,
						button.action.mode
					)
				end
				last[button.where] = step
				local action = button.action
				if action.mode ~= "locked" and action.spotId ~= button.where then
					fail(
						"%s: %s's %s card names %s",
						label,
						button.where,
						button.id,
						tostring(action.spotId)
					)
				end
				if button.owned ~= Lawn.owns(state, button.id) then
					fail(
						"%s: %s's picker calls %s owned %s",
						label,
						button.where,
						button.id,
						tostring(button.owned)
					)
				end
			end
			for _, def in LawnLogic.pieces() do
				if tab[def.id] ~= 1 then
					fail("%s: the tab shows %s %d times", label, def.id, tab[def.id] or 0)
				end
				for _, spot in LawnLogic.SPOTS do
					-- #1200: the picker lists only owned pieces (the Garden Nursery sells the rest)
					local want = if state.tier >= spot.tier
							and def.spot == spot.size
							and Lawn.owns(state, def.id)
						then 1
						else nil
					if (picks[spot.id] or {})[def.id] ~= want then
						fail(
							"%s: %s's picker shows %s %s times",
							label,
							spot.id,
							def.id,
							tostring((picks[spot.id] or {})[def.id])
						)
					end
				end
			end
			for _, def in Catalog.lawnStyles do
				if tab[def.id] ~= 1 then
					fail("%s: the tab shows %s %d times", label, def.id, tab[def.id] or 0)
				end
			end
			local used, open = LawnLogic.counts(state)
			local wantUsed, wantOpen = 0, 0
			for _, spot in LawnLogic.SPOTS do
				if state.tier >= spot.tier then
					wantOpen += 1
					wantUsed += if state.lawn[spot.id] ~= nil then 1 else 0
				end
			end
			if used ~= wantUsed or open ~= wantOpen then
				fail(
					"%s: the strip says %d / %d for %d / %d",
					label,
					used,
					open,
					wantUsed,
					wantOpen
				)
			end
		end

		it(
			"offers only what LawnService takes, and greys only what it refuses or leaves as it is",
			function()
				local random = Random.new(909)
				local pressed = 0
				for run = 1, 20 do
					local state: any = {
						tier = 1,
						money = 0,
						lawnOwned = {},
						lawn = {},
						lawnStyles = Lawn.freshStyles(),
					}
					for step = 1, 80 do
						local label = string.format("run %d step %d", run, step)
						local list = buttons(state)
						checkLists(state, list, label)
						for _, button in list do
							check(state, button, label)
						end
						local roll = random:NextInteger(1, 12)
						if roll == 1 and state.tier < Catalog.maxTier then
							state.tier += 1
							Lawn.grantTierGifts(state)
						elseif roll <= 3 then
							local prices = { 0, 499, 500, 1999, 2000, 99999, 100000, 1e9 }
							state.money = prices[random:NextInteger(1, #prices)]
						else
							local lit: { any } = {}
							for _, button in list do
								if button.action.enabled then
									table.insert(lit, button)
								end
							end
							if #lit > 0 then
								local button = lit[random:NextInteger(1, #lit)]
								server(state, button.call[1], button.call[2], button.call[3])
								pressed += 1
							end
						end
					end
				end
				expect(pressed > 900).to.equal(true)
			end
		)
	end)
end
