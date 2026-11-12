--!strict
-- The Cat Arcade's pops (#3062, Circle Streak; Gameplay-Engineer's arcade window calls them). Each is a short burst on
-- this player's screen round a UI object the window hands over, drawn on its own effects ScreenGui; it never changes
-- a UI object, sends nothing to the server and shows no toast.
--   ArcadeFx.hit(target, grade)          a ring tap: "perfect" a gold ring, sparkles and "Perfect!"; "good" a mint
--                                        ring and "Good"; "miss" a grey "Miss" that rises and fades
--   ArcadeFx.milestone(target, points)   every 10 points: two gold rings, a big sparkle and the points rising
--   ArcadeFx.goldenFish(target)          the run's golden fish: a 🐟 hops up off the target with a few sparkles
--   ArcadeFx.shine(face, corner)          #3338: a soft white band sweeps across the Play button now and then; returns
--                                        a switch (on while a game can start). Its only change to the window is one
--                                        see-through "Shine" frame laid over the face; none with Reduce Motion.
-- Reduce Motion: no rings and half the sparkles, the words fade where they are. Low performance: half the sparkles.
-- A target that isn't on screen plays nothing. Numbers in Presets.arcade.

local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local ArcadeFx = {}

local GUI_NAME = "EffectsArcade"
local FONT_ID = "rbxasset://fonts/families/FredokaOne.json"

export type Grade = "perfect" | "good" | "miss"

export type Burst = { colour: Color3, sparkles: number, rings: number, ringGap: number? }

-- `count` spots round the middle of `target` (pixels in `gui`), a little inside its edge.
local function spots(gui: ScreenGui, target: GuiObject, count: number): { Vector2 }
	local out: { Vector2 } = {}
	local middle = ScreenFx.centre(gui, target)
	local radius = math.min(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 0.35
	for i = 1, count do
		local angle = (i - 0.5) / count * 2 * math.pi
		table.insert(out, middle + Vector2.new(math.cos(angle), math.sin(angle)) * radius)
	end
	return out
end

-- (Also used by MouseDashFx, #3296, like word and ready below.)
-- Sparkles and rings round `target`, fewer with Reduce Motion or Low performance, no rings with Reduce Motion.
function ArcadeFx.burst(gui: ScreenGui, target: GuiObject, b: Burst)
	local s = Presets.arcade
	local still = Context.reducedMotion()
	local count = b.sparkles
	if still or Context.lowPerformance then
		count = math.ceil(count / 2)
	end
	if count > 0 then
		ScreenFx.sparkle(gui, spots(gui, target, count), b.colour, {
			size = s.sparkSize,
			seconds = s.sparkSeconds,
			reach = s.reach,
			stagger = s.sparkStagger,
		})
	end
	if still or b.rings <= 0 then
		return
	end
	local middle = ScreenFx.centre(gui, target)
	local across = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y)
	for ring = 1, b.rings do
		task.delay((ring - 1) * (b.ringGap or 0), function()
			ScreenFx.ring(
				gui,
				middle,
				across * s.ringFrom,
				across * s.ringTo,
				b.colour,
				s.ringSeconds
			)
		end)
	end
end

-- Outlined words in `colour` over the middle of `target` that rise (still with Reduce Motion) and fade.
function ArcadeFx.word(
	gui: ScreenGui,
	target: GuiObject,
	text: string,
	colour: Color3,
	size: number
)
	local s = Presets.arcade
	local from = ScreenFx.centre(gui, target)
	local label = Instance.new("TextLabel")
	label.Name = "ArcadeWord"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(size * 6, size + 8)
	label.Position = UDim2.fromOffset(from.X, from.Y)
	label.FontFace = Font.new(FONT_ID, Enum.FontWeight.Bold)
	label.TextSize = size
	label.TextColor3 = colour
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(42, 28, 21)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	local rise = if Context.reducedMotion() then 0 else s.wordRise
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / s.wordSeconds
		if k >= 1 or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			label:Destroy()
			return
		end
		local out = 1 - (1 - k) * (1 - k)
		label.Position = UDim2.fromOffset(from.X, from.Y - rise * out)
		local fade = math.max(0, (k - 0.5) * 2)
		label.TextTransparency = fade
		stroke.Transparency = fade
	end)
end

function ArcadeFx.ready(target: GuiObject): ScreenGui?
	if not ScreenFx.shown(target) then
		return nil
	end
	return ScreenFx.gui(GUI_NAME, Presets.arcade.displayOrder)
end

function ArcadeFx.hit(target: GuiObject, grade: Grade)
	local grades: { [string]: { word: string, colour: Color3, sparkles: number, rings: number } } =
		Presets.arcade.grades :: any
	local spec = grades[grade]
	if spec == nil then
		return
	end
	local gui = ArcadeFx.ready(target)
	if gui == nil then
		return
	end
	ArcadeFx.burst(
		gui,
		target,
		{ colour = spec.colour, sparkles = spec.sparkles, rings = spec.rings }
	)
	ArcadeFx.word(gui, target, spec.word, spec.colour, Presets.arcade.wordSize)
end

function ArcadeFx.milestone(target: GuiObject, points: number)
	local gui = ArcadeFx.ready(target)
	if gui == nil then
		return
	end
	local m = Presets.arcade.milestone
	ArcadeFx.burst(
		gui,
		target,
		{ colour = m.colour, sparkles = m.sparkles, rings = m.rings, ringGap = m.ringGap }
	)
	ArcadeFx.word(gui, target, tostring(math.floor(points)) .. "!", m.colour, m.wordSize)
end

function ArcadeFx.goldenFish(target: GuiObject)
	local gui = ArcadeFx.ready(target)
	if gui == nil then
		return
	end
	local f = Presets.arcade.fish
	ArcadeFx.burst(gui, target, { colour = f.colour, sparkles = f.sparkles, rings = 0 })
	ArcadeFx.word(gui, target, f.glyph, f.colour, f.wordSize)
end

-- #3338: the Play button's shine. `face` gets a "Shine" frame of its size with its corner, white through a band of a
-- UIGradient that slides across every `every` seconds over `seconds`. Returns a switch; off (or Reduce Motion) hides it.
function ArcadeFx.shine(face: GuiObject, corner: UDim?): (on: boolean) -> ()
	local s = Presets.arcade.shine
	local overlay = Instance.new("Frame")
	overlay.Name = "Shine"
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = face.ZIndex + 1
	overlay.Active = false
	overlay.Visible = false
	local round = Instance.new("UICorner")
	round.CornerRadius = corner or UDim.new(0, 8)
	round.Parent = overlay
	local band = Instance.new("UIGradient")
	local half = s.width / 2
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5 - half, 1),
		NumberSequenceKeypoint.new(0.5, s.transparency),
		NumberSequenceKeypoint.new(0.5 + half, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Rotation = 20
	band.Offset = Vector2.new(-1, 0)
	band.Parent = overlay
	overlay.Parent = face
	local on = false
	local clock = 0
	local step: RBXScriptConnection? = nil
	local function stop()
		if step ~= nil then
			step:Disconnect()
			step = nil
		end
		overlay.Visible = false
	end
	local function start()
		if step ~= nil then
			return
		end
		clock = 0
		step = RunService.Heartbeat:Connect(function(dt: number)
			if overlay.Parent == nil then
				stop()
				return
			end
			clock = (clock + dt) % s.every
			local t = clock / s.seconds
			local sweeping = t < 1 and not Context.reducedMotion()
			overlay.Visible = sweeping
			if sweeping then
				band.Offset = Vector2.new(-1 + 2 * t, 0)
			end
		end)
	end
	return function(want: boolean)
		if want == on then
			return
		end
		on = want
		if on then
			start()
		else
			stop()
		end
	end
end

return ArcadeFx
