--!strict
-- "Trading unlocked!" (#4280; Derek 2026-11-14: "encourage trading by showing an unlock with a lock falling off of
-- it animation on hitting Tier 3 (make sure its not overtop any other animations)"). On this player's screen only:
-- the Trade icon pops in on the upper middle with a closed padlock on it, the padlock wiggles, springs open in gold
-- sparkles, falls off and tumbles away, the words show under the icon, and the icon flies to the HUD's Trade tile,
-- which gets a sparkle burst and a ring so the player sees where to tap.
--
--   local started = TradeUnlock.play(hudTradeTile, function() end)
--
-- Gameplay-Engineer owns when it plays (the rank up that reaches the live TradeMinTier, queued after the rank up's
-- own effects and cards) and whether it has played before. This only shows it. play returns false, changing nothing
-- and never calling onDone, while it or a cutscene is already playing; otherwise onDone runs exactly once when it
-- ends. `tile` is where the icon flies to; with none on screen (nil, hidden, a small HUD) the icon fades where it is.
-- It takes no taps and covers no button: its ScreenGui has no active object. It draws at DisplayOrder 22, under the
-- toasts. Reduce Motion: nothing moves; the closed lock gives way to the open one and the words hold, then it all
-- fades. Low performance: half the sparkles. Nothing random and nothing for sale is shown.
-- Sound: TradeUnlock.onBeat's "open" (the lock springs open) and "land" (the icon reaches the tile).
-- Client only; it sends nothing. Timeline in Logic.tradeUnlock, numbers in Presets.tradeUnlock.

local RunService = game:GetService("RunService")

local BigTraitCut = require(script.Parent.BigTraitCut)
local Context = require(script.Parent.Context)
local ContextCut = require(script.Parent.ContextCut)
local FirstBaitCut = require(script.Parent.FirstBaitCut)
local Logic = require(script.Parent.Logic)
local MysticIntroCut = require(script.Parent.MysticIntroCut)
local Presets = require(script.Parent.Presets)
local RiftRun = require(script.Parent.RiftRun)
local ScreenFx = require(script.Parent.ScreenFx)

local TradeUnlock = {}

export type Beat = "open" | "land"

local GUI_NAME = "EffectsTradeUnlock"
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

local running = false
local listeners: { (beat: Beat) -> () } = {}

-- Calls `listener(beat)` as the lock springs open ("open") and as the icon reaches the Trade tile ("land").
-- Listeners only listen.
function TradeUnlock.onBeat(listener: (beat: Beat) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat)
	for _, listener in listeners do
		task.spawn(listener, name)
	end
end

-- Whether the moment is on screen now.
function TradeUnlock.playing(): boolean
	return running
end

-- Whether a cutscene has the screen, so the moment must wait.
function TradeUnlock.blocked(): boolean
	return ContextCut.playing()
		or FirstBaitCut.playing()
		or MysticIntroCut.playing()
		or BigTraitCut.playing()
		or RiftRun.playing()
end

local function image(name: string, id: string, parent: Instance): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Image = id
	label.ScaleType = Enum.ScaleType.Fit
	label.Parent = parent
	return label
end

local function words(name: string, text: string, size: number, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Size = UDim2.fromOffset(0, size + 6)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.FontFace = FONT
	label.TextSize = size
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(46, 30, 20)
	stroke.Transparency = 1
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function setWords(label: TextLabel, shown: number)
	label.TextTransparency = 1 - shown
	local stroke = label:FindFirstChild("Outline")
	if stroke ~= nil and stroke:IsA("UIStroke") then
		(stroke :: UIStroke).Transparency = 1 - shown
	end
end

-- `count` spots evenly round a circle `radius` pixels from `at`.
local function round(at: Vector2, radius: number, count: number): { Vector2 }
	local spots: { Vector2 } = {}
	for i = 1, count do
		local a = 2 * math.pi * i / count
		table.insert(spots, at + Vector2.new(math.cos(a), math.sin(a)) * radius)
	end
	return spots
end

-- Plays the moment; see the top of this file.
function TradeUnlock.play(tile: GuiObject?, onDone: (() -> ())?): boolean
	if running or TradeUnlock.blocked() then
		return false
	end
	local p = Presets.tradeUnlock
	local gui = ScreenFx.gui(GUI_NAME, p.displayOrder)
	if gui == nil then
		return false
	end
	running = true
	local still = Context.reducedMotion()
	local view = gui.AbsoluteSize
	local size = math.clamp(math.min(view.X, view.Y) * p.size, p.sizeMin, p.sizeMax)
	local small = size / p.sizeMax -- the words shrink with the icon on a small screen
	local home = Vector2.new(view.X / 2, view.Y * p.high)
	local sparkles = if Context.lowPerformance then math.ceil(p.sparkles / 2) else p.sparkles
	local landSparkles = if Context.lowPerformance
		then math.ceil(p.landSparkles / 2)
		else p.landSparkles

	local holder = Instance.new("Frame")
	holder.Name = "Moment"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local icon = image("Trade", p.tradeImage, holder)
	local lock = image("Lock", p.lockImage, holder)
	lock.ZIndex = 2
	local titleSize = math.max(18, math.floor(p.titleSize * small + 0.5))
	local lineSize = math.max(13, math.floor(p.lineSize * small + 0.5))
	local title = words("Title", p.title, titleSize, holder)
	title.TextColor3 = p.gold
	title.Position = UDim2.fromOffset(home.X, home.Y + size * 0.62)
	local line = words("Line", p.line, lineSize, holder)
	line.Position = UDim2.fromOffset(home.X, home.Y + size * 0.62 + titleSize + 8)

	local began = os.clock()
	local opened, landed = false, false
	local target: Vector2? = nil -- the Trade tile's middle, read as the flight begins
	local targetSize = size * p.land
	local loop: RBXScriptConnection? = nil

	local function finish()
		if loop ~= nil then
			loop:Disconnect()
			loop = nil
		end
		holder:Destroy()
		running = false
		if onDone ~= nil then
			task.spawn(onDone)
		end
	end

	loop = RunService.RenderStepped:Connect(function()
		if gui.Parent == nil or holder.Parent == nil then
			finish()
			return
		end
		local t = os.clock() - began
		local frame = Logic.tradeUnlock(t, p, still)
		if frame.open and not opened then
			opened = true
			lock.Image = p.openImage
			beat("open")
			ScreenFx.sparkle(gui, round(home, size * 0.35, sparkles), p.gold, p.sparkle)
			if not still then
				ScreenFx.ring(gui, home, size * 0.6, size * 1.5, p.gold, p.ringSeconds)
			end
		end
		-- the icon: at home, then along its flight to the Trade tile
		local at = home
		local across = size * frame.scale
		local shown = frame.shown
		if frame.fly > 0 then
			if target == nil and tile ~= nil and ScreenFx.shown(tile) then
				target = ScreenFx.centre(gui, tile)
				targetSize = math.min(tile.AbsoluteSize.X, tile.AbsoluteSize.Y) * 0.8
			end
			local to = target
			if to ~= nil then
				at = Logic.curve(home, Logic.flyBend(home, to, p.lift), to, frame.fly)
				across = size + (targetSize - size) * frame.fly
			else
				shown = 1 - frame.fly -- no tile on screen: it fades where it is
			end
		end
		icon.Position = UDim2.fromOffset(at.X, at.Y)
		icon.Size = UDim2.fromOffset(across, across)
		icon.ImageTransparency = 1 - shown
		-- the padlock: on the icon's lower right, hopping as it opens, then falling off
		local lockAcross = size * p.lock * frame.scale
		local rest = home + Vector2.new(size * 0.22, size * 0.2)
		lock.Position = UDim2.fromOffset(
			rest.X + frame.fallX * size,
			rest.Y + (frame.fallY - frame.hop * p.lock) * size
		)
		lock.Size = UDim2.fromOffset(lockAcross, lockAcross)
		lock.Rotation = frame.tilt + frame.fallSpin
		lock.ImageTransparency = 1 - frame.lockShown * frame.shown
		setWords(title, frame.words * frame.shown)
		setWords(line, frame.words * frame.shown)
		if frame.done then
			local to = target
			if to ~= nil and not landed then
				landed = true
				beat("land")
				ScreenFx.sparkle(gui, round(to, targetSize * 0.5, landSparkles), p.gold, p.sparkle)
				ScreenFx.ring(gui, to, targetSize, targetSize * 2, p.gold, p.ringSeconds)
			end
			finish()
		end
	end)
	return true
end

return TradeUnlock
