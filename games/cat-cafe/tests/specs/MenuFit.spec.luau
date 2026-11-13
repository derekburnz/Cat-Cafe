--!strict
-- UI/Components/MenuFit.luau: the left menu's tiles a row under Roblox's chat window (#3686).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local MenuFit = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MenuFit")
	) :: any

	-- seven tiles under the Store: 91 for the Store, 87 a row, 17 between the rows (the HUD's numbers on a PC)
	local function heightOf(columns: number): number
		local rows = math.ceil(7 / columns)
		return 91 + rows * 87 + (rows - 1) * 17
	end

	describe("MenuFit.underChat", function()
		it("keeps the layout's tiles a row when the column fits under the chat", function()
			expect(MenuFit.underChat(100, 700, 2, 4, heightOf)).to.equal(2)
		end)

		it("takes more tiles a row until the column fits (a 1218 x 841 window)", function()
			-- two a row is 490 tall, three a row 386
			expect(MenuFit.underChat(273, 755, 2, 4, heightOf)).to.equal(3)
		end)

		it("goes to four a row on a 720 tall window", function()
			expect(MenuFit.underChat(261, 598, 2, 4, heightOf)).to.equal(4)
		end)

		it("is nil when even the widest grid does not fit", function()
			expect(MenuFit.underChat(400, 598, 2, 4, heightOf)).to.equal(nil)
		end)

		it("never goes under the layout's own count", function()
			expect(MenuFit.underChat(0, 1000, 3, 4, heightOf)).to.equal(3)
			expect(MenuFit.underChat(0, 1000, 4, 4, heightOf)).to.equal(4)
		end)
	end)
end
