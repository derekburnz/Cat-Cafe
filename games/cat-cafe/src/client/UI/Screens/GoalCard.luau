--!strict
-- Tier and next goal (F39 P1; lighter HUD, Derek 2026-10-28: "these ui boxes need some fixing they clutter up the
-- screen too much... I don't think a lot of those even need backgrounds"): one block on the right of the HUD with no
-- box, outlined text over the world like the counters of Steal a Brainrot or Grow a Garden. Top down:
--   "Tier 1 · Corner Cafe"   small, the tier the cafe is at (it replaced the top centre tier pill)
--   "Next: Cozy Cafe"        the next tier's name; once every requirement is met just the name in gold, with a red
--                            "Rank up!" sticker at its left
--   Coins      $879 / $1.5K  per rank up requirement a caption and its numbers over a slim bar, the same numbers as
--   [=======-----]           the rank up card; a bar turns gold when its requirement is met
-- At the top tier only the tier line shows. A tap anywhere on it opens the rank up card.
-- #1919 (first-hour.md section 5): while the Grand Opening's twelve cats step is next and no rank up is ready, the
-- card reads "📖 Find 3 more cats" alone (render's `nudge`), and the HUD opens the Index from it instead.
-- #2331 (Derek2: "cozy cafe (tier up cafe) is more obviously your main goal to tier up and maybe flash and point
-- towards it when tier up is ready"): a gold "🏆 YOUR GOAL" line over a bigger tier name, and a gold edge, so the card
-- reads as the goal. Once every requirement is met its edge pulses gold and white and the tutorial's big arrow
-- (Components/TutorialArrow, as a low target so a tutorial step keeps the arrow) points at it, until the player opens
-- the rank up card (seen()). Once per ready state: it comes back only after the rank up stops being ready and is
-- ready again, or for the next tier.
-- #2714 (Derek2 11-09: "let you shrink down your goal so they have more screen space"): on touch a white ▶ arrow
-- button (#2828, like the HUD's other folds) at the card's left folds it into one finger-tall chip, "🏆 Grand Cafe 2/3" or a gold "🏆 Rank up!" (Components/GoalFold);
-- a tap on the chip opens it again. The choice is the goalFolded setting, saved through `onFold`. The ready pulse and
-- arrow stay on the chip.
-- #3022 (Derek2 11-10: "make it obvious to go catch second cat ... and progress 'your goal'"): render's `goal`
-- (Components/SecondCatGoal's view) takes the card over from the first customer served until the second cat: the
-- gold "🏆 YOUR GOAL" line, the goal's title in place of the tier's name, and its preview lines under it while the
-- HUD passes them. No bars: a tap still opens the rank up card. A ready rank up comes first, as for the nudge.
-- bounce() pops the card once (not with Reduce Motion): the HUD calls it as the goal changes and once more later.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local GoalFold = require(script.Parent.Parent.Components.GoalFold)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent.Parent.Components.TutorialArrow)
local Tween = require(script.Parent.Parent.Components.Tween)

export type GoalCard = {
	frame: TextButton,
	render: (
		self: GoalCard,
		progress: RankUp.Progress?,
		tierText: string,
		nudge: string?,
		goal: Goal?
	) -> (),
	setGoal: (self: GoalCard, goal: Goal?) -> (), -- #3022: the last render again with this goal
	bounce: (self: GoalCard) -> (), -- #3022: one pop of the card
	nudging: (self: GoalCard) -> boolean, -- the card shows the nudge, so a tap should open the Index
	setFolded: (self: GoalCard, folded: boolean) -> (), -- #2714: fold into the chip, or open again
	folded: (self: GoalCard) -> boolean,
	seen: (self: GoalCard) -> (), -- #2331: the rank up card opened, so the ready pulse and arrow stop
	alerting: (self: GoalCard) -> boolean, -- #2331: the ready pulse and arrow are on
	destroy: (self: GoalCard) -> (),
}

-- #3022: a goal that takes the card over (the HUD builds it from Components/SecondCatGoal.View): its title, the
-- lines under it (at most GOAL_LINES) and the folded chip's line
export type Goal = { title: string, lines: { string }, chip: string }

-- #2447: a requirement's shorter caption on a touch screen
local TOUCH_SHORT: { [string]: string } = { ["Different cats"] = "Cats" }

-- The compact card of Derek's 11-04 HUD mockup (#1176): a dark rounded card with the next tier's name, a pink
-- "Rank up!" pill at its right once ready and a thin bar per requirement under its caption and numbers ("Coins
-- $879 / $1.5K", "Different cats ✓"; the friend 11-04: "put the labels back"). At the top tier the card holds the
-- tier's line alone.
-- #2397 (Derek2 11-08: "shrink the your goal box by at least 25% to free up more screen space", then "net overlaps
-- your goal bubble so make sure your goal is much smaller", #2415): on touch the card is about 30% narrower and 30%
-- shorter (half the screen), with tight rows, smaller captions, title and sticker
local TOUCH = Scale.isTouch()
local WIDTH = if TOUCH then 180 else 250
local PAD = if TOUCH then 6 else 10
local TIER_H = if TOUCH then 15 else 18
local GOAL_H = if TOUCH then 12 else 16 -- #2331: the "YOUR GOAL" line over the title
local GOAL_TEXT = "🏆 YOUR GOAL"
local TITLE_H = if TOUCH then 20 else 30
local TITLE_TEXT = if TOUCH then Theme.sizes.textBody else Theme.sizes.textBody + 6
local BADGE_ROOM = if TOUCH then 66 else 96 -- the title's room left of the "Rank up!" sticker
local BADGE_H = if TOUCH then 18 else 22
local BADGE_TEXT = if TOUCH then Theme.sizes.textTiny else Theme.sizes.textSmall
local BADGE_PAD = if TOUCH then 6 else 10
local CAPTION_TEXT = if TOUCH then Theme.sizes.textTiny + 1 else Theme.sizes.textSmall
local TOP = GOAL_H + TITLE_H + 4 -- the first bar
local EDGE = 2.5 -- #2331: the gold edge, pulsing up to EDGE_READY while a rank up waits
local EDGE_READY = 5
local PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local CAPTION_H = if TOUCH then 14 else 17
local BAR_H = if TOUCH then 4 else 7
local ROW = CAPTION_H + 2 + BAR_H
local ROW_GAP = if TOUCH then 2 else 6
local CARD_TRANSPARENCY = 0.12
local PILL_COLOR = Color3.fromHex("FF6B81")
local ROWS = 3
local SMALL_OUTLINE = 2 -- small text over the bright world needs a little more outline than in a window
local ICON = 24 -- the nudge's Index icon
local NUDGE_CAPTION = "Tap to see where in the Index"
local GOAL_LINES = 3 -- #3022: lines under a goal's title (a wide card's money line and two preview lines)
local GOAL_LINE_GAP = 1
-- #2828: the fold button, the HUD's white arrow button (HUD's FOLD_W x FOLD_H), FOLD_GAP left of the card's edge
local FOLD_W = 44
local FOLD_H = 34
local FOLD_GAP = 6

type Row = { frame: Frame, fill: Frame, label: TextLabel, status: TextLabel }

local GoalCard = {}
GoalCard.__index = GoalCard

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local label: TextLabel = Create("TextLabel", merged)
	Outline.text(label, if label.TextSize < 20 then SMALL_OUTLINE else nil)
	return label
end

function GoalCard.new(
	parent: Instance,
	position: UDim2,
	onOpen: () -> (),
	onFold: ((folded: boolean) -> ())?
): GoalCard
	local self = setmetatable({}, GoalCard) :: any
	self._folded = false
	self._onFold = onFold
	self._last =
		nil :: { progress: RankUp.Progress?, tierText: string, nudge: string?, goal: Goal? }?

	-- the whole block is the button
	local frame: TextButton = Create("TextButton", {
		Name = "TierGoal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.outline,
		BackgroundTransparency = CARD_TRANSPARENCY,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(WIDTH, TIER_H + PAD * 2),
		Visible = false,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, PAD + 2),
			PaddingRight = UDim.new(0, PAD + 2),
			PaddingTop = UDim.new(0, PAD),
			PaddingBottom = UDim.new(0, PAD),
		}),
	})
	self._edge = Outline.border(frame, EDGE, Theme.colors.gold)
	self._pulse = nil :: Tween?
	self._alerting = false
	self._seenKey = nil :: string?
	self.frame = frame

	self._tier = text({
		Name = "Tier",
		Size = UDim2.new(1, 0, 0, TIER_H),
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	self._goalLine = text({
		Name = "Goal",
		Size = UDim2.new(1, 0, 0, GOAL_H),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = GOAL_TEXT,
		Visible = false,
		Parent = frame,
	})
	self._title = text({
		Name = "Title",
		Size = UDim2.new(1, -BADGE_ROOM, 0, TITLE_H),
		TextSize = TITLE_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	FitText.shrink(self._title) -- #2331: a long tier name or the nudge shrinks to fit the bigger title
	-- the simulator "something to claim" sticker, tilted at the left of the title while a rank up is ready
	self._badge = Create("TextLabel", {
		Name = "RankReady",
		BackgroundColor3 = PILL_COLOR,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, GOAL_H + TITLE_H / 2),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, BADGE_H),
		FontFace = Theme.fonts.display,
		TextSize = BADGE_TEXT,
		TextColor3 = Theme.colors.white,
		Text = "Rank up!",
		Visible = false,
		ZIndex = 3,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, BADGE_PAD), PaddingRight = UDim.new(0, BADGE_PAD) }
		),
	})
	Outline.text(self._badge)
	Outline.border(self._badge, 2)
	-- #1919: the nudge's Index icon, the HUD's Index picture with the book emoji until it loads
	self._icon = text({
		Name = "IndexIcon",
		Position = UDim2.fromOffset(0, (TITLE_H - ICON) / 2),
		Size = UDim2.fromOffset(ICON, ICON),
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = "📖",
		Visible = false,
		Parent = frame,
	})
	IconArt.setImage(self._icon, ShopIcons.hud("Index"))
	-- under the nudge, so the card stays a finger tall on a phone
	self._caption = text({
		Name = "Caption",
		Position = UDim2.fromOffset(0, TITLE_H + 2),
		Size = UDim2.new(1, 0, 0, CAPTION_H),
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = NUDGE_CAPTION,
		Visible = false,
		Parent = frame,
	})
	self._nudging = false
	-- #3022: a goal's preview lines, under its title; a long one shrinks to fit the card
	local goalLines: { TextLabel } = {}
	for index = 1, GOAL_LINES do
		local line = text({
			Name = "GoalLine" .. index,
			Position = UDim2.fromOffset(
				0,
				GOAL_H + TITLE_H + 2 + (index - 1) * (CAPTION_H + GOAL_LINE_GAP)
			),
			Size = UDim2.new(1, 0, 0, CAPTION_H),
			TextSize = CAPTION_TEXT,
			TextColor3 = Theme.colors.gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = false,
			Parent = frame,
		})
		FitText.shrink(line)
		goalLines[index] = line
	end
	self._goalLines = goalLines

	local rows: { Row } = {}
	for index = 1, ROWS do
		local row: Frame = Create("Frame", {
			Name = "Row" .. index,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, TOP + (index - 1) * (ROW + ROW_GAP)),
			Size = UDim2.new(1, 0, 0, ROW),
			Parent = frame,
		})
		-- slim bar: dark trough with an outline, shaded mint fill
		local track: Frame = Create("Frame", {
			Name = "Bar",
			BackgroundColor3 = Theme.colors.ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, CAPTION_H + 2),
			Size = UDim2.new(1, 0, 0, BAR_H),
			Parent = row,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(track, 1.5)
		local fill: Frame = Create("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.colors.mint,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.shade(fill, 0.25)
		rows[index] = {
			frame = row,
			fill = fill,
			label = text({
				Name = "Label",
				Size = UDim2.new(0.55, 0, 0, CAPTION_H),
				TextSize = CAPTION_TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			status = text({
				Name = "Status",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.45, 0, 0, CAPTION_H),
				TextSize = CAPTION_TEXT,
				Parent = row,
			}),
		}
		-- #2207: "Legendary or better" ran past its half on a phone; a long caption shrinks a little instead
		FitText.shrink(rows[index].label)
		FitText.shrink(rows[index].status)
	end
	self._rows = rows
	self._ready = false

	-- #2714: the fold button on touch, just left of the card (the card's own tap opens the rank up). #2828 (Derek2 11-09:
	-- "make the goal shrinking arrow way more obvious it's just a little box right now", "set it to be one of the white
	-- arrows like the rest"): the same white ghost arrow button as the HUD's menu fold (◀ ▶) and travel fold (▲ ▼),
	-- the same size, "▶" toward the screen's right edge the card folds to. Components/Button's Hit pad takes the tap.
	local fold = Button.new({
		name = "Fold",
		text = "▶",
		style = "ghost",
		size = UDim2.fromOffset(FOLD_W, FOLD_H),
		textSize = Theme.sizes.textBody,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(0, -(PAD + 2) - FOLD_GAP, 0, 0),
		parent = frame,
		onClick = function()
			self:_toggleFold(true)
		end,
	})
	fold.instance.Visible = TOUCH
	self._foldButton = fold
	self._fold = fold.instance

	self._connection = frame.Activated:Connect(function()
		if self._folded then
			self:_toggleFold(false) -- the chip opens again; the next tap opens the rank up
			return
		end
		onOpen()
	end)
	return self :: GoalCard
end

-- #2714: a press on the tab or the chip: fold or open, re-render, and save the choice
function GoalCard._toggleFold(self: any, folded: boolean)
	self:setFolded(folded)
	local save: ((folded: boolean) -> ())? = self._onFold
	if save then
		save(folded)
	end
end

function GoalCard.setFolded(self: any, folded: boolean)
	folded = folded and TOUCH
	if folded == self._folded then
		return
	end
	self._folded = folded
	local last = self._last
	if last then
		self:render(last.progress, last.tierText, last.nudge, last.goal)
	end
end

-- #3022: the last render again with `goal` (nil: the tier goal back), for the HUD's preview timer
function GoalCard.setGoal(self: any, goal: Goal?)
	local last = self._last
	if last then
		self:render(last.progress, last.tierText, last.nudge, goal)
	end
end

-- #3022: one pop of the card, as the goal changes; nothing with Reduce Motion or while the card is hidden
function GoalCard.bounce(self: any)
	if GuiService.ReducedMotionEnabled or not self.frame.Visible then
		return
	end
	Tween.popIn(self.frame, 0.82)
end

function GoalCard.folded(self: any): boolean
	return self._folded == true
end

-- #2714: the chip, one finger-tall line; the ready pulse and arrow carry on round it
function GoalCard._renderFolded(self: any, progress: RankUp.Progress?, nudge: string?, goal: Goal?)
	-- #3022: a goal's chip line stands where the nudge's would (a ready rank up still comes first)
	local words, gold = GoalFold.chip(progress :: any, if goal then goal.chip else nudge)
	self._tier.Visible = false
	for _, line in self._goalLines do
		line.Visible = false
	end
	self._goalLine.Visible = false
	self._icon.Visible = false
	self._caption.Visible = false
	self._badge.Visible = false
	self._fold.Visible = false
	for _, row in self._rows do
		row.frame.Visible = false
	end
	local height = Scale.tapHeight(TITLE_H + PAD * 2)
	self._title.Visible = true
	self._title.Text = words
	self._title.TextColor3 = if gold then Theme.colors.gold else Theme.hud.text
	self._title.Position = UDim2.fromOffset(0, (height - PAD * 2 - TITLE_H) / 2)
	self._title.Size = UDim2.new(1, 0, 0, TITLE_H)
	self.frame.Size = UDim2.fromOffset(WIDTH, height)
	local ready = progress ~= nil and progress.ready
	self._ready = ready
	local nextTier = if progress then progress.nextTier else nil
	local key = if ready and nextTier then tostring(nextTier.name) else nil
	if key == nil then
		self._seenKey = nil
	end
	self:_alert(if key ~= nil and key ~= self._seenKey then key else nil)
end

-- progress nil (no tiers in the catalog yet) shows tierText alone.
function GoalCard.render(
	self: any,
	progress: RankUp.Progress?,
	tierText: string,
	nudge: string?,
	goal: Goal?
)
	self.frame.Visible = true
	self._last = { progress = progress, tierText = tierText, nudge = nudge, goal = goal }
	if self._folded then
		self:_renderFolded(progress, nudge, goal)
		return
	end
	self._fold.Visible = TOUCH
	self._tier.Text = tierText
	local ready = progress ~= nil and progress.ready
	-- #3022: a goal takes the card over (a ready rank up still comes first): the gold line, its title, its lines
	local shown = 0
	for index, line: TextLabel in self._goalLines do
		local words = if goal ~= nil and not ready then goal.lines[index] else nil
		line.Visible = words ~= nil
		if words ~= nil then
			line.Text = words
			shown = index
		end
	end
	if goal ~= nil and not ready then
		self._nudging = false
		self._icon.Visible = false
		self._caption.Visible = false
		self._tier.Visible = false
		self._badge.Visible = false
		self._ready = false
		for _, row in self._rows do
			row.frame.Visible = false
		end
		self._goalLine.Visible = true
		self._title.Visible = true
		self._title.Text = goal.title
		self._title.TextColor3 = Theme.hud.text
		self._title.Position = UDim2.fromOffset(0, GOAL_H)
		self._title.Size = UDim2.new(1, 0, 0, TITLE_H)
		local height = GOAL_H + TITLE_H
		if shown > 0 then
			height += 2 + shown * (CAPTION_H + GOAL_LINE_GAP) - GOAL_LINE_GAP
		end
		-- (a finger tall on touch, as the nudge: the card is a button)
		self.frame.Size = UDim2.fromOffset(WIDTH, Scale.tapHeight(height + PAD * 2))
		self._seenKey = nil
		self:_alert(nil)
		return
	end
	local nudging = nudge ~= nil and not ready -- a ready rank up still comes first
	self._nudging = nudging
	self._icon.Visible = nudging
	self._caption.Visible = nudging
	if nudging then
		self._tier.Visible = false
		self._title.Visible = true
		self._title.Text = nudge
		self._title.TextColor3 = Theme.hud.text
		self._title.Position = UDim2.fromOffset(ICON + 6, 0)
		self._title.Size = UDim2.new(1, -(ICON + 6), 0, TITLE_H)
		for _, row in self._rows do
			row.frame.Visible = false
		end
		-- (a finger tall on touch: the card is the nudge's button)
		self.frame.Size =
			UDim2.fromOffset(WIDTH, Scale.tapHeight(TITLE_H + 2 + CAPTION_H + PAD * 2))
		self._badge.Visible = false
		self._ready = false
		self._goalLine.Visible = false
		self:_alert(nil)
		return
	end
	self._title.Position = UDim2.fromOffset(0, GOAL_H)
	self._title.Size = UDim2.new(1, -BADGE_ROOM, 0, TITLE_H)
	local nextTier = if progress then progress.nextTier else nil
	self._tier.Visible = nextTier == nil -- the top tier: its line alone
	self._title.Visible = nextTier ~= nil
	self._goalLine.Visible = nextTier ~= nil
	local count = 0
	for index, row in self._rows do
		local item = if progress and nextTier then progress.requirements[index] else nil
		row.frame.Visible = item ~= nil
		if item then
			count = index
			-- #2447 (Derek2 11-08: "change different cats to just Cats on mobile for main goal because it gets cut
			-- off"): the phone's card is too narrow for "Different cats" beside its count
			-- #2999 (Derek2 11-10): the rarity row reads "Mythical+ cat" or "2 Mythical+ cats" there too
			row.label.Text = if Scale.isTouch()
				then item.touch or TOUCH_SHORT[item.short] or item.short
				else item.short
			row.status.Text = if item.met then "✓" else item.status
			row.status.TextColor3 = if item.met then Theme.colors.gold else Theme.hud.text
			row.fill.Size = UDim2.fromScale(math.clamp(item.fraction, 0, 1), 1)
			row.fill.BackgroundColor3 = if item.met then Theme.colors.gold else Theme.colors.mint
		end
	end
	if nextTier then
		-- ready: "[Rank up!] Cozy Cafe" in gold, short enough to keep clear of the sticker
		self._title.Text = nextTier.name
		self._title.TextColor3 = Theme.hud.text
	end
	local height = if nextTier then TOP + count * (ROW + ROW_GAP) - ROW_GAP else TIER_H
	self.frame.Size = UDim2.fromOffset(WIDTH, height + PAD * 2)

	self._badge.Visible = ready
	if ready and not self._ready then
		Tween.popIn(self._badge, 0.7)
	end
	self._ready = ready
	-- #2331: the pulse and the arrow, once for each tier's ready state
	local key = if ready and nextTier then tostring(nextTier.name) else nil
	if key == nil then
		self._seenKey = nil
	end
	self:_alert(if key ~= nil and key ~= self._seenKey then key else nil)
end

-- #2331: the ready pulse and arrow on (key, the tier the rank up is for) or off (nil)
function GoalCard._alert(self: any, key: string?)
	local on = key ~= nil
	self._alertKey = key
	if on == self._alerting then
		return
	end
	self._alerting = on
	local pulse = self._pulse
	if pulse then
		pulse:Cancel()
		self._pulse = nil
	end
	local edge: UIStroke = self._edge
	edge.Thickness = EDGE
	edge.Color = Theme.colors.gold
	if on then
		if GuiService.ReducedMotionEnabled then
			edge.Thickness = EDGE_READY
		else
			local tween = TweenService:Create(
				edge,
				PULSE,
				{ Thickness = EDGE_READY, Color = Theme.colors.white }
			)
			tween:Play()
			self._pulse = tween
		end
		TutorialArrow.add(self.frame, true)
	else
		TutorialArrow.remove(self.frame)
	end
end

function GoalCard.seen(self: any)
	if self._alerting then
		self._seenKey = self._alertKey
		self:_alert(nil)
	end
end

function GoalCard.alerting(self: any): boolean
	return self._alerting == true
end

function GoalCard.nudging(self: any): boolean
	return self._nudging == true
end

function GoalCard.destroy(self: any)
	self:_alert(nil)
	self._connection:Disconnect()
	self._foldButton:destroy()
	self.frame:Destroy()
end

return GoalCard
