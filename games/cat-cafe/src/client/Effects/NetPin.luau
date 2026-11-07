--!strict
-- The net pins the cat (#2005 section 1, Derek2 2026-11-07: "when you start catching the cat with a successful swing
-- your net stays on top of the cat"): while a stray carries the server's `NetDown` (Gameplay-Engineer, #2025), every
-- client draws the catcher's net over it, upside down with its hoop on the floor round the stray's pivot and its bag
-- over the cat, the handle lying back toward the catcher (`LockedBy`). It drops in from above
-- (Presets.netPin.drop), stays put while the catch runs, and when `NetDown` clears it lifts off and fades
-- (Presets.netPin.lift). The net is the catcher's own level (CatCafe_Item_Net_L1 to L4 by their `NetLevel`, as in
-- the hand), scaled so its hoop rings the cat's box and its bag clears the cat's back. The catcher's hand net is put
-- away while theirs is down (NetHold asks `NetPin.pinning`), and the catch finish wobbles this net
-- (`NetPin.wobble`, from CatchReact) instead of the older closing ball. Reduce Motion: no drop, rise or wobble; it
-- appears and goes. Local copies that nothing collides with; nothing here fires a remote or moves the stray.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local NetPin = {}

type Pin = {
	stray: Model,
	net: Model,
	offset: CFrame, -- from the hoop's centre on the floor to the net's pivot (flipped, bag up)
	lift: number, -- studs from the floor's hoop centre to the hoop ring's middle, so the ring sits on the floor
	parts: { BasePart },
	base: { number }, -- each part's own transparency
	catcher: number?,
	downAt: number,
	liftAt: number?,
	wobbleAt: number?,
	last: CFrame?, -- the last floor frame, for a net still lifting after its stray has gone
}

local pins: { [Model]: Pin } = {}
local watched: { [Model]: RBXScriptConnection } = {}
local stepping: RBXScriptConnection? = nil
local started = false

local function template(level: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	for n = level, 1, -1 do
		local found = assets:FindFirstChild("CatCafe_Item_Net_L" .. n)
		if found ~= nil and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

local function netLevelOf(userId: number?): number
	local player = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	local level: unknown = nil
	if player ~= nil then
		local character = player.Character
		level = if character ~= nil then character:GetAttribute("NetLevel") else nil
		if level == nil then
			level = player:GetAttribute("NetLevel")
		end
	end
	return Avatar.netModel(level)
end

local function partsOf(root: Instance?): { BasePart }
	local parts: { BasePart } = {}
	if root == nil then
		return parts
	end
	if root:IsA("BasePart") then
		table.insert(parts, root :: BasePart)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

-- In the net's pivot space: the hoop's centre, its radius across the hoop's plane, how far the bag hangs below the
-- hoop (pivot -y) and the hoop ring's half thickness. A net with no Hoop or Bag model falls back to the box.
local function measure(net: Model): (Vector3, number, number, number)
	local pivot = net:GetPivot()
	local hoop = partsOf(net:FindFirstChild(net.Name .. "_Hoop"))
	local bag = partsOf(net:FindFirstChild(net.Name .. "_Bag"))
	if #hoop == 0 then
		local frame, size = net:GetBoundingBox()
		return pivot:PointToObjectSpace(frame.Position), math.max(size.X, size.Z) / 2, size.Y / 2, 0
	end
	local sum = Vector3.zero
	for _, part in hoop do
		sum += pivot:PointToObjectSpace(part.Position)
	end
	local centre = sum / #hoop
	local radius, thick = 0, 0
	for _, part in hoop do
		local at = pivot:PointToObjectSpace(part.Position) - centre
		radius = math.max(radius, Vector3.new(at.X, 0, at.Z).Magnitude)
		thick = math.max(thick, math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2)
	end
	local depth = 0
	for _, part in bag do
		local at = pivot:PointToObjectSpace(part.Position)
		depth =
			math.max(depth, centre.Y - at.Y + math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2)
	end
	return centre, radius, depth, thick
end

local function drop(pin: Pin)
	pins[pin.stray] = nil
	pin.net:Destroy()
end

-- The hoop's centre on the floor under the stray's pivot, facing so the handle lies back toward the catcher.
local function floorFrame(pin: Pin): CFrame?
	local stray = pin.stray
	if stray.Parent == nil or pin.liftAt ~= nil and pin.last ~= nil then
		return nil
	end
	local frame, size = stray:GetBoundingBox()
	local pivot = stray:GetPivot()
	local at = Vector3.new(pivot.Position.X, frame.Position.Y - size.Y / 2, pivot.Position.Z)
	local toward: Vector3? = nil
	local player = if pin.catcher ~= nil then Players:GetPlayerByUserId(pin.catcher) else nil
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		local flat = (root :: BasePart).Position - at
		flat = Vector3.new(flat.X, 0, flat.Z)
		if flat.Magnitude > 1e-3 then
			toward = flat.Unit
		end
	end
	if toward == nil then
		local look = pivot.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		toward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	end
	-- +z of this frame points at the catcher, where the flipped net's handle lies
	return CFrame.lookAt(at, at - (toward :: Vector3))
end

local function make(stray: Model): Pin?
	local catcher = stray:GetAttribute("LockedBy")
	local userId = if type(catcher) == "number" and catcher ~= 0 then catcher else nil
	local source = template(netLevelOf(userId))
	if source == nil then
		return nil
	end
	local net = source:Clone() :: Model
	local parts = partsOf(net)
	local base: { number } = {}
	for i, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		base[i] = part.Transparency
	end
	-- big enough that the hoop rings the cat's box and the bag clears its back
	local p = Presets.netPin
	local _, catSize = stray:GetBoundingBox()
	local _, radius, depth = measure(net)
	local reach = Vector3.new(catSize.X, 0, catSize.Z).Magnitude / 2
	local scale = math.clamp(
		math.max(
			reach * p.ring / math.max(radius, 1e-3),
			catSize.Y * p.cover / math.max(depth, 1e-3),
			1
		),
		1,
		p.maxScale
	)
	net:ScaleTo(net:GetScale() * scale)
	local centre, _, _, thick = measure(net)
	net.Parent = Context.folder()
	return {
		stray = stray,
		net = net,
		offset = CFrame.Angles(0, 0, math.pi) * CFrame.new(-centre),
		lift = thick,
		parts = parts,
		base = base,
		catcher = userId,
		downAt = os.clock(),
		liftAt = nil,
		wobbleAt = nil,
		last = nil,
	}
end

local function fade(pin: Pin, amount: number)
	for i, part in pin.parts do
		local own = pin.base[i]
		part.Transparency = own + (1 - own) * amount
	end
end

local function step()
	local now = os.clock()
	local still = Context.reducedMotion()
	local w = Presets.catchReact.wrap
	for _, pin in pins do
		local floor = floorFrame(pin) or pin.last
		if floor == nil then
			drop(pin)
			continue
		end
		pin.last = floor
		local rise, gone, done = 0, 0, false
		local liftAt = pin.liftAt
		if liftAt ~= nil and pin.wobbleAt ~= nil then
			liftAt = math.max(liftAt, pin.wobbleAt + w.seconds) -- the finish wobble plays out before it lifts
		end
		if liftAt ~= nil then
			rise, gone, done = Logic.netLift(now - liftAt)
			if still then
				rise = 0
			end
		elseif not still then
			rise = Logic.netDrop(now - pin.downAt)
		end
		if done then
			drop(pin)
			continue
		end
		local rock = 0
		if pin.wobbleAt ~= nil and not still then
			local alpha = (now - pin.wobbleAt) / w.seconds
			if alpha >= 1 then
				pin.wobbleAt = nil
			else
				local _, roll = Logic.netWrap(alpha)
				rock = roll
			end
		end
		pin.net:PivotTo(
			floor * CFrame.new(0, pin.lift + rise, 0) * CFrame.Angles(0, 0, rock) * pin.offset
		)
		fade(pin, gone)
	end
	if next(pins) == nil and stepping ~= nil then
		stepping:Disconnect()
		stepping = nil
	end
end

local function update(stray: Model)
	local down = stray:GetAttribute("NetDown") == true and stray.Parent ~= nil
	local pin = pins[stray]
	if down then
		if pin ~= nil and pin.liftAt == nil then
			return
		end
		if pin ~= nil then
			drop(pin) -- a new catch while the last net was still lifting
		end
		local frame = stray:GetPivot()
		if Context.distance(frame.Position) > Context.budget.animRadius then
			return
		end
		local made = make(stray)
		if made == nil then
			return
		end
		pins[stray] = made
		if stepping == nil then
			stepping = RunService.RenderStepped:Connect(step)
		end
		step()
	elseif pin ~= nil and pin.liftAt == nil then
		pin.liftAt = os.clock()
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local stray = instance :: Model
	local had: RBXScriptConnection? = watched[stray]
	if had then
		return
	end
	watched[stray] = stray:GetAttributeChangedSignal("NetDown"):Connect(function()
		update(stray)
	end)
	update(stray)
end

local function unwatch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local stray = instance :: Model
	local connection: RBXScriptConnection? = watched[stray]
	if connection then
		connection:Disconnect()
		watched[stray] = nil
	end
	-- a caught cat's stray goes as it is picked up: its net lifts off from where it was
	local pin = pins[stray]
	if pin ~= nil and pin.liftAt == nil then
		pin.liftAt = os.clock()
	end
end

-- True while a net of this player's is down over a stray (lifting counts as up), so their hand net is put away.
function NetPin.pinning(userId: number): boolean
	for _, pin in pins do
		if pin.catcher == userId and pin.liftAt == nil then
			return true
		end
	end
	return false
end

-- The catch finish's two wobbles on the net over `stray` (Presets.catchReact.wrap). False when no net is down over
-- it, so the caller can play the older closing ball instead.
function NetPin.wobble(stray: Model): boolean
	local pin = pins[stray]
	if pin == nil then
		return false
	end
	pin.wobbleAt = os.clock()
	return true
end

function NetPin.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(unwatch)
	for _, instance in CollectionService:GetTagged("Stray") do
		watch(instance)
	end
end

return NetPin
