--!strict
-- The rainbow coat's slowly turning bands on the UI (F99, rainbow-coat.md section 2): a UIGradient of Theme.rainbow
-- on a card's edge (a UIStroke), on a word ("RAINBOW") or on a chip's fill. One Heartbeat turns every live gradient
-- a little each frame; with Roblox's Reduce Motion on the bands stand still and the colours stay. A gradient leaves
-- the loop once it is destroyed with its card, and the loop stops while none are left.
--   Rainbow.stroke(stroke)    paints a UIStroke's edge in the bands (its Color goes white so they show true)
--   Rainbow.text(label)       the same on a label's text (for a label with no fill of its own)
--   Rainbow.fill(frame)       the same on a frame's fill; give its text a dark colour, which the bands barely tint
-- Each returns its UIGradient, so a reused card can switch it with `Enabled`.
--
-- Roblox terms: a UIGradient under a GuiObject (or a UIStroke) tints it from one side to the other with a colour
-- sequence; turning its Rotation turns the bands.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local Rainbow = {}

local SPEED = 45 -- degrees a second: one full turn in 8 s

local live: { [UIGradient]: true } = {}
local loop: RBXScriptConnection? = nil

local function step(dt: number)
	local any = false
	local still = GuiService.ReducedMotionEnabled
	for gradient in live do
		if gradient.Parent == nil then
			live[gradient] = nil -- destroyed with its card
		else
			any = true
			if not still and gradient.Enabled then
				gradient.Rotation = (gradient.Rotation + SPEED * dt) % 360
			end
		end
	end
	if not any and loop ~= nil then
		loop:Disconnect()
		loop = nil
	end
end

local function add(parent: Instance): UIGradient
	local gradient: UIGradient = Create("UIGradient", {
		Name = "Rainbow",
		Color = Theme.rainbow,
		Rotation = 0,
		Parent = parent,
	})
	live[gradient] = true
	if loop == nil then
		loop = RunService.Heartbeat:Connect(step)
	end
	return gradient
end

function Rainbow.stroke(stroke: UIStroke): UIGradient
	stroke.Color = Theme.colors.white
	return add(stroke)
end

function Rainbow.text(label: TextLabel): UIGradient
	label.TextColor3 = Theme.colors.white
	return add(label)
end

function Rainbow.fill(frame: GuiObject): UIGradient
	frame.BackgroundColor3 = Theme.colors.white
	return add(frame)
end

return Rainbow
