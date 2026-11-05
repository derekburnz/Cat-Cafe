--!strict
-- UI/Components/PalsLogic.luau: the pal chip, the pal arrived marker and the Team Rescue pop's words (F92,
-- playing-together.md sections 2, 3 and 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PalsLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PalsLogic")
	) :: any

	local NAMES: { [number]: string } = { [11] = "Sam", [22] = "Alex" }
	local function nameOf(userId: number): string?
		return NAMES[userId]
	end

	describe("PalsLogic.list", function()
		it("keeps whole positive ids once each, in order, and never this player", function()
			local list = PalsLogic.list({ 22, 11, 22, 5, -3, 0, 2.5, "9", 11 }, 5)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal(22)
			expect(list[2]).to.equal(11)
		end)

		it("reads anything that is not a list as no pals", function()
			expect(#PalsLogic.list(nil, 1)).to.equal(0)
			expect(#PalsLogic.list("11", 1)).to.equal(0)
			expect(#PalsLogic.list({}, 1)).to.equal(0)
		end)
	end)

	describe("PalsLogic.chip", function()
		it(
			"says the tips the pals add: 10% with one, 5% more each, at most 20% (#1165, #1347), nothing alone",
			function()
				expect(PalsLogic.chip(0)).to.equal(nil)
				expect(PalsLogic.chip(1)).to.equal("+10% with pals")
				expect(PalsLogic.chip(2)).to.equal("+15% with pals")
				expect(PalsLogic.chip(3)).to.equal("+20% with pals")
				expect(PalsLogic.chip(6)).to.equal("+20% with pals")
			end
		)
	end)

	describe("PalsLogic.faces", function()
		it("shows three headshots and counts the rest", function()
			local shown, more = PalsLogic.faces({ 1, 2, 3, 4, 5 })
			expect(#shown).to.equal(3)
			expect(shown[3]).to.equal(3)
			expect(more).to.equal(2)
			local one, none = PalsLogic.faces({ 7 })
			expect(#one).to.equal(1)
			expect(none).to.equal(0)
		end)

		it("asks Roblox for the headshot picture", function()
			expect(PalsLogic.headshot(11)).to.equal(
				"rbxthumb://type=AvatarHeadShot&id=11&w=48&h=48"
			)
		end)
	end)

	describe("PalsLogic.arrived", function()
		it("names where the pal is, and says nothing when the pal is at the cafe", function()
			expect(PalsLogic.arrived("Sam", "Park")).to.equal("Sam is in the Park")
			expect(PalsLogic.arrived(nil, "Woods")).to.equal("Your pal is in the Woods")
			expect(PalsLogic.arrived("Sam", nil)).to.equal(nil)
		end)
	end)

	describe("PalsLogic.inviteAsk", function()
		it("words the one invite nudge with the pal bonus", function()
			expect(PalsLogic.inviteAsk()).to.equal(
				"Playing with a friend gives you both +10% tips. Invite one?"
			)
		end)
	end)

	describe("PalsLogic.teamRescue", function()
		it("thanks the helper with the tip, and tells the rescuer who helped", function()
			expect(PalsLogic.teamRescue(22, 11, 22, 1240, nameOf)).to.equal(
				"You helped Sam free it! +$1,240"
			)
			expect(PalsLogic.teamRescue(22, 11, 22, 0, nameOf)).to.equal("You helped Sam free it!")
			expect(PalsLogic.teamRescue(11, 11, 22, 0, nameOf)).to.equal("Alex helped you free it!")
		end)

		it("still reads when the other player has left", function()
			expect(PalsLogic.teamRescue(22, 99, 22, 0, nameOf)).to.equal(
				"You helped your pal free it!"
			)
			expect(PalsLogic.teamRescue(11, 11, 99, 0, nameOf)).to.equal(
				"A pal helped you free it!"
			)
		end)
	end)
end
