--!strict
-- The Dragon Keep's card deal (#4062; Design-Agent/notes/ticket-booth-and-dragon-keep.md 2.6): the three cards lie
-- face down and flip one at a time, about 0.4 s apart (the Legendary word ladder's beat). Each card's edge takes its
-- rarity's colour and pulses once as it turns; a Legendary gets a glint sweeping across its face and a burst of gold
-- rays behind it, a Mythic a rainbow edge that turns slowly and a bigger burst.
--
--   local stop = CardFlip.deal(cards, { "rare", "common", "legendary" }, onFlip, onDone)
--
-- The deal window is the UI's (Design-Agent). A card is any GuiObject with two children that fill it, `Back` (shown
-- first) and `Front` (hidden first); a card without them only pops. CardFlip sets the two up, so the window needs to
-- do nothing but build them. `onFlip(i)` runs as card i shows its face and `onDone` after the last; `stop()` ends it
-- at once with every face showing. Reduce Motion: the faces swap with no turn, no rays and no sweep. Nothing
-- flashes: a card turns once, its edge pulses once. Client only. In Studio the Workspace attribute DragonCardTest
-- ("rare,legendary,mythic") deals three stand-in cards (Review-QA).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local CardFlip = {}

-- The beats, for the sounds: "flip" as a card turns, "rare" as a Legendary or Mythic face shows. Listeners only
-- listen.
export type Beat = "flip" | "rare"
local listeners: { (beat: Beat, index: number, rarity: string) -> () } = {}

local TEST_ATTRIBUTE = "DragonCardTest"
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

function CardFlip.onBeat(listener: (beat: Beat, index: number, rarity: string) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat, index: number, rarity: string)
	for _, listener in listeners do
		task.spawn(listener, name, index, rarity)
	end
end

-- The edge colour of a card of `rarity` (Presets.dragonRise.cards.edges; an unknown one is a Common's).
function CardFlip.edgeColour(rarity: string): Color3
	local edges = Presets.dragonRise.cards.edges :: { [string]: Color3 }
	return edges[string.lower(rarity)] or edges.common
end

local function isTop(rarity: string): boolean
	local lower = string.lower(rarity)
	return lower == "legendary" or lower == "mythic"
end

local function face(card: GuiObject, name: string): GuiObject?
	local found = card:FindFirstChild(name)
	return if found ~= nil and found:IsA("GuiObject") then found :: GuiObject else nil
end

-- Centres a face in its card, so it can narrow to a line and widen again about its middle.
local function centre(side: GuiObject)
	side.AnchorPoint = Vector2.new(0.5, 0.5)
	side.Position = UDim2.fromScale(0.5, 0.5)
	side.Size = UDim2.fromScale(1, 1)
end

-- Lays `card` face down, ready to flip.
function CardFlip.faceDown(card: GuiObject)
	local back, front = face(card, "Back"), face(card, "Front")
	if back ~= nil then
		centre(back)
		back.Visible = true
	end
	if front ~= nil then
		centre(front)
		front.Visible = false
	end
end

-- The rarity edge on a card's face: a stroke in the rarity's colour, a Mythic's a rainbow that turns slowly.
local function edge(target: GuiObject, rarity: string): UIStroke
	local c = Presets.dragonRise.cards
	local old = target:FindFirstChild("RarityEdge")
	if old ~= nil then
		old:Destroy()
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "RarityEdge"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = c.edge
	stroke.Color = CardFlip.edgeColour(rarity)
	if string.lower(rarity) == "mythic" then
		stroke.Color = Color3.new(1, 1, 1)
		local keys: { ColorSequenceKeypoint } = {}
		for i, colour in c.rainbow do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / #c.rainbow, colour))
		end
		table.insert(keys, ColorSequenceKeypoint.new(1, c.rainbow[1]))
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Rainbow"
		gradient.Color = ColorSequence.new(keys)
		gradient.Parent = stroke
		if not Context.reducedMotion() then
			local turning: RBXScriptConnection
			turning = RunService.Heartbeat:Connect(function(dt: number)
				if gradient.Parent == nil or not gradient:IsDescendantOf(game) then
					turning:Disconnect()
					return
				end
				gradient.Rotation = (gradient.Rotation + c.rainbowTurn * dt) % 360
			end)
		end
	end
	stroke.Parent = target
	return stroke
end

-- The burst behind a Legendary or Mythic card: rays fanning out from its middle and fading, in a ScreenGui of its
-- own so no window clips them.
local function rays(card: GuiObject, rarity: string)
	local c = Presets.dragonRise.cards
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local host = card:FindFirstAncestorWhichIsA("LayerCollector")
	if playerGui == nil or Context.reducedMotion() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EffectsCardBurst"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- just under the deal's window, so the rays show round the card and not over it
	gui.DisplayOrder = if host ~= nil and host:IsA("ScreenGui")
		then (host :: ScreenGui).DisplayOrder - 1
		else 0
	local inset = if host ~= nil
			and host:IsA("ScreenGui")
			and not (host :: ScreenGui).IgnoreGuiInset
		then game:GetService("GuiService"):GetGuiInset()
		else Vector2.zero
	local middle = card.AbsolutePosition + card.AbsoluteSize / 2 + inset
	local reach = math.max(card.AbsoluteSize.X, card.AbsoluteSize.Y)
	local mythic = string.lower(rarity) == "mythic"
	local count = if Context.lite or Context.tier == "low" then c.rays // 2 else c.rays
	for i = 1, count do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromOffset(middle.X, middle.Y)
		ray.Size = UDim2.fromOffset(reach * 0.09, reach * 0.3)
		ray.Rotation = (i - 1) / count * 360
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = if mythic
			then c.rainbow[(i - 1) % #c.rainbow + 1]
			else CardFlip.edgeColour(rarity)
		ray.BackgroundTransparency = 0.25
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(1, 0)
		fade.Parent = ray
		ray.Parent = gui
		local info = TweenInfo.new(c.raySeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ray, info, {
			Size = UDim2.fromOffset(reach * 0.05, reach * (if mythic then 1.25 else 1)),
			BackgroundTransparency = 1,
			Rotation = ray.Rotation + 20,
		}):Play()
	end
	gui.Parent = playerGui
	task.delay(c.raySeconds + 0.1, function()
		gui:Destroy()
	end)
end

-- A Legendary's glint: a pale band sweeping once across the face.
local function sweep(front: GuiObject)
	local c = Presets.dragonRise.cards
	if Context.reducedMotion() then
		return
	end
	local clip = Instance.new("Frame")
	clip.Name = "GlintClip"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = front.ZIndex + 5
	local band = Instance.new("Frame")
	band.Name = "Glint"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(-0.3, 0.5)
	band.Size = UDim2.fromScale(0.22, 1.6)
	band.Rotation = 20
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BackgroundTransparency = 0.45
	band.Parent = clip
	clip.Parent = front
	local info = TweenInfo.new(c.sweepSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(band, info, { Position = UDim2.fromScale(1.3, 0.5) }):Play()
	task.delay(c.sweepSeconds + 0.05, function()
		clip:Destroy()
	end)
end

-- Flips one card to its face: the back narrows to a line, the face widens out with a little overshoot, the card
-- pops, and its edge takes the rarity's colour and pulses once. `turned` runs as the face shows. Returns a function
-- that finishes it at once.
function CardFlip.flip(
	card: GuiObject,
	rarity: string,
	index: number?,
	turned: (() -> ())?
): () -> ()
	local c = Presets.dragonRise.cards
	local back, front = face(card, "Back"), face(card, "Front")
	local done = false
	local tweens: { Tween } = {}
	local function play(target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
		local tween = TweenService:Create(target, info, goal)
		table.insert(tweens, tween)
		tween:Play()
		return tween
	end
	local scale = card:FindFirstChild("FlipScale")
	if scale == nil or not scale:IsA("UIScale") then
		local made = Instance.new("UIScale")
		made.Name = "FlipScale"
		made.Parent = card
		scale = made
	end
	local pop = scale :: UIScale

	local function show()
		if done then
			return
		end
		done = true
		for _, tween in tweens do
			tween:Cancel()
		end
		if back ~= nil then
			back.Visible = false
		end
		if front ~= nil then
			centre(front)
			front.Visible = true
		end
		pop.Scale = 1
		local stroke = edge(front or card, rarity)
		stroke.Thickness = c.edge
	end

	beat("flip", index or 1, rarity)
	if Context.reducedMotion() then
		show()
		if isTop(rarity) then
			beat("rare", index or 1, rarity)
		end
		if turned ~= nil then
			task.spawn(turned)
		end
		return show
	end

	task.spawn(function()
		if back ~= nil then
			centre(back)
			local shut = play(
				back,
				TweenInfo.new(c.shut, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.fromScale(0, 1) }
			)
			shut.Completed:Wait()
			if done then
				return
			end
			back.Visible = false
		end
		local target: GuiObject = front or card
		local stroke = edge(target, rarity)
		if front ~= nil then
			centre(front)
			front.Size = UDim2.fromScale(0, 1)
			front.Visible = true
			play(
				front,
				TweenInfo.new(c.open, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(1, 1) }
			)
		end
		-- the pop and the edge's one pulse
		pop.Scale = c.pop
		play(
			pop,
			TweenInfo.new(c.open + 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		stroke.Thickness = c.edgePulse
		play(
			stroke,
			TweenInfo.new(c.edgeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Thickness = c.edge }
		)
		if isTop(rarity) then
			beat("rare", index or 1, rarity)
			rays(card, rarity)
			if front ~= nil and string.lower(rarity) == "legendary" then
				sweep(front)
			end
		end
		if turned ~= nil then
			task.spawn(turned)
		end
	end)
	return show
end

-- Deals `cards` face down and flips them one at a time (Presets.dragonRise.cards.gap apart). `rarities[i]` is card
-- i's rarity. Returns the stop, which shows every face at once (onDone still runs, once).
function CardFlip.deal(
	cards: { GuiObject },
	rarities: { string },
	onFlip: ((index: number) -> ())?,
	onDone: (() -> ())?
): () -> ()
	local c = Presets.dragonRise.cards
	local stops: { () -> () } = {}
	local ended = false
	for _, card in cards do
		CardFlip.faceDown(card)
	end
	local function finish()
		if ended then
			return
		end
		ended = true
		if onDone ~= nil then
			task.spawn(onDone)
		end
	end
	local thread = task.spawn(function()
		for i, card in cards do
			task.wait(c.gap)
			if ended then
				return
			end
			stops[i] = CardFlip.flip(card, rarities[i] or "common", i, function()
				if onFlip ~= nil then
					onFlip(i)
				end
			end)
		end
		task.wait(c.shut + c.open + 0.1)
		finish()
	end)
	return function()
		if ended then
			return
		end
		pcall(task.cancel, thread)
		for i, card in cards do
			local stop = stops[i]
			if stop ~= nil then
				stop()
			else
				CardFlip.flip(card, rarities[i] or "common", i, nil)()
			end
		end
		finish()
	end
end

-- Studio only: DragonCardTest = "rare,legendary,mythic" deals three stand-in cards in the middle of the screen for
-- a few seconds (Review-QA).
if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(function()
		local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if type(value) ~= "string" or value == "" or playerGui == nil then
			return
		end
		local old = playerGui:FindFirstChild("EffectsCardTest")
		if old ~= nil then
			old:Destroy()
		end
		local rarities = string.split(value, ",")
		local gui = Instance.new("ScreenGui")
		gui.Name = "EffectsCardTest"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 30
		local cards: { GuiObject } = {}
		for i, rarity in rarities do
			local card = Instance.new("Frame")
			card.Name = "Card" .. i
			card.BackgroundTransparency = 1
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Position = UDim2.fromScale(0.5 + (i - (#rarities + 1) / 2) * 0.2, 0.5)
			card.Size = UDim2.fromScale(0.16, 0.42)
			for _, side in { "Back", "Front" } do
				local sheet = Instance.new("TextLabel")
				sheet.Name = side
				sheet.Size = UDim2.fromScale(1, 1)
				sheet.BorderSizePixel = 0
				sheet.BackgroundColor3 = if side == "Back"
					then Color3.fromRGB(120, 60, 40)
					else Color3.fromRGB(255, 244, 226)
				sheet.FontFace = FONT
				sheet.TextScaled = true
				sheet.TextColor3 = if side == "Back"
					then Color3.fromRGB(255, 214, 120)
					else Color3.fromRGB(80, 36, 20)
				sheet.Text = if side == "Back" then "?" else string.upper(rarity)
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.08, 0)
				corner.Parent = sheet
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0.12, 0)
				pad.PaddingRight = UDim.new(0.12, 0)
				pad.Parent = sheet
				sheet.Parent = card
			end
			card.Parent = gui
			table.insert(cards, card)
		end
		gui.Parent = playerGui
		CardFlip.deal(cards, rarities, nil, function()
			task.delay(4, function()
				gui:Destroy()
			end)
		end)
	end)
end

return CardFlip
