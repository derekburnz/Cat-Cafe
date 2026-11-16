--!strict
-- Toys.luau (#4061, spec 1.3): the Ticket Booth's two held toys, who owns them, when a use counts and where the
-- Water Squirter's splash lands.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Remotes = require(Shared.Remotes)
	local TicketBooth = require(Shared.TicketBooth)
	local Toys = require(Shared.Toys)

	local MONDAY = 1794787200

	describe("the toys", function()
		it(
			"are the Water Squirter and the Pool Noodle, each a once-only 2,000 ticket booth prize",
			function()
				expect(#Toys.LIST).to.equal(2)
				for _, toy in Toys.LIST do
					local prize = TicketBooth.prize(toy.prize)
					expect(prize).to.be.ok()
					local p = prize :: TicketBooth.Prize
					expect(p.toy).to.equal(toy.id)
					expect(p.price).to.equal(2000)
					expect((p.limit :: any).per).to.equal("once")
					expect(p.weekly).to.equal(nil)
					expect(Toys.get(toy.id)).to.equal(toy)
				end
				expect(Toys.get("squirter") ~= nil and Toys.get("noodle") ~= nil).to.equal(true)
				expect(Toys.get("hammer")).to.equal(nil)
				expect(Toys.get(nil)).to.equal(nil)
			end
		)

		it("stay off the weekly shelf, so this week's four cards do not move", function()
			for _, prize in TicketBooth.WEEKLY do
				expect(prize.toy).to.equal(nil)
			end
		end)

		it("have their three remotes", function()
			expect(table.find(Remotes.ClientToServer, "HoldToy")).to.be.ok()
			expect(table.find(Remotes.ClientToServer, "UseToy")).to.be.ok()
			expect(table.find(Remotes.ServerToClient, "ToyUsed")).to.be.ok()
		end)
	end)

	describe("owning", function()
		it("comes from buying the booth prize once, and a second buy is refused", function()
			local save = TicketBooth.fresh()
			save.have = 5000
			expect(#Toys.owned(save)).to.equal(0)
			local prize = TicketBooth.prize("toyNoodle") :: TicketBooth.Prize
			expect(TicketBooth.blocker(save, prize, MONDAY)).to.equal(nil)
			TicketBooth.spend(save, prize, MONDAY)
			expect(save.have).to.equal(3000)
			local owned = Toys.owned(save)
			expect(#owned).to.equal(1)
			expect(owned[1]).to.equal("noodle")
			expect(Toys.owns(save, Toys.get("squirter") :: Toys.Toy)).to.equal(false)
			expect(TicketBooth.blocker(save, prize, MONDAY + 30 * 86400)).to.be.ok()
		end)

		it("shows on the booth view as a toy card that turns Owned", function()
			local save = TicketBooth.fresh()
			save.have = 2000
			local function row(): any
				for _, r in TicketBooth.view(save, MONDAY, true).prizes do
					if r.id == "toySquirter" then
						return r
					end
				end
				return nil
			end
			expect(row().kind).to.equal("toy")
			expect(row().item).to.equal("squirter")
			expect(row().owned).to.equal(false)
			TicketBooth.spend(save, TicketBooth.prize("toySquirter") :: TicketBooth.Prize, MONDAY)
			expect(row().owned).to.equal(true)
		end)
	end)

	describe("the toys switch", function()
		it("is off by default", function()
			local LiveFlags = require(Shared.LiveFlags)
			expect(Toys.FLAG).to.equal("toys")
			expect(LiveFlags.OFF_BY_DEFAULT[Toys.FLAG]).to.equal(true)
			expect(LiveFlags.parse({})[Toys.FLAG]).to.equal(false)
		end)

		it("off, leaves both toy cards out of the booth view and its ready count", function()
			local save = TicketBooth.fresh()
			save.have = 100000
			local off = TicketBooth.view(save, MONDAY)
			local on = TicketBooth.view(save, MONDAY, true)
			for _, r in off.prizes do
				expect(r.kind).never.to.equal("toy")
			end
			expect(#on.prizes - #off.prizes).to.equal(2)
			expect(on.ready - off.ready).to.equal(2)
			expect(TicketBooth.view(save, MONDAY, false).ready).to.equal(off.ready)
		end)
	end)

	describe("a use", function()
		it("needs a toy in hand, no catch, rescue or flight, and the cooldown over", function()
			expect(Toys.useBlocker(nil, nil, false)).to.equal("none")
			expect(Toys.useBlocker("hammer", nil, false)).to.equal("none")
			expect(Toys.useBlocker("noodle", nil, true)).to.equal("busy")
			expect(Toys.useBlocker("noodle", Toys.COOLDOWN - 0.1, false)).to.equal("cooldown")
			expect(Toys.useBlocker("noodle", Toys.COOLDOWN, false)).to.equal(nil)
			expect(Toys.useBlocker("squirter", nil, false)).to.equal(nil)
		end)

		it("aims the Water Squirter at the nearest player in reach, else straight ahead", function()
			local origin = Vector3.new(0, 3, 0)
			local look = Vector3.new(1, 0.5, 0)
			local near = Vector3.new(0, 3, 8)
			local far = Vector3.new(0, 3, Toys.SQUIRT_REACH + 1)
			expect(Toys.target(origin, look, { Vector3.new(20, 3, 0), near })).to.equal(near)
			local ahead = Toys.target(origin, look, { far })
			expect(ahead.X).to.be.near(Toys.SQUIRT_AHEAD, 1e-3)
			expect(ahead.Y).to.be.near(3, 1e-3)
			expect(ahead.Z).to.be.near(0, 1e-3)
			local up = Toys.target(origin, Vector3.new(0, 1, 0), {})
			expect(up.Z).to.be.near(Toys.SQUIRT_AHEAD, 1e-3)
		end)
	end)
end
