--!strict
-- A Legendary or Mythic trait roll's cutscene (#3846, Derek 2026-11-13: "add a quick cutscene animation for
-- legendary+ trait rerolls with some vfx/sound before the menu pops up showing what u got"). The server has already
-- rolled; this only shows it, then hands over to the trait card.
--   Near the pool (atPool): the camera eases to a low front view of the pool as the roll starts and watches the
--   pool's own roll (Effects/MysticPool.roll). As the cat pops back out comes the big moment: a pillar of light in
--   the rarity's colour, a star burst, a ring and confetti, the title ("LEGENDARY TRAIT!") growing in once and the
--   fanfare. After Presets.bigTrait.big seconds the camera eases back and `onReveal` runs (the card).
--   Away from the pool (screen, the Cannon menu): slow turning rays in the rarity's colour, the title and the
--   fanfare for `screenSeconds`, then `onReveal`.
--
--   local skip = BigTraitCut.atPool(station, "legendary", function(reveal) return MysticPool.roll(..., reveal) end, show)
--   local skip = BigTraitCut.screen("mythic", show)
--   -- skip() jumps straight to the card (the card's edge shade calls it on a tap)
--
-- onReveal runs exactly once, whatever happens. Nothing blinks and nothing is random; no near miss, since the colour
-- steps are the pool's own and only go up. The camera is only taken when it is free (not the intro, a cannon flight
-- or another cut) and a spot sees the pool clear; otherwise the pool and the title play without it. Controls and
-- prompts are off only while the camera is held, and a hard cap always gives them back.
--   #3942: a Mythic or Secret roll at the pool is a whole scene (Presets.bigTrait.scenes): letterbox bars, the world
--   dimmed and tinted, the camera slowly circling the pool, sparkles climbing the pillar and, for a Secret, a cat
--   drawn in stars over the pool. The music ducks for it ("hush", then "done").
-- Reduce Motion: no camera move and no particles; the title shows still for `still` seconds.
-- Sound: BigTraitCut.onBeat's "fanfare" (with the rarity); Audio plays the Legendary or Mythical jingle on it.
-- Client only; it sends nothing. Numbers in Presets.bigTrait.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local ContextCut = require(script.Parent.ContextCut)
local FirstBaitCut = require(script.Parent.FirstBaitCut)
local Logic = require(script.Parent.Logic)
local MysticIntroCut = require(script.Parent.MysticIntroCut)
local MysticPool = require(script.Parent.MysticPool)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits"))

local BigTraitCut = {}

export type Beat = "fanfare" | "hush" | "done" -- #3942: hush and done open and close a Mythic or Secret scene

local STEP = "EffectsBigTraitCut"
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

local running = false
local listeners: { (beat: Beat, rarity: string) -> () } = {}

-- Calls `listener("fanfare", rarity)` as the big moment lands, and for a whole scene (#3942) "hush" as it starts and
-- "done" as it ends. Listeners only listen.
function BigTraitCut.onBeat(listener: (beat: Beat, rarity: string) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat, rarity: string)
	for _, listener in listeners do
		task.spawn(listener, name, rarity)
	end
end

-- Whether a roll of `rarity` (a shared/Traits.RARITIES id) gets this cutscene.
function BigTraitCut.wanted(rarity: string): boolean
	return Logic.bigTraitRoll(rarity)
end

-- #3942: seconds the rolled cat rises up the pillar in a roll's whole scene (for MysticPool.roll), 0 for a rarity
-- with none or with Reduce Motion, and the studs it rises to (nil: the pool's own).
function BigTraitCut.liftFor(rarity: string): (number, number?)
	local scene = Logic.bigTraitScene(rarity)
	if scene == nil or Context.reducedMotion() then
		return 0, nil
	end
	return scene.lift, scene.liftHeight
end

-- Whether the camera is held by the cutscene now.
function BigTraitCut.playing(): boolean
	return running
end

-- #3908: the rarity's colour; the Secret rarity has the Secret cats' starlight until shared/Traits gives it one.
local function colourFor(rarity: string): Color3
	if rarity == "secret" then
		return Presets.bigTrait.secretColour
	end
	return MysticPool.colourOf(rarity)
end

-- The title and the rays on their own ScreenGui, over the card's edge shade. Returns the gui and a function that
-- draws them `t` seconds in (the rays turning and fading in, the title's grow).
local function overlay(rarity: string, withRays: boolean): (ScreenGui?, (t: number) -> ())
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil, function(_t: number) end
	end
	local b = Presets.bigTrait
	local sized = Logic.bigTraitSize(rarity)
	local colour = colourFor(rarity)
	local still = Context.reducedMotion()
	local edge = if GuiService:IsTenFootInterface() then b.tvSafe else 0
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsBigTraitCut"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = b.displayOrder

	-- #3908: a Mythic or Secret darkens the screen behind the title a little, so its colour stands out
	local shade: Frame? = nil
	if sized.dim > 0 then
		local dark = Instance.new("Frame")
		dark.Name = "Dim"
		dark.BackgroundColor3 = Color3.fromRGB(16, 10, 32)
		dark.BackgroundTransparency = if still then 1 - sized.dim else 1
		dark.BorderSizePixel = 0
		dark.Size = UDim2.fromScale(1, 1)
		dark.Parent = gui
		shade = dark
	end

	local hub: Frame? = nil
	local rays: { Frame } = {}
	if withRays and not still then
		local centre = Instance.new("Frame")
		centre.Name = "Rays"
		centre.BackgroundTransparency = 1
		centre.AnchorPoint = Vector2.new(0.5, 0.5)
		centre.Position = UDim2.fromScale(0.5, 0.42)
		centre.Size = UDim2.fromScale(1.6, 1.6)
		local square = Instance.new("UIAspectRatioConstraint")
		square.AspectRatio = 1
		square.Parent = centre
		for i = 1, sized.rays do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.new(0.07, 0, 1, 0)
			ray.Rotation = (i - 1) * 180 / sized.rays
			ray.BackgroundColor3 = colour
			ray.BackgroundTransparency = 1
			ray.BorderSizePixel = 0
			-- bright at the middle, gone at both ends
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = ray
			ray.Parent = centre
			table.insert(rays, ray)
		end
		centre.Parent = gui
		hub = centre
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.3 + edge)
	title.Size = UDim2.new(0.9, 0, 0, b.titleSize + 16)
	title.FontFace = FONT
	title.Text = Logic.bigTraitTitle(rarity)
	title.TextColor3 = colour
	title.TextScaled = true
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = b.titleSize
	size.MinTextSize = b.titleMin
	size.Parent = title
	local ink = Instance.new("UIStroke")
	ink.Color = b.titleInk
	ink.Thickness = 4
	ink.Parent = title
	local scale = Instance.new("UIScale")
	scale.Scale = if still then 1 else b.popFrom
	scale.Parent = title
	title.Parent = gui
	gui.Parent = playerGui

	local function draw(t: number)
		if still then
			return
		end
		scale.Scale = Logic.bigTraitPop(t)
		if shade ~= nil then
			shade.BackgroundTransparency = 1 - sized.dim * Logic.smoothstep01(t / b.popSeconds)
		end
		if hub ~= nil then
			hub.Rotation = (t * b.raySpin * 360) % 360
			local seen = 1 - (1 - b.rayFade) * Logic.smoothstep01(t / b.popSeconds)
			for _, ray in rays do
				ray.BackgroundTransparency = seen
			end
		end
	end
	return gui, draw
end

-- Away from the pool: the rays, the title and the fanfare, then onReveal. Returns the skip.
function BigTraitCut.screen(rarity: string, onReveal: () -> ()): () -> ()
	local b = Presets.bigTrait
	local gui, draw = overlay(rarity, true)
	local done = false
	local began = os.clock()
	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(STEP .. "Screen")
		if gui ~= nil then
			gui:Destroy()
		end
		task.spawn(onReveal)
	end
	beat("fanfare", rarity)
	RunService:BindToRenderStep(STEP .. "Screen", Enum.RenderPriority.Last.Value, function()
		local t = os.clock() - began
		draw(t)
		if
			t
			>= (
				if Context.reducedMotion()
					then b.still
					else Logic.bigTraitSize(rarity).screenSeconds
			)
		then
			finish()
		end
	end)
	return finish
end

-- The PlayerModule's controls, or nil without the default player scripts.
local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require -- Roblox's own PlayerModule is not in the Rojo tree
	local ok, controlModule = pcall(function(): any
		return requireAny(module):GetControls()
	end)
	return if ok then controlModule else nil
end

local function setControls(module: any?, on: boolean)
	if module == nil then
		return
	end
	pcall(function()
		if on then
			module:Enable()
		else
			module:Disable()
		end
	end)
end

-- The camera's spot over the pool (Presets.mysticIntro's), swung round until a ray from the pool reaches it clear.
local function clearEye(look: Vector3, front: Vector3, tall: boolean, station: Model): Vector3?
	local p = Presets.mysticIntro
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { station, Context.folder() }
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	for _, degrees in p.swings do
		local eye = Logic.cutAround(
			look,
			front,
			if tall then p.backTall else p.back,
			if tall then p.upTall else p.up,
			degrees
		)
		if Workspace:Raycast(look, eye - look, params) == nil then
			return eye
		end
	end
	return nil
end

-- The big moment's effects at the pool's surface, in the rarity's colour.
-- #3908: a Mythic gets three columns, two rings one after the other and more confetti; a Secret five columns,
-- three rings, the most of everything, a darker screen and a small shake.
local function burst(surface: Vector3, rarity: string)
	local b = Presets.bigTrait
	local sized = Logic.bigTraitSize(rarity)
	local colour = colourFor(rarity)
	for _, offset in Logic.bigTraitBeams(sized.beams, b.beamSpread) do
		Particles.beam(surface + offset, colour, b.beamWidth, sized.beamHeight, sized.big)
	end
	for i = 1, sized.rings do
		task.delay((i - 1) * b.ringGap, function()
			Particles.ring(
				surface + Vector3.new(0, 0.2, 0),
				colour,
				b.ringDiameter * (1 + (i - 1) * 0.35),
				b.ringSeconds
			)
		end)
	end
	Particles.burst(
		"catchSparkle",
		surface + Vector3.new(0, 2, 0),
		sized.stars,
		Presets.palette.sparkle
	)
	local palette = if rarity == "secret"
		then b.secretColours
		elseif rarity == "mythic" then Presets.mysticPool.mythicColours
		else { colour, Presets.palette.sparkle, Presets.palette.offwhite }
	Particles.confetti(surface + Vector3.new(0, 3, 0), sized.confetti, palette)
	if sized.shake > 0 then
		Context.shake(0.35, sized.shake)
	end
end

-- #3942: the whole scene's screen and world pieces: letterbox bars on their own ScreenGui and a ColorCorrection in
-- Lighting (this client's only). Returns a function drawing them at weight `w` (0 none, 1 full) and their clean up.
local function sceneLook(scene: Logic.BigTraitScene): ((w: number) -> (), () -> ())
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui: ScreenGui? = nil
	local bars: { Frame } = {}
	if playerGui ~= nil then
		local holder = Instance.new("ScreenGui")
		holder.Name = "EffectsBigTraitScene"
		holder.ResetOnSpawn = false
		holder.IgnoreGuiInset = true
		holder.DisplayOrder = Presets.bigTrait.displayOrder - 1 -- under the title
		for _, top in { true, false } do
			local bar = Instance.new("Frame")
			bar.Name = if top then "BarTop" else "BarBottom"
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
			bar.Position = UDim2.fromScale(0, if top then 0 else 1)
			bar.Size = UDim2.fromScale(1, 0)
			bar.Parent = holder
			table.insert(bars, bar)
		end
		holder.Parent = playerGui
		gui = holder
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EffectsBigTraitScene"
	grade.Parent = Lighting
	local white = Color3.new(1, 1, 1)
	local function draw(w: number)
		for _, bar in bars do
			bar.Size = UDim2.fromScale(1, scene.bars * w)
		end
		grade.Brightness = -scene.dim * w
		grade.Saturation = scene.saturation * w
		grade.TintColor = white:Lerp(scene.tint, w)
	end
	draw(0)
	local function clean()
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
		grade:Destroy()
	end
	return draw, clean
end

-- #3942: the big moment's extra pieces in a whole scene: sparkles climbing round the pillar and, for a Secret, a cat
-- of stars drawn over the pool, facing the camera. Timed pops only, nothing left behind.
local function sceneBurst(scene: Logic.BigTraitScene, surface: Vector3, colour: Color3)
	local b = Presets.bigTrait
	for i = 1, scene.spiral do
		task.delay((i - 1) * scene.spiralSeconds / math.max(1, scene.spiral), function()
			local at = surface + Logic.sceneSpiral(i, scene.spiral, b.spiralRadius, b.spiralHeight)
			Particles.burst("catchSparkle", at, 3, colour)
		end)
	end
	if not scene.constellation then
		return
	end
	local camera = Workspace.CurrentCamera
	local right = if camera ~= nil then camera.CFrame.RightVector else Vector3.xAxis
	right = Vector3.new(right.X, 0, right.Z)
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.xAxis
	local centre = surface + Vector3.new(0, b.skyHeight, 0)
	for i, point in Logic.CAT_CONSTELLATION do
		task.delay((i - 1) * b.starGap, function()
			local at = centre + right * point.X * b.skyScale + Vector3.yAxis * point.Y * b.skyScale
			Particles.burst("catchSparkle", at, b.starSparkles, colour)
		end)
	end
end

-- Derek 2026-11-13 ("make legendary a smaller one less underwhelming"): a Legendary's words RARE, EPIC and
-- LEGENDARY pop in one after another (Presets.bigTrait.ladder, `ladderGap` apart), each in its tier's colour with a
-- ring of that colour at the pool, the last staying a moment. Returns the seconds until the title.
local function ladder(surface: Vector3): number
	local b = Presets.bigTrait
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local tiers: { string } = b.ladder
	local total = #tiers * b.ladderGap
	if playerGui == nil then
		return total
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsBigTraitLadder"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = b.displayOrder
	gui.Parent = playerGui
	for i, tier in tiers do
		task.delay((i - 1) * b.ladderGap, function()
			if gui.Parent == nil then
				return
			end
			local colour = colourFor(tier)
			Particles.ring(
				surface + Vector3.new(0, 0.2 + i * 0.4, 0),
				colour,
				b.ringDiameter * (0.6 + 0.25 * i),
				0.7
			)
			Particles.burst("catchSparkle", surface + Vector3.new(0, 2 + i, 0), 8 + 4 * i, colour)
			local word = Instance.new("TextLabel")
			word.Name = "Word"
			word.BackgroundTransparency = 1
			word.AnchorPoint = Vector2.new(0.5, 0.5)
			word.Position = UDim2.fromScale(0.5, 0.3)
			word.Size = UDim2.new(0.9, 0, 0, b.ladderSize + 16)
			word.FontFace = FONT
			word.Text = (b.ladderWords :: { [string]: string })[tier] or string.upper(tier)
			word.TextColor3 = colour
			word.TextScaled = true
			local size = Instance.new("UITextSizeConstraint")
			size.MaxTextSize = b.ladderSize + 8 * (i - 1)
			size.MinTextSize = 20
			size.Parent = word
			local ink = Instance.new("UIStroke")
			ink.Color = b.titleInk
			ink.Thickness = 3
			ink.Parent = word
			local scale = Instance.new("UIScale")
			scale.Scale = b.popFrom
			scale.Parent = word
			for _, old in gui:GetChildren() do
				old:Destroy()
			end
			word.Parent = gui
			local began = os.clock()
			local pop: RBXScriptConnection
			pop = RunService.RenderStepped:Connect(function()
				local t = os.clock() - began
				if word.Parent == nil then
					pop:Disconnect()
					return
				end
				scale.Scale = Logic.bigTraitPop(t)
				local fade = Logic.smoothstep01((t - (b.ladderGap - 0.12)) / 0.12)
				word.TextTransparency = fade
				ink.Transparency = fade
				if t >= b.ladderGap then
					pop:Disconnect()
					word:Destroy()
				end
			end)
		end)
	end
	task.delay(total + 0.1, function()
		gui:Destroy()
	end)
	return total
end

-- Near the pool: see the top of this file. `roll(reveal)` starts the pool's own roll with `reveal` as its onReveal
-- and returns the roll's skip. Returns the skip for the whole cutscene.
function BigTraitCut.atPool(
	station: Model,
	rarity: string,
	roll: (reveal: () -> ()) -> () -> (),
	onReveal: () -> ()
): () -> ()
	local b = Presets.bigTrait
	local rig = MysticPool.rig(station)
	local camera = Workspace.CurrentCamera
	local eye: Vector3? = nil
	local look = rig.surface + Vector3.new(0, Presets.mysticIntro.lookUp, 0)
	if
		not running
		and not Context.reducedMotion()
		and camera ~= nil
		and camera.CameraType == Enum.CameraType.Custom
		and not ContextCut.playing()
		and not FirstBaitCut.playing()
		and not MysticIntroCut.playing()
	then
		eye = clearEye(look, rig.front, camera.ViewportSize.X < camera.ViewportSize.Y, station)
	end

	local began = os.clock()
	local finished = false
	local skipping = false
	local bigAt: number? = nil -- when the big moment began
	local titleAt: number? = nil -- when the title shows (after a Legendary's word ladder)
	local outFrom: number? = nil -- when the swing back began
	local outWeight = 1
	local w = 0
	local gui: ScreenGui? = nil
	local draw: (t: number) -> () = function(_t: number) end
	local held = false
	local start = if camera ~= nil then camera.CFrame else CFrame.new()
	local subject = if camera ~= nil then camera.CameraSubject else nil
	local module: any? = nil
	local promptsWere = ProximityPromptService.Enabled
	local rollSkip: (() -> ())? = nil
	-- #3942: a Mythic or Secret gets the whole scene, only with the camera held (decided below)
	local scene: Logic.BigTraitScene? = if eye ~= nil then Logic.bigTraitScene(rarity) else nil
	local sceneDraw: (w: number) -> () = function(_w: number) end
	local sceneClean: (() -> ())? = nil

	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
		local clean: (() -> ())? = sceneClean
		if clean ~= nil then
			sceneClean = nil
			(clean :: () -> ())()
			beat("done", rarity)
		end
		if held then
			held = false
			local cam = Workspace.CurrentCamera
			if cam ~= nil then
				cam.CFrame = start
				cam.CameraType = Enum.CameraType.Custom
				if subject ~= nil and subject.Parent ~= nil then
					cam.CameraSubject = subject
				end
			end
			setControls(module, true)
			ProximityPromptService.Enabled = promptsWere
			running = false
		end
		task.spawn(onReveal)
	end

	-- the pool's reveal (the cat popping back out) starts the big moment instead of the card
	local function big()
		if skipping or finished or bigAt ~= nil then
			return
		end
		bigAt = os.clock()
		burst(rig.surface, rarity)
		if scene ~= nil then
			sceneBurst(scene, rig.surface, colourFor(rarity))
		end
		if rarity == "legendary" and not Context.reducedMotion() then
			-- Derek 2026-11-13: RARE, EPIC, LEGENDARY climb in first, each with a gold ring, then the title
			local wait = ladder(rig.surface)
			titleAt = os.clock() + wait
			task.delay(wait, function()
				if finished or skipping then
					return
				end
				gui, draw = overlay(rarity, false)
				beat("fanfare", rarity)
			end)
			return
		end
		titleAt = bigAt
		gui, draw = overlay(rarity, false)
		beat("fanfare", rarity)
	end

	local function swingBack(now: number, quick: boolean)
		if outFrom == nil then
			outFrom = now
			outWeight = w
			if quick then
				outWeight = -w -- a negative weight marks the quick swing (skipOut)
			end
		end
	end

	if eye ~= nil and camera ~= nil then
		held = true
		running = true
		module = controls()
		setControls(module, false)
		ProximityPromptService.Enabled = false
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local away = if eye ~= nil then CFrame.lookAt(eye, look) else start
	if scene ~= nil then
		sceneDraw, sceneClean = sceneLook(scene)
		beat("hush", rarity)
	end

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		local t = now - began
		local character = Players.LocalPlayer.Character
		if
			t >= b.cap
			or character == nil
			or character.Parent == nil
			or not station:IsDescendantOf(game)
		then
			finish()
			return
		end
		local at = bigAt
		if at ~= nil then
			local shownAt = titleAt
			if shownAt ~= nil and now >= shownAt then
				draw(now - shownAt)
			end
			if
				now - at
				>= (if Context.reducedMotion() then b.still else Logic.bigTraitSize(rarity).big)
			then
				swingBack(now, false)
			end
		end
		local back = outFrom
		if back ~= nil then
			local quick = outWeight < 0
			local k = math.clamp((now - back) / (if quick then b.skipOut else b.swingOut), 0, 1)
			w = math.abs(outWeight) * (1 - Logic.smoothstep01(k))
			if k >= 1 or not held then
				finish()
				return
			end
		else
			w = Logic.smoothstep01(t / b.swingIn)
		end
		local cam = Workspace.CurrentCamera
		local shot = away
		local circling: Logic.BigTraitScene? = scene
		if circling ~= nil and eye ~= nil then
			-- #3942: the slow turn round the pool, eased in and out over the whole scene
			local turn = circling.orbit * Logic.smoothstep01(t / circling.orbitSeconds)
			-- as the cat rises up the pillar the camera tilts up to half its height, so it stays in frame
			local raisedAt: number? = bigAt
			local tilt = if raisedAt ~= nil
				then (circling.liftHeight or Presets.mysticPool.liftHeight) * 0.5 * Logic.smoothstep01(
					(now - raisedAt) / math.max(circling.lift, 0.1)
				)
				else 0
			shot = CFrame.lookAt(
				Logic.sceneOrbit(look, eye :: Vector3, turn),
				look + Vector3.new(0, tilt, 0)
			)
			sceneDraw(w)
		end
		if held and cam ~= nil then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = start:Lerp(shot, w)
		end
	end)

	rollSkip = roll(big)

	return function()
		if finished then
			return
		end
		skipping = true
		local skipRoll: (() -> ())? = rollSkip
		rollSkip = nil
		if skipRoll ~= nil then
			(skipRoll :: () -> ())() -- the pool jumps to its end; its reveal lands on `big`, which does nothing now
		end
		if gui ~= nil then
			gui:Destroy()
			gui = nil
		end
		if held then
			swingBack(os.clock(), true)
		else
			finish()
		end
	end
end

-- #3942: someone else's Mythic (or better) roll at the pool, seen from nearby: the pillar, rings, stars and confetti
-- of the big moment and the scene's spiral (a Secret's star cat too), with no camera, bars or title. Within
-- Presets.bigTrait.seenRadius studs of the pool, once per roll, never for this player's own roll (its scene plays),
-- not under Reduce Motion, and not for a mark older than `seenFresh` seconds (joining after it).
local function seenRoll(station: Model)
	local b = Presets.bigTrait
	local at = station:GetAttribute(Traits.ROLL_AT_ATTRIBUTE)
	local by = station:GetAttribute(Traits.ROLL_BY_ATTRIBUTE)
	local rarity = station:GetAttribute(Traits.ROLL_RARITY_ATTRIBUTE)
	if type(at) ~= "number" or type(rarity) ~= "string" or by == Players.LocalPlayer.UserId then
		return
	end
	if Workspace:GetServerTimeNow() - at > b.seenFresh or Context.reducedMotion() then
		return
	end
	local scene = Logic.bigTraitScene(rarity)
	if scene == nil or rarity == "legendary" then -- another's Legendary stays theirs
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local rig = MysticPool.rig(station)
	if
		root == nil
		or not root:IsA("BasePart")
		or (root.Position - rig.surface).Magnitude > b.seenRadius
	then
		return
	end
	-- the server rolled as the roller's scene began; the pillar goes up about when theirs does
	task.delay(b.seenDelay, function()
		if station:IsDescendantOf(game) then
			burst(rig.surface, rarity)
			sceneBurst(scene, rig.surface, colourFor(rarity))
		end
	end)
end

-- #3942: watches the Mystic Pool station for other players' big rolls (seenRoll). Started once with the effects.
function BigTraitCut.watchPool()
	-- weak keys: a station that streams out and back is a new instance, and the old one is let go
	local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function watch(station: Instance)
		if watched[station] or not station:IsA("Model") then
			return
		end
		watched[station] = true
		station:GetAttributeChangedSignal(Traits.ROLL_AT_ATTRIBUTE):Connect(function()
			seenRoll(station :: Model)
		end)
	end
	for _, station in CollectionService:GetTagged(Traits.TAG) do
		watch(station)
	end
	CollectionService:GetInstanceAddedSignal(Traits.TAG):Connect(watch)
end

return BigTraitCut
