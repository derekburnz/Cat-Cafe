--!strict
-- Effects drawn on this player's screen over the UI (F101's Rally pops into the banner's bar, F102's Trade done
-- flight into the cat room): one effects ScreenGui per moment, where a UI object stands in that ScreenGui's pixels
-- (whatever insets either keeps), whether a UI object shows at all, and small sparkle and ring pops. It only reads the
-- UI; it never changes a UI object.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Logic = require(script.Parent.Logic)

local ScreenFx = {}

type Spark = { frame: Frame, from: Vector2, way: Vector2, reach: number, size: number, delay: number }

local guis: { [string]: ScreenGui } = {}
local rng = Random.new()

-- This client's effects ScreenGui `name` at `displayOrder`, made once and kept across respawns; nil before the
-- PlayerGui exists. An empty `Origin` frame at its top left measures where its pixels start.
function ScreenFx.gui(name: string, displayOrder: number): ScreenGui?
	local existing: ScreenGui? = guis[name]
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local made = Instance.new("ScreenGui")
	made.Name = name
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = displayOrder
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local origin = Instance.new("Frame")
	origin.Name = "Origin"
	origin.BackgroundTransparency = 1
	origin.Size = UDim2.fromOffset(0, 0)
	origin.Parent = made
	made.Parent = playerGui
	guis[name] = made
	return made
end

-- An absolute screen point (from a UI object's AbsolutePosition) as an offset in `gui`.
function ScreenFx.toGui(gui: ScreenGui, absolute: Vector2): Vector2
	local origin = gui:FindFirstChild("Origin")
	if origin ~= nil and origin:IsA("GuiObject") then
		return absolute - (origin :: GuiObject).AbsolutePosition
	end
	return absolute
end

-- The middle of `object` in `gui`'s pixels.
function ScreenFx.centre(gui: ScreenGui, object: GuiObject): Vector2
	return ScreenFx.toGui(gui, object.AbsolutePosition + object.AbsoluteSize / 2)
end

-- Whether `object` shows: it has a size, it and every GuiObject it sits in are visible, and its ScreenGui is on and
-- in this player's PlayerGui.
function ScreenFx.shown(object: GuiObject): boolean
	if object.AbsoluteSize.X < 1 or object.AbsoluteSize.Y < 1 then
		return false
	end
	local at: Instance? = object
	while at ~= nil do
		if at:IsA("GuiObject") and not (at :: GuiObject).Visible then
			return false
		end
		if at:IsA("LayerCollector") then
			return (at :: LayerCollector).Enabled and at:IsDescendantOf(Players.LocalPlayer)
		end
		at = at.Parent
	end
	return false
end

-- Whether `object` is in this player's PlayerGui with a size, shown or just hidden.
function ScreenFx.placed(object: GuiObject): boolean
	return object.AbsoluteSize.X >= 1 and object:IsDescendantOf(Players.LocalPlayer)
end

local function diamond(gui: ScreenGui, colour: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Sparkle"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = colour
	frame.Rotation = 45 -- a little diamond
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Parent = gui
	return frame
end

-- One small diamond in `colour` for each of `spots` (pixels in `gui`), each flying out from its spot a random way up
-- to `reach` pixels, popping in and out over `seconds`, the n-th waiting up to `stagger` seconds. One loop for them
-- all.
function ScreenFx.sparkle(
	gui: ScreenGui,
	spots: { Vector2 },
	colour: Color3,
	o: { size: number, seconds: number, reach: number, stagger: number }
)
	if #spots == 0 then
		return
	end
	local sparks: { Spark } = {}
	for _, spot in spots do
		local angle = rng:NextNumber(0, 2 * math.pi)
		table.insert(sparks, {
			frame = diamond(gui, colour),
			from = spot,
			way = Vector2.new(math.cos(angle), math.sin(angle)),
			reach = o.reach * rng:NextNumber(0.5, 1),
			size = o.size * rng:NextNumber(0.6, 1),
			delay = rng:NextNumber(0, o.stagger),
		})
	end
	local began = os.clock()
	local last = o.seconds + o.stagger
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= last or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			for _, s in sparks do
				s.frame:Destroy()
			end
			return
		end
		for _, s in sparks do
			local k = (t - s.delay) / o.seconds
			local on = k > 0 and k < 1
			s.frame.Visible = on
			if on then
				local out = 1 - (1 - k) * (1 - k)
				local at = s.from + s.way * (s.reach * out)
				local grow = s.size * math.sin(math.pi * k)
				s.frame.Position = UDim2.fromOffset(at.X, at.Y)
				s.frame.Size = UDim2.fromOffset(grow, grow)
			end
		end
	end)
end

-- A thin ring in `colour` round `at` (pixels in `gui`) growing from `from` to `to` pixels across as it fades over
-- `seconds`.
function ScreenFx.ring(
	gui: ScreenGui,
	at: Vector2,
	from: number,
	to: number,
	colour: Color3,
	seconds: number
)
	local frame = Instance.new("Frame")
	frame.Name = "Ring"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(at.X, at.Y)
	frame.Size = UDim2.fromOffset(from, from)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 3
	stroke.Parent = frame
	frame.Parent = gui
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / seconds
		if k >= 1 or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			frame:Destroy()
			return
		end
		local across = from + (to - from) * Logic.easeInOut(k)
		frame.Size = UDim2.fromOffset(across, across)
		stroke.Transparency = k
	end)
end

return ScreenFx
