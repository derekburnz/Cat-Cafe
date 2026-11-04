--!strict
-- The shop-only cats' own effects (#1191, Design-Agent's brief on 2026-11-04). Sprinkles, the Starter Bundle's new
-- baker: a tiny puff of rainbow sprinkles over it when its table pays, at most once every `gap` seconds, as one burst.
-- With Reduce Motion it is a short soft glow instead. Duchess Marzipan, the Royal cat: a few lilac petals drift
-- round her (one steady emitter, the nearest budget.shopCatEmitters within `within` studs), a still scatter of
-- petals on the floor at her spot instead in Low performance or with Reduce Motion, and a soft lilac sparkle as she
-- starts a shift (the chime is Sound-Agent's). King Croissant joins here when his model lands.
--
-- Source: Moments.TipSwept(cat, position), fired in your own cafe when a Waiter or Greeter sweeps a paid table's tip
-- into its bag (Gameplay-Engineer's CafeOrders). The puff plays over every Sprinkles working in that cafe (a Model
-- with CatId "sprinkles" inside the same Plot), at its Head's `BubbleAnchor` (Model-Agent, #1244), else over its
-- pivot; when Sprinkles is the cat that swept, and so is away on its walk, over the pile it swept. Duchess: every
-- Model with CatId "duchess_marzipan" (Model-Agent, #1249), her Head's `BubbleAnchor` for the petals and the
-- sparkle; a shift starts when one of her models (by `Uid`) goes from off duty to working (a `Role` without
-- `Bedtime`), so a cafe rebuilding her model or her streaming back in plays nothing. Listening only. Numbers in
-- Presets.shopCats.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CafeWalk = require(script.Parent.CafeWalk)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local ShopCats = {}

local lastPuff: { [Model]: number } = {} -- os.clock() of each Sprinkles' last puff
local started = false

local function plotOf(instance: Instance): Model?
	local ancestor = instance.Parent
	while ancestor ~= nil do
		if ancestor:IsA("Model") and CollectionService:HasTag(ancestor, "Plot") then
			return ancestor :: Model
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- Where the puff goes over a cat: its Head's BubbleAnchor, else `fallback` studs over its pivot.
local function anchorOf(cat: Model, fallback: number): Vector3
	local head = cat:FindFirstChild("Head", true)
	local anchor = if head ~= nil then head:FindFirstChild("BubbleAnchor") else nil
	if anchor ~= nil and anchor:IsA("Attachment") then
		return (anchor :: Attachment).WorldPosition
	end
	return cat:GetPivot().Position + Vector3.new(0, fallback, 0)
end

-- Reduce Motion's stand-in: a light that fades in and out once, nothing moving.
type Glow = { seconds: number, range: number, brightness: number, colour: Color3 }

local function glow(at: Vector3, g: Glow)
	local part = Context.effectPart("ShopCatGlow", Vector3.new(0.2, 0.2, 0.2), g.colour)
	part.Transparency = 1
	part.Position = at
	local light = Instance.new("PointLight")
	light.Color = g.colour
	light.Range = g.range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = part
	part.Parent = Context.folder()
	local half = g.seconds / 2
	local info = TweenInfo.new(half, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true)
	TweenService:Create(light, info, { Brightness = g.brightness }):Play()
	Debris:AddItem(part, g.seconds + 0.2)
end

-- One puff: `each` sprinkles of every colour, so the whole puff is one small burst of rainbow.
local function puff(at: Vector3)
	local s = Presets.shopCats.sprinkles
	if Context.reducedMotion() then
		glow(at, s.glow)
		return
	end
	for _, colour in s.colours do
		Particles.burst("sprinkle", at, s.each, colour)
	end
end

local function swept(sweeper: unknown, position: unknown)
	if typeof(sweeper) ~= "Instance" or not (sweeper :: Instance):IsA("Model") then
		return
	end
	local plot = plotOf(sweeper :: Model)
	if plot == nil then
		return
	end
	local s = Presets.shopCats.sprinkles
	local now = os.clock()
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("CatId") == s.catId then
			local cat = descendant :: Model
			local last = lastPuff[cat]
			if last == nil or now - last >= s.gap then
				local at: Vector3? = nil
				if cat == sweeper and typeof(position) == "Vector3" then
					-- off on its walk: over the pile it swept
					at = (position :: Vector3) + Vector3.new(0, s.overPile, 0)
				elseif not CafeWalk.isAway(cat) then
					at = anchorOf(cat, s.overPivot)
				end
				if at ~= nil and Context.distance(at) <= s.within then
					lastPuff[cat] = now
					puff(at + Vector3.new(0, s.lift, 0))
				end
			end
		end
	end
	for cat in lastPuff do
		if cat.Parent == nil then
			lastPuff[cat] = nil
		end
	end
end

-- Duchess Marzipan ------------------------------------------------------------------------------------------

type Duchess = {
	emitter: ParticleEmitter?,
	still: Part?, -- the floor petals in Low performance or with Reduce Motion
}

local duchesses: { [Model]: Duchess } = {}
local onDuty: { [string]: boolean } = {} -- by Uid: last seen working (true) or off duty (false)

local function working(cat: Model): boolean
	return cat:GetAttribute("Role") ~= nil and cat:GetAttribute("Bedtime") ~= true
end

local function bubbleAnchor(cat: Model): Attachment?
	local head = cat:FindFirstChild("Head", true)
	local anchor = if head ~= nil then head:FindFirstChild("BubbleAnchor") else nil
	return if anchor ~= nil and anchor:IsA("Attachment") then anchor :: Attachment else nil
end

local function stopPetals(d: Duchess)
	local emitter = d.emitter
	if emitter ~= nil then
		d.emitter = nil
		emitter.Enabled = false
		-- the petals already in the air drift on and settle
		Debris:AddItem(emitter, Presets.emitters.lilacPetal.lifetime[2] + 0.2)
	end
end

local function hideStill(d: Duchess)
	local still = d.still
	if still ~= nil then
		d.still = nil
		still:Destroy()
	end
end

-- A few flat lilac petals lying on the floor round her feet, never moving.
local function showStill(d: Duchess, cat: Model)
	if d.still ~= nil and (d.still :: Part).Parent ~= nil then
		return
	end
	local p = Presets.shopCats.duchess.still
	local frame, size = cat:GetBoundingBox()
	local floor = frame.Position - Vector3.new(0, size.Y / 2 - 0.03, 0)
	local holder = Context.effectPart("DuchessPetals", Vector3.new(0.05, 0.05, 0.05), p.colour)
	holder.Transparency = 1
	holder.Position = floor
	for i, offset in p.spots do
		local petalSize = Vector3.new(p.size, 0.02, p.size * 0.6)
		local petal = Context.effectPart("Petal" .. i, petalSize, p.colour)
		petal.Transparency = 1
		local spot = floor + Vector3.new(offset[1], 0, offset[2])
		petal.CFrame = CFrame.new(spot) * CFrame.Angles(0, offset[3], 0)
		local decal = Instance.new("Decal")
		decal.Texture = Presets.textures.smoke
		decal.Color3 = p.colour
		decal.Transparency = p.transparency
		decal.Face = Enum.NormalId.Top
		decal.Parent = petal
		petal.Parent = holder
	end
	holder.Parent = Context.folder()
	d.still = holder
end

local function pickDuchesses()
	local c = Presets.shopCats.duchess
	local candidates: { Logic.Candidate<Model> } = {}
	for cat, d in duchesses do
		if cat.Parent == nil then
			stopPetals(d)
			hideStill(d)
			duchesses[cat] = nil
		elseif not CafeWalk.isAway(cat) and cat:GetAttribute("HiddenLocal") ~= true then
			local distance = Context.distance(cat:GetPivot().Position)
			table.insert(candidates, { key = cat, distance = distance })
		end
	end
	local budget = Context.budget.shopCatEmitters
	local still = budget <= 0 or Context.lowPerformance or Context.reducedMotion()
	local chosen: { [Model]: boolean } = {}
	for _, cat in Logic.nearest(candidates, c.within, math.max(budget, 1)) do
		chosen[cat] = true
		local d = duchesses[cat]
		local anchor = bubbleAnchor(cat)
		if still or anchor == nil then
			stopPetals(d)
			showStill(d, cat)
		else
			hideStill(d)
			local emitter = d.emitter
			if emitter == nil or emitter.Parent ~= anchor then
				stopPetals(d)
				emitter = Particles.attach("lilacPetal", anchor :: Attachment)
				d.emitter = emitter
			else
				Particles.switchOn(emitter, "lilacPetal") -- a new budget reaches it
			end
		end
	end
	for cat, d in duchesses do
		if not chosen[cat] then
			stopPetals(d)
			hideStill(d)
		end
	end
end

-- Her shift starts: a soft lilac sparkle over her ears.
local function shiftStart(cat: Model)
	local c = Presets.shopCats.duchess
	local anchor = bubbleAnchor(cat)
	local over = cat:GetPivot().Position + Vector3.new(0, c.overPivot, 0)
	local at = if anchor ~= nil then anchor.WorldPosition else over
	if Context.distance(at) > c.within then
		return
	end
	Particles.burst("dingSparkle", at, c.shift.sparkles, c.colour)
	Particles.ring(cat:GetPivot().Position, c.colour, c.shift.ring, c.shift.ringSeconds)
end

local function followDuchess(cat: Model)
	local uid = cat:GetAttribute("Uid")
	local key = if type(uid) == "string" then uid else cat:GetFullName()
	local function look()
		local now = working(cat)
		local before = onDuty[key]
		onDuty[key] = now
		if before == false and now then
			shiftStart(cat)
		end
	end
	if duchesses[cat] == nil then
		duchesses[cat] = { emitter = nil, still = nil }
		look()
		cat:GetAttributeChangedSignal("Bedtime"):Connect(look)
		cat:GetAttributeChangedSignal("Role"):Connect(look)
	end
end

-- The server sets CatId before it parents a cat (CafeService.buildCat), so it arrives with the model.
local function consider(instance: Instance)
	local id = Presets.shopCats.duchess.catId
	if instance:IsA("Model") and instance:GetAttribute("CatId") == id then
		followDuchess(instance :: Model)
	end
end

function ShopCats.start()
	if started then
		return
	end
	started = true
	Moments.TipSwept:Connect(swept)
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			task.wait(Presets.shopCats.duchess.pick)
			pickDuchesses()
		end
	end)
end

return ShopCats
