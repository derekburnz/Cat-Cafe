--!strict
-- Controllers/CafeOrders (F90, cats-make-orders.md section 2) without any station cats: what a customer orders by its
-- cafe's Tier, the rich customer's newest dish on the gold plate, and a dish that goes on the table as the customer
-- sits, with the heart, when no Barista works there.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CafeOrders =
		require(Client:WaitForChild("Controllers"):WaitForChild("CafeOrders")) :: any

	-- Stand-ins for a plot and its customers: attributes only, no Cats folder (so no Barista or Waiter works there)
	-- and no table, so nothing is placed in the world. `own` is true throughout: the device's effects tier is
	-- asked only for another player's cafe.
	local function fake(attributes: { [string]: any }?): any
		local self: any = { attributes = attributes or {} }
		function self.GetAttribute(this: any, name: string): any
			return this.attributes[name]
		end
		function self.SetAttribute(this: any, name: string, value: any)
			this.attributes[name] = value
		end
		function self.FindFirstChild(_this: any, _name: string): any
			return nil
		end
		return self
	end

	local function cafe(tier: number): any
		return fake({ Tier = tier })
	end

	local function place(): { [string]: any }
		return { seat = { Position = "seat" }, route = {}, tableModel = nil, dishAt = nil }
	end

	it("orders only what the cafe's Tier has opened", function()
		for _, tier in { 1, 3, 5 } do
			local open: { [string]: boolean } = {}
			for _, item in Catalog.menuFor(tier) do
				open[item.id] = true
			end
			local plot = cafe(tier)
			for _ = 1, 30 do
				local customer = fake()
				local ticket = CafeOrders.order(plot, customer, place(), false, true)
				local order = customer:GetAttribute("Order")
				expect(open[order :: string]).to.equal(true)
				expect(ticket.item.id).to.equal(order)
				expect(ticket.gold).to.equal(false)
				CafeOrders.left(ticket)
			end
		end
	end)

	it("gives the rich customer the newest dish on the gold plate", function()
		local customer = fake()
		local ticket = CafeOrders.order(cafe(5), customer, place(), true, true)
		expect(customer:GetAttribute("Order")).to.equal("rainbow_cake")
		expect(ticket.gold).to.equal(true)
		CafeOrders.left(ticket)
	end)

	it("with no Barista, serves the dish on the table as the customer sits and clears it as it leaves", function()
		local customer = fake()
		local ticket = CafeOrders.order(cafe(2), customer, place(), false, true)
		expect(ticket.state).to.equal("table")
		expect(ticket.handOver).to.equal(false)
		local seated = fake()
		CafeOrders.seated(ticket, seated)
		expect(seated:GetAttribute("Order")).to.equal(ticket.item.id)
		expect(seated:GetAttribute("Served")).to.equal(true)
		expect(ticket.state).to.equal("served")
		CafeOrders.left(ticket)
		expect(ticket.left).to.equal(true)
		expect(ticket.state).to.equal("served")
	end)

	it("drops an order whose customer leaves before it sits", function()
		local ticket = CafeOrders.order(cafe(1), fake(), place(), false, true)
		CafeOrders.left(ticket)
		expect(ticket.state).to.equal("gone")
		expect(ticket.dish).to.equal(nil)
	end)
end
