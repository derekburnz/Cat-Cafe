--!strict
-- One cat in the trade window (F102, trading.md section 3), in the cat room's card look: a cream card with its rarity
-- colour washing up from the bottom and on its edge (a thicker gold edge for a gold cat, the slowly turning rainbow
-- for a rainbow one, with ✨ or 🌈 in the corner), the cat's picture, "Lv 4" on the top left and what it earns a
-- second at the foot ("+$24/s" in green on their side, "$24/s" on yours). A cat that cannot go into the offer
-- (locked, or one only its owner may keep) is dimmed with 🔒; one already in the offer is dimmed with a green ✓.
-- `flash` turns the card yellow for a moment, for "Changed!".
--   TradeTile.new(props)  props.onClick makes the whole card a button
--   tile:set(view)        the cat and its words; nil empties the cell (a dashed slot)
--   tile:flash()

local CatPortrait = require(script.Parent.CatPortrait)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Rainbow = require(script.Parent.Rainbow)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Props = {
	parent: Instance,
	size: number,
	layoutOrder: number?,
	name: string?,
	onClick: (() -> ())?,
}

export type View = {
	def: Types.CatDef,
	variant: string?, -- "gold", "rainbow" or nil
	level: number?, -- nil hides the "Lv 4" badge (the Trades page's small cards)
	rate: string?, -- the foot line; nil hides it
	good: boolean?, -- the rate in green (their cats, earning for you)
	status: ("locked" | "offered")?,
}

export type TradeTile = {
	frame: Frame,
	set: (self: TradeTile, view: View?) -> (),
	flash: (self: TradeTile) -> (),
	destroy: (self: TradeTile) -> (),
}

local FLASH_SECONDS = 2

local TradeTile = {}
TradeTile.__index = TradeTile

local function badge(
	parent: Instance,
	text: string,
	color: Color3,
	textColor: Color3,
	size: number
): TextLabel
	local label: TextLabel = Create("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size),
		FontFace = Theme.fonts.bodyBold,
		TextSize = math.max(12, size - 4), -- 9 px or more on a phone
		TextColor3 = textColor,
		Text = text,
		ZIndex = 5,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
	return label
end

function TradeTile.new(props: Props): TradeTile
	local self = setmetatable({}, TradeTile) :: any
	local size = props.size
	self._size = size
	self._key = ""
	local frame: Frame = Create("Frame", {
		Name = props.name or "Tile",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.layoutOrder or 0,
		Parent = props.parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	self.frame = frame
	self._wash = Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(PAL.card),
		Parent = frame,
	}) :: UIGradient
	self._stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = PAL.subtext,
		Thickness = Theme.sizes.stroke,
		Transparency = 0.5,
		Parent = frame,
	}) :: UIStroke
	self._edge = nil :: UIGradient?
	local small = math.max(16, math.floor(size * 0.27))
	self._portrait = CatPortrait.new({
		parent = frame,
		size = UDim2.fromOffset(size - 10, size - 10),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 2),
		still = true,
		zIndex = 2,
	})
	self._level = badge(frame, "", Theme.colors.cocoaDeep, Theme.colors.white, small)
	self._level.Name = "Level"
	self._level.Position = UDim2.fromOffset(3, 3)
	self._coat = badge(frame, "", Theme.colors.gold, Theme.colors.goldText, small)
	self._coat.Name = "Coat"
	self._coat.AnchorPoint = Vector2.new(1, 0)
	self._coat.Position = UDim2.new(1, -3, 0, 3)
	self._rate = Create("TextLabel", {
		Name = "Rate",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -4, 0, small),
		FontFace = Theme.fonts.display,
		TextSize = math.max(12, small - 2),
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 5,
		Parent = frame,
	}) :: TextLabel
	Outline.text(self._rate, 1.5)
	-- the dim cover over a cat that cannot go, or is already in the offer
	self._cover = Create("Frame", {
		Name = "Cover",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 6,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) }) :: Frame
	self._mark = Create("TextLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.5, 0.5),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 7,
		Parent = self._cover,
	}) :: TextLabel
	-- an empty slot: a faint dashed look (a light card with a soft edge and nothing on it)
	self._empty = true
	local onClick = props.onClick
	if onClick then
		local hit: TextButton = Create("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 8,
			Parent = frame,
		})
		hit.Activated:Connect(function()
			onClick()
		end)
	end
	self:set(nil)
	return self :: TradeTile
end

function TradeTile.set(self: any, view: View?)
	local frame: Frame = self.frame
	local stroke: UIStroke = self._stroke
	local edge: UIGradient? = self._edge
	if view == nil then
		self._key = ""
		self._portrait.frame.Visible = false
		self._level.Visible = false
		self._coat.Visible = false
		self._rate.Visible = false
		self._cover.Visible = false
		self._wash.Color = ColorSequence.new(PAL.card)
		frame.BackgroundTransparency = 0.5
		stroke.Color = PAL.subtext
		stroke.Thickness = Theme.sizes.stroke
		stroke.Transparency = 0.6
		if edge then
			edge.Enabled = false
		end
		return
	end
	local def = view.def
	local rarity = def.rarity
	local gold = view.variant == "gold"
	local rainbow = view.variant == "rainbow"
	local key = def.id .. ":" .. (view.variant or "base")
	if key ~= self._key then
		self._key = key
		self._portrait:set(def, gold)
	end
	self._portrait.frame.Visible = true
	frame.BackgroundTransparency = 0
	self._wash.Color = ColorSequence.new(PAL.card, PAL.card:Lerp(Theme.rarityColor(rarity), 0.45))
	stroke.Transparency = 0
	stroke.Thickness = Theme.sizes.stroke + (if gold or rainbow then 1 else 0)
	stroke.Color = if gold then Theme.colors.gold else Theme.rarityColor(rarity)
	if rainbow and edge == nil then
		edge = Rainbow.stroke(stroke)
		self._edge = edge
	end
	if edge then
		edge.Enabled = rainbow
		if rainbow then
			stroke.Color = Theme.colors.white
		end
	end
	local level = view.level
	self._level.Text = if level then string.format("Lv %d", level) else ""
	self._level.Visible = level ~= nil
	self._coat.Visible = gold or rainbow
	self._coat.Text = if rainbow then "🌈" else "✨"
	self._coat.BackgroundColor3 = if rainbow then Theme.colors.white else Theme.colors.gold
	local rate = view.rate
	self._rate.Visible = rate ~= nil
	self._rate.Text = rate or ""
	self._rate.TextColor3 = if view.good then Theme.colors.mint else Theme.colors.white
	self._cover.Visible = view.status ~= nil
	self._mark.Text = if view.status == "offered" then "✓" else Theme.icons.lock
	self._mark.TextColor3 = if view.status == "offered"
		then Theme.colors.mint
		else Theme.colors.white
end

function TradeTile.flash(self: any)
	local frame: Frame = self.frame
	frame.BackgroundColor3 = Theme.colors.gold
	self._wash.Enabled = false
	local token = {}
	self._flashToken = token
	task.delay(FLASH_SECONDS, function()
		if self._flashToken == token and frame.Parent ~= nil then
			self._wash.Enabled = true
			Tween.to(frame, Tween.FAST, { BackgroundColor3 = PAL.card })
		end
	end)
end

function TradeTile.destroy(self: any)
	self._portrait:destroy()
	self.frame:Destroy()
end

return TradeTile
