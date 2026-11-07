--!strict
-- UI/Components/TackleTry.luau: when the "tackle them" tip shows (#2302).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TackleTry = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TackleTry")
	) :: any

	local function input(overrides: { [string]: any }): any
		local base: { [string]: any } = {
			lessonSeen = true,
			tried = false,
			ready = true,
			from = Vector3.new(0, 0, 0),
			reach = 12,
			others = { { position = Vector3.new(10, 0, 0), carrying = true } },
		}
		for key, value in overrides do
			base[key] = value
		end
		return base
	end

	describe("TackleTry.due", function()
		it("shows when the tackle is ready and a carrier is within a lunge", function()
			expect(TackleTry.due(input({}))).to.equal(true)
			-- a step past the lunge still counts
			expect(
				TackleTry.due(
					input({ others = { { position = Vector3.new(15, 0, 0), carrying = true } } })
				)
			).to.equal(true)
		end)

		it("waits for someone actually carrying, close enough", function()
			expect(
				TackleTry.due(
					input({ others = { { position = Vector3.new(5, 0, 0), carrying = false } } })
				)
			).to.equal(false)
			expect(
				TackleTry.due(
					input({ others = { { position = Vector3.new(40, 0, 0), carrying = true } } })
				)
			).to.equal(false)
			expect(TackleTry.due(input({ others = {} }))).to.equal(false)
		end)

		it("waits for the lesson, a ready tackle, and shows once", function()
			expect(TackleTry.due(input({ lessonSeen = false }))).to.equal(false)
			expect(TackleTry.due(input({ ready = false }))).to.equal(false)
			expect(TackleTry.due(input({ tried = true }))).to.equal(false)
		end)
	end)
end
