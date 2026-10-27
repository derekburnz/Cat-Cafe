--!strict
-- Client-side world touches: each area gate opens once the cafe reaches that area's tier, check-in fires itself at the
-- own cafe door while carrying, the first tutorial step advances when the player reaches the alley, a stray hides its
-- prompt while it runs off after a miss, the ambience follows the zone the player stands in, the roof of
-- the cafe the player is inside fades out, and the sky and the parts that glow at night follow the server's day and
-- night clock (features F20). It also follows two of the player's settings: Low performance and Show other cats.
-- All cosmetic, all local.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(script.Parent.Parent.Audio)
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local WorldController = {}

local player = Players.LocalPlayer

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- The cafe whose floor the player stands on, if any (plot space: X along the street, Z away from it).
local function plotAt(position: Vector3): Model?
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	if plots == nil then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			local offset = (plot :: Model):GetPivot():PointToObjectSpace(position)
			if
				math.abs(offset.X) <= Config.World.PlotWidth / 2 + 0.5
				and math.abs(offset.Z) <= Config.World.PlotDepth / 2 + 0.5
				and offset.Y < 12
			then
				return plot :: Model
			end
		end
	end
	return nil
end

-- The cafe shell's roof (its child Model <name>_Roof: roof, ridge and chimney) fades out on this screen while the
-- player is inside, the sketch's cutaway view (world-and-feel.md section 3). LocalTransparencyModifier is local
-- only, and at 1 the camera stops treating the roof as something to zoom in front of.
local ROOF_FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setRoofHidden(plot: Model, hidden: boolean)
	local shell = plot:FindFirstChild("Shell")
	if shell == nil then
		return
	end
	for _, child in shell:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-5) == "_Roof" then
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					TweenService:Create(
						descendant,
						ROOF_FADE,
						{ LocalTransparencyModifier = if hidden then 1 else 0 }
					):Play()
				end
			end
		end
	end
end

local insidePlot: Model? = nil -- the cafe whose floor the character stands on, its roof faded
local heldRoof: Model? = nil -- a cafe whose roof the intro holds faded wherever the character is (F72)

-- v0.5 (data-model section 10 step 5): a missed stray sprints off and catches its breath until its FleeingUntil
-- (server time). Its prompt hides on this client until then; the server refuses GrabBegin meanwhile anyway.
local function watchStray(model: Instance)
	local serial = 0
	local function refresh()
		serial += 1
		local mine = serial
		local prompt = model:FindFirstChild("GrabPrompt", true)
		if prompt == nil or not prompt:IsA("ProximityPrompt") then
			return
		end
		local fleeingUntil = model:GetAttribute("FleeingUntil")
		local left = if type(fleeingUntil) == "number"
			then fleeingUntil - Workspace:GetServerTimeNow()
			else 0
		(prompt :: ProximityPrompt).Enabled = left <= 0
		if left > 0 then
			task.delay(left, function()
				if serial == mine and model.Parent ~= nil then
					refresh()
				end
			end)
		end
	end
	refresh()
	model:GetAttributeChangedSignal("FleeingUntil"):Connect(refresh)
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

-- Only the gate's barrier changes: the ForceField part named Bars across the whole opening, or the lid of the
-- Square's manhole (the parts of its child Model named <asset>_Cover). The arch stays solid. The barrier keeps
-- its own look while closed and vanishes once open (Effects draws the dissolve the first time); a lid keeps its
-- own collision. A sign on the bars (the Alleyway's night fence) shows only while they are closed.
local closedTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

local function isLid(part: BasePart): boolean
	local parent = part.Parent
	return parent ~= nil and parent:IsA("Model") and parent.Name:sub(-6) == "_Cover"
end

local function setGateOpen(gate: Instance, open: boolean)
	for _, descendant in gate:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		local part = descendant :: BasePart
		local bars = part.Name == "Bars"
		if bars or isLid(part) then
			if closedTransparency[part] == nil then
				closedTransparency[part] = part.Transparency
			end
			if bars then
				part.CanCollide = not open
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceGui") then
						(child :: SurfaceGui).Enabled = not open
					end
				end
			end
			part.Transparency = if open then 1 else closedTransparency[part]
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
	ExposureCompensation = 0,
	ColorShift_Top = Color3.fromRGB(150, 170, 220),
}
local DAY_ATMOSPHERE_DENSITY = 0.3
local NIGHT_ATMOSPHERE = { Density = 0.4, Color = Color3.fromRGB(110, 120, 160) }
local LIGHTING_TWEEN = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Parts that glow at night (style guide section 9): any part under the World folder whose name ends in _Bulb,
-- _Bulbs, _Pane or _Tube, placeholder or real model. By day each keeps the look it was built with; at night it
-- turns Neon in lamp_warm (neon_pink for a sign's tube) and its light comes on. HangingLamp bulbs are indoors
-- and lit all day, so they stay as built. A window pane stays partly see-through at night and the lights are
-- soft, because solid Neon panes and bright lights washed the cafe inside out to white (laptop playtest, #184).
local LAMP_WARM = Color3.fromRGB(255, 217, 168)
local NEON_PINK = Color3.fromRGB(255, 107, 129)
local NIGHT_SUFFIXES = { "_Bulb", "_Bulbs", "_Pane", "_Tube" }
local PANE_NIGHT_TRANSPARENCY = 0.3
local GLOW_LIGHT_BRIGHTNESS = 0.8
local GLOW_LIGHT_RANGE = 10

type DayLook = { material: Enum.Material, color: Color3, transparency: number, light: Light }

local dayLooks: { [BasePart]: DayLook } = setmetatable({}, { __mode = "k" }) :: any
local modelLights: { [Instance]: Light } = setmetatable({}, { __mode = "k" }) :: any
local isNight = false
local atmosphereDayColor: Color3? = nil
local lowPerformance = false -- the Low performance setting: no night Light objects, shadows or post effects

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
		point.Range = GLOW_LIGHT_RANGE
		point.Brightness = GLOW_LIGHT_BRIGHTNESS
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
		part.Transparency = if part.Name:sub(-5) == "_Pane" then PANE_NIGHT_TRANSPARENCY else 0
	else
		part.Material = look.material
		part.Color = look.color
		part.Transparency = look.transparency
	end
	look.light.Enabled = isNight and not lowPerformance
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

-- The sky's tweens now playing, cancelled by the next change so an instant one is not overwritten by an old tween.
local lightingTweens: { Tween } = {}
-- True while the intro (F72) shows its own night on this screen; the clock's changes wait for endPreview.
local previewing = false

local function applyPhase(phase: any, instant: boolean, seconds: number?)
	for _, tween in lightingTweens do
		tween:Cancel()
	end
	table.clear(lightingTweens)
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
		local info = if seconds ~= nil
			then TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			else LIGHTING_TWEEN
		table.insert(lightingTweens, TweenService:Create(Lighting, info, goal :: any))
		if atmosphere ~= nil and atmosphereGoal ~= nil then
			table.insert(
				lightingTweens,
				TweenService:Create(atmosphere, info, atmosphereGoal :: any)
			)
		end
		for _, tween in lightingTweens do
			tween:Play()
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
		if not previewing then
			applyPhase(clock:GetAttribute("Phase"), false)
		end
	end)
end

-- Low performance (Derek's settings menu): the night parts still turn Neon but their Light objects stay off, and
-- the place's global shadows and its Bloom, SunRays and DepthOfField go off. Turning it back restores what the
-- place had. Effects follows the same setting for particles (Effects.applySettings).
local savedShadows: boolean? = nil
local savedPostEffects: { [PostEffect]: boolean } = {}

local function setLowPerformance(on: boolean)
	if on == lowPerformance then
		return
	end
	lowPerformance = on
	for part, look in dayLooks do
		setGlow(part, look)
	end
	if on then
		savedShadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		for _, child in Lighting:GetChildren() do
			if
				child:IsA("BloomEffect")
				or child:IsA("SunRaysEffect")
				or child:IsA("DepthOfFieldEffect")
			then
				local effect = child :: PostEffect
				savedPostEffects[effect] = effect.Enabled
				effect.Enabled = false
			end
		end
	else
		if savedShadows ~= nil then
			Lighting.GlobalShadows = savedShadows
			savedShadows = nil
		end
		for effect, enabled in savedPostEffects do
			effect.Enabled = enabled
		end
		table.clear(savedPostEffects)
	end
end

-- Show other cats (Derek's settings menu): off hides every cat another player owns, in their cafe, at their bait
-- bowl and in their arms, on this client only. A hidden cat's parts get LocalTransparencyModifier 1, its
-- billboards turn off, and it carries the local attribute HiddenLocal = true so Effects can skip it.
local showOtherCats = true
local hiddenCats: { [Model]: { [Instance]: boolean } } = {} -- each hidden cat's billboards and their Enabled before

local function isOtherCat(instance: Instance): boolean
	if not instance:IsA("Model") or instance:GetAttribute("CatId") == nil then
		return false
	end
	if instance.Name == "HeldCat" then
		local character = instance.Parent
		local owner = if character ~= nil and character:IsA("Model")
			then Players:GetPlayerFromCharacter(character :: Model)
			else nil
		return owner ~= nil and owner ~= player
	end
	local ownerId = instance:GetAttribute("OwnerUserId")
	return type(ownerId) == "number" and ownerId ~= 0 and ownerId ~= player.UserId
end

local function setCatHidden(model: Model, hidden: boolean)
	if (hiddenCats[model] ~= nil) == hidden then
		return
	end
	local billboards: { [Instance]: boolean } = {}
	if hidden then
		hiddenCats[model] = billboards
		model:SetAttribute("HiddenLocal", true)
	else
		billboards = hiddenCats[model] or billboards
		hiddenCats[model] = nil
		model:SetAttribute("HiddenLocal", nil)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("BillboardGui") then
			local gui = descendant :: BillboardGui
			if hidden then
				billboards[gui] = gui.Enabled
				gui.Enabled = false
			elseif billboards[gui] ~= nil then
				gui.Enabled = billboards[gui]
			end
		end
	end
end

-- A cat that arrives while Show other cats is off is hidden whole; a part or billboard that arrives later under a
-- hidden cat (an outfit piece, a name tag) is hidden with it (review N137).
local function considerCat(instance: Instance)
	if not showOtherCats and isOtherCat(instance) then
		setCatHidden(instance :: Model, true)
		return
	end
	if next(hiddenCats) == nil then
		return
	end
	local hiddenModel = instance:FindFirstAncestorWhichIsA("Model") :: Model?
	while hiddenModel ~= nil and hiddenCats[hiddenModel] == nil do
		hiddenModel = hiddenModel:FindFirstAncestorWhichIsA("Model") :: Model?
	end
	if hiddenModel == nil then
		return
	end
	if instance:IsA("BasePart") then
		(instance :: BasePart).LocalTransparencyModifier = 1
	elseif instance:IsA("BillboardGui") then
		local gui = instance :: BillboardGui
		hiddenCats[hiddenModel][gui] = gui.Enabled
		gui.Enabled = false
	end
end

local function eachOtherCat(visit: (Model) -> ())
	local world = Workspace:FindFirstChild("World")
	local plots = if world ~= nil then world:FindFirstChild("Plots") else nil
	if plots ~= nil then
		for _, descendant in plots:GetDescendants() do
			if isOtherCat(descendant) then
				visit(descendant :: Model)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		local held = if other ~= player and other.Character ~= nil
			then other.Character:FindFirstChild("HeldCat")
			else nil
		if held ~= nil and isOtherCat(held) then
			visit(held :: Model)
		end
	end
end

local function setShowOtherCats(on: boolean)
	if on == showOtherCats then
		return
	end
	showOtherCats = on
	if on then
		for model in hiddenCats do
			setCatHidden(model, false)
		end
	else
		eachOtherCat(function(model)
			setCatHidden(model, true)
		end)
	end
end

-- Watches for cats that arrive while Show other cats is off: a cafe's cats are rebuilt on every refresh, and a
-- carried cat is a HeldCat model under its carrier's character.
local function watchOtherCats()
	local function watchCharacter(character: Model)
		character.DescendantAdded:Connect(considerCat)
	end
	local function watchPlayer(other: Player)
		if other == player then
			return
		end
		other.CharacterAdded:Connect(watchCharacter)
		if other.Character ~= nil then
			watchCharacter(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		local plots = world:WaitForChild("Plots")
		plots.DescendantAdded:Connect(considerCat)
	end)
end

-- Follows the two switches as the Settings screen shows them (a tap at once, then the saved value), read on every
-- tick of the loop below once the first sync is in; both setters do nothing while their value is unchanged.
local function applySettings()
	setLowPerformance(UI.settings.value("lowPerformance"))
	setShowOtherCats(UI.settings.value("showOtherCats"))
end

-- The intro (F72, shot 3): `plot`'s roof fades as it does for an owner inside, wherever the character stands. Nil
-- lets the held roof go back to what the character's place says.
function WorldController.holdRoofOpen(plot: Model?)
	local was = heldRoof
	if was == plot then
		return
	end
	heldRoof = plot
	if was ~= nil and was ~= insidePlot then
		setRoofHidden(was, false)
	end
	if plot ~= nil and plot ~= insidePlot then
		setRoofHidden(plot, true)
	end
end

-- The intro (F72, shot 8): night falls ("night") or the sun rises ("day") on this screen over `seconds`, whatever
-- the server's clock says. The clock's own changes wait until endPreview.
function WorldController.previewPhase(phase: string, seconds: number)
	previewing = true
	applyPhase(phase, false, seconds)
end

-- Puts the sky and the night parts back to the server's phase after previewPhase: over `seconds`, or at once.
function WorldController.endPreview(seconds: number?)
	if not previewing then
		return
	end
	previewing = false
	applyPhase(
		ReplicatedStorage:WaitForChild("Clock"):GetAttribute("Phase"),
		seconds == nil,
		seconds
	)
end

-- The zone box name at `position` (ShoveController turns the Shove button on in a catching area).
function WorldController.zoneAt(position: Vector3): string?
	return zoneAt(position)
end

function WorldController.start()
	task.spawn(followClock)
	watchOtherCats()

	for _, model in CollectionService:GetTagged("Stray") do
		watchStray(model)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watchStray)

	-- Gates under World.Gates (WorldBuilder): the barrier is solid below the gate's RequiresTier and gone at or
	-- above it, and solid on every gate while the Clock's AreasOpen is false (v0.9, F66: the areas close at night;
	-- the Alleyway's night fence is a gate that only ever closes for that). Only this player's copy changes; the
	-- server checks the tier and the clock on every catch and rescue.
	local gateOpen: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local gateLocked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- seen below its tier
	local lastCheckIn = 0
	local sawAlley = false
	local lastZone: string? = nil

	task.spawn(function()
		local clock = ReplicatedStorage:WaitForChild("Clock")
		while true do
			task.wait(0.25)
			local state = UIController.state
			if state == nil then
				continue
			end
			applySettings()

			local world = Workspace:FindFirstChild("World")
			local gates = if world ~= nil then world:FindFirstChild("Gates") else nil
			if gates ~= nil then
				-- An area opening while you play (not one already open when you joined) is one moment, from the
				-- nearest of its ways in: the Sewer has its gate and the Square's manhole. A rank up at night waits
				-- for the sunrise to open the gate, so the moment does too.
				local opened: { [string]: Vector3 } = {}
				local here = rootPosition()
				local areasOpen = clock:GetAttribute("AreasOpen") ~= false
				for _, gate in gates:GetChildren() do
					local requires = gate:GetAttribute("RequiresTier")
					local unlocked = type(requires) == "number" and state.tier >= requires
					local open = unlocked and areasOpen
					if not unlocked then
						gateLocked[gate] = true
					end
					if gateOpen[gate] ~= open then
						gateOpen[gate] = open
						setGateOpen(gate, open)
						local area = gate:GetAttribute("Area")
						if
							open
							and gateLocked[gate] == true
							and type(area) == "string"
							and gate:IsA("Model")
						then
							gateLocked[gate] = nil
							local at = (gate :: Model):GetPivot().Position
							local best: Vector3? = opened[area]
							if
								best == nil
								or (here ~= nil and (at - here).Magnitude < (best - here).Magnitude)
							then
								opened[area] = at
							end
						end
					end
				end
				for area, at in opened do
					Moments.AreaUnlock:Fire(area, at)
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

			local inside = plotAt(position)
			local wasInside = insidePlot
			if inside ~= wasInside then
				if wasInside ~= nil and wasInside ~= heldRoof then
					setRoofHidden(wasInside, false)
				end
				if inside ~= nil then
					setRoofHidden(inside, true)
				end
				insidePlot = inside
			end

			local zone = zoneAt(position)
			if zone ~= lastZone then
				lastZone = zone
				Audio.setZone(zone)
				-- the HUD's zone chip (UI thread): nil or "Cafe" is the safe street, anything else a catching area.
				-- Looked up loosely so this loads before or after the UI build that adds it.
				local setZone: ((string?) -> ())? = (UI :: any).setZone
				if setZone ~= nil then
					setZone(zone)
				end
				-- walking into an area shows its title card (F39); the card skips a repeat within 4 s
				if zone ~= nil and zone ~= "Cafe" then
					UI.showAreaTitle(zone:lower())
				end
			end

			if not sawAlley and state.tutorialStep == 0 and zone == "Alley" then
				sawAlley = true
				Net.fire("TutorialAdvance", 1)
			end
		end
	end)
end

return WorldController
