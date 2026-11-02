--!strict
-- The Fresh Catch chalkboard on the Golden Fish Market's stall (F94, rewards-and-shops.md section 3; board model
-- Model-Agent #681). The stall model, tagged FishMarket, holds a Model CatCafe_Street_FishMarket_FreshCatch with one
-- Part of the same name whose Front face is the blank chalk, 1.7 by 1.45 studs; the model already draws FRESH CATCH
-- above it. This writes on the chalk from this client only: by day what the window stocks ("Money Potion  x2"), in
-- shelf order, and "Fresh catch in 3:12" at the foot; at night "Back at sunrise". The stock comes
-- from FreshCatchStock through UI.freshCatch.setStock, the same as the Market's Fresh Catch tab.
--   set(stock?, nameOf)   the window's stock (nil at night) and how to name a row

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local FreshCatchLogic = require(script.Parent.Parent.Components.FreshCatchLogic)
local Theme = require(script.Parent.Parent.Theme)

local TAG = "FishMarket"
local BOARD = "CatCafe_Street_FishMarket_FreshCatch"
local PIXELS_PER_STUD = 100 -- the 1.7 by 1.45 stud chalk is a 170 by 145 canvas
local FOOT = 24 -- the countdown line at the bottom
local PAD = 6
local LOOK_EVERY = 2 -- seconds between looks for the board while it is not found (it may stream in)
local CHALK = Color3.fromHex("F4F1E8")
local CHALK_DIM = Color3.fromHex("CFC8B8")

export type FreshCatchBoard = {
	set: (
		self: FreshCatchBoard,
		stock: FreshCatchLogic.Stock?,
		nameOf: (itemId: string) -> string
	) -> (),
	destroy: (self: FreshCatchBoard) -> (),
}

local FreshCatchBoard = {}
FreshCatchBoard.__index = FreshCatchBoard

local function findBoard(): BasePart?
	for _, station in CollectionService:GetTagged(TAG) do
		local holder = station:FindFirstChild(BOARD, true)
		if holder then
			local part = if holder:IsA("BasePart") then holder else holder:FindFirstChild(BOARD)
			if part and part:IsA("BasePart") then
				return part :: BasePart
			end
		end
	end
	return nil
end

local function chalk(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = CHALK,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function FreshCatchBoard.new(parent: Instance): FreshCatchBoard
	local self = setmetatable({}, FreshCatchBoard) :: any
	self._stock = nil :: FreshCatchLogic.Stock?
	self._lines = {} :: { FreshCatchLogic.BoardLine }
	self._rows = {} :: { Frame }

	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "CatCafeFreshCatchBoard",
		ResetOnSpawn = false,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0.4, -- chalk in the world dims a little at night, but stays readable
		MaxDistance = 80,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	self._gui = gui
	local list: Frame = Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -2 * PAD, 1, -(2 * PAD + FOOT)),
		Parent = gui,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		}),
	})
	self._list = list
	self._foot = chalk({
		Name = "Foot",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -PAD + 2),
		Size = UDim2.new(1, -2 * PAD, 0, FOOT - 6),
		TextColor3 = CHALK_DIM,
		Parent = gui,
	})
	self._closed = chalk({
		Name = "Closed",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4 * PAD, 0.5, 0),
		Text = "Back at sunrise",
		Visible = false,
		Parent = gui,
	})
	gui.Parent = parent

	-- once a second the countdown; every LOOK_EVERY a look for the board while it is missing
	local clock, look = 1, LOOK_EVERY
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		look += dt
		local board: Instance? = gui.Adornee
		if (board == nil or board.Parent == nil) and look >= LOOK_EVERY then
			look = 0
			local found = findBoard()
			gui.Adornee = found :: any
			gui.Enabled = found ~= nil
		end
		clock += dt
		if clock >= 1 then
			clock = 0
			self:_drawFoot()
		end
	end)
	return self :: FreshCatchBoard
end

function FreshCatchBoard._drawFoot(self: any)
	local stock: FreshCatchLogic.Stock? = self._stock
	if stock == nil then
		self._foot.Text = ""
		return
	end
	local left = stock.restocksAt - Workspace:GetServerTimeNow() -- the server's clock, as restocksAt is (S102)
	local count = #self._lines
	self._foot.Text = if left <= 0
		then "Fresh catch coming..."
		elseif count == 0 then "Sold out! " .. FreshCatchLogic.countdown(left)
		else FreshCatchLogic.countdown(left)
end

function FreshCatchBoard.set(
	self: any,
	stock: FreshCatchLogic.Stock?,
	nameOf: (itemId: string) -> string
)
	self._stock = stock
	for _, row in self._rows do
		row:Destroy()
	end
	table.clear(self._rows)
	local lines = FreshCatchLogic.board(stock, nameOf)
	self._lines = lines
	self._closed.Visible = stock == nil
	self._list.Visible = stock ~= nil
	-- one line a stocked row, the rows sharing the chalk's height (eight at most)
	local share = 1 / math.max(5, #lines)
	for index, line in lines do
		local row: Frame = Create("Frame", {
			Name = line.itemId,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, share, -1),
			Parent = self._list,
		})
		chalk({
			Name = "Item",
			Size = UDim2.fromScale(0.78, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = line.name,
			Parent = row,
		})
		chalk({
			Name = "Amount",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.2, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.colors.gold,
			Text = "x" .. line.amount,
			Parent = row,
		})
		table.insert(self._rows, row)
	end
	self:_drawFoot()
end

function FreshCatchBoard.destroy(self: any)
	self._tick:Disconnect()
	self._gui:Destroy()
end

return FreshCatchBoard
