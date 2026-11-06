--!strict
-- The camp extras' moving touches (F100, camp-extras.md section 3: golden fish "landed with a little rod animation",
-- "the box's lid rattling when a prize waits"). Model-Agent's #750 gives the Fish Pond a `_Rod` child Model pivoted at
-- its butt in the holder, with the line and the bobber inside it, and the Lost and Found a `_Lid` child Model pivoted
-- at its back hinge. On this client:
-- - When you collect the pond (Moments.CampExtraCollect "pond"), its rod tugs at the bite, lifts the fish in, casts
--   back out past rest and settles (Presets.campExtras.rod), with the rodCast beat as the bobber drops back into the
--   water. The line and the bobber hang from the tip and stay upright (Logic.hangs).
-- - While your Lost and Found holds a prize (Moments.CampExtrasState, the server's CampExtrasState passed on by the
--   engineer's controller), its lid rattles every few seconds with the lidRattle beat, on lids within
--   budget.ambientRadius. When you collect it ("lostFound"), the lid lifts to let the prize out and shuts with a bounce;
--   the collect's own sound plays then, so that has no beat.
-- - While your Lost and Found booth holds a prize (#1732, camp-stations.md section 4b), its desk bell (the booth's
--   `_LostFoundBooth_Bell` child Model, pivoted at its base) rings every few seconds: a side to side wobble that dies
--   away. It is the only touch here that plays with Reduce Motion, as the spec asks. The booth sign's blinking bulb is
--   VFX-Agent's (CampGlow).
-- Nothing else moves with Reduce Motion. The server places the sets once under Workspace.World and never moves these parts,
-- so each turn is drawn from the parts' frames read as it starts, and the parts go back to those frames when it ends.
-- VFX-Agent draws the fish jump, the thermos steam, the pipe drips and the Yard Sale sign's sway. Listening only:
-- nothing here fires a remote or changes game state.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local CampExtras = {}

-- the pond's rod: any child Model named ..._Rod (the FishPond's, the Woods FishingHut's and its gold coat's
-- ..._FishingHut_Gold_Rod, Model-Agent #1351), pivot at the butt, casting about X
local ROD = "_Rod"
local LID = "_LostFound_Lid"
local BELL = "_LostFoundBooth_Bell"

type Kind = "cast" | "rattle" | "pop" | "ring"

type Play = {
	model: Model,
	kind: Kind,
	started: number,
	pivot: CFrame, -- the Model's pivot as the play began
	parts: { BasePart },
	offsets: { CFrame }, -- each part in the pivot's space as the play began
	hanging: { boolean }, -- the rod's line and bobber: they follow the tip and stay upright
	tip: Vector3, -- where the hanging parts hang from, in the pivot's space
	plop: Instance, -- where the rodCast beat sounds: the lowest hanging part (the bobber), else the Model
	angle: number, -- the turn last drawn, radians
	beat: boolean, -- the rodCast beat has sounded
}

local rods: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lids: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local bells: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local playing: { [Model]: Play } = {}
local held = 0 -- prizes waiting in this player's Lost and Found
local rattleAt = 0
local ringAt = 0
local rng = Random.new()
local started = false

local function endsWith(name: string, suffix: string): boolean
	return string.sub(name, -#suffix) == suffix
end

local function found(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if endsWith(instance.Name, ROD) then
		rods[instance :: Model] = true
	elseif endsWith(instance.Name, LID) then
		lids[instance :: Model] = true
	elseif endsWith(instance.Name, BELL) then
		bells[instance :: Model] = true
	end
end

local function length(kind: Kind): number
	local c = Presets.campExtras
	if kind == "cast" then
		return Logic.keyedSeconds(c.rod.keys)
	elseif kind == "pop" then
		return Logic.keyedSeconds(c.lid.pop)
	elseif kind == "ring" then
		return c.bell.ring.seconds
	end
	return c.lid.rattle.seconds
end

local function angleOf(kind: Kind, t: number): number
	local c = Presets.campExtras
	if kind == "cast" then
		return math.rad(Logic.keyed(c.rod.keys, t))
	elseif kind == "pop" then
		return math.rad(Logic.keyed(c.lid.pop, t))
	elseif kind == "ring" then
		return Logic.bellWobble(t)
	end
	return Logic.lidRattle(t)
end

-- Draws a play turned `angle` about its pivot's X (a bell's ring: about its Z, side to side); the hanging parts move
-- with the tip and keep their own turn.
local function draw(play: Play, angle: number)
	local turn = if play.kind == "ring"
		then CFrame.Angles(0, 0, angle)
		else CFrame.Angles(angle, 0, 0)
	local shift = CFrame.new(turn * play.tip - play.tip)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for i, part in play.parts do
		if part.Parent ~= nil then
			table.insert(parts, part)
			table.insert(
				frames,
				play.pivot * (if play.hanging[i] then shift else turn) * play.offsets[i]
			)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Starts `kind` on a rod or lid. A play already running there keeps the frames it began from (they are the rest) and
-- starts over as the new kind.
local function begin(model: Model, kind: Kind, now: number)
	local play = playing[model]
	if play ~= nil then
		play.kind = kind
		play.started = now
		play.beat = false
		return
	end
	local pivot = model:GetPivot()
	local hangBeyond = Presets.campExtras.rod.hangBeyond
	local isRod = rods[model] == true
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local hanging: { boolean } = {}
	local tip = Vector3.zero
	local top = -math.huge
	local low = math.huge
	local plop: Instance = model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local offset = pivot:ToObjectSpace(part.CFrame)
			local hangs = isRod and Logic.hangs(offset, hangBeyond)
			table.insert(parts, part)
			table.insert(offsets, offset)
			table.insert(hanging, hangs)
			if hangs then
				local reach = offset.Position.Y + part.Size.Y / 2
				if reach > top then
					top = reach
					tip = Vector3.new(offset.Position.X, reach, offset.Position.Z)
				end
				if offset.Position.Y < low then
					low = offset.Position.Y
					plop = part
				end
			end
		end
	end
	if #parts == 0 then
		return
	end
	playing[model] = {
		model = model,
		kind = kind,
		started = now,
		pivot = pivot,
		parts = parts,
		offsets = offsets,
		hanging = hanging,
		tip = tip,
		plop = plop,
		angle = 0,
		beat = false,
	}
end

-- The rod or lid in `set` nearest `position`, within `within` studs.
local function nearest(set: { [Model]: boolean }, position: Vector3, within: number): Model?
	local best: Model? = nil
	local bestDistance = within
	for model in set do
		local at = Context.positionOf(model)
		if at ~= nil then
			local distance = (at - position).Magnitude
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

local function collected(extraId: unknown, position: unknown)
	if Context.reducedMotion() or typeof(position) ~= "Vector3" then
		return
	end
	local c = Presets.campExtras
	if extraId == "pond" then
		local rod = nearest(rods, position :: Vector3, c.rod.within)
		if rod ~= nil then
			begin(rod, "cast", os.clock())
		end
	elseif extraId == "lostFound" then
		local lid = nearest(lids, position :: Vector3, c.lid.within)
		if lid ~= nil then
			begin(lid, "pop", os.clock())
		end
	end
end

local function step()
	local now = os.clock()
	local still = Context.reducedMotion()
	local done: { Play } = {}
	for model, play in playing do
		local t = now - play.started
		-- only the booth's bell rings on with Reduce Motion (a separate boolean keeps play.kind's type whole below)
		local stops: boolean = still and play.kind ~= "ring"
		if stops or model.Parent == nil or t >= length(play.kind) then
			table.insert(done, play)
		else
			local angle = angleOf(play.kind, t)
			-- the cast's swing back down past rest: the bobber is in the water again
			if play.kind == "cast" and not play.beat and play.angle < 0 and angle >= 0 then
				play.beat = true
				Beats.hit:Fire("rodCast", play.plop)
			end
			play.angle = angle
			draw(play, angle)
		end
	end
	for _, play in done do
		draw(play, 0)
		playing[play.model] = nil
	end
	local radius = Context.budget.ambientRadius
	-- the booth's bell rings while a prize waits, Reduce Motion or not (camp-stations.md section 4b)
	if held > 0 and now >= ringAt then
		local every = Presets.campExtras.bell.every
		ringAt = now + rng:NextNumber(every[1], every[2])
		for model in bells do
			local at = Context.positionOf(model)
			if at ~= nil and playing[model] == nil and Context.distance(at) <= radius then
				begin(model, "ring", now)
			end
		end
	end
	if held <= 0 or still or now < rattleAt then
		return
	end
	local every = Presets.campExtras.lid.every
	rattleAt = now + rng:NextNumber(every[1], every[2])
	for model in lids do
		local at = Context.positionOf(model)
		if at ~= nil and playing[model] == nil and Context.distance(at) <= radius then
			begin(model, "rattle", now)
			Beats.hit:Fire("lidRattle", model)
		end
	end
end

function CampExtras.start()
	if started then
		return
	end
	started = true
	-- the engineer's camp extra moments (F100), once Moments has them; until then nothing here moves
	local moments = Moments :: any
	if moments.CampExtraCollect ~= nil then
		moments.CampExtraCollect:Connect(collected)
	end
	if moments.CampExtrasState ~= nil then
		moments.CampExtrasState:Connect(function(state: unknown)
			held = Logic.campHeld(state, "lostFound")
		end)
	end
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		for _, descendant in world:GetDescendants() do
			found(descendant)
		end
		world.DescendantAdded:Connect(found)
	end)
	RunService.PreRender:Connect(step)
end

return CampExtras
