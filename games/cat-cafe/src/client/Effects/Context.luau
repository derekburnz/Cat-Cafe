--!strict
-- What every effect asks about this client: its budget (phone or PC, or the Low performance setting), where the
-- player is, day or night, Reduce Motion and the Screen shake setting, the folder that holds parts made on this
-- client (the server never sees it) and the camera shake.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)
local Rumble = require(script.Parent.Rumble)

local Context = {}

Context.device = "high" :: string -- Presets.Tier of this device (Logic.tier)
Context.tier = "high" :: string -- Presets.Tier effects run at: the device's, or "low" in Low performance mode
Context.budget = Presets.budget.high
Context.screenShake = true -- the Screen shake setting
Context.lowPerformance = false -- the Low performance setting
Context.console = false -- an Xbox or PlayStation (a ten-foot screen): Presets.budget.console (#2871)
Context.lite = false -- #3794: the lighter budget (Logic.wantsLite): a struggling phone or graphics quality 1 to 3
Context.struggling = false -- #4311: this phone or tablet's frame rate stayed low (Logic.slowStep); kept all session
local RUMBLE_FLAG = "deviceFixes" -- #4224: rumble ships with the Tue 2026-11-17 device update's switch (off by default)

local SHAKE_STEP = "CatCafeEffectsShake"

local folder: Folder? = nil
local rng = Random.new()

-- The graphics quality the player set (1 to 10), or 0 for Automatic or when it cannot be read.
local function savedQuality(): number
	local ok, level = pcall(function(): number
		local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		return saved.Value
	end)
	return if ok and type(level) == "number" then level else 0
end

local function rebudget()
	Context.lite =
		Logic.wantsLite(Context.device :: Presets.Tier, savedQuality(), Context.struggling)
	local tier, budget = Logic.budgetFor(
		Context.device :: Presets.Tier,
		Context.lowPerformance,
		Context.console,
		Context.lite
	)
	Context.tier = tier
	Context.budget = budget
end

function Context.init()
	local function retier()
		Context.device = Logic.tier(
			UserInputService.TouchEnabled,
			UserInputService.KeyboardEnabled,
			UserInputService.MouseEnabled
		)
	end
	retier()
	Context.console = GuiService:IsTenFootInterface()
	rebudget()
	-- #3918: a keyboard case or a mouse can be attached mid session; the tier follows within a second
	for _, name in { "KeyboardEnabled", "MouseEnabled", "TouchEnabled" } do
		UserInputService:GetPropertyChangedSignal(name):Connect(function()
			retier()
			rebudget()
		end)
	end
	-- #3794: the graphics quality can change mid session; effects pick the budget up within a second
	pcall(function()
		local userSettings = UserSettings():GetService("UserGameSettings")
		userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(rebudget)
	end)
	-- #4311: watch the frame rate until this device is found to be struggling, then the lighter budget applies on
	-- a phone or tablet for the rest of the session. One add and one compare a frame; the watch ends when it trips.
	local slow = Logic.slowStart()
	local watch: RBXScriptConnection? = nil
	watch = RunService.RenderStepped:Connect(function(dt: number)
		if Logic.slowStep(slow, dt, Presets.slow, Context.cutscene()) then
			Context.struggling = true
			rebudget()
			-- #4945: once a session, for the analytics: when it tripped and how slow (Logic.liteReport)
			Net.fire("TelemetryReport", "fx_lite", Logic.liteReport(slow))
			if watch ~= nil then
				watch:Disconnect()
			end
		end
	end)
end

-- Whether a cutscene has the camera (it is Scriptable), so a slow frame there says nothing about the device.
function Context.cutscene(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable
end

-- Follows the player's Settings switches (Effects.applySettings). Turning Screen shake off also stops a shake that
-- is running; a new budget reaches each effect at its next once a second choice.
function Context.applySettings(settings: { [string]: unknown }?)
	local shake, lowPerformance = Logic.readSettings(settings)
	Context.screenShake = shake
	Context.lowPerformance = lowPerformance
	rebudget()
	if not shake then
		RunService:UnbindFromRenderStep(SHAKE_STEP)
	end
end

-- The player's position, or the camera's focus while the character is loading.
function Context.focus(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.Focus.Position else nil
end

function Context.distance(position: Vector3): number
	local focus = Context.focus()
	return if focus ~= nil then (position - focus).Magnitude else math.huge
end

-- #5265 (Derek 2026-11-18: "make it no spawns that I can see from areas not unlocked yet"): true when area `areaId`
-- is one this player's tier has not opened (the Player's Tier attribute, TradeService), so a spawn's beam, mark or
-- glow there stays away. False for an unknown area, before the tier is known, or with the lockedAreaQuiet switch
-- set false.
function Context.areaShut(areaId: unknown): boolean
	if type(areaId) ~= "string" then
		return false
	end
	if
		not LiveFlags.shown(
			"lockedAreaQuiet",
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. "lockedAreaQuiet")
		)
	then
		return false
	end
	local area = Catalog.getArea(areaId)
	local tier = Players.LocalPlayer:GetAttribute("Tier")
	if area == nil or type(tier) ~= "number" then
		return false
	end
	return tier < area.tier
end

-- ReplicatedStorage.Clock Phase (data-model section 9), the same attribute WorldController follows.
function Context.isNight(): boolean
	local clock = ReplicatedStorage:FindFirstChild("Clock")
	return clock ~= nil and clock:GetAttribute("Phase") == "night"
end

-- The player's Reduce Motion setting: no camera shake or flashes, fewer confetti pieces. In Studio only, the
-- Workspace attribute `ReduceMotionTest` = true turns it on too, so a playtest can check the still version of an
-- effect without changing a Roblox account setting (Review-QA, #4105). It does nothing in the live game.
local studioKnown, studio = pcall(function(): boolean
	return RunService:IsStudio()
end)
local IN_STUDIO = studioKnown and studio == true
function Context.reducedMotion(): boolean
	if IN_STUDIO and Workspace:GetAttribute("ReduceMotionTest") == true then
		return true
	end
	return GuiService.ReducedMotionEnabled
end

-- #4224: gamepad rumble only while the `deviceFixes` switch is on (off by default; read each time, so the
-- switch works mid session).
local function rumbleOn(): boolean
	return LiveFlags.shown(
		RUMBLE_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. RUMBLE_FLAG)
	)
end

-- A short camera shake for this player (a missed catch, being shoved), fading out over `seconds`. Runs after the
-- camera scripts each frame, so the offset never piles up; a new shake replaces one still running; off with Reduce
-- Motion or the Screen shake setting off. A gamepad in use buzzes with it (Effects/Rumble).
function Context.shake(seconds: number, studs: number)
	if not Context.screenShake then
		return
	end
	if rumbleOn() then
		Rumble.bump(seconds, studs) -- #4224: a gamepad buzzes with the bump, also with Reduce Motion (nothing moves)
	end
	if Context.reducedMotion() then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local began = os.clock()
	RunService:UnbindFromRenderStep(SHAKE_STEP)
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - began
		if t >= seconds then
			RunService:UnbindFromRenderStep(SHAKE_STEP)
			return
		end
		local k = (1 - t / seconds) * studs
		camera.CFrame = camera.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
	end)
end

-- #4224: a gamepad pulse with no camera bump (your own catch), off with the Screen shake setting off.
function Context.rumble(seconds: number, strength: number)
	if Context.screenShake and rumbleOn() then
		Rumble.pulse(seconds, strength)
	end
end

function Context.folder(): Folder
	local existing = folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "ClientEffects"
	created.Parent = Workspace
	folder = created
	return created
end

-- A part made on this client for an effect: anchored, never collides, never in a raycast, casts no shadow.
function Context.effectPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- The pivot of any model, or nil once it has left the world.
function Context.positionOf(instance: Instance): Vector3?
	if instance.Parent == nil then
		return nil
	end
	if instance:IsA("Model") then
		return (instance :: Model):GetPivot().Position
	elseif instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Attachment") then
		return (instance :: Attachment).WorldPosition
	end
	return nil
end

-- Calls `connect` with the RemoteEvent `name` as soon as it exists, now or whenever the server adds it: Net.on waits
-- with no end, and a feature's remotes only exist once the server has that feature.
function Context.whenRemote(name: string, connect: (RemoteEvent) -> ())
	task.spawn(function()
		local remotes = Remotes.folder()
		local function hook(child: Instance): boolean
			if child.Name ~= name or not child:IsA("RemoteEvent") then
				return false
			end
			connect(child :: RemoteEvent)
			return true
		end
		local existing = remotes:FindFirstChild(name)
		if existing ~= nil and hook(existing) then
			return
		end
		local waiting: RBXScriptConnection? = nil
		waiting = remotes.ChildAdded:Connect(function(child: Instance)
			if hook(child) and waiting ~= nil then
				waiting:Disconnect()
			end
		end)
	end)
end

-- #5000 (phone lag while walking, #4857, now that the place streams): about 17 effects each connected their own
-- Workspace.DescendantAdded, so every instance streaming in started that many handler threads. With the `fxOneAdded`
-- switch on (off by default) they share one connection that hands each new instance to every handler in turn, in the
-- order they joined; each runs under pcall, so one handler's error stays its own (reported once). Off, each handler
-- gets its own connection as before. The switch is read once, when the first handler joins (after LiveFlags' first
-- read, which the client waits for at start). None of the handlers yields.
-- #4857 (the Park landing hitch: 4,000 to 5,000 instances stream in in one frame, and Effects' handlers take 18 to
-- 27 ms of it): with the switch on, the shared connection only queues each new instance, and the handlers run
-- through the queue on the Heartbeat for at most ADDED_SPREAD_SECONDS a frame, so a burst is spread over several
-- frames. An instance gone again before its turn (streamed back out) is skipped, and a handler that joins later never
-- gets one queued before it joined (its own start walk found it). Every handler here is either
-- timer-driven or waits a frame itself, so a few frames late changes nothing on screen.
local ONE_ADDED_FLAG = "fxOneAdded"
local ADDED_SPREAD_SECONDS = 0.0015
local addedHandlers: { (Instance) -> () }? = nil
local addedOnError: { (unknown) -> () } = {}
local addedQueue: { Instance } = {}
local addedHead, addedTail = 1, 0 -- only ever count up, so a position names one instance for the session
local addedJoinedAt: { number } = {} -- each handler's addedTail when it joined: it walked everything up to there

function Context.onWorkspaceAdded(handler: (Instance) -> ())
	if addedHandlers == nil then
		if
			not LiveFlags.shown(
				ONE_ADDED_FLAG,
				ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. ONE_ADDED_FLAG)
			)
		then
			Workspace.DescendantAdded:Connect(handler)
			return
		end
		local handlers: { (Instance) -> () } = {}
		addedHandlers = handlers
		Workspace.DescendantAdded:Connect(function(instance: Instance)
			addedTail += 1
			addedQueue[addedTail] = instance
		end)
		RunService.Heartbeat:Connect(function()
			if addedHead > addedTail then
				return
			end
			local stop = os.clock() + ADDED_SPREAD_SECONDS
			while addedHead <= addedTail do
				local at = addedHead
				local instance = addedQueue[at]
				addedQueue[at] = nil
				addedHead += 1
				if instance.Parent ~= nil then
					for index, each in handlers do
						-- a handler that joined after this instance was queued found it in its own start walk
						if at > addedJoinedAt[index] then
							xpcall(each, addedOnError[index], instance)
						end
					end
				end
				if os.clock() >= stop then
					break
				end
			end
		end)
	end
	local handlers = addedHandlers :: { (Instance) -> () }
	table.insert(handlers, handler)
	table.insert(addedJoinedAt, addedTail)
	-- each handler's own error report, made once here so a streamed-in instance makes no new closure
	local warned = false
	table.insert(addedOnError, function(problem: unknown)
		if not warned then
			warned = true
			warn("[Effects] a Workspace.DescendantAdded handler failed: " .. tostring(problem))
		end
	end)
end

return Context
