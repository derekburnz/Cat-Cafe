--!strict
-- The Picnic Basket's ready glow (#1133, camp-stations.md section 2: "when a potion waits, a soft warm glow sits under
-- the parasol (VFX, a single PointLight, inside the night glow budget). It's off while refilling."). While your
-- picnic holds a potion, one soft warm PointLight glows under the station's parasol, fading in and out over `fade`
-- seconds as it fills and is collected (instant with Reduce Motion). Each client only knows its own picnic, so only
-- the owner sees it, like UI-Engineer's ReadyBang "!" over it. Off in Low performance, as the street's night lights
-- are (WorldController).
--
-- Source: Moments.CampExtrasState (the server's CampExtrasState, its `picnic.held`, Logic.campHeld) and the
-- `CampExtra`-tagged Model with ExtraId "picnic" (Model-Agent's CatCafe_Camp_Park_PicnicStation): the light goes
-- on its `GlowAnchor` attachment if it has one, else `under` of the way up its bounding box, under the parasol.
-- Listening only. Numbers in Presets.picnicGlow.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local PicnicGlow = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG
local EXTRA = "picnic"

local ready = false
local light: PointLight? = nil
local holder: Instance? = nil -- the GlowAnchor, or an Attachment this client made under the parasol
local started = false

local function station(): Model?
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == EXTRA
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

-- The light's spot on the station: its GlowAnchor, else an Attachment in the Terrain under the parasol.
local function spotFor(model: Model): Instance
	local anchor = model:FindFirstChild(Presets.picnicGlow.anchor, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor
	end
	local frame, size = model:GetBoundingBox()
	local at = frame.Position + Vector3.new(0, size.Y * (Presets.picnicGlow.under - 0.5), 0)
	local made = Instance.new("Attachment")
	made.Name = "PicnicGlowSpot"
	made.WorldPosition = at
	made.Parent = Workspace.Terrain
	return made
end

local function lightOn(): PointLight?
	local current = light
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local model = station()
	if model == nil then
		return nil
	end
	local g = Presets.picnicGlow
	local spot = spotFor(model)
	local made = Instance.new("PointLight")
	made.Name = "PicnicReadyGlow"
	made.Color = g.colour
	made.Range = g.range
	made.Brightness = 0
	made.Shadows = false
	made.Parent = spot
	light = made
	holder = spot
	return made
end

local function apply()
	local g = Presets.picnicGlow
	local on = ready and not Context.lowPerformance
	local current = if on then lightOn() else light
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

function PicnicGlow.start()
	if started then
		return
	end
	started = true
	local moments = Moments :: any
	if moments.CampExtrasState ~= nil then
		moments.CampExtrasState:Connect(function(state: unknown)
			local now = Logic.campHeld(state, EXTRA) > 0
			if now ~= ready then
				ready = now
				apply()
			end
		end)
	end
	-- the station streaming in or out, and the Low performance switch, every `pick` seconds
	task.spawn(function()
		local wasLow = Context.lowPerformance
		while true do
			task.wait(Presets.picnicGlow.pick)
			local current = light
			if current ~= nil and (current.Parent == nil or station() == nil) then
				local spot = holder
				if spot ~= nil and spot.Name == "PicnicGlowSpot" then
					spot:Destroy()
				end
				light, holder = nil, nil
			end
			local low = Context.lowPerformance
			if low ~= wasLow or (ready and not low and light == nil) then
				wasLow = low
				apply()
			end
		end
	end)
end

return PicnicGlow
