--!strict
-- The net swing on this client (F93, catch-rework.md section 1). A left click in the world, R2 on a gamepad or the
-- UI's Net button on a touch screen (`UI.events.netSwing`, once the UI has it; until then a tap in the world) sends
-- SwingNet with no arguments, and Moments.NetSmackPress starts the smack on this screen at once. A click on the HUD
-- never swings. The server judges the swing NetSmackDelay after it arrives and tells every nearby client with
-- NetSwung(userId, hit), passed on as Moments.NetSwung for the smack elsewhere, the bounce on a miss and the whoosh.
-- A press the server would refuse (carrying, in a catch or a rescue, flying, in a camp, inside NetSwingCooldown,
-- during the intro) does nothing here either, so the net never smacks for nothing.
-- Moments.NetInReach names the stray a swing would land on right now (shared/NetSwing.pick on the strays' replicated
-- attributes), for the UI's glow; `UI.net.setEnabled`, when the UI has it, shows the Net button while a swing could
-- go. Both judge from shared/NetSwing.landingOrigin, where the root will be when the net lands. Controllers/NetMarker
-- draws the swing's landing fan on the ground while a swing could go with a stray within MARKER_STUDS (Derek
-- 2026-11-03), gold while one is in reach, flashing as a press lands.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local NetMarker = require(script.Parent.NetMarker)
local NetSwing = require(Shared:WaitForChild("NetSwing"))
local UI = require(script.Parent.Parent.UI)

local NetSwingController = {}

local player = Players.LocalPlayer
local REACH_TICK = 0.1 -- seconds between in-reach checks
local MARKER_STUDS = 24 -- the landing marker shows while a swingable stray is this near on the ground plane
-- A catch or rescue whose end never reached this client stops holding the net back after this long.
local CATCH_HOLD_SECONDS = 30
local RESCUE_HOLD_SECONDS = Config.RescueAttemptMaxSeconds + 10

local nextSwingAt = 0 -- os.clock() this client may swing again
local catchingUntil = 0 -- os.clock(): circles up, from CatchStart to CatchSuccess or CatchFail
-- os.clock(): the rescue bar or its falling cat, from RescueStart to RescueDone, RescueFail or RescueCancel
local rescuingUntil = 0
local inIntro = false
local inReach: Model? = nil

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- True while a swing could go: alive, the net out (no cat in the arms), not in a minigame, the intro, a flight or a
-- camp. The server checks the same again.
local function canSwing(): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or (humanoid :: Humanoid).Health <= 0 then
		return false
	end
	local now = os.clock()
	if now < catchingUntil or now < rescuingUntil or inIntro then
		return false
	end
	return character:GetAttribute("CarryingCatId") == nil
		and character:GetAttribute("NetHidden") ~= true
		and character:GetAttribute("Launching") ~= true
		and character:GetAttribute("CloudHopAt") == nil
		and character:GetAttribute("Camp") == nil
end

local function press()
	local now = os.clock()
	if now < nextSwingAt or not canSwing() then
		return
	end
	nextSwingAt = now + Config.NetSwingCooldown
	NetMarker.pressed()
	Moments.NetSmackPress:Fire()
	Net.fire("SwingNet")
end

-- The body a stray is judged by, as the server's stray.body: its PrimaryPart, else its first part.
local function bodyOf(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary ~= nil then
		return primary
	end
	return model:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

-- The stray a swing pressed now would land on, from what the server shows: not running (FleeingUntil) and not
-- locked by someone else (LockedBy); and whether any such stray is within MARKER_STUDS.
local function findInReach(): (Model?, boolean)
	local root = rootPart()
	if root == nil or not canSwing() then
		return nil, false
	end
	local now = Workspace:GetServerTimeNow()
	local targets: { NetSwing.Target } = {}
	local byId: { [string]: Model } = {}
	local near = false
	for _, instance in CollectionService:GetTagged("Stray") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local model = instance :: Model
		local fleeing = model:GetAttribute("FleeingUntil")
		local locked = model:GetAttribute("LockedBy")
		local beginner = model:GetAttribute("Beginner") -- F87: another beginner's tutorial stray
		local id = model:GetAttribute("StrayId")
		local body = bodyOf(model)
		if
			type(id) ~= "string"
			or body == nil
			or (type(fleeing) == "number" and fleeing > now)
			or (type(locked) == "number" and locked ~= 0 and locked ~= player.UserId)
			or (type(beginner) == "number" and beginner ~= 0 and beginner ~= player.UserId)
		then
			continue
		end
		local position = (body :: BasePart).Position
		byId[id] = model
		table.insert(targets, { id = id, position = position })
		local flat = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		near = near or flat.Magnitude <= MARKER_STUDS
	end
	local origin = NetSwing.landingOrigin(root.Position, root.AssemblyLinearVelocity)
	local picked = NetSwing.pick(origin, root.CFrame.LookVector, targets)
	return if picked ~= nil then byId[picked.id] else nil, near
end

local function watchReach()
	local enabled: boolean? = nil
	while true do
		local found, near = findInReach()
		if found ~= inReach then
			inReach = found
			Moments.NetInReach:Fire(found)
		end
		local on = canSwing()
		NetMarker.setShown(on and near)
		NetMarker.setInReach(found ~= nil)
		if on ~= enabled then
			enabled = on
			local net: any = (UI :: any).net
			local setEnabled: unknown = if net ~= nil then net.setEnabled else nil
			if type(setEnabled) == "function" then
				(setEnabled :: (boolean) -> ())(on)
			end
		end
		task.wait(REACH_TICK)
	end
end

function NetSwingController.start()
	local uiEvents = UI.events :: any
	local button = uiEvents.netSwing
	if button ~= nil then
		button:Connect(press) -- the Net button on a touch screen (UI-Engineer)
	else
		-- until the UI has its Net button, a tap in the world swings on a touch screen
		UserInputService.TouchTapInWorld:Connect(
			function(_position: Vector2, processedByUI: boolean)
				if not processedByUI then
					press()
				end
			end
		)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return -- a click on the HUD, a text box or a bound action
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2
		then
			press()
		end
	end)
	Net.on("NetSwung", function(userId: unknown, hit: unknown)
		if type(userId) == "number" then
			Moments.NetSwung:Fire(userId, hit == true)
		end
	end)

	Moments.CatchStart:Connect(function()
		catchingUntil = os.clock() + CATCH_HOLD_SECONDS
	end)
	Moments.CatchSuccess:Connect(function()
		catchingUntil = 0
	end)
	Moments.CatchFail:Connect(function()
		catchingUntil = 0
	end)
	Moments.RescueStart:Connect(function()
		rescuingUntil = os.clock() + RESCUE_HOLD_SECONDS
	end)
	for _, ended in { Moments.RescueDone, Moments.RescueFail, Moments.RescueCancel } :: { any } do
		ended:Connect(function()
			rescuingUntil = 0
		end)
	end
	Moments.IntroStart:Connect(function()
		inIntro = true
	end)
	Moments.IntroEnd:Connect(function()
		inIntro = false
	end)
	player.CharacterAdded:Connect(function()
		-- a new character starts with nothing running
		catchingUntil = 0
		rescuingUntil = 0
	end)
	NetMarker.start(rootPart)
	task.spawn(watchReach)
end

return NetSwingController
