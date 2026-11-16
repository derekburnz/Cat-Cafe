--!strict
-- shared/Journeys.luau: the Roblox Journeys' names and how our checked events map onto their nodes (#4544).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Journeys = require(Shared:WaitForChild("Journeys")) :: any
	local StoreFunnel = require(Shared:WaitForChild("StoreFunnel")) :: any

	local function inConfig(journey: string, node: string): boolean
		for _, stage in Journeys.CONFIG[journey] do
			if table.find(stage, node) ~= nil then
				return true
			end
		end
		return false
	end

	describe("Journeys.CONFIG", function()
		it("keeps Roblox's limits: 2 to 10 stages, 1 to 10 nodes, plain names up to 50", function()
			for journey, stages in Journeys.CONFIG do
				expect(#journey <= 50).to.equal(true)
				expect(string.match(journey, "^[%w%.%-][%w%.%-_]*$") ~= nil).to.equal(true)
				expect(#stages >= 2 and #stages <= 10).to.equal(true)
				for _, stage in stages do
					expect(#stage >= 1 and #stage <= 10).to.equal(true)
					local seen: { [string]: boolean } = {}
					for _, node in stage do
						expect(#node >= 1 and #node <= 50).to.equal(true)
						expect(string.match(node, "^%a%w*$") ~= nil).to.equal(true)
						expect(seen[node]).to.equal(nil)
						seen[node] = true
					end
				end
			end
		end)

		it("holds every node the code can log", function()
			for _, node in Journeys.StoreNodes do
				expect(inConfig(Journeys.STORE, node)).to.equal(true)
			end
			for _, node in Journeys.TradeNodes do
				expect(inConfig(Journeys.TRADE, node)).to.equal(true)
			end
			for _, node in Journeys.AskNodes do
				expect(inConfig(Journeys.EVENT, node)).to.equal(true)
			end
			for _, node in Journeys.AreaNodes do
				expect(inConfig(Journeys.AREA, node)).to.equal(true)
			end
			for index = 1, 3 do
				for _, act in Journeys.ACTS do
					local node = Journeys.actNode(index, act)
					expect(table.find(Journeys.CONFIG[Journeys.FIRST][index], node) ~= nil).to.equal(
						true
					)
				end
			end
			for _, node in Journeys.FirstEnds do
				expect(table.find(Journeys.CONFIG[Journeys.FIRST][4], node) ~= nil).to.equal(true)
			end
		end)
	end)

	describe("Journeys.storeNode", function()
		it("names the open by every Store source, with the Tier", function()
			for _, source in StoreFunnel.SOURCES do
				local node, fields = Journeys.storeNode("opened", { source, "t2", "organic" })
				expect(inConfig(Journeys.STORE, node)).to.equal(true)
				expect(fields[1]).to.equal("t2")
			end
			expect((Journeys.storeNode("opened", { "hud_tile", "t1" }))).to.equal("OpenedFromHud")
			expect((Journeys.storeNode("opened", { "sign", "t1" }))).to.equal("OpenedOther")
		end)

		it("maps the tab, the buy and how the prompt closed", function()
			local node, fields = Journeys.storeNode("tab_viewed", { "passes", "picked" })
			expect(node).to.equal("ViewedTab")
			expect(fields[1]).to.equal("passes")
			node, fields = Journeys.storeNode("buy_pressed", { "vip", "12" })
			expect(node).to.equal("PressedBuy")
			expect(fields[1]).to.equal("na")
			expect(fields[2]).to.equal("vip")
			node, fields = Journeys.storeNode("prompt_closed", { "vip", "bought" })
			expect(node).to.equal("Bought")
			expect(fields[2]).to.equal("vip")
			expect((Journeys.storeNode("prompt_closed", { "vip", "cancelled" }))).to.equal(
				"Cancelled"
			)
		end)

		it("has no node for completed or an unknown step", function()
			expect((Journeys.storeNode("completed", { "vip" }))).to.equal(nil)
			expect((Journeys.storeNode("nope", {}))).to.equal(nil)
		end)
	end)

	describe("Journeys.actNode", function()
		it("names the first three acts by their place", function()
			expect(Journeys.actNode(1, "catch")).to.equal("FirstCatch")
			expect(Journeys.actNode(2, "store")).to.equal("SecondStore")
			expect(Journeys.actNode(3, "menu")).to.equal("ThirdMenu")
		end)

		it("has no node past the third act or for an unknown act", function()
			expect(Journeys.actNode(4, "catch")).to.equal(nil)
			expect(Journeys.actNode(0, "catch")).to.equal(nil)
			expect(Journeys.actNode(1, "nap")).to.equal(nil)
		end)
	end)

	describe("Journeys.askNode and tradeMix", function()
		it("maps every ask kind and nothing else", function()
			expect(Journeys.askNode("shown")).to.equal("SawAsk")
			expect(Journeys.askNode("remind")).to.equal("PressedInterested")
			expect(Journeys.askNode("not_going")).to.equal("RobloxNotGoing")
			expect(Journeys.askNode("nope")).to.equal(nil)
		end)

		it("words what moved in a trade", function()
			expect(Journeys.tradeMix(2, 0, 0, 0)).to.equal("cats")
			expect(Journeys.tradeMix(1, 3, 0, 50)).to.equal("cats+decor+fish")
			expect(Journeys.tradeMix(0, 0, 2, 0)).to.equal("crates")
			expect(Journeys.tradeMix(0, 0, 0, 0)).to.equal("nothing")
		end)
	end)
end
