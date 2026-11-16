--!strict
-- The Ticket Booth toys in use (#4061, Ticket Booth spec 1.3, fun only): the Water Squirter and the Pool Noodle,
-- each in its player's hand in place of the net while the server's `HeldToy` names it (NetHold).
-- - Water Squirter: a short stream of water drops leaves the toy's `Muzzle`, arcs to where the server says the
--   shot lands (the nearest player in range, else ahead) and splashes there with a pastel ring and the campSplash
--   sound. Harmless: nothing happens to whoever it lands on.
-- - Pool Noodle: the arm swings it like a net smack that hits; as it lands it squishes and springs back, with a
--   small puff of sparkles and a squeak (toyBonk).
-- Source: the server's ToyUsed(userId, toy, target?) to the players in range; it is listened for as soon as the
-- server has it (Context.whenRemote), so this does nothing until the booth's toys are on. Listening only: the press
-- (UseToy) is the booth UI's. Numbers in Presets.toys.
-- Studio only: the Workspace attribute `ToyFxTest` = "squirter" or "noodle" puts that toy in your own hand (on this
-- client only) and uses it at a point ahead; "" puts it away.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local NetHold = require(script.Parent.NetHold)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local ToyFx = {}

type Drop = { part: BasePart, from: Vector3, to: Vector3, height: number, born: number }

local drops: { Drop } = {}
local flying: RBXScriptConnection? = nil
local started = false

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- Moves every drop along its arc each frame; a drop that lands is gone, and the loop stops with the last one.
local function fly()
	local now = os.clock()
	local seconds = Presets.toys.seconds
	for i = #drops, 1, -1 do
		local drop = drops[i]
		local alpha = (now - drop.born) / seconds
		if alpha >= 1 or drop.part.Parent == nil then
			drop.part:Destroy()
			table.remove(drops, i)
		else
			drop.part.Position = Logic.hopArc(drop.from, drop.to, drop.height, alpha)
		end
	end
	if #drops == 0 and flying ~= nil then
		flying:Disconnect()
		flying = nil
	end
end

local function launch(from: Vector3, to: Vector3, height: number)
	local p = Presets.toys
	local part = Context.effectPart(
		"ToyDrop",
		Vector3.new(p.dropSize, p.dropSize, p.dropSize),
		Presets.palette.pastelSky
	)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Glass
	part.Transparency = 0.25
	part.Position = from
	part.Parent = Context.folder()
	table.insert(drops, { part = part, from = from, to = to, height = height, born = os.clock() })
	if flying == nil then
		flying = RunService.Heartbeat:Connect(fly)
	end
end

local function splash(at: Vector3)
	local p = Presets.toys
	Particles.burst("splashDrops", at, p.splash)
	Particles.ring(at, Presets.palette.pastelSky, p.ring)
	Beats.hit:Fire("toySquirt", at)
end

-- The squirt from `character`'s toy (its Muzzle, else the hand's height in front of it) to `target`.
local function squirt(character: Model, root: BasePart, target: Vector3?)
	local p = Presets.toys
	local to = target or (root.Position + root.CFrame.LookVector * p.ahead)
	local from = root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 0.5, 0)
	local model = if NetHold.toy(character) == "squirter" then NetHold.net(character) else nil
	local muzzle = if model ~= nil then model:FindFirstChild("Muzzle", true) else nil
	if muzzle ~= nil and muzzle:IsA("Attachment") then
		from = (muzzle :: Attachment).WorldPosition
	end
	local count = if Context.reducedMotion()
		then 0
		elseif Context.tier == "low" or Context.lite then p.dropsLow
		else p.drops
	local height = p.lift + (to - from).Magnitude * p.liftPer
	task.spawn(function()
		for _ = 1, count do
			launch(from, to, height)
			task.wait(p.every)
		end
	end)
	task.delay(p.seconds, splash, to) -- as the first drop lands
end

-- The noodle's bonk on `character`: the swing, then at its landing the squish, sparkles and squeak.
local function bonk(character: Model)
	if not NetHold.swing(character) then
		return
	end
	task.delay(Presets.netSmack.land, function()
		local model = NetHold.net(character)
		if model == nil or NetHold.toy(character) ~= "noodle" then
			return
		end
		local p = Presets.toys
		local tip = model:GetBoundingBox().Position
		Particles.burst("catchSparkle", tip, p.stars, Presets.palette.sparkle)
		Beats.hit:Fire("toyBonk", tip)
		if Context.reducedMotion() then
			return
		end
		local born = os.clock()
		local squishing: RBXScriptConnection? = nil
		squishing = RunService.Heartbeat:Connect(function()
			local alpha = (os.clock() - born) / p.squishSeconds
			local live = model.Parent ~= nil
			if live then
				-- down to `squish` by half way, back to full size at the end
				local dip = 1 - math.abs(1 - 2 * math.clamp(alpha, 0, 1))
				model:ScaleTo(1 - (1 - p.squish) * dip)
			end
			if (alpha >= 1 or not live) and squishing ~= nil then
				squishing:Disconnect()
				squishing = nil
				if live then
					model:ScaleTo(1)
				end
			end
		end)
	end)
end

-- One use of `toy` by the player `userId`, aimed at `target` (the squirter's splash point).
function ToyFx.play(userId: unknown, toy: unknown, target: unknown)
	local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then rootOf(character) else nil
	local kind = Avatar.toyOf(toy)
	if character == nil or root == nil or kind == nil then
		return
	end
	if player ~= Players.LocalPlayer and Context.distance(root.Position) > Presets.toys.radius then
		return
	end
	if kind == "squirter" then
		squirt(character, root, if typeof(target) == "Vector3" then target :: Vector3 else nil)
	else
		bonk(character)
	end
end

local function studioTest()
	local toy = Workspace:GetAttribute("ToyFxTest")
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then rootOf(character) else nil
	if character == nil or root == nil then
		return
	end
	local kind = Avatar.toyOf(toy)
	character:SetAttribute("HeldToy", kind)
	if kind == nil then
		return
	end
	task.wait(0.6) -- the arm comes up and the toy shows first
	local ahead = root.Position
		+ root.CFrame.LookVector * Presets.toys.ahead
		- Vector3.new(0, 2.5, 0)
	ToyFx.play(Players.LocalPlayer.UserId, kind, ahead)
end

function ToyFx.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("ToyUsed", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(ToyFx.play)
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("ToyFxTest"):Connect(function()
			task.spawn(studioTest)
		end)
	end
end

return ToyFx
