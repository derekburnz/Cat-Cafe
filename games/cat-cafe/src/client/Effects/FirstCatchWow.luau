--!strict
-- #5285 E2, a wow first catch (Design-Agent's first-90s spec, section E2; switch `firstCatchWow`, read straight, off
-- by default). On the account's first net catch only (FirstMinuteFx decides that, as for its cheer), as the catch
-- lands, and under 1.5 s in all:
--   0.0 s   a quarter second of slow motion (your character's animations at `slowSpeed`) while the camera pushes
--           `push` of the way toward the cat
--   0.25 s  the big pop: a ring under the cat at `ringScale` times its rarity's ring, about `coins` coins flying from
--           the cat to the money counter, and confetti in the Cozy Cream colours (half on a phone or the low tier)
--   0.3 s   "FIRST CATCH!" in the catch strip's spot at the top (not a card) until 1.3 s; FirstMinuteFx still fires
--           Moments.FirstCatchCheer, the one sting cue
--   1.3 s   the camera eases back and play goes on
-- Reduce Motion: no slow motion, push, ring, coins or confetti; the banner still shows. Client only: no remotes, no
-- game state; it reads the HUD's money coin for where the coins go. Numbers in Presets.firstCatchWow.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local FirstCatchWow = {}

FirstCatchWow.FLAG = "firstCatchWow"
FirstCatchWow.GUI = "EffectsFirstCatchWow"

local PUSH_STEP = "CatCafeFirstCatchWowPush"
local running = false
local rng = Random.new()

-- Whether the switch is on (read straight: anything but true is off).
function FirstCatchWow.on(): boolean
	return ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. FirstCatchWow.FLAG) == true
end

function FirstCatchWow.playing(): boolean
	return running
end

-- How long the moment runs: until the camera is back.
function FirstCatchWow.length(p: typeof(Presets.firstCatchWow)): number
	return p.backAt + p.backSeconds
end

local function smooth(x: number): number
	local k = math.clamp(x, 0, 1)
	return k * k * (3 - 2 * k)
end

-- At `t` seconds in: how far the camera has pushed 0 to 1, your animations' speed, and the banner's opacity 0 to 1.
-- Pure.
function FirstCatchWow.at(t: number, p: typeof(Presets.firstCatchWow)): (number, number, number)
	local push
	if t < p.pushIn then
		push = smooth(t / p.pushIn)
	elseif t < p.backAt then
		push = 1
	else
		push = 1 - smooth((t - p.backAt) / p.backSeconds)
	end
	local speed = if t >= 0 and t < p.slowSeconds then p.slowSpeed else 1
	local banner
	if t < p.bannerAt then
		banner = 0
	elseif t < p.bannerAt + p.bannerIn then
		banner = (t - p.bannerAt) / p.bannerIn
	elseif t < p.bannerEnd - p.bannerOut then
		banner = 1
	else
		banner = 1 - (t - (p.bannerEnd - p.bannerOut)) / p.bannerOut
	end
	return push, speed, math.clamp(banner, 0, 1)
end

-- How many confetti pieces: the budget's share, halved on a phone or the low tier.
function FirstCatchWow.confetti(
	budget: number,
	low: boolean,
	p: typeof(Presets.firstCatchWow)
): number
	local count = math.ceil(budget * p.confetti)
	return if low then math.ceil(count / 2) else count
end

local function phone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function strayById(strayId: string): Model?
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:GetAttribute("StrayId") == strayId then
			return instance :: Model
		end
	end
	return nil
end

-- Where the catch strip sits (the top of CatCafeCatchCircles), in `gui`'s pixels; the top middle if it is not there.
local function stripSpot(gui: ScreenGui, p: typeof(Presets.firstCatchWow)): Vector2
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local circles = if playerGui ~= nil
		then playerGui:FindFirstChild("CatCafeCatchCircles")
		else nil
	local strip = if circles ~= nil then circles:FindFirstChild("Strip", true) else nil
	if strip ~= nil and strip:IsA("GuiObject") and (strip :: GuiObject).AbsoluteSize.X >= 1 then
		local object = strip :: GuiObject
		local top = ScreenFx.toGui(gui, object.AbsolutePosition)
		return Vector2.new(gui.AbsoluteSize.X / 2, top.Y + object.AbsoluteSize.Y / 2)
	end
	return Vector2.new(gui.AbsoluteSize.X / 2, p.bannerTop)
end

-- The "FIRST CATCH!" banner in `gui`, hidden (opacity 0); FirstCatchWow.show(banner, a) draws it. Its text size
-- follows the screen's height between `textMin` and `textMax`.
function FirstCatchWow.banner(gui: ScreenGui): Frame
	local p = Presets.firstCatchWow
	local old = gui:FindFirstChild("Banner")
	if old ~= nil then
		old:Destroy()
	end
	local height = gui.AbsoluteSize.Y
	local textSize = math.clamp(math.floor(height * p.textShare), p.textMin, p.textMax)
	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	frame.BackgroundColor3 = p.panel
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local spot = stripSpot(gui, p)
	frame.Position = UDim2.fromOffset(spot.X, spot.Y)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, math.floor(textSize * 0.7))
	pad.PaddingRight = pad.PaddingLeft
	pad.PaddingTop = UDim.new(0, math.floor(textSize * 0.18))
	pad.PaddingBottom = pad.PaddingTop
	pad.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = p.popFrom
	scale.Parent = frame
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.Size = UDim2.fromOffset(0, 0)
	text.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	text.TextSize = textSize
	text.TextColor3 = p.gold
	text.TextTransparency = 1
	text.Text = p.text
	local stroke = Instance.new("UIStroke")
	stroke.Color = p.ink
	stroke.Thickness = math.max(2, math.floor(textSize / 14))
	stroke.Transparency = 1
	stroke.Parent = text
	text.Parent = frame
	frame.Parent = gui
	return frame
end

-- Draws the banner at opacity `a` 0 to 1; it pops from `popFrom` to full size as it comes in.
function FirstCatchWow.show(banner: Frame, a: number, rising: boolean)
	local p = Presets.firstCatchWow
	banner.BackgroundTransparency = 1 - a * (1 - p.panelTransparency)
	local text = banner:FindFirstChild("Text") :: TextLabel?
	if text ~= nil then
		text.TextTransparency = 1 - a
		local stroke = text:FindFirstChildOfClass("UIStroke") :: UIStroke?
		if stroke ~= nil then
			stroke.Transparency = 1 - a
		end
	end
	local scale = banner:FindFirstChildOfClass("UIScale") :: UIScale?
	if scale ~= nil and rising then
		-- a little overshoot as it lands (back out)
		local c = 1.70158
		local x = a - 1
		scale.Scale = p.popFrom + (1 - p.popFrom) * (1 + (c + 1) * x * x * x + c * x * x)
	end
end

-- The HUD's money coin, where the coins fly to.
local function moneyCoin(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeHUD") else nil
	local money = if hud ~= nil then hud:FindFirstChild("Money", true) else nil
	local coin = if money ~= nil then money:FindFirstChild("Coin") else nil
	return if coin ~= nil
			and coin:IsA("GuiObject")
			and ScreenFx.shown(coin :: GuiObject)
		then coin :: GuiObject
		else nil
end

local function coinImage(coin: GuiObject): string?
	local image = if coin:IsA("ImageLabel")
		then coin
		else coin:FindFirstChildWhichIsA("ImageLabel", true)
	if image ~= nil and (image :: ImageLabel).Image ~= "" then
		return (image :: ImageLabel).Image
	end
	return nil
end

-- What a coin fly needs (Presets.firstCatchWow, Presets.campCoinFly).
export type CoinFly = {
	coins: number,
	coinSeconds: number,
	coinStagger: number,
	coinSpread: number,
	coinLift: number,
	coinMin: number,
	gold: Color3,
}

-- About `coins` coins from `from` (pixels in `gui`) in arcs to the money coin, landing over `coinSeconds`. One loop.
-- Also Effects/CampCoinFly's (#5533).
function FirstCatchWow.flyCoins(gui: ScreenGui, from: Vector2, p: CoinFly)
	local target = moneyCoin()
	if target == nil then
		return
	end
	local to = ScreenFx.centre(gui, target :: GuiObject)
	local size = math.max(target.AbsoluteSize.Y, p.coinMin)
	local image = coinImage(target :: GuiObject)
	type Coin = { frame: GuiObject, start: Vector2, lift: Vector2, delay: number }
	local list: { Coin } = {}
	for i = 1, p.coins do
		local frame: GuiObject
		if image ~= nil then
			local picture = Instance.new("ImageLabel")
			picture.Image = image :: string
			picture.BackgroundTransparency = 1
			frame = picture
		else
			local dot = Instance.new("Frame")
			dot.BackgroundColor3 = p.gold
			dot.BorderSizePixel = 0
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = dot
			frame = dot
		end
		frame.Name = "Coin"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromOffset(size, size)
		frame.Visible = false
		frame.Parent = gui
		local angle = rng:NextNumber(0, 2 * math.pi)
		local spread = rng:NextNumber(0.3, 1) * p.coinSpread
		table.insert(list, {
			frame = frame,
			start = from + Vector2.new(math.cos(angle), math.sin(angle)) * spread * 0.35,
			lift = Vector2.new(
				math.cos(angle) * spread,
				-math.abs(math.sin(angle)) * spread - p.coinLift
			),
			delay = (i - 1) * p.coinStagger,
		})
	end
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock() - began
		local left = 0
		for _, coin in list do
			local k = (now - coin.delay) / p.coinSeconds
			if k >= 1 then
				if coin.frame.Parent ~= nil then
					coin.frame:Destroy()
				end
			else
				left += 1
				if k >= 0 then
					-- a quadratic arc: out and up from the cat, then in to the counter, faster at the end
					local e = k * k
					local mid = coin.start + coin.lift
					local a = coin.start:Lerp(mid, math.min(k * 2, 1))
					local b = mid:Lerp(to, e)
					local at = a:Lerp(b, k)
					coin.frame.Visible = true
					coin.frame.Position = UDim2.fromOffset(at.X, at.Y)
					local shrink = 1 - 0.4 * e
					coin.frame.Size = UDim2.fromOffset(size * shrink, size * shrink)
				end
			end
		end
		if left == 0 and connection ~= nil then
			connection:Disconnect()
		end
	end)
end

-- The speed to set a track to while the slow motion holds: `slow` of its own speed. `seen` is the speed it had when
-- last looked at, `set` what we set it to then (both nil the first time). A track whose speed is not what we set was
-- changed by someone else since (the Animate script sets the walk's speed as you move, a new pose starts at 1), so
-- its new speed becomes its own speed. Returns the speed to set and its own speed. Pure.
function FirstCatchWow.holdSpeed(
	now: number,
	own: number?,
	set: number?,
	slow: number
): (number, number)
	if own == nil or set == nil or math.abs(now - set) > 1e-3 then
		own = now
	end
	return (own :: number) * slow, own :: number
end

-- #5341 recheck (Sync, Nov 18): slowing the playing tracks once was undone at once (the Animate script sets the
-- speed again and the carry pose starts a new track at full speed), so the slow is held each frame for the window,
-- last in the render step, on every playing track including ones that start inside it; each goes back to its own
-- speed after, unless something else changed it since.
local function slowAnimations(p: typeof(Presets.firstCatchWow))
	local character = Players.LocalPlayer.Character
	local animator = if character ~= nil
		then character:FindFirstChildWhichIsA("Animator", true)
		else nil
	if animator == nil then
		return
	end
	local own: { [AnimationTrack]: number } = {}
	local set: { [AnimationTrack]: number } = {}
	local slowed = 0
	local who = character :: Model
	local function hold()
		for _, track in (animator :: Animator):GetPlayingAnimationTracks() do
			if own[track] == nil then
				slowed += 1
			end
			local speed, base =
				FirstCatchWow.holdSpeed(track.Speed, own[track], set[track], p.slowSpeed)
			own[track] = base
			if math.abs(track.Speed - speed) > 1e-3 then
				track:AdjustSpeed(speed)
			end
			set[track] = speed
		end
		-- for Sync's Studio check: how many of your character's playing tracks were slowed, and the speed while it lasts
		who:SetAttribute("FirstCatchSlowTracks", slowed)
	end
	who:SetAttribute("FirstCatchSlowSpeed", p.slowSpeed)
	hold()
	local name = "FirstCatchWowSlow"
	RunService:BindToRenderStep(name, Enum.RenderPriority.Last.Value, hold)
	task.delay(p.slowSeconds, function()
		RunService:UnbindFromRenderStep(name)
		who:SetAttribute("FirstCatchSlowSpeed", nil)
		for track, speed in own do
			local mine = set[track]
			if track.IsPlaying and mine ~= nil and math.abs(track.Speed - mine) <= 1e-3 then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

-- Plays the moment for the catch of stray `strayId` (a `rarity` cat). False when it cannot: one already running, no
-- camera or no PlayerGui. The switch is the caller's to check (FirstCatchWow.on).
function FirstCatchWow.play(strayId: string?, rarity: string?): boolean
	local camera = Workspace.CurrentCamera
	if running or camera == nil then
		return false
	end
	local p = Presets.firstCatchWow
	local gui = ScreenFx.gui(FirstCatchWow.GUI, p.displayOrder)
	if gui == nil then
		return false
	end
	running = true
	local reduced = Context.reducedMotion()
	local model = if type(strayId) == "string" then strayById(strayId) else nil
	local cat: Vector3? = nil
	local ground: Vector3? = nil
	if model ~= nil then
		local frame, size = (model :: Model):GetBoundingBox()
		cat = frame.Position + Vector3.new(0, size.Y / 2 + 0.3, 0)
		ground = frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
	end
	local banner = FirstCatchWow.banner(gui)
	local began = os.clock()
	local popped = false
	if not reduced then
		slowAnimations(p)
		if cat ~= nil then
			local target = cat :: Vector3
			RunService:BindToRenderStep(PUSH_STEP, Enum.RenderPriority.Camera.Value + 1, function()
				local push = FirstCatchWow.at(os.clock() - began, p)
				local cam = Workspace.CurrentCamera
				if cam ~= nil and push > 0 then
					local eye = cam.CFrame.Position
					cam.CFrame = cam.CFrame + (target - eye) * (p.push * push)
				end
			end)
		end
	end
	local length = FirstCatchWow.length(p)
	local lastBanner = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - began
		local _, _, a = FirstCatchWow.at(t, p)
		FirstCatchWow.show(banner, a, t < p.bannerAt + p.bannerIn and a >= lastBanner)
		lastBanner = a
		if not popped and t >= p.popAt then
			popped = true
			if not reduced and cat ~= nil and ground ~= nil then
				local colour = Logic.glowColour(rarity or "Common")
				local ring = Logic.catchPop(rarity or "Common")
				local part =
					Particles.ring(ground :: Vector3, colour, ring * p.ringScale, p.ringSeconds)
				if part ~= nil then
					-- named and sized for Sync's Studio check (ClientEffects.FirstCatchRing, its Diameter attribute)
					part.Name = "FirstCatchRing"
					part:SetAttribute("Diameter", ring * p.ringScale)
				end
				Particles.confetti(
					cat :: Vector3,
					FirstCatchWow.confetti(
						Context.budget.confetti,
						Context.tier == "low" or phone(),
						p
					),
					p.colours
				)
				local screen, visible = camera:WorldToViewportPoint(cat :: Vector3)
				local from = if visible
					then ScreenFx.toGui(gui, Vector2.new(screen.X, screen.Y))
					else Vector2.new(gui.AbsoluteSize.X / 2, gui.AbsoluteSize.Y / 2)
				FirstCatchWow.flyCoins(gui, from, p)
			end
		end
		if t >= length then
			if connection ~= nil then
				connection:Disconnect()
			end
			RunService:UnbindFromRenderStep(PUSH_STEP)
			banner:Destroy()
			running = false
		end
	end)
	return true
end

return FirstCatchWow
