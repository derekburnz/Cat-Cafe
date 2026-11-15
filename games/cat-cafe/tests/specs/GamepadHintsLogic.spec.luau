--!strict
-- UI/Components/GamepadHintsLogic.luau (#4224): the console button hints along the bottom of the screen.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("GamepadHintsLogic")) :: any

	local function view(changes: { [string]: any }): any
		local out: { [string]: any } =
			{ gamepad = true, on = true, window = false, tabs = false, selecting = false }
		for key, value in changes do
			out[key] = value
		end
		return out
	end

	local function words(list: { any }): string
		local out = {}
		for _, hint in list do
			table.insert(out, table.concat(hint.keys, "+") .. " " .. hint.label)
		end
		return table.concat(out, ", ")
	end

	describe("keys", function()
		it("hides off a controller or with the switch off", function()
			expect(#Logic.keys(view({ gamepad = false }))).to.equal(0)
			expect(#Logic.keys(view({ on = false, window = true }))).to.equal(0)
		end)

		it("says how to reach the menu with nothing open", function()
			expect(words(Logic.keys(view({})))).to.equal("Select Menu")
		end)

		it("says select and walk on the HUD's menu grid", function()
			expect(words(Logic.keys(view({ selecting = true })))).to.equal("A Select, B Walk")
		end)

		it("says B goes back over a drop-down list or card", function()
			expect(words(Logic.keys(view({ selecting = true, card = true })))).to.equal(
				"A Select, B Back"
			)
		end)

		it("adds the tab buttons only when the window has tabs", function()
			expect(words(Logic.keys(view({ window = true })))).to.equal("A Select, B Back")
			expect(words(Logic.keys(view({ window = true, tabs = true, selecting = true })))).to.equal(
				"A Select, B Back, L1+R1 Tabs"
			)
		end)

		it("has a short cap for every key", function()
			for _, key in { "A", "B", "L1", "R1", "Select" } do
				local cap = Logic.CAP[key]
				expect(cap ~= nil and #cap <= 4).to.equal(true)
			end
		end)
	end)
end
