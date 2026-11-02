--!strict
-- UI/Components/TutorialHints.luau: the tutorial strip's device-aware line per step (F87, easy-start.md section 2e).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TutorialHints = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TutorialHints")
	) :: any

	local DEVICES = { "keyboard", "touch", "gamepad" }
	local VIEWS = {
		{ step = 0 },
		{ step = 1 },
		{ step = 2, resting = true },
		{ step = 2, resting = false },
		{ step = 3 },
		{ step = 4, bowl = false },
		{ step = 4, bowl = true, baited = false },
		{ step = 4, bowl = true, baited = true },
	}

	local function line(view: { [string]: any }, device: string): string?
		local copy = table.clone(view)
		copy.device = device
		return TutorialHints.line(copy)
	end

	describe("TutorialHints.line", function()
		it("has a short line for every step on every device", function()
			for _, view in VIEWS do
				for _, device in DEVICES do
					local text = line(view, device)
					expect(type(text)).to.equal("string")
					expect(#(text :: string) > 10).to.equal(true)
					expect(#(text :: string) <= 50).to.equal(true)
				end
			end
		end)

		it("names a letter key on a keyboard only", function()
			for _, view in VIEWS do
				for _, device in { "touch", "gamepad" } do
					local text = line(view, device) :: string
					expect(text:find("%(%u%)") == nil).to.equal(true)
				end
			end
			expect(line({ step = 3 }, "keyboard")).to.equal(
				"Buy a table in Upgrades (U): more tips per cat"
			)
			expect(line({ step = 3 }, "touch")).to.equal(
				"Tap Upgrades and buy a table: more tips per cat"
			)
		end)

		it("says how to swing the net on each device", function()
			expect((line({ step = 0 }, "keyboard") :: string):find("Click", 1, true) ~= nil).to.equal(
				true
			)
			expect((line({ step = 0 }, "touch") :: string):find("Tap NET", 1, true) ~= nil).to.equal(
				true
			)
			expect((line({ step = 1 }, "gamepad") :: string):find("R2", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("follows step 2's and step 4's choices", function()
			expect(line({ step = 2, resting = true }, "keyboard")).to.equal(
				"Open Cats (C) and give your new cat a job"
			)
			expect((line({ step = 2 }, "keyboard") :: string):find("Upgrades", 1, true) ~= nil).to.equal(
				true
			)
			expect(line({ step = 4 }, "touch")).to.equal("Tap Upgrades and buy the Bait bowl")
			expect(line({ step = 4, bowl = true }, "keyboard")).to.equal(
				"Put Kibble in your bowl on the back step (F)"
			)
			expect(line({ step = 4, bowl = true, baited = true }, "gamepad")).to.equal(
				"A cat is on its way to your bowl"
			)
		end)

		it("has nothing once the first loop is done", function()
			expect(line({ step = 5 }, "keyboard")).to.equal(nil)
			expect(line({ step = 9 }, "touch")).to.equal(nil)
		end)
	end)

	describe("TutorialHints.resting", function()
		local spots = {
			{ id = "barista_1", tier = 1 },
			{ id = "waiter_1", tier = 1 },
			{ id = "chef_1", tier = 2 },
		}

		it("needs a resting cat and a free slot its tier opens", function()
			expect(TutorialHints.resting({ a = { spotId = "barista_1" }, b = {} }, spots, 1)).to.equal(
				true
			)
			expect(TutorialHints.resting({ a = { spotId = "barista_1" } }, spots, 1)).to.equal(
				false
			)
			expect(
				TutorialHints.resting(
					{ a = { spotId = "barista_1" }, b = { spotId = "waiter_1" }, c = {} },
					spots,
					1
				)
			).to.equal(false)
			expect(
				TutorialHints.resting(
					{ a = { spotId = "barista_1" }, b = { spotId = "waiter_1" }, c = {} },
					spots,
					2
				)
			).to.equal(true)
		end)

		it("is false with nothing to read", function()
			expect(TutorialHints.resting(nil, spots, 1)).to.equal(false)
			expect(TutorialHints.resting({ a = {} }, nil, 1)).to.equal(false)
		end)
	end)
end
