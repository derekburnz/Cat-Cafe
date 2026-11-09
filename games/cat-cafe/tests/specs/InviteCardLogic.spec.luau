--!strict
-- UI/Components/InviteCardLogic.luau: the one invite card with its reward, between 5 and 15 minutes of play (#2797).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local InviteCardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("InviteCardLogic")
	) :: any

	local function view(shown: boolean?): any
		return { cardShown = shown == true, fish = 20, leftToday = 5, cardFrom = 300, cardBy = 900 }
	end

	describe("InviteCardLogic.due", function()
		it("never before cardFrom, even at a good moment", function()
			expect(InviteCardLogic.due(view(), 120, true)).to.equal(false)
			expect(InviteCardLogic.due(view(), 299, true)).to.equal(false)
		end)

		it("at a good moment in the window, else at cardBy", function()
			expect(InviteCardLogic.due(view(), 400, true)).to.equal(true)
			expect(InviteCardLogic.due(view(), 400, false)).to.equal(false)
			expect(InviteCardLogic.due(view(), 900, false)).to.equal(true)
			expect(InviteCardLogic.due(view(), 3000, false)).to.equal(true)
		end)

		it("never once shown, nor from a server without it", function()
			expect(InviteCardLogic.due(view(true), 900, true)).to.equal(false)
			expect(InviteCardLogic.due(nil, 900, true)).to.equal(false)
			expect(InviteCardLogic.due(view(), nil, true)).to.equal(false)
		end)
	end)

	describe("the words and the moments", function()
		it("names the reward", function()
			expect(InviteCardLogic.title(view())).to.equal(
				"Invite a friend: you both get 🐟 20 when they start playing!"
			)
			expect(InviteCardLogic.title({ fish = 0 })).to.equal(
				"Invite a friend to play with you!"
			)
		end)

		it("counts Rare and better as a good moment", function()
			expect(InviteCardLogic.goodRarity("Rare")).to.equal(true)
			expect(InviteCardLogic.goodRarity("Mythical")).to.equal(true)
			expect(InviteCardLogic.goodRarity("Common")).to.equal(false)
			expect(InviteCardLogic.goodRarity(nil)).to.equal(false)
		end)

		it("counts play on from when the server's total came", function()
			expect(InviteCardLogic.played(300, 10, 70)).to.equal(360)
			expect(InviteCardLogic.played(nil, 10, 70)).to.equal(nil)
		end)
	end)
end
