--!strict
-- The Grand Opening strip under the goal card (#1893, first-hour.md 1b): the goal card's dark rounded look and width,
-- "Grand Opening 3/8" over eight dots (done ones gold). A tap opens it in place into the eight steps (done ones ticked
-- with their reward, the next one highlighted, later ones plain; 28 px rows, so the list fits a phone with no
-- scrolling) and a second tap closes it. No timers, no locks. The open or closed state is the `roadmapOpen` setting,
-- so `onToggle` saves it. Open, the list draws over the quest line under it (and, on a short screen, the HUD lifts the
-- strip over the goal card so all eight steps show). Components/RoadmapLogic says what shows.
--   Roadmap.new(parent, position, onToggle)    the strip (hidden until render gets a view)
--   roadmap:render(view, open)                 draw it, or hide it with a nil view
--   roadmap:pop(n)                             step n's dot pops gold as its toast slides in

local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local Outline = require(script.Parent.Parent.Components.Outline)
local RoadmapLogic = require(script.Parent.Parent.Components.RoadmapLogic)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type Roadmap = {
	frame: TextButton,
	render: (self: Roadmap, view: RoadmapLogic.View?, open: boolean) -> (),
	pop: (self: Roadmap, n: number) -> (),
	closedHeight: (self: Roadmap) -> number,
	destroy: (self: Roadmap) -> (),
}

local WIDTH = 250 -- the goal card's
local PAD = 10
local TITLE_H = 20
local DOT = 12
local DOT_GAP = 6
local DOTS_H = DOT + 6
local ROW_H = 28
local CARD_TRANSPARENCY = 0.12
local NEXT_COLOR = Color3.fromHex("FFE7A3") -- the next step's row, a soft gold

local Roadmap = {}
Roadmap.__index = Roadmap

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local made: TextLabel = Create("TextLabel", merged)
	Outline.text(made, 2)
	return made
end

function Roadmap.new(parent: Instance, position: UDim2, onToggle: (open: boolean) -> ()): Roadmap
	local self = setmetatable({}, Roadmap) :: any
	self._open = false
	local frame: TextButton = Create("TextButton", {
		Name = "GrandOpening",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.outline,
		BackgroundTransparency = CARD_TRANSPARENCY,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(WIDTH, TITLE_H + DOTS_H + PAD * 2),
		Visible = false,
		ZIndex = 7, -- open, it draws over the goal card (3), the quest line and the Potions symbol (6); the day card (20) stays on top
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
	Outline.border(frame, 2)
	self.frame = frame
	self._title = label({
		Name = "Title",
		Size = UDim2.new(1, -20, 0, TITLE_H),
		TextSize = Theme.sizes.textBody,
		Parent = frame,
	})
	self._arrow = label({
		Name = "Arrow",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(18, TITLE_H),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.hud.subtext,
		Text = "▾",
		Parent = frame,
	})
	local dots: Frame = Create("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TITLE_H + 4),
		Size = UDim2.new(1, 0, 0, DOT),
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, DOT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._dots = {} :: { Frame }
	for n = 1, #RoadmapLogic.STEPS do
		table.insert(
			self._dots,
			Create("Frame", {
				Name = "Dot" .. n,
				BackgroundColor3 = Theme.colors.cocoa,
				BorderSizePixel = 0,
				LayoutOrder = n,
				Size = UDim2.fromOffset(DOT, DOT),
				Parent = dots,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = Theme.hud.stroke, Thickness = 1.5 }),
			})
		)
	end
	local list: Frame = Create("Frame", {
		Name = "Steps",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TITLE_H + DOTS_H),
		Size = UDim2.new(1, 0, 0, ROW_H * #RoadmapLogic.STEPS),
		Visible = false,
		Parent = frame,
	})
	self._list = list
	self._rows = {} :: { { frame: Frame, text: TextLabel, reward: TextLabel } }
	for n = 1, #RoadmapLogic.STEPS do
		local row: Frame = Create("Frame", {
			Name = "Step" .. n,
			BackgroundColor3 = NEXT_COLOR,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-4, (n - 1) * ROW_H),
			Size = UDim2.new(1, 8, 0, ROW_H),
			Parent = list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		})
		local words = label({
			Name = "Text",
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 1),
			Parent = row,
		})
		FitText.shrink(words) -- #2207: "Grand Opening! Rank up to Tier 3" shrinks a little on a phone, never cut
		local reward = label({
			Name = "Reward",
			Size = UDim2.new(1, 0, 0, 11),
			Position = UDim2.fromOffset(0, 16),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.hud.subtext,
			Parent = row,
		})
		table.insert(self._rows, { frame = row, text = words, reward = reward })
	end
	frame.Activated:Connect(function()
		self._open = not self._open
		self:_layout()
		onToggle(self._open)
	end)
	return self :: Roadmap
end

function Roadmap._layout(self: any)
	local open = self._open == true
	self._list.Visible = open
	self._arrow.Text = if open then "▴" else "▾"
	local height = TITLE_H + DOTS_H + PAD * 2 + (if open then ROW_H * #RoadmapLogic.STEPS else 0)
	self.frame.Size = UDim2.fromOffset(WIDTH, height)
end

function Roadmap.render(self: any, view: RoadmapLogic.View?, open: boolean)
	if view == nil then
		self.frame.Visible = false
		return
	end
	self._open = open
	self._title.Text = view.title
	for index, row in view.rows do
		local dot: Frame? = self._dots[index]
		if dot then
			dot.BackgroundColor3 = if row.done then Theme.colors.gold else Theme.colors.cocoa
		end
		local drawn = self._rows[index]
		if drawn then
			drawn.text.Text = (if row.done then "✓ " else "") .. row.text
			drawn.text.TextColor3 = if row.done then Theme.hud.subtext else Theme.hud.text
			drawn.reward.Text = row.reward
			drawn.frame.BackgroundTransparency = if row.next then 0.75 else 1
		end
	end
	self:_layout()
	self.frame.Visible = true
end

-- The strip's height closed: what the quest line under it moves down by (the open list draws over what is below)
function Roadmap.closedHeight(_self: any): number
	return TITLE_H + DOTS_H + PAD * 2
end

function Roadmap.pop(self: any, n: number)
	local dot: Frame? = self._dots[n]
	if dot then
		dot.BackgroundColor3 = Theme.colors.gold
		Tween.popIn(dot, 0.3)
	end
end

function Roadmap.destroy(self: any)
	self.frame:Destroy()
end

return Roadmap
