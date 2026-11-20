--!strict
-- shared/MutationBoost.luau: twice the wild strays' gold and rainbow coats (#5493, mutationBoost).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local MutationBoost = require(Shared:WaitForChild("MutationBoost")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Config = require(Shared:WaitForChild("Config")) :: any

	describe("MutationBoost", function()
		it("is off by default and listed", function()
			expect(LiveFlags.OFF_BY_DEFAULT.mutationBoost).to.equal(true)
			expect(table.find(LiveFlags.KEYS, "mutationBoost") ~= nil).to.equal(true)
		end)

		it("doubles a wild stray's coat chances only with the switch on", function()
			expect(MutationBoost.scale(false)).to.equal(1)
			expect(MutationBoost.scale(true)).to.equal(2)
			expect(MutationBoost.gold()).to.equal(Config.GoldChanceNet) -- the switch is off here
			expect(MutationBoost.rainbow()).to.equal(Config.RainbowChanceNet)
		end)
	end)
end
