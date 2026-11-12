--!strict
-- Mouse Dash's pops (#3296, the second Cat Arcade game; Gameplay-Engineer's Screens/MouseDash calls them). Like
-- ArcadeFx, each is a short burst on this player's screen round a UI object the window hands over (a mouse hole, a
-- heart pad, the score), drawn on the arcade's effects ScreenGui; none sends anything to the server or shows a toast.
-- `kind` is what is in the hole: "mouse", "golden" (the golden mouse) or "kitten" (the napping kitten, the decoy).
--   MouseDashFx.pop(hole, kind)                   it pops up: a soft ring; the golden mouse a gold ring and a few
--                                                 sparkles; the kitten a "Zzz" that drifts up
--   MouseDashFx.catch(hole, points, kind, streak) a catch: mint sparkles, a ring and "+1", bigger and golden on every
--                                                 5th of a streak; the golden mouse the full gold burst and "+3"
--   MouseDashFx.escape(hole)                      the mouse ducks back in untapped: a dust puff over the hole
--   MouseDashFx.wrong(hole, kind)                 a wrong tap: "kitten" a blush "mrow?"; "empty" three dizzy stars
--                                                 and a little dust
--   MouseDashFx.heart(pad, gained)                a heart pad: won back a pink ring and sparkles, lost a grey puff
--   MouseDashFx.faster(target, level)             the speed step: a blue ring, sparkles and "Faster!"
--   MouseDashFx.best(target)                      a new best or a win: two gold rings, confetti in three colours and
--                                                 "New best!" (MouseDashFx.best(target, "You win!") for the win)
--   MouseDashFx.bounce(object, kind)              the one that touches the window: a quick scale bounce on a UIScale
--                                                 named "FxScale" it adds to `object`: "pop" (a mouse rising),
--                                                 "squash" (a caught mouse, the paw's bop) or "pulse" (a heart pad)
-- Milestones and the run's golden fish are ArcadeFx.milestone and ArcadeFx.goldenFish.
-- Reduce Motion: no rings, no bounce, half the sparkles, the dust fades where it is. Low performance: half the
-- sparkles and half the dust. A target that isn't on screen plays nothing. Each plays once per call and nothing
-- loops, so nothing flashes. Numbers in Presets.mouseDash.

local RunService = game:GetService("RunService")

local ArcadeFx = require(script.Parent.ArcadeFx)
local Context = require(script.Parent.Context)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local MouseDashFx = {}

local rng = Random.new()

export type Kind = "mouse" | "golden" | "kitten"

-- Pure: which catch pop a catch earns: "golden" for the golden mouse, "big" on every `every`-th catch of a streak,
-- else "small".
function MouseDashFx.catchKind(kind: any, streak: any, every: number?): "golden" | "big" | "small"
	if kind == "golden" then
		return "golden"
	end
	local step = every or Presets.mouseDash.bigEvery
	if type(streak) ~= "number" or streak ~= streak or streak < 1 then
		return "small"
	end
	return if math.floor(streak) % step == 0 then "big" else "small"
end

-- Pure: the scale of a bounce `k` (0 to 1) of the way through: from 1 out to `peak` and back, with one small
-- overshoot the other way before it settles on exactly 1.
function MouseDashFx.bounceScale(k: number, peak: number): number
	if k <= 0 or k >= 1 then
		return 1
	end
	if k < 0.4 then
		return 1 + (peak - 1) * math.sin(math.pi / 2 * k / 0.4)
	end
	local back = (k - 0.4) / 0.6
	return 1 + (peak - 1) * math.cos(math.pi * 1.5 * back) * (1 - back)
end

-- Pure: how many dust blobs a puff of `count` draws on this device.
function MouseDashFx.puffCount(count: number, lowPerformance: boolean): number
	return if lowPerformance then math.ceil(count / 2) else count
end

type Blob = { frame: Frame, way: Vector2, reach: number, size: number }

-- Round dust blobs in `colour` that drift out and a little up from the lower middle of `target`, swelling as they
-- fade over the preset's seconds. With Reduce Motion they stay put and only fade.
local function puff(gui: ScreenGui, target: GuiObject, count: number, colour: Color3)
	local p = Presets.mouseDash.puff
	local middle = ScreenFx.centre(gui, target)
	local from = middle + Vector2.new(0, target.AbsoluteSize.Y * p.drop)
	local still = Context.reducedMotion()
	local blobs: { Blob } = {}
	for i = 1, MouseDashFx.puffCount(count, Context.lowPerformance) do
		local frame = Instance.new("Frame")
		frame.Name = "Dust"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundColor3 = colour
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromOffset(from.X, from.Y)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		frame.Parent = gui
		-- spread over the upper half circle, so the dust rises off the hole's rim
		local angle = math.pi * (i - 0.5) / count + rng:NextNumber(-0.2, 0.2)
		table.insert(blobs, {
			frame = frame,
			way = Vector2.new(math.cos(angle), -math.sin(angle) * 0.6),
			reach = if still then 0 else p.reach * rng:NextNumber(0.6, 1),
			size = p.size * rng:NextNumber(0.7, 1.2),
		})
	end
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / p.seconds
		if k >= 1 or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			for _, blob in blobs do
				blob.frame:Destroy()
			end
			return
		end
		local out = 1 - (1 - k) * (1 - k)
		for _, blob in blobs do
			local at = from + blob.way * (blob.reach * out)
			local across = blob.size * (0.6 + 0.6 * out)
			blob.frame.Position = UDim2.fromOffset(at.X, at.Y)
			blob.frame.Size = UDim2.fromOffset(across, across)
			blob.frame.BackgroundTransparency = p.transparency + (1 - p.transparency) * k
		end
	end)
end

function MouseDashFx.pop(hole: GuiObject, kind: Kind?)
	local gui = ArcadeFx.ready(hole)
	if gui == nil then
		return
	end
	local p = Presets.mouseDash.pop
	if kind == "kitten" then
		ArcadeFx.word(gui, hole, p.kitten.word, p.kitten.colour, p.kitten.wordSize)
	elseif kind == "golden" then
		ArcadeFx.burst(
			gui,
			hole,
			{ colour = p.golden.colour, sparkles = p.golden.sparkles, rings = 1 }
		)
	else
		ArcadeFx.burst(gui, hole, { colour = p.colour, sparkles = 0, rings = 1 })
	end
end

function MouseDashFx.catch(hole: GuiObject, _points: number?, kind: Kind?, streak: number?)
	local gui = ArcadeFx.ready(hole)
	if gui == nil then
		return
	end
	local m = Presets.mouseDash
	local which = MouseDashFx.catchKind(kind, streak)
	local spec = if which == "golden"
		then m.catchGolden
		elseif which == "big" then m.catchBig
		else m.catch
	ArcadeFx.burst(
		gui,
		hole,
		{ colour = spec.colour, sparkles = spec.sparkles, rings = spec.rings }
	)
	ArcadeFx.word(gui, hole, spec.word, spec.colour, spec.wordSize)
end

function MouseDashFx.escape(hole: GuiObject)
	local gui = ArcadeFx.ready(hole)
	if gui == nil then
		return
	end
	local p = Presets.mouseDash.puff
	puff(gui, hole, p.count, p.colour)
end

function MouseDashFx.wrong(hole: GuiObject, kind: ("empty" | "kitten")?)
	local gui = ArcadeFx.ready(hole)
	if gui == nil then
		return
	end
	local w = Presets.mouseDash.wrong
	if kind == "kitten" then
		ArcadeFx.word(gui, hole, w.kitten.word, w.kitten.colour, w.kitten.wordSize)
		return
	end
	ArcadeFx.burst(gui, hole, { colour = w.empty.colour, sparkles = w.empty.stars, rings = 0 })
	puff(gui, hole, w.empty.puffs, Presets.mouseDash.puff.colour)
end

function MouseDashFx.heart(pad: GuiObject, gained: boolean?)
	local gui = ArcadeFx.ready(pad)
	if gui == nil then
		return
	end
	local h = Presets.mouseDash.heart
	if gained == true then
		ArcadeFx.burst(gui, pad, { colour = h.colour, sparkles = h.sparkles, rings = 1 })
	else
		puff(gui, pad, h.puffs, h.lost)
	end
end

function MouseDashFx.faster(target: GuiObject, _level: number?)
	local gui = ArcadeFx.ready(target)
	if gui == nil then
		return
	end
	local f = Presets.mouseDash.faster
	ArcadeFx.burst(gui, target, { colour = f.colour, sparkles = f.sparkles, rings = f.rings })
	ArcadeFx.word(gui, target, f.word, f.colour, f.wordSize)
end

function MouseDashFx.best(target: GuiObject, words: string?)
	local gui = ArcadeFx.ready(target)
	if gui == nil then
		return
	end
	local b = Presets.mouseDash.best
	-- confetti: the burst cap shared out over the colours, the rings only with the first
	local colours: { Color3 } = b.confetti
	local each = math.floor(b.sparkles / #colours)
	for index, colour in colours do
		ArcadeFx.burst(gui, target, {
			colour = colour,
			sparkles = each,
			rings = if index == 1 then b.rings else 0,
			ringGap = b.ringGap,
		})
	end
	ArcadeFx.word(gui, target, words or b.word, b.colour, b.wordSize)
end

local bouncing: { [UIScale]: RBXScriptConnection } = {}

function MouseDashFx.bounce(object: GuiObject, kind: ("pop" | "squash" | "pulse")?)
	if Context.reducedMotion() or not ScreenFx.shown(object) then
		return
	end
	local peaks: { [string]: number } = Presets.mouseDash.bounce.peaks :: any
	local peak = peaks[kind or "pop"] or peaks.pop
	local found = object:FindFirstChild("FxScale")
	local scale: UIScale
	if found ~= nil and found:IsA("UIScale") then
		scale = found :: UIScale
	else
		local made = Instance.new("UIScale")
		made.Name = "FxScale"
		made.Parent = object
		scale = made
	end
	local running: RBXScriptConnection? = bouncing[scale]
	if running then
		running:Disconnect()
	end
	local began = os.clock()
	local seconds = Presets.mouseDash.bounce.seconds
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / seconds
		if k >= 1 or scale.Parent == nil then
			loop:Disconnect()
			bouncing[scale] = nil
			scale.Scale = 1
			return
		end
		scale.Scale = MouseDashFx.bounceScale(k, peak)
	end)
	bouncing[scale] = loop
end

return MouseDashFx
