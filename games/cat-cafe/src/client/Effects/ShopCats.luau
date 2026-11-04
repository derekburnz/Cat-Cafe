--!strict
-- The shop-only cats' own effects (#1191, Design-Agent's brief on 2026-11-04). Sprinkles, the Starter Bundle's new
-- baker: a tiny puff of rainbow sprinkles over it when its table pays, at most once every `gap` seconds, as one burst.
-- With Reduce Motion it is a short soft glow instead. Duchess Marzipan and King Croissant join here when their models
-- land.
--
-- Source: Moments.TipSwept(cat, position), fired in your own cafe when a Waiter or Greeter sweeps a paid table's tip
-- into its bag (Gameplay-Engineer's CafeOrders). The puff plays over every Sprinkles working in that cafe (a Model
-- with CatId "sprinkles" inside the same Plot), at its Head's `BubbleAnchor` (Model-Agent, #1244), else over its
-- pivot; when Sprinkles is the cat that swept, and so is away on its walk, over the pile it swept. Listening only.
-- Numbers in Presets.shopCats.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CafeWalk = require(script.Parent.CafeWalk)
local Context = require(script.Parent.Context)
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

function ShopCats.start()
	if started then
		return
	end
	started = true
	Moments.TipSwept:Connect(swept)
end

return ShopCats
