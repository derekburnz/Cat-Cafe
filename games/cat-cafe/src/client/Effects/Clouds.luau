--!strict
-- The full-screen clouds (F84, hometown-cannon.md sections 3b and 5; Derek 2026-10-28 13:56: "make the cloud cutscene
-- a little better"). On a cannon flight fluffy clouds rush out of the middle of the screen past the launching player
-- as they vanish into the sky, with streaks of wind and a warm sun glow ahead, and the whole tunnel banks gently. The
-- clouds fill the screen while the server moves the player, take on the destination's colour, then part like
-- curtains to either side over the camp. A cloud hop (Home from a wild area, and the night sweep) is the same
-- clouds without the cannon. This player's screen only; UI-Engineer's destination name card sits above it. With
-- Reduce Motion the clouds hold still, with no wind or banking, and only fade in and out.
--
-- Source: Cannon.luau calls Clouds.play with the plan and the server time it started at. Numbers in Presets.clouds.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Clouds = {}

type Lobe = { frame: Frame, gradient: UIGradient }

type Cloud = {
	holder: Frame,
	lobes: { Lobe },
	angle: number, -- radians round the middle of the screen
	progress: number, -- 0 far off in the middle to 1 past the edge
	size: number, -- of the screen's shorter side, at the edge
}

type Streak = { frame: Frame, angle: number, progress: number }

local gui: ScreenGui? = nil
local veil: Frame? = nil
local veilGradient: UIGradient? = nil
local riderLayer: Frame? = nil
local glows: { Frame } = {}
local clouds: { Cloud } = {}
local streaks: { Streak } = {}
local loop: RBXScriptConnection? = nil
local rng = Random.new()

local function circle(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- One cloud: a big round middle with two smaller lobes low at its sides and one on top, lit from above.
local function makeCloud(parent: Instance): Cloud
	local c = Presets.clouds
	local holder = Instance.new("Frame")
	holder.Name = "Cloud"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local lobes: { Lobe } = {}
	for _, shape in c.lobes do
		local frame = circle(holder, "Lobe")
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = frame
		frame.Position = UDim2.fromScale(0.5 + shape[1], 0.5 + shape[2])
		frame.Size = UDim2.fromScale(shape[3], shape[3])
		table.insert(lobes, { frame = frame, gradient = gradient })
	end
	return {
		holder = holder,
		lobes = lobes,
		angle = rng:NextNumber(0, 2 * math.pi),
		progress = 0,
		size = rng:NextNumber(c.cloudSize[1], c.cloudSize[2]),
	}
end

local function makeStreak(parent: Instance): Streak
	local frame = Instance.new("Frame")
	frame.Name = "Wind"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Presets.clouds.white
	frame.ZIndex = 3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return { frame = frame, angle = 0, progress = 0 }
end

-- The ScreenGui with its sky veil and sun glow, made on first use.
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
	made.Name = "EffectsClouds"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = Presets.clouds.displayOrder
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.Enabled = false
	local cover = Instance.new("Frame")
	cover.Name = "Veil"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BorderSizePixel = 0
	cover.BackgroundColor3 = Color3.new(1, 1, 1)
	cover.BackgroundTransparency = 1
	cover.ZIndex = 1
	local sky = Instance.new("UIGradient")
	sky.Rotation = 90 -- blue sky above, white cloud below
	sky.Parent = cover
	cover.Parent = made
	table.clear(glows)
	for i = 1, #Presets.clouds.glow do
		local glow = circle(made, "Glow")
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.ZIndex = 2
		glows[i] = glow
	end
	local rider = Instance.new("Frame")
	rider.Name = "Rider"
	rider.Size = UDim2.fromScale(1, 1)
	rider.BackgroundTransparency = 1
	rider.ZIndex = Presets.clouds.riderZ
	rider.Parent = made
	made.Parent = playerGui
	gui, veil, veilGradient, riderLayer = made, cover, sky, rider
	table.clear(clouds)
	table.clear(streaks)
	return made
end

-- Matches the clouds and the wind to the budget (the Low performance setting can change between flights) and
-- spreads them along the rush so they never arrive in a clump.
local function fill(parent: ScreenGui)
	local want = Context.budget.cloudPuffs
	local wind = math.floor(want / 2)
	while #clouds > want do
		(table.remove(clouds) :: Cloud).holder:Destroy()
	end
	while #clouds < want do
		table.insert(clouds, makeCloud(parent))
	end
	while #streaks > wind do
		(table.remove(streaks) :: Streak).frame:Destroy()
	end
	while #streaks < wind do
		table.insert(streaks, makeStreak(parent))
	end
	for i, cloud in clouds do
		cloud.progress = ((i - 1) / want + rng:NextNumber(0, 0.5 / want)) % 1
		cloud.angle = rng:NextNumber(0, 2 * math.pi)
	end
	for i, streak in streaks do
		streak.progress = (i - 1) / math.max(1, wind)
		streak.angle = rng:NextNumber(0, 2 * math.pi)
	end
end

-- The full-screen layer between the clouds behind and in front, for the launching player's gliding character
-- (Animation-Engineer's CannonGlide), or nil before the first play.
function Clouds.rider(): Frame?
	return riderLayer
end

function Clouds.stop()
	local running = loop
	if running ~= nil then
		running:Disconnect()
		loop = nil
	end
	local made = gui
	if made ~= nil then
		made.Enabled = false
	end
end

-- Plays one plan (Presets.clouds.cannon or .hop) that started at `startedAt` in server time, turning toward `tint`.
-- A new play replaces one still running.
function Clouds.play(startedAt: number, plan: Logic.CloudPlan, tint: Color3)
	Clouds.stop()
	local made = screen()
	local cover, sky = veil, veilGradient
	if made == nil or cover == nil or sky == nil then
		return
	end
	fill(made)
	made.Enabled = true
	local c = Presets.clouds
	local still = Context.reducedMotion()
	loop = RunService.RenderStepped:Connect(function(dt: number)
		local t = Workspace:GetServerTimeNow() - startedAt
		if t >= plan.partTo then
			Clouds.stop()
			return
		end
		local amount = Logic.cloudCover(t, plan)
		local k = Logic.cloudTint(t, plan)
		local white = c.white:Lerp(tint, c.tint.top * k)
		local lobeColours = ColorSequence.new({
			ColorSequenceKeypoint.new(0, white),
			ColorSequenceKeypoint.new(c.shadeFrom, white),
			ColorSequenceKeypoint.new(1, c.shade:Lerp(tint, c.tint.under * k)),
		})
		local parting = if t >= plan.partFrom then 1 - amount else 0
		-- the clouds arrive first and the sky fills in behind them, so the screen is fully covered at 1
		local solid = math.clamp((amount - 0.35) / 0.65, 0, 1)
		cover.BackgroundTransparency = 1 - solid
		sky.Color = ColorSequence.new(
			c.sky:Lerp(tint, c.tint.skyTop * k),
			c.white:Lerp(tint, c.tint.skyBottom * k)
		)
		local camera = Workspace.CurrentCamera
		local view = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
		local short = math.min(view.X, view.Y)
		local reach = view.Magnitude * 0.6 -- past the corners
		local bank = if still then Vector2.zero else Logic.cloudBank(t, c.bank) * short
		local middle = view / 2 + bank
		local sun = c.sun:Lerp(tint, c.tint.top * k)
		for i, glow in glows do
			local ring = c.glow[i]
			local d = ring[1] * short * (1 + parting)
			glow.Position = UDim2.fromOffset(middle.X, middle.Y)
			glow.Size = UDim2.fromOffset(d, d)
			glow.BackgroundColor3 = sun
			glow.BackgroundTransparency = 1 - ring[2] * solid * (1 - parting)
		end
		for _, streak in streaks do
			if not still then
				streak.progress += dt / (c.rush * c.windShare)
				if streak.progress >= 1 then
					streak.progress -= 1
					streak.angle = rng:NextNumber(0, 2 * math.pi)
				end
			end
			local p = streak.progress
			local r = (0.15 + p) * reach * 0.8
			streak.frame.Position = UDim2.fromOffset(
				middle.X + math.cos(streak.angle) * r,
				middle.Y + math.sin(streak.angle) * r
			)
			streak.frame.Size =
				UDim2.fromOffset(c.windLength * short * p, math.max(2, short * 0.006))
			streak.frame.Rotation = math.deg(streak.angle)
			streak.frame.BackgroundColor3 = white
			streak.frame.BackgroundTransparency = if still
				then 1
				else 1
					- c.windAlpha
						* math.sin(math.pi * p)
						* math.min(1, amount * 2)
						* (1 - parting)
		end
		for _, cloud in clouds do
			if not still then
				cloud.progress += dt / c.rush
				if cloud.progress >= 1 then
					cloud.progress -= 1
					cloud.angle = rng:NextNumber(0, 2 * math.pi)
				end
			end
			local p = cloud.progress
			local r = p * p * reach
			local x, y = math.cos(cloud.angle) * r, math.sin(cloud.angle) * r
			-- parting: the clouds draw aside like curtains, left ones left and right ones right
			if not still then
				x += (if x < 0 then -1 else 1) * parting * view.X * 0.7
				y *= 1 + parting * 0.3
			end
			-- solid lobes, so overlaps never show: a cloud puffs up as they rush in and fades only while far off
			local grow = if still then 1 else math.min(1, amount * 2)
			local d = cloud.size * short * (0.25 + 0.75 * p) * grow
			cloud.holder.Position = UDim2.fromOffset(middle.X + x, middle.Y + y)
			cloud.holder.Size = UDim2.fromOffset(d, d)
			cloud.holder.ZIndex = 4 + 2 * math.floor(p * 4) -- nearer clouds over farther ones and the rider
			local alpha = if still then math.min(1, amount * 2) else math.min(1, p * 4)
			for _, lobe in cloud.lobes do
				lobe.frame.BackgroundTransparency = 1 - alpha
				lobe.gradient.Color = lobeColours
			end
		end
	end)
end

return Clouds
