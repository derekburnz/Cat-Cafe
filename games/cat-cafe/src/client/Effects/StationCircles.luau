--!strict
-- #4668 (Derek 2026-11-15: "a setting to remove the circles infront of all stations/things in settings and have it
-- default turn to visibility off I think it adds too much visual clutter but have the menus still open in the area"):
-- the glowing walk-up rings (World/WalkUpCircles, parts named WalkUp.CIRCLE) are hidden on this client unless the
-- Settings switch "Station circles" (settings.stationCircles, off by default) is on. Only the look goes: the ring part
-- stays where the server put it and moves with its station, so WalkUpController still opens the window on stepping
-- in, and the server's pad checks are untouched.
--
-- Hidden means the ring's SurfaceGui pieces are not Visible (StationLockController switches the SurfaceGui's own
-- Enabled for a locked station, so the two never fight) and the art laid in its middle has LocalTransparencyModifier 1.
-- A sweep every SWEEP (1) seconds puts the look back after anything else touches it (a station unlocking). Listening only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local WalkUp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkUp"))

local StationCircles = {}

local SWEEP = 1 -- seconds between sweeps of the known rings (a station unlocking flashes its art at most this long)

local started = false
local shownSetting = false
local rings: { [Instance]: RBXScriptConnection } = {}
local faded: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- what this module faded

-- #5463 (Derek 2026-11-19: "pads and effects are there even if its not unlocked yet"): StationLockController marks
-- the ring of a station still locked for this player with this attribute (set here only, switch lockedRingsHidden),
-- and a marked ring stays hidden whatever else would show it. Before, this module put back the art it had faded once
-- while StationLock, which hides each piece once, never hid it again.
StationCircles.LOCKED_ATTRIBUTE = "StationLockedHere"
StationCircles.FLAG = "lockedRingsHidden"

-- Pure: whether a ring shows, given what the setting and townRings say (`shown`) and its lock mark.
function StationCircles.shownHere(shown: boolean, lockedHere: unknown): boolean
	return shown and lockedHere ~= true
end

-- Pure: whether the rings show for a `stationCircles` setting value (only an explicit true shows them).
function StationCircles.visible(setting: unknown): boolean
	return setting == true
end

local function paint(ring: Instance)
	-- Derek 2026-11-18 (#5224, the townRings switch, shared/WalkUp.ringLook): a Town Square ring always shows, smaller,
	-- and an area's never does; the rest follow the setting
	local on = ReplicatedStorage:GetAttribute("LiveFlag_" .. WalkUp.TOWN_FLAG) == true
	local town = ring:GetAttribute(WalkUp.TOWN_ATTRIBUTE)
	-- #5605 (Derek 2026-11-20: "the codes stand circle is missing", switch codesRingTown): the Codes Cat's circle
	-- stands on the Town Square but carries no Town mark, so with townRings on it followed the Station circles setting
	-- (off by default) and hid while every other Town ring showed. It counts as a Town ring now, at its full size.
	local codes = town == nil
		and ring.Name ~= WalkUp.CIRCLE
		and ReplicatedStorage:GetAttribute("LiveFlag_codesRingTown") == true
	if codes then
		town = true
	end
	local shown, scale = WalkUp.ringLook(
		on,
		town,
		shownSetting,
		if codes then true else ring:GetAttribute(WalkUp.FULL_ATTRIBUTE),
		ReplicatedStorage:GetAttribute("LiveFlag_" .. WalkUp.AREA_CANNON_FLAG) == true -- #5416
	)
	shown = StationCircles.shownHere(shown, ring:GetAttribute(StationCircles.LOCKED_ATTRIBUTE)) -- #5463
	for _, child in ring:GetChildren() do
		if child:IsA("SurfaceGui") then
			for _, piece in child:GetChildren() do
				if piece:IsA("GuiObject") then
					(piece :: GuiObject).Visible = shown
					local found = piece:FindFirstChild("TownScale")
					local size: UIScale? = if found and found:IsA("UIScale")
						then found :: UIScale
						else nil
					if size then
						size.Scale = scale
					elseif scale ~= 1 then
						local made = Instance.new("UIScale")
						made.Name = "TownScale"
						made.Scale = scale
						made.Parent = piece
					end
				end
			end
		end
	end
	local pieces = ring:GetDescendants()
	table.insert(pieces, ring) -- a modelled CodesCircle part is itself the look (a WalkUpCircle part is see-through)
	for _, piece in pieces do
		if piece:IsA("BasePart") or piece:IsA("Decal") then
			local thing = piece :: any
			if not shown then
				if thing.LocalTransparencyModifier < 1 then
					faded[piece] = true
					thing.LocalTransparencyModifier = 1
				end
			elseif faded[piece] then
				faded[piece] = nil
				thing.LocalTransparencyModifier = 0
			end
		end
	end
end

-- #4671 Studio check: the Codes Cat's circle is no walk-up ring but reads as one, so it goes with them: its modelled
-- `CodesCircle` (a part, or a model with the ticket on it) and Effects/Codes' mint `CodesGlow` ring over it
-- the Codes Cat's own floor ring and red ticket are modelled into its stand (Sync's #4671 Studio check)
local NAMES = {
	[WalkUp.CIRCLE] = true,
	CodesCircle = true,
	CodesGlow = true,
	CatCafe_Street_CodesCat_CodesCircle = true,
	CatCafe_Street_CodesCat_Glow = true,
	CatCafe_Street_CodesCat_Ticket_Decor = true,
}

-- Pure: whether an instance called `name` of class `className` is a circle this hides (a WalkUpCircle ObjectValue
-- link is not; a CodesCircle may be a part or a model).
function StationCircles.isCircle(name: string, className: string): boolean
	if NAMES[name] ~= true then
		return false
	end
	return className ~= "ObjectValue"
end

-- Whether the circles show now (Effects/Codes asks before its motes and step-in ring).
function StationCircles.shown(): boolean
	return shownSetting
end

local function track(instance: Instance)
	-- #4987: the name first, so the class name is read only for the few named like a circle
	local name = instance.Name
	if NAMES[name] ~= true or not StationCircles.isCircle(name, instance.ClassName) then
		return
	end
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return
	end
	local ring = instance
	if rings[ring] then
		return
	end
	-- pieces that stream in after the part
	rings[ring] = ring.DescendantAdded:Connect(function()
		task.defer(paint, ring)
	end)
	paint(ring)
end

local function sweep()
	for ring, connection in rings do
		if ring.Parent == nil then
			connection:Disconnect()
			rings[ring] = nil
		else
			paint(ring)
		end
	end
end

-- Shows or hides every ring at once (Effects.applySettings, on a Settings tap and the saved value).
function StationCircles.set(setting: unknown)
	local want = StationCircles.visible(setting)
	if want == shownSetting then
		return
	end
	shownSetting = want
	sweep()
end

function StationCircles.start()
	if started then
		return
	end
	started = true
	for _, instance in Workspace:GetDescendants() do
		track(instance)
	end
	Context.onWorkspaceAdded(track)
	task.spawn(function()
		while true do
			task.wait(SWEEP)
			sweep()
		end
	end)
end

return StationCircles
