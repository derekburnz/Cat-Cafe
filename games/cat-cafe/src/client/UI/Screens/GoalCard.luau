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

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type GoalCard = {
	frame: TextButton,
	render: (self: GoalCard, progress: RankUp.Progress?, tierText: string) -> (),
	destroy: (self: GoalCard) -> (),
}

local WIDTH = 240
local TIER_H = 18
local TITLE_H = 26
local TOP = TIER_H + TITLE_H + 4 -- the first requirement's caption
local CAPTION_H = 18
local BAR_H = 8
local ROW = CAPTION_H + 2 + BAR_H
local ROW_GAP = 6
local ROWS = 3
local SMALL_OUTLINE = 2 -- small text over the bright world needs a little more outline than in a window

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

function GoalCard.new(parent: Instance, position: UDim2, onOpen: () -> ()): GoalCard
	local self = setmetatable({}, GoalCard) :: any

	-- the whole block is the button
	local frame: TextButton = Create("TextButton", {
		Name = "TierGoal",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(WIDTH, TIER_H),
		Visible = false,
		Parent = parent,
	})
	self.frame = frame

	self._tier = text({
		Name = "Tier",
		Size = UDim2.new(1, 0, 0, TIER_H),
		TextColor3 = Theme.hud.subtext,
		Parent = frame,
	})
	self._title = text({
		Name = "Title",
		Position = UDim2.fromOffset(0, TIER_H),
		Size = UDim2.new(1, 0, 0, TITLE_H),
		TextSize = Theme.sizes.textBody + 4,
		Parent = frame,
	})
	-- the simulator "something to claim" sticker, tilted at the left of the title while a rank up is ready
	self._badge = Create("TextLabel", {
		Name = "RankReady",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, TIER_H + TITLE_H / 2),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Rotation = -6,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "Rank up!",
		Visible = false,
		ZIndex = 3,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.text(self._badge)
	Outline.border(self._badge, 2)

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
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			}),
			status = text({
				Name = "Status",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.45, 0, 0, CAPTION_H),
				Parent = row,
			}),
		}
	end
	self._rows = rows
	self._ready = false

	self._connection = frame.Activated:Connect(function()
		onOpen()
	end)
	return self :: GoalCard
end

-- progress nil (no tiers in the catalog yet) shows tierText alone.
function GoalCard.render(self: any, progress: RankUp.Progress?, tierText: string)
	self.frame.Visible = true
	self._tier.Text = tierText
	local nextTier = if progress then progress.nextTier else nil
	local ready = progress ~= nil and progress.ready
	self._title.Visible = nextTier ~= nil
	local count = 0
	for index, row in self._rows do
		local item = if progress and nextTier then progress.requirements[index] else nil
		row.frame.Visible = item ~= nil
		if item then
			count = index
			row.label.Text = item.short
			row.status.Text = if item.met then "✓" else item.status
			row.status.TextColor3 = if item.met then Theme.colors.gold else Theme.hud.text
			row.fill.Size = UDim2.fromScale(math.clamp(item.fraction, 0, 1), 1)
			row.fill.BackgroundColor3 = if item.met then Theme.colors.gold else Theme.colors.mint
		end
	end
	if nextTier then
		-- ready: "[Rank up!] Cozy Cafe" in gold, short enough to keep clear of the sticker
		self._title.Text = if ready then nextTier.name else "Next: " .. nextTier.name
		self._title.TextColor3 = if ready then Theme.colors.gold else Theme.hud.text
	end
	local height = if nextTier then TOP + count * (ROW + ROW_GAP) - ROW_GAP else TIER_H
	self.frame.Size = UDim2.fromOffset(WIDTH, height)

	self._badge.Visible = ready
	if ready and not self._ready then
		Tween.popIn(self._badge, 0.7)
	end
	self._ready = ready
end

function GoalCard.destroy(self: any)
	self._connection:Disconnect()
	self.frame:Destroy()
end

return GoalCard
