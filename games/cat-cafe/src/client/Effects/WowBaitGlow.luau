--!strict
-- The first bowl cat looks rare (#4822, Design-Agent's first 60 seconds spec part B: "A rare cat that looks rare in
-- the first minute"). The account's first wow bait cat is already a guaranteed Rare or Epic (shared/Bait.wowRarity);
-- from the moment it stands at your bowl until it is claimed or let go it wears a Highlight outline in its rarity
-- colour, a slow soft sparkle round it and a small "RARE!" or "EPIC!" tag over its head. On a claim the tag pops and
-- the sparkle bursts once, then everything goes (owned cats keep no glow, to keep phones light). It waits while the
-- first bait cutscene still walks the cat in (SlotWalk), so the glow lands on the real cat at the bowl. Reduce
-- Motion: the outline and the tag only. Phone budget: one Highlight and one emitter (about a dozen sparkles).
--
-- Source: the server's FirstWow(rarity, first) as the wow cat reaches the bowl, the `Cat` model CafeService puts in
-- your plot's Bait (or Bait2) folder with its `Rarity`, and CatCaught's source "bowl" for the claim. Listening only:
-- nothing here fires a remote. Numbers in Presets.wowBait.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local WowBaitGlow = {}

type Shown = {
	model: Model,
	rarity: string,
	highlight: Highlight,
	anchor: Attachment,
	tag: BillboardGui,
	label: TextLabel,
	emitter: ParticleEmitter?,
}

local started = false
local wanted: { rarity: string, at: number }? = nil
local shown: Shown? = nil
local claimedAt = -math.huge
local lastLook = 0

-- The wow cat's rarity while it glows or is on its way, else nil (Effects/FirstMinuteFx's card jingle).
function WowBaitGlow.rarity(): string?
	if shown ~= nil then
		return shown.rarity
	end
	return if wanted ~= nil then wanted.rarity else nil
end

-- The tag's words for a rarity ("RARE!", "EPIC!"), nil for one that gets no glow.
function WowBaitGlow.tagFor(rarity: unknown): string?
	if type(rarity) ~= "string" or Presets.wowBait.rarities[rarity] ~= true then
		return nil
	end
	return string.upper(rarity) .. "!"
end

-- Whether a gone cat was claimed: CatCaught "bowl" came within `window` seconds either side of it going.
function WowBaitGlow.claimed(goneAt: number, claimAt: number, window: number): boolean
	return math.abs(goneAt - claimAt) <= window
end

local function ownPlot(): Instance?
	for _, instance in CollectionService:GetTagged("Plot") do
		if
			instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		then
			return instance
		end
	end
	return nil
end

-- The wow cat standing at one of your bowls, nil until it is there and done walking in.
local function findCat(rarity: string): Model?
	-- required here, not at the top: SlotWalk pulls in Pose's CFrames, which the pure tests' shim has none of
	local SlotWalk = require(script.Parent.SlotWalk) :: any
	local plot = ownPlot()
	if plot == nil then
		return nil
	end
	for _, name in Presets.wowBait.folders do
		local folder = plot:FindFirstChild(name)
		local cat = if folder ~= nil then folder:FindFirstChild("Cat") else nil
		if
			cat ~= nil
			and cat:IsA("Model")
			and cat:GetAttribute("Rarity") == rarity
			and cat:FindFirstChildWhichIsA("BasePart", true) ~= nil
			and not SlotWalk.isWalking(cat :: Model)
		then
			return cat :: Model
		end
	end
	return nil
end

local function attach(model: Model, rarity: string)
	local p = Presets.wowBait
	local colour = Presets.rarity[rarity] or Presets.palette.golden
	local box, size = model:GetBoundingBox()
	local highlight = Instance.new("Highlight")
	highlight.Name = "EffectsWowBait"
	highlight.Adornee = model
	highlight.FillTransparency = 1
	highlight.OutlineColor = colour
	highlight.OutlineTransparency = p.outline
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Context.folder()
	local anchor = Particles.anchor("EffectsWowBait", box.Position + Vector3.new(0, size.Y / 2, 0))
	local tag = Instance.new("BillboardGui")
	tag.Name = "WowTag"
	tag.Size = UDim2.fromOffset(p.tag.width, p.tag.height)
	tag.StudsOffset = Vector3.new(0, p.tag.lift, 0)
	tag.MaxDistance = p.tag.maxDistance
	tag.LightInfluence = 0
	tag.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = WowBaitGlow.tagFor(rarity) or ""
	label.TextColor3 = colour
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = p.tag.stroke
	stroke.Parent = label
	label.Parent = tag
	tag.Parent = anchor
	local emitter: ParticleEmitter? = nil
	if not Context.reducedMotion() then
		local preset = Presets.emitters[p.sparkle]
		if preset ~= nil then
			local made = Particles.make(preset, colour:Lerp(Color3.new(1, 1, 1), p.whiten))
			made.Name = p.sparkle
			made.Shape = Enum.ParticleEmitterShape.Sphere
			made.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			made.Parent = anchor
			Particles.switchOn(made, p.sparkle)
			anchor.Position -= Vector3.new(0, size.Y / 2, 0) -- the sparkle sits round the body, the tag rides higher
			tag.StudsOffset = Vector3.new(0, size.Y / 2 + p.tag.lift, 0)
			emitter = made
		end
	end
	shown = {
		model = model,
		rarity = rarity,
		highlight = highlight,
		anchor = anchor,
		tag = tag,
		label = label,
		emitter = emitter,
	}
end

local function detach(s: Shown, claimed: boolean)
	s.highlight:Destroy()
	local emitter = s.emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
	local p = Presets.wowBait
	if claimed and not Context.reducedMotion() then
		local colour = Presets.rarity[s.rarity] or Presets.palette.golden
		Particles.burst(p.burst, s.anchor.WorldPosition, p.burstCount, colour)
		local grow =
			TweenInfo.new(p.tag.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(s.tag, grow, {
			Size = UDim2.fromOffset(p.tag.width * p.tag.pop, p.tag.height * p.tag.pop),
		}):Play()
		TweenService:Create(s.label, TweenInfo.new(p.tag.popSeconds), { TextTransparency = 1 })
			:Play()
		local stroke = s.label:FindFirstChildWhichIsA("UIStroke")
		if stroke ~= nil then
			TweenService:Create(stroke, TweenInfo.new(p.tag.popSeconds), { Transparency = 1 })
				:Play()
		end
		task.delay(p.tag.popSeconds + 2, function()
			s.anchor:Destroy()
		end)
	else
		s.anchor:Destroy()
	end
end

local function step()
	local now = os.clock()
	if now - lastLook < Presets.wowBait.check then
		return
	end
	lastLook = now
	local s = shown
	if s ~= nil then
		if not s.model:IsDescendantOf(Workspace) then
			-- CatCaught can come just before or just after the cat goes: wait a moment for it
			local goneAt = now
			local current = s
			shown = nil
			task.delay(Presets.wowBait.claimWindow, function()
				detach(current, WowBaitGlow.claimed(goneAt, claimedAt, Presets.wowBait.claimWindow))
			end)
		end
		return
	end
	local want = wanted
	if want == nil then
		return
	end
	if now - want.at > Presets.wowBait.giveUp then
		wanted = nil
		return
	end
	local cat = findCat(want.rarity)
	if cat ~= nil then
		wanted = nil
		attach(cat, want.rarity)
	end
end

function WowBaitGlow.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("FirstWow", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(function(rarity: unknown)
			if WowBaitGlow.tagFor(rarity) ~= nil and shown == nil then
				wanted = { rarity = rarity :: string, at = os.clock() }
			end
		end)
	end)
	Context.whenRemote("CatCaught", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(
			function(_catId: unknown, _isNew: unknown, _variant: unknown, source: unknown)
				if source == "bowl" then
					claimedAt = os.clock()
				end
			end
		)
	end)
	RunService.Heartbeat:Connect(step)
end

return WowBaitGlow
