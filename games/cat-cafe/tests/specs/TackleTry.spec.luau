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

	describe("TackleTry.cueTarget (#2558)", function()
		local function cue(overrides: { [string]: any }): any
			local base: { [string]: any } = {
				ready = true,
				hits = 0,
				from = Vector3.new(0, 0, 0),
				reach = 12,
				others = {
					{ position = Vector3.new(14, 0, 0), carrying = true },
					{ position = Vector3.new(6, 0, 0), carrying = true },
					{ position = Vector3.new(2, 0, 0), carrying = false },
				},
			}
			for key, value in overrides do
				base[key] = value
			end
			return base
		end

		it("picks the nearest carrier within a step and a lunge", function()
			expect(TackleTry.cueTarget(cue({}))).to.equal(2)
			expect(
				TackleTry.cueTarget(cue({ others = { { position = Vector3.new(20, 0, 0), carrying = true } } }))
			).to.equal(nil)
			expect(TackleTry.cueTarget(cue({ others = {} }))).to.equal(nil)
		end)

		it("waits for a ready tackle and stops after CUE_HITS landed tackles", function()
			expect(TackleTry.cueTarget(cue({ ready = false }))).to.equal(nil)
			local nowhere = cue({})
			nowhere.from = nil -- no character yet
			expect(TackleTry.cueTarget(nowhere)).to.equal(nil)
			expect(TackleTry.cueTarget(cue({ hits = TackleTry.CUE_HITS - 1 }))).to.equal(2)
			expect(TackleTry.cueTarget(cue({ hits = TackleTry.CUE_HITS }))).to.equal(nil)
		end)
	end)
end
