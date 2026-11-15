--!strict
-- #4197: what the admin events drop into the world, drawn so it reads as arriving. The server's AdminDropService
-- puts each thing where it ends up, in Workspace.AdminDrops; this hides it on this client only until a stand-in made
-- here has flown in, then shows it.
--   Fish Fountain: a Part with AdminFish = true and From (the Town Square plinth's centre). A gold blob arcs from
--     From to the fish in Presets.adminDrops.fish.seconds, then a few glints where it lands.
--   Crate Drop: a Model with AdminCrate = true and LandsAt (server time). A box under a parachute comes down on the
--     crate's spot, swaying a little, and touches the ground at LandsAt; then a ring and a puff. The server takes no
--     touch before LandsAt, so nothing can be grabbed while only the stand-in shows.
-- Only drops within `within` studs get a stand-in; the rest just appear. Reduce Motion: no arc and no sway (the
-- chute comes straight down). Low performance: nothing here, the things just appear. A thing's parts can arrive
-- after it does (Review-QA, #4211), so the hide follows DescendantAdded until the landing.
-- Listening only: it sends nothing and changes nothing the server reads. Numbers in Presets.adminDrops.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local AdminDrops = {}

AdminDrops.FOLDER = "AdminDrops"

type Flight = { step: (now: number) -> boolean } -- false once it is over

local started = false
local flights: { Flight } = {}
local stepping: RBXScriptConnection? = nil

-- A point on the fish's arc: straight from `from` to `to` with a hump `rise` studs high in the middle. t 0 to 1.
function AdminDrops.arc(
	fromX: number,
	fromY: number,
	fromZ: number,
	toX: number,
	toY: number,
	toZ: number,
	t: number,
	rise: number
): (number, number, number)
	local k = math.clamp(t, 0, 1)
	return fromX + (toX - fromX) * k,
		fromY + (toY - fromY) * k + 4 * rise * k * (1 - k),
		fromZ + (toZ - fromZ) * k
end

-- How high over its spot the chute's box hangs with `left` seconds to go: `height` at `seconds` or more, 0 at the
-- landing, slowing a little as it nears the ground.
function AdminDrops.hang(left: number, seconds: number, height: number): number
	if seconds <= 0 then
		return 0
	end
	local k = math.clamp(left / seconds, 0, 1)
	return height * k * (0.6 + 0.4 * k)
end

-- The chute's lean in degrees at `t` seconds: a slow swing, none with Reduce Motion.
function AdminDrops.sway(t: number, degrees: number, period: number, still: boolean): number
	if still or period <= 0 then
		return 0
	end
	return degrees * math.sin(t / period * 2 * math.pi)
end

-- What a drop gets: its stand-in ("fly"), or nothing but to appear ("show").
function AdminDrops.plan(distance: number, within: number, low: boolean): "fly" | "show"
	return if low or distance > within then "show" else "fly"
end

local function run(flight: Flight)
	table.insert(flights, flight)
	if stepping ~= nil then
		return
	end
	stepping = RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for i = #flights, 1, -1 do
			if not flights[i].step(now) then
				table.remove(flights, i)
			end
		end
		if #flights == 0 and stepping ~= nil then
			stepping:Disconnect()
			stepping = nil
		end
	end)
end

-- Hides `thing` (a part or a model) on this client until the returned function is called.
local function hide(thing: Instance): () -> ()
	local hidden: { Instance } = {}
	local function take(d: Instance)
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 1
			table.insert(hidden, d)
		end
	end
	local added = thing.DescendantAdded:Connect(take)
	take(thing)
	for _, d in thing:GetDescendants() do
		take(d)
	end
	return function()
		added:Disconnect()
		for _, d in hidden do
			(d :: any).LocalTransparencyModifier = 0
		end
	end
end

local function fish(part: BasePart)
	local p = Presets.adminDrops
	local from = part:GetAttribute("From")
	local to = part.Position
	if
		typeof(from) ~= "Vector3"
		or Context.reducedMotion()
		or AdminDrops.plan(Context.distance(to), p.within, Context.lowPerformance) == "show"
	then
		return
	end
	local origin = from :: Vector3
	local show = hide(part)
	local blob = Context.effectPart("EffectsAdminFish", p.fish.blob, p.fish.colour)
	blob.Shape = Enum.PartType.Ball
	blob.Material = Enum.Material.Neon
	blob.CFrame = CFrame.new(origin)
	blob.Parent = Context.folder()
	local startedAt = Workspace:GetServerTimeNow()
	run({
		step = function(now: number): boolean
			local t = (now - startedAt) / p.fish.seconds
			if t < 1 and part.Parent ~= nil then
				local x, y, z =
					AdminDrops.arc(origin.X, origin.Y, origin.Z, to.X, to.Y, to.Z, t, p.fish.rise)
				blob.CFrame = CFrame.new(x, y, z)
				return true
			end
			blob:Destroy()
			show()
			if part.Parent ~= nil then
				Particles.burst(p.fish.splash, to, p.fish.splashCount)
			end
			return false
		end,
	})
end

local function crate(model: Model)
	local p = Presets.adminDrops
	local landsAt = model:GetAttribute("LandsAt")
	if type(landsAt) ~= "number" then
		return
	end
	local lands = landsAt :: number
	local left = lands - Workspace:GetServerTimeNow()
	local at = model:GetPivot().Position
	if
		left <= 0.2
		or AdminDrops.plan(Context.distance(at), p.within, Context.lowPerformance) == "show"
	then
		return
	end
	local c = p.crate
	local still = Context.reducedMotion()
	local show = hide(model)
	local box = Context.effectPart("EffectsAdminCrate", c.box, c.colour)
	local canopy = Context.effectPart("EffectsAdminChute", c.canopy, c.canopyColour)
	canopy.Shape = Enum.PartType.Ball
	local cords: { Part } = {}
	for i = 1, 2 do
		local cord =
			Context.effectPart("EffectsAdminCord", Vector3.new(0.15, c.cord, 0.15), c.cordColour)
		cords[i] = cord
	end
	local function place(now: number)
		local height = AdminDrops.hang(lands - now, c.seconds, c.height)
		local lean = math.rad(AdminDrops.sway(now, c.swayDegrees, c.swaySeconds, still))
		-- swing about the canopy, so the box swings under it
		local top = CFrame.new(at + Vector3.new(0, height + c.cord + c.box.Y, 0))
			* CFrame.Angles(0, 0, lean)
		canopy.CFrame = top
		box.CFrame = top * CFrame.new(0, -(c.cord + c.box.Y / 2), 0)
		for i, cord in cords do
			local side = if i == 1 then -1 else 1
			cord.CFrame = top
				* CFrame.new(side * c.box.X * 0.35, -c.cord / 2, 0)
				* CFrame.Angles(0, 0, side * math.rad(12))
		end
	end
	place(Workspace:GetServerTimeNow())
	box.Parent = Context.folder()
	canopy.Parent = Context.folder()
	for _, cord in cords do
		cord.Parent = Context.folder()
	end
	run({
		step = function(now: number): boolean
			if now < lands and model.Parent ~= nil then
				place(now)
				return true
			end
			box:Destroy()
			canopy:Destroy()
			for _, cord in cords do
				cord:Destroy()
			end
			show()
			if model.Parent ~= nil then
				Particles.ring(at + Vector3.new(0, 0.1, 0), c.canopyColour, c.ring, c.ringSeconds)
				Particles.burst(c.puff, at + Vector3.new(0, 0.5, 0), c.puffCount)
			end
			return false
		end,
	})
end

local function consider(instance: Instance)
	if instance:IsA("BasePart") and instance:GetAttribute("AdminFish") == true then
		fish(instance :: BasePart)
	elseif instance:IsA("Model") and instance:GetAttribute("AdminCrate") == true then
		crate(instance :: Model)
	end
end

local function watch(folder: Instance)
	folder.ChildAdded:Connect(function(child: Instance)
		-- its attributes come with it, its parts may not: a frame is enough for the pivot to be right
		task.defer(consider, child)
	end)
end

function AdminDrops.start()
	if started then
		return
	end
	started = true
	-- things already lying there when you join did not just arrive
	local folder = Workspace:FindFirstChild(AdminDrops.FOLDER)
	if folder ~= nil then
		watch(folder)
		return
	end
	local waiting: RBXScriptConnection? = nil
	waiting = Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == AdminDrops.FOLDER then
			if waiting ~= nil then
				waiting:Disconnect()
				waiting = nil
			end
			for _, thing in child:GetChildren() do
				task.defer(consider, thing)
			end
			watch(child)
		end
	end)
end

return AdminDrops
