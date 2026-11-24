--!strict
-- shared/TabletView: #5696, the wider camera view on 4:3 and 16:10 touch screens (switch tabletView).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local TabletView = require(Shared:WaitForChild("TabletView")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any

	describe("TabletView", function()
		it("is behind tabletView, off by default", function()
			expect(TabletView.FLAG).to.equal("tabletView")
			expect(LiveFlags.defaults().tabletView).to.equal(false)
		end)

		it("widens a 4:3 tablet to 80 and a 16:10 one to about 75", function()
			expect(TabletView.fov(4 / 3, true)).to.equal(80)
			local wide = TabletView.fov(16 / 10, true)
			expect(wide >= 74 and wide <= 76).to.equal(true)
		end)

		it("leaves phones, 16:9, portrait and mouse screens at 70", function()
			expect(TabletView.fov(19.5 / 9, true)).to.equal(70)
			expect(TabletView.fov(16 / 9, true)).to.equal(70)
			expect(TabletView.fov(9 / 19.5, true)).to.equal(70)
			expect(TabletView.fov(4 / 3, false)).to.equal(70)
			expect(TabletView.fov(0 / 0, true)).to.equal(70)
		end)
	end)
end
