--!strict
-- #5112 station unlock cutscene (Derek 2026-11-17 15:17 UTC; Design-Agent's spec
-- Design-Agent/station-unlock-2026-11-17/station-unlock-cutscene.md): right after a rank up that unlocks a big station
-- (Tier 8 Fusion Observatory, 9 Ticket Booth, 10 Dragon Keep; Presets.stationCut.stations), a quick fade takes the
-- camera to the station from three quarters front on a slow push in; it appears (hidden, then scaling up from
-- `fromScale` with a bigger StationReveal burst: gold beam, sparkles, confetti and two rings); a big "UNLOCKED!" label
-- with its name and one line; then a quick fade back and control returns. About 4.5 s. One tap, click or gamepad
-- button skips it (after `skipAfter`). No black bars (Derek #4366). Reduce Motion: no push in, no scale, only the
-- sparkles. Low performance halves the pieces.
--
-- Gameplay-Engineer owns the trigger (after RANK UP, once per account, the stream request, holding the cards that
-- follow, switch `stationCut`) and calls StationUnlockCut.play(tier, done). play returns false, and done is never
-- called, when it cannot run: no station for that tier, the station is not streamed in, another script holds the
-- camera or a cut is already playing. Then the caller shows the Unlocked card ("fallback"). Otherwise done(outcome)
-- comes once, "watched" or "skipped". StationUnlockCut.onReveal(listener) tells Sound the moment the station appears.
-- This client only; no remotes.
--
-- Sync's Studio run (2026-11-17): the camp stations' three quarters view looked into their area gates, so the view is
-- tried at each of `views` (degrees from the front, best first) with a ray from the station to the camera, and the
-- first clear one wins; with none clear, the one that sees furthest, pulled in to just short of what is in the way.
-- A station StationLockController hid below its tier (`locked`) comes back fully shown, never as it was hidden. The
-- HUD, toasts and cards are the caller's to put away (UI.tips.clearStage, as ContextCut's caller does): nothing here
-- touches another ScreenGui (Review-QA, #5127).
--
-- #5550 (switch `cutsQuick`, read as the cut starts): the quick cut of Presets.stationCut.quick, about 2 s with no skip
-- and over by `cap` seconds past its end whatever happens, and only for the tiers in its `plays` (no Tier 3 Cat Arcade:
-- StationUnlockCut.plays false, so the caller gives the toast and the Arcade shows as StationTiers opens it). Off keeps
-- the cut above exactly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local StationUnlockCut = {}

local STEP = "EffectsStationUnlockCut"
local FONT_ID = "rbxasset://fonts/families/FredokaOne.json"
local QUICK_FLAG = "LiveFlag_cutsQuick"

local running = false
local revealListeners: { (tier: number) -> () } = {}

export type Station = { tag: string, name: string, line: string, locked: boolean? }
export type View = { yaw: number, free: number } -- studs the camera can stand back at that turn before a hit

-- The view to film from: the first in `views` order with `want` studs free, else the one with the most room. Pure.
function StationUnlockCut.bestView(views: { View }, want: number): View?
	local best: View? = nil
	for _, view in views do
		if view.free >= want then
			return view
		end
		if best == nil or view.free > (best :: View).free then
			best = view
		end
	end
	return best
end

-- The station a rank up to `tier` unlocks, nil for a tier with no cut.
function StationUnlockCut.stationFor(tier: unknown): Station?
	if type(tier) ~= "number" then
		return nil
	end
	return Presets.stationCut.stations[tier :: number]
end

-- Where the cut is at `t` seconds: the black fade's opacity (0 clear, 1 black), whether the camera is at the station,
-- the push in 0 to 1, the station's grow 0 to 1 (nil before it appears) and the label's opacity. Pure.
function StationUnlockCut.at(
	t: number,
	p: typeof(Presets.stationCut)
): (number, boolean, number, number?, number)
	local fade = 0
	if t < p.fade then
		fade = t / p.fade
	elseif t < p.fade * 2 then
		fade = 1 - (t - p.fade) / p.fade
	elseif t >= p.endAt and t < p.endAt + p.fade then
		fade = (t - p.endAt) / p.fade
	elseif t >= p.endAt + p.fade then
		fade = 1 - math.min(1, (t - p.endAt - p.fade) / p.fade)
	end
	local there = t >= p.fade and t < p.endAt + p.fade
	local push = math.clamp((t - p.fade) / math.max(p.endAt - p.fade, 1e-6), 0, 1)
	local grow: number? = nil
	if t >= p.appearAt then
		grow = math.clamp((t - p.appearAt) / p.grow, 0, 1)
	end
	local label = 0
	if t >= p.labelAt and t < p.endAt then
		label = math.min(1, (t - p.labelAt) / p.labelIn)
	elseif t >= p.endAt then
		label = math.max(0, 1 - (t - p.endAt) / p.fade)
	end
	return math.clamp(fade, 0, 1), there, push, grow, label
end

-- The numbers a cut plays with: Presets.stationCut, with its `quick` fields over them when `quick`. Pure.
function StationUnlockCut.preset(quick: boolean): typeof(Presets.stationCut)
	local base = Presets.stationCut
	if not quick then
		return base
	end
	local out = table.clone(base) :: { [string]: any }
	for key, value in base.quick :: { [string]: any } do
		out[key] = value
	end
	return out :: any
end

-- Whether a rank up to `tier` gets a cut: a station for it, and with `quick`, one in the quick cut's `plays`. Pure.
function StationUnlockCut.plays(tier: unknown, quick: boolean): boolean
	if StationUnlockCut.stationFor(tier) == nil then
		return false
	end
	if not quick then
		return true
	end
	local plays: { [number]: boolean } = Presets.stationCut.quick.plays
	return plays[tier :: number] == true
end

-- Whether the quick cuts are on (switch `cutsQuick`).
function StationUnlockCut.quick(): boolean
	return ReplicatedStorage:GetAttribute(QUICK_FLAG) == true
end

-- The whole cut's length.
function StationUnlockCut.length(p: typeof(Presets.stationCut)): number
	return p.endAt + p.fade * 2
end

function StationUnlockCut.onReveal(listener: (tier: number) -> ())
	table.insert(revealListeners, listener)
end

function StationUnlockCut.playing(): boolean
	return running
end

local function stationModel(tag: string): Model?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

-- The PlayerModule's controls (as ContextCut), nil without the default player scripts.
local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require
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

type Screen = { gui: ScreenGui, black: Frame, title: TextLabel, name: TextLabel, line: TextLabel }

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	y: number,
	colour: Color3
): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.BackgroundTransparency = 1
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, y)
	made.Size = UDim2.new(0.9, 0, 0, size * 1.3)
	made.FontFace = Font.new(FONT_ID, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	made.TextSize = size
	made.TextScaled = false
	made.TextWrapped = true
	made.TextColor3 = colour
	made.TextTransparency = 1
	made.Text = text
	made.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, size / 14)
	stroke.Color = Color3.fromRGB(60, 36, 20)
	stroke.Transparency = 1
	stroke.Parent = made
	made.Parent = parent
	return made
end

local function makeScreen(station: Station): Screen?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local p = Presets.stationCut
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsStationUnlockCut"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = p.displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local black = Instance.new("Frame")
	black.Name = "Fade"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.ZIndex = 3
	black.Parent = gui
	local view = Workspace.CurrentCamera
	local small = view ~= nil and view.ViewportSize.Y < p.smallScreen
	local k = if small then p.smallScale else 1
	local screen = {
		gui = gui,
		black = black,
		title = label(
			gui,
			"Unlocked",
			"UNLOCKED!",
			math.floor(p.titleSize * k),
			p.titleY,
			Presets.palette.golden
		),
		name = label(
			gui,
			"Station",
			station.name,
			math.floor(p.nameSize * k),
			p.nameY,
			Color3.new(1, 1, 1)
		),
		line = label(
			gui,
			"Line",
			station.line,
			math.floor(p.lineSize * k),
			p.lineY,
			Color3.new(1, 1, 1)
		),
	}
	gui.Parent = playerGui
	return screen
end

local function drawLabels(screen: Screen, a: number)
	for _, text in { screen.title, screen.name, screen.line } do
		text.TextTransparency = 1 - a
		local stroke = text:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			(stroke :: UIStroke).Transparency = 1 - a
		end
	end
end

-- The burst as the station appears: StationReveal's, made bigger (Presets.stationCut.burst).
local function burst(model: Model)
	local b = Presets.stationCut.burst
	local frame, size = model:GetBoundingBox()
	local foot = frame.Position - Vector3.new(0, size.Y / 2, 0)
	local over = foot + Vector3.new(0, size.Y + b.lift, 0)
	local few = Context.lowPerformance
	Particles.burst(
		"catchSparkle",
		over,
		if few then b.sparkles // 2 else b.sparkles,
		Presets.palette.golden
	)
	if Context.reducedMotion() then
		return
	end
	Particles.beam(foot, Presets.palette.golden, b.beamWidth, b.beamHeight, b.beamSeconds)
	Particles.confetti(
		over,
		if few then b.confetti // 2 else b.confetti,
		Presets.stationReveal.colours
	)
	local ring = math.max(size.X, size.Z) + b.ringPad
	for i = 1, b.rings do
		task.delay((i - 1) * b.ringGap, function()
			Particles.ring(
				foot + Vector3.new(0, 0.2, 0),
				Presets.palette.golden,
				ring * i,
				b.ringSeconds
			)
		end)
	end
end

type Hidden = { [Instance]: number }

-- Hides every part and decal of `model` on this client (LocalTransparencyModifier), remembering what each had; a
-- `locked` station is remembered as shown (its lock opened with this rank up).
local function hide(model: Model, saved: Hidden, locked: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			if saved[part] == nil then
				saved[part] = if locked then 0 else part.LocalTransparencyModifier
			end
			part.LocalTransparencyModifier = 1
		elseif item:IsA("Decal") then
			local decal = item :: Decal
			if saved[decal] == nil then
				saved[decal] = if locked then 0 else decal.LocalTransparencyModifier
			end
			decal.LocalTransparencyModifier = 1
		end
	end
end

-- Puts `share` of the way back from hidden (0) to as it was (1).
local function show(saved: Hidden, share: number)
	for item, was in saved do
		if item.Parent == nil then
			continue
		end
		local value = 1 - (1 - was) * share
		if item:IsA("BasePart") then
			(item :: BasePart).LocalTransparencyModifier = value
		elseif item:IsA("Decal") then
			(item :: Decal).LocalTransparencyModifier = value
		end
	end
end

-- How far the camera can stand back from `look` along `dir` (rising `rise` per stud) before something seen is in the
-- way: the station itself, characters and see-through or ray-proof parts do not count.
local function freeAlong(
	look: Vector3,
	dir: Vector3,
	rise: number,
	distance: number,
	model: Model
): number
	local skip: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(skip, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local way = (dir + Vector3.new(0, rise, 0)).Unit
	local reach = distance * (dir + Vector3.new(0, rise, 0)).Magnitude
	for _ = 1, 6 do
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(look, way * reach, params)
		if hit == nil then
			return distance
		end
		local part = hit.Instance
		if part.Transparency < 0.8 then
			return (hit.Position - look).Magnitude / reach * distance
		end
		table.insert(skip, part)
	end
	return 0
end

-- Plays the cut for a rank up to `tier`; true when it took the camera (see the top). `done(outcome)` once at the end.
function StationUnlockCut.play(tier: number, done: (outcome: string) -> ()): boolean
	local station = StationUnlockCut.stationFor(tier)
	local camera = Workspace.CurrentCamera
	local quick = StationUnlockCut.quick()
	if
		station == nil
		or not StationUnlockCut.plays(tier, quick)
		or running
		or camera == nil
		or camera.CameraType ~= Enum.CameraType.Custom
	then
		return false
	end
	local model = stationModel(station.tag)
	if model == nil then
		return false
	end
	local p = StationUnlockCut.preset(quick)
	local reduced = Context.reducedMotion()
	local pivot = model:GetPivot()
	local frame, size = model:GetBoundingBox()
	local look = frame.Position + Vector3.new(0, size.Y * p.lookUp, 0)
	local extent = math.max(size.X, size.Y, size.Z)
	-- three quarters front: the model's front turned `yaw` degrees, flat
	local far = math.clamp(extent * p.far, p.nearest, p.farthest)
	local near = math.clamp(extent * p.near, p.nearest, p.farthest)
	local function dirAt(yaw: number): Vector3
		local front = (pivot * CFrame.Angles(0, math.rad(yaw), 0)).LookVector * p.faceSign
		local flat = Vector3.new(front.X, 0, front.Z)
		return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	end
	local tried: { View } = {}
	for _, yaw in p.views do
		table.insert(tried, { yaw = yaw, free = freeAlong(look, dirAt(yaw), p.rise, far, model) })
	end
	local view = StationUnlockCut.bestView(tried, far)
	local dir = dirAt(if view ~= nil then view.yaw else p.yaw)
	if view ~= nil and view.free < far then
		-- nothing clear all the way: stand just short of what is in the way, pushing in from there
		far = math.max(view.free - p.clearance, p.closest)
		near = math.min(near, far * p.near / p.far)
	end
	local baseScale = model:GetScale()

	running = true
	local start = camera.CFrame
	local subject = camera.CameraSubject
	local module = controls()
	local promptsWere = ProximityPromptService.Enabled
	setControls(module, false)
	ProximityPromptService.Enabled = false
	local screen = makeScreen(station)
	local saved: Hidden = {}
	local began = os.clock()
	local length = StationUnlockCut.length(p)
	local skipAt: number? = nil -- the cut's time when a skip came; the fade back starts there
	local revealed = false
	local grownTo = 1
	local finished = false
	local input: RBXScriptConnection? = nil

	local scaledAt = -math.huge
	-- ScaleTo moves every part of the model, so the grow is drawn at `scaleHz` (and always its last step)
	local function setScale(k: number)
		if reduced then
			return
		end
		local now = os.clock()
		if k ~= 1 and k ~= p.fromScale and now - scaledAt < 1 / p.scaleHz then
			return
		end
		scaledAt = now
		local want = baseScale * k
		if math.abs(want - model:GetScale()) > 1e-4 then
			pcall(function()
				model:ScaleTo(want)
			end)
		end
	end

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if input ~= nil then
			input:Disconnect()
		end
		show(saved, 1)
		if grownTo ~= 1 then
			setScale(1)
		end
		if screen ~= nil then
			screen.gui:Destroy()
		end
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
		task.spawn(done, if skipped then "skipped" else "watched")
	end

	input = UserInputService.InputBegan:Connect(function(event: InputObject)
		local t = os.clock() - began
		if not p.skip or skipAt ~= nil or t < p.skipAfter then
			return
		end
		local kind = event.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind.Name:sub(1, 7) == "Gamepad"
		then
			skipAt = t
		end
	end)

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		if cam == nil or model.Parent == nil then
			finish(skipAt ~= nil)
			return
		end
		local t = os.clock() - began
		-- a skip jumps to the end's fade from where it is
		local at = skipAt
		local timeline = t
		if at ~= nil then
			timeline = math.max(t - at, 0) + p.endAt
			if t < p.fade then
				timeline = p.endAt -- still fading in: go straight to the fade out
			end
		end
		if timeline >= length or t >= length + p.cap then
			finish(at ~= nil)
			return
		end
		local fade, there, push, grow, a = StationUnlockCut.at(timeline, p)
		cam.CameraType = Enum.CameraType.Scriptable
		if there then
			local k = if reduced then 0 else Logic.easeInOut(push)
			local distance = far + (near - far) * k
			local eye = look + dir * distance + Vector3.new(0, distance * p.rise, 0)
			cam.CFrame = CFrame.lookAt(eye, look)
			if grow == nil then
				hide(model, saved, station.locked == true)
				if not reduced then
					setScale(p.fromScale)
					grownTo = p.fromScale
				end
			else
				if not revealed then
					revealed = true
					burst(model)
					for _, listener in revealListeners do
						task.spawn(listener, tier)
					end
				end
				local g = grow :: number
				show(saved, math.min(1, g * 2))
				if not reduced then
					local k2 = p.fromScale
						+ (1 - p.fromScale) * math.min(Logic.easeOutBack(g), 1.04)
					setScale(k2)
					grownTo = if g >= 1 then 1 else k2
				end
			end
		else
			cam.CFrame = start
		end
		if screen ~= nil then
			screen.black.BackgroundTransparency = 1 - fade
			drawLabels(screen, a)
		end
	end)
	return true
end

return StationUnlockCut
