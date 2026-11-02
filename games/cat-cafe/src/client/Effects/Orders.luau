--!strict
-- Cats make the orders (F90, cats-make-orders.md section 2 step 2: "A puff at the station while it works: steam for a
-- drink, a flour puff and a warm glow from the oven door for a bake. At the end a "ding!" sparkle and sound, and the
-- item appears on the counter"). While a Barista makes an order, puffs rise at its station: steam off the espresso
-- machine, flour over the oven with its door window glowing warm and a light inside, a few cool twinkles at the
-- counter for the milk and the sundae. When the item appears a ding sparkle bursts over it with a ring round its
-- plate, in gold on the rich customer's gold-rimmed plate, and a bake's oven door swings open and shut with a waft of
-- steam. When the Waiter sets the dish on the table a few sparkles and a soft ring pop round the plate, under the
-- customer's heart. In your own cafe, when a Waiter or Greeter sweeps a tip pile into its coin bag gold coins hop up
-- off the table, and when it drops the bag in the till a gold burst and ring pop there. Your own cafe plays
-- everything; other cafes in range only on a PC or console, as section 4 asks. Reduce Motion keeps the door shut and
-- the glow steady.
--
-- Source: Gameplay-Engineer's `Moments.OrderMaking(plot, station, at, seconds)` when a Barista starts an order and
-- `Moments.OrderReady(plot, station, at, item)` when its item appears on the counter. `station` is "espresso", "oven"
-- or "counter"; `at` the plot's Espresso model, the oven (CatCafe_Cafe_Oven) or, at the counter, where the item goes
-- (a part, an attachment or the Barista); `item` the CatCafe_Menu_<Id> model, with `Rich = true` or the
-- CatCafe_Menu_GoldPlate inside it for the rich customer. Model-Agent's oven (#775) has the `DoorGlow` attachment on
-- its door window and the door as a `_Door` child Model pivoted on its bottom hinge. Listening only: the door moves
-- on this client and goes back where it was. Serving and tips: `Moments.OrderServed(customer, itemId, position)`
-- with the dish's spot on the table, and (your own cafe only) `Moments.TipSwept(cat, position)` at the pile and
-- `Moments.TipBanked(cat, position)` at the till (Gameplay-Engineer's CafeOrders, #781). Numbers in Presets.orders
-- and the budget's cafeOrders.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Orders = {}

type Oven = {
	model: Model,
	glow: Attachment?,
	window: BasePart?, -- the door window part by DoorGlow, which the cover follows as the door swings
	door: Model?,
	doorRest: CFrame?, -- the door's pivot in the oven's frame while it swings, to put it back
	cover: Part?,
	light: PointLight?,
	level: number,
	popAt: number?,
}

type Make = {
	plot: Model,
	station: string,
	at: Instance,
	own: boolean,
	endsAt: number,
	nextPuff: number,
	oven: Oven?,
}

local makes: { Make } = {}
local ovens: { [Model]: Oven } = {}
local started = false

local function isOwn(plot: Model): boolean
	local player = Players.LocalPlayer
	return player ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

local function othersPlaying(): number
	local n = 0
	for _, m in makes do
		if not m.own then
			n += 1
		end
	end
	return n
end

local function stationOf(value: unknown): string?
	if value == "espresso" or value == "oven" or value == "counter" then
		return value :: string
	end
	return nil
end

-- The middle of the top of a model or part, or the point itself.
local function topOf(instance: Instance): Vector3?
	if instance.Parent == nil then
		return nil
	end
	if instance:IsA("Model") then
		local frame, size = (instance :: Model):GetBoundingBox()
		return frame.Position + Vector3.new(0, size.Y / 2, 0)
	elseif instance:IsA("BasePart") then
		local part = instance :: BasePart
		return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
	end
	return Context.positionOf(instance)
end

-- Ovens ---------------------------------------------------------------------------------------------------------

local function findOven(model: Model): Oven
	local existing = ovens[model]
	if existing ~= nil then
		return existing
	end
	local o = Presets.orders.glow
	local found = model:FindFirstChild("DoorGlow", true)
	local glow: Attachment? = if found ~= nil and found:IsA("Attachment")
		then found :: Attachment
		else nil
	local door: Model? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and string.sub(descendant.Name, -5) == "_Door" then
			door = descendant :: Model
			break
		end
	end
	local window: BasePart? = nil
	if glow ~= nil then
		local best = o.reach
		local from = glow.WorldPosition
		for _, descendant in (door or model):GetDescendants() do
			if descendant:IsA("BasePart") then
				local d = ((descendant :: BasePart).Position - from).Magnitude
				if d < best then
					best = d
					window = descendant :: BasePart
				end
			end
		end
	end
	local oven: Oven = { model = model, glow = glow, window = window, door = door, level = 0 }
	ovens[model] = oven
	return oven
end

-- Where the window's cover goes now: just proud of the window part's front (-Z), or of DoorGlow with no window.
local function coverFrame(oven: Oven): (CFrame?, Vector3)
	local o = Presets.orders.glow
	local window = oven.window
	if window ~= nil and window.Parent ~= nil then
		local size = window.Size
		return window.CFrame * CFrame.new(0, 0, -(size.Z / 2 + o.pad)),
			Vector3.new(size.X + o.margin * 2, size.Y + o.margin * 2, o.thick)
	end
	local glow = oven.glow
	if glow ~= nil and glow.Parent ~= nil then
		return glow.WorldCFrame * CFrame.new(0, 0, -o.pad),
			Vector3.new(o.window.X, o.window.Y, o.thick)
	end
	return nil, Vector3.zero
end

local function dropCover(oven: Oven)
	local cover = oven.cover
	if cover ~= nil then
		cover:Destroy()
	end
	oven.cover = nil
	oven.light = nil
end

local function restDoor(oven: Oven)
	local door, rest = oven.door, oven.doorRest
	if door ~= nil and rest ~= nil and door.Parent ~= nil and oven.model.Parent ~= nil then
		door:PivotTo(oven.model:GetPivot() * rest)
	end
	oven.doorRest = nil
	oven.popAt = nil
end

local function forget(oven: Oven)
	restDoor(oven)
	dropCover(oven)
	ovens[oven.model] = nil
end

local function baking(oven: Oven): boolean
	for _, m in makes do
		if m.oven == oven then
			return true
		end
	end
	return false
end

local function stepOven(oven: Oven, now: number, dt: number)
	local o = Presets.orders.glow
	-- the door first, so the cover follows the window where it is this frame
	local popAt = oven.popAt
	if popAt ~= nil then
		local door, rest = oven.door, oven.doorRest
		local t = now - popAt
		if
			door ~= nil
			and rest ~= nil
			and door.Parent ~= nil
			and t < Logic.keyedSeconds(Presets.orders.door)
		then
			local degrees = Logic.keyed(Presets.orders.door, t)
			door:PivotTo(oven.model:GetPivot() * rest * CFrame.Angles(math.rad(degrees), 0, 0))
		else
			restDoor(oven)
		end
	end
	oven.level = Logic.glowStep(oven.level, baking(oven), dt, o.rise, o.fade)
	if oven.level <= 0 then
		dropCover(oven)
		return
	end
	local frame, size = coverFrame(oven)
	if frame == nil then
		dropCover(oven)
		return
	end
	local cover: Part
	local existing = oven.cover
	if existing ~= nil then
		cover = existing
	else
		local made = Context.effectPart("EffectsOvenGlow", size, o.colour)
		made.Material = Enum.Material.Neon
		made.Transparency = 1
		if not Context.lowPerformance then
			local light = Instance.new("PointLight")
			light.Color = o.light
			light.Range = o.range
			light.Brightness = 0
			light.Shadows = false
			light.Parent = made
			oven.light = light
		end
		made.Parent = Context.folder()
		oven.cover = made
		cover = made
	end
	local shown = if Context.reducedMotion()
		then oven.level
		else Logic.glowFlicker(oven.level, now, o.flicker, o.hz)
	cover.Size = size
	cover.CFrame = frame
	cover.Transparency = 1 - math.min(1, shown) * (1 - o.transparency)
	local light = oven.light
	if light ~= nil then
		light.Brightness = o.brightness * shown * (if Context.isNight() then o.night else 1)
	end
end

-- The door swings open and shut (from the start again if it was still swinging), with a waft of steam out of it.
local function popDoor(oven: Oven)
	local door = oven.door
	if door == nil or door.Parent == nil or Context.reducedMotion() then
		return
	end
	if oven.doorRest == nil then
		oven.doorRest = oven.model:GetPivot():ToObjectSpace(door:GetPivot())
	end
	oven.popAt = os.clock()
	local glow = oven.glow
	if glow ~= nil and glow.Parent ~= nil then
		local front = oven.model:GetPivot().LookVector
		Particles.burst("orderSteam", glow.WorldPosition + front * 0.6, Presets.orders.waft)
	end
end

-- Puffs -----------------------------------------------------------------------------------------------------------

local function steamPoint(at: Instance): Vector3?
	local points: { Vector3 } = {}
	for _, descendant in at:GetDescendants() do
		if string.sub(descendant.Name, -6) == "_Steam" then
			local p = Context.positionOf(descendant)
			if p ~= nil then
				table.insert(points, p)
			end
		end
	end
	if #points > 0 then
		local chosen: Vector3? = points[math.random(1, #points)]
		return chosen
	end
	local top = topOf(at)
	return if top ~= nil then top + Vector3.new(0, Presets.orders.steam.rise, 0) else nil
end

local function flourPoint(at: Instance): Vector3?
	local f = Presets.orders.flour
	if at:IsA("Model") and at.Parent ~= nil then
		local model = at :: Model
		local frame, size = model:GetBoundingBox()
		return frame.Position
			+ Vector3.new(0, size.Y / 2 + f.above, 0)
			+ model:GetPivot().LookVector * f.forward
	end
	local top = topOf(at)
	return if top ~= nil then top + Vector3.new(0, f.above, 0) else nil
end

local function puff(m: Make)
	local o = Presets.orders
	if m.station == "espresso" then
		local p = steamPoint(m.at)
		if p ~= nil then
			Particles.burst("orderSteam", p, o.steam.count)
		end
	elseif m.station == "oven" then
		local p = flourPoint(m.at)
		if p ~= nil then
			Particles.burst("flourPuff", p, o.flour.count)
		end
	else
		local p = Context.positionOf(m.at)
		if p ~= nil then
			Particles.burst(
				"counterTwinkle",
				p + Vector3.new(0, o.counter.above, 0),
				o.counter.count
			)
		end
	end
end

local function everyOf(station: string): number
	local o = Presets.orders
	return if station == "espresso"
		then o.steam.every
		elseif station == "oven" then o.flour.every
		else o.counter.every
end

local function step(dt: number)
	local now = os.clock()
	local grace = Presets.orders.grace
	local i = 1
	while i <= #makes do
		local m: Make? = makes[i]
		if m == nil then
			break
		end
		if m.plot.Parent == nil or m.at.Parent == nil or now > m.endsAt + grace then
			table.remove(makes, i)
			continue
		end
		if now < m.endsAt and now >= m.nextPuff then
			m.nextPuff = now + everyOf(m.station)
			puff(m)
		end
		i += 1
	end
	for model, oven in ovens do
		if not model:IsDescendantOf(Workspace) then
			forget(oven)
		else
			stepOven(oven, now, dt)
		end
	end
end

-- Moments ---------------------------------------------------------------------------------------------------------

local function making(plot: unknown, station: unknown, at: unknown, seconds: unknown)
	local kind = stationOf(station)
	if typeof(plot) ~= "Instance" or not (plot :: Instance):IsA("Model") or kind == nil then
		return
	end
	if typeof(at) ~= "Instance" or type(seconds) ~= "number" or seconds <= 0 then
		return
	end
	local cafe = plot :: Model
	local spot = at :: Instance
	local where = Context.positionOf(spot)
	if where == nil then
		return
	end
	local own = isOwn(cafe)
	local o = Presets.orders
	if
		not Logic.orderPlays(
			own,
			Context.distance(where),
			o.within,
			othersPlaying(),
			Context.budget.cafeOrders
		)
	then
		return
	end
	local now = os.clock()
	local oven: Oven? = if kind == "oven" and spot:IsA("Model")
		then findOven(spot :: Model)
		else nil
	table.insert(makes, {
		plot = cafe,
		station = kind,
		at = spot,
		own = own,
		endsAt = now + seconds,
		nextPuff = now,
		oven = oven,
	})
end

local function ready(plot: unknown, station: unknown, at: unknown, item: unknown)
	local kind = stationOf(station)
	if typeof(plot) ~= "Instance" or not (plot :: Instance):IsA("Model") or kind == nil then
		return
	end
	local cafe = plot :: Model
	local spot: Instance? = if typeof(at) == "Instance" then at :: Instance else nil
	-- this order's make is over: the earliest one at the same station
	local earliest: number? = nil
	for i, m in makes do
		if m.plot == cafe and m.station == kind and (spot == nil or m.at == spot) then
			local best: Make? = if earliest ~= nil then makes[earliest] else nil
			if best == nil or m.endsAt < best.endsAt then
				earliest = i
			end
		end
	end
	if earliest ~= nil then
		table.remove(makes, earliest)
	end
	local piece: Instance? = if typeof(item) == "Instance"
			and (item :: Instance):IsDescendantOf(Workspace)
		then item :: Instance
		else nil
	local top = if piece ~= nil then topOf(piece) elseif spot ~= nil then topOf(spot) else nil
	if top == nil then
		return
	end
	local o = Presets.orders
	if
		not Logic.orderPlays(
			isOwn(cafe),
			Context.distance(top),
			o.within,
			0,
			Context.budget.cafeOrders
		)
	then
		return
	end
	local d = o.ding
	local rich = piece ~= nil
		and (
			piece:GetAttribute("Rich") == true
			or piece:FindFirstChild("CatCafe_Menu_GoldPlate", true) ~= nil
		)
	if rich then
		Particles.burst("dingSparkle", top + Vector3.new(0, d.above, 0), d.goldSparkles, d.gold)
	else
		Particles.burst("dingSparkle", top + Vector3.new(0, d.above, 0), d.sparkles)
	end
	local base = if piece ~= nil and piece:IsA("Model")
		then (piece :: Model):GetPivot().Position
		else top
	Particles.ring(
		base + Vector3.new(0, 0.05, 0),
		if rich then d.gold else d.colour,
		d.ring,
		d.ringSeconds
	)
	if kind == "oven" and spot ~= nil and spot:IsA("Model") then
		popDoor(findOven(spot :: Model))
	end
end

-- Serving and tips (F90 section 2 steps 3 and 5) ---------------------------------------------------------------

-- Whether `at` is in this player's own cafe: within `plotReach` studs of the pivot of a Plot they own.
local function inOwnCafe(at: Vector3): boolean
	local player = Players.LocalPlayer
	if player == nil then
		return false
	end
	local reach = Presets.orders.plotReach
	for _, plot in CollectionService:GetTagged("Plot") do
		if
			plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId
			and ((plot :: Model):GetPivot().Position - at).Magnitude <= reach
		then
			return true
		end
	end
	return false
end

-- Moments.OrderServed: the dish set down on the customer's table, as the heart pops.
local function served(_customer: unknown, _itemId: unknown, position: unknown)
	if typeof(position) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local o = Presets.orders
	if
		not Logic.orderPlays(
			inOwnCafe(at),
			Context.distance(at),
			o.within,
			0,
			Context.budget.cafeOrders
		)
	then
		return
	end
	local s = o.served
	Particles.burst("dingSparkle", at + Vector3.new(0, s.above, 0), s.sparkles)
	Particles.ring(at + Vector3.new(0, 0.05, 0), s.colour, s.ring, s.ringSeconds)
end

-- Moments.TipSwept (your own cafe): coins hop up off the table as the pile goes into the bag.
local function swept(_cat: unknown, position: unknown)
	if typeof(position) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local o = Presets.orders
	if Context.distance(at) > o.within then
		return
	end
	Particles.burst("coinGlint", at + Vector3.new(0, o.sweep.above, 0), o.sweep.coins)
	Particles.burst("dust", at, o.sweep.dust)
end

-- Moments.TipBanked (your own cafe): the bag lands in the till with a gold burst and a ring.
local function banked(_cat: unknown, position: unknown)
	if typeof(position) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local o = Presets.orders
	if Context.distance(at) > o.within then
		return
	end
	local b = o.bank
	Particles.burst("coinGlint", at + Vector3.new(0, b.above, 0), b.coins)
	Particles.burst("dingSparkle", at + Vector3.new(0, b.above, 0), b.sparkles, b.colour)
	Particles.ring(at + Vector3.new(0, 0.05, 0), b.colour, b.ring, b.ringSeconds)
end

function Orders.start()
	if started then
		return
	end
	started = true
	local onMaking = (Moments :: any).OrderMaking -- F90, Gameplay-Engineer's CustomerController
	if onMaking ~= nil then
		onMaking:Connect(making)
	end
	local onReady = (Moments :: any).OrderReady
	if onReady ~= nil then
		onReady:Connect(ready)
	end
	local onServed = (Moments :: any).OrderServed
	if onServed ~= nil then
		onServed:Connect(served)
	end
	local onSwept = (Moments :: any).TipSwept
	if onSwept ~= nil then
		onSwept:Connect(swept)
	end
	local onBanked = (Moments :: any).TipBanked
	if onBanked ~= nil then
		onBanked:Connect(banked)
	end
	RunService.Heartbeat:Connect(step)
end

return Orders
