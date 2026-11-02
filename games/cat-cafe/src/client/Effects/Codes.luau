--!strict
-- The Codes Cat's walk-in circle (F65, design v0.10; Derek 2026-10-27 20:10: "make code cat have a stand and a clear
-- area circle to walk into to open code entering menu"). The circle itself is modelled (`CodesCircle` in the
-- `CodesCat` station) and the code box is the UI's; this adds a soft mint ring round the inside of its rim that
-- breathes so it reads as something to step into, brightens while you stand in it, sends a few motes up when you are
-- near and answers your step in with a ring and sparkles. In and out use the code box's own edges
-- (Logic.insideCircle with Config.CodesCircleRadius), so the glow and the box agree. The ring is drawn flat on a
-- SurfaceGui (no Neon bloom) and leaves the middle clear, so the ticket on the circle reads (Derek 2026-10-28 00:47:
-- "too bright and can't see what symbol its showing"; it was a Neon disc over the whole circle).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Codes = {}

type Circle = {
	station: Instance,
	centre: Vector3, -- on top of the circle
	radius: number,
	glow: Part, -- invisible; the ring's SurfaceGui and the motes' pad hang off it
	strokes: { UIStroke }, -- the ring, then the fainter halo inside it
	breath: { Tween },
	motes: ParticleEmitter?,
	inside: boolean,
}

local circles: { [Instance]: Circle } = {}
local started = false

-- CodesCircleRadius from the shared Config once the engineer adds it, so the glow matches the box; until then the
-- design's 4 studs.
local function circleRadius(): number?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared ~= nil then shared:FindFirstChild("Config") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, config = pcall(require, module)
	local radius = if ok and type(config) == "table" then (config :: any).CodesCircleRadius else nil
	return if type(radius) == "number" and radius > 0 then radius else nil
end

-- The top centre of a flat part or model and its radius on the ground, from its world-axis extents.
local function flatOf(instance: Instance): (Vector3?, number)
	local frame: CFrame, size: Vector3
	if instance:IsA("BasePart") then
		frame, size = (instance :: BasePart).CFrame, (instance :: BasePart).Size
	elseif instance:IsA("Model") then
		frame, size = (instance :: Model):GetBoundingBox()
	else
		return nil, 0
	end
	local half = Logic.halfExtents(frame, size)
	return frame.Position + Vector3.new(0, half.Y, 0), math.max(half.X, half.Z)
end

-- How see-through a stroke is at the ring's `transparency`: the ring itself, or the halo at haloShare of it.
local function strokeTransparency(index: number, transparency: number): number
	if index == 1 then
		return transparency
	end
	return 1 - (1 - transparency) * Presets.codes.haloShare
end

local function setRing(circle: Circle, transparency: number)
	for index, stroke in circle.strokes do
		stroke.Transparency = strokeTransparency(index, transparency)
	end
end

local function breathe(circle: Circle)
	for _, running in circle.breath do
		running:Cancel()
	end
	table.clear(circle.breath)
	local c = Presets.codes
	if circle.inside then
		setRing(circle, c.inside)
		return
	end
	setRing(circle, c.glow[1])
	if Context.reducedMotion() then
		return -- a steady glow
	end
	local info =
		TweenInfo.new(c.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for index, stroke in circle.strokes do
		local tween = TweenService:Create(
			stroke,
			info,
			{ Transparency = strokeTransparency(index, c.glow[2]) }
		)
		tween:Play()
		table.insert(circle.breath, tween)
	end
end

-- The ring: a flat SurfaceGui on the glow part's top, a circle `inset` in from the edge with a `ring` wide stroke
-- just inside it and a `halo` wide one inside that.
local function drawRing(glow: Part, radius: number): { UIStroke }
	local c = Presets.codes
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CodesRing"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = c.pixelsPerStud
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local strokes: { UIStroke } = {}
	local across = radius - c.inset
	for _, band in { { across, c.ring }, { across - c.ring, c.halo } } do
		local edge, wide = band[1], band[2]
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(edge / radius, edge / radius)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Presets.palette.mint
		stroke.Thickness = wide * c.pixelsPerStud
		stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		stroke.Parent = frame
		frame.Parent = gui
		table.insert(strokes, stroke)
	end
	gui.Parent = glow
	return strokes
end

local function remove(station: Instance)
	local circle: Circle? = circles[station]
	if circle == nil then
		return
	end
	circles[station] = nil
	for _, running in circle.breath do
		running:Cancel()
	end
	circle.glow:Destroy() -- the ring and the motes' pad too
end

local function add(station: Instance)
	if circles[station] ~= nil or not station:IsDescendantOf(Workspace) then
		return -- the stand's template in ReplicatedStorage.Assets carries the tag too
	end
	local found = station:FindFirstChild("CodesCircle", true)
	if found == nil then
		return -- streamed in later: tried again at the next check
	end
	local centre, modelled = flatOf(found)
	if centre == nil then
		return
	end
	local c = Presets.codes
	local radius = circleRadius() or (if modelled > 0.5 then modelled else c.radius)
	local top = centre + Vector3.new(0, c.lift, 0)
	local glow = Context.effectPart(
		"CodesGlow",
		Vector3.new(radius * 2, 0.05, radius * 2),
		Presets.palette.mint
	)
	glow.Transparency = 1
	glow.CFrame = CFrame.new(top)
	glow.Parent = Context.folder()
	local circle: Circle = {
		station = station,
		centre = top,
		radius = radius,
		glow = glow,
		strokes = drawRing(glow, radius),
		breath = {},
		motes = nil,
		inside = false,
	}
	circles[station] = circle
	breathe(circle)
end

-- Motes rise off a circle you are near, inside the steady budget's range; none in Low performance. They come off
-- an invisible square pad that fits inside the circle (the glow part is the circle's whole square, so its corners
-- stick out).
local function mote(circle: Circle, near: boolean)
	local on = near and not Context.lowPerformance
	local motes = circle.motes
	if on and motes == nil then
		local side = circle.radius * Presets.codes.padShare
		local pad =
			Context.effectPart("CodesMotes", Vector3.new(side, 0.05, side), Presets.palette.mint)
		pad.Transparency = 1
		pad.CFrame = CFrame.new(circle.centre)
		pad.Parent = circle.glow
		local made = Particles.make(Presets.emitters.codesMotes)
		made.Name = "codesMotes"
		made.Parent = pad
		circle.motes = made
		motes = made
	end
	if motes ~= nil then
		if on then
			Particles.switchOn(motes, "codesMotes")
		else
			motes.Enabled = false
		end
	end
end

local function check()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local c = Presets.codes
	for station, circle in circles do
		if station.Parent == nil or circle.glow.Parent == nil then
			remove(station)
			continue
		end
		local flat = Vector3.new(focus.X - circle.centre.X, 0, focus.Z - circle.centre.Z).Magnitude
		local inside = Logic.insideCircle(circle.inside, flat, circle.radius, c.leaveAfter)
		if inside ~= circle.inside then
			circle.inside = inside
			breathe(circle)
			if inside then
				Particles.ring(
					circle.centre,
					Presets.palette.mint,
					circle.radius * 2 + c.ringPad,
					c.ringSeconds
				)
				Particles.burst("gateSparkle", circle.centre, c.sparkles)
			end
		end
		mote(circle, (focus - circle.centre).Magnitude <= Context.budget.ambientRadius)
	end
end

function Codes.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("CodesCat"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("CodesCat"):Connect(remove)
	task.spawn(function()
		while true do
			for _, station in CollectionService:GetTagged("CodesCat") do
				add(station) -- also a circle that streamed in after its station
			end
			check()
			task.wait(Presets.codes.checkEvery)
		end
	end)
end

return Codes
