--!strict
-- Shove on this client (data-model section 10c, v0.5 F41). Turns the UI's Shove button on while the player stands
-- in a catching area their tier opens, forwards its press as Bump, and answers ShoveResult: the target's own client
-- pushes its character ShoveKnockbackStuds along the server's direction (characters are client-owned), and every
-- client fires Moments.Shove, then BumpLoose or BumpHeld, for sound and effects. The server checks everything again.

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
local PUSH_SECONDS = 0.25 -- the push covers ShoveKnockbackStuds in this long, then the player has control again

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
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

-- A LinearVelocity in the ground plane for PUSH_SECONDS, so gravity still works and the humanoid takes over after.
local function pushSelf(direction: Vector3)
	local root = rootPart()
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if root == nil or flat.Magnitude < 0.5 then
		return
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
	local velocity = flat.Unit * (Config.ShoveKnockbackStuds / PUSH_SECONDS)
	push.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	push.MaxForce = 1e6
	push.Parent = root
	Debris:AddItem(push, PUSH_SECONDS)
	Debris:AddItem(attachment, PUSH_SECONDS)
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
			UI.shove.result(false)
		end
		return
	end
	if role == "shover" then
		UI.shove.result(true)
	end
	if role == "target" and typeof(direction) == "Vector3" then
		pushSelf(direction)
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
	UI.events.shove:Connect(function(targetUserId: number)
		Net.fire("Bump", targetUserId)
	end)
	Net.on("ShoveResult", onShoveResult)
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
