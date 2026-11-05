--!strict
-- The context tips' camera cuts (#976, easy-start.md sections 3 and 7, ui-contract.md "Context tips"): the first time
-- a player meets the bait bowl, a rank up, a golden fish, the dealer or the Spin Wheel, the UI's tip queue calls
-- ContextCut.play(id, caption, seconds, done) at a quiet moment. The camera swings out to that place, holds with the
-- caption on black bars, and swings back (Presets.contextCut). Controls and prompts are off for its length; any press
-- after `skipAfter` seconds swings back early. `done(skipped)` is called once at the end; the UI then sends TipSeen.
-- It returns false, and the UI shows the tip's card instead, when the place has not streamed in, another script
-- already holds the camera (the intro, a cannon flight) or a cut is already running.
--
-- Where each cut looks: `bowl` the player's own bait bowl (its plot's `BaitBowl` anchor); `rank_up` the gate of the
-- area the next rank opens (an `AreaGate` whose RequiresTier is one past the plot's Tier), else the nearest cannon;
-- `golden_fish` the nearest Fish Market, `dealer` the nearest dealer cart, `spin_wheel` the nearest Spin Wheel (by
-- their tags). This client only; it never fires a remote (the UI's done does).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local ContextCut = {}

local STEP = "EffectsContextCut"
local CAPTION_FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

-- the cut on screen now, if any
local running = false

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

-- This player's cafe under World.Plots (the plot whose OwnerUserId is theirs), nil before it has one.
local function ownPlot(): Instance?
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	if plots == nil then
		return nil
	end
	local me = Players.LocalPlayer.UserId
	for _, plot in plots:GetChildren() do
		if numberAttribute(plot, "OwnerUserId") == me then
			return plot
		end
	end
	return nil
end

-- The middle and size across of a model or part, nil for anything else.
local function boundsOf(instance: Instance): (CFrame?, Vector3?)
	if instance:IsA("Model") then
		local frame, size = (instance :: Model):GetBoundingBox()
		return frame, size
	elseif instance:IsA("BasePart") then
		local part = instance :: BasePart
		return part.CFrame, part.Size
	end
	return nil, nil
end

-- Of `candidates`, the one closest to the player (or the camera while the character loads).
local function nearest(candidates: { Instance }): Instance?
	local focus = Context.focus()
	local best: Instance? = nil
	local bestDistance = math.huge
	for _, item in candidates do
		local position = Context.positionOf(item)
		if position ~= nil and item:IsDescendantOf(Workspace) then
			local distance = if focus ~= nil then (position - focus).Magnitude else 0
			if distance < bestDistance then
				best, bestDistance = item, distance
			end
		end
	end
	return best
end

-- The place a cut looks at, by tip id; nil when it is not here (not streamed in, or no such place yet).
local function targetFor(id: string): Instance?
	if id == "bowl" then
		local plot = ownPlot()
		return if plot ~= nil then plot:FindFirstChild("BaitBowl", true) else nil
	elseif id == "rank_up" then
		local plot = ownPlot()
		local tier = if plot ~= nil then numberAttribute(plot, "Tier") else nil
		if tier ~= nil then
			local gates = {}
			for _, gate in CollectionService:GetTagged("AreaGate") do
				if numberAttribute(gate, "RequiresTier") == tier + 1 then
					table.insert(gates, gate)
				end
			end
			local gate = nearest(gates)
			if gate ~= nil then
				return gate
			end
		end
		return nearest(CollectionService:GetTagged("CatCannon"))
	elseif id == "golden_fish" then
		return nearest(CollectionService:GetTagged("FishMarket"))
	elseif id == "dealer" then
		return nearest(CollectionService:GetTagged("DealerCart"))
	elseif id == "spin_wheel" then
		return nearest(CollectionService:GetTagged("SpinWheel"))
	end
	return nil
end

-- The PlayerModule's controls, or nil when the default player scripts are not there.
local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local module = if scripts ~= nil then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local requireAny: any = require -- Roblox's own PlayerModule is not in the Rojo tree, so it has no types
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

type Bars = { gui: ScreenGui, top: Frame, bottom: Frame, caption: TextLabel, stroke: UIStroke }

-- The black bars and the caption, hidden until the first frame draws them.
local function makeBars(caption: string): Bars?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local p = Presets.contextCut
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsContextCut"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = p.displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local function bar(name: string, anchorY: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0, anchorY)
		frame.Position = UDim2.fromScale(0, anchorY)
		frame.Size = UDim2.fromScale(1, 0)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		return frame
	end
	local top = bar("Top", 0)
	local bottom = bar("Bottom", 1)
	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 1 - p.bars / 2)
	label.Size = UDim2.new(1, -32, p.bars, 0)
	label.FontFace = CAPTION_FONT
	label.TextSize = p.captionSize
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.Text = caption
	label.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = playerGui
	return { gui = gui, top = top, bottom = bottom, caption = label, stroke = stroke }
end

local function drawBars(bars: Bars, w: number)
	local h = Presets.contextCut.bars * w
	bars.top.Size = UDim2.fromScale(1, h)
	bars.bottom.Size = UDim2.fromScale(1, h)
	bars.caption.TextTransparency = 1 - w
	bars.stroke.Transparency = 1 - w
end

-- Plays the cut for tip `id`, `seconds` long, with `caption`; true when it took the camera. `done(skipped)` comes
-- once, at the end. The UI's CutPlayer (UI.tips.setCutPlayer).
function ContextCut.play(
	id: string,
	caption: string,
	seconds: number,
	done: (skipped: boolean) -> ()
): boolean
	local camera = Workspace.CurrentCamera
	if running or camera == nil or camera.CameraType ~= Enum.CameraType.Custom or seconds <= 0 then
		return false
	end
	local target = targetFor(id)
	if target == nil then
		return false
	end
	local frame: CFrame?, size: Vector3? = boundsOf(target)
	if frame == nil or size == nil then
		return false
	end
	local p = Presets.contextCut
	local look = frame.Position + Vector3.new(0, size.Y * p.lookUp, 0)
	local start = camera.CFrame
	local eye = Logic.cutEye(look, math.max(size.X, size.Y, size.Z), start.Position, p)
	local away = CFrame.lookAt(eye, look)
	local reduced = Context.reducedMotion()

	running = true
	local subject = camera.CameraSubject
	local module = controls()
	local promptsWere = ProximityPromptService.Enabled
	setControls(module, false)
	ProximityPromptService.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local bars = makeBars(caption)

	local began = os.clock()
	local skippedAt: number? = nil
	local skipFrom = 0
	local finished = false
	local inputConnection: RBXScriptConnection? = nil

	local function finish(skipped: boolean)
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if inputConnection ~= nil then
			inputConnection:Disconnect()
		end
		if bars ~= nil then
			bars.gui:Destroy()
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
		task.spawn(done, skipped)
	end

	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		if skippedAt ~= nil or os.clock() - began < p.skipAfter then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind.Name:sub(1, 7) == "Gamepad"
		then
			skippedAt = os.clock()
			skipFrom = Logic.cutWeight(os.clock() - began, seconds, p, reduced)
		end
	end)

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		if cam == nil then
			finish(skippedAt ~= nil)
			return
		end
		local now = os.clock()
		local w: number
		local at = skippedAt
		if at ~= nil then
			local k = if reduced then 1 else math.clamp((now - at) / p.skipOut, 0, 1)
			w = skipFrom * (1 - k * k * (3 - 2 * k))
			if k >= 1 then
				finish(true)
				return
			end
		else
			local t = now - began
			if t >= seconds then
				finish(false)
				return
			end
			w = Logic.cutWeight(t, seconds, p, reduced)
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = start:Lerp(away, w)
		if bars ~= nil then
			drawBars(bars, math.clamp(w * 2, 0, 1))
		end
	end)
	return true
end

-- Whether a cut is on screen now.
function ContextCut.playing(): boolean
	return running
end

-- Hands the UI its cut player (ui-contract.md: until this runs, the five cut tips show as cards).
function ContextCut.start(ui: any)
	local tips = if type(ui) == "table" then ui.tips else nil
	if type(tips) == "table" and type(tips.setCutPlayer) == "function" then
		tips.setCutPlayer(ContextCut.play)
	end
end

return ContextCut
