--!strict
-- The Tackle on this client (data-model section 10c, v0.5 F41 as v0.11 F74). Turns the UI's button on while the
-- player stands in a catching area their tier opens, and on a press lunges this character TackleLungeStuds straight
-- ahead (characters are client-owned) and sends Tackle; the server decides hit or miss and checks everything again.
-- It answers ShoveResult: a hit stops the tackler's lunge and holds them TackleHitRecoverSeconds; the target's own
-- client pushes its character ShoveKnockbackStuds along the server's direction and holds it TackledDownSeconds after
-- the push; a miss holds the tackler TackleMissRecoverSeconds; and every client fires Moments.Shove, then BumpLoose
-- or BumpHeld, for sound and effects. Holding a player down disables the PlayerModule's controls, so the Humanoid
-- stays upright for the animation and WalkSpeed stays the server's (it changes when a carry starts or ends).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Shove = require(Shared:WaitForChild("Shove"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldController = require(script.Parent.WorldController)

local ShoveController = {}

local player = Players.LocalPlayer
local PUSH_SECONDS = 0.25 -- the push covers ShoveKnockbackStuds in this long
local VERDICT_SLACK = 0.3 -- seconds past the server's hit window for its ShoveResult to arrive (review S81)
-- After the lunge the dive carries on as a skid that slows from this speed to a stop over SKID_SECONDS, so the belly
-- slide on a miss has movement for the effects to follow; a hit stops it. 12 studs plus this 1.5 stays inside the
-- server's reach cap of TackleLungeStuds plus TackleHitSlackStuds.
local SKID_SPEED = 10
local SKID_SECONDS = 0.3

local lunge: LinearVelocity? = nil -- this character's lunge while it runs
local nextPressAt = 0 -- os.clock() this client may press again (TackleCooldownSeconds from the press)
local downUntil = 0 -- os.clock() the controls come back

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- The PlayerModule's controls, or nil when the default player scripts are not there.
local function controls(): any?
	local scripts = player:FindFirstChildOfClass("PlayerScripts")
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

local function setControls(on: boolean)
	local module = controls()
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

-- Holds this player still (no moving or jumping) for `seconds` from now: longer than any hold already running, or,
-- with `replace`, exactly that long (the tackler's own verdict sets its recovery).
local function holdDown(seconds: number, replace: boolean?)
	local untilAt = os.clock() + seconds
	if replace ~= true and untilAt <= downUntil then
		return
	end
	downUntil = untilAt
	setControls(false)
	task.delay(seconds, function()
		if downUntil == untilAt then -- nothing moved the end since
			setControls(true)
		end
	end)
end

local function release()
	downUntil = 0
	setControls(true)
end

-- True while this player stands inside a catching area their tier opens (the server's rule, checked again there).
local function inOpenArea(): boolean
	local root = rootPart()
	local state = UIController.state
	if not Config.BumpEnabled or root == nil or state == nil then
		return false
	end
	local zone = WorldController.zoneAt(root.Position)
	local area = if zone ~= nil then Catalog.getArea(zone:lower()) else nil
	return area ~= nil and state.tier >= area.tier
end

-- A LinearVelocity in the ground plane for `seconds`, so gravity still works and the humanoid takes over after.
local function slide(
	root: BasePart,
	direction: Vector3,
	studs: number,
	seconds: number
): LinearVelocity?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.5 then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ShoveAttachment"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Name = "ShovePush"
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	local velocity = flat.Unit * (studs / seconds)
	push.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	push.MaxForce = 1e6
	push.Parent = root
	Debris:AddItem(push, seconds)
	Debris:AddItem(attachment, seconds)
	return push
end

local function stopLunge()
	local current = lunge
	lunge = nil
	if current ~= nil and current.Parent ~= nil then
		local attachment = current.Attachment0
		current:Destroy()
		if attachment ~= nil then
			attachment:Destroy()
		end
	end
end

-- The dive: TackleLungeStuds in TackleLungeSeconds along `direction`, then the skid, as one ground-plane
-- LinearVelocity updated every frame. stopLunge ends it early.
local function startLunge(root: BasePart, direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	local unit = flat.Unit
	local attachment = Instance.new("Attachment")
	attachment.Name = "TackleAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TackleLunge"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.MaxForce = 1e6
	local speed = Config.TackleLungeStuds / Config.TackleLungeSeconds
	local first = unit * speed
	velocity.PlaneVelocity = Vector2.new(first.X, first.Z)
	velocity.Parent = root
	lunge = velocity
	local started = os.clock()
	task.spawn(function()
		while lunge == velocity and velocity.Parent ~= nil do
			local t = os.clock() - started
			local now: number
			if t < Config.TackleLungeSeconds then
				now = speed
			elseif t < Config.TackleLungeSeconds + SKID_SECONDS then
				now = SKID_SPEED * (1 - (t - Config.TackleLungeSeconds) / SKID_SECONDS)
			else
				break
			end
			local planar = unit * now
			velocity.PlaneVelocity = Vector2.new(planar.X, planar.Z)
			RunService.Heartbeat:Wait()
		end
		if lunge == velocity then
			stopLunge()
		end
	end)
end

-- Tells the UI's button how a press ended: ok false for a refusal; for the tackler's hit or miss also the outcome
-- and the target's UserId (0 on a miss) for its "Missed!" and "Tackled Alex!" (the extra arguments are optional on
-- the UI side).
local function report(ok: boolean, outcome: string?, targetUserId: number?)
	local result: any = UI.shove.result
	result(ok, outcome, targetUserId)
end

-- A press of the Tackle button or key. The UI hides or greys the button when a press would be refused; these are
-- the same checks so a stray key press does not lunge for nothing.
local function press()
	local root = rootPart()
	local state = UIController.state
	local now = os.clock()
	if
		root == nil
		or not inOpenArea()
		or (state ~= nil and state.carrying ~= nil)
		or now < nextPressAt
		or now < downUntil
	then
		return
	end
	nextPressAt = now + Config.TackleCooldownSeconds
	stopLunge()
	startLunge(root, root.CFrame.LookVector)
	-- held from the press until the verdict, so a miss never frees the tackler before its belly slide (S81)
	holdDown(Shove.window() + VERDICT_SLACK, true)
	Moments.TacklePress:Fire(root.Position)
	Net.fire("Tackle")
end

local function onShoveResult(
	outcome: string,
	shoverUserId: number,
	targetUserId: number,
	position: Vector3?,
	direction: Vector3?
)
	local role = if shoverUserId == player.UserId
		then "shover"
		elseif targetUserId == player.UserId then "target"
		else "bystander"
	if outcome == "refused" then
		if role == "shover" then
			-- the server spent nothing, so neither does this client
			nextPressAt = 0
			stopLunge()
			release()
			report(false)
			Moments.TackleRefused:Fire()
		end
		return
	end
	if outcome == "miss" then
		if role == "shover" then
			-- the skid finishes on its own; the tackler stays down from now
			holdDown(Config.TackleMissRecoverSeconds, true)
			report(true, "miss", 0)
		end
		return
	end
	if role == "shover" then
		stopLunge()
		holdDown(Config.TackleHitRecoverSeconds, true)
		report(true, outcome, targetUserId)
	end
	if role == "target" and typeof(direction) == "Vector3" then
		stopLunge()
		local root = rootPart()
		if root ~= nil then
			slide(root, direction, Config.ShoveKnockbackStuds, PUSH_SECONDS)
		end
		holdDown(PUSH_SECONDS + Config.TackledDownSeconds)
	end
	if typeof(position) ~= "Vector3" then
		return
	end
	Moments.Shove:Fire(role, position)
	if outcome == "loose" then
		Moments.BumpLoose:Fire(role, position)
	elseif outcome == "held" then
		Moments.BumpHeld:Fire(role, position)
	end
end

function ShoveController.start()
	-- The old Shove button still fires shove(targetUserId); the Tackle has no target, so any press is a lunge.
	UI.events.shove:Connect(function()
		press()
	end)
	local tackleEvent = (UI.events :: any).tackle -- the Tackle button's own event, once the UI has it (F74)
	if tackleEvent ~= nil then
		tackleEvent:Connect(press)
	end
	Net.on("ShoveResult", onShoveResult)
	player.CharacterAdded:Connect(function()
		-- a new character starts free
		lunge = nil
		downUntil = 0
		setControls(true)
	end)
	-- The button follows the area the player stands in; it hides itself while carrying or in a minigame.
	task.spawn(function()
		local shown: boolean? = nil
		while true do
			local on = inOpenArea()
			if on ~= shown then
				shown = on
				UI.shove.setEnabled(on)
			end
			task.wait(0.25)
		end
	end)
end

return ShoveController
