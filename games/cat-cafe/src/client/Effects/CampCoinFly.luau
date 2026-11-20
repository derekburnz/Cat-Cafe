--!strict
-- The new start's camp pay moment (#5533 version 2, Gameplay-Engineer's ask 2026-11-20): at this player's first
-- `checkIns` camp check-ins of the session while the play first start is quiet (shared/FreeStart.quiet), coins fly from
-- the camp to the HUD's money counter (FirstCatchWow's coin arc), the counter gives one small bounce, and a
-- "+12/s" line pops in under it big and settles, then fades: the coins a second the cafe now earns. The HUD keeps the
-- rate per second hidden (Derek 2026-11-02), so the line is this moment's own and goes again in `rateSeconds`.
-- Source: Moments.CampCheckIn (userId, campId) for the LocalPlayer's own userId, and ProfileSync's incomePerSecond.
-- No switch of its own: FreeStart.quiet() is false unless `freeStart` marked this save. Reduce Motion: no coins and no
-- bounce, the line shows still. Listening only: no remotes, no game state. Numbers in Presets.campCoinFly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local FirstCatchWow = require(script.Parent.FirstCatchWow)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local CampCoinFly = {}

local started = false
local shown = 0
local perSecond = 0
local quiet: (() -> boolean)? = nil

-- Pure: whether this check-in gets the moment: this player's own, the start quiet, and fewer than `most` so far.
function CampCoinFly.due(own: boolean, isQuiet: boolean, sofar: number, most: number): boolean
	return own and isQuiet and sofar < most
end

-- Pure: "+12/s", "+1.5K/s", "+2.3M/s" for a rate per second.
function CampCoinFly.rateText(rate: number): string
	local n = math.max(0, rate)
	local text
	if n >= 1e9 then
		text = string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		text = string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		text = string.format("%.1fK", n / 1e3)
	else
		text = tostring(math.floor(n + 0.5))
	end
	text = string.gsub(text, "%.0([KMB])", "%1")
	return "+" .. text .. "/s"
end

-- Pure: the line's size (1 its own) and see-through share `t` seconds in: it pops in at `pop` times, settles to 1 by
-- `settle` seconds and fades out over its last `fade` seconds of `seconds`.
function CampCoinFly.lineAt(
	t: number,
	seconds: number,
	pop: number,
	settle: number,
	fade: number
): (number, number)
	if t < 0 or t >= seconds then
		return 1, 1
	end
	local size = if t < settle then pop + (1 - pop) * (t / settle) else 1
	local clear = if t > seconds - fade then (t - (seconds - fade)) / fade else 0
	return size, clear
end

local function isQuiet(): boolean
	if quiet == nil then
		-- shared/FreeStart is Gameplay-Engineer's (#5541); until it is there, nothing plays
		local module = ReplicatedStorage:FindFirstChild("Shared")
		local found = if module ~= nil then module:FindFirstChild("FreeStart") else nil
		if found == nil or not found:IsA("ModuleScript") then
			return false
		end
		local ok, loaded = pcall(require, found)
		local fn = if ok and type(loaded) == "table" then (loaded :: any).quiet else nil
		if type(fn) ~= "function" then
			return false
		end
		quiet = fn
	end
	local ok, answer = pcall(quiet :: () -> boolean)
	return ok and answer == true
end

local function campAt(campId: unknown): Vector3?
	for _, model in CollectionService:GetTagged("CatCannon") do
		if model:IsA("Model") and model:GetAttribute("CannonId") == campId then
			return (model :: Model):GetPivot().Position
		end
	end
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function moneyCounter(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeHUD") else nil
	local money = if hud ~= nil then hud:FindFirstChild("Money", true) else nil
	return if money ~= nil
			and money:IsA("GuiObject")
			and ScreenFx.shown(money :: GuiObject)
		then money :: GuiObject
		else nil
end

local function bounce(counter: GuiObject)
	local p = Presets.campCoinFly
	local scale = counter:FindFirstChild("EffectsCampBounce")
	if scale == nil then
		local made = Instance.new("UIScale")
		made.Name = "EffectsCampBounce"
		made.Parent = counter
		scale = made
	end
	local s = scale :: UIScale
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - began) / p.bounceSeconds
		if k >= 1 then
			s.Scale = 1
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		s.Scale = 1 + (p.bounce - 1) * math.sin(math.pi * k)
	end)
end

local function rateLine(gui: ScreenGui, counter: GuiObject)
	local p = Presets.campCoinFly
	local under = ScreenFx.toGui(
		gui,
		counter.AbsolutePosition + Vector2.new(counter.AbsoluteSize.X / 2, counter.AbsoluteSize.Y)
	)
	local label = Instance.new("TextLabel")
	label.Name = "CampRate"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromOffset(under.X, under.Y + p.lineGap)
	label.Size = UDim2.fromOffset(p.lineWidth, p.lineHeight)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = p.gold
	label.Text = CampCoinFly.rateText(perSecond)
	local stroke = Instance.new("UIStroke")
	stroke.Color = p.ink
	stroke.Thickness = 2
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	label.Parent = gui
	local still = Context.reducedMotion()
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= p.rateSeconds then
			label:Destroy()
			if connection ~= nil then
				connection:Disconnect()
			end
			return
		end
		local size, clear =
			CampCoinFly.lineAt(t, p.rateSeconds, if still then 1 else p.pop, p.settle, p.fade)
		scale.Scale = size
		label.TextTransparency = clear
		stroke.Transparency = clear
	end)
end

local function play(campId: unknown)
	local p = Presets.campCoinFly
	local gui = ScreenFx.gui(p.gui, p.displayOrder)
	local counter = moneyCounter()
	if gui == nil or counter == nil then
		return
	end
	local still = Context.reducedMotion()
	if not still then
		local at = campAt(campId)
		local camera = Workspace.CurrentCamera
		if at ~= nil and camera ~= nil then
			local screen, visible = camera:WorldToViewportPoint(at :: Vector3)
			local from = if visible
				then ScreenFx.toGui(gui, Vector2.new(screen.X, screen.Y))
				else Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y * 0.6)
			FirstCatchWow.flyCoins(gui, from, p)
		end
		task.delay(p.coinSeconds + p.coinStagger * p.coins, function()
			bounce(counter)
		end)
	end
	task.delay(if still then 0 else p.coinSeconds, function()
		rateLine(gui, counter)
	end)
end

function CampCoinFly.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local rate = (state :: { [string]: unknown }).incomePerSecond
		if type(rate) == "number" and rate == rate then
			perSecond = rate
		end
	end)
	Moments.CampCheckIn:Connect(function(userId: unknown, campId: unknown)
		local own = userId == Players.LocalPlayer.UserId
		if not CampCoinFly.due(own, own and isQuiet(), shown, Presets.campCoinFly.checkIns) then
			return
		end
		shown += 1
		-- the check-in's own sync (the new rate) lands just after the moment fires
		task.delay(Presets.campCoinFly.waitSync, play, campId)
	end)
end

return CampCoinFly
