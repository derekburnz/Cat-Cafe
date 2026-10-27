--!strict
-- A shove (design v0.5, F41): a puff where it lands, a skid of dust at the shoved player's feet and dizzy stars
-- circling their head, and for the shoved player a camera bump bigger than a missed catch. The knockback itself is
-- the engineer's, applied on the shoved player's own client; this only draws it.
--
-- Source: the shoved player's character carries `ShovedAt` (server time of the shove) and, when the server sets
-- it, `ShovedBy` (the shover's UserId), so every player nearby sees it. Listening only: nothing here fires a
-- remote.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Shove = {}

type Stars = { labels: { TextLabel }, began: number }

local LATE_SECONDS = 0.6 -- a shove that replicates later than this is over; nothing plays
local DARK_WOOD = Color3.fromRGB(94, 70, 52)

local spinning: { Stars } = {}
local spinLoop: RBXScriptConnection? = nil
local started = false

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	return if part ~= nil and part:IsA("BasePart") then part :: BasePart else nil
end

local function spin()
	local s = Presets.shove
	local now = os.clock()
	local still = Context.reducedMotion()
	local i = 1
	while i <= #spinning do
		local stars = spinning[i]
		local age = now - stars.began
		if age >= s.starSeconds then
			spinning[i] = spinning[#spinning]
			spinning[#spinning] = nil
		else
			local fade = math.clamp((age - (s.starSeconds - 0.3)) / 0.3, 0, 1)
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

-- Dizzy stars over a head, gone after shove.starSeconds.
local function stars(head: BasePart)
	local s = Presets.shove
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
	Debris:AddItem(gui, s.starSeconds + 0.1)
	table.insert(spinning, { labels = labels, began = os.clock() })
	if spinLoop == nil then
		spinLoop = RunService.PreRender:Connect(spin)
	end
end

local function play(character: Model)
	local at = character:GetAttribute("ShovedAt")
	if type(at) ~= "number" or Workspace:GetServerTimeNow() - at >= LATE_SECONDS then
		return
	end
	local root = partOf(character, "HumanoidRootPart")
	if root == nil then
		return
	end
	local mine = character == Players.LocalPlayer.Character
	if not mine and Context.distance(root.Position) > Context.budget.ambientRadius then
		return
	end
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
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	Particles.burst(
		"kick",
		root.Position - Vector3.new(0, hip + root.Size.Y / 2, 0),
		Presets.motion.gait.dust + 1
	)
	local head = partOf(character, "Head")
	if head ~= nil then
		stars(head)
	end
	if mine then
		Context.shake(Presets.shove.shake, Presets.shove.shakeStuds)
	end
end

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("ShovedAt"):Connect(function()
		play(character)
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
