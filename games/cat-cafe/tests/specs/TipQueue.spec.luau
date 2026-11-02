--!strict
-- UI/Components/TipQueue.luau: the context tips' words and timing (F87, easy-start.md section 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TipQueue = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TipQueue")
	) :: any
	local Tips = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Tips")
	) :: any

	local DEVICES = { "keyboard", "touch", "gamepad" }

	describe("TipQueue words", function()
		it("has a card line for every tip and the like ask, on every device", function()
			local ids: { string } = { Tips.LIKE_ASK }
			for _, def in Tips.LIST do
				table.insert(ids, def.id)
			end
			for _, id in ids do
				for _, device in DEVICES do
					local line = TipQueue.line(id, device)
					expect(type(line)).to.equal("string")
					expect(#line > 10).to.equal(true)
				end
			end
		end)

		it("gives every camera cut its caption", function()
			for _, def in Tips.LIST do
				if def.kind == "cut" then
					local caption = TipQueue.line(def.id, "keyboard", true)
					expect(type(caption)).to.equal("string")
					expect(caption ~= TipQueue.line(def.id, "keyboard")).to.equal(true)
				end
			end
		end)

		it("never names a letter key on touch", function()
			for _, def in Tips.LIST do
				local line = TipQueue.line(def.id, "touch")
				expect(line:find("%(%u%)") == nil).to.equal(true)
				expect(line:find("Hold %u ") == nil).to.equal(true)
			end
			expect(TipQueue.line("second_cat", "keyboard")).to.equal(
				"Open Cats (C) to give your new cat a job"
			)
			expect(TipQueue.line("second_cat", "touch")).to.equal(
				"Tap Cats to give your new cat a job"
			)
			expect(TipQueue.line("stuck_cat", "gamepad"):find("Hold X", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("names the area a rank up opens", function()
			expect(TipQueue.line("rank_up", "keyboard", true, "Park")).to.equal(
				"Rank up to open the Park!"
			)
			expect(TipQueue.line("rank_up", "touch")).to.equal(
				"Rank up to open the Park! Tap your tier to see how"
			)
		end)

		it("has nothing for an unknown id", function()
			expect(TipQueue.line("nope", "keyboard")).to.equal(nil)
			expect(TipQueue.icon("nope")).to.equal("💡")
		end)

		it("reads the device from the last input", function()
			expect(TipQueue.device("Gamepad1", false)).to.equal("gamepad")
			expect(TipQueue.device("Touch", false)).to.equal("touch")
			expect(TipQueue.device("MouseButton1", true)).to.equal("keyboard")
			expect(TipQueue.device("Keyboard", true)).to.equal("keyboard")
			expect(TipQueue.device("None", true)).to.equal("touch")
			expect(TipQueue.device("None", false)).to.equal("keyboard")
		end)
	end)

	describe("TipQueue.free", function()
		it("waits for every busy moment", function()
			expect(TipQueue.free({})).to.equal(true)
			for _, key in { "catching", "rescuing", "carrying", "intro", "flying", "window", "hidden" } do
				expect(TipQueue.free({ [key] = true })).to.equal(false)
			end
		end)

		it("keeps quiet in the dusk warning's last five seconds", function()
			expect(TipQueue.free({ duskLeft = 12 })).to.equal(true)
			expect(TipQueue.free({ duskLeft = 5 })).to.equal(false)
			expect(TipQueue.free({ duskLeft = 1 })).to.equal(false)
		end)
	end)

	describe("TipQueue queue", function()
		it("shows one tip a gap, the first at once", function()
			local queue = TipQueue.new(60)
			queue:push("tackle")
			queue:push("night")
			expect(queue:take(100)).to.equal("tackle")
			queue:shown(100)
			expect(queue:take(130)).to.equal(nil)
			expect(queue:take(160)).to.equal("night")
			expect(queue:size()).to.equal(0)
		end)

		it("keeps three, dropping the oldest, and never one twice", function()
			local queue = TipQueue.new(60)
			expect(queue:push("a")).to.equal(true)
			expect(queue:push("a")).to.equal(false)
			queue:push("b")
			queue:push("c")
			queue:push("d")
			expect(queue:size()).to.equal(3)
			expect(queue:has("a")).to.equal(false)
			expect(queue:take(0)).to.equal("b")
			queue:clear()
			expect(queue:size()).to.equal(0)
		end)
	end)
end
