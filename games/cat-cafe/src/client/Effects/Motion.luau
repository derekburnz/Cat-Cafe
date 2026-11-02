--!strict
-- Moving parts of rare decor (F89 2c, luck-and-rare-moments.md: a Legendary piece needs "a moving part and a light").
-- Model-Agent marks each moving part as a child Model named by how it moves (agreed 2026-11-01): `_Swing` swings side
-- to side about its pivot's Z axis with the pivot at the hook (the Blossom Tree's paper lanterns, a porch swing, wind
-- chimes), `_Spin` turns about its pivot's Y axis (a jukebox record, a little fan) and `_Bob` rides up and down along
-- its pivot's Y (a duck on fountain water). A light inside (a nested `_Glow` Model) rides along. Each starts at its
-- own point of its cycle, so two lanterns never swing in step, and its `Angle`, `Seconds` and `Rise` attributes
-- override the defaults. Only the nearest few within reach move; Reduce Motion and Low performance hold them all
-- still as modelled.
--
-- Source: the Models in Workspace (placed decor in a plot, or anywhere else) and their attributes. Every part in a
-- moving Model is anchored and not welded to the rest of the piece; one that is not is left alone. Numbers in
-- Presets.decorMotion and the budget's decorMotion. Only this client's copy moves.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Motion = {}

type Kind = "swing" | "spin" | "bob"

type Mover = {
	model: Model,
	kind: Kind,
	bound: boolean,
	base: CFrame, -- its pivot as modelled
	written: CFrame?, -- where this client last put it
	offset: number, -- 0 to 1: where in its cycle it started
	angle: number,
	seconds: number,
	rise: number,
	moving: boolean,
	changed: RBXScriptConnection?, -- its AttributeChanged hook, let go when it leaves Workspace
}

local movers: { [Model]: Mover } = {}
local moving: { Mover } = {}
local lastStep = 0
local rng = Random.new()
local started = false

local function kindOf(name: string): Kind?
	if string.sub(name, -6) == "_Swing" then
		return "swing"
	elseif string.sub(name, -5) == "_Spin" then
		return "spin"
	elseif string.sub(name, -4) == "_Bob" then
		return "bob"
	end
	return nil
end

local function anchored(model: Model): boolean
	local any = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not (descendant :: BasePart).Anchored then
				return false
			end
			any = true
		end
	end
	return any
end

-- Whether something else (the server placing or moving the piece) moved it since this client last put it.
local function movedOff(m: Mover): boolean
	local written = m.written
	if written == nil then
		return false
	end
	local now = m.model:GetPivot()
	return (now.Position - written.Position).Magnitude > 0.01
		or now.LookVector:Dot(written.LookVector) < 0.9999
end

-- Reads a moving part where it stands now, with its own numbers.
local function bind(m: Mover): boolean
	local model = m.model
	if not anchored(model) then
		return false -- welded to the piece, or not streamed in yet: moving it would drag the rest along
	end
	local d = Presets.decorMotion
	m.base = model:GetPivot()
	m.written = nil
	m.angle = Logic.motionNumber(
		model:GetAttribute("Angle"),
		d.angle.default,
		d.angle.least,
		d.angle.most
	)
	m.seconds = Logic.motionNumber(
		model:GetAttribute("Seconds"),
		d.seconds.default,
		d.seconds.least,
		d.seconds.most
	)
	m.rise =
		Logic.motionNumber(model:GetAttribute("Rise"), d.rise.default, d.rise.least, d.rise.most)
	m.bound = true
	return true
end

local function place(m: Mover, cframe: CFrame)
	m.model:PivotTo(cframe)
	m.written = cframe
end

local function rest(m: Mover)
	if m.moving then
		m.moving = false
		if m.model.Parent ~= nil and not movedOff(m) then
			place(m, m.base)
		else
			m.bound = false -- moved off: read it again where it is next time
		end
		m.written = nil
	end
end

-- Where a moving part goes `t` seconds in, from where it was modelled.
local function pose(m: Mover, t: number): CFrame
	if m.kind == "swing" then
		return m.base
			* CFrame.Angles(0, 0, math.rad(Logic.swingAngle(t, m.seconds, m.angle, m.offset)))
	elseif m.kind == "spin" then
		return m.base * CFrame.Angles(0, math.rad(Logic.spinAngle(t, m.seconds, m.offset)), 0)
	end
	return m.base * CFrame.new(0, Logic.bobRise(t, m.seconds, m.rise, m.offset), 0)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or movers[instance :: Model] ~= nil then
		return
	end
	local kind: Kind? = kindOf(instance.Name)
	if kind == nil then
		return
	end
	local model = instance :: Model
	movers[model] = {
		model = model,
		kind = kind :: Kind,
		bound = false,
		base = CFrame.new(),
		written = nil,
		offset = rng:NextNumber(),
		angle = 0,
		seconds = 1,
		rise = 0,
		moving = false,
		changed = nil,
	}
	-- a change to its numbers is read on its next pick
	movers[model].changed = model.AttributeChanged:Connect(function()
		local m = movers[model]
		if m ~= nil and m.bound then
			rest(m)
			m.bound = false
		end
	end)
end

-- Every `pick` seconds: the nearest budget.decorMotion within ambientRadius move; the rest stand as modelled.
local function pick()
	local budget = Context.budget
	local still = Context.reducedMotion() or budget.decorMotion <= 0
	local candidates: { Logic.Candidate<Mover> } = {}
	for model, m in movers do
		if not model:IsDescendantOf(Workspace) then
			local changed = m.changed
			if changed ~= nil then
				changed:Disconnect()
			end
			movers[model] = nil
		elseif not still then
			table.insert(
				candidates,
				{ key = m, distance = Context.distance(model:GetPivot().Position) }
			)
		end
	end
	local chosen: { Mover } = {}
	if not still then
		chosen = Logic.nearest(candidates, budget.ambientRadius, budget.decorMotion)
	end
	local on: { [Mover]: boolean } = {}
	local now: { Mover } = {}
	for _, m in chosen do
		if movedOff(m) then
			m.bound = false -- placed again or moved: read it again where it is
			m.written = nil
		end
		if m.bound or bind(m) then
			on[m] = true
			m.moving = true
			table.insert(now, m)
		end
	end
	for _, m in moving do
		if not on[m] then
			rest(m)
		end
	end
	moving = now
end

local function step()
	local now = os.clock()
	if now - lastStep < 1 / Context.budget.animHz then
		return
	end
	lastStep = now
	for _, m in moving do
		if m.moving and m.model.Parent ~= nil and not movedOff(m) then
			place(m, pose(m, now))
		end
	end
end

function Motion.start()
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
			task.wait(Presets.decorMotion.pick)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Motion
