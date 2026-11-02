--!strict
-- One leaderboard row (F98, leaderboards.md section 2): the rank, the player's head picture, their display name (a
-- 👑 before it while they are in an all time top 10) and the value on the right. Ranks 1 to 3 sit on gold, silver and
-- bronze; the player's own row has a sky edge. The town boards and the Index's Top tab both draw these.

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
	self._rank = label({
		Name = "Rank",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0, RANK_W, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = look.textSize,
		TextColor3 = look.text,
		Parent = frame,
	})
	self._head = Create("ImageLabel", {
		Name = "Head",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4 + RANK_W + 4, pad),
		Size = UDim2.fromOffset(head, head),
		Image = "",
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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
		TextSize = look.textSize,
		TextColor3 = look.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	if look.outlined then
		for _, text in { self._rank, self._name, self._value } do
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
	local medal = LeaderboardLogic.medal(row.rank)
	if medal ~= nil then
		self.frame.BackgroundColor3 = Theme.medals[medal]
		self.frame.BackgroundTransparency = 0.15
	else
		self.frame.BackgroundColor3 = look.plain
		self.frame.BackgroundTransparency = look.plainTransparency
	end
	-- on a medal the words go dark so they read on the bright fill
	local ink = if medal ~= nil and not look.outlined then Theme.colors.ink else look.text
	self._rank.Text = "#" .. tostring(row.rank)
	self._rank.TextColor3 = ink
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
