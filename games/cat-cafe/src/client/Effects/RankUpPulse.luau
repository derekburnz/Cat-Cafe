--!strict
-- #4920 (Design-Agent's spec, items 5 and 7; Derek's first 5 minutes priority, 34% of players with a rank up ready
-- never press it): two small screen moments, drawn over the UI through ScreenFx. It only reads the UI.
--   * The first time each tier's rank up is ready this session (the LocalPlayer attribute `RankUpReady`, the tier,
--     set by Gameplay-Engineer's HUD), every RANK UP button that shows (the strip's `TutorialBuy` in CatCafeHUD, the
--     Rank Up window's `RankUpButton`) gets `pulses` gold glows: a rounded frame the button's shape swells off it and fades,
--     then a few sparkles. Reduce Motion: one glow, no sparkles.
--   * When the tutorial strip's count moves on (the attribute `TutorialCount`, "1/2" and so on), a small tick of
--     sparkles off the strip's `Tutorial` label and one ring. None with Reduce Motion.
-- Listening only: no remotes, no game state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local RankUpPulse = {}

local started = false
local GUI = "EffectsRankUpPulse"

-- Whether a UI object of this name is a RANK UP button: the tutorial strip's (HUD) or the Rank Up window's.
function RankUpPulse.isRankButton(name: string): boolean
	return name == "TutorialBuy" or name == "RankUpButton"
end

-- Every RANK UP button that shows now: the strip's TutorialBuy in CatCafeHUD and the Rank Up window's
-- RankUpButton. Two lookups by name, cheap enough to repeat every `look` seconds.
local function buttons(): { GuiObject }
	local out: { GuiObject } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return out
	end
	local hud = playerGui:FindFirstChild("CatCafeHUD")
	local strip = if hud ~= nil then hud:FindFirstChild("TutorialBuy", true) else nil
	-- "RankUpButton" is unique in the UI ("RankUp" is not: the Upgrades shop has a card of that name too)
	local button = playerGui:FindFirstChild("RankUpButton", true)
	for _, found in { strip, button } do
		if found ~= nil and found:IsA("GuiObject") and RankUpPulse.isRankButton(found.Name) then
			if ScreenFx.shown(found :: GuiObject) then
				table.insert(out, found :: GuiObject)
			end
		end
	end
	return out
end

-- One glow off `object`: a rounded frame its size swelling by `grow` pixels as it fades over `seconds`, following
-- the object if it moves.
local function glow(gui: ScreenGui, object: GuiObject, p: typeof(Presets.rankUpPulse))
	local frame = Instance.new("Frame")
	frame.Name = "Glow"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = p.colour
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, p.corner)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = p.colour
	stroke.Thickness = p.thickness
	stroke.Parent = frame
	frame.Parent = gui
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / p.seconds
		if k >= 1 or gui.Parent == nil or object.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			frame:Destroy()
			return
		end
		local at = ScreenFx.centre(gui, object)
		local out = p.grow * Logic.easeInOut(k)
		frame.Position = UDim2.fromOffset(at.X, at.Y)
		frame.Size = UDim2.fromOffset(object.AbsoluteSize.X + out, object.AbsoluteSize.Y + out)
		stroke.Transparency = k
		frame.BackgroundTransparency = 1 - p.fill * (1 - k)
	end)
end

-- The glows on one button: `pulses` of them (one with Reduce Motion), then corner sparkles.
local function pulse(
	gui: ScreenGui,
	object: GuiObject,
	p: typeof(Presets.rankUpPulse),
	still: boolean
)
	task.spawn(function()
		local count = if still then 1 else p.pulses
		for i = 1, count do
			if object.Parent == nil then
				return
			end
			glow(gui, object, p)
			if i == count and not still then
				local c = ScreenFx.centre(gui, object)
				local half = object.AbsoluteSize / 2
				ScreenFx.sparkle(gui, {
					c + Vector2.new(-half.X, -half.Y),
					c + Vector2.new(half.X, -half.Y),
					c + Vector2.new(-half.X, half.Y),
					c + Vector2.new(half.X, half.Y),
				}, p.colour, p.sparkle)
			end
			task.wait(p.every)
		end
	end)
end

local glowed: { [number]: boolean } = {} -- tiers whose rank up has glowed this session
local watching = 0
local looking: number? = nil -- the tier being looked for now

-- Review-QA on #4927: the Rank Up window opens only on a calm screen, often well after RankUpReady, so this keeps
-- looking (every `look` seconds for up to `lookFor`, while the attribute still names this tier) and glows each
-- RANK UP button once as it first shows. Once per tier a session, however often coins dip under the cost and back:
-- a tier counts as glowed once a glow has played, so a look that found nothing tries again on the next flip.
local function ready(tier: unknown)
	if type(tier) ~= "number" or glowed[tier :: number] or looking == tier then
		return
	end
	local n = tier :: number
	looking = n
	watching += 1
	local mine = watching
	local p = Presets.rankUpPulse
	task.spawn(function()
		local done: { [GuiObject]: boolean } = {}
		local began = os.clock()
		local player = Players.LocalPlayer
		while
			mine == watching
			and os.clock() - began < p.lookFor
			and player:GetAttribute("RankUpReady") == n
		do
			for _, object in buttons() do
				if not done[object] then
					done[object] = true
					task.delay(p.wait, function() -- a window that just opened slides in first
						local gui = ScreenFx.gui(GUI, p.displayOrder)
						if gui ~= nil and ScreenFx.shown(object) then
							glowed[n] = true
							pulse(gui, object, p, Context.reducedMotion())
						end
					end)
				end
			end
			task.wait(p.look)
		end
		if mine == watching then
			looking = nil
		end
	end)
end

local function counted(text: unknown)
	if type(text) ~= "string" or text == "" or Context.reducedMotion() then
		return
	end
	local p = Presets.rankUpPulse.tick
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeHUD") else nil
	local label = if hud ~= nil then hud:FindFirstChild("Tutorial", true) else nil
	if label == nil or not label:IsA("TextLabel") or not ScreenFx.shown(label :: GuiObject) then
		return
	end
	local gui = ScreenFx.gui(GUI, Presets.rankUpPulse.displayOrder)
	if gui == nil then
		return
	end
	local object = label :: TextLabel
	local c = ScreenFx.centre(gui, object)
	-- the end of the words, where the count sits
	local right = c + Vector2.new(math.min(object.TextBounds.X, object.AbsoluteSize.X) / 2, 0)
	local spots = {}
	for _ = 1, p.sparks do
		table.insert(spots, right)
	end
	ScreenFx.sparkle(gui, spots, Presets.rankUpPulse.colour, p.sparkle)
	ScreenFx.ring(gui, right, p.ringFrom, p.ringTo, Presets.rankUpPulse.colour, p.ringSeconds)
end

function RankUpPulse.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("RankUpReady"):Connect(function()
		ready(player:GetAttribute("RankUpReady"))
	end)
	player:GetAttributeChangedSignal("TutorialCount"):Connect(function()
		counted(player:GetAttribute("TutorialCount"))
	end)
end

return RankUpPulse
