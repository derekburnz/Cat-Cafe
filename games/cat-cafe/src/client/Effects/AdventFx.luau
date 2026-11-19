--!strict
-- The advent calendar's board moments (#5502, advent-calendar-spec; server side shared/Advent and AdventService,
-- board CatCafe_Square_AdventBoard from Model-Agent). Each player sees their own board:
--   1. the doors they have opened stand open, swung out to the front about their hinge (the viewer's left edge);
--   2. the door a tap opens now (`ready`) breathes a soft gold glow, brighter and with sparkles when it is one of
--      the four calendar cat doors (6, 12, 18 and 24);
--   3. a door opened since the last sync swings open with a little overshoot, and snow and gold confetti burst from
--      its nook; a cat door also lights its nook gold for a few seconds with a ring and a column of light.
-- Locks: nothing shows unless the `adventCalendar` switch is on and the server's own view says `live` (both
-- switches and its UTC date past Dec 1 20:00), so the board stays shut until then whatever the client's clock says.
-- Display only: it never opens a door (OpenAdventDoor is the UI card's). Reduce Motion snaps the doors open and keeps
-- fewer particles; Low performance keeps the sparkles alone. Numbers in Presets.adventFx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local AdventFx = {}

export type View = { live: boolean, opened: number, ready: boolean }

local started = false
local board: Model? = nil
local lookedAt = -math.huge
local view: View = { live = false, opened = 0, ready = false }
local seen = false -- a first live view only sets the doors, with no swing
local closed: { [Instance]: CFrame? } = setmetatable({}, { __mode = "k" }) :: any -- each door's own CFrame, shut
local swinging: { [number]: number } = {} -- door number -> the clock its swing started
local glow: Highlight? = nil
local glowDoor = 0
local sparkle: ParticleEmitter? = nil

-- Pure: the view from a ProfileSync's `advent` field (nil or junk: not live).
function AdventFx.read(raw: unknown): View
	if type(raw) ~= "table" then
		return { live = false, opened = 0, ready = false }
	end
	local t = raw :: { [string]: unknown }
	local opened = if type(t.opened) == "number" and t.opened == t.opened
		then math.clamp(math.floor(t.opened :: number), 0, Presets.adventFx.doors)
		else 0
	return { live = t.live == true, opened = opened, ready = t.ready == true }
end

-- Pure: the doors opened between two views (`before` to `after`), in order; none when either is not live.
function AdventFx.newlyOpened(before: View, after: View): { number }
	local out = {}
	if not before.live or not after.live then
		return out
	end
	for n = before.opened + 1, after.opened do
		table.insert(out, n)
	end
	return out
end

-- Pure: the door a tap opens now, or 0.
function AdventFx.readyDoor(v: View): number
	if v.live and v.ready and v.opened < Presets.adventFx.doors then
		return v.opened + 1
	end
	return 0
end

function AdventFx.isCatDoor(n: number): boolean
	return table.find(Presets.adventFx.catDoors, n) ~= nil
end

-- Pure: how far open (0 shut, 1 fully) a swing is `t` seconds in, over `seconds`, with an `over` share of overshoot
-- that settles back.
function AdventFx.swing(t: number, seconds: number, over: number): number
	if seconds <= 0 or t >= seconds then
		return 1
	end
	if t <= 0 then
		return 0
	end
	local k = t / seconds
	-- ease out back: rises past 1 by about `over`, then settles to 1
	local s = over * 10
	local u = k - 1
	return 1 + (s + 1) * u * u * u + s * u * u
end

-- Pure: where the middle of a door `width` studs across moves to (x, z in its own shut frame) once swung `angle`
-- radians about its hinge on its own +X edge (the viewer's left), opening out to its front (-Z).
function AdventFx.hingeShift(width: number, angle: number): (number, number)
	local half = width / 2
	return half * (1 - math.cos(angle)), -half * math.sin(angle)
end

-- The CFrame of a door shut at `shut`, swung open `angle` radians (AdventFx.hingeShift).
function AdventFx.openFrame(shut: CFrame, width: number, angle: number): CFrame
	local x, z = AdventFx.hingeShift(width, angle)
	return shut * CFrame.new(x, 0, z) * CFrame.Angles(0, -angle, 0)
end

local function switchOn(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. Presets.adventFx.flag) == true
end

local function findBoard(): Model?
	if board ~= nil and board:IsDescendantOf(Workspace) then
		return board
	end
	board = nil
	local now = os.clock()
	if now - lookedAt < Presets.adventFx.lookSeconds then
		return nil
	end
	lookedAt = now
	local found = Workspace:FindFirstChild(Presets.adventFx.board, true)
	if found ~= nil and found:IsA("Model") then
		board = found :: Model
	end
	return board
end

local function doorOf(model: Model, n: number): BasePart?
	local found =
		model:FindFirstChild(string.format("%s_Door%02d", Presets.adventFx.board, n), true)
	if found == nil then
		found = model:FindFirstChild(string.format("Door%02d", n), true)
	end
	if found ~= nil and found:IsA("BasePart") then
		return found :: BasePart
	end
	return nil
end

local function nookOf(model: Model, n: number, door: BasePart): Vector3
	local prize = model:FindFirstChild(string.format("Prize%02d", n), true)
	if prize ~= nil and prize:IsA("Attachment") then
		return (prize :: Attachment).WorldPosition
	end
	return (closed[door] or door.CFrame).Position
end

-- Every door set to how open it should be now: shut, open, or partway through its swing.
local function place(model: Model)
	local p = Presets.adventFx
	local now = os.clock()
	for n = 1, p.doors do
		local door = doorOf(model, n)
		if door ~= nil then
			local shut = closed[door]
			if shut == nil then
				shut = door.CFrame
				closed[door] = shut
			end
			local amount = 0
			if view.live and n <= view.opened then
				local began = swinging[n]
				if began ~= nil then
					amount = AdventFx.swing(now - began, p.swingSeconds, p.overshoot)
					if now - began >= p.swingSeconds then
						swinging[n] = nil
					end
				else
					amount = 1
				end
			end
			local want = if amount == 0
				then shut :: CFrame
				else AdventFx.openFrame(shut :: CFrame, door.Size.X, p.openAngle * amount)
			if door.CFrame ~= want then
				door.CFrame = want
			end
		end
	end
end

local function setGlow(model: Model)
	local p = Presets.adventFx
	local n = AdventFx.readyDoor(view)
	local door = if n > 0 then doorOf(model, n) else nil
	if door == nil then
		n = 0
	end
	if n == glowDoor and (n == 0 or (glow ~= nil and glow.Adornee == door)) then
		return
	end
	glowDoor = n
	if sparkle ~= nil then
		sparkle:Destroy()
		sparkle = nil
	end
	if door == nil then
		if glow ~= nil then
			glow.Enabled = false
		end
		return
	end
	if glow == nil then
		local made = Instance.new("Highlight")
		made.Name = "EffectsAdventGlow"
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.FillColor = p.gold
		made.OutlineColor = p.gold
		made.Parent = Context.folder()
		glow = made
	end
	local h = glow :: Highlight
	h.Adornee = door
	h.Enabled = true
	if AdventFx.isCatDoor(n) and not Context.lowPerformance then
		sparkle = Particles.attach("catchSparkle", door)
	end
end

local function breathe()
	local h = glow
	if h == nil or not h.Enabled then
		return
	end
	local p = Presets.adventFx
	local cat = AdventFx.isCatDoor(glowDoor)
	local wave = if Context.reducedMotion()
		then 0.5
		else 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 / p.breathe)
	local low, high = p.fillLow, if cat then p.fillCat else p.fillHigh
	h.FillTransparency = 1 - (low + (high - low) * wave)
	h.OutlineTransparency = if cat then 0 else 0.4
end

local function burst(model: Model, n: number)
	local door = doorOf(model, n)
	if door == nil then
		return
	end
	local p = Presets.adventFx
	local at = nookOf(model, n, door)
	if Context.distance(at) > Context.budget.animRadius then
		return
	end
	local cat = AdventFx.isCatDoor(n)
	Particles.burst("catchSparkle", at, if cat then p.catSparkles else p.sparkles, p.gold)
	if Context.lowPerformance then
		return
	end
	Particles.burst("sigSnowflake", at, p.snow, nil)
	Particles.confetti(at, math.ceil(Context.budget.confetti * p.confetti), p.colours)
	if not cat then
		return
	end
	Particles.ring(at - Vector3.new(0, p.ringDrop, 0), p.gold, p.ring)
	Particles.beam(at, p.gold, p.beamWidth, p.beamHeight, p.catSeconds)
	local light = Instance.new("PointLight")
	light.Name = "EffectsAdventNook"
	light.Color = p.gold
	light.Brightness = p.lightBrightness
	light.Range = p.lightRange
	light.Parent = door
	task.delay(p.catSeconds, function()
		light:Destroy()
	end)
end

local function sync(raw: unknown)
	local after = AdventFx.read(raw)
	if not switchOn() then
		after = { live = false, opened = 0, ready = false }
	end
	local fresh: { number } = if seen then AdventFx.newlyOpened(view, after) else {}
	if after.live then
		seen = true
	end
	view = after
	local model = findBoard()
	if model == nil then
		return
	end
	local now = os.clock()
	for _, n in fresh do
		if not Context.reducedMotion() then
			swinging[n] = now
		end
		burst(model, n)
	end
	place(model)
	setGlow(model)
end

function AdventFx.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		sync((state :: { [string]: unknown }).advent)
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		if not view.live and next(swinging) == nil and glowDoor == 0 then
			return
		end
		local model = board
		if model == nil or not model:IsDescendantOf(Workspace) then
			return
		end
		breathe()
		local now = os.clock()
		-- every frame while a door swings, else once in a while for doors that streamed back in shut
		if next(swinging) ~= nil or now - last >= Presets.adventFx.lookSeconds then
			last = now
			place(model)
		end
	end)
end

return AdventFx
