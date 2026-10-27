--!strict
-- The Tackle on every R15 character this client can see (design v0.11, F74): the tackler's dive, then the stumble
-- to a stop after a hit or the belly slide and get up after a miss, and the tackled player's fall and get up. Poses
-- from Avatar.luau go into the joints' Motor6D.Transform after the Animator each frame (PreSimulation), eased in
-- from and back out to whatever the character was playing; Transform does not replicate, so each client draws every
-- character it sees. The engineer moves and holds the characters; this only draws them.
--
-- Source: a tackler's character carries `TackleAt` (server time of the press) and `TackleMissAt` (a window that
-- ended with no hit); a hit sets the target's `ShovedAt` and `ShovedBy` (the tackler's UserId), so the tackler's hit
-- is the target whose ShovedBy names it. On its own screen the tackler's dive starts at the press
-- (Moments.TacklePress, once the engineer adds it) instead of a round trip later, and a refused press
-- (Moments.TackleRefused) lets go of it.
-- Listening only: nothing here fires a remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local Tackle = {}

type Entry = {
	rig: Avatar.Rig,
	written: { [Motor6D]: CFrame }, -- what this wrote last frame, to tell the Animator's frames from its own
	shoveSeen: number?, -- the ShovedAt the fall direction below was worked out for
	fallForward: boolean,
	side: number,
	cutKey: number?, -- the move the player walked out of, and when
	cutAt: number,
}

local entries: { [Model]: Entry } = {}
local localPress: number? = nil -- server time of this player's own press
local timing: Avatar.Timing? = nil
local started = false

-- The engineer's timers from the shared Config where it has them, else the design's numbers (Presets.tacklePose).
local function timingNow(): Avatar.Timing
	if timing ~= nil then
		return timing
	end
	local t = Presets.tacklePose
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared ~= nil then shared:FindFirstChild("Config") else nil
	local config: any = nil
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		config = if ok and type(loaded) == "table" then loaded else nil
	end
	local function read(name: string, fallback: number): number
		local value = if config ~= nil then config[name] else nil
		return if type(value) == "number" and value >= 0 then value else fallback
	end
	local loaded = {
		lunge = read("TackleLungeSeconds", t.lunge),
		grace = read("TackleHitGraceSeconds", t.grace),
		hitRecover = read("TackleHitRecoverSeconds", t.hitRecover),
		missRecover = read("TackleMissRecoverSeconds", t.missRecover),
		push = t.push,
		down = read("TackledDownSeconds", t.down),
	}
	timing = loaded
	return loaded
end

local function number(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

local function rootOf(character: Model?): BasePart?
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- Gives the joints back to the Animator: a joint no track drives would otherwise keep the last pose.
local function release(entry: Entry)
	for motor, frame in entry.written do
		if motor.Transform == frame then
			motor.Transform = CFrame.identity
		end
	end
	table.clear(entry.written)
end

local function forget(character: Model)
	local entry = entries[character]
	if entry ~= nil then
		release(entry)
		entries[character] = nil
	end
end

-- Which way a tackle threw this player, from where the tackler stands: on its front when hit from behind, and
-- tipped towards a push from the side.
local function aim(entry: Entry, character: Model, shovedAt: number)
	if entry.shoveSeen == shovedAt then
		return
	end
	entry.shoveSeen = shovedAt
	entry.fallForward, entry.side = false, 0
	local by = number(character, "ShovedBy")
	local tackler = if by ~= nil then Players:GetPlayerByUserId(by) else nil
	local from = rootOf(if tackler ~= nil then tackler.Character else nil)
	local root = rootOf(character)
	if from == nil or root == nil then
		return
	end
	local push = root.Position - from.Position
	push = Vector3.new(push.X, 0, push.Z)
	if push.Magnitude < 0.1 then
		return
	end
	local mine = root.CFrame:VectorToObjectSpace(push.Unit)
	entry.fallForward = -mine.Z > 0.3
	entry.side = mine.X
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local t = Presets.tacklePose
	local times = timingNow()
	local me = Players.LocalPlayer.Character
	local radius = Context.budget.animRadius

	-- Who landed a tackle on whom: the latest ShovedAt under each tackler's UserId.
	local hits: { [number]: number } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			local by, at = number(character, "ShovedBy"), number(character, "ShovedAt")
			if by ~= nil and at ~= nil and at > (hits[by] or -math.huge) then
				hits[by] = at
			end
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local entry = if character ~= nil then entries[character] else nil
		if character == nil or entry == nil then
			continue
		end
		local root = entry.rig.root
		local mine = character == me
		if not mine and Context.distance(root.Position) > radius then
			release(entry)
			continue
		end
		local tackleAt = number(character, "TackleAt")
		if mine and localPress ~= nil then
			local press = localPress :: number
			-- the server's TackleAt for this press lands a little after it; an older one is the last press
			if tackleAt == nil or tackleAt < press + 1 then
				tackleAt = press
			end
		end
		local shovedAt = number(character, "ShovedAt")
		if shovedAt ~= nil then
			aim(entry, character, shovedAt)
		end
		local pose, weight, began, still = Avatar.at({
			tackleAt = tackleAt,
			hitAt = hits[player.UserId],
			missAt = number(character, "TackleMissAt"),
			shovedAt = shovedAt,
			fallForward = entry.fallForward,
			side = entry.side,
		}, now, times)
		if pose == nil then
			release(entry)
			continue
		end
		-- Walking while the pose says it is down means it is up: let go of this move.
		if entry.cutKey ~= began and now > still + t.cutAfter then
			local v = root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > t.cutSpeed then
				entry.cutKey, entry.cutAt = began, now
			end
		end
		if entry.cutKey == began then
			weight *= 1 - math.clamp((now - entry.cutAt) / t.cutSeconds, 0, 1)
		end
		if weight <= 0 then
			release(entry)
			continue
		end
		for motor, frame in Avatar.solve(entry.rig, pose) do
			local base = motor.Transform
			if entry.written[motor] == base then
				base = CFrame.identity -- the Animator left this joint alone, so last frame's pose is still on it
			end
			local out = base:Lerp(frame, weight)
			motor.Transform = out
			entry.written[motor] = out
		end
	end
end

local function watchCharacter(character: Model)
	-- the joints are there once the character is in the world; R15 only
	task.defer(function()
		if not character:IsDescendantOf(game) or entries[character] ~= nil then
			return
		end
		local rig = Avatar.bind(character)
		if rig == nil then
			return
		end
		entries[character] = {
			rig = rig,
			written = {},
			shoveSeen = nil,
			fallForward = false,
			side = 0,
			cutKey = nil,
			cutAt = 0,
		}
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(game) then
				forget(character)
			end
		end)
	end)
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function Tackle.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	-- The engineer's press and refusal moments, once Moments has them; until then the dive waits for TackleAt.
	local moments = Moments :: any
	if moments.TacklePress ~= nil then
		moments.TacklePress:Connect(function()
			localPress = Workspace:GetServerTimeNow()
		end)
	end
	if moments.TackleRefused ~= nil then
		moments.TackleRefused:Connect(function()
			localPress = nil
			local me = Players.LocalPlayer.Character
			local entry = if me ~= nil then entries[me] else nil
			if entry ~= nil then
				release(entry)
			end
		end)
	end
	RunService.PreSimulation:Connect(step)
end

return Tackle
