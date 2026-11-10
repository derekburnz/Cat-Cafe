--!strict
-- One decor or lawn piece in the trade window (#1574, trading.md section 1b), in TradeTile's card look: a dark card
-- with its rarity colour washing up from the bottom and on its edge, the piece's clean picture (ShopIcons.decor, its
-- first letter until the picture loads), a small badge on the top left ("Lawn" for a lawn piece) and its tip bonus
-- at the foot ("+5%"). A piece that cannot go into the offer is dimmed: 🔒 while locked, "Has it" when the other
-- player owns it already; one already in the offer is dimmed with a green ✓. `flash` turns it yellow for "Changed!".
-- #2745: a banked crate kind uses it too ("x3" in the pill, 🔒 while the other player can't take it, "blocked"), and
-- props.onHold makes a press held HOLD_SECONDS call it instead of onClick (the Crates tab's count picker).
--   TradeItemTile.new(props)  props.onClick makes the whole card a button
--   tile:set(view)            the piece and its words; nil hides it
--   tile:flash()

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Props = {
	parent: Instance,
	size: number,
	layoutOrder: number?,
	name: string?,
	onClick: (() -> ())?,
	onHold: (() -> ())?, -- #2745: a long press
}

export type View = {
	id: string,
	name: string,
	rarity: string,
	image: string?, -- the clean picture, nil while there is none
	badge: string?, -- the top-left pill: "Lawn"
	foot: string?, -- the foot line: "+5%"
	status: ("locked" | "offered" | "theyHave" | "blocked")?,
}

export type TradeItemTile = {
	frame: Frame,
	set: (self: TradeItemTile, view: View?) -> (),
	flash: (self: TradeItemTile) -> (),
	destroy: (self: TradeItemTile) -> (),
}

local FLASH_SECONDS = 2
local HOLD_SECONDS = 0.45 -- a press held this long is a long press (#2745)

local TradeItemTile = {}
TradeItemTile.__index = TradeItemTile

-- a rarity's colour, the lawn's Uncommon and Golden rungs too (Theme.lawnRarity)
function TradeItemTile.color(rarity: string): Color3
	local lawn = Theme.lawnRarity[rarity]
	return if lawn ~= nil then lawn.color else Theme.rarityColor(rarity)
end

function TradeItemTile.new(props: Props): TradeItemTile
	local self = setmetatable({}, TradeItemTile) :: any
	local size = props.size
	local small = math.max(16, math.floor(size * 0.27))
	local frame: Frame = Create("Frame", {
		Name = props.name or "Piece",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.layoutOrder or 0,
		Visible = false,
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
		Parent = frame,
	}) :: UIStroke
	self._letter = Create("TextLabel", {
		Name = "Letter",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.6, 0.6),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 2,
		Parent = frame,
	}) :: TextLabel
	self._picture = Create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(size - 12, size - 12),
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
		ZIndex = 3,
		Parent = frame,
	}) :: ImageLabel
	self._badge = Create("TextLabel", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(0, small),
		FontFace = Theme.fonts.bodyBold,
		TextSize = math.max(12, small - 4),
		TextColor3 = Theme.colors.white,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	}) :: TextLabel
	self._foot = Create("TextLabel", {
		Name = "Foot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -4, 0, small),
		FontFace = Theme.fonts.display,
		TextSize = math.max(12, small - 2),
		TextColor3 = Theme.colors.mint,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 5,
		Parent = frame,
	}) :: TextLabel
	Outline.text(self._foot, 1.5)
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
		Size = UDim2.fromScale(0.8, 0.45),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 7,
		Parent = self._cover,
	}) :: TextLabel
	Outline.text(self._mark, 1.5)
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
		local onHold = props.onHold
		local held = false
		if onHold then
			local token = 0
			hit.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
					return
				end
				token += 1
				local mine = token
				held = false
				task.delay(HOLD_SECONDS, function()
					if token == mine and frame.Parent ~= nil then
						held = true
						onHold()
					end
				end)
			end)
			hit.InputEnded:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
					token += 1 -- let go before the hold: a tap
				end
			end)
		end
		hit.Activated:Connect(function()
			if held then
				held = false -- the long press had it
				return
			end
			onClick()
		end)
	end
	return self :: TradeItemTile
end

function TradeItemTile.set(self: any, view: View?)
	local frame: Frame = self.frame
	if view == nil then
		frame.Visible = false
		return
	end
	frame.Visible = true
	local color = TradeItemTile.color(view.rarity)
	local gold = view.rarity == "Golden"
	self._wash.Color = ColorSequence.new(PAL.card, PAL.card:Lerp(color, 0.45))
	local stroke: UIStroke = self._stroke
	stroke.Color = if gold then Theme.colors.gold else color
	stroke.Thickness = Theme.sizes.stroke + (if gold then 1 else 0)
	local image = view.image
	self._picture.Image = image or ""
	self._picture.Visible = image ~= nil
	self._letter.Text = view.name:sub(1, 1):upper()
	self._letter.Visible = image == nil
	self._badge.Text = view.badge or ""
	self._badge.Visible = view.badge ~= nil
	self._foot.Text = view.foot or ""
	self._foot.Visible = view.foot ~= nil
	local status = view.status
	self._cover.Visible = status ~= nil
	self._mark.Text = if status == "offered"
		then "✓"
		elseif status == "theyHave" then "Has it"
		else Theme.icons.lock
	self._mark.TextColor3 = if status == "offered" then Theme.colors.mint else Theme.colors.white
end

function TradeItemTile.flash(self: any)
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

function TradeItemTile.destroy(self: any)
	self.frame:Destroy()
end

return TradeItemTile
