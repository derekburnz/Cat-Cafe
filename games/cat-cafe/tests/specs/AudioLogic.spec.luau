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

	describe("Audio.Logic hold, zones and gold (2026-10-27 batch)", function()
		it("stretches the hold fill so its pop lands on the trigger", function()
			expect(Logic.holdSpeed(0.48)).to.equal(1)
			expect(math.abs((Logic.holdSpeed(0.5) :: number) - 0.96) < 1e-9).to.equal(true)
			expect(Logic.holdSpeed(0.3)).to.equal(1.6)
			expect(Logic.holdSpeed(0.1)).to.equal(2)
			expect(Logic.holdSpeed(5)).to.equal(0.5)
			expect(Logic.holdSpeed(0)).to.equal(nil)
			expect(Logic.holdSpeed(-1)).to.equal(nil)
			expect(Logic.holdSpeed(0 / 0)).to.equal(nil)
		end)

		it("chimes only when crossing between the safe street and a catching area", function()
			expect(Logic.zoneCue(nil, "Alley")).to.equal("zoneArea")
			expect(Logic.zoneCue("Cafe", "Park")).to.equal("zoneArea")
			expect(Logic.zoneCue("Alley", nil)).to.equal("zoneSafe")
			expect(Logic.zoneCue("Park", "Cafe")).to.equal("zoneSafe")
			expect(Logic.zoneCue(nil, "Cafe")).to.equal(nil)
			expect(Logic.zoneCue("Cafe", nil)).to.equal(nil)
			expect(Logic.zoneCue("Alley", "Park")).to.equal(nil)
			expect(Logic.zoneCue("Alley", "Alley")).to.equal(nil)
			expect(Logic.isSafeZone(nil)).to.equal(true)
			expect(Logic.isSafeZone("Cafe")).to.equal(true)
			expect(Logic.isSafeZone("Sewer")).to.equal(false)
		end)

		it("twinkles for gold strays and Epic and up", function()
			expect(Logic.shimmers(true, "Common")).to.equal(true)
			expect(Logic.shimmers(true, nil)).to.equal(true)
			expect(Logic.shimmers(false, "Epic")).to.equal(true)
			expect(Logic.shimmers(nil, "legendary")).to.equal(true)
			expect(Logic.shimmers(nil, "Mythical")).to.equal(true)
			expect(Logic.shimmers(false, "Rare")).to.equal(false)
			expect(Logic.shimmers(nil, "Common")).to.equal(false)
			expect(Logic.shimmers("yes", 3)).to.equal(false)
			expect(Logic.shimmers(nil, nil)).to.equal(false)
		end)
	end)

	describe("Audio.Logic hold, zones and gold edges (QA)", function()
		-- The zone chime and the HUD's Safe zone chip (UI/Components/Wayfinding) each decide what is safe; a player
		-- must never hear "safe" while the chip says "catching area", or the other way round.
		it("agrees with the zone chip on every zone, and the chimes mirror each other", function()
			local Components = Client:WaitForChild("UI"):WaitForChild("Components")
			local Wayfinding = require(Components:WaitForChild("Wayfinding")) :: any
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			) :: any
			local zones: { string | false } = { false, "Cafe" }
			for _, area in Catalog.areas do
				-- WorldBuilder names each area's zone box with the id's first letter upper-cased ("alley" -> "Alley")
				table.insert(
					zones,
					string.upper(string.sub(area.id, 1, 1)) .. string.sub(area.id, 2)
				)
			end
			for _, a in zones do
				local from = if a == false then nil else a
				expect(Logic.isSafeZone(from)).to.equal(Wayfinding.isSafe(from))
				for _, b in zones do
					local to = if b == false then nil else b
					local there, back = Logic.zoneCue(from, to), Logic.zoneCue(to, from)
					expect(there == "zoneArea").to.equal(back == "zoneSafe")
					expect(there == nil).to.equal(back == nil)
				end
			end
		end)

		it("never fills the hold faster as the hold gets longer, and stays in 0.5 to 2", function()
			local last = math.huge
			for step = 1, 600 do
				local speed = Logic.holdSpeed(step / 100) :: number
				expect(speed >= 0.5 and speed <= 2 and speed <= last).to.equal(true)
				last = speed
			end
			expect(Logic.holdSpeed(math.huge)).to.equal(0.5)
			expect(Logic.holdSpeed(-math.huge)).to.equal(nil)
		end)
	end)

	-- QA for Sound-Agent's PR #268 (reviewer N131, N150): which resting cafe cat purrs. The server marks a cat on the
	-- seated body with Pose "sit" (CafeService, PR #266); a lying cat purrs only while Effects shows it loafing.
	describe("Audio.Logic resting purrs (QA)", function()
		it("purrs on the sitting body all day, on the lying body only in a loaf, never at night", function()
			expect(Logic.restingPurrs("sit", false, false)).to.equal(true)
			expect(Logic.restingPurrs("sit", true, false)).to.equal(false)
			expect(Logic.restingPurrs("sit", true, true)).to.equal(false)
			expect(Logic.restingPurrs(nil, false, true)).to.equal(true)
			expect(Logic.restingPurrs(nil, false, false)).to.equal(false)
			expect(Logic.restingPurrs(nil, true, true)).to.equal(false)
		end)

		it("treats any pose but the exact \"sit\" like no pose, for every night and loaf", function()
			local poses: { any } = { "nap", "upright", "Sit", "sit ", "", 5, true, {} }
			for _, pose in poses do
				for _, night in { false, true } do
					for _, loafing in { false, true } do
						local want = not night and loafing
						expect(Logic.restingPurrs(pose, night, loafing)).to.equal(want)
						expect(Logic.restingPurrs(nil, night, loafing)).to.equal(want)
					end
				end
			end
		end)
	end)

	-- QA for Sound-Agent's PR #303 (v0.8 and the short night, data-model sections 12, 12b and 13): when the dusk
	-- bell rings, which shout-out sting a rarity gets, a fresh carry start, and the plot attribute cues.
	describe("Audio.Logic v0.8 cues (QA)", function()
		local Catalog = require(
			game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
		) :: any

		it("rings the dusk bell warning seconds before night, by day only", function()
			expect(Logic.duskBellIn("day", 100, 50, 15)).to.equal(35)
			expect(Logic.duskBellIn("day", 100, 85, 15)).to.equal(0)
			expect(Logic.duskBellIn("day", 100, 85.5, 15)).to.equal(0)
			expect(Logic.duskBellIn("day", 100, 86, 15)).to.equal(0)
			expect(Logic.duskBellIn("day", 100, 86.5, 15)).never.to.be.ok()
			for _, phase in { "night", "Day", "", 5 } :: { any } do
				expect(Logic.duskBellIn(phase, 100, 50, 15)).never.to.be.ok()
			end
			expect(Logic.duskBellIn(nil, 100, 50, 15)).never.to.be.ok()
			expect(Logic.duskBellIn("day", nil, 50, 15)).never.to.be.ok()
			-- a sweep through the last 20 s of a day: never negative, and the bell lands on its second or is skipped
			for step = 0, 80 do
				local now = 80 + step * 0.25
				local wait = Logic.duskBellIn("day", 100, now, 15)
				if now <= 85 then
					expect(wait).to.equal(85 - now)
				elseif now <= 86 then
					expect(wait).to.equal(0)
				else
					expect(wait).never.to.be.ok()
				end
			end
		end)

		it("gives the Mythical sting to Mythical and the old Secret only, in any case", function()
			for rarity in Catalog.rarities do
				local want = if string.lower(rarity) == "mythical"
					then "announceMythical"
					else "announce"
				expect(Logic.announceCue(rarity)).to.equal(want)
				expect(Logic.announceCue(string.upper(rarity))).to.equal(want)
				expect(Logic.announceCue(string.lower(rarity))).to.equal(want)
			end
			expect(Logic.announceCue("Secret")).to.equal("announceMythical")
			expect(Logic.announceCue("SECRET")).to.equal("announceMythical")
			for _, rarity in { "", "Mythic", "gold", "Unknown" } do
				expect(Logic.announceCue(rarity)).to.equal("announce")
			end
			expect(Logic.announceCue(nil)).to.equal("announce")
		end)

		it("takes a carry start as fresh from 2 s before now to 1 s after", function()
			local now = 1000
			for step = -16, 12 do
				local startedAt = now + step * 0.25
				expect(Logic.freshStart(startedAt, now)).to.equal(step >= -8 and step <= 4)
			end
			for _, odd in { nil, "1000", true, {}, 0 / 0, math.huge, -math.huge } :: { any } do
				expect(Logic.freshStart(odd, now)).to.equal(false)
			end
		end)

		it("cues each plot attribute change as the data model's display attributes move", function()
			local values: { any } = { nil, 0, -1, 1, 6, "3", true }
			local names = {
				"TipPiles",
				"CollectorUntil",
				"MysteryGiftAt",
				"TipPilesAmount",
				"CollectorCatId",
				"tippiles",
			}
			for _, name in names do
				for i = 1, 7 do
					for j = 1, 7 do
						local before, after = values[i], values[j]
						local was = if type(before) == "number" then before else 0
						local is = if type(after) == "number" then after else 0
						local want: string? = nil
						if name == "TipPiles" and is < was then
							want = "tipPile"
						elseif name == "CollectorUntil" and was <= 0 and is > 0 then
							want = "visitorCollector"
						elseif name == "MysteryGiftAt" and was <= 0 and is > 0 then
							want = "visitorMystery" -- a clearing is silent: giftOpen plays with the result card
						end
						expect(Logic.plotCue(name, before, after)).to.equal(want)
					end
				end
			end
		end)

		it("names only cues the table has; giftOpen stays for the result card", function()
			local names: { string } =
				{ "duskBell", "announce", "announceMythical", "tipPile", "visitorCollector" }
			for _, name in { "visitorMystery", "giftOpen" } do
				table.insert(names, name)
			end
			for _, name in names do
				expect(Cues[name] ~= nil).to.equal(true)
			end
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

	describe("Audio.Logic tackle sounds (QA)", function()
		-- v0.11 F74: TackleAt and TackleMissAt sound only while under 0.6 s old (init.luau TACKLE_FRESH), so a join
		-- or a respawn replays nothing; with no window a carry start keeps its 2 s.
		it("a tackle's attribute sounds for 0.6 s and never later, whatever the default window", function()
			local now = 1000
			expect(Logic.freshStart(now, now, 0.6)).to.equal(true)
			expect(Logic.freshStart(now - 0.59, now, 0.6)).to.equal(true)
			expect(Logic.freshStart(now - 0.61, now, 0.6)).to.equal(false)
			expect(Logic.freshStart(now - 1.5, now, 0.6)).to.equal(false)
			expect(Logic.freshStart(now - 1.5, now)).to.equal(true)
			expect(Logic.freshStart(now - 1.5, now, nil)).to.equal(true)
			expect(Logic.freshStart(now - 2.01, now)).to.equal(false)
		end)

		it("a clock up to 1 s ahead counts as fresh at any window, and nothing past it", function()
			local now = 1000
			for _, window in { 0, 0.6, 2, 30 } do
				expect(Logic.freshStart(now + 0.99, now, window)).to.equal(true)
				expect(Logic.freshStart(now + 1.01, now, window)).to.equal(false)
			end
			expect(Logic.freshStart(now - 0.01, now, 0)).to.equal(false)
		end)

		it("anything but a number never sounds, with the short window too", function()
			for _, odd in { nil, "1000", true, {}, 0 / 0, math.huge, -math.huge } :: { any } do
				expect(Logic.freshStart(odd, 1000, 0.6)).to.equal(false)
			end
		end)
	end)
end
