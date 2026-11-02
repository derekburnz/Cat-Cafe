--!strict
-- Big pulls (F89, luck-and-rare-moments.md 2a and 2b; Derek 2026-10-30: "when securing something good leg/mythic decor
-- or cats possibly consider a bigger VFX or Animation to make it feel more rewarding"). When this player secures a
-- Legendary, a Mythical or a gold Epic cat, or a Legendary or Mythical crate piece opens (Market.luau), confetti in the
-- rarity colour bursts in from both edges of the screen, spinning and fluttering as it falls, over UI-Engineer's big
-- pull card, with a small camera shake; a Mythical adds a second wave of sparkles round the middle, and a gold cat
-- mixes gold in. Everyone near sees the catch pop of that rarity where the cat was secured (its beam from Legendary
-- up), and a Mythical's ground shockwave. Reduce Motion halves the confetti and drops the shake and the shockwave.
--
-- Source: the server's `SecuredRare(userId, catId, rarity, gold, variant)` to every client after the check-in, hooked
-- when the remote appears; the player's character for where. A rainbow cat (`variant` "rainbow", F99) is always a
-- big pull, with confetti in the six rainbow hues and Rainbow.beam. Numbers in Presets.bigPull and the budget's
-- pullConfetti.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Catch = require(script.Parent.Catch)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Rainbow = require(script.Parent.Rainbow)

local Pull = {}

type Piece = {
	frame: Frame,
	from: Vector2,
	velocity: Vector2,
	delay: number,
	spin: number,
	flutter: number,
	width: number,
}

type Sparkle = { frame: Frame, at: Vector2, delay: number, size: number }

local gui: ScreenGui? = nil
local loop: RBXScriptConnection? = nil
local rng = Random.new()
local below = RaycastParams.new()
below.FilterType = Enum.RaycastFilterType.Exclude
local started = false

local function screen(): ScreenGui?
	local existing = gui
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local made = Instance.new("ScreenGui")
	made.Name = "EffectsPull"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = Presets.bigPull.displayOrder
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.Parent = playerGui
	gui = made
	return made
end

local function stop()
	local running = loop
	if running ~= nil then
		running:Disconnect()
		loop = nil
	end
	local made = gui
	if made ~= nil then
		made:ClearAllChildren()
	end
end

local function piece(parent: Instance, colour: Color3, size: number, round: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Confetti"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = colour
	frame.Size = UDim2.fromOffset(size, if round then size else size * 0.55)
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- Confetti from both edges for this player's own pull of `rarity`, and a Mythical's sparkles. A new pull replaces one
-- still on screen.
function Pull.screen(rarity: string, gold: boolean, rainbow: boolean?)
	stop()
	local made = screen()
	if made == nil then
		return
	end
	local c = Presets.bigPull
	local reduced = Context.reducedMotion()
	local colour = Presets.rarity[rarity] or Presets.rarity.Common
	local colours =
		{ colour, colour:Lerp(Color3.new(1, 1, 1), 0.45), colour:Lerp(Color3.new(), 0.2) }
	table.insert(colours, Presets.palette.offwhite)
	table.insert(colours, Presets.palette.sparkle)
	if gold then
		for _, shade in c.gold do
			table.insert(colours, shade)
		end
	end
	if rainbow == true then
		-- a rainbow cat (F99): the six hues and white, whatever its rarity
		colours = table.clone(Presets.rainbow.hues)
		table.insert(colours, Presets.palette.offwhite)
	end
	local camera = Workspace.CurrentCamera
	local view = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local pieces: { Piece } = {}
	local count = Logic.pullCount(Context.budget.pullConfetti, reduced)
	for i = 1, count do
		local side = if i % 2 == 0 then 1 else -1
		local from, velocity =
			Logic.pullLaunch(side, rng:NextNumber(), rng:NextNumber(), rng:NextNumber(), view, c)
		local size = view.Y * rng:NextNumber(c.size[1], c.size[2])
		local round = rng:NextNumber() < c.round
		local frame = piece(made, colours[rng:NextInteger(1, #colours)], size, round)
		frame.Position = UDim2.fromOffset(from.X, from.Y)
		frame.Rotation = rng:NextNumber(0, 360)
		frame.Visible = false
		table.insert(pieces, {
			frame = frame,
			from = from,
			velocity = velocity,
			delay = rng:NextNumber(0, c.stagger),
			spin = if reduced then 0 else rng:NextNumber(-c.spin, c.spin),
			flutter = if round or reduced then 0 else rng:NextNumber(c.flutter[1], c.flutter[2]),
			width = size,
		})
	end
	local sparkles: { Sparkle } = {}
	if rarity == "Mythical" then
		local s = c.sparkles
		local middle = view / 2
		for _ = 1, if reduced then math.ceil(s.count / 2) else s.count do
			local angle = rng:NextNumber(0, 2 * math.pi)
			local reach = view.Y * rng:NextNumber(s.radius[1], s.radius[2])
			local size = view.Y * s.size * rng:NextNumber(0.6, 1)
			local frame = piece(made, colours[rng:NextInteger(1, #colours)], size, false)
			frame.Size = UDim2.fromOffset(size, size)
			frame.Rotation = 45 -- a little diamond
			frame.Visible = false
			table.insert(sparkles, {
				frame = frame,
				at = middle + Vector2.new(math.cos(angle) * reach * 1.4, math.sin(angle) * reach),
				delay = s.at + rng:NextNumber(0, s.seconds * 0.4),
				size = size,
			})
		end
	end
	Context.shake(c.shake, c.shakeStuds) -- off with Reduce Motion or Screen shake off
	local gravity, began = view.Y * c.gravity, os.clock()
	loop = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - began
		if t >= c.seconds then
			stop()
			return
		end
		local fade = Logic.pullFade(t, c.seconds, c.fade)
		for _, p in pieces do
			local age = t - p.delay
			p.frame.Visible = age >= 0
			if age >= 0 then
				local at = Logic.confettiAt(p.from, p.velocity, gravity, c.drag, age)
				p.frame.Position = UDim2.fromOffset(at.X, at.Y)
				p.frame.Rotation += p.spin * dt
				if p.flutter > 0 then
					local flip = math.abs(math.cos(2 * math.pi * p.flutter * age))
					p.frame.Size = UDim2.fromOffset(p.width * (0.15 + 0.85 * flip), p.width * 0.55)
				end
				p.frame.BackgroundTransparency = fade
			end
		end
		for _, s in sparkles do
			local k = (t - s.delay) / (c.sparkles.seconds * 0.6)
			s.frame.Visible = k > 0 and k < 1
			if k > 0 and k < 1 then
				local grow = math.sin(math.pi * k) -- pops in and out
				s.frame.Size = UDim2.fromOffset(s.size * grow, s.size * grow)
				s.frame.Position = UDim2.fromOffset(s.at.X, s.at.Y)
			end
		end
	end)
end

-- The ground under `at`, within `depth` studs and past `ignore` and the effects, or nil when there is none.
function Pull.floorBelow(at: Vector3, ignore: { Instance }, depth: number): Vector3?
	local skip = table.clone(ignore)
	table.insert(skip, Context.folder())
	below.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(at, Vector3.new(0, -depth, 0), below)
	return if hit ~= nil then hit.Position else nil
end

-- The world side of a big pull at `at` (where the cat went into the basket, or the open crate's rim) over `ground`:
-- the catch pop of `rarity` and a Mythical's shockwave, on `floor` when given (a crate's sits on the counter).
function Pull.world(at: Vector3, ground: Vector3, rarity: string, floor: Vector3?)
	Catch.pop(at, ground, rarity)
	if rarity ~= "Mythical" or Context.reducedMotion() then
		return
	end
	local w = Presets.bigPull.shockwave
	local colour = Presets.rarity.Mythical
	local centre = floor or ground
	Particles.ring(centre + Vector3.new(0, 0.1, 0), colour, w.diameter, w.seconds)
	task.delay(w.puffAt, function()
		for i = 1, w.puffs do
			local angle = 2 * math.pi * i / w.puffs
			local edge = Vector3.new(math.cos(angle), 0.3, math.sin(angle)) * (w.diameter / 2)
			Particles.burst("dust", centre + edge, 2, colour:Lerp(Color3.new(1, 1, 1), 0.5))
		end
	end)
end

-- SecuredRare: the big pull for the securing player's screen, and its world side for anyone near.
local function secured(userId: unknown, rarity: unknown, gold: unknown, variant: unknown)
	if type(userId) ~= "number" or type(rarity) ~= "string" then
		return
	end
	local shiny = gold == true
	local rainbow = variant == "rainbow"
	if not Logic.bigPull(rarity, shiny, rainbow) then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local mine = player == Players.LocalPlayer
	if mine then
		Pull.screen(rarity, shiny, rainbow)
	end
	if character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local at = (root :: BasePart).Position
	if not mine and Context.distance(at) > Presets.bigPull.within then
		return
	end
	local ground = Pull.floorBelow(at, { character }, 10) or at - Vector3.new(0, 3, 0)
	Pull.world(at + Vector3.new(0, 1.5, 0), ground, rarity)
	if rainbow then
		Rainbow.beam(ground)
	end
end

function Pull.start()
	if started then
		return
	end
	started = true
	-- SecuredRare(userId, catId, rarity, gold, variant). Net.on waits for the remote with no end, and it only exists
	-- once the server has F89, so this hooks it up whenever it appears instead.
	task.spawn(function()
		local folder = Remotes.folder()
		local function hook(child: Instance): boolean
			if child.Name ~= "SecuredRare" or not child:IsA("RemoteEvent") then
				return false
			end
			(child :: RemoteEvent).OnClientEvent:Connect(
				function(
					userId: unknown,
					_catId: unknown,
					rarity: unknown,
					gold: unknown,
					variant: unknown
				)
					secured(userId, rarity, gold, variant)
				end
			)
			return true
		end
		local existing = folder:FindFirstChild("SecuredRare")
		if existing ~= nil and hook(existing) then
			return
		end
		local waiting: RBXScriptConnection? = nil
		waiting = folder.ChildAdded:Connect(function(child: Instance)
			if hook(child) and waiting ~= nil then
				waiting:Disconnect()
			end
		end)
	end)
end

return Pull
