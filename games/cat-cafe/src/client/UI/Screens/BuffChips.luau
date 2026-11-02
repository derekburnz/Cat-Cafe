--!strict
-- The HUD's potion timers (F64, data-model section 12b; quests.md section 7: "their timers show in the HUD buff
-- chips"): over the money and golden fish counters in the bottom left (beside the menu's arrow tab on a phone), one small chip per running potion, a round tile in the potion's
-- colour and its time left in outlined white ("8:12"), no dark panel behind them. A tap on any chip opens the
-- potion bag. Each tile shows the potion's own bottle icon (Components/ShopIcons). The row hides with no potion running; while one runs it ticks once a second, and a chip goes when
-- its time is up. Times come from ProfileSync `buffs` (endsAt in server time), so a rejoin shows what is left.
-- F88: the HUD's Luck chip (Screens/LuckChip) leads the row; setLead keeps the row up while it shows. F92: the pal
-- chip (Screens/PalChip) closes the row and keeps it up the same way, under its own key.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type BuffChips = {
	frame: Frame,
	setCatalog: (self: BuffChips, catalog: Types.Catalog) -> (),
	render: (self: BuffChips, state: Types.PlayerState) -> (),
	place: (self: BuffChips, position: UDim2, anchor: Vector2) -> (),
	setLead: (self: BuffChips, shown: boolean, key: string?) -> (), -- key "luck" (the default) or "pals"
	destroy: (self: BuffChips) -> (),
}

local HEIGHT = 30 -- the time label
local TILE = 28
local TAP_H = 36 -- each chip takes taps this tall round its 28 px tile (more on a phone, Scale.tapHeight)

type Chip = { frame: TextButton, time: TextLabel }

local BuffChips = {}
BuffChips.__index = BuffChips

-- How tall the row is: a chip's tap height, so the HUD keeps that much free over the counters.
function BuffChips.rowHeight(): number
	return Scale.tapHeight(TAP_H)
end

function BuffChips.new(parent: Instance, x: number, onOpen: () -> ()): BuffChips
	local self = setmetatable({}, BuffChips) :: any
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._chips = {} :: { [string]: Chip }
	self._loop = nil :: RBXScriptConnection?
	self._clock = 0
	self._onOpen = onOpen
	self._leads = {} :: { [string]: boolean } -- F88: the Luck chip at the row's start; F92: the pal chip at its end
	self._running = 0

	self.frame = Create("Frame", {
		Name = "Potions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(0, BuffChips.rowHeight()),
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

-- Where the row sits (the HUD's _layoutMenu: over the counters in the bottom left, or beside the menu's arrow tab).
function BuffChips.place(self: any, position: UDim2, anchor: Vector2)
	self.frame.AnchorPoint = anchor
	self.frame.Position = position
end

-- F88: whether the Luck chip (the row's first child, LayoutOrder 0) shows, so the row stays up for it alone. F92: the
-- pal chip (LayoutOrder 100) says the same under the key "pals".
function BuffChips.setLead(self: any, shown: boolean, key: string?)
	self._leads[key or "luck"] = if shown then true else nil
	self.frame.Visible = next(self._leads) ~= nil or self._running > 0
end

function BuffChips.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_draw()
end

function BuffChips._chip(self: any, potionId: string, order: number): Chip
	-- the whole chip is the tap target for the bag, taller than it looks so a finger finds it
	local frame: TextButton = Create("TextButton", {
		Name = potionId,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, BuffChips.rowHeight()),
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
	frame.Activated:Connect(function()
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
	self._running = #running
	self.frame.Visible = #running > 0 or next(self._leads) ~= nil
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
