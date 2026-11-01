--!strict
-- The campfires (Derek 2026-10-30: "The fire from the camp fire isnt moving"). Model-Agent's flame is the
-- `_Campfire_Glow` model over each ring of stones: three tongues, each three stacked Neon discs. On this client each
-- tongue stretches and squashes, leans and bends a little more at the tip, and flickers brighter, out of step with
-- the other two, so the fire looks alive without any fire texture. Warm embers drift up off it, a few more pop up
-- now and then, and a warm light flickers with the flame, brighter at night. With Reduce Motion the flame moves less.
-- Only the nearest campfires within the budget's range move; the others stand as modelled, and every disc goes back
-- to its modelled place, size and colour when its fire stops.
--
-- Source: Models under Workspace.World whose name ends `_Campfire_Glow` (their parts share the name). The parts are
-- the server's, placed once by the area set and never moved after; a part found away from where this client last
-- put it (checked every step while the fire moves, every second while it stands) has been moved or streamed again,
-- so the fire is read again, and a flame whose parts have not streamed in yet is tried again every second. Numbers
-- in Presets.campfire.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Campfire = {}

type Disc = {
	part: BasePart,
	rest: CFrame,
	size: Vector3,
	colour: Color3,
	up: number, -- the part's own axis that stands up (Logic.upAxis)
	offset: Vector3, -- its centre from the tongue's base
}

type Tongue = { discs: { Disc }, base: Vector3, top: number, phase: number }

type Fire = {
	model: Model,
	tongues: { Tongue },
	parts: { BasePart }, -- every disc, for BulkMoveTo
	frames: { CFrame }, -- reused every step, also where this client last put each disc
	base: Vector3, -- the flame's middle at the bottom
	on: boolean,
	stale: boolean, -- stopped by a step that found it moved or streamed out: read it again
	holder: Attachment?,
	light: PointLight?,
	nextPop: number, -- os.clock()
}

local SUFFIX = "_Campfire_Glow"
local TICK_SECONDS = 1

local fires: { [Model]: Fire } = {}
local waiting: { [Model]: boolean } = {} -- flames found before any of their parts had streamed in
local rng = Random.new()
local lastStep = 0
local started = false

local function isFlame(instance: Instance): boolean
	local name = instance.Name
	return instance:IsA("Model") and #name >= #SUFFIX and name:sub(-#SUFFIX) == SUFFIX
end

local function axisOf(part: BasePart): number
	local frame = part.CFrame
	return Logic.upAxis(frame.RightVector.Y, frame.UpVector.Y, frame.LookVector.Y)
end

-- Reads a flame as it stands: its discs grouped into tongues. Nil while none of its parts have streamed in.
local function bind(model: Model): Fire?
	local parts: { BasePart } = {}
	local points: { Vector3 } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			table.insert(parts, part)
			table.insert(points, part.Position)
		end
	end
	if #parts == 0 then
		return nil
	end
	local c = Presets.campfire
	local fire: Fire = {
		model = model,
		tongues = {},
		parts = {},
		frames = {},
		base = Vector3.zero,
		on = false,
		stale = false,
		holder = nil,
		light = nil,
		nextPop = 0,
	}
	local middle = Vector3.zero
	local shift = rng:NextNumber(0, 2 * math.pi) -- so two fires never flicker together
	for k, indexes in Logic.flameTongues(points, c.gap) do
		local lowest = parts[indexes[1]]
		local up = axisOf(lowest)
		local half = (
			if up == 1 then lowest.Size.X elseif up == 2 then lowest.Size.Y else lowest.Size.Z
		) / 2
		local base = lowest.Position - Vector3.new(0, half, 0)
		local tongue: Tongue = { discs = {}, base = base, top = 0, phase = shift + k * 2.1 }
		for _, i in indexes do
			local part = parts[i]
			local axis = axisOf(part)
			local offset = part.Position - base
			table.insert(tongue.discs, {
				part = part,
				rest = part.CFrame,
				size = part.Size,
				colour = part.Color,
				up = axis,
				offset = offset,
			})
			local reach = (
				if axis == 1 then part.Size.X elseif axis == 2 then part.Size.Y else part.Size.Z
			) / 2
			tongue.top = math.max(tongue.top, offset.Y + reach)
			table.insert(fire.parts, part)
			table.insert(fire.frames, part.CFrame)
		end
		middle += base
		table.insert(fire.tongues, tongue)
	end
	fire.base = middle / #fire.tongues
	return fire
end

-- True while every disc is still where this client last put it (or the server left it, while the fire is off).
local function intact(fire: Fire): boolean
	for i, part in fire.parts do
		if part.Parent == nil or (part.Position - fire.frames[i].Position).Magnitude > 0.01 then
			return false
		end
	end
	return true
end

local function countParts(model: Model): number
	local n = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Stops a fire and gives each disc back its modelled size and colour, and its place too when `restoreFrames` (not
-- when the server has moved it since).
local function switchOff(fire: Fire, restoreFrames: boolean)
	fire.on = false
	local holder = fire.holder
	if holder ~= nil then
		holder:Destroy()
	end
	fire.holder, fire.light = nil, nil
	for _, tongue in fire.tongues do
		for _, disc in tongue.discs do
			if disc.part.Parent ~= nil then
				if restoreFrames then
					disc.part.CFrame = disc.rest
				end
				disc.part.Size = disc.size
				disc.part.Color = disc.colour
			end
		end
	end
	for i, part in fire.parts do
		fire.frames[i] = part.CFrame
	end
end

local function switchOn(fire: Fire)
	local c = Presets.campfire
	fire.on = true
	local holder = Particles.anchor("EffectsCampfire", fire.base + Vector3.new(0, c.emberHeight, 0))
	local light = Instance.new("PointLight")
	light.Color = c.light
	light.Range = c.range
	light.Brightness = c.brightness
	light.Shadows = false
	light.Parent = holder
	Particles.attach("ember", holder)
	fire.holder, fire.light = holder, light
	fire.nextPop = os.clock() + rng:NextNumber(c.popEvery[1], c.popEvery[2])
end

local function step()
	local now = os.clock()
	if now - lastStep < 1 / Context.budget.animHz then
		return
	end
	lastStep = now
	local c = Presets.campfire
	local calm = if Context.reducedMotion() then c.still else 1
	local glow = c.brightness * (if Context.isNight() then c.night else 1)
	local motion = { stretch = c.stretch * calm, lean = c.lean * calm, hz = c.hz }
	for _, fire in fires do
		if not fire.on then
			continue
		end
		-- a disc streamed out, or away from where this client last put it (the server moved it): stop, and tick
		-- reads it again
		local whole = true
		for i, part in fire.parts do
			whole = whole
				and part.Parent ~= nil
				and (part.Position - fire.frames[i].Position).Magnitude <= 0.01
		end
		if not whole then
			switchOff(fire, false)
			fire.stale = true
			continue
		end
		local n, flickers = 0, 0
		for _, tongue in fire.tongues do
			local stretch, leanX, leanZ, flicker = Logic.flame(now, tongue.phase, motion)
			flickers += flicker
			for _, disc in tongue.discs do
				n += 1
				local lift, ax, az = Logic.flameLift(disc.offset, tongue.top, stretch, leanX, leanZ)
				fire.frames[n] = CFrame.new(tongue.base + lift)
					* CFrame.Angles(ax, 0, az)
					* disc.rest.Rotation
				disc.part.Size = disc.size * Logic.flameScale(disc.up, stretch)
				disc.part.Color = disc.colour:Lerp(c.hot, c.brighten * flicker)
			end
		end
		Workspace:BulkMoveTo(fire.parts, fire.frames, Enum.BulkMoveMode.FireCFrameChanged)
		local light = fire.light
		if light ~= nil then
			local flicker = flickers / math.max(1, #fire.tongues)
			light.Brightness = glow * (1 + c.flicker * (flicker * 2 - 1))
		end
		if now >= fire.nextPop then
			fire.nextPop = now + rng:NextNumber(c.popEvery[1], c.popEvery[2])
			Particles.burst("ember", fire.base + Vector3.new(0, c.emberHeight, 0), c.pop)
		end
	end
end

-- Once a second: the nearest fires in range move, the rest stand still.
local function tick()
	for model in waiting do
		local fire = if model.Parent ~= nil then bind(model) else nil
		if fire ~= nil then
			fires[model] = fire
		end
		if fire ~= nil or model.Parent == nil then
			waiting[model] = nil
		end
	end
	local budget = Context.budget
	local candidates: { Logic.Candidate<Fire> } = {}
	for model, fire in fires do
		if model.Parent == nil then
			switchOff(fire, false)
			fires[model] = nil
			continue
		end
		-- moved by the server or streamed out, or more of it streamed in: read it again
		local moved = not intact(fire)
		if moved or fire.stale or countParts(model) ~= #fire.parts then
			switchOff(fire, not moved)
			fires[model] = nil
			local again = bind(model)
			if again ~= nil then
				fires[model] = again
			else
				waiting[model] = true
			end
			continue
		end
		table.insert(candidates, { key = fire, distance = Context.distance(fire.base) })
	end
	local chosen: { [Fire]: boolean } = {}
	for _, fire in Logic.nearest(candidates, budget.ambientRadius, budget.campfires) do
		chosen[fire] = true
		if not fire.on then
			switchOn(fire)
		end
	end
	for _, fire in fires do
		if fire.on and not chosen[fire] then
			switchOff(fire, true)
		end
	end
end

local function found(instance: Instance)
	if isFlame(instance) and fires[instance :: Model] == nil then
		-- its parts stream in after it, so give them a moment; one with none yet waits for tick to try again
		task.defer(function()
			local model = instance :: Model
			if model.Parent ~= nil and fires[model] == nil then
				local fire = bind(model)
				if fire ~= nil then
					fires[model] = fire
				else
					waiting[model] = true
				end
			end
		end)
	end
end

function Campfire.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		for _, descendant in world:GetDescendants() do
			found(descendant)
		end
		world.DescendantAdded:Connect(found)
		while true do
			tick()
			task.wait(TICK_SECONDS)
		end
	end)
	RunService.PreRender:Connect(step)
end

return Campfire
