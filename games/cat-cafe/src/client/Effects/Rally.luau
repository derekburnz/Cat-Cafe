--!strict
-- The Rescue Rally weekend (F101, rescue-rally.md section 4). On this player's screen, over UI-Engineer's banner bar
-- (the Frame named `RallyBar`): every point anyone in the server scores pops a "+N" up from just under the bar into
-- the end of its fill, and this player's own points fly a paw with its "+N" up from the bottom middle of the screen,
-- each landing with a small sparkle. Each step of the bar (25%, 50%, the full bar) runs sparkles along what is
-- filled, gold and twice as many for the full bar. In the world, the bunting (any Model or part ending `_Pennant`
-- inside a Model with `Bunting` in its name, or with it in its own name: the Town Square's Rally bunting, the Rally
-- Crate's cheer bunting placed in a cafe) flutters in the wind, a gust running across it the way the wind blows.
-- Reduce Motion stops the pops and the flutter and halves the step sparkles; the bar still fills (the UI's). The Rally board's marquee is RallyBoard.luau,
-- told here when the Rally is on, each point and each step.
--
-- Source: the server's `RallyState({ active, endsAt, lap, goal, points, myPoints, lapsPaid })` and
-- `RallyPoint(userId, amount)` to every client, hooked when they appear (they only exist once the server has F101).
-- Numbers in Presets.rally, Presets.bunting and the budget's rallyPops and pennants. Listening only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)
local RallyBoard = require(script.Parent.RallyBoard)
local ScreenFx = require(script.Parent.ScreenFx)

local Rally = {}

type Pennant = {
	target: Instance, -- the part or Model that swings
	bound: boolean,
	base: CFrame, -- where it was modelled (a Model's pivot)
	written: CFrame?, -- where this client last put it
	top: Vector3, -- the middle of its top edge, at `base`
	along: Vector3, -- the axis along its string, at `base`
	phase: number,
	side: number, -- 1 or -1: which way of its swing is downwind
	moving: boolean,
}

local GUI_NAME = "EffectsRally"

-- the bar as the server last said (for its steps) and as this client shows it (the server's points plus the pops
-- since, for where the fill ends)
local served = { known = false, active = false, lap = 0, fill = 0 }
local shown = { goal = 0, points = 0 }
local bar: GuiObject? = nil
local barLookedAt = -math.huge
local flying = 0
local pennants: { [Instance]: Pennant } = {}
local moving: { Pennant } = {}
local lastStep = 0
local rng = Random.new()
local started = false

-- The UI's bar track, looked for at most once a second while it is missing.
local function findBar(): GuiObject?
	local current = bar
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local now = os.clock()
	if now - barLookedAt < 1 then
		return nil
	end
	barLookedAt = now
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui ~= nil then playerGui:FindFirstChild("RallyBar", true) else nil
	if found ~= nil and found:IsA("GuiObject") then
		bar = found :: GuiObject
		return found :: GuiObject
	end
	return nil
end

-- Where the bar's fill ends now, in `gui`'s pixels.
local function fillEnd(gui: ScreenGui, track: GuiObject): Vector2
	local fill = Logic.rallyFill(shown.points, shown.goal)
	local size = track.AbsoluteSize
	return ScreenFx.toGui(gui, track.AbsolutePosition + Vector2.new(size.X * fill, size.Y / 2))
end

local function label(parent: Instance, amount: number): TextLabel
	local r = Presets.rally
	local text = Instance.new("TextLabel")
	text.Name = "Points"
	text.BackgroundTransparency = 1
	text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	text.Text = "+" .. tostring(amount)
	text.TextColor3 = r.text
	text.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = r.stroke
	stroke.Thickness = 2
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function pad(parent: Instance, x: number, y: number, w: number, h: number)
	local r = Presets.rally
	local frame = Instance.new("Frame")
	frame.Name = "Pad"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = r.paw
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = r.stroke
	stroke.Thickness = 2
	stroke.Parent = frame
	frame.Parent = parent
end

-- A "+N" alone, or this player's paw print with its "+N" beside it: a box that scales as one.
local function popFrame(gui: ScreenGui, amount: number, mine: boolean): (Frame, Vector2)
	local r = Presets.rally
	local holder = Instance.new("Frame")
	holder.Name = if mine then "RallyPaw" else "RallyPoint"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	local size: Vector2
	if mine then
		size = Vector2.new(r.ownSize * 2, r.ownSize)
		pad(holder, 0.25, 0.68, 0.3, 0.5) -- the big pad
		pad(holder, 0.11, 0.38, 0.1, 0.24) -- four toes
		pad(holder, 0.2, 0.17, 0.1, 0.24)
		pad(holder, 0.3, 0.17, 0.1, 0.24)
		pad(holder, 0.39, 0.38, 0.1, 0.24)
		local text = label(holder, amount)
		text.AnchorPoint = Vector2.new(0, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromScale(0.5, 0.7)
	else
		size = Vector2.new(r.textSize * 2.2, r.textSize * 1.2)
		local text = label(holder, amount)
		text.Size = UDim2.fromScale(1, 1)
	end
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = gui
	return holder, size
end

-- One point's pop flying into the bar.
local function pop(amount: number, mine: boolean)
	local r = Presets.rally
	if Context.reducedMotion() or flying >= Context.budget.rallyPops then
		return -- the rest are skipped: the bar still fills
	end
	local track = findBar()
	if track == nil or not ScreenFx.shown(track) then
		return
	end
	local gui = ScreenFx.gui(GUI_NAME, r.displayOrder)
	if gui == nil then
		return
	end
	local target = fillEnd(gui, track)
	local from = if mine
		then Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y * 0.78)
		else target + Vector2.new(
			rng:NextNumber(-r.spreadX, r.spreadX),
			track.AbsoluteSize.Y / 2 + rng:NextNumber(r.below[1], r.below[2])
		)
	local lift = rng:NextNumber(r.lift[1], r.lift[2]) * (if rng:NextNumber() < 0.5 then -1 else 1)
	local holder, size = popFrame(gui, amount, mine)
	flying += 1
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		local to = if track.Parent ~= nil then fillEnd(gui, track) else target
		-- the banner hides while a catch or a rescue shows (UI #827): a pop still flying stops where it is
		local gone = holder.Parent == nil or not ScreenFx.shown(track)
		if t >= r.seconds or gone then
			if loop ~= nil then
				loop:Disconnect()
			end
			holder:Destroy()
			flying -= 1
			if t >= r.seconds and not gone and gui.Parent ~= nil then
				local spots = table.create(r.arrive, to)
				ScreenFx.sparkle(
					gui,
					spots,
					r.sparkle,
					{ size = 9, seconds = 0.35, reach = 22, stagger = 0.05 }
				)
			end
			return
		end
		local at =
			Logic.curve(from, Logic.flyBend(from, to, lift), to, Logic.easeInOut(t / r.seconds))
		local k = Logic.popScale(t, r.seconds, r.popIn, r.land)
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		holder.Size = UDim2.fromOffset(size.X * k, size.Y * k)
	end)
end

-- A step of the bar reached: sparkles along what is filled, the full bar's in gold and twice as many.
local function stepped(step: number)
	local r = Presets.rally
	local track = findBar()
	if track == nil or not ScreenFx.shown(track) then
		return
	end
	local gui = ScreenFx.gui(GUI_NAME, r.displayOrder)
	if gui == nil then
		return
	end
	local full = step >= 1
	local count = Logic.pullCount(
		if full then r.stepSparkles * 2 else r.stepSparkles,
		Context.reducedMotion()
	)
	local left = ScreenFx.toGui(gui, track.AbsolutePosition)
	local size = track.AbsoluteSize
	local width = size.X * math.min(step, 1)
	local spots: { Vector2 } = {}
	for i = 1, count do
		table.insert(
			spots,
			left + Vector2.new(width * (i - 0.5) / count, size.Y * rng:NextNumber(0.2, 0.8))
		)
	end
	ScreenFx.sparkle(gui, spots, if full then r.full else r.sparkle, {
		size = 12,
		seconds = r.stepSeconds * 0.6,
		reach = size.Y * 1.2,
		stagger = r.stepSeconds * 0.4,
	})
end

local function onState(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p = payload :: { [string]: unknown }
	local active = p.active == true
	local lap = if type(p.lap) == "number" then p.lap else 0
	local goal = if type(p.goal) == "number" then p.goal else 0
	local points = if type(p.points) == "number" then p.points else 0
	local fill = Logic.rallyFill(points, goal)
	if served.known and served.active and active then
		for i, step in Logic.rallySteps(served.fill, served.lap, fill, lap, Presets.rally.steps) do
			task.delay((i - 1) * 0.35, stepped, step)
			task.delay((i - 1) * 0.35, RallyBoard.flash, step)
		end
	end
	RallyBoard.setActive(active)
	served.known, served.active, served.lap, served.fill = true, active, lap, fill
	shown.goal, shown.points = goal, points
end

local function onPoint(userId: unknown, amount: unknown)
	if type(amount) ~= "number" or amount <= 0 or not served.active then
		return
	end
	shown.points += amount
	pop(amount, userId == Players.LocalPlayer.UserId)
	RallyBoard.point()
end

-- Bunting ---------------------------------------------------------------------------------------------------------

-- A pennant counts when it or a Model holding it has `Bunting` in its name: a placed decor piece's model is renamed
-- to its decor id (CafeService), so the Cheer Bunting's flags carry it in their own names instead.
local function inBunting(instance: Instance): boolean
	if string.find(instance.Name, "Bunting", 1, true) ~= nil then
		return true
	end
	local world: Instance = Workspace
	local holder = instance.Parent
	while holder ~= nil and holder ~= world do
		if holder:IsA("Model") and string.find(holder.Name, "Bunting", 1, true) ~= nil then
			return true
		end
		holder = holder.Parent
	end
	return false
end

local function anchored(target: Instance): boolean
	if target:IsA("BasePart") then
		return (target :: BasePart).Anchored
	end
	local any = false
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not (descendant :: BasePart).Anchored then
				return false
			end
			any = true
		end
	end
	return any
end

local function cframeOf(target: Instance): CFrame
	if target:IsA("BasePart") then
		return (target :: BasePart).CFrame
	end
	return (target :: Model):GetPivot()
end

local function wind(): Vector3
	local blowing = Workspace.GlobalWind
	return if blowing.Magnitude > 0.05 then blowing else Presets.sky.wind
end

-- Reads a pennant as it hangs now: its hinge along the top edge and which way is downwind.
local function bind(p: Pennant): boolean
	local target = p.target
	if not anchored(target) then
		return false -- welded to the string: moving it would move the whole bunting
	end
	local box: CFrame, size: Vector3
	if target:IsA("BasePart") then
		local part = target :: BasePart
		box, size = part.CFrame, part.Size
	else
		box, size = (target :: Model):GetBoundingBox()
	end
	local along, up, half = Logic.pennantHinge(box.RightVector, box.UpVector, -box.LookVector, size)
	local blowing = wind()
	p.base = cframeOf(target)
	p.top = box.Position + up * half
	p.along = along
	p.phase = Logic.windPhase(box.Position, blowing, Presets.bunting.wavelength)
	p.side = if up:Cross(along):Dot(blowing) < 0 then -1 else 1
	p.written = nil
	p.bound = true
	return true
end

local function place(p: Pennant, cframe: CFrame)
	local target = p.target
	if target:IsA("BasePart") then
		(target :: BasePart).CFrame = cframe
	else
		(target :: Model):PivotTo(cframe)
	end
	p.written = cframe
end

-- Whether something else moved the pennant since this client last put it.
local function movedOff(p: Pennant): boolean
	local written = p.written
	if written == nil then
		return false
	end
	local now = cframeOf(p.target)
	return (now.Position - written.Position).Magnitude > 0.01
		or now.LookVector:Dot(written.LookVector) < 0.9999
end

local function rest(p: Pennant)
	if p.moving then
		p.moving = false
		if p.target.Parent ~= nil and not movedOff(p) then
			place(p, p.base)
		else
			p.bound = false -- moved off: read it again where it is next time
		end
		p.written = nil
	end
end

local function considerPennant(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) or pennants[instance] ~= nil then
		return
	end
	if string.sub(instance.Name, -8) ~= "_Pennant" or not inBunting(instance) then
		return
	end
	pennants[instance] = {
		target = instance,
		bound = false,
		base = CFrame.new(),
		written = nil,
		top = Vector3.zero,
		along = Vector3.xAxis,
		phase = 0,
		side = 1,
		moving = false,
	}
end

-- Every `pick` seconds: the nearest budget.pennants within ambientRadius flutter; the rest hang as modelled.
local function pickPennants()
	local budget = Context.budget
	local still = Context.reducedMotion() or budget.pennants <= 0
	local candidates: { Logic.Candidate<Pennant> } = {}
	for target, p in pennants do
		if not target:IsDescendantOf(Workspace) then
			pennants[target] = nil
		elseif not still then
			local at = Context.positionOf(target)
			if at ~= nil then
				table.insert(candidates, { key = p, distance = Context.distance(at) })
			end
		end
	end
	local chosen: { Pennant } = {}
	if not still then
		chosen = Logic.nearest(candidates, budget.ambientRadius, budget.pennants)
	end
	local on: { [Pennant]: boolean } = {}
	local now: { Pennant } = {}
	for _, p in chosen do
		if movedOff(p) then
			p.bound = false -- the server moved it: read it again where it is
			p.written = nil
		end
		if p.bound or bind(p) then
			on[p] = true
			p.moving = true
			table.insert(now, p)
		end
	end
	for _, p in moving do
		if not on[p] then
			rest(p)
		end
	end
	moving = now
end

local function flutter()
	local now = os.clock()
	if now - lastStep < 1 / Context.budget.animHz then
		return
	end
	lastStep = now
	local b = Presets.bunting
	for _, p in moving do
		if p.moving and p.target.Parent ~= nil and not movedOff(p) then
			local angle = math.rad(p.side * Logic.flutter(now, p.phase, b))
			local turn = CFrame.new(p.top)
				* CFrame.fromAxisAngle(p.along, angle)
				* CFrame.new(-p.top)
			place(p, turn * p.base)
		end
	end
end

function Rally.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("RallyState", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(onState)
	end)
	Context.whenRemote("RallyPoint", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(onPoint)
	end)
	for _, descendant in Workspace:GetDescendants() do
		considerPennant(descendant)
	end
	Workspace.DescendantAdded:Connect(considerPennant)
	RallyBoard.start()
	task.spawn(function()
		while true do
			pickPennants()
			task.wait(Presets.bunting.pick)
		end
	end)
	RunService.Heartbeat:Connect(flutter)
end

return Rally
