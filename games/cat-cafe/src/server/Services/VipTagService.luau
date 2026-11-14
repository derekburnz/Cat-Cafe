--!strict
-- #4235 (Derek 2026-11-14 17:09 UTC, priority: "make vip +50% money and a hovering vip tag about their head"): a gold
-- VIP tag floats over every VIP owner's head, seen by everyone, behind the `vipBoost` switch (on unless switched off).
-- Built on the server so it replicates to every player; it is put back on each new character, appears the moment the
-- pass is bought in game, and comes off when the switch is turned off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local PassService = require(script.Parent.PassService)

local VipTagService = {}

VipTagService.NAME = "VipTag"
local GOLD = Color3.fromRGB(255, 200, 60)
local GOLD_DARK = Color3.fromRGB(196, 132, 20)
local INK = Color3.fromRGB(58, 34, 12)

-- The tag itself: a gold rounded plate with a dark outline and "VIP" in thick white letters, sized in studs
-- (scale) so it shrinks with distance like the world, above Roblox's own name line.
function VipTagService.build(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = VipTagService.NAME
	gui.Size = UDim2.fromScale(2.6, 1.05)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = GOLD
	plate.BorderSizePixel = 0
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.35, 0)
	corner.Parent = plate
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(GOLD, GOLD_DARK)
	gradient.Rotation = 90
	gradient.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 2.5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.78)
	label.Font = Enum.Font.FredokaOne
	label.Text = "👑 VIP"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = plate
	local ink = Instance.new("UIStroke")
	ink.Color = INK
	ink.Thickness = 2
	ink.Parent = label
	return gui
end

local function on(): boolean
	return Economy.vipBoost()
end

local function owns(player: Player): boolean
	return Config.VipPassId ~= 0 and PassService.owns(player, Config.VipPassId)
end

-- Puts the tag on (or takes it off) `player`'s current character to match the pass and the switch.
function VipTagService.refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local tag: Instance? = head:FindFirstChild(VipTagService.NAME)
	local want = on() and owns(player)
	if want and not tag then
		local gui = VipTagService.build()
		gui.Adornee = head
		gui.Parent = head
	elseif not want and tag then
		tag:Destroy()
	end
end

function VipTagService.start()
	local function watch(player: Player)
		local function follow(character: Model)
			-- Review-QA (Studio): Roblox's avatar load swaps the Head part just after CharacterAdded and the tag went
			-- with the old one, so the tag follows every new Head, and the appearance load, too
			character.ChildAdded:Connect(function(child: Instance)
				if child.Name == "Head" then
					task.defer(VipTagService.refresh, player)
				end
			end)
			character:WaitForChild("Head", 10)
			VipTagService.refresh(player)
			-- the join's pass lookup can answer after the spawn without firing `changed`: look again a few times
			for _, after in { 2, 5, 12 } do
				task.delay(after, function()
					if player.Character == character then
						VipTagService.refresh(player)
					end
				end)
			end
		end
		player.CharacterAdded:Connect(follow)
		player.CharacterAppearanceLoaded:Connect(function()
			VipTagService.refresh(player)
		end)
		local character = player.Character
		if character ~= nil then
			task.spawn(follow, character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- the join lookup answers after the character can already be in, and a purchase in game: both fire `changed`
	PassService.changed:Connect(function(player: Player)
		task.defer(VipTagService.refresh, player)
	end)
	-- the switch flipped: every player's tag follows
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Economy.VIP_BOOST_FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				VipTagService.refresh(player)
			end
		end)
end

return VipTagService
