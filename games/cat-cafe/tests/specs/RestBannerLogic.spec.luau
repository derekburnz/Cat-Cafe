--!strict
-- UI/Components/RestBannerLogic (#3701): which state of the cafe rest banner shows, and its words.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("RestBannerLogic")) :: any

	local function view(over: { [string]: any }): { [string]: any }
		local base: { [string]: any } =
			{ rest = nil, zone = true, sinceInput = 0, welcomeAge = nil, calm = true, wait = 120 }
		for key, value in over do
			base[key] = value
		end
		return base
	end

	describe("Rest banner", function()
		it("welcomes on a walk in, for a few seconds, at most once a minute", function()
			expect(Logic.pick(view({ welcomeAge = 0 }))).to.equal("welcome")
			local late = Logic.WELCOME_SECONDS - 0.1
			expect(Logic.pick(view({ welcomeAge = late }))).to.equal("welcome")
			expect(Logic.pick(view({ welcomeAge = Logic.WELCOME_SECONDS }))).to.equal(nil)
			expect(Logic.pick(view({}))).to.equal(nil)
			expect(Logic.welcomeDue(nil, 100)).to.equal(true)
			expect(Logic.welcomeDue(100, 100 + Logic.WELCOME_GAP - 1)).to.equal(false)
			expect(Logic.welcomeDue(100, 100 + Logic.WELCOME_GAP)).to.equal(true)
		end)

		it("shows nothing outside the zone, over a window or in a minigame", function()
			expect(Logic.pick(view({ zone = false, welcomeAge = 0 }))).to.equal("welcome")
			expect(Logic.pick(view({ welcomeAge = 0, calm = false }))).to.equal(nil)
			expect(Logic.pick(view({ rest = true, calm = false }))).to.equal(nil)
			local state = Logic.pick({
				rest = nil,
				zone = nil,
				sinceInput = 50,
				welcomeAge = 0,
				calm = true,
				wait = 120,
			})
			expect(state).to.equal(nil)
		end)

		it("counts down while the player is still, and not in a 2x party", function()
			expect(Logic.pick(view({ sinceInput = Logic.COUNT_AFTER - 1 }))).to.equal(nil)
			local state, left = Logic.pick(view({ sinceInput = 40 }))
			expect(state).to.equal("counting")
			expect(left).to.equal(80)
			-- the count holds at its last second while the server takes the rest up, then goes
			state, left = Logic.pick(view({ sinceInput = 121 }))
			expect(state).to.equal("counting")
			expect(left).to.equal(1)
			expect(Logic.pick(view({ sinceInput = 120 + Logic.GRACE }))).to.equal(nil)
			expect(Logic.pick(view({ zone = false, sinceInput = 40 }))).to.equal(nil)
			-- the count comes before a welcome that is still up
			expect(Logic.pick(view({ sinceInput = 12, welcomeAge = 2 }))).to.equal("counting")
		end)

		it("rests whenever the server says so", function()
			expect(Logic.pick(view({ rest = true, sinceInput = 500 }))).to.equal("resting")
			local party = view({ rest = false, zone = false, sinceInput = 500 })
			expect(Logic.pick(party)).to.equal("resting")
		end)

		it("reads the time as minutes and seconds", function()
			expect(Logic.clock(80)).to.equal("1:20")
			expect(Logic.clock(5)).to.equal("0:05")
			expect(Logic.clock(120)).to.equal("2:00")
			expect(Logic.clock(-3)).to.equal("0:00")
		end)

		it("keeps the big line short, names 2x only while it is true and stays gentle", function()
			for _, state in { "welcome", "counting", "resting" } do
				for _, doubled in { true, false } do
					if state == "counting" and not doubled then
						continue -- never shown: the count is skipped in a party
					end
					local big, small, badge = Logic.words(state, doubled, 119)
					expect(#big <= Logic.MAX_CHARS).to.equal(true)
					expect(#small > 0 and #badge > 0).to.equal(true)
					local all = string.lower(big .. " " .. small)
					if not doubled then
						expect(string.find(all, "2x", 1, true)).to.equal(nil)
						expect(string.find(all, "double", 1, true)).to.equal(nil)
					end
					local never = { "hurry", "stay", "don't", "miss", "lose", "leave", "kick", "!" }
					for _, bad in never do
						expect(string.find(all, bad, 1, true)).to.equal(nil)
					end
				end
			end
			expect((Logic.words("welcome", true, 0))).to.equal("Stand still for 2x money")
			expect((Logic.words("counting", true, 80))).to.equal("2x money in 1:20")
			expect((Logic.words("resting", true, 0))).to.equal("2x money ON")
		end)
	end)
end
