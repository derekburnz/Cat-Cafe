--!strict
-- The HUD's potion timers (F64, data-model section 12b; quests.md section 7: "their timers show in the HUD buff
-- chips"): under the money and golden fish pills, one small chip per running potion, a round tile in the potion's
-- colour and its time left in outlined white ("8:12"), no dark panel behind them. A tap on any chip opens the
-- potion bag. Each tile shows the potion's own bottle icon (Components/ShopIcons). The row hides with no potion running; while one runs it ticks once a second, and a chip goes when
-- its time is up. Times come from ProfileSync `buffs` (endsAt in server time), so a rejoin shows what is left.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type BuffChips = {
	frame: Frame,
	setCatalog: (self: BuffChips, catalog: Types.Catalog) -> (),
	render: (self: BuffChips, state: Types.PlayerState) -> (),
	setTop: (self: BuffChips, y: number) -> (),
	destroy: (self: BuffChips) -> (),
}

local HEIGHT = 30
local TILE = 28

type Chip = { frame: Frame, time: TextLabel }

local BuffChips = {}
BuffChips.__index = BuffChips

function BuffChips.new(parent: Instance, x: number, onOpen: () -> ()): BuffChips
	local self = setmetatable({}, BuffChips) :: any
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._chips = {} :: { [string]: Chip }
	self._loop = nil :: RBXScriptConnection?
	self._clock = 0
	self._onOpen = onOpen

	self.frame = Create("Frame", {
		Name = "Potions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	return self :: BuffChips
end

function BuffChips.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_draw()
end

function BuffChips.setTop(self: any, y: number)
	self.frame.Position = UDim2.fromOffset(self.frame.Position.X.Offset, y)
end

function BuffChips.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_draw()
end

function BuffChips._chip(self: any, potionId: string, order: number): Chip
	local frame: Frame = Create("Frame", {
		Name = potionId,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Parent = self.frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tile: TextLabel = Create("TextLabel", {
		Name = "Tile",
		BackgroundColor3 = Theme.potionColor(potionId),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TILE, TILE),
		FontFace = Theme.fonts.body,
		TextSize = 16,
		Text = Theme.icons.potion,
		LayoutOrder = 1,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(tile, 2)
	IconArt.setImage(tile, ShopIcons.potion(potionId), 0.92) -- the bottle; the glyph until it loads
	local time: TextLabel = Create("TextLabel", {
		Name = "Time",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.colors.white,
		Text = "",
		LayoutOrder = 2,
		Parent = frame,
	})
	Outline.text(time, 2)
	-- the whole chip is the tap target for the bag
	local hit: TextButton = Create("TextButton", {
		Name = "Open",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 3,
		Parent = frame,
	})
	hit.Activated:Connect(function()
		self._onOpen()
	end)
	return { frame = frame, time = time }
end

function BuffChips._draw(self: any)
	local state: Types.PlayerState? = self._state
	local running: { PotionLogic.Row } = if state
		then PotionLogic.running(self._catalog, state, Workspace:GetServerTimeNow())
		else {}
	local shown: { [string]: boolean } = {}
	for order, row in running do
		local id = row.potion.id
		shown[id] = true
		local chip: Chip = self._chips[id] or self:_chip(id, order)
		self._chips[id] = chip
		chip.frame.LayoutOrder = order
		chip.time.Text = PotionLogic.clock(row.secondsLeft)
	end
	for id, chip in self._chips do
		if not shown[id] then
			chip.frame:Destroy()
			self._chips[id] = nil
		end
	end
	self.frame.Visible = #running > 0
	-- tick once a second while anything runs; stop when the last one ends
	local loop: RBXScriptConnection? = self._loop
	if #running > 0 and loop == nil then
		self._loop = RunService.Heartbeat:Connect(function(dt: number)
			self._clock += dt
			if self._clock >= 1 then
				self._clock = 0
				self:_draw()
			end
		end)
	elseif #running == 0 and loop then
		loop:Disconnect()
		self._loop = nil
	end
end

function BuffChips.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	self.frame:Destroy()
end

return BuffChips
