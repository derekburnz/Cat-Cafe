--!strict
-- The HUD's potion timers (F64, data-model section 12b; quests.md section 7: "their timers show in the HUD buff
-- chips"). Since 2026-11-03 (#963, Derek: "can show active like this screenshot") they are their own row, `potions`,
-- which the HUD sets beside the Potions tile in the bottom right (HUD._placePotionTimers): one dark rounded chip per
-- running potion with the potion's own bottle (Components/ShopIcons) and its time left under it in outlined white
-- ("8:12"). A tap on any chip opens the potion bag. The row hides with no potion running; while one runs it ticks once
-- a second, and a chip goes when its time is up. Times come from ProfileSync `buffs` (endsAt in server time), so a
-- rejoin shows what is left.
-- `frame` is the row over the money and golden fish counters in the bottom left (beside the menu's arrow tab on a
-- phone) that holds the HUD's Luck chip (F88, Screens/LuckChip) and pal chip (F92, Screens/PalChip); setLead keeps it
-- up while either shows, under its own key.
-- #2090 (Derek2 11-07: "add an arrow to hide potion effects as if you drink a lot it's a lot of screen clutter"):
-- with potions running (two or more until #2396), an arrow tab sits at the row's left end. A tap folds the chips away into one
-- compact chip (the bottle and how many run, "x5"), and a tap on that brings them back. The choice holds until it is
-- tapped again (also across a rebuilt HUD); BuffChips.fold(count, folded) says what shows.

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
	frame: Frame, -- the Luck and pal chips' row
	potions: Frame, -- the running potions' chips
	setCatalog: (self: BuffChips, catalog: Types.Catalog) -> (),
	render: (self: BuffChips, state: Types.PlayerState) -> (),
	place: (self: BuffChips, position: UDim2, anchor: Vector2) -> (),
	setLead: (self: BuffChips, shown: boolean, key: string?) -> (), -- key "luck" (the default) or "pals"
	setFolded: (self: BuffChips, folded: boolean) -> (), -- #2090
	setHidden: (self: BuffChips, hidden: boolean) -> (), -- #2393: the Luck row steps away during a catch on touch
	destroy: (self: BuffChips) -> (),
}

local TAP_H = 36 -- the Luck and pal row's height (more on a phone, Scale.tapHeight)
-- a potion chip (2026-11-03 mockup): a dark rounded square, the bottle over the time; tall enough for a finger
local CHIP_W = 58
local CHIP_H = 62
local CHIP_BOTTLE = 36
local CHIP_TEXT = 16
local CHIP_GAP = 8

local TAB_W = 36 -- #2090: the arrow tab at the row's left end (full chip height; wider on touch, Scale.tapHeight)
local FOLDED_W = 58 -- the folded chip: the bottle over "x5"
-- #2396 (Derek2 11-08: "the potion menu shrink button is hard to see on mobile so make it just default to shrunk
-- down", then "make sure potion list defaults to closed down on every join"): the row starts folded on every join,
-- on every device (the choice is never saved), and the arrow shows with one potion too, so it always folds back
local FOLD_FROM = 1 -- running potions before the arrow shows
local FOLD_DEFAULT = true

type Chip = { frame: TextButton, time: TextLabel }

local BuffChips = {}
BuffChips.__index = BuffChips

-- the fold holds across a rebuilt HUD (a respawn rebuilds nothing, but a reset of the UI does)
local foldedNow = FOLD_DEFAULT

-- #2090: what the potion row shows for `count` running potions: the chips, the arrow tab (two or more, or folded
-- with any), and the folded chip in place of the chips.
function BuffChips.fold(
	count: number,
	folded: boolean
): { chips: boolean, tab: boolean, folded: boolean }
	if count <= 0 then
		return { chips = false, tab = false, folded = false }
	end
	if folded then
		return { chips = false, tab = false, folded = true }
	end
	return { chips = true, tab = count >= FOLD_FROM, folded = false }
end

-- How tall the Luck and pal row is, so the HUD keeps that much free over the counters.
function BuffChips.rowHeight(): number
	return Scale.tapHeight(TAP_H)
end

-- How tall the potion chips' row is (the HUD sets it beside the Potions tile).
function BuffChips.potionsHeight(): number
	return CHIP_H
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
	self._folded = foldedNow
	self._hidden = false

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
	self.potions = Create("Frame", {
		Name = "PotionTimers",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(0, CHIP_H),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, CHIP_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- #2090: the arrow tab (LayoutOrder 0, the row's left end) and the folded chip (in the chips' place)
	local tab: TextButton = Create("TextButton", {
		Name = "Fold",
		Text = "▶",
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.colors.white,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.outline,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(Scale.tapHeight(TAB_W), CHIP_H),
		LayoutOrder = 0,
		Visible = false,
		Parent = self.potions,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	Outline.border(tab, 3)
	tab.Activated:Connect(function()
		self:setFolded(true)
	end)
	self._tab = tab
	local folded: TextButton = Create("TextButton", {
		Name = "Folded",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.outline,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(FOLDED_W, CHIP_H),
		LayoutOrder = 1000,
		Visible = false,
		Parent = self.potions,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	Outline.border(folded, 3)
	Create("TextLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(14, 16),
		FontFace = Theme.fonts.display,
		TextSize = 12,
		TextColor3 = Theme.colors.white,
		Text = "◀",
		Parent = folded,
	})
	-- #2396 (Derek2: "the potion is using a old image when collapsed"): the first running potion's own bottle, as on its
	-- chip (_draw); the glyph only until the art loads
	self._foldedBottle = Create("TextLabel", {
		Name = "Bottle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(CHIP_BOTTLE, CHIP_BOTTLE),
		FontFace = Theme.fonts.body,
		TextSize = 24,
		Text = Theme.icons.potion,
		Parent = folded,
	}) :: TextLabel
	self._foldedId = nil :: string?
	local count: TextLabel = Create("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -4, 0, CHIP_TEXT + 4),
		FontFace = Theme.fonts.display,
		TextSize = CHIP_TEXT,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = folded,
	})
	Outline.text(count, 2)
	folded.Activated:Connect(function()
		self:setFolded(false)
	end)
	self._foldedChip = folded
	self._count = count
	return self :: BuffChips
end

-- #2090: fold the running potions into one chip, or bring them back.
function BuffChips.setFolded(self: any, folded: boolean)
	self._folded = folded
	foldedNow = folded
	self:_draw()
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
	self.frame.Visible = not self._hidden and next(self._leads) ~= nil
end

-- #2393: hide the Luck and pal row whatever it holds (the HUD, while a catch has the top middle on touch).
function BuffChips.setHidden(self: any, hidden: boolean)
	self._hidden = hidden
	self.frame.Visible = not hidden and next(self._leads) ~= nil
end

function BuffChips.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_draw()
end

function BuffChips._chip(self: any, potionId: string, order: number): Chip
	-- the whole chip is the tap target for the bag: the bottle at the top, the time under it
	local frame: TextButton = Create("TextButton", {
		Name = potionId,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.outline,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CHIP_W, CHIP_H),
		LayoutOrder = order,
		Parent = self.potions,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	Outline.border(frame, 3)
	local bottle: TextLabel = Create("TextLabel", {
		Name = "Bottle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(CHIP_BOTTLE, CHIP_BOTTLE),
		FontFace = Theme.fonts.body,
		TextSize = 24,
		TextColor3 = Theme.potionColor(potionId),
		Text = Theme.icons.potion,
		Parent = frame,
	})
	IconArt.setImages(bottle, ShopIcons.potionAll(potionId)) -- the first bottle that loads; the glyph until then
	local time: TextLabel = Create("TextLabel", {
		Name = "Time",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -4, 0, CHIP_TEXT + 4),
		FontFace = Theme.fonts.display,
		TextSize = CHIP_TEXT,
		TextColor3 = Theme.colors.white,
		Text = "",
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
	local look = BuffChips.fold(#running, self._folded)
	if #running == 0 and self._folded ~= FOLD_DEFAULT then
		-- nothing left running: the next potion starts folded, as the row does (#2396)
		self._folded = FOLD_DEFAULT
		foldedNow = FOLD_DEFAULT
	end
	for _, chip in self._chips do
		chip.frame.Visible = look.chips
	end
	self._tab.Visible = look.tab
	self._foldedChip.Visible = look.folded
	self._count.Text = "x" .. #running
	local lead: string? = if #running > 0 then running[1].potion.id else nil
	if lead ~= nil and lead ~= self._foldedId then
		self._foldedId = lead
		self._foldedBottle.TextColor3 = Theme.potionColor(lead)
		IconArt.setImages(self._foldedBottle, ShopIcons.potionAll(lead))
	end
	for id, chip in self._chips do
		if not shown[id] then
			chip.frame:Destroy()
			self._chips[id] = nil
		end
	end
	self.potions.Visible = #running > 0
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
	self.potions:Destroy()
end

return BuffChips
