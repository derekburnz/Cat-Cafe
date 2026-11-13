--!strict
-- #3556: the wider Net button reach on touch screens (shared/TouchReach).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local NetSwing = require(Shared:WaitForChild("NetSwing"))
	local TouchReach = require(Shared:WaitForChild("TouchReach"))

	local ORIGIN = Vector3.new(0, 3, 0)
	local function at(id: string, x: number, y: number?): NetSwing.Target
		return { id = id, position = Vector3.new(x, 3 + (y or 0), 0) }
	end

	describe("TouchReach", function()
		it("is behind a switch that starts off", function()
			expect(LiveFlags.OFF_BY_DEFAULT[TouchReach.FLAG]).to.equal(true)
			expect(LiveFlags.shown(TouchReach.FLAG, nil)).to.equal(false)
			expect(LiveFlags.shown(TouchReach.FLAG, true)).to.equal(true)
		end)

		it("reaches 1.5 times a swing, and the Long Net's extra with it", function()
			expect(TouchReach.reach()).to.equal(NetSwing.reach() * 1.5)
			expect(TouchReach.reach(3)).to.equal(NetSwing.reach(3) * 1.5)
		end)

		it("picks the nearest stray inside the reach, whichever way the player faces", function()
			local reach = TouchReach.reach()
			local picked =
				TouchReach.pick(ORIGIN, { at("far", reach - 0.5), at("near", -(reach - 2)) })
			expect(picked).to.be.ok()
			expect((picked :: NetSwing.Target).id).to.equal("near")
		end)

		it("picks nothing beyond the reach or up on a perch", function()
			local reach = TouchReach.reach()
			expect(TouchReach.pick(ORIGIN, { at("out", reach + 0.5) })).to.equal(nil)
			expect(TouchReach.pick(ORIGIN, { at("perch", 4, NetSwing.BEGINNER_RISE + 1) })).to.equal(
				nil
			)
			expect(TouchReach.pick(ORIGIN, {})).to.equal(nil)
		end)

		it("counts a stray as near within NEAR_STUDS on the ground", function()
			expect(TouchReach.near(ORIGIN, { at("a", TouchReach.NEAR_STUDS - 1, 30) })).to.equal(
				true
			)
			expect(TouchReach.near(ORIGIN, { at("a", TouchReach.NEAR_STUDS + 1) })).to.equal(false)
		end)

		it("ends a walk after WALK_SECONDS or when a swing cannot go", function()
			expect(TouchReach.walking(0, true)).to.equal(true)
			expect(TouchReach.walking(TouchReach.WALK_SECONDS - 0.1, true)).to.equal(true)
			expect(TouchReach.walking(TouchReach.WALK_SECONDS, true)).to.equal(false)
			expect(TouchReach.walking(1, false)).to.equal(false)
		end)
	end)
end
