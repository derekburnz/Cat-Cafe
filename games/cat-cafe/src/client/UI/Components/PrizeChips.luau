--!strict
-- What an Index reward pays, as little pictures with amounts (Derek 2026-10-27: "showing little symbols of whatever
-- they are going to get as next reward and how much"): a coin tile "$300", golden fish "x10", the food's own model
-- with its grade gem (F69) "x2", a crate "x1", the wheel "x1" for spins, a name tag, and a gold "+2% tips forever"
-- pill (golden-fish.md section 5). One chip per part from IndexRewards.prizeParts, so whatever the designer puts in Catalog.indexPrizes
-- shows without a UI change; a kind the UI does not know yet shows a gift.
--   PrizeChips.new(props)   a row that sizes itself to its chips, or wraps them inside its width (props.wrap)
--   chips:setCatalog(catalog)   foods, decor and crates by id, for their names and models
--   chips:set(prize, look?)   look.dayRate prices coins that grow with the cafe, look.spinsBanked marks spins that
--                             would not fit the Spin Wheel bank, look.gold tints a decor tile gold, look.tier names
--                             the "highest" crate (CrateLogic.resolve)
--   PrizeChips.bonusText(0.02)   "+2% tips forever"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrateLogic = require(script.Parent.CrateLogic)
local Create = require(script.Parent.Create)
local FishCoin = require(script.Parent.FishCoin)
local FoodGrade = require(script.Parent.FoodGrade)
local Format = require(script.Parent.Format)
local IndexRewards = require(script.Parent.IndexRewards)
local ItemIcon = require(script.Parent.ItemIcon)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Props = {
	parent: Instance,
	tile: number, -- each picture's size in px
	textSize: number?,
	textColor: Color3?,
	outlined: boolean?, -- white text with a dark outline, for dark boards
	wrap: boolean?, -- wrap onto more lines inside `size` (its height grows) instead of growing sideways
	size: UDim2?, -- with wrap; the width the chips wrap in
	showBonus: boolean?, -- false leaves the tips-forever pill out, for a card that shows it on a band of its own
	fitTo: GuiObject?, -- without wrap: shrink the whole row to fit inside this frame's width (a big prize on a board)
	fitPad: number?, -- px of fitTo's width kept clear
	name: string?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	align: Enum.HorizontalAlignment?,
}

export type Look = {
	gold: boolean?, -- the all-gold milestone of F48
	dayRate: number?, -- prices coinSeconds; without it coins shows the least it pays
	spinsBanked: number?, -- spins already banked; spins over SpinBankCap read "Full"
	tier: number?, -- the player's tier: a "highest" crate shows the crate of the highest area it opens
}

export type PrizeChips = {
	frame: Frame,
	setCatalog: (self: PrizeChips, catalog: Types.Catalog) -> (),
	set: (self: PrizeChips, prize: Types.IndexPrize?, look: Look?) -> (),
	destroy: (self: PrizeChips) -> (),
}

-- one chip on show: its amount label, kept to change the text without rebuilding the pictures
type Chip = { frame: Frame, label: TextLabel? }

local COIN_GLYPH = "💰"
local OTHER_GLYPH = "🎁"
local LINE_GAP = 4 -- between wrapped lines
local SPIN_BANK_CAP: number = Config.SpinBankCap or 20

local PrizeChips = {}
PrizeChips.__index = PrizeChips

function PrizeChips.new(props: Props): PrizeChips
	local self = setmetatable({}, PrizeChips) :: any
	self._props = props
	self._lures = {} :: { [string]: Types.LureDef }
	self._decor = {} :: { [string]: Types.DecorDef }
	self._crates = {} :: { [string]: CrateLogic.Crate }
	self._areas = {} :: { CrateLogic.Area }
	self._icons = {} :: { ItemIcon.ItemIcon }
	self._chips = {} :: { Chip }
	self._prize = nil :: Types.IndexPrize?
	self._look = nil :: Look?
	self._shape = "" -- the kinds and ids on show; a change rebuilds the chips, an amount change only relabels
	self._fit = {} :: { RBXScriptConnection }
	local wrap = props.wrap == true
	local layout: UIListLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, math.max(4, math.floor(props.tile / 5))),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = wrap,
	})
	self.frame = Create("Frame", {
		Name = props.name or "Prize",
		BackgroundTransparency = 1,
		AutomaticSize = if wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.X,
		Size = if wrap
			then props.size or UDim2.new(1, 0, 0, 0)
			else UDim2.fromOffset(0, props.tile),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchorPoint or Vector2.new(),
		LayoutOrder = props.layoutOrder or 0,
		Parent = props.parent,
	}, { layout :: Instance })
	local fitTo = props.fitTo
	if fitTo and not wrap then
		local scale: UIScale = Create("UIScale", { Parent = self.frame })
		local function fit()
			-- AbsoluteContentSize already includes the UIScale, so divide it back out for the row's own width
			local natural = layout.AbsoluteContentSize.X / math.max(scale.Scale, 0.01)
			local room = fitTo.AbsoluteSize.X - (props.fitPad or 0)
			scale.Scale = if room > 0 and natural > room then room / natural else 1
		end
		table.insert(self._fit, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit))
		table.insert(self._fit, fitTo:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	end
	return self :: PrizeChips
end

function PrizeChips.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._lures)
	for _, lure in catalog.lures do
		self._lures[lure.id] = lure
	end
	table.clear(self._decor)
	for _, decor in catalog.decor do
		self._decor[decor.id] = decor
	end
	self._crates = CrateLogic.byId(catalog.crates)
	self._areas = (catalog.areas or {}) :: any
	self._shape = "" -- names and models may have changed
	if self._prize ~= nil then
		self:set(self._prize, self._look)
	end
end

-- The picture, the glyph without a model, the tile's rarity colour and the amount text for one part.
function PrizeChips._partLook(
	self: any,
	part: IndexRewards.PrizePart,
	look: Look
): (string?, string, string?, string)
	local amount = "x" .. Format.short(part.amount)
	local kind = part.kind
	if kind == "coins" then
		return nil, COIN_GLYPH, "Legendary", Format.money(part.amount)
	elseif kind == "fish" then
		return nil, "", "Legendary", amount -- the cat-face coin is drawn over the tile in set
	elseif kind == "lure" then
		local lure: Types.LureDef? = self._lures[part.id or ""]
		return if lure then lure.asset else nil,
			Theme.foodIcons[part.id or ""] or Theme.icons.food,
			if lure then FoodGrade.of(lure) else nil,
			amount
	elseif kind == "spins" then
		local banked = look.spinsBanked
		local full = banked ~= nil and banked + part.amount > SPIN_BANK_CAP
		return nil, Theme.icons.spin, "Epic", if full then "Full" else amount
	elseif kind == "crate" then
		local id = part.id or "" -- already resolved by set
		local crate: CrateLogic.Crate? = self._crates[id]
		return if crate then crate.asset else nil,
			Theme.icons.crate,
			if CrateLogic.isGolden(id, crate) then "Legendary" else "Rare",
			amount
	elseif kind == "potion" then
		return nil, Theme.icons.potion, "Epic", amount
	elseif kind == "tag" then
		return nil, Theme.icons.tag, "Mythical", part.id or ""
	elseif kind == "decor" then
		local decor: Types.DecorDef? = self._decor[part.id or ""]
		return if decor then decor.asset else nil,
			Theme.icons.decor,
			if look.gold then "Legendary" else "Epic",
			""
	end
	return nil, OTHER_GLYPH, nil, amount
end

function PrizeChips.bonusText(fraction: number): string
	return "+" .. Format.percent(fraction) .. " tips forever"
end
local bonusText = PrizeChips.bonusText

function PrizeChips._clear(self: any)
	for _, icon in self._icons do
		icon:destroy()
	end
	table.clear(self._icons)
	for _, chip in self._chips do
		chip.frame:Destroy()
	end
	table.clear(self._chips)
end

function PrizeChips._amountLabel(self: any, chip: Frame, text: string, height: number): TextLabel
	local props: Props = self._props
	local label: TextLabel = Create("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		LayoutOrder = 1,
		FontFace = Theme.fonts.display,
		TextSize = props.textSize or Theme.sizes.textBody,
		TextColor3 = props.textColor
			or (if props.outlined then Theme.colors.white else Theme.modal.text),
		Text = text,
		Parent = chip,
	})
	if props.outlined then
		Outline.text(label, 2)
	end
	return label
end

-- The gold pill for a tips-forever bonus, a little shorter than a picture.
function PrizeChips._bonusPill(self: any, chip: Frame, text: string): TextLabel
	local props: Props = self._props
	local pill: TextLabel = Create("TextLabel", {
		Name = "Bonus",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, math.floor(props.tile * 0.7)),
		FontFace = Theme.fonts.display,
		TextSize = math.max(12, (props.textSize or Theme.sizes.textBody) - 2),
		TextColor3 = Theme.colors.white,
		Text = text,
		Parent = chip,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	Outline.border(pill, 2)
	Outline.text(pill, 1.5)
	return pill
end

function PrizeChips.set(self: any, prize: Types.IndexPrize?, look: Look?)
	local props: Props = self._props
	local shown: Look = look or {}
	self._prize = prize
	self._look = look
	if prize == nil then
		self._shape = ""
		self:_clear()
		return
	end
	local parts: { IndexRewards.PrizePart } = {}
	for _, raw in IndexRewards.prizeParts(prize, shown.dayRate) do
		local part: IndexRewards.PrizePart = raw
		if raw.kind == "crate" then
			-- "highest" becomes the crate it pays now, so the picture changes when a new area opens
			local id = CrateLogic.resolve(raw.id or "", self._crates, self._areas, shown.tier)
			local resolved: IndexRewards.PrizePart =
				{ kind = "crate", id = id, amount = raw.amount }
			part = resolved
		end
		if part.kind ~= "bonus" or props.showBonus ~= false then
			table.insert(parts, part)
		end
	end
	local keys: { string } = {}
	for _, part in parts do
		table.insert(keys, part.kind .. ":" .. (part.id or ""))
	end
	local shape = table.concat(keys, ",") .. (if shown.gold then "|gold" else "")
	if shape == self._shape and #self._chips == #parts then
		-- the same pictures: only the amounts can have changed (a coin estimate, a fuller spin bank)
		for index, part in parts do
			local label: TextLabel? = self._chips[index].label
			if label then
				local _, _, _, amount = self:_partLook(part, shown)
				label.Text = if part.kind == "bonus" then bonusText(part.amount) else amount
			end
		end
		return
	end
	self._shape = shape
	self:_clear()
	local tile = props.tile
	local height = tile + (if props.wrap then LINE_GAP else 0)
	for order, part in parts do
		local chip: Frame = Create("Frame", {
			Name = part.kind .. (if part.id then "_" .. part.id else ""),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, height),
			LayoutOrder = order,
			Parent = self.frame,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 3),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local entry: Chip = { frame = chip, label = nil }
		if part.kind == "bonus" then
			entry.label = self:_bonusPill(chip, bonusText(part.amount))
		else
			local asset, glyph, rarity, amount = self:_partLook(part, shown)
			local icon = ItemIcon.new({
				parent = chip,
				size = UDim2.fromOffset(tile, tile),
				name = "Picture",
				badge = "gem",
			})
			if part.kind == "lure" then
				icon:setFood(self._lures[part.id or ""], part.id) -- F69: the food's grade gem
			else
				icon:set(asset, glyph, rarity)
			end
			if part.kind == "fish" then
				FishCoin.new({
					parent = icon.frame,
					size = math.floor(tile * 0.62),
					position = UDim2.fromScale(0.5, 0.58),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 2,
				})
			end
			table.insert(self._icons, icon)
			if amount ~= "" then
				entry.label = self:_amountLabel(chip, amount, tile)
			end
		end
		table.insert(self._chips, entry)
	end
end

function PrizeChips.destroy(self: any)
	for _, connection in self._fit do
		connection:Disconnect()
	end
	table.clear(self._fit)
	self:_clear()
	self.frame:Destroy()
end

return PrizeChips
