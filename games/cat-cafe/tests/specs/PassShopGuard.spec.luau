--!strict
-- UI/Components/PassShop.prompt behind the store guard (#1936, release.md section 3): no tap, or a catch, a rescue or a
-- cutscene, and Roblox's purchase window never opens; each refusal fires `blocked` with its source and reason.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PassShop = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PassShop")
	) :: any

	-- runs `body` and returns each refusal it caused as { source, reason }
	local function refusals(body: () -> ()): { { string } }
		local seen: { { string } } = {}
		local connection = PassShop.blocked:Connect(function(source: string, reason: string)
			table.insert(seen, { source, reason })
		end)
		body()
		connection:Disconnect()
		return seen
	end

	describe("PassShop.prompt's guard", function()
		it("refuses a call with no tap and names the source", function()
			local seen = refusals(function()
				PassShop.prompt(200, "bait")
			end)
			expect(#seen).to.equal(1)
			expect(seen[1][1]).to.equal("bait")
			expect(seen[1][2]).to.equal("no_tap")
		end)

		it("refuses during a catch, a rescue or a cutscene even right after a tap", function()
			local before = PassShop.busy
			PassShop.busy = function()
				return true
			end
			local seen = refusals(function()
				PassShop.noteTap()
				PassShop.prompt(200, "store")
			end)
			PassShop.busy = before
			expect(#seen).to.equal(1)
			expect(seen[1][1]).to.equal("store")
			expect(seen[1][2]).to.equal("busy")
		end)

		it("reads a call with no source as the Store's", function()
			local seen = refusals(function()
				PassShop.prompt(200)
			end)
			expect(seen[1][1]).to.equal("store")
		end)
	end)
end
