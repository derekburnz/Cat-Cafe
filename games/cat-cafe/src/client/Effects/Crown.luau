--!strict
-- The leaderboard crown's sparkle (F98, leaderboards.md section 3: a crown over anyone in an all time top 10 at the
-- last refresh). The UI's Screens/Crowns draws the crown over the head; here it glints now and then with a few gold
-- stars, on the nearest crowned players only, and when a player near you earns it while you watch, gold sparkles and
-- stars burst at the crown with a little gold confetti and a gold ring at their feet. A crown seen as a player joins,
-- or as this client starts, only glints. Your own crown too.
--
-- Source: the `Crown` attribute LeaderboardService sets on each Player, their character's Head and
-- HumanoidRootPart, the camera's up (the crown's BillboardGui is lifted in the camera's up, StudsOffset). Listening
-- only. Numbers in Presets.crown and the budget's crownGlints.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Crown = {}

local seen: { [Player]: boolean } = {} -- each player's Crown as last seen; missing until the first value
local nextAt: { [Player]: number } = {} -- when each glinting crown glints next
local rng = Random.new()
local started = false

local function wears(player: Player): boolean
	return player:GetAttribute("Crown") == true
end

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	return if head ~= nil and head:IsA("BasePart") then head :: BasePart else nil
end

-- Where the crown is drawn: `lift` studs over the head's centre in the camera's up, as the BillboardGui lifts it.
local function crownAt(head: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	local up = if camera ~= nil then camera.CFrame.UpVector else Vector3.yAxis
	return head.Position + up * Presets.crown.lift
end

local function glint(head: BasePart)
	local c = Presets.crown
	local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		* c.spread
	Particles.burst("crownGlint", crownAt(head) + offset, c.glint)
end

-- A player near you just earned the crown.
local function earned(player: Player)
	local head = headOf(player)
	if head == nil then
		return
	end
	local c = Presets.crown
	local at = crownAt(head)
	if Context.distance(at) > c.within then
		return
	end
	local e = c.earned
	Particles.burst("dingSparkle", at, e.sparkles, e.colour)
	Particles.burst("crownGlint", at, e.stars)
	local count = math.ceil(Context.budget.confetti * e.confetti)
	Particles.confetti(at, count, { e.colour, Presets.palette.goldLight, Presets.palette.sparkle })
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		local body = root :: BasePart
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		local hip = if humanoid ~= nil then humanoid.HipHeight else 2
		local feet = body.Position - Vector3.new(0, body.Size.Y / 2 + hip - 0.1, 0)
		Particles.ring(feet, e.colour, e.ring, e.ringSeconds)
	end
	nextAt[player] = os.clock() + c.every[2] -- the burst is its glint for a while
end

local function follow(player: Player)
	seen[player] = wears(player)
	player:GetAttributeChangedSignal("Crown"):Connect(function()
		local now = wears(player)
		local before = seen[player]
		seen[player] = now
		if Logic.crownEarned(before, now) then
			earned(player)
		end
	end)
end

local function step()
	local c = Presets.crown
	local candidates: { Logic.Candidate<Player> } = {}
	local heads: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		if wears(player) then
			local head = headOf(player)
			if head ~= nil then
				heads[player] = head
				table.insert(
					candidates,
					{ key = player, distance = Context.distance(head.Position) }
				)
			end
		end
	end
	local now = os.clock()
	local chosen: { [Player]: boolean } = {}
	for _, player in Logic.nearest(candidates, c.within, Context.budget.crownGlints) do
		chosen[player] = true
		local due = nextAt[player]
		if due == nil then
			nextAt[player] = now + rng:NextNumber(0, c.every[2]) -- stagger crowns that come near together
		elseif now >= due then
			local head: BasePart? = heads[player]
			if head ~= nil then
				glint(head)
			end
			nextAt[player] = now + rng:NextNumber(c.every[1], c.every[2])
		end
	end
	for player in nextAt do
		if not chosen[player] then
			nextAt[player] = nil
		end
	end
end

function Crown.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
	Players.PlayerRemoving:Connect(function(player: Player)
		seen[player] = nil
		nextAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Presets.crown.pick)
			step()
		end
	end)
end

return Crown
