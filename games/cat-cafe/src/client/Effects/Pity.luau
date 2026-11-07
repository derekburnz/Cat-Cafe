--!strict
-- The pity cat (#1572, luck-and-rare-moments.md 1h). As a pity stray appears, a gold beam rises from it for a few
-- seconds (a bundle for a Mythical), seen from across the area. When it is caught in another server, or goes at
-- night, its copy here puffs away in a cloud of gold sparkles and smoke. A catch in this server plays the usual catch
-- effects instead. Reduce Motion skips the beam and keeps the puff.
--
-- While a pity stray is out it also keeps a mark (#2099, luck-and-rare-moments.md 1j; UI-Engineer's "Pity cat" tag
-- goes over its head): a soft gold ring (violet for a Mythical) on the floor under it that breathes from 90 to 100%
-- of its size over 2 s, and one small sparkle puff every 1.5 s. Reduce Motion holds the ring still and drops the
-- sparkles; Low performance does the same (a flat ring, nothing moving but the cat). The mark goes the moment the
-- stray does (caught and carried off, or gone at night), when its PityCat clears, or at nightfall. Presets.pity.mark.
--
-- Source: Gameplay-Engineer's #1744: the `PityCat` attribute ("Legendary" or "Mythical") on the Stray-tagged model,
-- and `PityAnnounce(kind, areaId, state, winnerName?)` with state "out", "caught" or "gone". Listening only. Numbers
-- in Presets.pity.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Pity = {}

local strays: { [Model]: Vector3 } = {} -- each pity stray here and its last known position
local gone: { at: Vector3, when: number }? = nil -- the last pity stray to leave, for a puff just after it went
local beamed: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local started = false

type Mark = {
	stray: Model,
	ring: Part, -- invisible; the ring's SurfaceGui is on its top
	diameter: number,
	sparkAt: number,
	colour: Color3,
}

local marks: { [Model]: Mark } = {}
local stepping: RBXScriptConnection? = nil

local function kindOf(model: Model): string?
	local kind = model:GetAttribute("PityCat")
	return if type(kind) == "string" and kind ~= "" then kind else nil
end

local function beam(model: Model, kind: string)
	if beamed[model] then
		return
	end
	beamed[model] = true
	local p = Presets.pity
	local at = model:GetPivot().Position
	if Context.distance(at) > p.within then
		return
	end
	local b = if kind == "Mythical" then p.mythical else p.legendary
	for i = 1, b.beams do
		local offset = if b.beams > 1
			then Vector3.new(
				math.cos(i / b.beams * 2 * math.pi),
				0,
				math.sin(i / b.beams * 2 * math.pi)
			) * b.spread
			else Vector3.zero
		Particles.beam(
			at + offset,
			b.colours[(i - 1) % #b.colours + 1],
			b.width,
			b.height,
			p.seconds
		)
	end
	Particles.burst("dingSparkle", at + Vector3.new(0, p.lift, 0), b.sparkles, b.colours[1])
end

-- The ring: a flat SurfaceGui on the top of an invisible part, a circle with a `stroke` wide edge and a fainter
-- `halo` inside it, drawn without light or bloom so it reads soft on any floor.
local function drawRing(part: Part, diameter: number, colour: Color3)
	local m = Presets.pity.mark
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PityRing"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = m.pixelsPerStud
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	for _, band in
		{
			{ 1, m.stroke, m.transparency },
			{ 1 - 2 * m.stroke / diameter, m.halo, m.haloTransparency },
		}
	do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(band[1], band[1])
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = colour
		stroke.Thickness = band[2] * m.pixelsPerStud
		stroke.Transparency = band[3]
		stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		stroke.Parent = frame
		frame.Parent = gui
	end
	gui.Parent = part
end

local function unmark(stray: Model)
	local mark = marks[stray]
	if mark ~= nil then
		marks[stray] = nil
		mark.ring:Destroy()
	end
end

-- The floor under the stray's pivot: the bottom of its box.
local function floorUnder(stray: Model): Vector3
	local frame, size = stray:GetBoundingBox()
	local pivot = stray:GetPivot().Position
	return Vector3.new(pivot.X, frame.Position.Y - size.Y / 2, pivot.Z)
end

local function stepMarks()
	local m = Presets.pity.mark
	local now = os.clock()
	local still = Context.reducedMotion() or Context.lowPerformance
	for stray, mark in marks do
		if stray.Parent == nil or kindOf(stray) == nil or Context.isNight() then
			unmark(stray)
			continue
		end
		local at = floorUnder(stray)
		local far = Context.distance(at) > m.within
		local gui = mark.ring:FindFirstChild("PityRing")
		if gui ~= nil and gui:IsA("SurfaceGui") then
			(gui :: SurfaceGui).Enabled = not far
		end
		if far then
			continue
		end
		local scale = if still then m.breath[2] else Logic.pityBreath(now)
		local across = mark.diameter * scale
		mark.ring.Size = Vector3.new(across, 0.05, across)
		mark.ring.CFrame = CFrame.new(at + Vector3.new(0, m.lift, 0))
		if not still and now >= mark.sparkAt then
			mark.sparkAt = now + m.sparkleEvery
			Particles.burst(
				"dingSparkle",
				at + Vector3.new(0, m.sparkleLift, 0),
				m.sparkles,
				mark.colour
			)
		end
	end
	if next(marks) == nil and stepping ~= nil then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Puts the lasting mark under a pity stray, or takes it off when it is no longer one (or it is night).
local function updateMark(model: Model)
	local kind = kindOf(model)
	if kind == nil or model.Parent == nil or Context.isNight() then
		unmark(model)
		return
	end
	if marks[model] ~= nil then
		return
	end
	local m = Presets.pity.mark
	local colour = if kind == "Mythical" then m.mythical else m.legendary
	local _, size = model:GetBoundingBox()
	local diameter = math.max(m.minDiameter, math.max(size.X, size.Z) * m.ring)
	local ring = Context.effectPart("PityMark", Vector3.new(diameter, 0.05, diameter), colour)
	ring.Transparency = 1
	ring.CastShadow = false
	ring.CFrame = CFrame.new(floorUnder(model) + Vector3.new(0, m.lift, 0))
	drawRing(ring, diameter, colour)
	ring.Parent = Context.folder()
	marks[model] = {
		stray = model,
		ring = ring,
		diameter = diameter,
		sparkAt = os.clock(),
		colour = colour,
	}
	if stepping == nil then
		stepping = RunService.PreRender:Connect(stepMarks)
	end
end

local function follow(model: Model)
	local known: Vector3? = strays[model]
	if known then
		return
	end
	local kind = kindOf(model)
	if kind == nil then
		return
	end
	strays[model] = model:GetPivot().Position
	beam(model, kind)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	follow(model)
	updateMark(model)
	model:GetAttributeChangedSignal("PityCat"):Connect(function()
		follow(model)
		updateMark(model)
	end)
end

local function puff(at: Vector3)
	local p = Presets.pity
	if Context.distance(at) > p.within then
		return
	end
	Particles.burst("smokePuff", at, p.puff.smoke)
	Particles.burst("dingSparkle", at + Vector3.new(0, p.lift, 0), p.puff.sparkles, p.puff.colour)
	Particles.ring(at, p.puff.colour, p.puff.ring, p.puff.ringSeconds)
end

-- Whether the winner is a player in this server, so the catch here already plays its own effects.
local function winnerHere(winner: unknown): boolean
	if type(winner) ~= "string" or winner == "" then
		return false
	end
	for _, player in Players:GetPlayers() do
		if player.Name == winner or player.DisplayName == winner then
			return true
		end
	end
	return false
end

local function announced(_kind: unknown, _areaId: unknown, state: unknown, winner: unknown)
	if state ~= "caught" and state ~= "gone" then
		return
	end
	if state == "caught" and winnerHere(winner) then
		return
	end
	local any = false
	for model, at in strays do
		if model.Parent ~= nil then
			puff(model:GetPivot().Position)
		else
			puff(at)
		end
		any = true
	end
	local last = gone
	if not any and last ~= nil and os.clock() - last.when <= Presets.pity.lateSeconds then
		puff(last.at)
	end
	gone = nil
end

function Pity.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("Stray") do
		consider(instance)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(consider)
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			local at: Vector3? = strays[instance :: Model]
			if at then
				gone = { at = at, when = os.clock() }
				strays[instance :: Model] = nil
			end
			unmark(instance :: Model)
		end
	end)
	Context.whenRemote("PityAnnounce", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(announced)
	end)
	-- keep each stray's last position, so a puff after it streamed out or was removed lands where it stood
	task.spawn(function()
		while true do
			task.wait(Presets.pity.track)
			for model in strays do
				if model.Parent ~= nil then
					strays[model] = model:GetPivot().Position
					updateMark(model) -- back after the night, or streamed in again
				end
			end
		end
	end)
end

return Pity
