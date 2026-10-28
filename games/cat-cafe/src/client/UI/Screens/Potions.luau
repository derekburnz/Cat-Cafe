--!strict
-- The potion bag (F64, data-model section 12b; the quest potions of F73 join it, quests.md section 4). Opened from
-- the Potions pill on the left menu (key P) or a tap on a HUD potion timer. One row per potion, kept brief (Derek
-- 2026-10-28: "keep the info brief and simple"): a round tile in the potion's colour with how many are in the bag,
-- the name, one short line on what it does and for how long, the time left while it runs ("8:12 left"), and a Use
-- button. Use is grey with none in the bag and reads "Full" when another would take the timer past
-- PotionMaxMinutes (60). A pressed Use reads "..." for a moment; the server's answer is the next ProfileSync, and
-- a refusal is the server's toast. The drink sound plays when the bag's count drops, which is the server accepting.
-- Timers pause while the player is away, so a rejoin shows what was left. Rows and sums: Components/PotionLogic.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	use: (potionId: string) -> (),
	close: () -> (),
}

export type Potions = {
	frame: Frame,
	setCatalog: (self: Potions, catalog: Types.Catalog) -> (),
	render: (self: Potions, state: Types.PlayerState) -> (),
	destroy: (self: Potions) -> (),
}

local ROW_H = 76
local TILE = 56
local USE_W = 104
local PENDING_SECONDS = 1 -- a pressed Use waits this long for the server before it can be pressed again

type Row = {
	frame: Frame,
	tile: Frame,
	count: TextLabel,
	name: TextLabel,
	effect: TextLabel,
	left: TextLabel,
	use: Button.Button,
}

local Potions = {}
Potions.__index = Potions

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function Potions.new(callbacks: Callbacks): Potions
	local self = setmetatable({}, Potions) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._rows = {} :: { [string]: Row }
	self._counts = nil :: { [string]: number }? -- the bag at the last render, to hear a drink land
	self._pending = {} :: { [string]: number } -- potion id -> os.clock() of the press

	local panel = Panel.new({
		name = "Potions",
		title = "Potions",
		subtitle = "Drink one for a boost · timers pause while you're away",
		color = Theme.colors.berry,
		icon = Theme.icons.potion,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(600, 520), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	-- with an empty bag, one line on where potions come from, under the rows
	self._hint = text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "No potions yet. Mystery visitors, gifts and codes give them.",
		LayoutOrder = 1000,
		Visible = false,
		Parent = self._list,
	})

	-- once a second while open, so the times left count down
	local clock = 0
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 1 then
			return
		end
		clock = 0
		if self.frame.Visible then
			self:_refresh()
		end
	end)
	return self :: Potions
end

function Potions.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_refresh()
end

function Potions.render(self: any, state: Types.PlayerState)
	-- a count that dropped is the server taking a UsePotion: the drink sound (sound list 5.11)
	local counts: { [string]: number } = state.potions or {}
	local before: { [string]: number }? = self._counts
	if before then
		for id, count in before do
			if (counts[id] or 0) < count then
				Sound.play("potionDrink")
				self._pending[id] = nil
				break
			end
		end
	end
	self._counts = table.clone(counts)
	self._state = state
	self:_refresh()
end

function Potions._row(self: any, potionId: string): Row
	local frame: Frame = Create("Frame", {
		Name = potionId,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = Theme.potionColor(potionId),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(TILE, TILE),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(tile, 2)
	local glyph = text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.icons.potion,
		Parent = tile,
	})
	IconArt.set(glyph, Theme.icons.potion, 0.8)
	-- how many are in the bag, a small dark pill on the tile's corner
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 4),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.ink,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 2,
		Parent = tile,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = count })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = count,
	})
	local textLeft = TILE + 24
	local textRight = USE_W + 20
	local name = text({
		Name = "PotionName",
		Position = UDim2.fromOffset(textLeft, 12),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 3,
		Parent = frame,
	})
	local effect = text({
		Name = "Effect",
		Position = UDim2.fromOffset(textLeft, 40),
		Size = UDim2.new(1, -(textLeft + textRight), 0, 22),
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	-- "8:12 left" over the Use button while it runs
	local left = text({
		Name = "Left",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(USE_W, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.goodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = frame,
	})
	local use = Button.new({
		name = "Use",
		text = "Use",
		style = "primary",
		size = UDim2.fromOffset(USE_W, 38),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -10, 1, -10),
		textSize = Theme.sizes.textBody + 1,
		parent = frame,
		onClick = function()
			local pressedAt = self._pending[potionId]
			if pressedAt and os.clock() - pressedAt < PENDING_SECONDS then
				return
			end
			self._pending[potionId] = os.clock()
			self._callbacks.use(potionId)
			self:_refresh()
			task.delay(PENDING_SECONDS, function()
				if self._rows[potionId] then
					self:_refresh()
				end
			end)
		end,
	})
	return {
		frame = frame,
		tile = tile,
		count = count,
		name = name,
		effect = effect,
		left = left,
		use = use,
	}
end

function Potions._refresh(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	local rows = PotionLogic.rows(self._catalog, state, Workspace:GetServerTimeNow())
	local shown: { [string]: boolean } = {}
	local any = false
	for order, view in rows do
		local potion = view.potion
		shown[potion.id] = true
		local row: Row = self._rows[potion.id] or self:_row(potion.id)
		self._rows[potion.id] = row
		row.frame.LayoutOrder = order
		row.name.Text = potion.name
		local line: { string } = {}
		if potion.effect ~= "" then
			table.insert(line, potion.effect)
		end
		if potion.minutes > 0 then
			table.insert(line, ("%d min"):format(potion.minutes))
		end
		row.effect.Text = table.concat(line, "  ·  ")
		row.count.Text = "x" .. view.count
		row.count.Visible = view.count > 0
		local running = view.secondsLeft > 0
		row.left.Visible = running
		row.left.Text = PotionLogic.clock(view.secondsLeft) .. " left"
		local pressedAt: number? = self._pending[potion.id]
		local pending = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local full = view.count > 0 and not view.canUse
		row.use:setText(if pending then "..." elseif full then "Full" else "Use")
		row.use:setEnabled(view.canUse and not pending)
		-- an empty row stays to show what the potion does, faded
		local empty = view.count == 0 and not running
		row.frame.BackgroundTransparency = if empty then 0.4 else 0
		row.tile.BackgroundTransparency = if empty then 0.5 else 0
		any = any or view.count > 0 or running
	end
	for id, row in self._rows do
		if not shown[id] then
			row.use:destroy()
			row.frame:Destroy()
			self._rows[id] = nil
		end
	end
	self._hint.Visible = not any
end

function Potions.destroy(self: any)
	self._tick:Disconnect()
	for _, row in self._rows do
		row.use:destroy()
	end
	table.clear(self._rows)
	self._panel:destroy()
end

return Potions
