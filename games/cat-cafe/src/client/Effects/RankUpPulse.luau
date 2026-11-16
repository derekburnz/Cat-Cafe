--!strict
-- #4920 (Design-Agent's spec, items 5 and 7; Derek's first 5 minutes priority, 34% of players with a rank up ready
-- never press it): two small screen moments, drawn over the UI through ScreenFx. It only reads the UI.
--   * The first time each tier's rank up is ready this session (the LocalPlayer attribute `RankUpReady`, the tier,
--     set by Gameplay-Engineer's HUD), every RANK UP button that shows (the strip's `TutorialBuy` in CatCafeHUD, the
--     Rank Up window's button) gets `pulses` gold glows: a rounded frame the button's shape swells off it and fades,
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

-- Whether `object` is a RANK UP button or the label on one.
function RankUpPulse.isRankButton(name: string, text: string?): boolean
	if name == "TutorialBuy" then
		return true
	end
	-- the button words are capitals ("RANK UP", "RANK UP  ·  $1.2K"); the strip's "Rank up! Tap RANK UP" is not one
	return text ~= nil and string.sub(text, 1, 7) == "RANK UP"
end

-- Every RANK UP button that shows now: the strip's TutorialBuy, and any button (or its label) reading RANK UP.
local function buttons(): { GuiObject }
	local out: { GuiObject } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return out
	end
	local seen: { [Instance]: boolean } = {}
	local own = playerGui:FindFirstChild(GUI)
	for _, d in playerGui:GetDescendants() do
		if d:IsA("GuiObject") and (own == nil or not d:IsDescendantOf(own)) then
			local text = if d:IsA("TextButton") or d:IsA("TextLabel") then (d :: any).Text else nil
			if RankUpPulse.isRankButton(d.Name, text) then
				-- a label inside a button glows the button
				local target: GuiObject = d :: GuiObject
				local parent = d.Parent
				if d:IsA("TextLabel") and parent ~= nil and parent:IsA("GuiButton") then
					target = parent :: GuiObject
				end
				if not seen[target] and ScreenFx.shown(target) then
					seen[target] = true
					table.insert(out, target)
				end
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

local function ready(tier: unknown)
	if type(tier) ~= "number" then
		return
	end
	local p = Presets.rankUpPulse
	local still = Context.reducedMotion()
	task.delay(p.wait, function() -- the window that opens with it slides in first
		local gui = ScreenFx.gui(GUI, p.displayOrder)
		if gui == nil then
			return
		end
		local count = if still then 1 else p.pulses
		local found = buttons() -- one look through the UI; each glow follows its button
		for i = 1, count do
			for _, object in found do
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
			end
			task.wait(p.every)
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
