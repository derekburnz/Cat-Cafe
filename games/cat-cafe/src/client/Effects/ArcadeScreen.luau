--!strict
-- The Cat Arcade cabinet's attract screen (Derek 2026-11-18: "make the cat arcade screen show something"). The
-- cabinet (tagged "ArcadeCabinet", WorldBuilder) has a part named `Screen` (Model-Agent's 2.4 x 1.9 stud
-- CatCafe_Town_ArcadeCabinet_Screen, front -Z) that showed only a flat colour. This puts a SurfaceGui on its front
-- that plays a little Mouse Dash on a loop: the cellar floor, three holes, a mouse popping up from one hole after
-- another (now and then the golden one), the cat's paw bopping one with a puff of dust, and PRESS PLAY blinking
-- underneath. The pictures are Mouse Dash's own uploaded sheet and floor (the group's, the same ids as
-- UI/Components/MouseDashLogic SHEET and BACKDROP).
-- Past `within` studs, and with Reduce Motion, it holds a still frame (one mouse up, PRESS PLAY on). It glows
-- (LightInfluence 0) so it reads at night. This client only; listening only, nothing sent.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)

local ArcadeScreen = {}

local TAG = "ArcadeCabinet"
local GUI_NAME = "CatCafeArcadeAttract"
local FONT_ID = "rbxasset://fonts/families/FredokaOne.json"

type Hole = { clip: Frame, mouse: ImageLabel, dust: ImageLabel }
type Screen = {
	gui: SurfaceGui,
	part: BasePart,
	holes: { Hole },
	paw: ImageLabel,
	prompt: TextLabel,
	beat: number,
}

local screens: { [Instance]: Screen } = {}
local started = false

local function cell(image: ImageLabel, name: string)
	local p = Presets.arcadeScreen
	local at = p.cells[name]
	image.Image = p.sheet
	image.ImageRectSize = Vector2.new(p.cell, p.cell)
	image.ImageRectOffset = if at ~= nil then Vector2.new(at[1], at[2]) else Vector2.zero
end

local function picture(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2,
	anchor: Vector2
): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = anchor
	image.Size = size
	image.Position = position
	cell(image, name)
	image.Parent = parent
	return image
end

-- What the n-th beat does: which hole (1 to `holes`), which mouse ("Mouse" or "GoldMouse") and whether the paw bops
-- it. Pure, so the loop's pattern is fixed: every `bopEvery`-th beat bops, every `goldEvery`-th mouse is golden.
function ArcadeScreen.beatAt(
	n: number,
	holes: number,
	p: typeof(Presets.arcadeScreen)
): (number, string, boolean)
	local hole = (n * 2) % holes + 1 -- 1, 3, 2, 1, 3, 2 for three holes: never the same hole twice running
	local kind = if n % p.goldEvery == p.goldEvery - 1 then "GoldMouse" else "Mouse"
	local bop = n % p.bopEvery == p.bopEvery - 1
	return hole, kind, bop
end

local function build(part: BasePart): Screen
	local p = Presets.arcadeScreen
	local old = part:FindFirstChild(GUI_NAME)
	if old ~= nil then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = GUI_NAME
	gui.Face = Enum.NormalId.Front -- the screen faces -Z
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = p.pixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = p.brightness
	gui.MaxDistance = p.maxDistance
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	local floor = Instance.new("ImageLabel")
	floor.Name = "Floor"
	floor.BackgroundColor3 = p.night
	floor.BorderSizePixel = 0
	floor.Size = UDim2.fromScale(1, 1)
	floor.Image = p.backdrop
	floor.ImageColor3 = p.floorTint
	floor.ScaleType = Enum.ScaleType.Crop
	floor.Parent = gui
	local holes: { Hole } = {}
	for i = 1, p.holes do
		local x = (i - 0.5) / p.holes
		picture(
			"Hole",
			floor,
			UDim2.fromScale(p.holeSize, p.holeSize),
			UDim2.fromScale(x, p.holeY),
			Vector2.new(0.5, 0.5)
		)
		-- the mouse rises out of the hole: a clip whose bottom is the hole's middle
		local clip = Instance.new("Frame")
		clip.Name = "Rise"
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.AnchorPoint = Vector2.new(0.5, 1)
		clip.Size = UDim2.fromScale(p.holeSize, p.holeSize * 1.1)
		clip.Position = UDim2.fromScale(x, p.holeY + p.holeSize * 0.08)
		clip.Parent = floor
		local mouse = picture(
			"Mouse",
			clip,
			UDim2.fromScale(0.9, 0.9),
			UDim2.fromScale(0.5, 1.95),
			Vector2.new(0.5, 1)
		)
		local dust = picture(
			"Dust",
			floor,
			UDim2.fromScale(p.holeSize * 1.2, p.holeSize * 1.2),
			UDim2.fromScale(x, p.holeY - 0.1),
			Vector2.new(0.5, 0.5)
		)
		dust.ImageTransparency = 1
		table.insert(holes, { clip = clip, mouse = mouse, dust = dust })
	end
	local paw = picture(
		"Paw",
		floor,
		UDim2.fromScale(p.holeSize, p.holeSize),
		UDim2.fromScale(0.5, -0.4),
		Vector2.new(0.5, 1)
	)
	paw.ZIndex = 3
	local prompt = Instance.new("TextLabel")
	prompt.Name = "Prompt"
	prompt.BackgroundTransparency = 1
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.Position = UDim2.fromScale(0.5, 0.97)
	prompt.Size = UDim2.fromScale(0.9, 0.17)
	prompt.FontFace = Font.new(FONT_ID, Enum.FontWeight.Bold)
	prompt.TextScaled = true
	prompt.TextColor3 = p.gold
	prompt.Text = p.text
	local stroke = Instance.new("UIStroke")
	stroke.Color = p.ink
	stroke.Thickness = 2
	stroke.Parent = prompt
	prompt.Parent = floor
	gui.Parent = part
	-- the still frame: the middle mouse up
	local middle = holes[math.ceil(p.holes / 2)]
	if middle ~= nil then
		middle.mouse.Position = UDim2.fromScale(0.5, 1)
	end
	return { gui = gui, part = part, holes = holes, paw = paw, prompt = prompt, beat = 0 }
end

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

local function alive(s: Screen): boolean
	local parent: Instance? = s.gui.Parent
	return parent ~= nil
end

local function play(s: Screen)
	local p = Presets.arcadeScreen
	local holeIndex, kind, bop = ArcadeScreen.beatAt(s.beat, #s.holes, p)
	s.beat += 1
	s.prompt.Visible = s.beat % 3 ~= 0 -- blinks: on two beats, off one
	for _, h in s.holes do
		tween(h.mouse, p.down, { Position = UDim2.fromScale(0.5, 1.95) })
	end
	local hole = s.holes[holeIndex]
	if hole == nil then
		return
	end
	task.delay(p.down, function()
		if not alive(s) then
			return
		end
		cell(hole.mouse, kind)
		tween(hole.mouse, p.up, { Position = UDim2.fromScale(0.5, 1) }, Enum.EasingStyle.Back)
		if not bop then
			return
		end
		task.delay(p.up + p.wait, function()
			if not alive(s) then
				return
			end
			local x = hole.clip.Position.X.Scale
			s.paw.Position = UDim2.fromScale(x, -0.4)
			cell(s.paw, "PawBop")
			tween(s.paw, p.bop, { Position = UDim2.fromScale(x, p.holeY - p.holeSize * 0.15) })
			task.delay(p.bop, function()
				if not alive(s) then
					return
				end
				cell(hole.mouse, if kind == "GoldMouse" then "GoldMouseHit" else "MouseHit")
				hole.dust.ImageTransparency = 0
				tween(hole.dust, p.dust, { ImageTransparency = 1 })
				tween(s.paw, p.bop * 1.5, { Position = UDim2.fromScale(x, -0.4) })
			end)
		end)
	end)
end

local function added(instance: Instance)
	if screens[instance] ~= nil then
		return
	end
	local found = instance:FindFirstChild(Presets.arcadeScreen.part, true)
	if found == nil or not found:IsA("BasePart") then
		return
	end
	screens[instance] = build(found :: BasePart)
end

local function step()
	local p = Presets.arcadeScreen
	local still = Context.reducedMotion()
	-- a cabinet can stream in before its Screen part, or lose and regain it: try again each beat (one cabinet)
	for _, instance in CollectionService:GetTagged(TAG) do
		if screens[instance] == nil then
			added(instance)
		end
	end
	for instance, s in screens do
		if not instance:IsDescendantOf(game) or s.part.Parent == nil then
			s.gui:Destroy()
			screens[instance] = nil
			continue
		end
		if still or Context.distance(s.part.Position) > p.within then
			s.prompt.Visible = true
			continue
		end
		play(s)
	end
end

function ArcadeScreen.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(TAG) do
		added(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(added)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		local s = screens[instance]
		if s ~= nil then
			s.gui:Destroy()
			screens[instance] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Presets.arcadeScreen.beat)
			step()
		end
	end)
end

return ArcadeScreen
