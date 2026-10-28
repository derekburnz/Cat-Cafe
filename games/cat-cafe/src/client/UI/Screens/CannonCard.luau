--!strict
-- The destination's name card in the clouds (F84, hometown-cannon.md 3b): while the cloud tunnel covers the screen
-- in a cannon flight, a ticket with the place's picture, "To the Woods!" on a ribbon in its colour and "Landing at
-- the Woods camp" under it. It pops in with a white ring as the clouds close (1.6 s after CannonLaunchAt), wobbles
-- as the tunnel takes the place's colour (2.0), zips up and off as they part (2.4) and is gone by 2.6. With reduced
-- motion it only shows from 1.6 to 2.4. DisplayOrder 46 sits just over VFX's cloud tunnel (45) and under the intro
-- (50); it never takes input. No card for a cloud hop home.

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local CannonLogic = require(script.Parent.Parent.Components.CannonLogic)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type CannonCard = {
	screenGui: ScreenGui,
	-- destination is "town" or an area id; launchAt is the flight's CannonLaunchAt (server time); hold is how long it
	-- stays up (CannonLogic.cardTimes)
	show: (
		self: CannonCard,
		destination: string,
		name: string,
		launchAt: number,
		hold: number?
	) -> (),
	hide: (self: CannonCard) -> (),
	destroy: (self: CannonCard) -> (),
}

local TICKET = Vector2.new(440, 268)
local PICTURE_H = 150
local HOME = UDim2.fromScale(0.5, 0.42)
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RING = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WOBBLE = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local ZIP = TweenInfo.new(
	CannonLogic.CARD_GONE - CannonLogic.CARD_OUT,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.In
)

local CannonCard = {}
CannonCard.__index = CannonCard

function CannonCard.new(parent: Instance): CannonCard
	local self = setmetatable({}, CannonCard) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeCannonCard",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 46,
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local ticket: Frame = Create("Frame", {
		Name = "Ticket",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = HOME,
		Size = UDim2.fromOffset(TICKET.X, TICKET.Y),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }) })
	Outline.border(ticket, Theme.sizes.outline + 1)
	self._ticket = ticket
	self._scale = Create("UIScale", { Parent = ticket })

	-- the white ring that flashes out round the ticket as it pops in
	local ring: Frame = Create("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = ticket,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 8) }) })
	self._ring = ring
	self._ringStroke = Create("UIStroke", {
		Color = Theme.colors.white,
		Thickness = 6,
		Transparency = 1,
		Parent = ring,
	})

	local art: Frame = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, PICTURE_H),
		Parent = ticket,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(art, 2)
	self._art = art
	self._icon = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = "",
		Parent = art,
	}, {
		Create("UIPadding", { PaddingTop = UDim.new(0, 24), PaddingBottom = UDim.new(0, 24) }),
	})
	self._picture = Create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		Image = "",
		Parent = art,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })

	-- the ribbon across the picture's foot, in the place's colour
	local ribbon: Frame = Create("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 12 + PICTURE_H),
		Size = UDim2.new(1, 20, 0, 58),
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = ticket,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	Outline.border(ribbon, Theme.sizes.outline)
	Outline.shade(ribbon, 0.2)
	self._ribbon = ribbon
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 38,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 3,
		Parent = ribbon,
	})
	Outline.text(self._title, 4)
	self._sub = Create("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 26),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.modal.text,
		Text = "",
		Parent = ticket,
	})
	self._token = 0
	return self :: CannonCard
end

local function still(): boolean
	return GuiService.ReducedMotionEnabled
end

function CannonCard.show(
	self: any,
	destination: string,
	name: string,
	launchAt: number,
	hold: number?
)
	self:hide() -- a card still up from an earlier flight goes first
	local inAt, wobbleAt, outAt, goneAt = CannonLogic.cardTimes(hold)
	local elapsed = Workspace:GetServerTimeNow() - launchAt
	if elapsed >= outAt then
		return -- joined the flight too late to matter
	end
	local token = self._token
	local color = Theme.areaColors[destination] or Theme.colors.caramel
	local glyph = (Theme.icons :: any)[destination] or Theme.icons.travel
	self._art.BackgroundColor3 = color
	self._icon.Text = glyph
	self._picture.Image = Theme.areaPictures[destination] or ""
	self._ribbon.BackgroundColor3 = color
	self._title.Text = CannonLogic.cardTitle(destination, name)
	self._sub.Text = CannonLogic.cardSub(destination, name)

	local function at(seconds: number, step: () -> ())
		task.delay(math.max(0, seconds - elapsed), function()
			if self._token == token then
				step()
			end
		end)
	end
	at(inAt, function()
		local ticket: Frame = self._ticket
		ticket.Position = HOME
		ticket.Rotation = 0
		ticket.Visible = true
		self._ringStroke.Transparency = 1
		if still() then
			self._scale.Scale = 1
			return
		end
		self._scale.Scale = 1.12
		Tween.to(self._scale, POP, { Scale = 1 })
		self._ring.Size = UDim2.fromScale(1, 1)
		self._ringStroke.Transparency = 0
		Tween.to(self._ring, RING, { Size = UDim2.new(1, 60, 1, 60) })
		Tween.to(self._ringStroke, RING, { Transparency = 1 })
	end)
	at(wobbleAt, function()
		if still() then
			return
		end
		self._ticket.Rotation = -5
		Tween.to(self._ticket, WOBBLE, { Rotation = 0 })
	end)
	at(outAt, function()
		if still() then
			self._ticket.Visible = false
			return
		end
		Tween.to(self._ticket, ZIP, { Position = UDim2.new(0.5, 0, -0.4, 0) })
	end)
	at(goneAt, function()
		self._ticket.Visible = false
		self._ticket.Position = HOME
	end)
end

function CannonCard.hide(self: any)
	self._token += 1
	self._ticket.Visible = false
	self._ticket.Position = HOME
end

function CannonCard.destroy(self: any)
	self._token += 1
	self.screenGui:Destroy()
end

return CannonCard
