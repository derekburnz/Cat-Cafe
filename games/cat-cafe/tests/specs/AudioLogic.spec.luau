--!strict
-- Pure audio rules (src/client/Audio/Logic.luau) and the cue table (Cues.luau), sound list sections 2 to 6.
return function()
	local Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Audio = Client:WaitForChild("Audio")
	local Logic = require(Audio:WaitForChild("Logic")) :: any
	local Cues = require(Audio:WaitForChild("Cues")) :: any

	local function only(names: { string }): (string) -> boolean
		local set = {}
		for _, name in names do
			set[name] = true
		end
		return function(name: string): boolean
			return set[name] == true
		end
	end

	describe("Audio.Logic voices", function()
		it("reuses an idle voice first", function()
			local voices = { { playing = true, startedAt = 1 }, { playing = false, startedAt = 2 } }
			expect(Logic.pickVoice(voices, 2)).to.equal(2)
		end)

		it("adds a voice while under the limit", function()
			expect(Logic.pickVoice({ { playing = true, startedAt = 1 } }, 2)).to.equal(2)
			expect(Logic.pickVoice({}, 1)).to.equal(1)
		end)

		it("restarts the oldest when every voice is busy", function()
			local voices = { { playing = true, startedAt = 5 }, { playing = true, startedAt = 3 } }
			expect(Logic.pickVoice(voices, 2)).to.equal(2)
		end)

		it("drops a play inside minGap", function()
			expect(Logic.canPlay(nil, 10, 0.08)).to.equal(true)
			expect(Logic.canPlay(10, 10.05, 0.08)).to.equal(false)
			expect(Logic.canPlay(10, 10.08, 0.08)).to.equal(true)
			expect(Logic.canPlay(0, 0.5, 0.5)).to.equal(true) -- exactly minGap later plays (QA: 10.08 - 10 is not exact)
		end)
	end)

	describe("Audio.Logic pitch", function()
		it("steps up the pentatonic scale per circle", function()
			expect(Logic.scaleStep(nil)).to.equal(1)
			expect(Logic.scaleStep(1)).to.equal(1)
			expect(Logic.scaleStep(2)).to.equal(1.125)
			expect(Logic.scaleStep(4)).to.equal(1.5)
			expect(Logic.scaleStep(5)).to.be.near(5 / 3, 1e-9)
		end)

		it("goes up an octave past the fifth step", function()
			expect(Logic.scaleStep(6)).to.equal(2)
			expect(Logic.scaleStep(7)).to.equal(2.25)
		end)

		it("multiplies the step by the random pitch range", function()
			expect(Logic.speed(nil, 2, 0.5)).to.equal(1.125)
			expect(Logic.speed({ 0.9, 1.1 }, nil, 0)).to.be.near(0.9, 1e-9)
			expect(Logic.speed({ 0.9, 1.1 }, nil, 0.5)).to.be.near(1, 1e-9)
		end)

		it("is silent with no ids and picks within the variants", function()
			expect(Logic.pickId({}, 0.5)).to.equal(nil)
			local ids = { "a", "b", "c" }
			expect(Logic.pickId(ids, 0)).to.equal("a")
			expect(Logic.pickId(ids, 0.999)).to.equal("c")
			expect(Logic.pickId(ids, 1)).to.equal("c")
		end)
	end)

	describe("Audio.Logic music and ambience", function()
		local both = only({ "musicDayA", "musicDayB", "musicNightA", "musicNightB" })

		it("plays bed A first and B after 150 s", function()
			expect(Logic.bedFor("day", 0, 150, both)).to.equal("musicDayA")
			expect(Logic.bedFor("day", 150, 150, both)).to.equal("musicDayB")
			expect(Logic.bedFor("night", 20, 150, both)).to.equal("musicNightA")
		end)

		it("falls back to the other bed, then to silence", function()
			local onlyA = only({ "musicDayA" })
			expect(Logic.bedFor("day", 200, 150, onlyA)).to.equal("musicDayA")
			expect(Logic.bedFor("night", 0, 150, onlyA)).to.equal(nil)
		end)

		it("measures how far into the phase the clock is", function()
			expect(Logic.secondsInto(300, 1250, 1000)).to.equal(50)
			expect(Logic.secondsInto(300, nil, 1000)).to.equal(0)
			expect(Logic.secondsInto(300, 2000, 1000)).to.equal(0)
			expect(Logic.secondsInto(300, 990, 1000)).to.equal(300) -- past the phase end it stays at the full length
		end)

		it("picks the zone bed for the phase, then the zone's only bed", function()
			local has = only({ "ambAlleyNight", "ambSewer" })
			expect(Logic.ambienceFor("Alley", "night", has)).to.equal("ambAlleyNight")
			expect(Logic.ambienceFor("alley", "night", has)).to.equal("ambAlleyNight")
			expect(Logic.ambienceFor("Alley", "day", has)).to.equal(nil)
			expect(Logic.ambienceFor("Sewer", "day", has)).to.equal("ambSewer")
			expect(Logic.ambienceFor(nil, "day", has)).to.equal(nil)
		end)

		it("ducks to the lowest active level and mutes by setting", function()
			expect(Logic.duckLevel({})).to.equal(1)
			expect(Logic.duckLevel({ catch = 0.6, sting = 0.4 })).to.equal(0.4)
			expect(Logic.groupVolume(0.5, true)).to.equal(0.5)
			expect(Logic.groupVolume(0.5, false)).to.equal(0)
		end)

		it("scales a channel by its settings slider, squared, full volume when missing", function()
			expect(Logic.sliderGain(nil)).to.equal(1)
			expect(Logic.sliderGain("loud")).to.equal(1)
			expect(Logic.sliderGain(0 / 0)).to.equal(1)
			expect(Logic.sliderGain(1)).to.equal(1)
			expect(Logic.sliderGain(0.5)).to.equal(0.25)
			expect(Logic.sliderGain(0)).to.equal(0)
			expect(Logic.sliderGain(-2)).to.equal(0)
			expect(Logic.sliderGain(7)).to.equal(1)
			expect(Logic.groupVolume(0.8, true, 0.25)).to.equal(0.2)
			expect(Logic.groupVolume(0.5, true, 0.25)).to.equal(0.125)
			expect(Logic.groupVolume(0.8, false, 0.25)).to.equal(0)
		end)

		it("never lowers a channel as its slider rises; gain stays in 0 to 1 (QA)", function()
			local last = -1
			for step = -20, 120 do
				local gain = Logic.sliderGain(step / 100)
				expect(gain >= 0 and gain <= 1).to.equal(true)
				expect(gain >= last).to.equal(true)
				last = gain
			end
			expect(Logic.sliderGain(math.huge)).to.equal(1)
			expect(Logic.sliderGain(-math.huge)).to.equal(0)
			for _, base in { 0, 0.3, 0.8, 1 } do
				expect(Logic.groupVolume(base, true, nil)).to.equal(base)
				expect(Logic.groupVolume(base, true, Logic.sliderGain(1))).to.equal(base)
				expect(Logic.groupVolume(base, false, Logic.sliderGain(0.5))).to.equal(0)
			end
		end)
	end)

	describe("Audio.Logic moment lookups", function()
		it("maps rarity to its jingle, none for Common", function()
			expect(Logic.jingleFor("Common")).to.equal(nil)
			expect(Logic.jingleFor("Rare")).to.equal("jingleRare")
			expect(Logic.jingleFor("Mythical")).to.equal("jingleMythical")
			expect(Logic.jingleFor("Secret")).to.equal("jingleMythical")
			expect(Logic.jingleFor(nil)).to.equal(nil)
		end)

		it("maps grades in either case", function()
			expect(Logic.gradeCue("perfect")).to.equal("circlePerfect")
			expect(Logic.gradeCue("Good")).to.equal("circleGood")
			expect(Logic.gradeCue("miss")).to.equal("circleMiss")
			expect(Logic.gradeCue("great")).to.equal(nil)
		end)

		it("maps foods and traps", function()
			local exists = function(name: string): boolean
				return Cues[name] ~= nil
			end
			expect(Logic.foodCue("kibble", exists)).to.equal("foodKibble")
			expect(Logic.foodCue("star_treat", exists)).to.equal("foodDealer")
			expect(Logic.trapCue("trash_bin")).to.equal("rescueHitBin")
			expect(Logic.trapCue("tree")).to.equal("rescueHitTree")
			expect(Logic.trapCue("dumpster")).to.equal(nil)
		end)

		it("steps a shout-out up the scale by rarity", function()
			expect(Logic.rarityStep("Common")).to.equal(1)
			expect(Logic.rarityStep("legendary")).to.equal(4)
			expect(Logic.rarityStep("Secret")).to.equal(5)
			expect(Logic.rarityStep("Shiny")).to.equal(nil)
			expect(Logic.rarityStep(nil)).to.equal(nil)
		end)

		it("climbs one step per rarity in the catalog's order (QA)", function()
			local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
			for index, rarity in Catalog.rarityOrder do
				expect(Logic.rarityStep(rarity)).to.equal(index)
			end
		end)
	end)

	describe("Audio.Logic world loops", function()
		it("keeps the nearest loops inside the radius, nearest first", function()
			local picked = Logic.nearest({ 20, 3, 9, 14, 1 }, 14, 3)
			expect(#picked).to.equal(3)
			expect(picked[1]).to.equal(5)
			expect(picked[2]).to.equal(2)
			expect(picked[3]).to.equal(3)
		end)

		it("keeps fewer when fewer are close, none when all are far", function()
			local picked = Logic.nearest({ 20, 14, 30 }, 14, 3)
			expect(#picked).to.equal(1)
			expect(picked[1]).to.equal(2)
			expect(#Logic.nearest({ 20, 30 }, 14, 3)).to.equal(0)
			expect(#Logic.nearest({}, 14, 3)).to.equal(0)
		end)

		it("keeps none with a max of 0 (QA)", function()
			expect(#Logic.nearest({ 1, 2 }, 14, 0)).to.equal(0)
		end)
	end)

	describe("Audio.Cues", function()
		it("gives every cue a known channel, a sane volume and only asset ids", function()
			local channels = { Music = true, Ambience = true, Sfx = true, Ui = true }
			for name, cue in Cues do
				expect(channels[cue.group]).to.equal(true)
				expect(cue.volume > 0 and cue.volume <= 1).to.equal(true)
				for _, id in cue.ids do
					expect(string.match(id, "^rbxassetid://%d+$") ~= nil).to.equal(true)
				end
				if cue.pitch ~= nil then
					expect(#cue.pitch).to.equal(2)
				end
				expect(type(name)).to.equal("string")
			end
		end)

		it("has every P0 cue", function()
			for _, name in
				{
					"musicDayA",
					"musicNightA",
					"jingleCatFound",
					"jingleRankUp",
					"ambAlleyNight",
					"netSwing",
					"circlePerfect",
					"circleGood",
					"circleMiss",
					"catchSparkle",
					"catchMiss",
					"catHiss",
					"pawLost",
					"purrfectChime",
					"strayFlee",
					"checkInBell",
					"coinPop",
					"purchase",
					"uiClick",
					"uiError",
				}
			do
				expect(Cues[name] ~= nil).to.equal(true)
			end
		end)
	end)
end
