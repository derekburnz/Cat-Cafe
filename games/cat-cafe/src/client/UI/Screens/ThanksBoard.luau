--!strict
-- The Thank You board's face (#1083, idea-credits.md section 3): on the board in the Town Square, under a cat-paw
-- header "Thank you for the ideas!", one card per credited idea, newest first: the idea in our words in bold, and
-- under it "v190 · Idea from MochiPie" (or "Idea from a player" when the name is hidden or the lookup failed). The
-- server builds the rows (IdeaCreditsService, display names only) and sends them with ThanksBoard(rows, hasCredit);
-- this draws them. Six cards to a page so the words stay readable from a few steps away; "Older ideas" and "Newer"
-- page through the rest. With no credits yet, one line says how a name gets here.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It sits in PlayerGui with its Adornee set to the
-- board's part named Screen (a SurfaceGui must be in PlayerGui to take clicks); when the board streams out and back
-- in, its tag fires again and the page is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local ThanksBoardLogic = require(script.Parent.Parent.Components.ThanksBoardLogic)
local Theme = require(script.Parent.Parent.Theme)

export type ThanksBoard = {
	setRows: (self: ThanksBoard, rows: { ThanksBoardLogic.Row }) -> (),
	destroy: (self: ThanksBoard) -> (),
}

local TAG = "ThanksBoard"
local PIXELS_PER_STUD = 64 -- the 7.6 x 5.2 stud Screen is 486 x 333
local MAX_DISTANCE = 80
local MARGIN = 8
local HEADER = 46
local FOOTER = 34
local COCOA = Color3.fromRGB(92, 58, 38)
local BERRY = Color3.fromRGB(196, 74, 104)

local ThanksBoard = {}
ThanksBoard.__index = ThanksBoard

-- The newest rows and the board drawing them: init keeps neither (it is at Luau's 200 locals), so ThanksBoard(rows)
-- can arrive before or after the board is built.
local latest: { ThanksBoardLogic.Row } = {}
local current: any = nil

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextColor3 = COCOA,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	return if screen and screen:IsA("BasePart") then screen :: BasePart else nil
end

function ThanksBoard.new(parent: Instance): ThanksBoard
	local self = setmetatable({}, ThanksBoard) :: any
	self._rows = {} :: { ThanksBoardLogic.Row }
	self._page = 1
	self._connections = {} :: { RBXScriptConnection }

	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "CatCafeThanksBoard",
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = true,
		Enabled = false,
		Parent = parent,
	})
	self._gui = gui
	local page: Frame = Create("Frame", {
		Name = "Page",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local header = text({
		Name = "Header",
		Position = UDim2.fromOffset(MARGIN, 4),
		Size = UDim2.new(1, -MARGIN * 2, 0, HEADER),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🐾 Thank you for the ideas!",
		Parent = page,
	})
	Outline.text(header, 2.5)
	self._list = Create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, HEADER + 6),
		Size = UDim2.new(1, -MARGIN * 2, 1, -(HEADER + 6 + FOOTER)),
		Parent = page,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 1 / 3, -5),
			CellPadding = UDim2.fromOffset(8, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(MARGIN * 2, HEADER + 20),
		Size = UDim2.new(1, -MARGIN * 4, 0, 120),
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = ThanksBoardLogic.EMPTY,
		Visible = false,
		Parent = page,
	})
	local function pager(
		name: string,
		label: string,
		x: number,
		anchor: number,
		step: number
	): TextButton
		local button: TextButton = Create("TextButton", {
			Name = name,
			AutoButtonColor = true,
			BackgroundColor3 = BERRY,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(anchor, 1),
			Position = UDim2.new(x, if anchor == 0 then MARGIN else -MARGIN, 1, -4),
			Size = UDim2.fromOffset(150, FOOTER - 6),
			FontFace = Theme.fonts.display,
			TextSize = 18,
			TextColor3 = Theme.colors.white,
			Text = label,
			Visible = false,
			Parent = page,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		table.insert(
			self._connections,
			button.Activated:Connect(function()
				self._page += step
				self:_paint()
			end)
		)
		return button
	end
	self._newer = pager("Newer", "‹ Newer", 0, 0, -1)
	self._older = pager("Older", "Older ideas ›", 1, 1, 1)
	self._pageLabel = text({
		Name = "PageNumber",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(120, FOOTER - 8),
		TextSize = 16,
		TextColor3 = COCOA,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = page,
	})
	self._cards = {} :: { Frame }

	-- the header sits on a berry band
	Create("Frame", {
		Name = "Band",
		BackgroundColor3 = BERRY,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER + 8),
		ZIndex = 0,
		Parent = page,
	})

	current = self
	self._rows = latest
	self:_paint()
	for _, model in CollectionService:GetTagged(TAG) do
		self:_hang(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
			self:_hang(model)
		end)
	)
	return self :: ThanksBoard
end

-- Hangs the page on a placed board's Screen (the tagged template in ReplicatedStorage.Assets gets none).
function ThanksBoard._hang(self: any, model: Instance)
	if not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part may stream in after the model
		local waiting: RBXScriptConnection
		waiting = model.DescendantAdded:Connect(function(child: Instance)
			if child.Name == "Screen" and child:IsA("BasePart") then
				waiting:Disconnect()
				self:_hang(model)
			end
		end)
		table.insert(self._connections, waiting)
		return
	end
	self._gui.Adornee = screen
	self._gui.Face = Enum.NormalId.Front
	self._gui.Enabled = true
end

-- ThanksBoard(rows, hasCredit) from the server: kept, and drawn on the board once there is one.
function ThanksBoard.show(rows: { ThanksBoardLogic.Row })
	latest = rows
	if current then
		current:setRows(rows)
	end
end

function ThanksBoard.setRows(self: any, rows: { ThanksBoardLogic.Row })
	self._rows = rows
	self:_paint()
end

function ThanksBoard._card(self: any, index: number): Frame
	local card: Frame? = self._cards[index]
	if card then
		return card
	end
	local made: Frame = Create("Frame", {
		Name = "Card" .. index,
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = Color3.fromRGB(226, 205, 178), Thickness = 2 }),
	})
	text({
		Name = "Idea",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0.55, -6),
		FontFace = Theme.fonts.display,
		TextSize = 21,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = made,
	})
	text({
		Name = "Credit",
		Position = UDim2.new(0, 10, 0.55, 2),
		Size = UDim2.new(1, -20, 0.45, -8),
		TextSize = 16,
		TextColor3 = BERRY,
		Parent = made,
	})
	self._cards[index] = made
	return made
end

function ThanksBoard._paint(self: any)
	local view = ThanksBoardLogic.page(self._rows, self._page)
	self._page = view.page
	for index, row in view.rows do
		local card = self:_card(index)
		card.Visible = true
		(card:FindFirstChild("Idea") :: TextLabel).Text = row.idea;
		(card:FindFirstChild("Credit") :: TextLabel).Text = ThanksBoardLogic.creditLine(row)
	end
	for index = #view.rows + 1, #self._cards do
		self._cards[index].Visible = false
	end
	self._empty.Visible = #self._rows == 0
	self._newer.Visible = view.page > 1
	self._older.Visible = view.page < view.pages
	self._pageLabel.Text = if view.pages > 1 then ("%d / %d"):format(view.page, view.pages) else ""
end

function ThanksBoard.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._gui:Destroy()
	if current == self then
		current = nil
	end
end

return ThanksBoard
