--!strict
-- UI/Components/CatBubblesLogic.luau and CatBubbleLines.luau: which cat's speech bubble shows (#1079,
-- docs/design/cat-cafe/cat-bubbles.md section 2 and the QA checks in section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("CatBubblesLogic")) :: any
	local Lines = require(Components:WaitForChild("CatBubbleLines")) :: any

	local SHOW = Logic.SHOW_STUDS
	local HIDE = Logic.HIDE_STUDS
	local REPEAT = Logic.REPEAT_SECONDS

	-- one step with stations given as { key, distance } pairs
	local function step(
		memory: any,
		stations: { { any } },
		now: number,
		blocked: boolean?
	): (any, any)
		local keys, distances = {}, {}
		for i, station in stations do
			keys[i] = station[1]
			distances[i] = station[2]
		end
		return Logic.step(memory, keys, distances, #stations, now, blocked == true)
	end

	describe("CatBubblesLogic.step", function()
		it("shows within the show range and not beyond it", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", SHOW + 1 } }, 0)).to.equal(nil)
			expect(step(memory, { { "wheel", SHOW } }, 1)).to.equal("wheel")
		end)

		it("keeps showing out to the hide range, so the edge does not flicker", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 10 } }, 0)).to.equal("wheel")
			expect(step(memory, { { "wheel", 14 } }, 1)).to.equal("wheel")
			expect(step(memory, { { "wheel", HIDE } }, 2)).to.equal("wheel")
			local shown, stopped = step(memory, { { "wheel", HIDE + 0.5 } }, 3)
			expect(shown).to.equal(nil)
			expect(stopped).to.equal("wheel")
		end)

		it("shows only the nearest station in range", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 9 }, { "market", 6 } }, 0)).to.equal("market")
		end)

		it("swaps to a nearer station and makes the old one quiet", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 5 }, { "market", 11 } }, 0)).to.equal("wheel")
			local shown, stopped = step(memory, { { "wheel", 10 }, { "market", 7 } }, 1)
			expect(shown).to.equal("market")
			expect(stopped).to.equal("wheel")
			-- walking straight back: the wheel is quiet, the market keeps its bubble while in hide range
			expect(step(memory, { { "wheel", 4 }, { "market", 13 } }, 5)).to.equal("market")
		end)

		it("keeps a station quiet for the repeat time after its bubble fades", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 5 } }, 0)).to.equal("wheel")
			step(memory, { { "wheel", 20 } }, 10) -- walked away: quiet until 10 + REPEAT
			expect(step(memory, { { "wheel", 5 } }, 10 + REPEAT - 1)).to.equal(nil)
			expect(step(memory, { { "wheel", 5 } }, 10 + REPEAT)).to.equal("wheel")
		end)

		it("hides while blocked and counts that as a fade", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 5 } }, 0)).to.equal("wheel")
			local shown, stopped = step(memory, { { "wheel", 5 } }, 1, true)
			expect(shown).to.equal(nil)
			expect(stopped).to.equal("wheel")
			expect(step(memory, { { "wheel", 5 } }, 2)).to.equal(nil)
		end)

		it("shows nothing new while blocked", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "wheel", 5 } }, 0, true)).to.equal(nil)
			expect(step(memory, { { "wheel", 5 } }, 1)).to.equal("wheel")
		end)

		it("fades a station that leaves the list (its line may no longer show)", function()
			local memory = Logic.newMemory()
			expect(step(memory, { { "cart", 5 } }, 0)).to.equal("cart")
			local shown, stopped = step(memory, {}, 1)
			expect(shown).to.equal(nil)
			expect(stopped).to.equal("cart")
		end)

		it("ignores entries past count in reused arrays", function()
			local memory = Logic.newMemory()
			local shown = Logic.step(memory, { "wheel", "market" }, { 20, 3 }, 1, 0, false)
			expect(shown).to.equal(nil)
		end)
	end)

	describe("CatBubblesLogic.allowed", function()
		it("shows the Bellhop line only once the sync says it is not claimed", function()
			expect(Logic.allowed("unclaimedBellhop", false, true)).to.equal(true)
			expect(Logic.allowed("unclaimedBellhop", true, true)).to.equal(false)
			expect(Logic.allowed("unclaimedBellhop", nil, true)).to.equal(false)
		end)

		it("shows the dealer and Collector lines only while they are here", function()
			expect(Logic.allowed("dealerHere", nil, true)).to.equal(true)
			expect(Logic.allowed("dealerHere", nil, false)).to.equal(false)
			expect(Logic.allowed("collectorVisiting", nil, false)).to.equal(false)
			expect(Logic.allowed("always", nil, false)).to.equal(true)
			expect(Logic.allowed("someday", nil, true)).to.equal(false)
		end)
	end)

	describe("CatBubblesLogic sizes", function()
		it("grows with the line and shrinks up close, never past its full size", function()
			local short = Logic.size("Hi")
			local long = Logic.size("Got a spin? Give the wheel a whirl!")
			expect(long > short).to.equal(true)
			expect(Logic.closeScale(SHOW)).to.equal(1)
			expect(Logic.closeScale(Logic.FULL_STUDS / 2)).to.near(0.5, 1e-9)
			expect(Logic.closeScale(0)).to.near(Logic.MIN_SCALE, 0.026)
		end)
	end)

	describe("CatBubbleLines", function()
		it("has the seven cats, one line each, each line at most 36 characters", function()
			local tags = {}
			for _, line in Lines.LINES do
				expect(tags[line.tag]).to.equal(nil)
				tags[line.tag] = true
				expect(#line.text <= Lines.MAX_CHARS).to.equal(true)
				expect(#line.text > 0).to.equal(true)
			end
			expect(#Lines.LINES).to.equal(7)
		end)
	end)
end
