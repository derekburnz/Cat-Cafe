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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WorldController = require(script.Parent.WorldController)

local ShoveController = {}

local player = Players.LocalPlayer
local PUSH_SECONDS = 0.25 -- the push covers ShoveKnockbackStuds in this long

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

-- Holds this player still (no moving or jumping) for `seconds` from now, or longer if already held longer.
local function holdDown(seconds: number)
	local untilAt = os.clock() + seconds
	if untilAt <= downUntil then
		return
	end
	downUntil = untilAt
	setControls(false)
	task.delay(seconds, function()
		if os.clock() + 1e-3 >= downUntil then
			setControls(true)
		end
	end)
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
	local look = root.CFrame.LookVector
	stopLunge()
	lunge = slide(root, look, Config.TackleLungeStuds, Config.TackleLungeSeconds)
	holdDown(Config.TackleLungeSeconds)
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
			UI.shove.result(false)
			Moments.TackleRefused:Fire()
		end
		return
	end
	if outcome == "miss" then
		if role == "shover" then
			stopLunge()
			holdDown(Config.TackleMissRecoverSeconds)
			UI.shove.result(true)
		end
		return
	end
	if role == "shover" then
		stopLunge()
		holdDown(Config.TackleHitRecoverSeconds)
		UI.shove.result(true)
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
