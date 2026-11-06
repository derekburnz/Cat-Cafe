--!strict
-- The world side of a catch (design v0.4 section 1): a Miss makes the cat hiss and hop back, a catch pops in the
-- cat's rarity colour (sparkles and a ring under it, confetti from Epic up, a beam of light from Legendary up, a
-- second ring and falling sparkles for a Mythical), and a Purrfect (every circle Perfect) bursts gold with a ring
-- and confetti instead, keeping the beam. The screen side (PERFECT, GOOD and MISS pops, the paw row) is the UI's.
--
-- Sources: this player's own CatchSchedule and CatchResult events, plus the stray's HissAt attribute so every
-- player nearby sees a hiss, not only the catcher. Listening only: nothing here fires a remote.
--
-- The result word (F93, catch-rework.md section 3): as UI-Engineer's word slams in over the catch screen, sparkles
-- burst off it and rings grow round it in its colour, gold and biggest for PURRFECT!, gold for EXCELLENT!, mint for
-- GREAT!, none for "So close!". The word comes from CatchResult's grades (Logic.catchWord) and the burst waits for the
-- label to show (Presets.catchWord.targets in CatCafeCatchCircles). Screen only, over the UI through ScreenFx.
--
-- Catch v3 (#1884, catch-rework.md 7b to 7d). Each ring the server judges (CatchJudged) pops at the cat's head in
-- its grade's colour, gold for Perfect, mint for Good and a grey puff for a Miss, and a Perfect first holds the camera
-- and your character's animations for 60 ms (a hit-stop, this client only: the rings never pause, so the timing stays
-- fair). When CatchResult carries the server's `finish`, the pop waits for the net to wrap and wobble, then bursts
-- with confetti in the finish's colours (a Purrfect as before, gold and biggest) and the banner's screen burst. Reduce
-- Motion: no rings and no hit-stop, fewer confetti; Low performance: the budget's smaller bursts. Numbers in
-- Presets.catchJudge and Presets.catchFinish.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local Catch = {}

type Scheduled = { model: Model, position: Vector3, ground: Vector3, rarity: string }

local scheduled: { [string]: Scheduled } = {}
local rng = Random.new()
local lastHiss: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function strayById(strayId: string): Model?
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:GetAttribute("StrayId") == strayId then
			return instance :: Model
		end
	end
	return nil
end

-- Just above the cat, where its sparkle or puff should come from.
local function topOf(model: Model): Vector3
	local frame, size = model:GetBoundingBox()
	return frame.Position + Vector3.new(0, size.Y / 2 + 0.3, 0)
end

-- The floor under the cat, where its ring spreads and its beam starts.
local function bottomOf(model: Model): Vector3
	local frame, size = model:GetBoundingBox()
	return frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
end

local function headOf(model: Model): BasePart?
	local head = model:FindFirstChild("Head", true)
	if head ~= nil and head:IsA("BasePart") then
		return head :: BasePart
	end
	local primary = model.PrimaryPart
	if primary ~= nil then
		return primary
	end
	return model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
end

-- The hiss: a puff, a "!" over the head and the hop. Once per cat per second, so the catcher's CatchResult and
-- the HissAt attribute never play it twice. `lag` is how long ago the server marked the miss.
local function hiss(model: Model, lag: number?)
	if model.Parent == nil then
		return
	end
	local now = os.clock()
	local last: number? = lastHiss[model]
	if last ~= nil and now - last < 1 then
		return
	end
	local at = topOf(model)
	if Context.distance(at) > Context.budget.animRadius then
		return
	end
	lastHiss[model] = now
	Cats.hiss(model, lag)
	Particles.burst("hissPuff", at, Presets.bursts.hissPuff)
	local head = headOf(model)
	if head ~= nil then
		Particles.mark(head, "!", Presets.palette.neonPink, 0.9)
	end
end

-- The beam from Legendary up, and a Mythical's second ring and slow showers of sparkles from the top of the beam.
local function beam(ground: Vector3, rarity: string, colour: Color3)
	local c = Presets.catchPop
	local _, _, beams = Logic.catchPop(rarity)
	if not beams then
		return
	end
	Particles.beam(ground, colour, c.beam.width, c.beam.height, c.beam.seconds)
	if rarity ~= "Mythical" then
		return
	end
	task.delay(c.echo.after, function()
		Particles.ring(
			ground,
			Presets.palette.sparkle,
			c.ring.Mythical * c.echo.scale,
			c.echo.seconds
		)
	end)
	for i = 1, c.shower.bursts do
		task.delay(c.shower.after + (i - 1) * c.shower.every, function()
			local at = ground
				+ Vector3.new(rng:NextNumber(-1.5, 1.5), c.shower.height, rng:NextNumber(-1.5, 1.5))
			Particles.burst(
				"shower",
				at,
				Presets.bursts.shower,
				if i % 2 == 0 then Presets.palette.sparkle else colour
			)
		end)
	end
end

local function purrfect(at: Vector3, ground: Vector3, rarity: string)
	Particles.burst("catchSparkle", at, Presets.bursts.purrfect, Presets.palette.golden)
	Particles.ring(at - Vector3.new(0, 1, 0), Presets.palette.golden)
	Particles.confetti(at, math.ceil(Context.budget.confetti * 0.6), Presets.purrfectColors)
	beam(ground, rarity, Presets.rarity[rarity] or Presets.rarity.Common)
end

local function caught(at: Vector3, ground: Vector3, rarity: string)
	local colour = Presets.rarity[rarity] or Presets.rarity.Common
	local ring, confetti = Logic.catchPop(rarity)
	Particles.burst("catchSparkle", at, Presets.catchSparkle[rarity] or 8, colour)
	Particles.ring(ground, colour, ring, Presets.catchPop.ringSeconds)
	if confetti > 0 then
		Particles.confetti(
			at,
			math.ceil(Context.budget.confetti * confetti),
			{ colour, Presets.palette.sparkle, Presets.palette.offwhite }
		)
	end
	beam(ground, rarity, colour)
end

-- A catch's pop for `rarity` anywhere else something of that rarity is won (a crate piece at the Market): sparkles
-- at `at`, the ring, beam and showers from `ground`.
function Catch.pop(at: Vector3, ground: Vector3, rarity: string)
	caught(at, ground, rarity)
end

-- The result word on the catch screen while it shows: the first of Presets.catchWord.targets in CatCafeCatchCircles.
local function resultWord(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeCatchCircles") else nil
	if screen == nil then
		return nil
	end
	for _, name in Presets.catchWord.targets do
		local found = screen:FindFirstChild(name, true)
		if found ~= nil and found:IsA("GuiObject") and ScreenFx.shown(found :: GuiObject) then
			return found :: GuiObject
		end
	end
	return nil
end

-- The burst behind `word` ("purrfect", "excellent" or "great"), once the word shows, within Presets.catchWord.wait.
local function wordBurst(word: string)
	local c = Presets.catchWord
	local look = c.words[word]
	if look == nil then
		return
	end
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local label = resultWord()
		if label == nil then
			if os.clock() - began > c.wait and loop ~= nil then
				loop:Disconnect()
			end
			return
		end
		if loop ~= nil then
			loop:Disconnect()
		end
		local gui = ScreenFx.gui("EffectsCatchWord", c.displayOrder)
		if gui == nil then
			return
		end
		local object = label :: GuiObject
		local centre = ScreenFx.centre(gui, object)
		local width = object.AbsoluteSize.X
		if object:IsA("TextLabel") then
			local bounds = (object :: TextLabel).TextBounds.X
			if bounds > 0 then
				width = math.min(width, bounds) -- the word, not its box
			end
		end
		local reduced = Context.reducedMotion()
		local count = math.min(look.sparkles, Context.budget.maxBurst)
		if reduced then
			count = math.max(1, math.floor(count / 2))
		end
		ScreenFx.sparkle(gui, Logic.wordSpots(centre, width, count), look.colour, {
			size = c.size,
			seconds = c.seconds,
			reach = c.reach,
			stagger = c.stagger,
		})
		if reduced then
			return
		end
		for i = 1, look.rings do
			task.delay((i - 1) * c.ringGap, function()
				ScreenFx.ring(
					gui,
					centre,
					width * c.ringFrom,
					width * c.ringTo,
					look.colour,
					c.ringSeconds
				)
			end)
		end
	end)
end

-- The hit-stop on a Perfect: the camera and this player's character animations hold for `hitStop` seconds. A second
-- Perfect while one holds stretches it rather than stacking. Off with Reduce Motion.
local held: { [AnimationTrack]: number } = {}
local holdUntil = 0
local HOLD = "CatCafeCatchHitStop"

local function hitStop()
	local seconds = Presets.catchJudge.hitStop
	if seconds <= 0 or Context.reducedMotion() then
		return
	end
	local camera = Workspace.CurrentCamera
	local first = holdUntil <= os.clock()
	holdUntil = os.clock() + seconds
	if first then
		if camera ~= nil then
			local frame = camera.CFrame
			RunService:BindToRenderStep(HOLD, Enum.RenderPriority.Camera.Value + 2, function()
				camera.CFrame = frame
			end)
		end
		local character = Players.LocalPlayer.Character
		local animator = if character ~= nil
			then character:FindFirstChildWhichIsA("Animator", true)
			else nil
		if animator ~= nil then
			for _, track in (animator :: Animator):GetPlayingAnimationTracks() do
				held[track] = track.Speed
				track:AdjustSpeed(0)
			end
		end
	end
	task.delay(seconds, function()
		if os.clock() < holdUntil - 0.001 then
			return -- a later Perfect still holds
		end
		RunService:UnbindFromRenderStep(HOLD)
		for track, speed in held do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
		table.clear(held)
	end)
end

-- One ring judged (CatchJudged): its pop at the cat's head in the grade's colour.
local function judged(strayId: string, grade: unknown)
	local name = Logic.gradeName(grade)
	if name == nil then
		return
	end
	local j = Presets.catchJudge
	local look = j.grades[name]
	local entry: Scheduled? = scheduled[strayId]
	local model = if entry ~= nil then entry.model else strayById(strayId)
	if model == nil or model.Parent == nil then
		return
	end
	local head = headOf(model)
	local at = if head ~= nil then head.Position else topOf(model)
	if name == "perfect" then
		hitStop()
	end
	if look.sparkles > 0 then
		Particles.burst("catchSparkle", at, look.sparkles, look.colour)
	end
	if look.puff > 0 then
		Particles.burst("smokePuff", at, look.puff, look.colour)
	end
	Particles.ring(at, look.colour, look.ring, j.ringSeconds)
end

-- The v3 finish, once the net has wrapped and wobbled: the catch pops with confetti and the banner bursts.
local function finished(spot: Scheduled, finish: string)
	local f = Presets.catchFinish
	task.delay(f.wrap, function()
		wordBurst(finish)
		if finish == "purrfect" then
			purrfect(spot.position, spot.ground, spot.rarity)
			return
		end
		caught(spot.position, spot.ground, spot.rarity)
		local share = f.confetti[finish]
		local colours = f.colours[finish]
		if share ~= nil and colours ~= nil then
			Particles.confetti(spot.position, math.ceil(Context.budget.confetti * share), colours)
		end
	end)
end

local function watchStray(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	model:GetAttributeChangedSignal("HissAt"):Connect(function()
		-- HissAt is the server time of the miss; the server walks the cat back from then, so the hop starts that
		-- far in, and a miss that is already over by the time it replicates plays nothing.
		local at = model:GetAttribute("HissAt")
		if type(at) ~= "number" then
			return
		end
		local lag = math.max(0, Workspace:GetServerTimeNow() - at)
		if lag < Presets.motion.hiss.seconds then
			hiss(model, lag)
		end
	end)
end

function Catch.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("Stray") do
		watchStray(instance)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watchStray)

	-- The stray is locked in place for the whole catch, so where it stood at the schedule is where the result
	-- plays, even if the server removes the caught cat in the same moment it answers.
	Net.on("CatchSchedule", function(strayId: string)
		local model = strayById(strayId)
		if model ~= nil then
			local rarity = model:GetAttribute("Rarity")
			scheduled[strayId] = {
				model = model,
				position = topOf(model),
				ground = bottomOf(model),
				rarity = if type(rarity) == "string" then rarity else "Common",
			}
		end
	end)

	Net.on("CatchJudged", function(strayId: string, _index: number, grade: unknown)
		judged(strayId, grade)
	end)

	Net.on(
		"CatchResult",
		function(strayId: string, grades: { Logic.Grade }, third: any, fourth: any, ...: any)
			local entry: Scheduled? = scheduled[strayId]
			scheduled[strayId] = nil
			local model = if entry ~= nil then entry.model else strayById(strayId)
			if type(grades) ~= "table" then
				return
			end
			if Logic.catchSucceeded(third, fourth) then
				local finish = Logic.catchFinish(third, fourth, ...) -- v3 (#1884); nil on the v2 catch
				local word = if finish == nil then Logic.catchWord(grades) else nil
				if word ~= nil then
					wordBurst(word) -- on the screen, wherever the cat is
				end
				-- A catch whose schedule this client missed plays where the cat stands now.
				local spot: Scheduled? = entry
				if spot == nil and model ~= nil then
					local named = model:GetAttribute("Rarity")
					spot = {
						model = model,
						position = topOf(model),
						ground = bottomOf(model),
						rarity = if type(named) == "string" then named else "Common",
					}
				end
				if spot == nil then
					return
				end
				if finish ~= nil then
					finished(spot, finish)
				elseif Logic.isPurrfect(grades) then
					purrfect(spot.position, spot.ground, spot.rarity)
				else
					caught(spot.position, spot.ground, spot.rarity)
				end
			elseif model ~= nil then
				-- v0.4: a catch only fails on a Miss (a late or wild press, or walking out of range).
				Context.shake(Presets.shake.seconds, Presets.shake.studs) -- for the player who missed
				hiss(model)
			end
		end
	)
end

return Catch
