--!strict
-- The destination's name card in the clouds (F84, hometown-cannon.md 3b): while the cloud tunnel covers the screen
-- in a cannon flight, a ticket with the place's picture and "To the Woods!" on a ribbon in its colour. Since Derek
-- 2026-11-03 ("have the picture be top and you be shown still in the frame below the location as it's cool to see
-- your character fly") it is a smaller card at the top centre, so the flying character in the middle stays in view,
-- and the "Landing at the Woods camp" line is gone (less text). Since #1163 (Derek 2026-11-04) a player's own flight
-- shows it as the picker closes: it pops in with a white ring at once, wobbles, zips up and off with the BOOM (0.5 s
-- after CannonLaunchAt) and is gone by 0.7 (CannonLogic.CHOSEN_HOLD). The intro's shot 2 keeps the cloud schedule:
-- in at 1.6 s after its launchAt, wobble, zip off at 2.0 and gone by 2.2 (CannonLogic.cardTimes(0.4)). With reduced
-- motion it fades in and out instead, with no pop, ring, wobble or zip. DisplayOrder 46 sits just over VFX's cloud
-- tunnel (45) and under the intro (50); it never takes input. No card for a cloud hop home.

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
	-- destination is "town" or an area id; startAt is the server time its steps count from (the intro's CannonLaunchAt,
	-- or the moment a player's picker closed); hold and from are how long it stays up and when it pops in
	-- (CannonLogic.cardTimes)
	show: (
		self: CannonCard,
		destination: string,
		name: string,
		startAt: number,
		hold: number?,
		from: number?
	) -> (),
	hide: (self: CannonCard) -> (),
	destroy: (self: CannonCard) -> (),
}

local PICTURE_H = 104
local RIBBON_H = 50
local TICKET = Vector2.new(360, 12 + PICTURE_H + RIBBON_H / 2 + 14)
local TOP_GAP = 14 -- under Roblox's top bar (the ScreenGui keeps clear of it)
local HOME = UDim2.new(0.5, 0, 0, TOP_GAP + 30 + TICKET.Y / 2) -- 30: room for the pop ring above the card
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RING = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WOBBLE = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local ZIP = TweenInfo.new(
	CannonLogic.CARD_GONE - CannonLogic.CARD_OUT,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.In
)
-- Reduce Motion: the whole ticket fades in, and out over the zip's time, in place
local FADE_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(
	CannonLogic.CARD_GONE - CannonLogic.CARD_OUT,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.In
)

-- One transparency property of a part of the ticket, at its built value, for the Reduce Motion fade.
type Fade = { instance: Instance, property: string, base: number }

-- Every transparency the fade moves: the ticket's and its descendants' (not the pop ring, which never shows then).
local function fadesOf(ticket: Frame, ring: Frame): { Fade }
	local list: { Fade } = {}
	local function add(instance: Instance, property: string)
		table.insert(
			list,
			{ instance = instance, property = property, base = (instance :: any)[property] }
		)
	end
	local items: { Instance } = ticket:GetDescendants()
	table.insert(items, 1, ticket)
	for _, item in items do
		if item == (ring :: Instance) or item:IsDescendantOf(ring) then
			continue
		end
		if item:IsA("GuiObject") then
			add(item, "BackgroundTransparency")
		end
		if item:IsA("TextLabel") then
			add(item, "TextTransparency")
		elseif item:IsA("ImageLabel") then
			add(item, "ImageTransparency")
		elseif item:IsA("UIStroke") then
			add(item, "Transparency")
		end
	end
	return list
end

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
		Size = UDim2.new(1, 20, 0, RIBBON_H),
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
		TextSize = 32,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 3,
		Parent = ribbon,
	})
	Outline.text(self._title, 4)
	self._fades = fadesOf(ticket, ring)
	self._fading = {} :: { Tween }
	self._token = 0
	return self :: CannonCard
end

local function still(): boolean
	return GuiService.ReducedMotionEnabled
end

-- Stops a running fade and puts every transparency back at its built value.
local function unfade(self: any)
	for _, tween in self._fading do
		tween:Cancel()
	end
	table.clear(self._fading)
	for _, fade in self._fades :: { Fade } do
		(fade.instance :: any)[fade.property] = fade.base
	end
end

-- Fades the ticket from fully clear to as built (`visible`), or from as built to clear.
local function fade(self: any, visible: boolean, info: TweenInfo)
	unfade(self)
	for _, f in self._fades :: { Fade } do
		local clear = 1
		if visible then
			(f.instance :: any)[f.property] = clear
		end
		table.insert(
			self._fading,
			Tween.to(f.instance, info, { [f.property] = if visible then f.base else clear })
		)
	end
end

function CannonCard.show(
	self: any,
	destination: string,
	name: string,
	startAt: number,
	hold: number?,
	from: number?
)
	self:hide() -- a card still up from an earlier flight goes first
	local inAt, wobbleAt, outAt, goneAt = CannonLogic.cardTimes(hold, from)
	local elapsed = Workspace:GetServerTimeNow() - startAt
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
			fade(self, true, FADE_IN)
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
			fade(self, false, FADE_OUT)
			return
		end
		self._zip = Tween.to(self._ticket, ZIP, { Position = UDim2.new(0.5, 0, -0.4, 0) })
	end)
	at(goneAt, function()
		self._ticket.Visible = false
		self._ticket.Position = HOME
		unfade(self)
	end)
end

function CannonCard.hide(self: any)
	self._token += 1
	unfade(self)
	if self._zip ~= nil then
		self._zip:Cancel() -- an older card's zip would drag the new one off screen
		self._zip = nil
	end
	self._ticket.Visible = false
	self._ticket.Position = HOME
end

function CannonCard.destroy(self: any)
	self._token += 1
	unfade(self)
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CannonCard
