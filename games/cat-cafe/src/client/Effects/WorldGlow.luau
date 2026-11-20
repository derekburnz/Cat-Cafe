--!strict
-- The new start's only guidance (#5533 version 2, Design-Agent's new-start-v2-spec.md: no dims, arrows, strips or
-- windows, "the thing in the world glows"). Three soft Cozy Cream gold glows on things in the world, never on the
-- screen, each behind its own switch read straight (`== true`):
--   1. `stallGlow`: WorldGlow.stall(target) glows a target for `stallSeconds` with a soft breathing pulse. Gameplay-
--      Engineer's goal chip timer calls it once per goal when the goal has not moved for 11 s. `target` is an
--      Instance (the nearest stray), "door" (this player's own cafe door) or "cannon" (the Town Square cannon).
--   2. `cannonGlow`: while the LocalPlayer attribute `CannonGlowArea` (an area id, set by the server after a Rank Up
--      that opens an area, cleared on the first flight there) is set, the Town Square cannon glows steadily with a
--      small sign over it naming the area (PARK).
--   3. under `freeStart`: while this player carries their first cat (the character's CarryingCatId, ProfileSync's
--      stats.catsCaught at most 1), their own cafe door glows steadily.
-- A model or a visible part gets a Highlight; the cafe door is an invisible zone part, so it gets a thin glowing
-- panel in its doorway instead. Reduce Motion: no breathing, a still glow. Listening only: no remotes, no game state.
-- Numbers in Presets.worldGlow.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)

local WorldGlow = {}

export type Target = Instance | "door" | "cannon"

type Glow = {
	target: Instance,
	highlight: Highlight?,
	panel: BasePart?,
	light: PointLight?,
}

local started = false
local catsCaught = 0
local stallGlow: Glow? = nil
local stallAt = 0
local cannonGlow: Glow? = nil
local cannonSign: BillboardGui? = nil
local cannonArea: string? = nil
local doorGlow: Glow? = nil

-- Pure: the stall glow's strength (0 to 1) `t` seconds in: it fades in, breathes every `period` seconds between
-- `low` and 1, and fades out by `seconds`. `still` (Reduce Motion) holds it at 1 between the fades.
function WorldGlow.stallStrength(
	t: number,
	seconds: number,
	period: number,
	low: number,
	still: boolean
): number
	if t <= 0 or t >= seconds then
		return 0
	end
	local fade = math.min(1, t / 0.5, (seconds - t) / 0.5)
	if still or period <= 0 then
		return fade
	end
	local wave = 0.5 - 0.5 * math.cos(2 * math.pi * t / period)
	return fade * (low + (1 - low) * wave)
end

-- Pure: the sign's words for an area id.
function WorldGlow.signText(area: string): string
	local named = Presets.worldGlow.areaNames[area]
	return string.upper(if named ~= nil then named else area)
end

-- Pure: whether the door glows for a carry: carrying, the first cat, the switch on.
function WorldGlow.carryDoor(carrying: boolean, caught: number, on: boolean): boolean
	return on and carrying and caught <= 1
end

local function flag(key: string): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. key) == true
end

local function ownDoor(): BasePart?
	local me = Players.LocalPlayer
	for _, door in CollectionService:GetTagged("CafeDoor") do
		if door:IsA("BasePart") then
			local node: Instance? = door.Parent
			while node ~= nil do
				local owner = node:GetAttribute("OwnerUserId")
				if owner ~= nil then
					if owner == me.UserId then
						return door :: BasePart
					end
					break
				end
				node = node.Parent
			end
		end
	end
	return nil
end

local function townCannon(): Model?
	for _, model in CollectionService:GetTagged("CatCannon") do
		if model:IsA("Model") and model:GetAttribute("CannonId") == "town" then
			return model :: Model
		end
	end
	return nil
end

local function resolve(target: Target): Instance?
	if target == "door" then
		return ownDoor()
	elseif target == "cannon" then
		return townCannon()
	elseif typeof(target) == "Instance" then
		return target :: Instance
	end
	return nil
end

local function hidden(target: Instance): boolean
	return target:IsA("BasePart") and (target :: BasePart).Transparency >= 0.95
end

local function makeGlow(target: Instance, name: string): Glow
	local p = Presets.worldGlow
	local glow: Glow = { target = target }
	if hidden(target) then
		-- the cafe door's zone: a thin panel in the doorway, with a soft light
		local zone = target :: BasePart
		local panel =
			Context.effectPart(name, Vector3.new(zone.Size.X, zone.Size.Y, p.panelDepth), p.gold)
		panel.Material = Enum.Material.Neon
		panel.CFrame = zone.CFrame
		panel.Transparency = 1
		panel.Parent = Context.folder()
		local light = Instance.new("PointLight")
		light.Color = p.gold
		light.Range = p.lightRange
		light.Brightness = 0
		light.Parent = panel
		glow.panel, glow.light = panel, light
	else
		local h = Instance.new("Highlight")
		h.Name = name
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillColor = p.gold
		h.OutlineColor = p.cream
		h.FillTransparency = 1
		h.OutlineTransparency = 1
		h.Parent = Context.folder()
		glow.highlight = h
	end
	return glow
end

local function setStrength(glow: Glow, k: number)
	local p = Presets.worldGlow
	if glow.highlight ~= nil then
		glow.highlight.FillTransparency = 1 - p.fill * k
		glow.highlight.OutlineTransparency = 1 - p.outline * k
	end
	if glow.panel ~= nil then
		glow.panel.Transparency = 1 - p.panel * k
		if
			glow.panel.Parent ~= nil
			and glow.target.Parent ~= nil
			and glow.target:IsA("BasePart")
		then
			glow.panel.CFrame = (glow.target :: BasePart).CFrame
		end
	end
	if glow.light ~= nil then
		glow.light.Brightness = p.lightBrightness * k
	end
end

local function drop(glow: Glow?)
	if glow == nil then
		return
	end
	if glow.highlight ~= nil then
		glow.highlight:Destroy()
	end
	if glow.panel ~= nil then
		glow.panel:Destroy()
	end
end

-- Glows `target` for Presets.worldGlow.stallSeconds (switch `stallGlow`). A new call replaces the one running.
function WorldGlow.stall(target: Target)
	if not flag(Presets.worldGlow.stallFlag) then
		return
	end
	local found = resolve(target)
	if found == nil then
		return
	end
	drop(stallGlow)
	stallGlow = makeGlow(found, "EffectsStallGlow")
	stallAt = os.clock()
end

local function steadyStrength(): number
	if Context.reducedMotion() then
		return 1
	end
	local p = Presets.worldGlow
	return 1 - p.steadyDip * (0.5 - 0.5 * math.cos(2 * math.pi * os.clock() / p.steadyPeriod))
end

local function updateCannon()
	local p = Presets.worldGlow
	local area = Players.LocalPlayer:GetAttribute(p.cannonAttribute)
	local want = if flag(p.cannonFlag)
			and type(area) == "string"
			and area ~= ""
		then area :: string
		else nil
	local cannon = if want ~= nil then townCannon() else nil
	if cannon == nil then
		want = nil
	end
	local same = cannonGlow ~= nil and cannonGlow.target == cannon and cannonArea == want
	if not same then
		drop(cannonGlow)
		cannonGlow = nil
		if cannonSign ~= nil then
			cannonSign:Destroy()
			cannonSign = nil
		end
		cannonArea = want
		if want ~= nil and cannon ~= nil then
			cannonGlow = makeGlow(cannon, "EffectsCannonGlow")
			local _, size = cannon:GetBoundingBox()
			local sign = Instance.new("BillboardGui")
			sign.Name = "EffectsCannonSign"
			sign.Adornee = cannon -- a model: the sign sits over its box's middle
			sign.Size = UDim2.fromScale(p.signWidth, p.signHeight)
			sign.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + p.signLift, 0)
			sign.MaxDistance = p.signDistance
			sign.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.BackgroundColor3 = p.cream
			label.BackgroundTransparency = 0.1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = p.ink
			label.Text = WorldGlow.signText(want)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.3, 0)
			corner.Parent = label
			local stroke = Instance.new("UIStroke")
			stroke.Color = p.gold
			stroke.Thickness = 3
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = label
			label.Parent = sign
			sign.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			cannonSign = sign
		end
	end
	if cannonGlow ~= nil then
		setStrength(cannonGlow, steadyStrength())
	end
end

local function updateDoor()
	local character = Players.LocalPlayer.Character
	local carrying = character ~= nil and character:GetAttribute("CarryingCatId") ~= nil
	local want = WorldGlow.carryDoor(carrying, catsCaught, flag(Presets.worldGlow.carryFlag))
	local door = if want then ownDoor() else nil
	if door == nil then
		if doorGlow ~= nil then
			drop(doorGlow)
			doorGlow = nil
		end
		return
	end
	if doorGlow == nil or doorGlow.target ~= door then
		drop(doorGlow)
		doorGlow = makeGlow(door, "EffectsCarryDoorGlow")
	end
	setStrength(doorGlow :: Glow, steadyStrength())
end

local function updateStall()
	local glow = stallGlow
	if glow == nil then
		return
	end
	local p = Presets.worldGlow
	local t = os.clock() - stallAt
	if t >= p.stallSeconds or glow.target.Parent == nil then
		drop(glow)
		stallGlow = nil
		return
	end
	setStrength(
		glow,
		WorldGlow.stallStrength(t, p.stallSeconds, p.breathe, p.low, Context.reducedMotion())
	)
end

function WorldGlow.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local stats = (state :: { [string]: unknown }).stats
		if type(stats) == "table" and type((stats :: any).catsCaught) == "number" then
			catsCaught = (stats :: any).catsCaught
		end
	end)
	local lookedAt = 0
	RunService.Heartbeat:Connect(function()
		updateStall()
		local now = os.clock()
		local lively = cannonGlow ~= nil or doorGlow ~= nil
		-- the steady glows breathe every frame while they show; what shows is looked at a few times a second
		if now - lookedAt >= Presets.worldGlow.lookSeconds then
			lookedAt = now
			updateCannon()
			updateDoor()
		elseif lively then
			if cannonGlow ~= nil then
				setStrength(cannonGlow, steadyStrength())
			end
			if doorGlow ~= nil then
				setStrength(doorGlow, steadyStrength())
			end
		end
	end)
end

return WorldGlow
