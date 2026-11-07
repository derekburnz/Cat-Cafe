--!strict
-- The Rescue Rally's bar (F101, rescue-rally.md section 4), drawn on the HUD banner and on the Town Square board: a
-- dark rounded track filling in the Rally red, a round marker at each step (15%, 30%, 50%, 75% and the end) with the
-- step's picture (the golden fish, a potion, the Rally Crate), gold once the step is reached, the points the step
-- pays at under it, and "45 / 90" just past the track's end, where no picture can cover it (#2078).
--   RallyBar.new(props)   props.name names the track ("RallyBar" on the banner, where VFX's Effects/Rally sends
--                         its "+1" pops); size is the track's (leave countWidth px past its end for the count),
--                         marker each step's circle, numberSize the text under it
--   bar:set(view)         a RallyLogic view: the fill eases to it and the reached steps turn gold

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local RallyLogic = require(script.Parent.RallyLogic)
local ShopIcons = require(script.Parent.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Props = {
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	marker: number, -- px, each step's circle
	textSize: number, -- the count's largest size; it shrinks to fit countWidth
	countWidth: number, -- px past the track's end marker for "45 / 90"
	numberSize: number, -- the step numbers under the markers
	textColor: Color3?, -- the step numbers not reached yet (white unless given)
	zIndex: number?,
}

export type RallyBar = {
	frame: Frame,
	set: (self: RallyBar, view: RallyLogic.View) -> (),
	destroy: (self: RallyBar) -> (),
}

type Marker = {
	frame: Frame,
	stroke: UIStroke,
	picture: ImageLabel,
	glyph: TextLabel,
	number: TextLabel,
	key: string,
}

local RallyBar = {}
RallyBar.__index = RallyBar

RallyBar.RED = Color3.fromHex("D9483B") -- Model-Agent's Rally colours (#759)
RallyBar.BLUE = Color3.fromHex("3C7DD9")
RallyBar.NAVY = Color3.fromHex("2F3E5C")
RallyBar.TRACK = Color3.fromHex("1C2539")
RallyBar.COUNT_GAP = 4 -- px between the end marker and the count

local function pictureOf(picture: RallyLogic.Picture): string?
	if picture.kind == "crate" then
		return ShopIcons.crate(picture.id)
	elseif picture.kind == "potion" then
		return ShopIcons.potion(picture.id)
	end
	return Theme.textures.fishCoin
end

local function glyphOf(picture: RallyLogic.Picture): string
	return if picture.kind == "crate"
		then Theme.icons.crate
		elseif picture.kind == "potion" then "🧪"
		else Theme.icons.goldenFish
end

function RallyBar.new(props: Props): RallyBar
	local self = setmetatable({}, RallyBar) :: any
	self._props = props
	self._markers = {} :: { Marker }
	self._fillTo = -1
	local z = props.zIndex or 1
	local track: Frame = Create("Frame", {
		Name = props.name,
		BackgroundColor3 = RallyBar.TRACK,
		BorderSizePixel = 0,
		Size = props.size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchorPoint or Vector2.new(),
		ZIndex = z,
		Parent = props.parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = RallyBar.RED,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = z + 1,
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }) :: Frame
	-- the count sits past the end marker, outside the track, so no step picture can cover it (#2078)
	self._points = Create("TextLabel", {
		Name = "Points",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, props.marker / 2 + RallyBar.COUNT_GAP, 0.5, 0),
		Size = UDim2.new(0, props.countWidth, 0, math.max(props.marker, props.textSize + 4)),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = z + 2,
		Parent = track,
	}, { Create("UITextSizeConstraint", { MaxTextSize = props.textSize }) }) :: TextLabel
	Outline.text(self._points, 2)
	self.frame = track
	return self :: RallyBar
end

function RallyBar._marker(self: any, index: number, share: number): Marker
	local existing: Marker? = self._markers[index]
	if existing then
		existing.frame.Position = UDim2.new(share, 0, 0.5, 0)
		return existing
	end
	local props: Props = self._props
	local size = props.marker
	local z = (props.zIndex or 1) + 3
	local frame: Frame = Create("Frame", {
		Name = "Step" .. index,
		BackgroundColor3 = RallyBar.NAVY,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(share, 0, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = self.frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local stroke = Outline.border(frame, 2)
	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = "",
		ZIndex = z + 1,
		Parent = frame,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0.2, 0),
			PaddingBottom = UDim.new(0.2, 0),
		}),
	})
	local picture: ImageLabel = Create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z + 2,
		Parent = frame,
	})
	-- the points this step pays at, just under its circle (#2078)
	local number: TextLabel = Create("TextLabel", {
		Name = "At",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 1),
		Size = UDim2.fromOffset(math.max(size, props.numberSize * 3), props.numberSize + 2),
		FontFace = Theme.fonts.display,
		TextSize = props.numberSize,
		TextColor3 = props.textColor or Theme.colors.white,
		Text = "",
		ZIndex = z + 2,
		Parent = frame,
	})
	Outline.text(number, 1)
	local marker: Marker = {
		frame = frame,
		stroke = stroke,
		picture = picture,
		glyph = glyph,
		number = number,
		key = "",
	}
	self._markers[index] = marker
	return marker
end

function RallyBar.set(self: any, view: RallyLogic.View)
	local fill = math.clamp(view.fill, 0, 1)
	if fill ~= self._fillTo then
		-- a new lap empties the bar at once; points ease in
		local fillFrame: Frame = self._fill
		if fill < self._fillTo then
			fillFrame.Size = UDim2.fromScale(fill, 1)
		else
			Tween.to(fillFrame, Tween.FAST, { Size = UDim2.fromScale(fill, 1) })
		end
		self._fillTo = fill
	end
	self._points.Text = view.points
	for index, step in view.steps do
		local marker = self:_marker(index, step.share)
		local key = step.picture.kind .. ":" .. (step.picture.id or "")
		if marker.key ~= key then
			marker.key = key
			local image = pictureOf(step.picture)
			marker.picture.Image = image or ""
			marker.picture.Visible = image ~= nil
			marker.glyph.Text = if image == nil then glyphOf(step.picture) else ""
		end
		marker.number.Text = tostring(step.at)
		marker.number.TextColor3 = if step.reached
			then Theme.colors.gold
			else self._props.textColor or Theme.colors.white
		marker.frame.BackgroundColor3 = if step.reached then Theme.colors.gold else RallyBar.NAVY
		marker.stroke.Color = if step.reached then Theme.colors.goldDark else Theme.colors.outline
	end
	for index = #view.steps + 1, #self._markers do
		self._markers[index].frame.Visible = false
	end
end

function RallyBar.destroy(self: any)
	self.frame:Destroy()
end

return RallyBar
