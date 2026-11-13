--!strict
-- shared/SpeedShoes (#3535): the Mystery Market's Speed Shoes, carry speed only, behind the `speedShoes` switch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local MysteryMarket = require(Shared.MysteryMarket)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SpeedShoes = require(Shared.SpeedShoes)

	local function profile(owns: boolean): any
		local p: any = ProfileSchema.template(0)
		if owns then
			p.mystery[SpeedShoes.ID] = true
		end
		return p
	end

	local CARRY, WALK = Config.CarryWalkSpeed, Config.NormalWalkSpeed

	describe("the item", function()
		it("is a Mystery Market row behind a live switch that starts off", function()
			local item = Catalog.getMysteryItem(SpeedShoes.ID) :: any
			expect(item.name).to.equal("Speed Shoes")
			expect(item.text).to.equal("Carry cats faster!")
			expect(item.cost).to.equal(500)
			expect(item.flag).to.equal(SpeedShoes.FLAG)
			expect(table.find(LiveFlags.KEYS, SpeedShoes.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[SpeedShoes.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[SpeedShoes.FLAG]).to.equal(false)
		end)

		it("is kept by the save check once owned", function()
			local kept = MysteryMarket.sanitize({ speed_shoes = true, nonsense = true })
			expect(kept.speed_shoes).to.equal(true)
			expect(kept.nonsense).to.equal(nil)
			expect(SpeedShoes.owns(profile(true))).to.equal(true)
			expect(SpeedShoes.owns(profile(false))).to.equal(false)
			expect(SpeedShoes.owns(nil)).to.equal(false)
		end)
	end)

	describe("the carry speed", function()
		it("adds 3 to a plain carry: 16 becomes 19", function()
			expect(Config.SpeedShoesCarryBonus).to.equal(3)
			expect(CARRY).to.equal(16)
			expect(SpeedShoes.carry(CARRY, WALK, profile(true), true)).to.equal(19)
		end)

		it("adds nothing without the shoes or with the switch off", function()
			expect(SpeedShoes.carry(CARRY, WALK, profile(false), true)).to.equal(CARRY)
			expect(SpeedShoes.carry(CARRY, WALK, profile(true), false)).to.equal(CARRY)
			expect(SpeedShoes.carry(CARRY, WALK, nil, true)).to.equal(CARRY)
		end)

		it("stacks with Swift Paws in full, since Swift Paws lifts the walk as well", function()
			for _, paws in { 1, 2, 2.5, 3, 3.5 } do
				expect(SpeedShoes.carry(CARRY + paws, WALK + paws, profile(true), true)).to.equal(
					CARRY + paws + 3
				)
			end
		end)

		it(
			"never reaches the player's own walk speed with no cat, and never slows a carry",
			function()
				-- a boost that lifts only the carry: the shoes' bonus is trimmed to one under the walk
				expect(SpeedShoes.carry(18, 20, profile(true), true)).to.equal(19)
				expect(SpeedShoes.carry(19, 20, profile(true), true)).to.equal(19)
				-- already at or over the walk speed: the shoes add nothing and take nothing away
				expect(SpeedShoes.carry(20, 20, profile(true), true)).to.equal(20)
				expect(SpeedShoes.carry(23, 20, profile(true), true)).to.equal(23)
				for base = 10, 30 do
					for walk = 10, 30 do
						local speed = SpeedShoes.carry(base, walk, profile(true), true)
						expect(speed >= base).to.equal(true)
						expect(speed <= base + Config.SpeedShoesCarryBonus).to.equal(true)
						expect(speed <= math.max(base, walk - 1)).to.equal(true)
					end
				end
			end
		)
	end)
end
