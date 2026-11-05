--!strict
-- The camp stations' ready glows (camp-stations.md: the Picnic Basket #1133, section 2, "when a potion waits, a soft
-- warm glow sits under the parasol (VFX, a single PointLight, inside the night glow budget). It's off while
-- refilling."; the Yard Sale #1154 and the Fish Pond #1232 in the same style). While one of your stations holds
-- something (Picnic potions, a free Yard Sale crate, 18 or more Fish Pond fish), one soft PointLight glows under its roof,
-- fading in and out over `fade` seconds as it fills and is collected (instant with Reduce Motion). Each client only
-- knows its own stations, so only the owner sees them, like UI-Engineer's ReadyBang "!" over them. Off in Low
-- performance, as the street's night lights are (WorldController).
--
-- Source: Moments.CampExtrasState (the server's CampExtrasState, each extra's `held`, Logic.campHeld) and the
-- `CampExtra`-tagged Model with that ExtraId (Model-Agent's CatCafe_Camp_Park_PicnicStation,
-- CatCafe_Camp_Neighbourhood_YardSaleStall and CatCafe_Camp_Woods_FishingHut once they land, today's models before
-- that): the light goes on its `GlowAnchor` attachment if it has one, else `under` of the way up its bounding box.
-- Listening only. Numbers in Presets.campGlow.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local CampGlow = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG
local SPOT = "CampGlowSpot"

type Extra = { under: number, colour: Color3, atLeast: number }
local EXTRAS: { [string]: Extra } = Presets.campGlow.extras :: any

type Glow = {
	ready: boolean,
	light: PointLight?,
	holder: Instance?, -- the GlowAnchor, or an Attachment this client made under the roof
}

local glows: { [string]: Glow } = {}
local started = false

local function station(extraId: string): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == extraId
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

-- The light's spot on the station: its GlowAnchor, else an Attachment in the Terrain `under` of the way up.
local function spotFor(model: Model, under: number): Instance
	local anchor = model:FindFirstChild(Presets.campGlow.anchor, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor
	end
	local frame, size = model:GetBoundingBox()
	local made = Instance.new("Attachment")
	made.Name = SPOT
	made.WorldPosition = frame.Position + Vector3.new(0, size.Y * (under - 0.5), 0)
	made.Parent = Workspace.Terrain
	return made
end

local function forget(glow: Glow)
	local spot = glow.holder
	if spot ~= nil and spot.Name == SPOT then
		spot:Destroy() -- also takes the light
	elseif glow.light ~= nil then
		(glow.light :: PointLight):Destroy()
	end
	glow.light, glow.holder = nil, nil
end

local function lightOn(extraId: string, glow: Glow): PointLight?
	local current = glow.light
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local model = station(extraId)
	if model == nil then
		return nil
	end
	local g, e = Presets.campGlow, EXTRAS[extraId]
	local spot = spotFor(model, e.under)
	local made = Instance.new("PointLight")
	made.Name = "CampReadyGlow"
	made.Color = e.colour
	made.Range = g.range
	made.Brightness = 0
	made.Shadows = false
	made.Parent = spot
	glow.light, glow.holder = made, spot
	return made
end

local function apply(extraId: string, glow: Glow)
	local g = Presets.campGlow
	local on = glow.ready and not Context.lowPerformance
	local current = if on then lightOn(extraId, glow) else glow.light
	if current == nil then
		return
	end
	local target = if on then g.brightness else 0
	if Context.reducedMotion() then
		current.Brightness = target
	else
		local info = TweenInfo.new(g.fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		TweenService:Create(current, info, { Brightness = target }):Play()
	end
end

function CampGlow.start()
	if started then
		return
	end
	started = true
	for extraId in EXTRAS do
		glows[extraId] = { ready = false, light = nil, holder = nil }
	end
	local moments = Moments :: any
	if moments.CampExtrasState ~= nil then
		moments.CampExtrasState:Connect(function(state: unknown)
			for extraId, glow in glows do
				local now = Logic.campHeld(state, extraId) >= math.max(1, EXTRAS[extraId].atLeast)
				if now ~= glow.ready then
					glow.ready = now
					apply(extraId, glow)
				end
			end
		end)
	end
	-- the stations streaming in or out, and the Low performance switch, every `pick` seconds
	task.spawn(function()
		local wasLow = Context.lowPerformance
		while true do
			task.wait(Presets.campGlow.pick)
			local low = Context.lowPerformance
			local switched = low ~= wasLow
			wasLow = low
			for extraId, glow in glows do
				local current = glow.light
				if current ~= nil and (current.Parent == nil or station(extraId) == nil) then
					forget(glow)
				end
				if switched or (glow.ready and not low and glow.light == nil) then
					apply(extraId, glow)
				end
			end
		end
	end)
end

return CampGlow
