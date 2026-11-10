--!strict
-- The first bait's cutscene (#2946, Derek2 11-10: "make a cut scene where when they put the kibble in bowl it shows a
-- cat walking up and eating it and then the food timer left gets set to 0 so they can claim the cat"). Once per
-- account, right after the first food goes in: the camera eases over to the player's own bowl, the bait cat walks in
-- from the yard to its spot by the bowl, eats with a few happy bites and a sparkle, and the camera eases back. A tap
-- skips it. Controls and prompts are off only while it runs, and a hard cap (Presets.firstBaitCut.cap) always gives
-- them back. While it runs UI.bait.busy() is true, so the wow card and the bait cat's claim card wait for its end.
--
-- Source: ProfileSync's `firstBait` flipping from true to false (the server's UseLure counted the first food), and the
-- server's own bait cat: Gameplay's half of #2946 makes the first bait's cat arrive about a second after the food,
-- so the `Cat` model (CafeService.refreshBowl) appears in the plot's Bait folder while the camera is already there.
-- SlotWalk walks a copy of it in from the yard on the walking body and swaps it for the real cat at the bowl; then
-- the cat's local FirstBaitEatingLocal attribute has Cats.luau dip its head (Logic.eatPose). The server's model is
-- never moved. Design-Agent's spec on #2946 sets the shot and the timing. It does not play with Reduce Motion or at
-- night, when the camera is busy (the intro, a cannon flight, a context cut), when the bowl is not streamed in or far
-- away, or when walls block every camera spot; the cat then just arrives. It swings back early when the cat does not
-- come within `waitCat` seconds. Its outcome goes to the server as TelemetryReport("first_bait_cutscene", "shown",
-- "skipped" or "none"). It never fires anything else.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local ContextCut = require(script.Parent.ContextCut)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local SlotWalk = require(script.Parent.SlotWalk)

local FirstBaitCut = {}

local STEP = "EffectsFirstBaitCut"
FirstBaitCut.EATING = "FirstBaitEatingLocal" -- on the bait cat, this client only: when it started eating (os.clock)
local EATING = FirstBaitCut.EATING
local HAPPY = Color3.fromRGB(255, 150, 190)
local SKIP_FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

local running = false
local started = false
local wasFirst: boolean? = nil -- the last ProfileSync's firstBait
local ui: any = nil

local clearEye: (Vector3, Vector3, boolean, Instance) -> Vector3?

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

-- This player's cafe under World.Plots, nil before it has one.
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

local function part(parent: Instance, name: string): BasePart?
	local found = parent:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("BasePart") then found :: BasePart else nil
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

-- The skip line in the words of the input the player last used (#2871): "Press A to skip" on a gamepad.
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

-- The small "Tap to skip" label in the bottom right (never in the middle), shown from `skipAfter`. On a TV it keeps
-- inside the 5% a television may crop off its edges (#2871).
local function skipLabel(): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local p = Presets.firstBaitCut
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsFirstBaitCut"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = p.displayOrder
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Skip"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 1)
	local edge = if GuiService:IsTenFootInterface() then p.tvSafe else 0
	label.Position = UDim2.new(1 - edge, -24, 1 - edge, -24)
	label.Size = UDim2.fromOffset(160, 28)
	label.FontFace = SKIP_FONT
	label.TextSize = p.skipSize
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = p.skipFade
	label.Text = skipWords()
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = p.skipFade
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function report(outcome: string)
	pcall(function()
		Net.fire("TelemetryReport", "first_bait_cutscene", outcome)
	end)
end

-- The bait cat the server put at the bowl for the food in now, or nil.
local function catIn(folder: Instance): Model?
	local cat = folder:FindFirstChild("Cat")
	if cat ~= nil and cat:IsA("Model") and cat:GetAttribute("BaitKey") ~= nil then
		return cat :: Model
	end
	return nil
end

-- A flat unit vector, or `fallback` when `v` has no flat length.
local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else fallback
end

-- The camera's spot for the cut (Design-Agent's spec on #2946): `back` studs from `look` along `toward` (the far side
-- of the bowl from the yard, so the cat walks at the camera at an angle) and `up` studs up, more on a portrait screen;
-- swung round the bowl by each of `swings` degrees in turn until one ray from the bowl reaches it clear. Nil when none.
clearEye = function(look: Vector3, toward: Vector3, tall: boolean, plot: Instance): Vector3?
	local p = Presets.firstBaitCut
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	local bait = plot:FindFirstChild("Bait")
	if bait ~= nil then
		table.insert(ignore, bait)
	end
	params.FilterDescendantsInstances = ignore
	for _, degrees in p.swings do
		local eye = Logic.cutAround(
			look,
			toward,
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

type Walk = {
	cat: Model,
	rest: CFrame, -- where the server has it
	began: number,
	eatAt: number?, -- when it started eating
}

-- Plays the cutscene now; false (and nothing changes) when it cannot.
function FirstBaitCut.play(): boolean
	local camera = Workspace.CurrentCamera
	if
		running
		or camera == nil
		or camera.CameraType ~= Enum.CameraType.Custom
		or ContextCut.playing()
		or Context.reducedMotion() -- the spec: no cut with Reduce Motion or at night; the cat just arrives
		or Context.isNight()
	then
		return false
	end
	local plot = ownPlot()
	local folder = if plot ~= nil then plot:FindFirstChild("Bait") else nil
	local bowlAnchor = if plot ~= nil then part(plot, "BaitBowl") else nil
	local catAnchor = if plot ~= nil then part(plot, "BaitCat") else nil
	if folder == nil or bowlAnchor == nil or catAnchor == nil then
		return false
	end
	local p = Presets.firstBaitCut
	local bowlAt = (bowlAnchor :: BasePart).Position
	local catAt = (catAnchor :: BasePart).Position
	if Context.distance(bowlAt) > p.maxDistance then
		return false -- food put in from far away (the F menu): the toast sends them home instead
	end
	local yard = flat((bowlAnchor :: BasePart).CFrame.ZVector, Vector3.new(0, 0, 1))
	local side = yard:Cross(Vector3.yAxis)
	local look = (bowlAt + catAt) / 2 + Vector3.new(0, p.lookUp, 0)
	local eye =
		clearEye(look, -yard, camera.ViewportSize.X < camera.ViewportSize.Y, plot :: Instance)
	if eye == nil then
		return false -- walls all round: the cat just arrives
	end
	local away = CFrame.lookAt(eye :: Vector3, look)
	local start = camera.CFrame

	running = true
	if ui ~= nil and type(ui.close) == "function" then
		pcall(ui.close) -- the bowl's screen closes, so nothing covers the middle
	end
	local subject = camera.CameraSubject
	local module = controls()
	local promptsWere = ProximityPromptService.Enabled
	setControls(module, false)
	ProximityPromptService.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local skipGui = skipLabel()

	local began = os.clock()
	local walk: Walk? = nil
	local outFrom: number? = nil -- when the swing back began
	local outWeight = 1
	local skipped = false
	local puffed = false -- the heart puff, halfway through the eat
	local finished = false
	local inputConnection: RBXScriptConnection? = nil

	local function settleCat()
		local w = walk
		if w ~= nil and w.cat.Parent ~= nil then
			w.cat:SetAttribute(EATING, nil)
		end
	end

	local function finish(outcome: string)
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(STEP)
		if inputConnection ~= nil then
			inputConnection:Disconnect()
		end
		if skipGui ~= nil then
			skipGui:Destroy()
		end
		settleCat()
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
		report(outcome)
	end

	local function swingBack(now: number, weight: number)
		if outFrom == nil then
			outFrom = now
			outWeight = weight
			settleCat()
		end
	end

	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		if outFrom ~= nil or os.clock() - began < p.skipAfter then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind.Name:sub(1, 7) == "Gamepad"
		then
			skipped = true
			local t = os.clock() - began
			swingBack(os.clock(), Logic.smoothstep01(t / p.swingIn))
		end
	end)

	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local now = os.clock()
		local t = now - began
		if cam == nil or character == nil or character.Parent == nil or t >= p.cap then
			finish(if skipped then "skipped" else "none")
			return
		end
		-- the weight of the camera's swing over to the bowl, 0 to 1
		local w: number
		local back = outFrom
		if back ~= nil then
			local span = if skipped then p.skipOut else p.swingOut
			local k = math.clamp((now - back) / span, 0, 1)
			w = outWeight * (1 - Logic.smoothstep01(k))
			if k >= 1 then
				finish(if skipped then "skipped" elseif walk ~= nil then "shown" else "none")
				return
			end
		else
			w = Logic.smoothstep01(t / p.swingIn)
			local current = walk
			if current == nil then
				local cat = catIn(folder :: Instance)
				if cat ~= nil then
					local rest = cat:GetPivot()
					local from = rest.Position + yard * p.walkDistance + side * p.walkSide
					-- SlotWalk walks a copy in from the yard on the walking body and swaps it for the real cat at
					-- the bowl, so the server's model is never moved here
					SlotWalk.walkIn(cat, CFrame.lookAt(from, rest.Position))
					local made: Walk = { cat = cat, rest = rest, began = now, eatAt = nil }
					current = made
					walk = current
				elseif t >= p.waitCat then
					swingBack(now, w) -- the cat did not come in time: back to the player
				end
			end
			if current ~= nil and current.cat.Parent == nil then
				walk = nil
				swingBack(now, w)
			elseif current ~= nil then
				local eatAt = current.eatAt
				if
					eatAt == nil
					and (not SlotWalk.isWalking(current.cat) or now - current.began >= p.walkMax)
				then
					eatAt = now
					current.eatAt = now
					current.cat:SetAttribute(EATING, now) -- Cats.luau dips its head (Logic.eatPose)
					Moments.FirstBaitEat:Fire(bowlAt, p.eat)
				end
				if eatAt ~= nil then
					local e = now - eatAt
					if not puffed and e >= p.eat / 2 then
						puffed = true
						Particles.burst(
							"dingSparkle",
							current.rest.Position + Vector3.new(0, p.happyUp, 0),
							p.happy,
							HAPPY
						)
					end
					if e >= p.eat then
						swingBack(now, w)
					end
				end
			end
		end
		if skipGui ~= nil then
			skipGui.Enabled = outFrom == nil and t >= p.skipAfter
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = start:Lerp(away, w)
	end)
	return true
end

-- Whether the cutscene is on screen now (UI.bait.busy holds the bait cards while it is).
function FirstBaitCut.playing(): boolean
	return running
end

-- `ui` is the client UI (UI.close, UI.bait): its bait cards wait while the cutscene runs.
function FirstBaitCut.start(clientUi: any)
	if started then
		return
	end
	started = true
	ui = clientUi
	local bait = if type(clientUi) == "table" then clientUi.bait else nil
	if type(bait) == "table" then
		bait.cutting = FirstBaitCut.playing
	end
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local first = (state :: { [string]: unknown }).firstBait
		if type(first) ~= "boolean" then
			return
		end
		local was = wasFirst
		wasFirst = first
		if was == true and first == false then
			-- the first food just went in
			if not FirstBaitCut.play() then
				report("none")
			end
		end
	end)
end

return FirstBaitCut
