--!strict
-- The Rummage Bin on this client (#3050; the rules are shared/RummageBin, the server is BinService). The bin's prompt
-- (RummageBin.PROMPT on the model's PromptAnchor, made by WorldBuilder, drawn as the UI's action pill with the chances
-- under it) reads "Rummage" while this player's bin is full and "Empty for now 🐾" while it is not, from the player's
-- BinNextAt attribute: never a countdown, and nothing announces the refill (Monetization-Agent 11-10). The model shows
-- its `_Ready` look (lid back, prizes poking out) or its `_Empty` look (lid shut) the same way, for this player only.
-- A press on a full bin sends RescueBegin with RummageBin.SPOT; the server answers with the rescue bar
-- (RescueChallenge), and its winning RescueResult fires Moments.RummageWin(row id, first) for the effects and sounds
-- (UIController). Nothing is sent during a catch, a rescue, a flight or the intro.
-- #3458 (Derek 2026-11-12: "put exclamation mark when ready"): a red "!" (the camp stations' ReadyBang dot) hangs over
-- the bin while it is full for this player and its switch is on: for this player only (it lives in their PlayerGui),
-- seen within BANG_RANGE studs, bobbing unless Reduce Motion is on. No countdown and nothing outside the Alleyway.
-- #3460: the note under the prompt names this player's next fixed prize, then the chances (RummageBin.note).
-- #3608, behind the `binRoll` switch: the server chooses the prize before the bar and says so with BinRolled (the
-- row's id and a mode). A fresh roll plays Effects/BinRoll's roll over the board's rows and a fixed first prize its
-- reveal; a tap, click or key skips either (a RescuePress, which makes the server send the bar at once). The win
-- plays the tier's effect and the prize's hop to the player. The pad in front of the bin (the model's floor ring)
-- starts a rummage for a player who has stood on it Config.BinPadDwellSeconds, once per visit to the pad, with the
-- prompt's own remote; the ring shows only while the switch is on. BinController.onRoll and .onPrize let the board
-- (UI) follow along.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(script.Parent.Parent.UI.Components.Create)
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Outline = require(script.Parent.Parent.UI.Components.Outline)
local RummageBin = require(Shared:WaitForChild("RummageBin"))
local Scale = require(script.Parent.Parent.UI.Scale)
local Theme = require(script.Parent.Parent.UI.Theme)
local UI = require(script.Parent.Parent.UI)
local UserInputService = game:GetService("UserInputService")
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local BinController = {}

-- #3608: what the board hears. `onPrize(rowId, mode)` when the server names the prize (nil, nil when the rummage is
-- over), `onRoll(index)` for each row the roll's highlight passes and lands on.
BinController.onPrize = nil :: ((rowId: string?, mode: string?) -> ())?
BinController.onRoll = nil :: ((index: number) -> ())?

local PAD_SECONDS = 0.1

local LABEL_SECONDS = 1
local BANG_RANGE = 40 -- studs from the camera, as the camp stations' "!" (CampExtrasLogic.BANG_RANGE)
local BANG_LIFT = 2 -- studs over the top of the bin
local BOB_STUDS = 1
local BOB_SECONDS = 2

local models: { [Model]: ProximityPrompt? } = {} -- each placed bin on this client and its prompt

local function ready(): boolean
	local nextAt = Players.LocalPlayer:GetAttribute(RummageBin.NEXT_AT_ATTRIBUTE)
	return type(nextAt) ~= "number" or Workspace:GetServerTimeNow() >= nextAt
end

-- Shows one of the model's two looks. Their parts are all opaque, so a look is hidden at Transparency 1.
local function setLook(model: Model, full: boolean)
	for _, look in model:GetChildren() do
		if not look:IsA("Model") then
			continue
		end
		local shown = (look.Name:sub(-6) == "_Empty") ~= full
		local transparency = if shown then 0 else 1
		for _, piece in look:GetDescendants() do
			if piece:IsA("BasePart") and (piece :: BasePart).Transparency ~= transparency then
				(piece :: BasePart).Transparency = transparency
			end
		end
	end
end

-- The "!" over a bin: a BillboardGui in this player's PlayerGui, hung from the bin's main part.
type Bang = { gui: BillboardGui, bob: Tween? }
local bangs: { [Model]: Bang } = {}

local function still(bang: Bang)
	if bang.bob ~= nil then
		bang.bob:Cancel()
		bang.bob = nil
	end
	bang.gui.StudsOffset = Vector3.zero
end

local function dropBang(model: Model)
	local bang = bangs[model]
	if bang ~= nil then
		bangs[model] = nil
		still(bang)
		bang.gui:Destroy()
	end
end

local function bangFor(model: Model): Bang?
	local found = bangs[model]
	if found ~= nil then
		return found
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if part == nil or playerGui == nil then
		return nil
	end
	local box, size = model:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeBinBang",
		Size = UDim2.new(
			1.6 * Scale.phoneStuds(),
			Scale.billboard(28),
			1.6 * Scale.phoneStuds(),
			Scale.billboard(28)
		),
		StudsOffsetWorldSpace = Vector3.new(0, top - part.Position.Y + BANG_LIFT, 0),
		LightInfluence = 0,
		AlwaysOnTop = false,
		MaxDistance = BANG_RANGE,
		DistanceLowerLimit = Scale.BUBBLE_NEAR,
		ResetOnSpawn = false,
		Enabled = false,
		Adornee = part,
		Parent = playerGui,
	})
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark: TextLabel = Create("TextLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "!",
		ZIndex = 2,
		Parent = dot,
	})
	Outline.text(mark, 2)
	local bang: Bang = { gui = gui, bob = nil }
	bangs[model] = bang
	return bang
end

local function setBang(model: Model, on: boolean)
	local bang = if on then bangFor(model) else bangs[model]
	if bang == nil then
		return
	end
	bang.gui.Enabled = on
	if not on or GuiService.ReducedMotionEnabled then
		still(bang)
	elseif bang.bob == nil then
		local info = TweenInfo.new(
			BOB_SECONDS / 2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		local bob =
			TweenService:Create(bang.gui, info, { StudsOffset = Vector3.new(0, BOB_STUDS, 0) })
		bob:Play()
		bang.bob = bob
	end
end

local function label()
	local full = ready()
	local action = if full then RummageBin.ACTION else RummageBin.EMPTY
	local uses = Players.LocalPlayer:GetAttribute(RummageBin.USES_ATTRIBUTE)
	local note = RummageBin.note(if type(uses) == "number" then uses else Config.BinFirstUses)
	for model, prompt in models do
		if prompt ~= nil then
			if prompt.ActionText ~= action then
				prompt.ActionText = action
			end
			-- set on this client only: each player sees their own next prize
			if prompt:GetAttribute("Note") ~= note then
				prompt:SetAttribute("Note", note)
			end
		end
		setLook(model, full)
		-- the "!" only while the bin can be rummaged: full, and its prompt on (the alleyBin switch)
		setBang(model, full and prompt ~= nil and prompt.Enabled)
	end
end

local function busy(): boolean
	local ui: any = UI
	local character = Players.LocalPlayer.Character
	return (
		character ~= nil
		and (
			character:GetAttribute("Launching") == true
			or character:GetAttribute("CloudHopAt") ~= nil
		)
	)
		or ui.catch.circlesActive()
		or ui.rescue.isActive()
		or ui.intro.playing()
end

local function onTriggered()
	if busy() or not ready() then
		return -- an empty bin's pill already says so
	end
	Net.fire("RescueBegin", RummageBin.SPOT)
end

local function rollOn(): boolean
	return LiveFlags.shown(
		RummageBin.ROLL_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. RummageBin.ROLL_FLAG)
	)
end

-- The bin's floor ring (World/WalkUpCircles): the part, or nil while it is streamed out.
local function padOf(model: Model): BasePart?
	local link = model:FindFirstChild(WalkUp.CIRCLE)
	local ring = if link ~= nil and link:IsA("ObjectValue")
		then (link :: ObjectValue).Value
		else nil
	return if ring ~= nil and ring:IsA("BasePart") then ring :: BasePart else nil
end

-- Motion-FX's roll and prize effects (Effects/BinRoll, #3612), when that module is in the build.
local function binFx(): any
	local controllers: Instance? = script.Parent
	local client: Instance? = if controllers ~= nil then controllers.Parent else nil
	local effects: Instance? = if client ~= nil then client:FindFirstChild("Effects") else nil
	local module: Instance? = if effects ~= nil then effects:FindFirstChild("BinRoll") else nil
	if module == nil or not (module :: Instance):IsA("ModuleScript") then
		return nil
	end
	local ok, fx = pcall(require :: any, module)
	return if ok then fx else nil
end

local function firstBin(): Model?
	for model in models do
		return model
	end
	return nil
end

-- The show before the bar: the roll or the reveal, until the bar comes or the player skips.
local showing: { skip: (() -> ())? }? = nil

local function endShow()
	local show = showing
	showing = nil
	if show ~= nil and show.skip ~= nil then
		show.skip()
	end
end

local function onRolled(rowId: unknown, mode: unknown, seconds: unknown)
	if type(rowId) ~= "string" or type(mode) ~= "string" then
		return
	end
	local row = RummageBin.rollRow(rowId)
	if row == nil then
		return
	end
	endShow()
	if BinController.onPrize ~= nil then
		BinController.onPrize(rowId, mode)
	end
	if mode == RummageBin.MODE_WAITING or type(seconds) ~= "number" or seconds <= 0 then
		return
	end
	local show: { skip: (() -> ())? } = { skip = nil }
	showing = show
	local model, fx = firstBin(), binFx()
	local index = RummageBin.rollIndex(rowId)
	local function landed()
		if showing == show then
			show.skip = nil
		end
		if index ~= nil and BinController.onRoll ~= nil then
			BinController.onRoll(index)
		end
	end
	if fx ~= nil and model ~= nil then
		local ok, skip = pcall(function(): any
			if mode == RummageBin.MODE_ROLL and index ~= nil then
				return fx.play(
					model,
					#RummageBin.rollRows(),
					index,
					RummageBin.tier(row),
					function(at: number)
						if BinController.onRoll ~= nil then
							BinController.onRoll(at)
						end
					end,
					landed
				)
			end
			return fx.reveal(model, RummageBin.tier(row), landed)
		end)
		if ok and type(skip) == "function" then
			show.skip = skip
			return
		end
	end
	landed() -- no effects module: the board just shows the row
end

local SKIP_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
}

-- A tap, click, Space, E, Enter or the gamepad's A during the show skips it: the effect jumps to its end and the server sends the bar now.
local function onInput(input: InputObject, processed: boolean)
	if showing == nil or processed then
		return
	end
	local kind = input.UserInputType
	if
		kind ~= Enum.UserInputType.Touch
		and kind ~= Enum.UserInputType.MouseButton1
		and kind ~= Enum.UserInputType.Keyboard
		and kind ~= Enum.UserInputType.Gamepad1
	then
		return
	end
	if kind == Enum.UserInputType.Gamepad1 and input.KeyCode ~= Enum.KeyCode.ButtonA then
		return
	end
	-- on a keyboard only the keys that mean "go on": walking (W, A, S, D, Shift) leaves the roll playing
	if kind == Enum.UserInputType.Keyboard and not SKIP_KEYS[input.KeyCode] then
		return
	end
	endShow()
	Net.fire("RescuePress", RummageBin.SPOT, Workspace:GetServerTimeNow())
end

local function onWin(rowId: string, _first: boolean)
	endShow()
	if BinController.onPrize ~= nil then
		BinController.onPrize(nil, nil)
	end
	if not rollOn() then
		return
	end
	local row, model, fx = RummageBin.rollRow(rowId), firstBin(), binFx()
	if row == nil or model == nil or fx == nil then
		return
	end
	local tier = RummageBin.tier(row)
	setLook(model, false) -- the empty look first, so the lid that hops is the one that shows
	pcall(function()
		fx.win(model, tier)
		fx.hop(model, function(): Vector3?
			local character = Players.LocalPlayer.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
		end, tier)
	end)
end

-- The pad: standing inside the ring for BinPadDwellSeconds starts a rummage, once per visit to the pad, so a miss
-- or a closed bar never starts another by itself and running across it starts nothing.
local padSince: number? = nil
local padUsed = false

-- The pad waits for the tutorial: a new player who stops on it at the first landing is not handed a bar in the
-- middle of the first steps (the prompt still works for them).
local TUTORIAL_DONE = 5
local function inTutorial(): boolean
	local controller: any = require(script.Parent.UIController)
	local state: any = controller.state
	return state == nil
		or type(state.tutorialStep) ~= "number"
		or state.tutorialStep < TUTORIAL_DONE
end

local function padStep()
	local on = rollOn()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local inside = false
	for model, prompt in models do
		local pad = padOf(model)
		if pad == nil then
			continue
		end
		local gui = pad:FindFirstChildWhichIsA("SurfaceGui") :: SurfaceGui?
		local shown = on and prompt ~= nil and prompt.Enabled
		if gui ~= nil and gui.Enabled ~= shown then
			gui.Enabled = shown
		end
		if shown and root ~= nil and root:IsA("BasePart") then
			local offset = (root :: BasePart).Position - pad.Position
			local radius = pad:GetAttribute("Radius")
			local reach = if type(radius) == "number" then radius else pad.Size.X / 2
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach
				and math.abs(offset.Y) <= 8
			then
				inside = true
			end
		end
	end
	if not inside then
		padSince = nil
		padUsed = false
		return
	end
	local now = os.clock()
	local since = padSince or now
	padSince = since
	if padUsed or now - since < Config.BinPadDwellSeconds then
		return
	end
	if busy() or not ready() or inTutorial() then
		return -- keeps waiting on the pad: a bin that fills while the player stands there starts
	end
	padUsed = true
	Net.fire("RescueBegin", RummageBin.SPOT)
end

-- Picks up a placed bin's prompt (again after its model streams back in).
local function track(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return
	end
	local model = instance :: Model
	if models[model] ~= nil then
		return
	end
	local prompt = model:FindFirstChild(RummageBin.PROMPT, true)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		-- not here yet: take it when it arrives
		local waiting: RBXScriptConnection
		waiting = model.DescendantAdded:Connect(function(child: Instance)
			if child.Name == RummageBin.PROMPT and child:IsA("ProximityPrompt") then
				waiting:Disconnect()
				track(model)
			end
		end)
		return
	end
	local found = prompt :: ProximityPrompt
	models[model] = found
	found.Triggered:Connect(onTriggered)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			models[model] = nil
			dropBang(model)
		end
	end)
	label()
end

function BinController.start()
	for _, instance in CollectionService:GetTagged(RummageBin.TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(RummageBin.TAG):Connect(track)
	Players.LocalPlayer:GetAttributeChangedSignal(RummageBin.NEXT_AT_ATTRIBUTE):Connect(label)
	Players.LocalPlayer:GetAttributeChangedSignal(RummageBin.USES_ATTRIBUTE):Connect(label)
	task.spawn(function()
		while true do
			task.wait(LABEL_SECONDS)
			label()
		end
	end)
	-- #3608
	Net.on("BinRolled", onRolled)
	Moments.RummageWin:Connect(onWin)
	UserInputService.InputBegan:Connect(onInput)
	task.spawn(function()
		while true do
			task.wait(PAD_SECONDS)
			padStep()
		end
	end)
end

return BinController
