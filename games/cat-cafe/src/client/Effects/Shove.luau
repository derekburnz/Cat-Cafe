--!strict
-- The tackle (F74, data-model 10c v0.11; the shove of design v0.5 F41 before it). While the tackler lunges, a
-- streak of dust trails along the ground behind them with dust kicked up at their feet. A tackle that lands is a
-- shove: a puff where it lands, a skid of dust at the tackled player's feet and dizzy stars circling their head for
-- as long as they are down and getting up, and for them a camera bump bigger than a missed catch. A miss kicks up
-- dust as the tackler slides on their belly and puffs where they stop. The lunge, the knockback and the poses are the
-- engineer's and the Animation-Engineer's; this only draws them. The stars also circle a player startled by a miss
-- (F57, Chase.luau).
--
-- Source: the tackler's character carries `TackleAt` (server time of the press) and `TackleMissAt` (server time a
-- lunge ended with no hit); the tackled player's carries `ShovedAt` (server time it landed) and `ShovedBy` (the
-- tackler's UserId), so every player nearby sees them. Listening only: nothing here fires a remote.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Shove = {}

type Stars = { head: BasePart, gui: BillboardGui, labels: { TextLabel }, began: number, ends: number }

local LATE_SECONDS = 0.6 -- a shove or tackle that replicates later than this is over; nothing plays
local DARK_WOOD = Color3.fromRGB(94, 70, 52)

local spinning: { Stars } = {}
local spinLoop: RBXScriptConnection? = nil
local config: { [string]: unknown }? = nil
local started = false

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	return if part ~= nil and part:IsA("BasePart") then part :: BasePart else nil
end

-- A positive number from the shared Config once the engineer adds it, so the effects keep time with the tackle;
-- `fallback` until then.
local function tuning(name: string, fallback: number): number
	if config == nil then
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = if shared ~= nil then shared:FindFirstChild("Config") else nil
		local loaded: any = nil
		if module ~= nil and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			loaded = if ok then result else nil
		end
		config = if type(loaded) == "table" then loaded else {}
	end
	local value = (config :: { [string]: unknown })[name]
	return if type(value) == "number" and value > 0 then value else fallback
end

-- How far below a character's root part the ground is.
local function drop(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return hip + root.Size.Y / 2
end

-- The ground under a character.
local function feetOf(character: Model, root: BasePart): Vector3
	return root.Position - Vector3.new(0, drop(character, root), 0)
end

local function fresh(character: Model, attribute: string): boolean
	local at = character:GetAttribute(attribute)
	return type(at) == "number" and Workspace:GetServerTimeNow() - at < LATE_SECONDS
end

-- The root part of a character this player should see a tackle on: their own, or one within ambientRadius.
local function nearRoot(character: Model): BasePart?
	local root = partOf(character, "HumanoidRootPart")
	if root == nil then
		return nil
	end
	if
		character ~= Players.LocalPlayer.Character
		and Context.distance(root.Position) > Context.budget.ambientRadius
	then
		return nil
	end
	return root
end

local function spin()
	local s = Presets.shove
	local now = os.clock()
	local still = Context.reducedMotion()
	local i = 1
	while i <= #spinning do
		local stars = spinning[i]
		local age = now - stars.began
		if now >= stars.ends or stars.head.Parent == nil then
			stars.gui:Destroy()
			spinning[i] = spinning[#spinning]
			spinning[#spinning] = nil
		else
			local fade = math.clamp((now - (stars.ends - 0.3)) / 0.3, 0, 1)
			for n, label in stars.labels do
				local angle = (n - 1) / #stars.labels * 2 * math.pi
					+ (if still then 0 else age * s.starHz * 2 * math.pi)
				-- Round the head on a flat circle, seen a little from above: the far side sits higher.
				label.Position =
					UDim2.fromScale(0.5 + 0.42 * math.cos(angle), 0.5 - 0.18 * math.sin(angle))
				label.TextTransparency = fade
				label.TextStrokeTransparency = 0.2 + 0.8 * fade
			end
			i += 1
		end
	end
	if #spinning == 0 and spinLoop ~= nil then
		spinLoop:Disconnect()
		spinLoop = nil
	end
end

-- Dizzy stars circling a head for `seconds`. Stars already over that head keep going until the later end, so a
-- shove and a startle together show one ring of stars.
function Shove.stars(head: BasePart, seconds: number)
	local s = Presets.shove
	local now = os.clock()
	for _, existing in spinning do
		if existing.head == head then
			existing.ends = math.max(existing.ends, now + seconds)
			return
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsDizzy"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(2 * s.starRadius + 0.6, 1.2) -- studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	local labels: { TextLabel } = {}
	for _ = 1, s.stars do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(0.3, 0.45)
		label.Font = Enum.Font.FredokaOne
		label.Text = "*"
		label.TextScaled = true
		label.TextColor3 = Presets.palette.sparkle
		label.TextStrokeColor3 = DARK_WOOD
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = Context.folder()
	table.insert(
		spinning,
		{ head = head, gui = gui, labels = labels, began = now, ends = now + seconds }
	)
	if spinLoop == nil then
		spinLoop = RunService.PreRender:Connect(spin)
	end
end

local function play(character: Model)
	if not fresh(character, "ShovedAt") then
		return
	end
	local root = nearRoot(character)
	if root == nil then
		return
	end
	local mine = character == Players.LocalPlayer.Character
	-- The puff goes where the shove landed: between the two players when the shover is known.
	local contact = root.Position
	local by = character:GetAttribute("ShovedBy")
	local shover = if type(by) == "number" then Players:GetPlayerByUserId(by) else nil
	local shoverRoot = if shover ~= nil and shover.Character ~= nil
		then partOf(shover.Character, "HumanoidRootPart")
		else nil
	if shoverRoot ~= nil and (shoverRoot.Position - root.Position).Magnitude < 8 then
		contact = (root.Position + shoverRoot.Position) / 2
	end
	Particles.burst("hissPuff", contact, Presets.shove.puff)
	Particles.burst("kick", feetOf(character, root), Presets.motion.gait.dust + 1)
	local head = partOf(character, "Head")
	if head ~= nil then
		local t = Presets.tackle
		Shove.stars(head, tuning("TackledDownSeconds", t.downSeconds) + t.starsAfter)
	end
	if mine then
		Context.shake(Presets.shove.shake, Presets.shove.shakeStuds)
	end
end

-- A flat ribbon of dust along the ground under a character, drawn only while it moves.
local function streak(character: Model, root: BasePart): { Instance }
	local t = Presets.tackle
	local feet = Vector3.new(0, 0.15 - drop(character, root), 0) -- in the upright root's own axes
	local left = Instance.new("Attachment")
	left.Name = "EffectsTackleStreak"
	left.Position = feet - Vector3.new(t.streakWidth / 2, 0, 0)
	local right = Instance.new("Attachment")
	right.Name = "EffectsTackleStreak"
	right.Position = feet + Vector3.new(t.streakWidth / 2, 0, 0)
	local trail = Instance.new("Trail")
	trail.Name = "EffectsTackleStreak"
	trail.Attachment0 = left
	trail.Attachment1 = right
	trail.Lifetime = t.streakSeconds
	trail.MinLength = 0.05
	trail.Texture = Presets.textures.smoke
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Color = ColorSequence.new(Presets.palette.cream)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.4)
	trail.LightInfluence = 0.6
	left.Parent = root
	right.Parent = root
	trail.Parent = root
	return { trail, left, right }
end

-- The ribbon stops drawing and the dust already behind fades out before it goes.
local function endStreak(made: { Instance })
	for _, instance in made do
		if instance:IsA("Trail") then
			(instance :: Trail).Enabled = false
		end
		Debris:AddItem(instance, Presets.tackle.streakSeconds + 0.1)
	end
end

-- Follows a character for at most `seconds`, kicking `kick` particles of dust at its feet every `tackle.every` while
-- it moves along the ground at `speed` studs a second or faster. It ends once two looks in a row find it slower,
-- after it has gone that fast when `fastFirst`, then calls `done` with where it is.
local function follow(
	character: Model,
	root: BasePart,
	seconds: number,
	speed: number,
	kick: number,
	fastFirst: boolean,
	done: (Vector3) -> ()
)
	task.spawn(function()
		local t = Presets.tackle
		local ends = os.clock() + seconds
		local last = root.Position
		local went, slow = not fastFirst, 0
		while os.clock() < ends and root:IsDescendantOf(Workspace) do
			local dt = task.wait(t.every)
			local now = root.Position
			local moved = Vector3.new(now.X - last.X, 0, now.Z - last.Z).Magnitude
			last = now
			if moved >= speed * dt then
				went, slow = true, 0
				Particles.burst("kick", feetOf(character, root), kick)
			elseif went then
				slow += 1
				if slow >= 2 then
					break -- the lunge or the slide is over
				end
			end
		end
		done(feetOf(character, root))
	end)
end

-- The lunge: the ribbon and the kicks for as long as it runs fast, the hit window's grace at most.
local function lunge(character: Model)
	if not fresh(character, "TackleAt") then
		return
	end
	local root = nearRoot(character)
	if root == nil then
		return
	end
	local t = Presets.tackle
	local seconds = tuning("TackleLungeSeconds", t.lungeSeconds)
		+ tuning("TackleHitGraceSeconds", t.graceSeconds)
	local made = streak(character, root)
	follow(character, root, seconds, t.lungeSpeed, t.kick, true, function()
		endStreak(made)
	end)
end

-- A miss: dust kicked up while the tackler slides on their belly, and a puff where they stop.
local function missed(character: Model)
	if not fresh(character, "TackleMissAt") then
		return
	end
	local root = nearRoot(character)
	if root == nil then
		return
	end
	local t = Presets.tackle
	follow(character, root, t.skidSeconds, t.skidSpeed, t.skidKick, false, function(feet: Vector3)
		Particles.burst("dust", feet, t.skidDust)
	end)
end

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("ShovedAt"):Connect(function()
		play(character)
	end)
	character:GetAttributeChangedSignal("TackleAt"):Connect(function()
		lunge(character)
	end)
	character:GetAttributeChangedSignal("TackleMissAt"):Connect(function()
		missed(character)
	end)
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function Shove.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return Shove
