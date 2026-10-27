--!strict
-- After a catch and after a miss (design v0.8, F55 and F57):
-- - the getaway: when a net catch or a rescue pushes the players round the catcher away, a ring as wide as the push
--   spreads from the catcher's feet with a puff of dust, and speed lines stream off the catcher while their Catch
--   Rush lasts; a pushed player skids on a little dust;
-- - startled: the player who missed gets the dizzy stars of a shove for as long as they are slowed, and for them a
--   camera bump.
-- The push and both walk speeds are the engineer's; this only draws them.
--
-- Source: the catcher's character carries `RushUntil` and the player who missed `StartledUntil` (server times the
-- rush and the slow end, data-model section 13), and a pushed player `PushedAt` (server time of the push) once the
-- engineer sets it, so every player nearby sees them. Listening only: nothing here fires a remote.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Shove = require(script.Parent.Shove)

local Chase = {}

type Watched = { rushEnds: unknown, startledEnds: unknown, lines: { Instance }, token: number }

local LATE_SECONDS = 0.6 -- a push that replicates later than this is over; nothing plays

local started = false

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	return if part ~= nil and part:IsA("BasePart") then part :: BasePart else nil
end

-- The ground under a character.
local function feetOf(character: Model, root: BasePart): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, hip + root.Size.Y / 2, 0)
end

local function inRange(character: Model, root: BasePart): boolean
	return character == Players.LocalPlayer.Character
		or Context.distance(root.Position) <= Context.budget.ambientRadius
end

-- Thin trails off the body, as many as the budget's rushLines. A trail only draws while it moves, so the lines show
-- while the catcher runs and stop when they stand still.
local function addLines(state: Watched, root: BasePart)
	local c = Presets.chase
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, math.min(Context.budget.rushLines, #c.lines) do
		local at = c.lines[i]
		local top = Instance.new("Attachment")
		top.Name = "EffectsRushLine"
		top.Position = at + Vector3.new(0, c.lineWidth, 0)
		local bottom = Instance.new("Attachment")
		bottom.Name = "EffectsRushLine"
		bottom.Position = at
		local trail = Instance.new("Trail")
		trail.Name = "EffectsRushLine"
		trail.Attachment0 = bottom
		trail.Attachment1 = top
		trail.FaceCamera = true
		trail.Lifetime = c.lineSeconds
		trail.MinLength = 0.05
		trail.Color = ColorSequence.new(Presets.palette.offwhite)
		trail.Transparency = fade
		trail.WidthScale = NumberSequence.new(1, 0.3)
		trail.LightEmission = 0.4
		trail.LightInfluence = 0
		bottom.Parent = root
		top.Parent = root
		trail.Parent = root
		table.insert(state.lines, trail)
		table.insert(state.lines, bottom)
		table.insert(state.lines, top)
	end
end

-- The lines stop drawing and the streaks already behind fade out before they go.
local function endLines(state: Watched)
	for _, instance in state.lines do
		if instance:IsA("Trail") then
			(instance :: Trail).Enabled = false
		end
		Debris:AddItem(instance, Presets.chase.lineSeconds + 0.1)
	end
	table.clear(state.lines)
end

local function getaway(character: Model, root: BasePart)
	local c = Presets.chase
	local feet = feetOf(character, root)
	Particles.ring(
		feet + Vector3.new(0, 0.2, 0),
		Presets.palette.offwhite,
		c.ringDiameter,
		c.ringSeconds
	)
	Particles.burst("dust", feet, c.dust)
end

local function rush(character: Model, state: Watched)
	local ends = character:GetAttribute("RushUntil")
	local left, fresh =
		Logic.timedState(ends, state.rushEnds, Workspace:GetServerTimeNow(), Presets.chase.longest)
	state.rushEnds = ends
	state.token += 1
	if left <= 0 then
		endLines(state)
		return
	end
	local root = partOf(character, "HumanoidRootPart")
	if root == nil or not inRange(character, root) then
		return
	end
	if fresh then
		getaway(character, root)
	end
	if #state.lines == 0 then
		addLines(state, root)
	end
	local token = state.token
	task.delay(left, function()
		if state.token == token then
			endLines(state)
		end
	end)
end

local function startle(character: Model, state: Watched)
	local ends = character:GetAttribute("StartledUntil")
	local left, fresh = Logic.timedState(
		ends,
		state.startledEnds,
		Workspace:GetServerTimeNow(),
		Presets.chase.longest
	)
	state.startledEnds = ends
	if left <= 0 then
		return
	end
	local root = partOf(character, "HumanoidRootPart")
	if root == nil or not inRange(character, root) then
		return
	end
	local head = partOf(character, "Head")
	if head ~= nil then
		Shove.stars(head, left)
	end
	-- The catch's own miss shake has just played; this one replaces it, so the two read as one bump.
	if fresh and character == Players.LocalPlayer.Character then
		Context.shake(Presets.chase.startledShake, Presets.chase.startledStuds)
	end
end

local function pushed(character: Model)
	local at = character:GetAttribute("PushedAt")
	if type(at) ~= "number" or Workspace:GetServerTimeNow() - at >= LATE_SECONDS then
		return
	end
	local root = partOf(character, "HumanoidRootPart")
	if root ~= nil and inRange(character, root) then
		Particles.burst("kick", feetOf(character, root), Presets.chase.pushedDust)
	end
end

local function watchCharacter(character: Model)
	local state: Watched = {
		rushEnds = character:GetAttribute("RushUntil"),
		startledEnds = character:GetAttribute("StartledUntil"),
		lines = {},
		token = 0,
	}
	character:GetAttributeChangedSignal("RushUntil"):Connect(function()
		rush(character, state)
	end)
	character:GetAttributeChangedSignal("StartledUntil"):Connect(function()
		startle(character, state)
	end)
	character:GetAttributeChangedSignal("PushedAt"):Connect(function()
		pushed(character)
	end)
	-- A character that arrives mid-rush gets its lines for the rest of it, without the ring.
	if
		Logic.timedState(state.rushEnds, nil, Workspace:GetServerTimeNow(), Presets.chase.longest)
		> 0
	then
		task.defer(rush, character, state)
	end
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function Chase.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return Chase
