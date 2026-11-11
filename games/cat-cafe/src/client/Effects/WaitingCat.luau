--!strict
-- The stray waiting for your second cat (#3022, Derek2 2026-11-10: "make it obvious to go catch second cat"). From
-- the first customer served until the second catch, the server keeps one alley stray waiting for each new player,
-- its number attribute `WaitsFor` set to that player's UserId (shared/SecondCat, #3038). On that player's screen only,
-- a column of gold sparkles rises off it and a gold ring pulses out at its feet every few seconds, so it stands out
-- from across the alley where UI's GuideTrail leads. #3238 (only 51 of 139 players reached the trail): a gold paw
-- badge floats over it, drawn through walls, so it shows from the cafe; and after `seconds` the rings slow down
-- instead of stopping, so the beacon lasts until the cat is caught or gone. It starts `delay` seconds after the cat
-- first shows (SecondCat's TRAIL_DELAY_SECONDS and TRAIL_SECONDS when present). Reduce Motion keeps the sparkles and a
-- still badge without the rings; Low performance keeps the badge and rings without the sparkles. Listening only.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the world, always facing the camera; AlwaysOnTop draws it
-- over walls. It is made by this client, so no other player sees it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local WaitingCat = {}

local started = false
local cat: Model? = nil
local seenAt = 0
local ringAt = 0
local anchor: Attachment? = nil
local emitter: ParticleEmitter? = nil
local badge: Attachment? = nil

-- SecondCat's attribute name and timings, if that module is in, else Presets.waitingCat's.
local function rules(): (string, number, number)
	local p = Presets.waitingCat
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared ~= nil then shared:FindFirstChild("SecondCat") else nil
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, found = pcall(require, module)
		if ok and type(found) == "table" then
			local s = found :: any
			local attribute = if type(s.ATTRIBUTE) == "string" then s.ATTRIBUTE else p.attribute
			local delay = if type(s.TRAIL_DELAY_SECONDS) == "number"
				then s.TRAIL_DELAY_SECONDS
				else p.delay
			local seconds = if type(s.TRAIL_SECONDS) == "number" then s.TRAIL_SECONDS else p.seconds
			return attribute, delay, seconds
		end
	end
	return p.attribute, p.delay, p.seconds
end

local function drop()
	local made = anchor
	if made ~= nil then
		made:Destroy()
	end
	anchor, emitter = nil, nil
end

local function dropBadge()
	local made = badge
	if made ~= nil then
		made:Destroy()
	end
	badge = nil
end

-- The gold paw over the cat: a round gold badge with the glyph in it, bobbing unless Reduce Motion is on.
local function makeBadge(at: Vector3): Attachment
	local m = Presets.waitingCat.marker
	local holder = Particles.anchor("WaitingCatBadge", at)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WaitingCatBadge"
	gui.Size = UDim2.new(m.studs, m.pixels, m.studs, m.pixels)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true -- seen through the cafe walls and the alley fence
	gui.MaxDistance = m.within
	gui.Adornee = holder
	gui.Parent = holder
	local disc = Instance.new("Frame")
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Presets.palette.golden
	disc.BorderSizePixel = 0
	disc.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	local rim = Instance.new("UIStroke")
	rim.Color = Presets.palette.offwhite
	rim.Thickness = 2
	rim.Parent = disc
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.7, 0.7)
	label.Text = m.glyph
	label.TextScaled = true
	label.Parent = disc
	if not Context.reducedMotion() then
		local info = TweenInfo.new(
			m.seconds / 2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, m.bob, 0) }):Play()
	end
	return holder
end

-- This player's waiting stray in the world, if any.
local function find(attribute: string): Model?
	local me = Players.LocalPlayer.UserId
	for _, instance in CollectionService:GetTagged("Stray") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute(attribute) == me
			and instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
		then
			return instance :: Model
		end
	end
	return nil
end

local function step()
	local p = Presets.waitingCat
	local attribute, delay, seconds = rules()
	local found = find(attribute)
	if found ~= cat then
		drop()
		dropBadge()
		cat = found
		seenAt = os.clock()
	end
	local model = cat
	if model == nil then
		return
	end
	local age = os.clock() - seenAt
	local frame, size = model:GetBoundingBox()
	local feet = frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
	if age < delay then
		return
	end
	local head = frame.Position + Vector3.new(0, size.Y / 2 + p.marker.lift, 0)
	local held = badge
	if held == nil then
		badge = makeBadge(head)
	else
		held.Position = head
	end
	if Context.distance(feet) > p.within then
		drop()
		return
	end
	if not Context.lowPerformance then
		local made: Attachment? = anchor
		if made == nil then
			local fresh = Particles.anchor("WaitingCat", feet)
			anchor, emitter = fresh, Particles.attach(p.emitter, fresh)
		else
			made.Position = feet
		end
		local glow = emitter
		if glow ~= nil then
			Particles.switchOn(glow, p.emitter)
		end
	else
		drop()
	end
	local every = if age > delay + seconds then p.calmEvery else p.ringEvery
	if os.clock() - ringAt >= every then
		ringAt = os.clock()
		Particles.ring(feet, Presets.palette.golden, p.ring, p.ringSeconds) -- none with Reduce Motion
	end
end

function WaitingCat.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			step()
			task.wait(Presets.waitingCat.check)
		end
	end)
end

return WaitingCat
