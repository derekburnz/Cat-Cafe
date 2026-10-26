--!strict
-- Small animation helpers. All tweens are short so the UI never feels like it is waiting.

local TweenService = game:GetService("TweenService")

local Tween = {}

Tween.FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Tween.POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Tween.SETTLE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Tween.RISE = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Tween.to(instance: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

-- Scales a GuiObject in from `from` to 1 using a UIScale child (created if missing).
local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChildOfClass("UIScale")
	if existing and existing:IsA("UIScale") then
		return existing :: UIScale
	end
	local created = Instance.new("UIScale")
	created.Parent = gui
	return created
end

function Tween.popIn(gui: GuiObject, from: number?)
	local scale = scaleOf(gui)
	scale.Scale = from or 0.88
	Tween.to(scale, Tween.POP, { Scale = 1 })
end

function Tween.popOut(gui: GuiObject, onDone: (() -> ())?)
	local scale = scaleOf(gui)
	local tween = Tween.to(scale, Tween.SETTLE, { Scale = 0.9 })
	if onDone then
		tween.Completed:Once(function()
			onDone()
		end)
	end
end

-- Quick squash on press, used by Button.
function Tween.press(scale: UIScale, down: boolean)
	Tween.to(scale, Tween.FAST, { Scale = if down then 0.95 else 1 })
end

return Tween
