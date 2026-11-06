--!strict
-- The pity cat (#1572, luck-and-rare-moments.md 1h). As a pity stray appears, a gold beam rises from it for a few
-- seconds (a bundle for a Mythical), seen from across the area. When it is caught in another server, or goes at
-- night, its copy here puffs away in a cloud of gold sparkles and smoke. A catch in this server plays the usual catch
-- effects instead. Reduce Motion skips the beam and keeps the puff.
--
-- Source: Gameplay-Engineer's #1744: the `PityCat` attribute ("Legendary" or "Mythical") on the Stray-tagged model,
-- and `PityAnnounce(kind, areaId, state, winnerName?)` with state "out", "caught" or "gone". Listening only. Numbers
-- in Presets.pity.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Pity = {}

local strays: { [Model]: Vector3 } = {} -- each pity stray here and its last known position
local gone: { at: Vector3, when: number }? = nil -- the last pity stray to leave, for a puff just after it went
local beamed: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function kindOf(model: Model): string?
	local kind = model:GetAttribute("PityCat")
	return if type(kind) == "string" and kind ~= "" then kind else nil
end

local function beam(model: Model, kind: string)
	if beamed[model] then
		return
	end
	beamed[model] = true
	local p = Presets.pity
	local at = model:GetPivot().Position
	if Context.distance(at) > p.within then
		return
	end
	local b = if kind == "Mythical" then p.mythical else p.legendary
	for i = 1, b.beams do
		local offset = if b.beams > 1
			then Vector3.new(
				math.cos(i / b.beams * 2 * math.pi),
				0,
				math.sin(i / b.beams * 2 * math.pi)
			) * b.spread
			else Vector3.zero
		Particles.beam(
			at + offset,
			b.colours[(i - 1) % #b.colours + 1],
			b.width,
			b.height,
			p.seconds
		)
	end
	Particles.burst("dingSparkle", at + Vector3.new(0, p.lift, 0), b.sparkles, b.colours[1])
end

local function follow(model: Model)
	local known: Vector3? = strays[model]
	if known then
		return
	end
	local kind = kindOf(model)
	if kind == nil then
		return
	end
	strays[model] = model:GetPivot().Position
	beam(model, kind)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	follow(model)
	model:GetAttributeChangedSignal("PityCat"):Connect(function()
		follow(model)
	end)
end

local function puff(at: Vector3)
	local p = Presets.pity
	if Context.distance(at) > p.within then
		return
	end
	Particles.burst("smokePuff", at, p.puff.smoke)
	Particles.burst("dingSparkle", at + Vector3.new(0, p.lift, 0), p.puff.sparkles, p.puff.colour)
	Particles.ring(at, p.puff.colour, p.puff.ring, p.puff.ringSeconds)
end

-- Whether the winner is a player in this server, so the catch here already plays its own effects.
local function winnerHere(winner: unknown): boolean
	if type(winner) ~= "string" or winner == "" then
		return false
	end
	for _, player in Players:GetPlayers() do
		if player.Name == winner or player.DisplayName == winner then
			return true
		end
	end
	return false
end

local function announced(_kind: unknown, _areaId: unknown, state: unknown, winner: unknown)
	if state ~= "caught" and state ~= "gone" then
		return
	end
	if state == "caught" and winnerHere(winner) then
		return
	end
	local any = false
	for model, at in strays do
		if model.Parent ~= nil then
			puff(model:GetPivot().Position)
		else
			puff(at)
		end
		any = true
	end
	local last = gone
	if not any and last ~= nil and os.clock() - last.when <= Presets.pity.lateSeconds then
		puff(last.at)
	end
	gone = nil
end

function Pity.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("Stray") do
		consider(instance)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(consider)
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			local at: Vector3? = strays[instance :: Model]
			if at then
				gone = { at = at, when = os.clock() }
				strays[instance :: Model] = nil
			end
		end
	end)
	Context.whenRemote("PityAnnounce", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(announced)
	end)
	-- keep each stray's last position, so a puff after it streamed out or was removed lands where it stood
	task.spawn(function()
		while true do
			task.wait(Presets.pity.track)
			for model in strays do
				if model.Parent ~= nil then
					strays[model] = model:GetPivot().Position
				end
			end
		end
	end)
end

return Pity
