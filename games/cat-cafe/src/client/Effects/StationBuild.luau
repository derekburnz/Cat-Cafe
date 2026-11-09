--!strict
-- The station build-in (#2687 part 3, Derek2 2026-11-09: "make unlocking the stations inside new areas more impactful
-- so it feels like you are actually unlocking progress"). The first time this account comes into an area whose
-- station it owns, that area's camp station builds itself on this client: every part starts up in the air, a little
-- to the side and turned, then drops into place and lands with a snap, bottom to top, fading in as it falls
-- (Presets.stationBuild, about 2.3 s, inside the reveal's 3 s beat). Each landing sounds the stationClunk beat, at most
-- one every clunkGap seconds, for Sound-Agent's clunk set. With Reduce Motion the station only fades in.
--
-- Source: Moments.StationReveal(area, perkId) from Gameplay's WorldController (#2755), and the `CampExtra`-tagged
-- models (shared/CampExtras.TAG) whose `Area` attribute is that area. They stream in whole (Atomic), so the build waits
-- up to `wait` seconds for them. The server places the sets once and never moves them, so the build reads each part's
-- frame as it starts and puts every part back on that frame, with its LocalTransparencyModifier at 0, when it ends.
-- CampExtras.luau leaves a station's rod, lid and bell alone while it builds (StationBuild.building). VFX-Agent draws
-- the burst and the path's sparkle, Sound-Agent the fanfare, UI-Engineer the Unlocked card. Listening only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local StationBuild = {}

local TAG = "CampExtra" -- shared/CampExtras.TAG

type Build = {
	model: Model,
	started: number,
	calm: boolean, -- Reduce Motion: a fade only
	parts: { BasePart },
	rest: { CFrame }, -- each part's frame as the build began
	ranks: { number }, -- each part's place bottom to top, from 1
	from: { CFrame }, -- each part's start, relative to its rest: lifted, shifted and turned
	landed: { boolean },
	seconds: number,
}

local builds: { [Model]: Build } = {}
local rng = Random.new()
local clunkAt = 0
local heartbeat: RBXScriptConnection? = nil
local started = false

-- Whether `instance` is (in) a station that is building in on this client right now.
function StationBuild.building(instance: Instance): boolean
	for model in builds do
		if instance == (model :: Instance) or instance:IsDescendantOf(model) then
			return true
		end
	end
	return false
end

-- The streamed-in camp stations of `area`.
local function stationsOf(area: string): { Model }
	local found: { Model } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("Area") == area
			and instance:IsDescendantOf(Workspace)
		then
			table.insert(found, instance :: Model)
		end
	end
	return found
end

-- A start frame for one piece, relative to its rest in world axes: lifted, shifted to the side and turned.
local function startOffset(): CFrame
	local c = Presets.stationBuild
	local lift = rng:NextNumber(c.lift[1], c.lift[2])
	local angle = rng:NextNumber(math.rad(-c.tilt), math.rad(c.tilt))
	local axis = rng:NextUnitVector()
	local side =
		Vector3.new(rng:NextNumber(-c.drift, c.drift), 0, rng:NextNumber(-c.drift, c.drift))
	return CFrame.new(side + Vector3.new(0, lift, 0)) * CFrame.fromAxisAngle(axis, angle)
end

-- Puts every part of `build` back where it began, shown.
local function finish(build: Build)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for i, part in build.parts do
		if part.Parent ~= nil then
			table.insert(parts, part)
			table.insert(frames, build.rest[i])
			part.LocalTransparencyModifier = 0
		end
	end
	if not build.calm and #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	builds[build.model] = nil
end

-- Draws `build` at `t` seconds; true once it has ended.
local function draw(build: Build, t: number, now: number): boolean
	local c = Presets.stationBuild
	if build.model.Parent == nil then
		builds[build.model] = nil
		return true
	end
	if t >= build.seconds then
		finish(build)
		return true
	end
	if build.calm then
		local shown = math.clamp(t / math.max(c.calmFade, 1e-3), 0, 1)
		for _, part in build.parts do
			part.LocalTransparencyModifier = 1 - shown
		end
		return false
	end
	local count = #build.parts
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for i, part in build.parts do
		if part.Parent == nil then
			continue
		end
		local u = Logic.buildPiece(build.ranks[i], count, t, c.spread, c.piece)
		local rest = build.rest[i]
		local frame: CFrame
		if u == nil then
			frame = CFrame.new(build.from[i].Position) * rest
			part.LocalTransparencyModifier = 1
		else
			local k = Logic.buildFall(u)
			local from = build.from[i]
			local turn = CFrame.identity:Lerp(from - from.Position, k)
			frame = CFrame.new(rest.Position + from.Position * k) * turn * (rest - rest.Position)
			part.LocalTransparencyModifier = 1 - math.clamp(u / math.max(c.fade, 1e-3), 0, 1)
			if u >= 1 and not build.landed[i] then
				build.landed[i] = true
				if now - clunkAt >= c.clunkGap then
					clunkAt = now
					Beats.hit:Fire("stationClunk", part)
				end
			end
		end
		table.insert(parts, part)
		table.insert(frames, frame)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	return false
end

local function step()
	local now = os.clock()
	local running = false
	for _, build in builds do
		if not draw(build, now - build.started, now) then
			running = true
		end
	end
	if not running and heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

-- Starts the build-in on `model` (once at a time).
function StationBuild.play(model: Model)
	if builds[model] ~= nil then
		return
	end
	local c = Presets.stationBuild
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		-- anchored parts only: moving a welded loose part would pull its assembly along
		if descendant:IsA("BasePart") and (descendant :: BasePart).Anchored then
			table.insert(parts, descendant :: BasePart)
		end
	end
	if #parts == 0 then
		return
	end
	-- bottom to top by each part's lowest point, so the base lands first and the roof last
	local order: { number } = {}
	local bottoms: { number } = {}
	for i, part in parts do
		order[i] = i
		bottoms[i] = part.Position.Y - part.Size.Magnitude / 2
	end
	table.sort(order, function(a: number, b: number): boolean
		return bottoms[a] < bottoms[b]
	end)
	local ranks: { number } = {}
	for rank, i in order do
		ranks[i] = rank
	end
	local rest: { CFrame } = {}
	local from: { CFrame } = {}
	local landed: { boolean } = {}
	for i, part in parts do
		rest[i] = part.CFrame
		from[i] = startOffset()
		landed[i] = false
		part.LocalTransparencyModifier = 1
	end
	local calm = Context.reducedMotion()
	builds[model] = {
		model = model,
		started = os.clock(),
		calm = calm,
		parts = parts,
		rest = rest,
		ranks = ranks,
		from = from,
		landed = landed,
		seconds = if calm then c.calmFade else Logic.buildSeconds(#parts, c.spread, c.piece),
	}
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	step()
end

-- Builds in `area`'s stations, waiting up to `wait` seconds for them to stream in.
local function reveal(area: unknown, _perkId: unknown)
	if type(area) ~= "string" then
		return
	end
	task.spawn(function()
		local giveUp = os.clock() + Presets.stationBuild.wait
		local stations = stationsOf(area :: string)
		while #stations == 0 and os.clock() < giveUp do
			task.wait(0.2)
			stations = stationsOf(area :: string)
		end
		for _, model in stations do
			StationBuild.play(model)
		end
	end)
end

function StationBuild.start()
	if started then
		return
	end
	started = true
	-- Moments.StationReveal comes with Gameplay's #2755; until it lands there is nothing to listen to
	local signal = (Moments :: any).StationReveal
	if signal ~= nil then
		signal:Connect(reveal)
	end
end

return StationBuild
