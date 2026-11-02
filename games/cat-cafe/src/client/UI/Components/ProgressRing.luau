--!strict
-- A ring that fills clockwise from twelve o'clock (F90, cats-make-orders.md section 2: the Barista's making
-- bubble). No image upload: two halves, each a clipped circle whose stroke carries a hard-edged UIGradient, the way
-- Roblox circular progress bars are usually built. Turning a half's gradient shows more of that half's stroke.
-- No Theme, so the cloud spec runner can load it.
--   ProgressRing.rotations(progress) -> (right, left)   the two gradients' Rotation for 0 to 1
--   ProgressRing.new(props)                               props: parent, color, thickness, zIndex?
--   ring:set(progress)                                    0 empty, 1 full
--   ring.frame                                            fills its parent; size and place it like any frame. The
--                                                         ring's outer edge is the frame's edge, `thickness` wide

local ProgressRing = {}
ProgressRing.__index = ProgressRing

export type Props = {
	parent: Instance,
	color: Color3,
	thickness: number,
	zIndex: number?,
}

export type ProgressRing = {
	frame: Frame,
	set: (self: ProgressRing, progress: number) -> (),
	destroy: (self: ProgressRing) -> (),
}

-- opaque on the first half of the gradient's axis, clear on the second (made on first use: the spec runner has
-- no NumberSequence)
local function halfSequence(): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- At Rotation r a half's gradient is opaque on the side its axis starts from, the line between turned r degrees
-- clockwise: 0 shows the left half, 90 the top, 180 the right. The right half fills over the first half of the
-- progress (0 to 180 degrees), the left half over the second (180 to 360).
function ProgressRing.rotations(progress: number): (number, number)
	local p = math.clamp(if progress == progress then progress else 0, 0, 1)
	local degrees = p * 360
	return math.min(degrees, 180), math.max(degrees, 180)
end

local function half(parent: Frame, name: string, x: number, props: Props): UIGradient
	local clip = Instance.new("Frame")
	clip.Name = name
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromScale(x, 0)
	clip.Size = UDim2.fromScale(0.5, 1)
	clip.ZIndex = props.zIndex or 1
	clip.Parent = parent
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.BackgroundTransparency = 1
	circle.BorderSizePixel = 0
	-- the whole circle, with only this half inside the clip, inset so its stroke (drawn outside its edge) ends at
	-- the ring's edge rather than past the clip
	local t = props.thickness
	circle.Position = UDim2.new(-2 * x, t, 0, t)
	circle.Size = UDim2.new(2, -2 * t, 1, -2 * t)
	circle.ZIndex = props.zIndex or 1
	circle.Parent = clip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = props.color
	stroke.Thickness = props.thickness
	stroke.Parent = circle
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = halfSequence()
	gradient.Parent = stroke
	return gradient
end

function ProgressRing.new(props: Props): ProgressRing
	local self = setmetatable({}, ProgressRing) :: any
	local frame = Instance.new("Frame")
	frame.Name = "Ring"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = props.zIndex or 1
	self.frame = frame
	self._right = half(frame, "Right", 0.5, props)
	self._left = half(frame, "Left", 0, props)
	self:set(0)
	frame.Parent = props.parent
	return self :: ProgressRing
end

function ProgressRing.set(self: any, progress: number)
	local right, left = ProgressRing.rotations(progress)
	self._right.Rotation = right
	self._left.Rotation = left
end

function ProgressRing.destroy(self: any)
	self.frame:Destroy()
end

return ProgressRing
