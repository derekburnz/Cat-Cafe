--!strict
-- Components/RankUpNeeds.steps (#5218, switch rankUpSteps): the needs as steps in rankUpBlocker's order (cats, rarity,
-- coins), with the count of steps left, and each need's plain words.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RankUpNeeds = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RankUpNeeds")
	) :: any

	local function row(kind: string, met: boolean): any
		return {
			kind = kind,
			met = met,
			label = kind,
			short = kind,
			status = "",
			fraction = 0,
			step = kind,
		}
	end

	describe("RankUpNeeds.steps", function()
		it("orders cats, rarity, then coins and counts what is left", function()
			local list, left =
				RankUpNeeds.steps({ row("coins", false), row("cats", true), row("rarity", false) })
			expect(list[1].kind).to.equal("cats")
			expect(list[2].kind).to.equal("rarity")
			expect(list[3].kind).to.equal("coins")
			expect(left).to.equal(2)
		end)

		it("has none left when every need is met", function()
			local _, left = RankUpNeeds.steps({ row("coins", true), row("cats", true) })
			expect(left).to.equal(0)
		end)

		it("is off by default", function()
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags) :: any
			expect(LiveFlags.OFF_BY_DEFAULT.rankUpSteps).to.equal(true)
		end)
	end)
end
