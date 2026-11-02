--!strict
-- The net swing's whoosh (F93, catch-rework.md sections 1 and 5): over the downswing of each smack, a short pale trail
-- sweeps off the net between its hoop and a point partway down the handle, like a swung racket, and fades a moment
-- later. It starts with NetHold's smack: on the swinger's own screen at the press (Moments.NetSmackPress) and on
-- everyone else's when the server's NetSwung arrives, hit or miss. Your own swing always draws one; other players'
-- within `within` studs while fewer than budget.netTrails are drawing. None with Reduce Motion or while the net is
-- away (NetHold.net is nil then). Listening only: nothing here fires a remote. Numbers in Presets.netTrail.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local NetHold = require(script.Parent.NetHold)
local Presets = require(script.Parent.Presets)

local NetTrail = {}

local drawing = 0 -- whooshes on screen now
local started = false

-- The net's hoop (its part farthest from the Grip) and the trail's two edges in world space: the hoop's far end and a
-- point `inner` of the way out to it from the grip.
local function edges(net: Model): (BasePart?, Vector3, Vector3)
	local grip = net:FindFirstChild("Grip", true)
	local from = if grip ~= nil and grip:IsA("Attachment")
		then (grip :: Attachment).WorldPosition
		else net:GetPivot().Position
	local hoop: BasePart? = nil
	local farthest = -1
	for _, descendant in net:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local distance = (part.Position - from).Magnitude
			if distance > farthest then
				hoop, farthest = part, distance
			end
		end
	end
	if hoop == nil or farthest <= 0 then
		return nil, from, from
	end
	local head = hoop :: BasePart
	local way = (head.Position - from).Unit
	local half = Logic.halfExtents(head.CFrame, head.Size)
	local reach = math.abs(way.X) * half.X + math.abs(way.Y) * half.Y + math.abs(way.Z) * half.Z
	local tip = head.Position + way * reach
	return head, tip, from + (tip - from) * Presets.netTrail.inner
end

local function whoosh(character: Model?, mine: boolean)
	if character == nil or Context.reducedMotion() then
		return
	end
	local p = Presets.netTrail
	if not mine and drawing >= Context.budget.netTrails then
		return
	end
	local net = NetHold.net(character)
	if net == nil then
		return
	end
	if not mine and Context.distance(net:GetPivot().Position) > p.within then
		return
	end
	local hoop, tip, inner = edges(net)
	if hoop == nil then
		return
	end
	local part = hoop :: BasePart
	local outer = Instance.new("Attachment")
	outer.Name = "EffectsWhooshTip"
	outer.Position = part.CFrame:PointToObjectSpace(tip)
	outer.Parent = part
	local near = Instance.new("Attachment")
	near.Name = "EffectsWhooshInner"
	near.Position = part.CFrame:PointToObjectSpace(inner)
	near.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "EffectsWhoosh"
	trail.Attachment0 = outer
	trail.Attachment1 = near
	trail.Lifetime = p.lifetime
	trail.MinLength = 0
	trail.FaceCamera = false
	trail.LightEmission = p.lightEmission
	trail.Color = ColorSequence.new(p.colors[1], p.colors[2])
	trail.Transparency = NumberSequence.new(p.transparency, 1)
	trail.WidthScale = NumberSequence.new(1, 0.4)
	trail.Enabled = false
	trail.Parent = part
	drawing += 1
	task.delay(p.from, function()
		if trail.Parent ~= nil then
			trail.Enabled = true
		end
	end)
	task.delay(p.to, function()
		if trail.Parent ~= nil then
			trail.Enabled = false
		end
	end)
	task.delay(p.to + p.lifetime, function()
		drawing -= 1
		trail:Destroy()
		outer:Destroy()
		near:Destroy()
	end)
end

function NetTrail.start()
	if started then
		return
	end
	started = true
	-- The engineer's swing moments (F93, #667), once Moments has them; until then nothing swings.
	local moments = Moments :: any
	if moments.NetSmackPress ~= nil then
		moments.NetSmackPress:Connect(function()
			whoosh(Players.LocalPlayer.Character, true)
		end)
	end
	if moments.NetSwung ~= nil then
		moments.NetSwung:Connect(function(userId: unknown)
			if type(userId) ~= "number" or userId == Players.LocalPlayer.UserId then
				return -- your own swing drew its whoosh at the press
			end
			local player = Players:GetPlayerByUserId(userId)
			whoosh(if player ~= nil then player.Character else nil, false)
		end)
	end
end

return NetTrail
