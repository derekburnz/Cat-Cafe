--!strict
-- The world side of opening a Cafe Crate at the Golden Fish Market (F53, golden-fish.md section 4). The window plays
-- the reveal card (the UI's); here a puff of ice sparkle comes off the stall's counter and the won piece's rarity
-- pops out of it, the same pop a catch of that rarity gets (Catch.pop): sparkles and a ring in the rarity colour,
-- confetti from Epic up, a beam from Legendary up and a second ring and showers for a Mythical. It plays when the
-- window shows the prize: the moment CrateResult arrives, or at the stop of the window's crate reel (F103,
-- crate-reel.md) once it has one. It is in the won piece's colour from its first frame, and never builds up or shows a
-- better rarity first, so nothing looks like a near miss (monetization-policy). A duplicate pops the same; its golden
-- fish back sparkle on the player (Fish.luau). Only the opener sees it, near a stall. Listening only.
--
-- The crate itself (Model-Agent's crates.py, `ReplicatedStorage.Assets.CatCafe_Prop_Crate_<Pool>` and `_Gold`): the
-- crate that was opened appears on the counter facing you at the same instant, its lid (the child Model ending
-- `_Lid`) swings up on its back hinge as the pop comes out of it, and it fades away a moment later. Before the models
-- land, or for a crate with none, the pop comes off the bare counter as before.
--
-- The crate reel (F103): while the strip slides, the crate sits closed on the counter and its lid knocks on its
-- hinge as hard as the reel runs, easing in, flat out, then settling as the reel slows; the same for every prize, so
-- nothing hints at the rarity. At the stop the lid opens and the pop comes out. The stop is the UI's
-- `Moments.CrateReelLanded` (which a tap's skip fires too) once it has one, else the time Config's CrateReel* numbers
-- give (about 2.9 s after CrateResult). With Reduce Motion the window has no reel, so the crate opens at once.
--
-- A Legendary or Mythical piece is a big pull (F89, luck-and-rare-moments.md 2b): the crate glows in the piece's
-- rarity colour from the moment the prize shows (CrateResult, or the reel's stop), shakes harder and harder for a
-- moment with sparkles rising off it, then its lid blows open and the pop comes out with Pull.screen's confetti on
-- your screen (UI-Engineer holds the big pull card for the shake). With Reduce Motion it glows without shaking.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)

local Catch = require(script.Parent.Catch)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Pull = require(script.Parent.Pull)

local Market = {}

local started = false
local shown: Model? = nil -- the crate on the counter now; the next open takes its place
local opens = 0 -- CrateResults so far, so a reel that stops after the next open began does nothing

-- The window's crate reel (F103): seconds from CrateResult to its stop, its speed up and the start of its slow down.
type Reel = { stop: number, ramp: number, slowFrom: number, slow: number }

-- The stall this player opened the crate at: the nearest one in Workspace within reach (the stall's template in
-- ReplicatedStorage.Assets may carry the tag too).
local function nearestStall(): Instance?
	local best: Instance? = nil
	local bestDistance = Presets.market.within
	for _, station in CollectionService:GetTagged("FishMarket") do
		local at = if station:IsDescendantOf(Workspace) then Context.positionOf(station) else nil
		if at ~= nil then
			local distance = Context.distance(at)
			if distance <= bestDistance then
				best, bestDistance = station, distance
			end
		end
	end
	return best
end

-- Where the pop comes from: the top of the stand-in stall's `FishCrate`, else the middle of the counter's ice on the
-- modelled stall (market.py), measured from its pivot at the base centre with the counter front toward -Z.
local function counterTop(station: Instance): Vector3?
	local crate = station:FindFirstChild("FishCrate", true)
	if crate ~= nil and crate:IsA("BasePart") then
		local part = crate :: BasePart
		return part.Position + Vector3.new(0, Logic.halfExtents(part.CFrame, part.Size).Y, 0)
	end
	local m = Presets.market
	if station:IsA("Model") then
		return ((station :: Model):GetPivot() * CFrame.new(0, m.counterY, m.counterZ)).Position
	end
	return Context.positionOf(station)
end

-- The opened crate's model in ReplicatedStorage.Assets, or nil before the models land.
local function crateTemplate(crateId: string): Model?
	local crate = Catalog.getCrate(crateId)
	local name: string? = if crate ~= nil
		then Logic.crateModelName(crate.area, crate.golden)
		else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if name == nil or assets == nil then
		return nil
	end
	local found = assets:FindFirstChild(name :: string)
	return if found ~= nil and found:IsA("Model") then found :: Model else nil
end

local function lidOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -4) == "_Lid" then
			return child :: Model
		end
	end
	return nil
end

local function removeShown()
	if shown ~= nil then
		shown:Destroy()
		shown = nil
	end
end

-- The reel's timing from Config's CrateReel* numbers, or nil when the window plays no reel: before the UI's reel
-- lands in Config, or with Reduce Motion, which keeps the short fade.
local function reelTiming(): Reel?
	local config = Config :: any
	local landing, top = config.CrateReelLandingTile, config.CrateReelTopSpeed
	local ramp, slow = config.CrateReelRampSeconds, config.CrateReelStopSeconds
	if
		type(landing) ~= "number"
		or type(top) ~= "number"
		or type(ramp) ~= "number"
		or type(slow) ~= "number"
	then
		return nil
	end
	if Context.reducedMotion() then
		return nil
	end
	local stop, slowFrom = Logic.crateReelStop(landing, top, ramp, slow)
	return { stop = stop, ramp = ramp, slowFrom = slowFrom, slow = slow }
end

-- Runs `landed` once, at the reel's stop: the UI's CrateReelLanded moment (a tap's skip fires it too) once Moments
-- has it, with the stop plus reelSafety as a fallback, else the stop itself.
local function whenLanded(reel: Reel, landed: () -> ())
	local done = false
	local connection: any = nil
	local function finish()
		if done then
			return
		end
		done = true
		if connection ~= nil then
			connection:Disconnect()
		end
		landed()
	end
	local seconds = reel.stop
	local moment = (Moments :: any).CrateReelLanded
	if moment ~= nil then
		connection = moment:Connect(finish)
		seconds += Presets.marketCrate.reelSafety
	end
	task.delay(seconds, finish)
end

-- The lid's back edge, its hinge (the crate's front is -Z).
local function hingeOf(lid: Model, facing: CFrame): CFrame
	local box, size = lid:GetBoundingBox()
	local centre = facing:PointToObjectSpace(box.Position)
	local half = Logic.halfExtents(facing:ToObjectSpace(box), size)
	return facing * CFrame.new(centre + Vector3.new(0, -half.Y, half.Z))
end

-- While the reel runs: `target` (the lid on its `about` hinge, or a crate without one on its base) knocks as hard as
-- the reel is fast (Logic.crateReelPace), lifting and, when `tilt`, tipping up a little; the same for every prize.
-- Returns a stop that sets it back where it was at once.
local function knock(target: Model, about: CFrame, reel: Reel, tilt: boolean): () -> ()
	local c = Presets.marketCrate
	local closed = target:GetPivot()
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		if target.Parent ~= nil then
			target:PivotTo(closed)
		end
	end
	connection = RunService.RenderStepped:Connect(function()
		if target.Parent == nil then
			stop()
			return
		end
		local t = os.clock() - began
		local k = Logic.crateReelPace(t, reel.ramp, reel.slowFrom, reel.slow)
			* math.abs(math.sin(2 * math.pi * c.reelHz * t))
		local degrees = if tilt then c.reelRattle * k else 0
		local turn = CFrame.new(0, c.reelHop * k, 0) * CFrame.Angles(math.rad(degrees), 0, 0)
		target:PivotTo(about * turn * about:Inverse() * closed)
	end)
	return stop
end

-- Swings the lid up about its back edge, the hinge, from closed to `lidDegrees` over `seconds`.
local function openLid(lid: Model, facing: CFrame, seconds: number)
	local c = Presets.marketCrate
	local hinge = hingeOf(lid, facing)
	local closed = lid:GetPivot()
	local function swing(degrees: number)
		lid:PivotTo(hinge * CFrame.Angles(math.rad(degrees), 0, 0) * hinge:Inverse() * closed)
	end
	if Context.reducedMotion() then
		swing(c.lidDegrees)
		return
	end
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - began
		if lid.Parent == nil or elapsed >= seconds then
			if connection ~= nil then
				connection:Disconnect()
			end
		end
		if lid.Parent ~= nil then
			swing(Logic.lidAngle(elapsed, seconds, c.lidDegrees))
		end
	end)
end

-- A big pull's crate: a glow in `colour` from now on, then a rattle about its base (`facing`) that grows over
-- crateShake seconds with sparkles rising off it; `done` runs when it ends, the crate back where it stood.
local function rattle(model: Model, facing: CFrame, colour: Color3, done: () -> ())
	local b = Presets.bigPull
	local glow = Instance.new("Highlight")
	glow.FillColor = colour
	glow.FillTransparency = b.glowFill
	glow.OutlineColor = colour
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = b.glowLight.range
	light.Brightness = b.glowLight.brightness
	light.Shadows = false
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	light.Parent = holder
	local placed = model:GetPivot()
	local still = Context.reducedMotion()
	local began, nextSparkle = os.clock(), 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if model.Parent == nil or t >= b.crateShake then
			if connection ~= nil then
				connection:Disconnect()
			end
			if model.Parent ~= nil then
				model:PivotTo(placed)
				done()
			end
			return
		end
		if t >= nextSparkle then
			nextSparkle = t + b.sparkleEvery
			Particles.burst(
				"catchSparkle",
				facing.Position + Vector3.new(0, 0.6, 0),
				b.crateSparkles,
				colour
			)
		end
		if not still then
			local k = t / b.crateShake
			local wave = math.sin(2 * math.pi * b.rattleHz * t)
			local turn = CFrame.new(0, b.rattleHop * k * math.abs(wave), 0)
				* CFrame.Angles(
					0,
					math.rad(b.rattle * k * wave * 0.5),
					math.rad(b.rattle * k * wave)
				)
			model:PivotTo(facing * turn * facing:Inverse() * placed)
		end
	end)
end

-- Puts a copy of the crate on the counter at `top`, its front toward you, and returns its reveal, which opens it and
-- fades it away after a moment: a big pull's crate (`rare`, its rarity colour) glows and shakes first, and `popped`
-- gets the open crate's rim, where the pop comes out, as the lid opens. With a `reel` the lid knocks until then.
local function showCrate(
	template: Model,
	top: Vector3,
	rare: Color3?,
	popped: (Vector3) -> (),
	reel: Reel?
): () -> ()
	removeShown()
	local c = Presets.marketCrate
	local model = template:Clone() :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model:ScaleTo(c.scale)
	-- the base centre under the box, wherever the model's pivot is (the template stands unturned)
	local box, size = model:GetBoundingBox()
	local height = Logic.halfExtents(box, size).Y * 2
	local base = model:GetPivot():PointToObjectSpace(box.Position - Vector3.new(0, height / 2, 0))
	local facing = CFrame.new(top)
	local focus = Context.focus()
	if focus ~= nil and Vector3.new(focus.X - top.X, 0, focus.Z - top.Z).Magnitude > 0.1 then
		facing = CFrame.lookAt(top, Vector3.new(focus.X, top.Y, focus.Z))
	end
	model:PivotTo(facing * CFrame.new(-base))
	model.Name = "EffectsMarketCrate"
	model.Parent = Context.folder()
	shown = model
	local rim = height
	local lid = lidOf(model)
	if lid ~= nil then
		local lidBox, lidSize = lid:GetBoundingBox()
		rim = facing:PointToObjectSpace(lidBox.Position).Y
			- Logic.halfExtents(facing:ToObjectSpace(lidBox), lidSize).Y
	end
	local function open(seconds: number)
		if lid ~= nil then
			openLid(lid, facing, seconds)
		end
		popped(top + Vector3.new(0, rim, 0))
	end
	local settle: () -> () = function() end
	if reel ~= nil then
		if lid ~= nil then
			settle = knock(lid, hingeOf(lid, facing), reel, true)
		else
			settle = knock(model, facing, reel, false)
		end
	end
	return function()
		settle()
		if shown ~= model then
			return -- the next open took its place
		end
		local wait = 0
		if rare ~= nil then
			wait = Presets.bigPull.crateShake
			rattle(model, facing, rare, function()
				open(Presets.bigPull.blowSeconds)
			end)
		else
			open(c.lidSeconds)
		end
		task.delay(c.hold + wait, function()
			if model.Parent == nil then
				return -- the next open took its place
			end
			-- a big pull's glow and light fade with it: a Highlight still draws on a part that has faded out
			local fade = TweenInfo.new(c.fade)
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
				elseif descendant:IsA("Highlight") then
					TweenService
						:Create(descendant, fade, { FillTransparency = 1, OutlineTransparency = 1 })
						:Play()
				elseif descendant:IsA("PointLight") then
					TweenService:Create(descendant, fade, { Brightness = 0 }):Play()
				end
			end
			task.delay(c.fade, function()
				if shown == model then
					shown = nil
				end
				model:Destroy()
			end)
		end)
	end
end

local function opened(crateId: string, decorId: string)
	opens += 1
	local mine = opens
	removeShown() -- a crate still waiting on an earlier reel goes with it
	local def = Catalog.getDecor(decorId)
	local station = nearestStall()
	if def == nil or station == nil then
		return -- walked off before the answer came: the window's toast says what it was
	end
	local top = counterTop(station)
	if top == nil then
		return
	end
	local m = Presets.market
	local rarity = def.rarity or "Common"
	local big = Logic.bigPull(rarity, false)
	local function pop(from: Vector3)
		Particles.burst("dust", from, m.puff, Presets.palette.fishBelly)
		if big then
			-- a Mythical's shockwave runs over the ground round the stall, not the counter top
			local floor = Pull.floorBelow(top, { station }, m.floorDepth)
			Pull.world(from + Vector3.new(0, m.above, 0), top, rarity, floor)
			Pull.screen(rarity, false)
		else
			Catch.pop(from + Vector3.new(0, m.above, 0), top, rarity)
		end
	end
	local reel = reelTiming()
	local template = crateTemplate(crateId)
	local reveal: () -> ()
	if template ~= nil then
		reveal = showCrate(template, top, if big then Presets.rarity[rarity] else nil, pop, reel)
	else
		reveal = function()
			pop(top)
		end
	end
	if reel == nil then
		reveal()
	else
		-- nothing shows the prize before the stop, not even a bare counter's pop
		whenLanded(reel, function()
			if mine == opens then
				reveal()
			end
		end)
	end
end

function Market.start()
	if started then
		return
	end
	started = true
	-- CrateResult(crateId, decorId, duplicate, refund); decorId is "" when the open was refused.
	Net.on("CrateResult", function(crateId: unknown, decorId: unknown)
		if type(crateId) == "string" and type(decorId) == "string" and decorId ~= "" then
			opened(crateId, decorId)
		end
	end)
end

return Market
