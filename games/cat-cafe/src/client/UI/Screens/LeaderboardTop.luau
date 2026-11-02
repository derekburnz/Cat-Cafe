--!strict
-- The Index's Top tab (F98, leaderboards.md section 2): three board buttons along the top (Index, Playtime, Money),
-- the All time and This week switch on the right (Playtime and Money only), the top 50 as rows (rank, head picture,
-- display name with a 👑 for an all time top 10, value; ranks 1 to 3 on gold, silver and bronze) and this player's
-- own line pinned at the bottom ("You: #23", else "You: 41 h 12 m"). Drawn on the Index's dark page from the
-- server's LeaderboardSync (UI.leaderboards.sync); a view only, it sends nothing.

local Players = game:GetService("Players")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local LeaderboardLogic = require(script.Parent.Parent.Components.LeaderboardLogic)
local LeaderboardRow = require(script.Parent.Parent.Components.LeaderboardRow)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

export type LeaderboardTop = {
	frame: Frame,
	setSync: (self: LeaderboardTop, sync: LeaderboardLogic.Sync?) -> (),
	render: (self: LeaderboardTop) -> (),
	destroy: (self: LeaderboardTop) -> (),
}

local BOARD_W = 132
local BOARD_MIN = 96 -- the board buttons narrow to this on a small Index window, so the switch never covers Money
local WINDOW_W = 112
local BAR_H = 41 -- the Index tabs' height: a 36 px face on a mouse, taller on touch
local ROW_H = 36
local MAX_ROWS = 50 -- Config.LeaderboardSize

local ROW_LOOK: LeaderboardRow.Look = {
	height = ROW_H,
	textSize = Theme.sizes.textBody,
	text = Theme.index.text,
	plain = Theme.colors.white,
	plainTransparency = 0.92,
	outlined = false,
}

local LeaderboardTop = {}
LeaderboardTop.__index = LeaderboardTop

function LeaderboardTop.new(parent: Instance): LeaderboardTop
	local self = setmetatable({}, LeaderboardTop) :: any
	self._sync = nil :: LeaderboardLogic.Sync?
	self._board = "index" :: LeaderboardLogic.Board
	self._window = "allTime" :: LeaderboardLogic.Window
	local barH = Scale.tapHeight(BAR_H, Theme.sizes.buttonDepth)
	local frame: Frame = Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})
	self.frame = frame

	local boards: Frame = Create("Frame", {
		Name = "Boards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, barH),
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._boardButtons = {} :: { [string]: Button.Button }
	for order, board in LeaderboardLogic.BOARDS do
		local info = LeaderboardLogic.info(board)
		self._boardButtons[board] = Button.new({
			name = "Board_" .. board,
			text = info.name,
			icon = info.icon,
			style = "ghost",
			size = UDim2.fromOffset(BOARD_W, barH),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = boards,
			sound = "uiTab",
			onClick = function()
				self._board = board
				if not LeaderboardLogic.hasWeek(board) then
					self._window = "allTime"
				end
				self:render()
			end,
		})
	end
	-- All time | This week, right of the board buttons
	local switch: Frame = Create("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(WINDOW_W * 2 + Theme.sizes.gap, barH),
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._switch = switch
	self._barH = barH
	self._windowButtons = {} :: { [string]: Button.Button }
	for order, pair in { { "allTime", "All time" }, { "week", "This week" } } do
		local window = pair[1] :: LeaderboardLogic.Window
		self._windowButtons[window] = Button.new({
			name = "Window_" .. window,
			text = pair[2],
			style = "ghost",
			size = UDim2.fromOffset(WINDOW_W, barH),
			textSize = Theme.sizes.textSmall + 1,
			layoutOrder = order,
			parent = switch,
			sound = "uiTab",
			onClick = function()
				self._window = window
				self:render()
			end,
		})
	end

	local top = barH + Theme.sizes.gap
	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -(top + ROW_H + Theme.sizes.gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	self._list = list
	self._rows = {} :: { LeaderboardRow.LeaderboardRow }
	self._empty = Create("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top + 40),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.index.subtext,
		Text = "",
		Visible = false,
		Parent = frame,
	})
	-- this player's own line, pinned under the list
	self._me = Create("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -10, 0, ROW_H),
		BackgroundColor3 = Theme.colors.sky,
		BorderSizePixel = 0,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Visible = false,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	self._resize = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end)
	return self :: LeaderboardTop
end

-- Review N323: on an Index window too narrow for the three board buttons and the switch side by side, the board
-- buttons give up width (down to BOARD_MIN) rather than sit under the switch.
function LeaderboardTop._fit(self: any)
	local width = self.frame.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local gap = Theme.sizes.gap
	local switchW = if self._switch.Visible then WINDOW_W * 2 + gap * 2 else 0
	local each = math.clamp(math.floor((width - switchW - gap * 2) / 3), BOARD_MIN, BOARD_W)
	for _, button in self._boardButtons do
		button.instance.Size = UDim2.fromOffset(each, self._barH)
	end
end

function LeaderboardTop.setSync(self: any, sync: LeaderboardLogic.Sync?)
	self._sync = sync
	if self.frame.Visible then
		self:render()
	end
end

function LeaderboardTop.render(self: any)
	local board: LeaderboardLogic.Board = self._board
	local window: LeaderboardLogic.Window = self._window
	for id, button in self._boardButtons do
		button:setStyle(if id == board then "gold" else "ghost")
	end
	local weekly = LeaderboardLogic.hasWeek(board)
	self._switch.Visible = weekly
	self:_fit()
	for id, button in self._windowButtons do
		button:setStyle(if id == window then "primary" else "ghost")
	end
	local sync: LeaderboardLogic.Sync? = self._sync
	local rows = LeaderboardLogic.rows(sync, board, window, MAX_ROWS)
	local userId = Players.LocalPlayer.UserId
	-- rows are made as the lists grow and reused after
	for index = #self._rows + 1, #rows do
		table.insert(self._rows, LeaderboardRow.new(self._list, ROW_LOOK, index))
	end
	for index, view in self._rows do
		local row = rows[index]
		view:paint(row, board, row ~= nil and row.userId == userId)
	end
	self._empty.Visible = #rows == 0
	self._empty.Text = if sync == nil
		then "The boards are loading..."
		elseif window == "week" then "No one yet this week. Play to be first!"
		else "No one yet. Play to be first!"
	local line = if sync ~= nil then LeaderboardLogic.meLine(sync, board, window, userId) else nil
	self._me.Text = line or ""
	self._me.Visible = line ~= nil
end

function LeaderboardTop.destroy(self: any)
	self._resize:Disconnect()
	for _, row in self._rows do
		row:destroy()
	end
	for _, button in self._boardButtons do
		button:destroy()
	end
	for _, button in self._windowButtons do
		button:destroy()
	end
	self.frame:Destroy()
end

return LeaderboardTop
