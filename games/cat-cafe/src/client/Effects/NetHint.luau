--!strict
-- #5647 (Derek 2026-11-22: "for pc show clicking mouse on the screen when in range so people know to click to use net
-- because some people don't. (point at net button for phone and anything else that uses net)"), switch netHint: while
-- a cat is in net reach (Moments.NetInReach, the stray a swing would land on) and the save has caught fewer than
-- `untilCaught` cats (ProfileSync stats.catsCaught), this shows how to swing on this device:
--   mouse    a little mouse over the cat whose left button presses in every `period` seconds, with "Click!"
--   gamepad  an "R2" key over the cat that presses in the same way
--   touch    the tutorial's ring and arrow on the Net button (the player's NetHintButton attribute)
-- It goes once the cat leaves reach. Reduce Motion: the mouse and key hold still, lit. Listening only; it sends
-- nothing. Numbers in Presets.netHint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)
local SyncSeed = require(script.Parent.SyncSeed)

local NetHint = {}

export type Device = "mouse" | "gamepad" | "touch"

local started = false
local caught: number? = nil -- stats.catsCaught as last seen
local inReach: Model? = nil
local gui: BillboardGui? = nil
local press: Frame? = nil -- the part that lights on each press: the mouse's left button or the R2 key
local word: TextLabel? = nil
local shownFor: Device? = nil
local touchOn = false

-- Whether the hint shows: the switch is on, a cat is in reach and the save has caught fewer than `untilCaught` (an
-- unknown count shows nothing, so it never flashes for a player whose count has not arrived). Pure.
function NetHint.shows(
	on: boolean,
	reach: boolean,
	catsCaught: number?,
	untilCaught: number
): boolean
	return on and reach and catsCaught ~= nil and catsCaught < untilCaught
end

-- Which hint this device gets: touch on a touch screen with no keyboard, gamepad with a gamepad and no mouse, else the
-- mouse. Pure.
function NetHint.device(touch: boolean, keyboard: boolean, gamepad: boolean, mouse: boolean): Device
	if touch and not keyboard then
		return "touch" :: Device
	elseif gamepad and not mouse then
		return "gamepad" :: Device
	end
	return "mouse" :: Device
end

-- How far the press is in at `t` seconds: 1 for the first `down` share of each `period`, else 0; held at 1 with
-- Reduce Motion. Pure.
function NetHint.pressed(t: number, period: number, down: number, still: boolean): number
	if still or period <= 0 then
		return 1
	end
	return if (t % period) / period < down then 1 else 0
end

local function corner(parent: Instance, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = 2.5
	s.Parent = parent
end

local function build(device: Device): BillboardGui
	local p = Presets.netHint
	local made = Instance.new("BillboardGui")
	made.Name = "EffectsNetHint"
	made.Size = UDim2.fromOffset(p.size, p.size * 1.35)
	made.AlwaysOnTop = true
	made.LightInfluence = 0
	made.ResetOnSpawn = false
	made.MaxDistance = p.maxDistance
	made.StudsOffsetWorldSpace = Vector3.new(0, p.lift, 0)
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = made
	local label = Instance.new("TextLabel")
	label.Name = "Word"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.3)
	label.Position = UDim2.fromScale(0, 0.7)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = p.white
	label.TextStrokeColor3 = p.ink
	label.TextStrokeTransparency = 0
	label.Text = if device == "gamepad" then "Press!" else "Click!"
	label.Parent = holder
	word = label
	if device == "gamepad" then
		local key = Instance.new("Frame")
		key.Name = "Key"
		key.AnchorPoint = Vector2.new(0.5, 0)
		key.Position = UDim2.fromScale(0.5, 0.05)
		key.Size = UDim2.fromScale(0.8, 0.55)
		key.BackgroundColor3 = p.white
		corner(key, 0.3)
		stroke(key, p.ink)
		key.Parent = holder
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = p.ink
		text.Text = "R2"
		text.Parent = key
		press = key
	else
		-- a mouse: a rounded body with two buttons on top and a line between them
		local body = Instance.new("Frame")
		body.Name = "Mouse"
		body.AnchorPoint = Vector2.new(0.5, 0)
		body.Position = UDim2.fromScale(0.5, 0.02)
		body.Size = UDim2.fromScale(0.5, 0.65)
		body.BackgroundColor3 = p.white
		corner(body, 0.5)
		stroke(body, p.ink)
		body.Parent = holder
		local left = Instance.new("Frame")
		left.Name = "Left"
		left.Position = UDim2.fromScale(0.06, 0.05)
		left.Size = UDim2.fromScale(0.42, 0.38)
		left.BackgroundColor3 = p.white
		left.BorderSizePixel = 0
		corner(left, 0.45)
		left.Parent = body
		local split = Instance.new("Frame")
		split.Name = "Split"
		split.AnchorPoint = Vector2.new(0.5, 0)
		split.Position = UDim2.fromScale(0.5, 0)
		split.Size = UDim2.new(0, 2, 0.45, 0)
		split.BackgroundColor3 = p.ink
		split.BorderSizePixel = 0
		split.Parent = body
		press = left
	end
	return made
end

local function clear()
	if gui ~= nil then
		(gui :: BillboardGui):Destroy()
	end
	gui, press, word, shownFor = nil, nil, nil, nil
end

-- the touch Net button's ring and arrow: UI/Screens/NetButton reads this attribute on the player
local function setTouch(on: boolean)
	if touchOn == on then
		return
	end
	touchOn = on
	Players.LocalPlayer:SetAttribute(Presets.netHint.buttonAttribute, if on then true else nil)
end

local function update()
	local p = Presets.netHint
	if caught == nil then
		caught = SyncSeed.seedCaught() -- #5677: the join's sync came before this started
	end
	local on = ReplicatedStorage:GetAttribute("LiveFlag_" .. p.flag) == true
	local model = inReach
	local reach = model ~= nil and model.Parent ~= nil
	local show = NetHint.shows(on, reach, caught, p.untilCaught)
	local device: Device = NetHint.device(
		UserInputService.TouchEnabled,
		UserInputService.KeyboardEnabled,
		UserInputService.GamepadEnabled,
		UserInputService.MouseEnabled
	)
	setTouch(show and device == "touch")
	if not show or device == "touch" or model == nil then
		clear()
		return
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if part == nil then
		clear()
		return
	end
	if gui == nil or shownFor ~= device then
		clear()
		local made = build(device)
		made.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		gui, shownFor = made, device
	end
	local made = gui :: BillboardGui
	if made.Adornee ~= part then
		made.Adornee = part
	end
end

local function animate()
	local p = Presets.netHint
	local key, label = press, word
	if key == nil then
		return
	end
	local k = NetHint.pressed(os.clock(), p.period, p.down, Context.reducedMotion())
	key.BackgroundColor3 = p.white:Lerp(p.gold, k)
	if label ~= nil then
		label.TextTransparency = 0.35 * (1 - k)
	end
end

function NetHint.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local stats = (state :: { [string]: unknown }).stats
		if type(stats) == "table" and type((stats :: any).catsCaught) == "number" then
			caught = (stats :: any).catsCaught
			update()
		end
	end)
	local signal = (Moments :: any).NetInReach
	if signal ~= nil then
		signal:Connect(function(model: Model?)
			inReach = model
			update()
		end)
	end
	-- the switch can turn on mid session; looked at twice a second, the press animates every frame while it shows
	local lookedAt = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lookedAt >= 0.5 then
			lookedAt = now
			update()
		end
		if gui ~= nil then
			animate()
		end
	end)
end

return NetHint
