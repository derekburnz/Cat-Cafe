--!strict
-- One leaderboard row (F98, leaderboards.md section 2): the rank, the player's head picture, their display name (a
-- 👑 before it while they are in an all time top 10) and the value on the right. #972 (Derek's reference board,
-- 2026-11-03): the rank is a round badge, gold, silver and bronze for 1 to 3 and dark below, with a white outlined
-- number; the head picture is round with a dark outline; the value is bold and bigger. Every row has the same fill, so
-- the medal badges carry the top three. The player's own row has a sky edge.

local Create = require(script.Parent.Create)
local LeaderboardLogic = require(script.Parent.LeaderboardLogic)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Look = {
	height: number,
	textSize: number,
	text: Color3, -- the name and value on a plain row
	plain: Color3, -- a plain row's fill
	plainTransparency: number,
	outlined: boolean, -- white text with a dark outline (the chalkboard) rather than plain text
}

export type LeaderboardRow = {
	frame: Frame,
	paint: (self: LeaderboardRow, row: LeaderboardLogic.Row?, board: string, mine: boolean) -> (),
	destroy: (self: LeaderboardRow) -> (),
}

local RANK_W = 30
local VALUE_W = 104
local PLAIN_BADGE = Color3.fromHex("3F332E") -- a rank badge below the top three (Theme.dark.card)

local LeaderboardRow = {}
LeaderboardRow.__index = LeaderboardRow

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.bodyBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function LeaderboardRow.new(parent: Instance, look: Look, order: number?): LeaderboardRow
	local self = setmetatable({}, LeaderboardRow) :: any
	self._look = look
	local frame: Frame = Create("Frame", {
		Name = "Row",
		BackgroundColor3 = look.plain,
		BackgroundTransparency = look.plainTransparency,
		BorderSizePixel = 0,
		LayoutOrder = order or 0,
		Size = UDim2.new(1, 0, 0, look.height),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	self.frame = frame
	self._stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.colors.sky,
		Thickness = 2,
		Enabled = false,
		Parent = frame,
	})
	local pad = math.floor(look.height * 0.12)
	local head = look.height - pad * 2
	local badge = math.min(RANK_W, head)
	self._badge = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = PLAIN_BADGE,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 4 + RANK_W / 2, 0.5, 0),
		Size = UDim2.fromOffset(badge, badge),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(self._badge, 2)
	self._rank = label({
		Name = "Rank",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = math.max(10, look.textSize - 2),
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = self._badge,
	})
	Outline.text(self._rank, 1.5)
	self._head = Create("ImageLabel", {
		Name = "Head",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4 + RANK_W + 4, pad),
		Size = UDim2.fromOffset(head, head),
		Image = "",
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(self._head, 2)
	local nameX = 4 + RANK_W + 4 + head + 6
	self._name = label({
		Name = "PlayerName",
		Position = UDim2.fromOffset(nameX, 0),
		Size = UDim2.new(1, -(nameX + VALUE_W + 6), 1, 0),
		TextSize = look.textSize,
		TextColor3 = look.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	self._value = label({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		Size = UDim2.new(0, VALUE_W, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = look.textSize + 2,
		TextColor3 = look.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	if look.outlined then
		for _, text in { self._name, self._value } do
			Outline.text(text, 1.5)
		end
	end
	return self :: LeaderboardRow
end

function LeaderboardRow.paint(self: any, row: LeaderboardLogic.Row?, board: string, mine: boolean)
	local look: Look = self._look
	self.frame.Visible = row ~= nil
	if row == nil then
		return
	end
	-- the medal colours the rank badge only; the row keeps the plain fill (#972)
	local medal = LeaderboardLogic.medal(row.rank)
	self._badge.BackgroundColor3 = if medal ~= nil then Theme.medals[medal] else PLAIN_BADGE
	self.frame.BackgroundColor3 = look.plain
	self.frame.BackgroundTransparency = look.plainTransparency
	local ink = look.text
	self._rank.Text = tostring(row.rank)
	self._head.Image = LeaderboardLogic.headshot(row.userId)
	self._name.Text = (if row.crown == true then LeaderboardLogic.CROWN .. " " else "")
		.. (row.name or "")
	self._name.TextColor3 = ink
	self._value.Text = LeaderboardLogic.value(board, row.value)
	self._value.TextColor3 = ink
	self._stroke.Enabled = mine
end

function LeaderboardRow.destroy(self: any)
	self.frame:Destroy()
end

return LeaderboardRow
