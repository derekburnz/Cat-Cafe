--!strict
-- The Cat Cannon picker (F84, hometown-cannon.md 3a and 3c; mockup approved by Derek 2026-10-28 13:55 and 14:04):
-- opened by holding "Hop in" at a cannon. One card per place the cannon can fire to, each with a picture of its
-- landmark, its name, how many of its cats the player has ("7/10 cats", no coin line: Derek 13:55) and Launch.
-- The Town Square cannon lists every area the player's tier has opened, the Alleyway from Tier 1; a camp's cannon
-- lists Town Square first, then the other opened areas. In the last DuskWarningSeconds of the day the area cards
-- read "Night soon" and at night a moon covers them, with the sunrise countdown under the title; Town Square
-- stays open. Every Launch greys while carrying. Rules and words in Components/CannonLogic.

local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CannonLogic = require(script.Parent.Parent.Components.CannonLogic)
local Create = require(script.Parent.Parent.Components.Create)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local NightClock = require(script.Parent.Parent.Components.NightClock)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	launch: (cannonId: string, destination: string) -> (),
	close: () -> (),
}

export type Cannon = {
	frame: Frame,
	setCatalog: (self: Cannon, catalog: Types.Catalog) -> (),
	-- "town" or a camp's area id: the cannon the player hopped into
	setCannon: (self: Cannon, cannonId: string) -> (),
	setAreasOpen: (self: Cannon, open: boolean) -> (),
	setClock: (self: Cannon, phase: Types.ClockPhase?, phaseEndsAt: number?) -> (),
	render: (self: Cannon, state: Types.PlayerState, carrying: boolean) -> (),
	opened: (self: Cannon) -> (),
	closed: (self: Cannon) -> (),
	-- the server's answer: a refusal lifts the wait and wobbles the card's Launch
	result: (self: Cannon, ok: boolean, destination: string?) -> (),
	destroy: (self: Cannon) -> (),
}

local CARD = Vector2.new(226, 214)
local ART_H = 100
local PENDING_SECONDS = 1 -- Launch greys this long after a press, so a double tap is one launch
local DUSK_SECONDS: number = 15
do
	local Config =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	DUSK_SECONDS = (Config :: any).DuskWarningSeconds or DUSK_SECONDS
end

local Cannon = {}
Cannon.__index = Cannon

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function Cannon.new(callbacks: Callbacks): Cannon
	local self = setmetatable({}, Cannon) :: any
	self._callbacks = callbacks
	self._cards = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._cannonId = CannonLogic.TOWN
	self._areasOpen = true
	self._phase = nil :: Types.ClockPhase?
	self._phaseEndsAt = nil :: number?
	self._state = nil :: Types.PlayerState?
	self._carrying = false
	self._pendingUntil = 0
	self._open = false
	self._tick = 0

	local panel = Panel.new({
		name = "Cannon",
		color = Theme.colors.mintDark,
		icon = Theme.icons.cannon,
		title = "Cat Cannon",
		subtitle = "Pick where to fly",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 540), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
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
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap + 4, Theme.sizes.gap + 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 6),
		}),
	})

	return self :: Cannon
end

-- One card per place: Town Square and every catalog area. render shows the ones this cannon lists.
function Cannon._buildCards(self: any)
	for _, card in self._cards do
		card.launch:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	local places: { { id: string, name: string } } =
		{ { id = CannonLogic.TOWN, name = CannonLogic.TOWN_NAME } }
	local areaList: { Types.AreaDef } = catalog.areas or {}
	for _, area in areaList do
		table.insert(places, { id = area.id, name = area.name })
	end
	for _, place in places do
		local id = place.id
		local frame: Frame = Create("Frame", {
			Name = id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Visible = false,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local art: Frame = Create("Frame", {
			Name = "Art",
			BackgroundColor3 = Theme.areaColors[id] or Theme.colors.caramel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, ART_H),
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		-- the emoji under the picture shows until the picture loads, and for good where there is none
		local icon = text({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = (Theme.icons :: any)[id] or Theme.icons.travel,
			Parent = art,
		})
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
			Parent = icon,
		})
		local picture = Theme.areaPictures[id]
		if picture then
			Create("ImageLabel", {
				Name = "Picture",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = picture,
				ScaleType = Enum.ScaleType.Crop,
				Parent = art,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		end
		-- the night cover: a moon and "Closed until sunrise" over the picture
		local night: Frame = Create("Frame", {
			Name = "Night",
			BackgroundColor3 = Theme.colors.skyText,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 3,
			Parent = art,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		text({
			Name = "Moon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(48, 48),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = Theme.icons.moon,
			ZIndex = 4,
			Parent = night,
		})
		local nightLine = text({
			Name = "Line",
			Position = UDim2.new(0, 6, 0, 62),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.colors.white,
			Text = "Closed until sunrise",
			ZIndex = 4,
			Parent = night,
		})
		Outline.text(nightLine, 2)
		Outline.border(art, 2)
		Outline.shade(art, 0.2)
		text({
			Name = "Name",
			Position = UDim2.fromOffset(10, ART_H + 14),
			Size = UDim2.new(1, -20, 0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = place.name,
			Parent = frame,
		})
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(10, ART_H + 40),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = if id == CannonLogic.TOWN then "Cafes and markets" else "",
			Parent = frame,
		})
		local launch = Button.new({
			name = "Launch",
			text = "Launch",
			icon = Theme.icons.cannon,
			style = "primary",
			size = UDim2.new(1, -20, 0, 44),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -10),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_press(id)
			end,
		})
		self._cards[id] = {
			frame = frame,
			night = night,
			count = count,
			launch = launch,
			buttonState = nil :: CannonLogic.ButtonState?,
			pending = false,
		}
	end
end

function Cannon.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildCards()
	self:_rerender()
end

function Cannon.setCannon(self: any, cannonId: string)
	self._cannonId = cannonId
	self:_rerender()
end

-- F66: false from dusk to sunrise.
function Cannon.setAreasOpen(self: any, open: boolean)
	self._areasOpen = open
	self:_rerender()
end

function Cannon.setClock(self: any, phase: Types.ClockPhase?, phaseEndsAt: number?)
	self._phase, self._phaseEndsAt = phase, phaseEndsAt
	self:_rerender()
end

function Cannon._remaining(self: any): number?
	local endsAt: number? = self._phaseEndsAt
	if endsAt == nil then
		return nil
	end
	return endsAt - Workspace:GetServerTimeNow()
end

function Cannon._press(self: any, destination: string)
	if os.clock() < self._pendingUntil then
		return
	end
	local card = self._cards[destination]
	if card == nil or card.buttonState ~= "launch" then
		return
	end
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self:_rerender()
	task.delay(PENDING_SECONDS, function()
		if os.clock() >= self._pendingUntil then
			self:_rerender()
		end
	end)
	self._callbacks.launch(self._cannonId, destination)
end

function Cannon._rerender(self: any)
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state, self._carrying)
	end
end

function Cannon.render(self: any, state: Types.PlayerState, carrying: boolean)
	self._state = state
	self._carrying = carrying
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	local areas: { Types.AreaDef } = catalog.areas or {}
	local tier = state.tier or 1
	local closed = not NightClock.areasOpen(self._areasOpen)
	local remaining = self:_remaining()
	local dusk = self._phase ~= nil
		and remaining ~= nil
		and NightClock.isDusk(self._phase :: NightClock.Phase, remaining, DUSK_SECONDS)
	local pending = os.clock() < self._pendingUntil
	local list = CannonLogic.destinations(areas :: any, tier, self._cannonId)
	local shown: { [string]: number } = {}
	for index, destination in list do
		shown[destination.id] = index
	end
	for id, card in self._cards do
		local order = shown[id]
		card.frame.Visible = order ~= nil
		if order == nil then
			continue
		end
		card.frame.LayoutOrder = order
		local buttonState: CannonLogic.ButtonState = CannonLogic.button(id, closed, dusk, carrying)
		card.night.Visible = buttonState == "night"
		if id ~= CannonLogic.TOWN then
			local counts = IndexRewards.counts(catalog, state, id)
			card.count.Text = ("%d/%d cats"):format(counts.found, counts.total)
		end
		local enabled = buttonState == "launch" and not pending
		if card.buttonState ~= buttonState then
			card.buttonState = buttonState
			card.launch:setText(
				if buttonState == "night"
					then Theme.icons.moon .. " Sunrise"
					elseif buttonState == "dusk" then "Night soon"
					else "Launch"
			)
		end
		if card.enabled ~= enabled then
			card.enabled = enabled
			card.launch:setEnabled(enabled)
		end
	end
	local notice = CannonLogic.notice(closed, dusk, carrying, if closed then remaining else nil)
	local plain = if self._cannonId == CannonLogic.TOWN
		then "Pick where to fly"
		else "Fly home to " .. CannonLogic.TOWN_NAME .. " or on to another area"
	if notice == nil and CannonLogic.moreToOpen(areas :: any, tier) then
		plain ..= ". More open as you rank up."
	end
	self._panel:setTitle("Cat Cannon", notice or plain)
end

-- While the picker is open the sunrise countdown and the dusk warning move on their own, once a second.
function Cannon.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_rerender()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				self:_rerender()
			end
		end
	end)
end

function Cannon.closed(self: any)
	self._open = false
	self._tick += 1
end

function Cannon.result(self: any, ok: boolean, destination: string?)
	if ok then
		return
	end
	self._pendingUntil = 0
	self:_rerender()
	local card = if destination then self._cards[destination] else nil
	if card then
		local button: Frame = card.launch.instance
		button.Rotation = -8
		Tween.to(
			button,
			TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Rotation = 0 }
		)
	end
end

function Cannon.destroy(self: any)
	self._open = false
	self._tick += 1
	for _, card in self._cards do
		card.launch:destroy()
	end
	self._panel:destroy()
end

return Cannon
