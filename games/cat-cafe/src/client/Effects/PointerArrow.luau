--!strict
-- The gold world arrow that points down over a cat (#5594 firstCatArrow, #5649 parkCatArrow), as one builder so other
-- pointers share its look (#5715 tier3Pointer draws it 1.3 times as big on a tablet). A "▼" in gold with a cocoa
-- outline, `size` pixels square at scale 1, always on top. PointerArrow.over(model) and PointerArrow.bob(t, still)
-- place it: `above` studs over the top of the model, bobbing `bob` studs up and down (still with Reduce Motion).

local PointerArrow = {}

PointerArrow.SIZE = 64 -- pixels at scale 1
PointerArrow.ABOVE = 2.6 -- studs over the top of the cat, clear of its name tag (Effects/CatNames)
PointerArrow.BOB = 0.45 -- studs up and down
PointerArrow.SPEED = 5 -- radians a second
PointerArrow.GOLD = Color3.fromRGB(255, 200, 40)
PointerArrow.OUTLINE = Color3.fromRGB(60, 35, 10)

-- The arrow's side in pixels at `scale`. Pure.
function PointerArrow.pixels(scale: number): number
	return math.floor(PointerArrow.SIZE * scale + 0.5)
end

-- A hidden arrow, `scale` times the usual size, seen up to `reach` studs away.
function PointerArrow.build(name: string, scale: number, reach: number): BillboardGui
	local px = PointerArrow.pixels(scale)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(px, px)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.MaxDistance = reach
	gui.Enabled = false
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = PointerArrow.GOLD
	local stroke = Instance.new("UIStroke")
	stroke.Color = PointerArrow.OUTLINE
	stroke.Thickness = math.max(2, math.floor(3 * scale + 0.5))
	stroke.Parent = arrow
	arrow.Parent = gui
	return gui
end

-- How far over `at` (the arrow's Adornee part) the arrow sits for `model`: the top of its box plus ABOVE.
function PointerArrow.over(model: Model, at: BasePart): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y + size.Y / 2 - at.Position.Y + PointerArrow.ABOVE
end

-- The bob in studs at `t` seconds; 0 with Reduce Motion. Pure.
function PointerArrow.bob(t: number, still: boolean): number
	return if still then 0 else math.sin(t * PointerArrow.SPEED) * PointerArrow.BOB
end

-- The part an arrow over `model` hangs on: its PrimaryPart, else its first BasePart.
function PointerArrow.partOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local found = model:FindFirstChildWhichIsA("BasePart", true)
	return if found ~= nil then found :: BasePart else nil
end

return PointerArrow
