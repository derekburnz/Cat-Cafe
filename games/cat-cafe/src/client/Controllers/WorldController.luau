--!strict
-- Client-side world touches: each area gate opens once the cafe reaches that area's tier, check-in fires itself at the
-- own cafe door while carrying, the first tutorial step advances when the player reaches the alley, a stray this
-- player is out of paws on hides its prompt for them, the ambience follows the zone the player stands in, and the
-- sky and the parts that glow at night follow the server's day and night clock (features F20). All cosmetic, all
-- local.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(script.Parent.Parent.Audio)
local Config = require(Shared:WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local UIController = require(script.Parent.UIController)

local WorldController = {}

local player = Players.LocalPlayer

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- v0.4 (data-model section 10 step 5): once this player has no paws left on a stray (its Paws_<UserId> attribute
-- reaches 0) its prompt goes away for them only; everyone else still sees it.
local function watchStray(model: Instance)
	local attribute = "Paws_" .. player.UserId
	local function refresh()
		local prompt = model:FindFirstChild("GrabPrompt", true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).Enabled = model:GetAttribute(attribute) ~= 0
		end
	end
	refresh()
	model:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- The World.Zones box the player stands in ("Cafe", "Alley", "Park" and so on), or nil (WorldBuilder).
local function zoneAt(position: Vector3): string?
	local world = Workspace:FindFirstChild("World")
	local zones = if world ~= nil then world:FindFirstChild("Zones") else nil
	if zones == nil then
		return nil
	end
	for _, box in zones:GetChildren() do
		if box:IsA("BasePart") then
			local offset = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if
				math.abs(offset.X) <= half.X
				and math.abs(offset.Y) <= half.Y
				and math.abs(offset.Z) <= half.Z
			then
				return box.Name
			end
		end
	end
	return nil
end

local function setGateOpen(gate: Instance, open: boolean)
	for _, descendant in gate:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.CanCollide = not open
			part.Transparency = if open then 0.85 else (if part.Name == "Bars" then 0.35 else 0)
		elseif descendant:IsA("BillboardGui") then
			(descendant :: BillboardGui).Enabled = not open
		end
	end
end

-- Lighting presets from the style guide (section 9). Visual only, so the numbers live here rather than in Config.
-- Technology, Bloom and ColorCorrection are place settings in Studio; Atmosphere is tweened when the place has one.
local DAY_LIGHTING = {
	ClockTime = 14.5,
	Brightness = 2,
	OutdoorAmbient = Color3.fromRGB(170, 160, 150),
	Ambient = Color3.fromRGB(120, 115, 110),
	ExposureCompensation = 0,
	ColorShift_Top = Color3.fromRGB(255, 245, 230),
}
local NIGHT_LIGHTING = {
	ClockTime = 0.5,
	Brightness = 0.6,
	OutdoorAmbient = Color3.fromRGB(45, 55, 85),
	Ambient = Color3.fromRGB(30, 35, 55),
	ExposureCompensation = 0.25,
	ColorShift_Top = Color3.fromRGB(150, 170, 220),
}
local DAY_ATMOSPHERE_DENSITY = 0.3
local NIGHT_ATMOSPHERE = { Density = 0.4, Color = Color3.fromRGB(110, 120, 160) }
local LIGHTING_TWEEN = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Parts that glow at night (style guide section 9): any part under the World folder whose name ends in _Bulb,
-- _Bulbs, _Pane or _Tube, placeholder or real model. By day each keeps the look it was built with; at night it
-- turns Neon in lamp_warm (neon_pink for a sign's tube) and its light comes on. HangingLamp bulbs are indoors
-- and lit all day, so they stay as built.
local LAMP_WARM = Color3.fromRGB(255, 217, 168)
local NEON_PINK = Color3.fromRGB(255, 107, 129)
local NIGHT_SUFFIXES = { "_Bulb", "_Bulbs", "_Pane", "_Tube" }

type DayLook = { material: Enum.Material, color: Color3, transparency: number, light: Light }

local dayLooks: { [BasePart]: DayLook } = setmetatable({}, { __mode = "k" }) :: any
local modelLights: { [Instance]: Light } = setmetatable({}, { __mode = "k" }) :: any
local isNight = false
local atmosphereDayColor: Color3? = nil

local function glowsAtNight(part: BasePart): boolean
	local name = part.Name
	if name:find("HangingLamp", 1, true) ~= nil then
		return false
	end
	for _, suffix in NIGHT_SUFFIXES do
		if name:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local function isTube(part: BasePart): boolean
	return part.Name:sub(-5) == "_Tube"
end

-- The part's own light if it has one, otherwise the light the style guide gives that kind of part, made once per
-- model: a string of bulbs gets one soft light, not one per bulb (reviewer S22).
local function lightFor(part: BasePart): Light
	local existing = part:FindFirstChildWhichIsA("Light")
	if existing ~= nil then
		return existing :: Light
	end
	local model = part:FindFirstAncestorWhichIsA("Model")
	local shared = if model ~= nil then modelLights[model] else nil
	if shared ~= nil then
		return shared
	end
	local light: Light
	if part.Name:find("StreetLamp", 1, true) ~= nil then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 100
		spot.Range = 30
		spot.Brightness = 3
		spot.Color = Color3.fromRGB(255, 200, 150)
		light = spot
	else
		local point = Instance.new("PointLight")
		point.Range = 16
		point.Brightness = 1.5
		point.Color = if isTube(part) then NEON_PINK else Color3.fromRGB(255, 214, 170)
		light = point
	end
	light.Enabled = false
	light.Parent = part
	if model ~= nil then
		modelLights[model] = light
	end
	return light
end

local function setGlow(part: BasePart, look: DayLook)
	if isNight then
		part.Material = Enum.Material.Neon
		part.Color = if isTube(part) then NEON_PINK else LAMP_WARM
		part.Transparency = 0
	else
		part.Material = look.material
		part.Color = look.color
		part.Transparency = look.transparency
	end
	look.light.Enabled = isNight
end

-- Records a night part's day look the first time it is seen, then gives it the current phase's look.
local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	if dayLooks[part] ~= nil or not glowsAtNight(part) then
		return
	end
	local look: DayLook = {
		material = part.Material,
		color = part.Color,
		transparency = part.Transparency,
		light = lightFor(part),
	}
	dayLooks[part] = look
	setGlow(part, look)
end

local function setNight(night: boolean)
	isNight = night
	local world = Workspace:FindFirstChild("World")
	if world ~= nil then
		for _, descendant in world:GetDescendants() do
			track(descendant)
		end
	end
	for part, look in dayLooks do
		setGlow(part, look)
	end
end

local function applyPhase(phase: any, instant: boolean)
	local night = phase == "night"
	local goal = table.clone(if night then NIGHT_LIGHTING else DAY_LIGHTING)
	-- ClockTime wraps at 24, so the sun always runs forward: dusk goes 14.5 to 24.5 (0.5) and dawn 0.5 to 14.5,
	-- never backwards (reviewer N23).
	if not instant and goal.ClockTime < Lighting.ClockTime then
		goal.ClockTime += 24
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") :: Atmosphere?
	local atmosphereGoal = nil
	if atmosphere ~= nil then
		local dayColor = atmosphereDayColor or atmosphere.Color
		atmosphereDayColor = dayColor
		atmosphereGoal = if night
			then NIGHT_ATMOSPHERE
			else { Density = DAY_ATMOSPHERE_DENSITY, Color = dayColor }
	end
	if instant then
		Lighting.ClockTime = goal.ClockTime
		Lighting.Brightness = goal.Brightness
		Lighting.OutdoorAmbient = goal.OutdoorAmbient
		Lighting.Ambient = goal.Ambient
		Lighting.ExposureCompensation = goal.ExposureCompensation
		Lighting.ColorShift_Top = goal.ColorShift_Top
		if atmosphere ~= nil and atmosphereGoal ~= nil then
			atmosphere.Density = atmosphereGoal.Density
			atmosphere.Color = atmosphereGoal.Color
		end
	else
		TweenService:Create(Lighting, LIGHTING_TWEEN, goal :: any):Play()
		if atmosphere ~= nil and atmosphereGoal ~= nil then
			TweenService:Create(atmosphere, LIGHTING_TWEEN, atmosphereGoal :: any):Play()
		end
	end
	setNight(night)
end

local function followClock()
	-- Night parts that stream in or are built later (a bought neon sign) pick up the current phase. They live
	-- in the World folder, so only that folder is watched, not every stray and customer (reviewer N22).
	task.spawn(function()
		Workspace:WaitForChild("World").DescendantAdded:Connect(track)
	end)
	local clock = ReplicatedStorage:WaitForChild("Clock")
	applyPhase(clock:GetAttribute("Phase"), true)
	clock:GetAttributeChangedSignal("Phase"):Connect(function()
		applyPhase(clock:GetAttribute("Phase"), false)
	end)
end

function WorldController.start()
	task.spawn(followClock)

	for _, model in CollectionService:GetTagged("Stray") do
		watchStray(model)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watchStray)

	-- Gates under World.Gates (WorldBuilder): solid below the gate's RequiresTier, see-through and passable at
	-- or above it. Only this player's copy changes; the server checks the tier on every catch and rescue.
	local gateOpen: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local lastCheckIn = 0
	local sawAlley = false
	local lastZone: string? = nil

	task.spawn(function()
		while true do
			task.wait(0.25)
			local state = UIController.state
			if state == nil then
				continue
			end

			local world = Workspace:FindFirstChild("World")
			local gates = if world ~= nil then world:FindFirstChild("Gates") else nil
			if gates ~= nil then
				for _, gate in gates:GetChildren() do
					local requires = gate:GetAttribute("RequiresTier")
					local open = type(requires) == "number" and state.tier >= requires
					if gateOpen[gate] ~= open then
						gateOpen[gate] = open
						setGateOpen(gate, open)
					end
				end
			end

			local position = rootPosition()
			if position == nil then
				continue
			end

			if state.carrying ~= nil and os.clock() - lastCheckIn > 2 then
				-- Either door checks the cat in (layout v2).
				local front, back = UIController.ownDoor(), UIController.ownBackDoor()
				local reach = Config.CheckInRangeStuds - 1
				if
					(front ~= nil and (front.Position - position).Magnitude <= reach)
					or (back ~= nil and (back.Position - position).Magnitude <= reach)
				then
					lastCheckIn = os.clock()
					Net.fire("CheckIn")
				end
			end

			local zone = zoneAt(position)
			if zone ~= lastZone then
				lastZone = zone
				Audio.setZone(zone)
			end

			if not sawAlley and state.tutorialStep == 0 and zone == "Alley" then
				sawAlley = true
				Net.fire("TutorialAdvance", 1)
			end
		end
	end)
end

return WorldController
