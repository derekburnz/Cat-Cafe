--!strict
-- The store's motion (#1823, store remake v2; UI-Engineer calls these from the Store screen): a pressed button dips
-- and springs back, and a card just bought pops, flashes and throws a few gold sparks. Each works through a UIScale on
-- the object (its own if it has one, scaled from that UIScale's own value) and a few short lived frames inside the
-- card, so nothing about the UI's layout changes. Both do nothing with Reduce Motion. Numbers in
-- Presets.storeMotion. Client only; nothing here fires a remote.

local TweenService = game:GetService("TweenService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local StoreMotion = {}

local SCALE = "StoreMotionScale"
local BASE = "StoreMotionBase"

-- the scale tween running on each object, so a new press replaces it instead of fighting it
local running: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any

-- The UIScale this module moves on `object` and the value it rests at.
local function scaleOf(object: GuiObject): (UIScale, number)
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale == nil then
		local made = Instance.new("UIScale")
		made.Name = SCALE
		made.Parent = object
		scale = made
	end
	local found = scale :: UIScale
	local base = found:GetAttribute(BASE)
	if type(base) ~= "number" then
		base = found.Scale
		found:SetAttribute(BASE, base)
	end
	return found, base :: number
end

-- Tweens `object`'s scale through `steps` ({ multiple of its rest scale, seconds, style }), one after the other.
local function scaleThrough(object: GuiObject, steps: { { any } })
	local scale, base = scaleOf(object)
	local old: Tween? = running[object]
	if old then
		old:Cancel()
	end
	local i = 0
	local function nextStep()
		i += 1
		local step = steps[i]
		if step == nil or object.Parent == nil then
			running[object] = nil
			return
		end
		local info = TweenInfo.new(step[2], step[3], Enum.EasingDirection.Out)
		local tween = TweenService:Create(scale, info, { Scale = base * step[1] })
		running[object] = tween
		tween.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and running[object] == tween then
				nextStep()
			end
		end)
		tween:Play()
	end
	nextStep()
end

-- A pressed button dips and springs back.
function StoreMotion.press(button: GuiButton)
	if Context.reducedMotion() then
		return
	end
	local p = Presets.storeMotion.press
	scaleThrough(button, {
		{ p.dip, p.down, Enum.EasingStyle.Quad },
		{ 1, p.up, Enum.EasingStyle.Back },
	})
end

-- A card just bought pops, flashes white and throws a few gold sparks from its middle.
function StoreMotion.bought(card: GuiObject)
	if Context.reducedMotion() then
		return
	end
	local b = Presets.storeMotion.bought
	scaleThrough(card, {
		{ b.pop, b.grow, Enum.EasingStyle.Back },
		{ 1, b.settle, Enum.EasingStyle.Quad },
	})

	local flash = Instance.new("Frame")
	flash.Name = "StoreMotionFlash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = b.flash
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = card.ZIndex + 5
	local corner = card:FindFirstChildOfClass("UICorner")
	if corner ~= nil then
		corner:Clone().Parent = flash
	end
	flash.Parent = card
	local fade = TweenService:Create(
		flash,
		TweenInfo.new(b.flashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	fade.Completed:Connect(function()
		flash:Destroy()
	end)
	fade:Play()

	for k = 1, b.sparks do
		local offset = Logic.sparkOut(k, b.sparks, b.reach)
		local spark = Instance.new("Frame")
		spark.Name = "StoreMotionSpark"
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromScale(0.5, 0.5)
		spark.Size = UDim2.fromOffset(b.sparkSize, b.sparkSize)
		spark.Rotation = 45
		spark.BackgroundColor3 = b.colour
		spark.BorderSizePixel = 0
		spark.ZIndex = card.ZIndex + 6
		spark.Parent = card
		local fly = TweenService:Create(
			spark,
			TweenInfo.new(b.sparkSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
				BackgroundTransparency = 1,
				Rotation = 135,
			}
		)
		fly.Completed:Connect(function()
			spark:Destroy()
		end)
		fly:Play()
	end
end

return StoreMotion
