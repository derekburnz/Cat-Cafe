--!strict
-- The stuck cat that calls for help (#2912; Design-Agent 2026-11-12, on top of the stuck cat pointer). 140 of 582 new
-- players got their first bait cat and never started a rescue. While this player's save waits for its first rescue,
-- the cat in the Alleyway's starter trap asks for it: a warm, thin pillar of light stands over the trap and can be
-- seen from the camp, a "Help! 🐾" bubble rocks gently over it like a waving paw, the trap gives a small wiggle every
-- few seconds, and the cat meows as you come near (at most four times). Everything goes when your rescue bar opens,
-- while someone else is on that cat, and for good once your first rescue has started. Nothing counts down, nothing
-- says hurry and there is no arrow (Derek's no-arrows rule). Reduce Motion keeps the bubble and the trap still.
--
-- Sources: ProfileSync's `stuckGoal` (true from the first bait cat until the first rescue starts, shared/StuckGoal),
-- the StuckCat tag and that model's `Starter`, `Area`, `RescueSpotId` and `LockedBy` attributes (RescueService), and
-- the UIController's Moments.RescueStart, RescueDone, RescueFail and RescueCancel. The trap is WorldBuilder's
-- `<rescueSpotId>_Trap` model beside the spot's `RescueSpot` anchor; one built into the area's set keeps still. The
-- meow is Beats.hit("stuckCall", the cat) for Audio's strayCall. Listening only. Numbers in Presets.stuckCall.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StuckGoal = require(ReplicatedStorage.Shared.StuckGoal)

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)

local StuckCall = {}

type Call = {
	model: Model,
	foot: Part, -- unseen, under the pillar
	beam: Beam,
	halo: Beam, -- the soft glow around the pillar
	bubble: BillboardGui,
	card: Frame,
	rock: Tween?,
}

type Wiggle = { trap: Model, placed: CFrame, base: CFrame, began: number }

local waiting = false -- ProfileSync's stuckGoal
local busy = false -- this player's rescue bar is up
local call: Call? = nil
local wiggle: Wiggle? = nil
local wiggledAt = 0
local meowedAt: number? = nil
local meows = 0
local loop: RBXScriptConnection? = nil
local started = false

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

-- The cat in the Alleyway's starter trap, or nil while the trap is empty or has not streamed in.
local function starter(): Model?
	for _, instance in CollectionService:GetTagged("StuckCat") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("Starter") == true
			and instance:GetAttribute("Area") == StuckGoal.AREA
		then
			return instance :: Model
		end
	end
	return nil
end

-- The trap model beside the cat's rescue spot, or nil for a trap built into the area's set.
local function trapOf(model: Model): Model?
	local id = model:GetAttribute("RescueSpotId")
	if type(id) ~= "string" then
		return nil
	end
	for _, spot in CollectionService:GetTagged("RescueSpot") do
		if spot:GetAttribute("RescueSpotId") == id and spot:IsDescendantOf(Workspace) then
			local folder = spot.Parent
			local found = if folder ~= nil then folder:FindFirstChild(id .. "_Trap") else nil
			return if found ~= nil and found:IsA("Model") then found :: Model else nil
		end
	end
	return nil
end

local function settle()
	local w: Wiggle? = wiggle
	if w ~= nil then
		if w.trap.Parent ~= nil then
			w.trap:PivotTo(w.placed)
		end
		wiggle = nil
	end
end

local function clear()
	settle()
	local c: Call? = call
	if c ~= nil then
		call = nil
		if c.rock ~= nil then
			c.rock:Cancel()
		end
		c.foot:Destroy()
		c.bubble:Destroy()
	end
	local running = loop
	if running ~= nil then
		running:Disconnect()
		loop = nil
	end
end

local function make(model: Model): Call?
	if bodyOf(model) == nil then
		return nil -- not streamed in yet
	end
	local s = Presets.stuckCall
	local p, b = s.pillar, s.bubble
	local frame, size = model:GetBoundingBox()
	local top = frame.Position + Vector3.new(0, Logic.halfExtents(frame, size).Y, 0)

	local foot = Context.effectPart("StuckCallPillar", Vector3.new(0.2, 0.2, 0.2), p.colour)
	foot.Transparency = 1
	local from = Instance.new("Attachment")
	from.Name = "From"
	from.Position = Vector3.new(0, p.lift, 0)
	from.Parent = foot
	local to = Instance.new("Attachment")
	to.Name = "To"
	to.Position = Vector3.new(0, p.lift + p.height, 0)
	to.Parent = foot
	local beam = Instance.new("Beam")
	beam.Name = "Light"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(p.colour)
	beam.LightEmission = p.emission
	beam.LightInfluence = 0
	beam.Width0 = p.widthMin
	beam.Width1 = p.widthMin
	beam.Parent = foot
	local halo = beam:Clone() :: Beam
	halo.Name = "Halo"
	halo.LightEmission = 1
	halo.Width0 = p.widthMin * p.halo.wide
	halo.Width1 = p.widthMin * p.halo.wide
	halo.Transparency = NumberSequence.new(1)
	halo.Parent = foot
	foot.CFrame = CFrame.new(top)
	foot.Parent = Context.folder()

	local bubble = Instance.new("BillboardGui")
	bubble.Name = "EffectsStuckCall"
	bubble.Adornee = foot
	bubble.StudsOffsetWorldSpace = Vector3.new(0, b.above, 0)
	bubble.Size = UDim2.fromScale(b.width, b.height)
	bubble.LightInfluence = 0
	bubble.AlwaysOnTop = false -- walls in front hide it, as they hide the trap
	bubble.MaxDistance = b.within
	bubble.Enabled = false
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.92, 0.8)
	card.BackgroundColor3 = Presets.palette.offwhite
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Presets.stuckMark.colour
	stroke.Thickness = 2
	stroke.Parent = card
	local label = Instance.new("TextLabel")
	label.Name = "Words"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.78)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = b.text
	label.TextScaled = true
	label.TextColor3 = Presets.stuckMark.colour
	label.Parent = card
	card.Parent = bubble
	bubble.Parent = Context.folder()

	local rock: Tween? = nil
	if not Context.reducedMotion() then
		card.Rotation = -b.rock
		local made = TweenService:Create(
			card,
			TweenInfo.new(
				b.rockSeconds,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			),
			{ Rotation = b.rock }
		)
		made:Play()
		rock = made
	end
	return {
		model = model,
		foot = foot,
		beam = beam,
		halo = halo,
		bubble = bubble,
		card = card,
		rock = rock,
	}
end

-- Each frame while the cat calls: the pillar takes the width and fade for how far the camera is, and a wiggle in
-- progress moves the trap.
local function step()
	local c: Call? = call
	if c == nil then
		return
	end
	local p = Presets.stuckCall.pillar
	local camera = Workspace.CurrentCamera
	local at = c.foot.Position
	local distance = if camera ~= nil then (camera.CFrame.Position - at).Magnitude else 0
	local width, foot = Logic.stuckPillar(distance)
	c.beam.Width0 = width
	c.beam.Width1 = width
	c.beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, foot),
		NumberSequenceKeypoint.new(1 - p.topFade, foot),
		NumberSequenceKeypoint.new(1, 1),
	})
	local glow = math.min(1, foot + p.halo.add)
	c.halo.Width0 = width * p.halo.wide
	c.halo.Width1 = width * p.halo.wide
	c.halo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, glow),
		NumberSequenceKeypoint.new(1 - p.topFade, glow),
		NumberSequenceKeypoint.new(1, 1),
	})
	local w: Wiggle? = wiggle
	if w ~= nil then
		local o = Presets.trapShake
		local g = Presets.stuckCall.wiggle
		local t = os.clock() - w.began
		if w.trap.Parent == nil or t >= o.seconds then
			settle()
		else
			local tip, hop = Logic.trapShake(t, g.hits, g.needed, o)
			w.trap:PivotTo(
				w.base
					* CFrame.new(0, hop, 0)
					* CFrame.Angles(0, 0, math.rad(tip))
					* w.base:Inverse()
					* w.placed
			)
		end
	end
end

local function check()
	local s = Presets.stuckCall
	local model = starter()
	if
		model == nil
		or not Logic.stuckCallOn(waiting, busy, model:GetAttribute("LockedBy"))
		or Context.isNight()
	then
		clear()
		return
	end
	local had: Call? = call
	if had ~= nil and had.model ~= model then
		clear() -- the trap was refilled with another cat
		had = nil
	end
	local c: Call
	if had ~= nil then
		c = had
	else
		local made = make(model)
		if made == nil then
			return
		end
		call = made
		c = made
		wiggledAt = os.clock()
		if loop == nil then
			loop = RunService.RenderStepped:Connect(step)
		end
	end
	local at = c.foot.Position
	local distance = Context.distance(at)
	local now = os.clock()
	c.bubble.Enabled = distance <= s.bubble.within and distance > s.bubble.hideWithin
	if
		wiggle == nil
		and now - wiggledAt >= s.wiggle.every
		and distance <= s.wiggle.within
		and not Context.reducedMotion()
	then
		wiggledAt = now
		local trap = trapOf(model)
		if trap ~= nil then
			local box, size = trap:GetBoundingBox()
			wiggle = {
				trap = trap,
				placed = trap:GetPivot(),
				base = box * CFrame.new(0, -size.Y / 2, 0),
				began = now,
			}
		end
	end
	local m = s.meow
	if Logic.stuckMeowDue(meowedAt, meows, now, distance, m.near, m.gap, m.most) then
		local body = bodyOf(model)
		if body ~= nil then
			meowedAt = now
			meows += 1
			Beats.hit:Fire("stuckCall", body)
		end
	end
end

function StuckCall.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local flag = (state :: { [string]: unknown }).stuckGoal
		if type(flag) == "boolean" then
			waiting = flag -- a partial sync without it changes nothing
		end
	end)
	Moments.RescueStart:Connect(function()
		busy = true
		clear() -- at once: the trap is the rescue's to shake now
	end)
	local function ended()
		busy = false
	end
	Moments.RescueDone:Connect(ended)
	Moments.RescueFail:Connect(ended)
	Moments.RescueCancel:Connect(ended)
	CollectionService:GetInstanceRemovedSignal("StuckCat"):Connect(function(instance: Instance)
		local c: Call? = call
		if c ~= nil and (c.model :: Instance) == instance then
			clear()
		end
	end)
	task.spawn(function()
		while true do
			check()
			task.wait(Presets.stuckCall.checkEvery)
		end
	end)
end

return StuckCall
