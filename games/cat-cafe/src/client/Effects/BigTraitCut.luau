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
-- Reduce Motion: no camera move and no particles; the title shows still for `still` seconds.
-- Sound: BigTraitCut.onBeat's "fanfare" (with the rarity); Audio plays the Legendary or Mythical jingle on it.
-- Client only; it sends nothing. Numbers in Presets.bigTrait.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
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

local BigTraitCut = {}

export type Beat = "fanfare"

local STEP = "EffectsBigTraitCut"
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

local running = false
local listeners: { (beat: Beat, rarity: string) -> () } = {}

-- Calls `listener("fanfare", rarity)` as the big moment lands. Listeners only listen.
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
			draw(now - at)
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
		if held and cam ~= nil then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = start:Lerp(away, w)
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

return BigTraitCut
