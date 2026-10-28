--!strict
-- The intro cutscene's screen (F72, docs/design/cat-cafe/intro-cutscene.md section 4; Derek 2026-10-27 20:45: a
-- quick fly-through before a new player plays, the important things first, a small Skip after a couple of
-- seconds). The engineer's IntroController moves the camera and calls UI.intro; this draws over it:
--   letterbox bars   9% of the screen each, near black; they slide in on start and out over 0.45 s at the end
--   caption          one line just above the lower bar, popping from 0.9 to full size on each shot
--   shot dots        one per shot on the top bar (IntroLogic.SHOTS, from shared/Intro), the current one gold
--   title card       the areas shot's names, one per cut, slammed in the middle of the screen
--   demo ring        shot 2's closing catch circle over the stray: PERFECT at 1.3 s, a sparkle to 2.0 s
--   job card         shot 4's four role buttons in miniature beside the cat; the given role lights with a tap
--   Skip             an outlined "Skip »" pill on the lower bar at the right, on screen from the start and dimmed,
--                    with a gold bar filling it over skipAfter (Derek 2026-10-28: "show a bar loading it's ability
--                    to be pressed make it 5 seconds"). Full, it brightens and pops; a tap, a click or gamepad B
--                    then fires callbacks.skip(shot) once, and the controller ends the intro and calls finish. An
--                    early press only shakes it. A replay starts full.
-- Numbers live in Components/IntroLogic.
--
-- Roblox terms: Camera:WorldToViewportPoint turns a world position into a screen pixel for the current camera,
-- and a ScreenGui with IgnoreGuiInset covers the whole screen (Roblox's top bar strip too), so the two agree.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local IntroLogic = require(script.Parent.Parent.Components.IntroLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Parent.Components.Signal)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	skip: (shot: number) -> (), -- Skip or gamepad B, once per play
	ended: (replay: boolean) -> (), -- the end began (finish, or the Skip fallback): bring the HUD back
}

export type Intro = {
	screenGui: ScreenGui,
	start: (self: Intro, options: Types.IntroOptions?) -> (),
	setShot: (self: Intro, index: number, caption: string, titleCard: string?) -> (),
	demoCatch: (self: Intro, worldPosition: Vector3) -> (),
	jobCard: (self: Intro, worldPosition: Vector3, role: string) -> (),
	finish: (self: Intro) -> (),
	playing: (self: Intro) -> boolean,
	destroy: (self: Intro) -> (),
}

local BAR = IntroLogic.BAR
local BAR_TRANSPARENCY = 0.08 -- near black, the world just showing through
local BARS_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OUT = IntroLogic.OUT_SECONDS
local BARS_OUT = TweenInfo.new(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAPTION_POP = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TITLE_SLAM = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SIDE = 24 -- design pixels kept clear at the screen's sides
local CAPTION_HEIGHT = 44
local CAPTION_TEXT = 30
local TITLE_TEXT = 64
local DOT = 10
local DOT_NOW = 14
local DOT_GAP = 8
local SKIP_WIDTH = 116
local SKIP_ACTION = "CatCafeIntroSkip"
local SKIP_DIM = 0.5 -- Skip's label and outline while its bar fills
local SKIP_POP = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true) -- to 1.1 and back
local SKIP_SHAKE = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true)
-- shot 4's job card: four role tiles beside the cat, a little right of it and up
local JOB_TILE = 44
local JOB_GAP = 6
local JOB_PAD = 8
local JOB_OFFSET = Vector2.new(70, -60)
-- the demo ring in the catch circles' look (Screens/CatchCircles)
local RING_RADIUS = IntroLogic.RING_RADIUS
local RING_THICKNESS = 4
local GOOD_BAND = 14
local PERFECT_BAND = 5
local SPARKLES = 8
local SPARKLE_REACH = RING_RADIUS + 36
local SPARKLE_OUT = TweenInfo.new(
	IntroLogic.END - IntroLogic.CLOSE,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local Intro = {}
Intro.__index = Intro

-- A ring from `inner` to `outer` radius: a circle of the inner radius with its stroke outside it, as the catch
-- circles are drawn.
local function ring(
	name: string,
	inner: number,
	outer: number,
	color: Color3,
	transparency: number,
	parent: Instance
): (Frame, UIStroke)
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(inner * 2, inner * 2),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = color,
		Thickness = math.max(1, outer - inner),
		Transparency = transparency,
		Parent = frame,
	})
	return frame, stroke
end

-- Eight gold diamonds flying out from the ring as PERFECT pops, gone by the end of the demo.
local function sparkle(holder: Frame)
	for index = 1, SPARKLES do
		local angle = (index - 1) / SPARKLES * math.pi * 2
		local dx, dy = math.cos(angle), math.sin(angle)
		local spark: Frame = Create("Frame", {
			Name = "Sparkle",
			BackgroundColor3 = Theme.colors.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, dx * RING_RADIUS, 0.5, dy * RING_RADIUS),
			Rotation = 45,
			Size = UDim2.fromOffset(10, 10),
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 2) }) })
		Tween.to(spark, SPARKLE_OUT, {
			Position = UDim2.new(0.5, dx * SPARKLE_REACH, 0.5, dy * SPARKLE_REACH),
			Size = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
		})
	end
end

function Intro.new(parent: Instance, callbacks: Callbacks): Intro
	local self = setmetatable({}, Intro) :: any
	self._callbacks = callbacks
	self._alive = true
	self._playing = false
	self._replay = false
	self._skipped = false
	self._skipShown = false
	self._skipReady = false -- the bar is full, so a press skips
	self._shot = 0
	self._caption = nil :: string?
	self._token = 0 -- one per start and finish, so a late timer cannot touch a newer play
	self._ring = nil :: Frame?
	self._ringLoop = nil :: RBXScriptConnection?
	self._job = nil :: Frame?
	self._jobLoop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeIntro",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50, -- over the popups (40) and everything else while it plays
		Enabled = false,
	})
	self.screenGui = screenGui

	local function bar(name: string): Frame
		return Create("Frame", {
			Name = name,
			BackgroundColor3 = Theme.colors.black,
			BackgroundTransparency = BAR_TRANSPARENCY,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, BAR),
			Parent = screenGui,
		})
	end
	self._top = bar("TopBar")
	self._bottom = bar("BottomBar")

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = screenGui,
	})
	self._root = root
	self._uiScale = Scale.bind(root)

	self._ringLayer = Create("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	-- the shot dots, centred on the top bar
	local dots: Frame = Create("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, BAR / 2),
		Size = UDim2.fromOffset(IntroLogic.SHOTS * (DOT_NOW + DOT_GAP), DOT_NOW),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, DOT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._dots = {} :: { Frame }
	for index = 1, IntroLogic.SHOTS do
		self._dots[index] = Create("Frame", {
			Name = "Dot" .. index,
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(DOT, DOT),
			Parent = dots,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- the caption, just above the lower bar; a long one shrinks to stay on one line
	local caption: TextLabel = Create("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - BAR, -10),
		Size = UDim2.new(1, -2 * SIDE, 0, CAPTION_HEIGHT),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextScaled = true,
		Text = "",
		Parent = root,
	}, { Create("UITextSizeConstraint", { MaxTextSize = CAPTION_TEXT, MinTextSize = 14 }) })
	Outline.text(caption, 3)
	self._captionLabel = caption
	self._captionScale = Create("UIScale", { Parent = caption })

	-- shot 5's area name
	local title: TextLabel = Create("TextLabel", {
		Name = "TitleCard",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -2 * SIDE, 0, TITLE_TEXT + 16),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextScaled = true,
		Text = "",
		Visible = false,
		Parent = root,
	}, { Create("UITextSizeConstraint", { MaxTextSize = TITLE_TEXT, MinTextSize = 24 }) })
	Outline.text(title, 4)
	self._title = title
	self._titleScale = Create("UIScale", { Parent = title })

	-- Skip: a dark pill with a light outline on the lower bar at the right, and a gold bar filling it
	local skip: TextButton = Create("TextButton", {
		Name = "Skip",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromOffset(SKIP_WIDTH, IntroLogic.SKIP_HEIGHT),
		Visible = false,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._skipStroke = Outline.border(skip, 2, Theme.colors.paper)
	self._skipScale = Create("UIScale", { Parent = skip })
	self._skipFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = skip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local skipLabel: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		TextColor3 = Theme.colors.white,
		Text = "Skip »",
		ZIndex = 2,
		Parent = skip,
	})
	self._skipLabelStroke = Outline.text(skipLabel, 2)
	self._skipButton = skip
	self._skipLabel = skipLabel
	table.insert(
		self._connections,
		skip.Activated:Connect(function()
			self:_skip()
		end)
	)

	self._scaleConnection = Scale.changed:Connect(function()
		self:_layout()
	end) :: Signal.Connection
	self:_layout()
	screenGui.Parent = parent
	return self :: Intro
end

-- The Skip pill grows to a finger's size on touch and sits on the lower bar however tall the screen is.
function Intro._layout(self: any)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Scale.DESIGN
	local height, below = IntroLogic.skipPlace(viewport.Y, Scale.get(), Scale.isTouch())
	self._skipButton.Size = UDim2.fromOffset(SKIP_WIDTH + height - IntroLogic.SKIP_HEIGHT, height)
	self._skipButton.Position = UDim2.new(1, -SIDE, 1, -below)
end

function Intro._renderDots(self: any)
	for index, dot: Frame in self._dots do
		local look = IntroLogic.dot(index, self._shot)
		local size = if look == "now" then DOT_NOW else DOT
		dot.Size = UDim2.fromOffset(size, size)
		dot.BackgroundColor3 = if look == "now" then Theme.colors.gold else Theme.colors.paper
		dot.BackgroundTransparency = if look == "next" then 0.6 else 0
	end
end

-- Plays from the top: bars in, dots reset, Skip after skipAfter seconds (IntroLogic.skipAfter).
function Intro.start(self: any, options: Types.IntroOptions?)
	self._token += 1
	local token = self._token
	self:_clearRing()
	self:_clearJob()
	self:_hideSkip()
	self._playing = true
	self._replay = options ~= nil and options.replay == true
	self._skipped = false
	self._shot = 0
	self._caption = nil
	self._captionLabel.Text = ""
	self._title.Visible = false
	self._root.Visible = true
	self:_renderDots()
	self:_layout()
	self._top.Position = UDim2.fromScale(0, -BAR)
	self._bottom.Position = UDim2.fromScale(0, 1)
	Tween.to(self._top, BARS_IN, { Position = UDim2.fromScale(0, 0) })
	Tween.to(self._bottom, BARS_IN, { Position = UDim2.fromScale(0, 1 - BAR) })
	self.screenGui.Enabled = true
	local wait = IntroLogic.skipAfter(options)
	self:_showSkip(wait)
	if wait > 0 then
		task.delay(wait, function()
			if self._alive and self._playing and token == self._token then
				self:_readySkip(true)
			end
		end)
	end
end

-- A new shot: its dot turns gold and its caption pops. Within the areas shot the controller calls again for each cut
-- with the next title card; the caption then stays put and only the card slams in.
function Intro.setShot(self: any, index: number, caption: string, titleCard: string?)
	if not self._playing then
		return
	end
	local shot = math.clamp(math.floor(index), 1, IntroLogic.SHOTS)
	if shot ~= self._shot or caption ~= self._caption then
		self._captionLabel.Text = caption
		self._captionScale.Scale = 0.9
		Tween.to(self._captionScale, CAPTION_POP, { Scale = 1 })
	end
	self._shot = shot
	self._caption = caption
	self:_renderDots()
	if titleCard and titleCard ~= "" then
		self._title.Text = titleCard
		self._title.Visible = true
		self._titleScale.Scale = 1.25
		Tween.to(self._titleScale, TITLE_SLAM, { Scale = 1 })
	else
		self._title.Visible = false
	end
end

-- Shot 2's demo catch over the stray: the circle closes onto its ring in 1.3 s, PERFECT pops with the catch
-- sound and a gold sparkle, and it all fades by 2.0 s. It follows the stray's screen position while the camera
-- pushes in, and hides while the point is behind the camera.
function Intro.demoCatch(self: any, worldPosition: Vector3)
	self:_clearRing()
	if not self._playing then
		return
	end
	local holder: Frame = Create("Frame", {
		Name = "DemoRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = self._ringLayer,
	})
	local scale: UIScale = Create("UIScale", { Parent = holder })
	ring(
		"GoodBand",
		RING_RADIUS - GOOD_BAND,
		RING_RADIUS + GOOD_BAND,
		Theme.colors.good,
		0.45,
		holder
	)
	ring(
		"PerfectBand",
		RING_RADIUS - PERFECT_BAND,
		RING_RADIUS + PERFECT_BAND,
		Theme.colors.gold,
		0.1,
		holder
	)
	local half = RING_THICKNESS / 2
	local _, ringStroke =
		ring("Ring", RING_RADIUS - half, RING_RADIUS + half, Theme.colors.paper, 0, holder)
	local start = IntroLogic.START_RADIUS
	local closer = ring("Closer", start, start + RING_THICKNESS, Theme.colors.paper, 0, holder)
	local grade: TextLabel = Create("TextLabel", {
		Name = "Grade",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -(RING_RADIUS + 8)),
		Size = UDim2.fromOffset(180, 36),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		TextColor3 = Theme.colors.gold,
		Text = "PERFECT!",
		Visible = false,
		Parent = holder,
	})
	Outline.text(grade, 3)
	self._ring = holder

	local started = os.clock()
	local popped = false
	local fading = false
	self._ringLoop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= IntroLogic.END then
			self:_clearRing()
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(worldPosition)
			local viewport = camera.ViewportSize
			holder.Visible = point.Z > 0 and viewport.X > 0 and viewport.Y > 0
			if holder.Visible then
				holder.Position = UDim2.fromScale(point.X / viewport.X, point.Y / viewport.Y)
			end
		end
		local radius = IntroLogic.closerRadius(t)
		closer.Size = UDim2.fromOffset(radius * 2, radius * 2)
		if not popped and t >= IntroLogic.CLOSE then
			popped = true
			closer.Visible = false
			ringStroke.Color = Theme.colors.gold
			grade.Visible = true
			Tween.popIn(grade, 0.6)
			scale.Scale = 1.12
			Tween.to(scale, Tween.POP, { Scale = 1 })
			Sound.play("circlePerfect")
			sparkle(holder)
		end
		if not fading and t >= IntroLogic.FADE_FROM then
			fading = true
			for _, part in holder:GetDescendants() do
				if part:IsA("UIStroke") then
					Tween.to(part, FADE, { Transparency = 1 })
				elseif part:IsA("TextLabel") then
					Tween.to(part, FADE, { TextTransparency = 1 })
				end
			end
		end
	end)
end

function Intro._clearRing(self: any)
	local loop: RBXScriptConnection? = self._ringLoop
	if loop then
		loop:Disconnect()
		self._ringLoop = nil
	end
	local holder: Frame? = self._ring
	if holder then
		holder:Destroy()
		self._ring = nil
	end
end

-- Shot 4's job card beside the cat at `worldPosition`: the four role tiles in miniature, `role`'s lighting up
-- with a tap JOB_TAP later, the card gone JOB_GONE after it showed, as the cat takes its spot. It follows the
-- cat's screen position and hides while the point is behind the camera.
function Intro.jobCard(self: any, worldPosition: Vector3, role: string)
	self:_clearJob()
	if not self._playing then
		return
	end
	local count = #IntroLogic.ROLES
	local card: Frame = Create("Frame", {
		Name = "JobCard",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(
			count * JOB_TILE + (count - 1) * JOB_GAP + 2 * JOB_PAD,
			JOB_TILE + 2 * JOB_PAD
		),
		Visible = false,
		Parent = self._ringLayer,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, JOB_PAD),
			PaddingRight = UDim.new(0, JOB_PAD),
			PaddingTop = UDim.new(0, JOB_PAD),
			PaddingBottom = UDim.new(0, JOB_PAD),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, JOB_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Outline.border(card, 3)
	local lit: Frame? = nil
	for index, id in IntroLogic.ROLES do
		local tile: Frame = Create("Frame", {
			Name = id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(JOB_TILE, JOB_TILE),
			Parent = card,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("TextLabel", {
				Name = "Glyph",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.body,
				TextSize = 24,
				Text = Theme.roleIcons[id] or "",
			}),
		})
		Outline.border(tile, 2)
		if id == role then
			lit = tile
		end
	end
	self._job = card

	local started = os.clock()
	local tapped, leaving = false, false
	self._jobLoop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(worldPosition)
			local viewport = camera.ViewportSize
			card.Visible = point.Z > 0 and viewport.X > 0 and viewport.Y > 0
			if card.Visible then
				-- the screen point as a fraction of the screen, the offset in design pixels like the card
				card.Position = UDim2.new(
					point.X / viewport.X,
					JOB_OFFSET.X,
					point.Y / viewport.Y,
					JOB_OFFSET.Y
				)
			end
		end
		if not tapped and t >= IntroLogic.JOB_TAP then
			tapped = true
			if lit then
				lit.BackgroundColor3 = Theme.colors.good
				Tween.popIn(lit, 0.8)
			end
			Sound.play("uiClick")
		end
		if not leaving and t >= IntroLogic.JOB_GONE - Tween.SETTLE.Time then
			leaving = true
			Tween.popOut(card, function()
				if self._job == card then
					self:_clearJob()
				end
			end)
		end
	end)
	Tween.popIn(card, 0.6)
end

function Intro._clearJob(self: any)
	local loop: RBXScriptConnection? = self._jobLoop
	if loop then
		loop:Disconnect()
		self._jobLoop = nil
	end
	local card: Frame? = self._job
	if card then
		card:Destroy()
		self._job = nil
	end
end

-- Skip on screen from the start, dimmed, its bar filling over `wait` seconds; with no wait it is ready at once.
-- Gamepad B is bound from the start too, so an early press can shake the pill.
function Intro._showSkip(self: any, wait: number)
	self._skipShown = true
	local skip: TextButton = self._skipButton
	skip.Visible = true
	self._skipScale.Scale = 1
	skip.Rotation = 0
	local fill: Frame = self._skipFill
	fill.Size = UDim2.fromScale(IntroLogic.skipFill(0, wait), 1)
	if wait > 0 then
		self:_readySkip(false)
		Tween.to(
			fill,
			TweenInfo.new(wait, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 1) }
		)
	else
		self:_readySkip(nil)
	end
	ContextActionService:BindActionAtPriority(
		SKIP_ACTION,
		function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				self:_skip()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
end

-- Skip's look: dimmed while its bar fills (false), full once ready (true pops it to 1.1 and back; nil, a
-- replay's, does not).
function Intro._readySkip(self: any, ready: boolean?)
	self._skipReady = ready ~= false
	local alpha = if ready == false then SKIP_DIM else 0
	self._skipStroke.Transparency = alpha
	self._skipLabel.TextTransparency = alpha
	self._skipLabelStroke.Transparency = alpha
	if ready == true then
		self._skipFill.Size = UDim2.fromScale(1, 1)
		Tween.to(self._skipScale, SKIP_POP, { Scale = 1.1 })
	end
end

function Intro._hideSkip(self: any)
	if self._skipShown then
		ContextActionService:UnbindAction(SKIP_ACTION)
	end
	self._skipShown = false
	self._skipReady = false
	self._skipButton.Visible = false
end

-- Fires callbacks.skip once with the shot showing. If the controller has not ended the intro SKIP_FALLBACK
-- seconds later (a script error mid-intro), the screen ends itself so the HUD comes back.
function Intro._skip(self: any)
	if not self._playing or self._skipped or not self._skipShown then
		return
	end
	if not self._skipReady then
		-- the bar is still filling: a small shake, nothing else
		local skip: TextButton = self._skipButton
		skip.Rotation = 0
		Tween.to(skip, SKIP_SHAKE, { Rotation = 5 })
		return
	end
	self._skipped = true
	Sound.play("uiClick")
	Tween.to(self._skipLabel, FADE, { TextTransparency = 0.5 })
	local token = self._token
	self._callbacks.skip(IntroLogic.skipShot(self._shot))
	task.delay(IntroLogic.SKIP_FALLBACK, function()
		if self._alive and self._playing and token == self._token then
			self:finish()
		end
	end)
end

-- The end: the caption, dots and Skip go at once and the bars slide off over OUT_SECONDS while the HUD comes
-- back under them (callbacks.ended).
function Intro.finish(self: any)
	if not self._playing then
		return
	end
	self._playing = false
	self._token += 1
	local token = self._token
	self:_clearRing()
	self:_clearJob()
	self:_hideSkip()
	self._root.Visible = false
	Tween.to(self._top, BARS_OUT, { Position = UDim2.fromScale(0, -BAR) })
	Tween.to(self._bottom, BARS_OUT, { Position = UDim2.fromScale(0, 1) })
	task.delay(IntroLogic.OUT_SECONDS, function()
		if self._alive and token == self._token then
			self.screenGui.Enabled = false
		end
	end)
	self._callbacks.ended(self._replay)
end

function Intro.playing(self: any): boolean
	return self._playing
end

function Intro.destroy(self: any)
	self._alive = false
	self._playing = false
	self:_clearRing()
	self:_clearJob()
	self:_hideSkip()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._scaleConnection:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return Intro
