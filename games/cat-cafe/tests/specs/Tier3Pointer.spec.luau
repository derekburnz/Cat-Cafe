--!strict
-- shared/Tier3Pointer: #5715, at Tier 2 in the Park the one thing that gets Tier 3's coins next (switch tier3Pointer).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Tier3Pointer = require(Shared:WaitForChild("Tier3Pointer")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any

	-- a Tier 2 save in the Park with Tier3Path met and coins short, nothing busy, nothing near
	local function look(changes: { [string]: any }?): any
		local value: { [string]: any } = {
			tier = 2,
			coins = 10000,
			cost = 25000,
			pathMet = true,
			area = "park",
			busy = false,
			picnicReady = false,
			picnicRunning = false,
			catNear = false,
		}
		for key, v in changes or {} do
			value[key] = v
		end
		return value
	end

	describe("Tier3Pointer", function()
		it("is behind tier3Pointer, off by default", function()
			expect(Tier3Pointer.FLAG).to.equal("tier3Pointer")
			expect(LiveFlags.defaults().tier3Pointer).to.equal(false)
		end)

		it("points at a ready Picnic Basket first", function()
			expect(Tier3Pointer.target(look({ picnicReady = true, catNear = true }))).to.equal(
				"picnic"
			)
			expect(Tier3Pointer.caption("picnic")).to.equal("Picnic Party: 2x coins")
		end)

		it("points at nothing while Picnic Time runs", function()
			expect(Tier3Pointer.target(look({ picnicRunning = true, catNear = true }))).to.equal(
				nil
			)
			expect(Tier3Pointer.target(look({ picnicReady = true, picnicRunning = true }))).to.equal(
				nil
			)
		end)

		it("points at a near Park cat otherwise, and at nothing with none near", function()
			expect(Tier3Pointer.target(look({ catNear = true }))).to.equal("cat")
			expect(Tier3Pointer.caption("cat")).to.equal("Catch cats: more coins")
			expect(Tier3Pointer.target(look())).to.equal(nil)
			expect(Tier3Pointer.caption(nil)).to.equal(nil)
		end)

		it("ends once Tier 3 is funded, and holds off before Tier3Path is met", function()
			expect(Tier3Pointer.target(look({ catNear = true, coins = 25000 }))).to.equal(nil)
			expect(Tier3Pointer.target(look({ catNear = true, pathMet = false }))).to.equal(nil)
		end)

		it("only at Tier 2, in the Park, and not while busy", function()
			expect(Tier3Pointer.target(look({ catNear = true, tier = 3 }))).to.equal(nil)
			expect(Tier3Pointer.target(look({ catNear = true, tier = 1 }))).to.equal(nil)
			expect(Tier3Pointer.target(look({ catNear = true, area = "street" }))).to.equal(nil)
			expect(Tier3Pointer.target(look({ catNear = true, busy = true }))).to.equal(nil)
			local noTier3 = look({ catNear = true })
			noTier3.cost = nil
			expect(Tier3Pointer.target(noTier3)).to.equal(nil)
		end)

		it("logs a field per target under tier3_path", function()
			expect(Tier3Pointer.field("picnic")).to.equal("coins_picnic")
			expect(Tier3Pointer.field("cat")).to.equal("coins_cat")
			expect(Tier3Pointer.field(nil)).to.equal(nil)
			expect(Tier3Pointer.EVENT).to.equal("tier3_path")
		end)
	end)
end
