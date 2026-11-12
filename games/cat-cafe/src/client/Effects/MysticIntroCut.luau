--!strict
-- The Mystic Pool's first walk-up cutscene (#3430, Derek 2026-11-12: "a quick cutscene when first going up to the
-- trait reroll stand"). About 7 seconds, this player only:
--   1. the camera eases from the player to a low front view of the pool and the moon arch;
--   2. Sage Sorrel raises his staff and waves it, and the liquid steps through its five colours (grey, green, blue,
--      gold, purple) with a bubble burst on each;
--   3. a cat's silhouette rises from the liquid in a soft sparkle while a card line reads the preset's words;
--   4. the camera eases back to the player and `onDone` runs (Gameplay opens the pool's menu there).
--
--   local playing = MysticIntroCut.play(station, function(outcome, seconds) openMenu() end)
--
-- Gameplay-Engineer owns when it plays (the walk-up, the once per account mark on the server, the tutorial and
-- window checks) and what follows. This only shows it. `onDone(outcome, seconds)` runs exactly once whenever play
-- returned true: outcome "watched" or "skipped" and the seconds seen, for the `mystic_intro` count. play returns
-- false, changing nothing and never calling onDone, when the camera is busy (the intro, a cannon flight, another
-- cut), the pool is too far or every camera spot is walled in.
-- A tap, click, key or gamepad button skips it straight to step 4; the "Tap to skip" label shows from the first
-- frame. Controls and prompts are off only while it runs and a hard cap always gives them back. It shows no roll,
-- no result, no odds and no price, and nothing in it is random: the five colours always play in order.
-- Reduce Motion: no camera move, no wave and no swirl; the card line shows for `still` seconds, then onDone.
-- Sound: MysticIntroCut.onBeat's "step" (1 to 5) and "rise" beats; Audio plays the pool's own chimes on them.
-- Client only; it sends nothing. Numbers in Presets.mysticIntro.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local ContextCut = require(script.Parent.ContextCut)
local FirstBaitCut = require(script.Parent.FirstBaitCut)
local Logic = require(script.Parent.Logic)
local MysticPool = require(script.Parent.MysticPool)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits"))

local MysticIntroCut = {}

export type Outcome = "watched" | "skipped"
export type Beat = "step" | "rise"

local STEP = "EffectsMysticIntroCut"
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

local running = false
local listeners: { (beat: Beat, step: number, at: Vector3) -> () } = {}

-- Calls `listener(beat, step, at)` on each colour step ("step", 1 to 5) and as the silhouette rises ("rise"); `at`
-- is the liquid's surface. Listeners only listen.
function MysticIntroCut.onBeat(listener: (beat: Beat, step: number, at: Vector3) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat, step: number, at: Vector3)
	for _, listener in listeners do
		task.spawn(listener, name, step, at)
	end
end

-- The skip line in the words of the input the player last used.
local function skipWords(): string
	local last = UserInputService:GetLastInputType().Name
	if last:sub(1, 7) == "Gamepad" then
		return "Press A to skip"
	elseif
		last == "Touch" or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	then
		return "Tap to skip"
	end
	return "Click to skip"
end

-- The cutscene's own ScreenGui: the skip label in the bottom right from the first frame and the card line at the
-- bottom middle (hidden until `Line.Visible`). Both keep inside a TV's safe edge.
local function overlay(withSkip: boolean): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local p = Presets.mysticIntro
	local edge = if GuiService:IsTenFootInterface() then p.tvSafe else 0
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsMysticIntroCut"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = p.displayOrder

	local skip = Instance.new("TextLabel")
	skip.Name = "Skip"
	skip.BackgroundTransparency = 1
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1 - edge, -24, 1 - edge, -24)
	skip.Size = UDim2.fromOffset(160, 28)
	skip.FontFace = FONT
	skip.TextSize = p.skipSize
	skip.TextXAlignment = Enum.TextXAlignment.Right
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.TextTransparency = p.skipFade
	skip.Text = skipWords()
	skip.Visible = withSkip
	local skipStroke = Instance.new("UIStroke")
	skipStroke.Thickness = 2
	skipStroke.Transparency = p.skipFade
	skipStroke.Parent = skip
	skip.Parent = gui

	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0.5, 1)
	line.Position = UDim2.new(0.5, 0, 1 - edge, -p.lineUp)
	line.Size = UDim2.new(0.86, 0, 0, p.lineHeight)
	line.BackgroundColor3 = p.lineCard
	line.BorderSizePixel = 0
	line.FontFace = FONT
	line.Text = p.words
	line.TextColor3 = p.lineText
	line.TextScaled = true
	line.Visible = false
	local widest = Instance.new("UISizeConstraint")
	widest.MaxSize = Vector2.new(p.lineWidth, math.huge)
	widest.Parent = line
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = p.lineSize
	size.MinTextSize = 10
	size.Parent = line
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = line
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = line
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = p.lineText
	stroke.Thickness = 3
	stroke.Parent = line
	line.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function showLine(gui: ScreenGui?, on: boolean)
	local line = if gui ~= nil then gui:FindFirstChild("Line") else nil
	if line ~= nil and line:IsA("GuiObject") then
		(line :: GuiObject).Visible = on
	end
end

-- A dark cat shape to rise from the liquid: a copy of the preset's cat with every surface painted one colour, or nil
-- without that asset (the sparkle alone then).
local function silhouette(): Model?
	local p = Presets.mysticIntro
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil then assets:FindFirstChild(p.cat) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = (source :: Model):Clone() :: Model
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Color = p.shade
			part.Material = Enum.Material.SmoothPlastic
			if part:IsA("MeshPart") then
				(part :: MeshPart).TextureID = ""
			end
		elseif
			d:IsA("Decal")
			or d:IsA("SurfaceAppearance")
			or d:IsA("Script")
			or d:IsA("LocalScript")
		then
			d:Destroy()
		end
	end
	copy.Name = "MysticIntro_Cat"
	copy.Parent = Context.folder()
	return copy
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

-- The camera's spot: `back` studs out along the pool's front and `up` studs up from `look`, swung round by each of
-- the preset's angles until one ray from the pool reaches it clear. Nil when none does.
local function clearEye(look: Vector3, front: Vector3, tall: boolean, station: Model): Vector3?
	local p = Presets.mysticIntro
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { station }
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

local function colourAt(i: number): Color3
	return MysticPool.colourOf(Traits.RARITIES[i].id)
end

-- Reduce Motion: nothing moves; the card line shows for `still` seconds (a press ends it sooner).
local function playStill(onDone: (outcome: Outcome, seconds: number) -> ())
	local p = Presets.mysticIntro
	local gui = overlay(false)
	showLine(gui, true)
	local began = os.clock()
	local finished = false
	local input: RBXScriptConnection? = nil
	local function finish(outcome: Outcome)
		if finished then
			return
		end
		finished = true
		if input ~= nil then
			input:Disconnect()
		end
		if gui ~= nil then
			gui:Destroy()
		end
		running = false
		task.spawn(onDone, outcome, os.clock() - began)
	end
	input = UserInputService.InputBegan:Connect(function(pressed: InputObject)
		local kind = pressed.UserInputType
		if
			os.clock() - began >= p.skipAfter
			and (
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.Touch
				or kind.Name:sub(1, 7) == "Gamepad"
			)
		then
			finish("skipped")
		end
	end)
	task.delay(p.still, finish, "watched")
end

-- Plays the cutscene at `station` (the pool's Model); see the top of this file.
function MysticIntroCut.play(
	station: Model,
	onDone: (outcome: Outcome, seconds: number) -> ()
): boolean
	local camera = Workspace.CurrentCamera
	if
		running
		or camera == nil
		or camera.CameraType ~= Enum.CameraType.Custom
		or ContextCut.playing()
		or FirstBaitCut.playing()
		or station.Parent == nil
	then
		return false
	end
	local p = Presets.mysticIntro
	local rig = MysticPool.rig(station)
	if Context.distance(rig.surface) > p.maxDistance then
		return false
	end
	if Context.reducedMotion() then
		running = true
		playStill(onDone)
		return true
	end
	local look = rig.surface + Vector3.new(0, p.lookUp, 0)
	local eye = clearEye(look, rig.front, camera.ViewportSize.X < camera.ViewportSize.Y, station)
	if eye == nil then
		return false
	end
	local away = CFrame.lookAt(eye, look)
	local start = camera.CFrame

	running = true
	local subject = camera.CameraSubject
	local module = controls()
	local promptsWere = ProximityPromptService.Enabled
	setControls(module, false)
	ProximityPromptService.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local gui = overlay(true)

	local swirlSeconds = p.step * p.steps
	local began = os.clock()
	local outFrom: number? = nil -- when the swing back began
	local outWeight = 1
	local outColour = rig.rest
	local outArm = 0
	local skipped = false
	local finished = false
	local lastStep = 0
	local colour = rig.rest
	local arm = 0
	local cat: Model? = nil
	local risen = false
	local input: RBXScriptConnection? = nil

	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if input ~= nil then
			input:Disconnect()
		end
		if gui ~= nil then
			gui:Destroy()
		end
		if cat ~= nil then
			cat:Destroy()
		end
		rig.paint(rig.rest)
		rig.setArm(0)
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
		task.spawn(onDone, if skipped then "skipped" else "watched", os.clock() - began)
	end

	local function swingBack(now: number, weight: number)
		if outFrom == nil then
			outFrom = now
			outWeight = weight
			outColour = colour
			outArm = arm
			showLine(gui, false)
		end
	end

	input = UserInputService.InputBegan:Connect(function(pressed: InputObject)
		if outFrom ~= nil or os.clock() - began < p.skipAfter then
			return
		end
		local kind = pressed.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind.Name:sub(1, 7) == "Gamepad"
		then
			skipped = true
			swingBack(os.clock(), Logic.smoothstep01((os.clock() - began) / p.swingIn))
		end
	end)

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local now = os.clock()
		local t = now - began
		if
			cam == nil
			or character == nil
			or character.Parent == nil
			or station.Parent == nil
			or t >= p.cap
		then
			finish()
			return
		end
		local w: number -- the weight of the camera's swing over to the pool, 0 to 1
		local back = outFrom
		if back ~= nil then
			local k = math.clamp((now - back) / (if skipped then p.skipOut else p.swingOut), 0, 1)
			local e = Logic.smoothstep01(k)
			w = outWeight * (1 - e)
			-- the pool settles as the camera leaves: the liquid back to its rest colour, the staff down
			rig.paint(outColour:Lerp(rig.rest, e))
			rig.setArm(outArm * (1 - e))
			if cat ~= nil then
				cat:Destroy()
				cat = nil
			end
			if k >= 1 then
				finish()
				return
			end
		else
			w = Logic.smoothstep01(t / p.swingIn)
			local s = t - p.swingIn -- seconds into the wave and the swirl
			if s >= 0 then
				arm = Logic.mysticIntroWave(s)
				rig.setArm(arm)
				local i, k = Logic.mysticIntroSwirl(s)
				colour = (if i == 1 then rig.rest else colourAt(i - 1)):Lerp(colourAt(i), k)
				rig.paint(colour)
				if i > lastStep then
					lastStep = i
					Particles.burst("poolBubble", rig.surface, p.bubbles, colourAt(i))
					beat("step", i, rig.surface)
				end
			end
			local r = s - swirlSeconds -- seconds into the silhouette's rise
			if r >= 0 then
				if not risen then
					risen = true
					cat = silhouette()
					showLine(gui, true)
					Particles.burst(
						"catchSparkle",
						rig.surface + Vector3.new(0, 1.5, 0),
						p.sparkles,
						Presets.palette.sparkle
					)
					beat("rise", 0, rig.surface)
				end
				local shape = cat
				if shape ~= nil then
					local tall = shape:GetExtentsSize().Y
					local k = Logic.smoothstep01(r / p.riseSeconds)
					local under = rig.surface - Vector3.new(0, tall + 0.5, 0)
					local over = rig.surface + Vector3.new(0, p.riseHeight, 0)
					local at = under:Lerp(over, k) + Vector3.new(0, 0.12 * math.sin(r * 4), 0)
					-- it looks out of the pool's front, as the rolled cat does, turning a little as it comes up
					local facing = station:GetPivot().Rotation * CFrame.Angles(0, math.pi, 0)
					shape:PivotTo(
						CFrame.new(at)
							* facing
							* CFrame.Angles(0, (1 - k) * math.rad(p.riseTurn), 0)
					)
				end
				if r >= p.rise then
					swingBack(now, w)
				end
			end
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = start:Lerp(away, w)
	end)
	return true
end

-- Whether the cutscene is on screen now.
function MysticIntroCut.playing(): boolean
	return running
end

return MysticIntroCut
