--!strict
-- UI/Components/AutoEquipToast.luau: the toast after Auto Equip moves cats (#1955, auto-equip.md).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local AutoEquipToast = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AutoEquipToast")
	) :: any

	local function money(n: number): string
		return "$" .. tostring(n)
	end

	describe("AutoEquipToast.text", function()
		it("names one cat, its job and what it adds", function()
			local swaps = { { catName = "Mochi", role = "Barista", perSecond = 12 } }
			expect(AutoEquipToast.text(swaps, money)).to.equal(
				"Auto Equip: Mochi is now your Barista (+$12/s)"
			)
			expect(AutoEquipToast.text({ { catName = "Mochi", role = "Barista" } }, money)).to.equal(
				"Auto Equip: Mochi is now your Barista"
			)
		end)

		it("counts several swaps in one toast and says nothing with none", function()
			local swaps = {
				{ catName = "Mochi", role = "Barista" },
				{ catName = "Ginger", role = "Waiter" },
			}
			expect(AutoEquipToast.text(swaps, money)).to.equal(
				"Auto Equip: 2 cats moved to better jobs"
			)
			expect(AutoEquipToast.text({}, money)).to.equal(nil)
		end)
	end)

	describe("AutoEquipToast.clean", function()
		it("keeps only swaps with a name and a job, and a real rate", function()
			local swaps = AutoEquipToast.clean({
				{ catName = "Mochi", role = "Barista", perSecond = 0 / 0 },
				{ catName = 5, role = "Waiter" },
				"junk",
				{ catName = "Ginger", role = "Waiter", perSecond = 3 },
			})
			expect(#swaps).to.equal(2)
			expect(swaps[1].perSecond).to.equal(nil)
			expect(swaps[2].perSecond).to.equal(3)
			expect(#AutoEquipToast.clean(nil)).to.equal(0)
		end)
	end)
end
