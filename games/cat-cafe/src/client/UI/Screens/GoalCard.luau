--!strict
-- Next goal card (F39 P1, copied from the Pet Simulator 99 quest card): one card on the right of the HUD with
-- the next tier's name and a bar per rank up requirement, the same numbers as the rank up card. It turns gold
-- when every requirement is met, and a tap opens the rank up card. Hidden at the top tier.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type GoalCard = {
	frame: TextButton,
	render: (self: GoalCard, progress: RankUp.Progress?) -> (),
	destroy: (self: GoalCard) -> (),
}

local WIDTH = 240
local TOP = 52 -- caption and title
local ROW = 26
local ROW_GAP = 6
local ROWS = 3

type Row = { frame: Frame, fill: Frame, label: TextLabel, status: TextLabel }

local GoalCard = {}
GoalCard.__index = GoalCard

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local label: TextLabel = Create("TextLabel", merged)
	Outline.text(label)
	return label
end

function GoalCard.new(parent: Instance, position: UDim2, onOpen: () -> ()): GoalCard
	local self = setmetatable({}, GoalCard) :: any

	-- the whole card is the button, like a quest card
	local frame: TextButton = Create("TextButton", {
		Name = "NextGoal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(WIDTH, TOP + ROWS * (ROW + ROW_GAP)),
		Visible = false,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self.frame = frame
	self._border = Outline.border(frame, Theme.sizes.outline, Theme.hud.stroke)

	self._caption = text({
		Name = "Caption",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NEXT GOAL",
		Parent = frame,
	})
	self._title = text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(1, -24, 0, 24),
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local rows: { Row } = {}
	for index = 1, ROWS do
		local row: Frame = Create("Frame", {
			Name = "Row" .. index,
			BackgroundColor3 = Theme.colors.ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, TOP + (index - 1) * (ROW + ROW_GAP)),
			Size = UDim2.new(1, -20, 0, ROW),
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		Outline.border(row, 2)
		local fill: Frame = Create("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.colors.mint,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Parent = row,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		Outline.shade(fill, 0.22)
		rows[index] = {
			frame = row,
			fill = fill,
			label = text({
				Name = "Label",
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(0.66, -8, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
				Parent = row,
			}),
			status = text({
				Name = "Status",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.new(0.34, -8, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 2,
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

function GoalCard.render(self: any, progress: RankUp.Progress?)
	local nextTier = if progress then progress.nextTier else nil
	if not progress or not nextTier then
		self.frame.Visible = false
		return
	end
	assert(progress and nextTier, "progress and next tier set")
	self.frame.Visible = true
	self._title.Text = ("%s  ·  Tier %d"):format(nextTier.name, nextTier.tier)

	local count = 0
	for index, row in self._rows do
		local item = progress.requirements[index]
		row.frame.Visible = item ~= nil
		if item then
			count = index
			row.label.Text = item.label
			row.status.Text = if item.met then "✓" else item.status
			row.fill.Size = UDim2.fromScale(math.clamp(item.fraction, 0, 1), 1)
			row.fill.BackgroundColor3 = if item.met then Theme.colors.gold else Theme.colors.mint
		end
	end
	self.frame.Size = UDim2.fromOffset(WIDTH, TOP + count * (ROW + ROW_GAP) + 4)

	local ready = progress.ready
	self._caption.Text = if ready then "READY! TAP TO RANK UP" else "NEXT GOAL"
	self._border.Color = if ready then Theme.colors.gold else Theme.hud.stroke
	if ready and not self._ready then
		Tween.popIn(self.frame, 0.9)
	end
	self._ready = ready
end

function GoalCard.destroy(self: any)
	self._connection:Disconnect()
	self.frame:Destroy()
end

return GoalCard
