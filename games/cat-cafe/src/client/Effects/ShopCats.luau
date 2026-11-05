--!strict
-- The shop-only cats' own effects (#1191, Design-Agent's brief on 2026-11-04). Sprinkles, the Starter Bundle's new
-- baker: a tiny puff of rainbow sprinkles over it when its table pays, at most once every `gap` seconds, as one burst.
-- With Reduce Motion it is a short soft glow instead. Duchess Marzipan, the Royal cat: a few lilac petals drift
-- round her (one steady emitter, the nearest budget.shopCatEmitters within `within` studs), a still scatter of
-- petals on the floor at her spot instead in Low performance or with Reduce Motion, and a soft lilac sparkle as she
-- starts a shift (the chime is Sound-Agent's). King Croissant, the King cat: a soft gold glow round him, one steady
-- emitter of drifting gold motes, a slow gold shine scrolling along his cape's dotted trim, and a gold pop off his
-- crown when his table pays (at most every `pop.gap` seconds). Reduce Motion keeps only the glow (the trim held
-- still); Low performance drops the motes. The King Cat Pack's Royal Crest sign style: a slow gold shine sweeps
-- across its gold frame every 8 s, a scrolling Texture with no particles, none with Reduce Motion.
--
-- Source: Moments.TipSwept(cat, position), fired in your own cafe when a Waiter or Greeter sweeps a paid table's tip
-- into its bag (Gameplay-Engineer's CafeOrders). The puff plays over every Sprinkles working in that cafe (a Model
-- with CatId "sprinkles" inside the same Plot), at its Head's `BubbleAnchor` (Model-Agent, #1244), else over its
-- pivot; when Sprinkles is the cat that swept, and so is away on its walk, over the pile it swept. Duchess: every
-- Model with CatId "duchess_marzipan" (Model-Agent, #1249), her Head's `BubbleAnchor` for the petals and the
-- sparkle; a shift starts when one of her models (by `Uid`) goes from off duty to working (a `Role` without
-- `Bedtime`), so a cafe rebuilding her model or her streaming back in plays nothing. King: every Model with CatId
-- "king_croissant" (Model-Agent, friend/cat-king), his `Glow` attachment in the Body for the light and the motes,
-- `CrownTop` (in the crown Prop inside the Head Model) for the pop, and the largest part of the Model ending
-- `_CapeTrim` (inside Prop2) for the scrolling shine, the same Moments.TipSwept as Sprinkles for the pop. The
-- Royal Crest: every part (the frame's bars) in a Model named `CatCafe_Plot_SignRoyalCrest_Frame` (#1289).
-- Listening only. Numbers in Presets.shopCats.

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

-- King Croissant's crown: its `CrownTop` attachment (in the crown Prop inside the Head Model), else over his ears.
local function crownTop(cat: Model): Vector3
	local top = cat:FindFirstChild("CrownTop", true)
	if top ~= nil and top:IsA("Attachment") then
		return (top :: Attachment).WorldPosition
	end
	return anchorOf(cat, Presets.shopCats.king.overPivot)
end

-- His table pays: gold glints and stars pop off the crown with a small gold ring. Not with Reduce Motion, which
-- keeps only his glow.
local function crownPop(at: Vector3)
	if Context.reducedMotion() then
		return
	end
	local p = Presets.shopCats.king.pop
	Particles.burst("dingSparkle", at, p.sparkles, Presets.palette.golden)
	Particles.burst("crownGlint", at, p.stars)
	Particles.ring(at, Presets.palette.golden, p.ring, p.ringSeconds)
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
	local k = Presets.shopCats.king
	local now = os.clock()
	for _, descendant in plot:GetDescendants() do
		local catId = if descendant:IsA("Model") then descendant:GetAttribute("CatId") else nil
		if catId == s.catId or catId == k.catId then
			local cat = descendant :: Model
			local king = catId == k.catId
			local gap = if king then k.pop.gap else s.gap
			local last = lastPuff[cat]
			if last == nil or now - last >= gap then
				local at: Vector3? = nil
				if cat == sweeper and typeof(position) == "Vector3" then
					-- off on its walk: over the pile it swept
					at = (position :: Vector3) + Vector3.new(0, s.overPile, 0)
				elseif not CafeWalk.isAway(cat) then
					at = if king then crownTop(cat) else anchorOf(cat, s.overPivot)
				end
				if at ~= nil and Context.distance(at) <= s.within then
					lastPuff[cat] = now
					if king then
						crownPop(at :: Vector3)
					else
						puff((at :: Vector3) + Vector3.new(0, s.lift, 0))
					end
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

-- King Croissant -------------------------------------------------------------------------------------------

type King = {
	light: PointLight?,
	motes: ParticleEmitter?,
	trim: { Texture }, -- the shine on both faces of his cape trim's band
	started: number, -- os.clock() when his trim began to scroll, for its phase
}

local kings: { [Model]: King } = {}

local function glowAttachment(cat: Model): Attachment?
	local glowAt = cat:FindFirstChild("Glow", true)
	return if glowAt ~= nil and glowAt:IsA("Attachment") then glowAt :: Attachment else nil
end

-- The band of his cape's dotted trim: the largest part in the Model ending `_CapeTrim` (Model-Agent, inside Prop2).
local function trimBand(cat: Model): BasePart?
	local best: BasePart? = nil
	local bestSize = 0
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("Model") and string.sub(descendant.Name, -9) == "_CapeTrim" then
			for _, part in descendant:GetDescendants() do
				if part:IsA("BasePart") then
					local size = (part :: BasePart).Size
					local area = size.X * size.Y * size.Z
					if area > bestSize then
						best, bestSize = part :: BasePart, area
					end
				end
			end
		end
	end
	return best
end

local function clearKing(k: King)
	local light, motes, trim = k.light, k.motes, k.trim
	k.light, k.motes, k.trim = nil, nil, {}
	if light ~= nil then
		light:Destroy()
	end
	if motes ~= nil then
		motes.Enabled = false
		Debris:AddItem(motes, Presets.emitters.goldMote.lifetime[2] + 0.2)
	end
	for _, texture in trim do
		texture:Destroy()
	end
end

-- The soft gold glow round him, the gold motes and the shine on his cape trim, on the nearest kings.
local function dressKing(cat: Model, k: King, motes: boolean, still: boolean)
	local c = Presets.shopCats.king
	local glowAt = glowAttachment(cat)
	if glowAt ~= nil and (k.light == nil or (k.light :: PointLight).Parent ~= glowAt) then
		local light = Instance.new("PointLight")
		light.Name = "KingGlow"
		light.Color = c.glow.colour
		light.Range = c.glow.range
		light.Brightness = c.glow.brightness
		light.Shadows = false
		light.Parent = glowAt
		k.light = light
	end
	if motes and glowAt ~= nil then
		local emitter = k.motes
		if emitter == nil or emitter.Parent ~= glowAt then
			k.motes = Particles.attach("goldMote", glowAt :: Attachment)
		else
			Particles.switchOn(emitter, "goldMote")
		end
	elseif k.motes ~= nil then
		local emitter = k.motes :: ParticleEmitter
		k.motes = nil
		emitter.Enabled = false
		Debris:AddItem(emitter, Presets.emitters.goldMote.lifetime[2] + 0.2)
	end
	local laid = #k.trim > 0 and k.trim[1].Parent ~= nil
	local band = if laid then nil else trimBand(cat)
	if band ~= nil then
		local t = c.trim
		k.trim = {}
		for _, face in t.faces do
			local texture = Instance.new("Texture")
			texture.Name = "KingTrimShine"
			texture.Texture = Presets.textures.sparkle
			texture.Color3 = t.colour
			texture.Transparency = t.transparency
			texture.StudsPerTileU = t.tile
			texture.StudsPerTileV = t.tile
			texture.Face = face
			texture.Parent = band
			table.insert(k.trim, texture)
		end
		k.started = os.clock()
	end
	-- a slow scroll along the band; held still with Reduce Motion
	local offset = if still then 0 else ((os.clock() - k.started) * c.trim.speed) % c.trim.tile
	for _, texture in k.trim do
		texture.OffsetStudsU = offset
	end
end

local function stepKings()
	local c = Presets.shopCats.king
	local candidates: { Logic.Candidate<Model> } = {}
	for cat, k in kings do
		if cat.Parent == nil then
			clearKing(k)
			kings[cat] = nil
		elseif not CafeWalk.isAway(cat) and cat:GetAttribute("HiddenLocal") ~= true then
			local distance = Context.distance(cat:GetPivot().Position)
			table.insert(candidates, { key = cat, distance = distance })
		end
	end
	local still = Context.reducedMotion()
	local budget = Context.budget.shopCatEmitters
	local motes = not still and not Context.lowPerformance and budget > 0
	local chosen: { [Model]: boolean } = {}
	-- nearest first: the glow and the trim on every chosen king, the motes only on the nearest
	-- budget.shopCatEmitters (one on a phone)
	for index, cat in Logic.nearest(candidates, c.within, c.most) do
		chosen[cat] = true
		dressKing(cat, kings[cat], motes and index <= budget, still)
	end
	for cat, k in kings do
		if not chosen[cat] then
			clearKing(k)
		end
	end
end

-- The Royal Crest sign style (King Cat Pack) -------------------------------------------------------------

type Crest = {
	shine: { Texture }, -- on the front and back faces of every bar
	along: { [Texture]: number }, -- studs along the sign from its middle to each texture's bar
	width: number, -- the sign's width, in studs
	nextAt: number, -- os.clock() when the next sweep starts
}

local crests: { [Model]: Crest } = {}

local function clearCrest(c: Crest)
	for _, texture in c.shine do
		texture:Destroy()
	end
	c.shine = {}
	c.along = {}
end

-- Lays a soft gold sprite twice the sign's width on both faces of every bar of the frame, each bar's texture shifted
-- by where the bar sits along the sign, so one band of light travels across all of them together.
local function layCrest(frame: Model, c: Crest)
	local r = Presets.shopCats.royalCrest
	local pivot = frame:GetPivot()
	local _, size = frame:GetBoundingBox()
	c.width = math.max(size.X, size.Z)
	for _, bar in frame:GetDescendants() do
		if bar:IsA("BasePart") then
			local part = bar :: BasePart
			local along = (part.Position - pivot.Position):Dot(pivot.RightVector)
			for _, face in r.faces do
				local texture = Instance.new("Texture")
				texture.Name = "RoyalCrestShine"
				texture.Texture = Presets.textures.sparkle
				texture.Color3 = r.colour
				texture.Transparency = 1
				texture.StudsPerTileU = c.width * 2
				texture.StudsPerTileV = size.Y * 1.5
				texture.Face = face
				texture.Parent = part
				table.insert(c.shine, texture)
				c.along[texture] = along
			end
		end
	end
end

-- A slow gold shine sweeping once across the frame every `every` seconds: the band slides from one side of the sign
-- to the other over `sweep` seconds, then hides until the next. Held off with Reduce Motion.
local function stepCrests()
	local r = Presets.shopCats.royalCrest
	local now = os.clock()
	local candidates: { Logic.Candidate<Model> } = {}
	for frame, c in crests do
		if frame.Parent == nil then
			clearCrest(c)
			crests[frame] = nil
		else
			local distance = Context.distance(frame:GetPivot().Position)
			table.insert(candidates, { key = frame, distance = distance })
		end
	end
	local chosen: { [Model]: boolean } = {}
	if not Context.reducedMotion() then
		for _, frame in Logic.nearest(candidates, r.within, r.most) do
			chosen[frame] = true
			local c = crests[frame]
			if #c.shine == 0 then
				layCrest(frame, c)
			end
			local t = now - c.nextAt
			if t >= r.sweep then
				c.nextAt = now + r.every - r.sweep
				t = -1
			end
			local travel, fade = Logic.shineSweep(t, r.sweep, c.width)
			for _, texture in c.shine do
				texture.OffsetStudsU = travel - (c.along[texture] or 0)
				texture.Transparency = 1 - fade * (1 - r.transparency)
			end
		end
	end
	for frame, c in crests do
		if not chosen[frame] then
			clearCrest(c)
		end
	end
end

local function considerCrest(instance: Instance)
	local r = Presets.shopCats.royalCrest
	if instance:IsA("Model") and instance.Name == r.model and crests[instance :: Model] == nil then
		-- each sign on its own beat, so a street of them never sweeps together; its bars share one
		local first = os.clock() + math.random() * r.every
		crests[instance :: Model] = { shine = {}, along = {}, width = 0, nextAt = first }
	end
end

-- The server sets CatId before it parents a cat (CafeService.buildCat), so it arrives with the model.
local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local catId = instance:GetAttribute("CatId")
	if catId == Presets.shopCats.duchess.catId then
		followDuchess(instance :: Model)
	elseif catId == Presets.shopCats.king.catId and kings[instance :: Model] == nil then
		kings[instance :: Model] = { light = nil, motes = nil, trim = {}, started = os.clock() }
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
		considerCrest(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	Workspace.DescendantAdded:Connect(considerCrest)
	task.spawn(function()
		while true do
			task.wait(Presets.shopCats.duchess.pick)
			pickDuchesses()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Presets.shopCats.king.step)
			stepKings()
			stepCrests()
		end
	end)
end

return ShopCats
