--!strict
-- The Rally board's marquee (F101, rescue-rally.md section 4: "a big Rally board by the cannon showing the bar";
-- Model-Agent's #759 offered its bulbs for a chase). While a Rescue Rally runs, the bulbs round the board's face
-- chase: every third one glows and the lit ones run round the frame, faster for a moment after each point anyone
-- scores. Each step of the bar flashes every bulb twice, the full bar three times in gold. The bulbs themselves are
-- never touched (WorldController lights them at night): this client lays a glowing cover over each lit one and, at
-- night, a dim cover over each unlit one so the chase reads against the glow. Only the nearest board within reach
-- runs; Reduce Motion and Low performance leave the bulbs as built. Rally.luau tells it when the Rally is on, each
-- point and each step.
--
-- Source: the Parts inside a Model in Workspace whose name has `RallyBoard` in it and ends `_Bulbs`
-- (`CatCafe_Square_RallyBoard_Bulbs`, 32 bulbs on the face, front -Z), ordered round the frame. Listening only.
-- Numbers in Presets.rallyBoard and the budget's rallyBoards.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local RallyBoard = {}

type Look = "lit" | "gold" | "dark" | "none"

type Board = {
	model: Model,
	bulbs: { BasePart }, -- round the frame, clockwise from the front
	covers: { Part },
	looks: { Look },
	pivot: CFrame, -- where the board stood when its covers were laid
	on: boolean,
}

local boards: { [Model]: Board } = {}
local active = false
local phase = 0
local burstUntil = 0
local flashFrom = -math.huge
local flashFull = false
local lastStep = os.clock()
local started = false

local function isBulbs(instance: Instance): boolean
	local name = instance.Name
	return instance:IsA("Model")
		and string.sub(name, -6) == "_Bulbs"
		and string.find(name, "RallyBoard", 1, true) ~= nil
end

local function consider(instance: Instance)
	if not isBulbs(instance) or boards[instance :: Model] ~= nil then
		return
	end
	local model = instance :: Model
	boards[model] =
		{ model = model, bulbs = {}, covers = {}, looks = {}, pivot = CFrame.new(), on = false }
end

-- The board's bulbs in order round its face: by their angle about the middle as you look at the front (-Z).
local function ordered(model: Model): { BasePart }
	local bulbs: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(bulbs, descendant :: BasePart)
		end
	end
	if #bulbs == 0 then
		return bulbs
	end
	local box = model:GetBoundingBox()
	local frame = CFrame.new(box.Position) * model:GetPivot().Rotation
	local angles: { [BasePart]: number } = {}
	for _, bulb in bulbs do
		local at = frame:PointToObjectSpace(bulb.Position)
		-- seen from the front the viewer's right is -X, so this angle falls going clockwise
		angles[bulb] = math.atan2(at.Y, -at.X)
	end
	table.sort(bulbs, function(a: BasePart, b: BasePart): boolean
		return angles[a] > angles[b]
	end)
	return bulbs
end

local function stopBoard(b: Board)
	for _, cover in b.covers do
		cover:Destroy()
	end
	table.clear(b.covers)
	table.clear(b.looks)
	table.clear(b.bulbs)
	b.on = false
end

local function startBoard(b: Board): boolean
	local o = Presets.rallyBoard
	local bulbs = ordered(b.model)
	if #bulbs == 0 then
		return false -- not streamed in yet
	end
	b.bulbs = bulbs
	b.pivot = b.model:GetPivot()
	for i, bulb in bulbs do
		local cover = Context.effectPart("EffectsRallyBulb", bulb.Size * o.grow, o.on)
		cover.CFrame = bulb.CFrame
		cover.Transparency = 1
		cover.Parent = Context.folder()
		b.covers[i] = cover
		b.looks[i] = "none"
	end
	b.on = true
	return true
end

local function show(b: Board, i: number, look: Look)
	local o = Presets.rallyBoard
	local cover: Part? = b.covers[i]
	if cover == nil then
		return
	end
	if look == "lit" or look == "gold" then
		cover.Material = Enum.Material.Neon
		cover.Color = if look == "gold" then o.full else o.on
		cover.Transparency = 0
	elseif look == "dark" then
		cover.Material = Enum.Material.SmoothPlastic
		cover.Color = o.off
		cover.Transparency = 0
	else
		cover.Transparency = 1
	end
	b.looks[i] = look
end

-- Placed again, or more of its bulbs streamed in since the covers were laid: lay them again.
local function stale(b: Board): boolean
	local now = b.model:GetPivot()
	if
		(now.Position - b.pivot.Position).Magnitude > 0.01
		or now.LookVector:Dot(b.pivot.LookVector) < 0.9999
	then
		return true
	end
	local count = 0
	for _, descendant in b.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count ~= #b.bulbs
end

local function pick()
	local o = Presets.rallyBoard
	local still = not active or Context.reducedMotion() or Context.budget.rallyBoards <= 0
	local candidates: { Logic.Candidate<Board> } = {}
	for model, b in boards do
		if not model:IsDescendantOf(Workspace) then
			stopBoard(b)
			boards[model] = nil
		elseif not still then
			table.insert(
				candidates,
				{ key = b, distance = Context.distance(model:GetPivot().Position) }
			)
		end
	end
	local chosen: { [Board]: boolean } = {}
	if not still then
		for _, b in Logic.nearest(candidates, o.within, Context.budget.rallyBoards) do
			chosen[b] = true
		end
	end
	for _, b in boards do
		if b.on and chosen[b] and stale(b) then
			stopBoard(b) -- lay the covers again where the bulbs are now, all of them
		end
		if chosen[b] and not b.on then
			startBoard(b)
		elseif b.on and not chosen[b] then
			stopBoard(b)
		end
	end
end

local function step()
	local o = Presets.rallyBoard
	local now = os.clock()
	local dt = now - lastStep
	lastStep = now
	phase += dt * (if now < burstUntil then o.burstHz else o.hz)
	local flash = Logic.marqueeFlash(
		now - flashFrom,
		if flashFull then o.fullFlashes else o.flashes,
		o.flashHz
	)
	local night = Context.isNight()
	local glow: Look = if flash ~= nil and flashFull then "gold" else "lit"
	for _, b in boards do
		if not b.on then
			continue
		end
		for i in b.covers do
			local lit = if flash ~= nil then flash else Logic.marqueeLit(i, phase, o.gap)
			local look: Look = if lit then glow elseif night then "dark" else "none"
			if look ~= b.looks[i] then
				show(b, i, look)
			end
		end
	end
end

-- Rally.luau: whether a Rally is running (RallyState's `active`).
function RallyBoard.setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	if not on then
		for _, b in boards do
			if b.on then
				stopBoard(b)
			end
		end
	end
end

-- Rally.luau: a point scored anywhere in the server; the chase runs faster for a moment.
function RallyBoard.point()
	burstUntil = os.clock() + Presets.rallyBoard.burstSeconds
end

-- Rally.luau: a step of the bar reached (1 the full bar); every bulb flashes.
function RallyBoard.flash(step: number)
	flashFrom = os.clock()
	flashFull = step >= 1
end

function RallyBoard.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.rallyBoard.pick)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return RallyBoard
