--!strict
-- UI/Components/EdgeShadeLogic (#3702): the screen's edge shade stays at the edges, soft and slow.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local EdgeShadeLogic = require(Components:WaitForChild("EdgeShadeLogic")) :: any

	describe("Edge shade", function()
		it("has one strip per edge and leaves the middle clear", function()
			expect(#EdgeShadeLogic.EDGES).to.equal(4)
			local seen = {}
			for _, edge in EdgeShadeLogic.EDGES do
				seen[edge.name] = true
				-- each strip spans its edge fully one way and only part of the screen the other way
				local full = (edge.size.X == 1 and edge.size.Y < 0.5)
					or (edge.size.Y == 1 and edge.size.X < 0.5)
				expect(full).to.equal(true)
			end
			expect(seen.Left and seen.Right and seen.Top and seen.Bottom).to.equal(true)
			local wide, tall = EdgeShadeLogic.clear()
			expect(wide >= 0.4).to.equal(true)
			expect(tall >= 0.4).to.equal(true)
		end)

		it("is a soft shade that fades slowly and sits over the menus", function()
			-- never near black at the edge, lighter further in
			expect(EdgeShadeLogic.EDGE_TRANSPARENCY >= 0.35).to.equal(true)
			expect(EdgeShadeLogic.MID_TRANSPARENCY > EdgeShadeLogic.EDGE_TRANSPARENCY).to.equal(
				true
			)
			-- no flash: a quarter of a second or more each way
			expect(EdgeShadeLogic.FADE >= 0.25).to.equal(true)
			expect(EdgeShadeLogic.DISPLAY_ORDER > 20).to.equal(true)
		end)

		it("keeps the hint readable and clear of the HUD's bottom row and of the middle", function()
			expect(EdgeShadeLogic.HINT_SIZE >= 16).to.equal(true)
			expect(EdgeShadeLogic.HINT_AT > 0.6).to.equal(true)
			expect(EdgeShadeLogic.HINT_AT < 0.8).to.equal(true)
		end)
	end)
end
